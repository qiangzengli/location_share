import 'dart:async';
import 'dart:io' show Platform;

import 'package:x_amap_flutter_base/amap_flutter_base.dart';
import 'package:x_amap_flutter_location/amap_flutter_location.dart';
import 'package:x_amap_flutter_location/amap_location_option.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:location_share/config/env.dart';
import 'package:location_share/models/participant_location.dart';
import 'package:location_share/repositories/location_sync_repository.dart';
import 'package:location_share/services/local_prefs.dart';
import 'package:location_share/utils/geo_utils.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

class SharingController extends ChangeNotifier {
  SharingController({
    required LocalPrefs prefs,
    LocationSyncRepository? syncRepository,
  })  : _prefs = prefs,
        _sync = syncRepository;

  final LocalPrefs _prefs;
  final LocationSyncRepository? _sync;

  /// 每次启动管道新建实例，并在停止时 [destroy]，避免 [onLocationChanged] 单订阅 Stream 二次 listen 报错。
  AMapFlutterLocation? _location;

  String participantId = '';
  String displayName = '我';
  String groupId = LocalPrefs.defaultGroupId;
  bool amapPrivacyAccepted = false;
  bool sharingEnabled = false;
  String? statusMessage;
  String? selectedParticipantId;

  LatLng? myLatLng;
  double? myAccuracy;
  DateTime? myLocationTime;

  final Map<String, ParticipantLocation> remoteById = {};
  StreamSubscription<List<ParticipantLocation>>? _remoteSub;
  StreamSubscription<Map<String, Object>>? _locSub;

  DateTime? _lastUpsertUtc;
  LatLng? _lastUpsertPosition;

  static const _upsertMinInterval = Duration(seconds: 2);
  static const _upsertMinMoveM = 8.0;

  static const _androidMapPrivacyChannel = MethodChannel(
    'com.locationshare.location_share/amap_privacy',
  );

  bool get hasSyncBackend => _sync != null;

  Future<void> initialize() async {
    participantId = await _prefs.getParticipantId() ?? '';
    if (participantId.isEmpty) {
      participantId = const Uuid().v4();
      await _prefs.setParticipantId(participantId);
    }
    displayName = await _prefs.getDisplayName();
    groupId = await _prefs.getGroupId();
    amapPrivacyAccepted = await _prefs.getAmapPrivacyAccepted();
    sharingEnabled = await _prefs.getSharingEnabled();

    if (amapPrivacyAccepted) {
      await _syncAmapPrivacyNative();
    }

    if (sharingEnabled) {
      await _startPipeline();
    }
    notifyListeners();
  }

  Future<void> applyAuthenticatedUser({
    required String uid,
    required String displayName,
  }) async {
    final normalizedName = displayName.trim().isEmpty ? '我' : displayName.trim();
    var changed = false;

    if (participantId != uid) {
      participantId = uid;
      await _prefs.setParticipantId(uid);
      changed = true;
    }
    if (this.displayName != normalizedName) {
      this.displayName = normalizedName;
      await _prefs.setDisplayName(normalizedName);
      changed = true;
    }

    if (changed) {
      notifyListeners();
    }
  }

  Future<void> setAmapPrivacyAccepted(bool v) async {
    amapPrivacyAccepted = v;
    await _prefs.setAmapPrivacyAccepted(v);
    if (v) {
      await _syncAmapPrivacyNative();
      if (sharingEnabled) {
        await _startPipeline();
      }
    }
    notifyListeners();
  }

  /// 定位 SDK 与地图 SDK 均要求在各自接口前完成隐私合规；Android 地图侧再经 [MainActivity] 同步 [MapsInitializer]。
  Future<void> _syncAmapPrivacyNative() async {
    AMapFlutterLocation.updatePrivacyShow(true, true);
    AMapFlutterLocation.updatePrivacyAgree(true);
    if (Platform.isAndroid) {
      try {
        await _androidMapPrivacyChannel.invokeMethod<void>('syncMapPrivacy');
      } on MissingPluginException {
        // 非 Android 宿主或旧构建无 Channel 时忽略
      }
    }
  }

  Future<void> setDisplayName(String name) async {
    displayName = name.trim().isEmpty ? '我' : name.trim();
    await _prefs.setDisplayName(displayName);
    notifyListeners();
  }

  Future<void> setGroupId(String id) async {
    final trimmed = id.trim();
    groupId = trimmed.isEmpty ? LocalPrefs.defaultGroupId : trimmed;
    await _prefs.setGroupId(groupId);
    if (sharingEnabled) {
      await _stopPipeline();
      await _startPipeline();
    }
    notifyListeners();
  }

  void selectParticipant(String? id) {
    selectedParticipantId = id;
    notifyListeners();
  }

  Future<void> setSharingEnabled(bool on) async {
    if (on == sharingEnabled) return;
    if (on) {
      if (_sync == null) {
        statusMessage = '请先完成 Firebase 配置并登录，才能启用位置共享。';
        notifyListeners();
        return;
      }
      final loc = await Permission.locationWhenInUse.request();
      if (!loc.isGranted) {
        statusMessage = '需要定位权限才能共享位置。';
        notifyListeners();
        return;
      }
    }
    sharingEnabled = on;
    await _prefs.setSharingEnabled(on);
    if (on) {
      await _startPipeline();
    } else {
      await _stopPipeline();
    }
    statusMessage = null;
    notifyListeners();
  }

  Future<void> _startPipeline() async {
    await _stopPipeline();
    if (!amapPrivacyAccepted) {
      statusMessage = '请先同意高德地图 SDK 隐私合规声明。';
      notifyListeners();
      return;
    }

    await _syncAmapPrivacyNative();
    AMapFlutterLocation.setApiKey(Env.amapAndroidKey, Env.amapIosKey);

    _location = AMapFlutterLocation();
    _location!.setLocationOption(
      AMapLocationOption(
        onceLocation: false,
        needAddress: false,
        locationInterval: 2000,
        pausesLocationUpdatesAutomatically: false,
      ),
    );

    _locSub = _location!.onLocationChanged().listen(_onLocationMap);

    _location!.startLocation();

    final sync = _sync;
    if (sync != null) {
      await _remoteSub?.cancel();
      _remoteSub = sync.watchGroupSnapshots(groupId).listen((list) {
        remoteById
          ..clear()
          ..addEntries(list.map((e) => MapEntry(e.participantId, e)));
        notifyListeners();
      });
    }
  }

  Future<void> _stopPipeline() async {
    await _remoteSub?.cancel();
    _remoteSub = null;
    remoteById.clear();

    await _locSub?.cancel();
    _locSub = null;

    if (amapPrivacyAccepted) {
      await _syncAmapPrivacyNative();
      _location?.stopLocation();
      _location?.destroy();
    }
    _location = null;
  }

  void _onLocationMap(Map<String, Object> raw) {
    final err = raw['errorCode'];
    if (err != null && err.toString() != '0') {
      final info = raw['errorInfo']?.toString();
      statusMessage =
          '定位失败($err)${info == null || info.isEmpty ? '' : ': $info'}';
      notifyListeners();
      return;
    }
    final lat = _toDouble(raw['latitude']);
    final lng = _toDouble(raw['longitude']);
    if (lat == null || lng == null) return;

    final next = LatLng(lat, lng);
    myLatLng = next;
    myAccuracy = _toDouble(raw['accuracy']);
    myLocationTime = DateTime.now();
    notifyListeners();

    if (!sharingEnabled || _sync == null) return;

    if (!_shouldUpsert(next)) return;

    final row = ParticipantLocation(
      groupId: groupId,
      participantId: participantId,
      displayName: displayName,
      latitude: lat,
      longitude: lng,
      accuracy: myAccuracy,
      heading: _toDouble(raw['bearing'] ?? raw['heading']),
      speed: _toDouble(raw['speed']),
      updatedAt: DateTime.now().toUtc(),
      platform: Platform.isIOS ? 'ios' : 'android',
    );

    _lastUpsertUtc = row.updatedAt;
    _lastUpsertPosition = next;

    unawaited(_upsertSafe(row));
  }

  Future<void> _upsertSafe(ParticipantLocation row) async {
    try {
      await _sync!.upsertMyLocation(row);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('upsert failed: $e\n$st');
      }
      statusMessage = '位置同步失败，请检查 Firebase 配置、登录状态与网络。';
      notifyListeners();
    }
  }

  bool _shouldUpsert(LatLng next) {
    final now = DateTime.now().toUtc();
    if (_lastUpsertUtc == null || _lastUpsertPosition == null) return true;
    if (now.difference(_lastUpsertUtc!) >= _upsertMinInterval) return true;
    return distanceMeters(_lastUpsertPosition!, next) >= _upsertMinMoveM;
  }

  double? _toDouble(Object? v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  List<ParticipantLocation> peopleForList() {
    final me = myLatLng == null
        ? null
        : ParticipantLocation(
            groupId: groupId,
            participantId: participantId,
            displayName: displayName,
            latitude: myLatLng!.latitude,
            longitude: myLatLng!.longitude,
            accuracy: myAccuracy,
            updatedAt: myLocationTime ?? DateTime.now(),
            platform: Platform.isIOS ? 'ios' : 'android',
          );

    final others = remoteById.values
        .where((p) => p.participantId != participantId)
        .toList();

    others.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final out = <ParticipantLocation>[];
    if (me != null) {
      out.add(me);
    }
    out.addAll(others);
    return out;
  }

  ParticipantLocation? selectedParticipant() {
    if (selectedParticipantId == null) return null;
    if (selectedParticipantId == participantId) {
      final me = myLatLng;
      if (me == null) return null;
      return ParticipantLocation(
        groupId: groupId,
        participantId: participantId,
        displayName: displayName,
        latitude: me.latitude,
        longitude: me.longitude,
        accuracy: myAccuracy,
        updatedAt: myLocationTime ?? DateTime.now(),
        platform: Platform.isIOS ? 'ios' : 'android',
      );
    }
    return remoteById[selectedParticipantId!];
  }

  @override
  void dispose() {
    unawaited(_stopPipeline());
    super.dispose();
  }
}

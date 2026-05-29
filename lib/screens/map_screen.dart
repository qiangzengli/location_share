import 'dart:io' show Platform;

import 'package:x_amap_flutter_base/amap_flutter_base.dart';
import 'package:x_amap_flutter_map/amap_flutter_map.dart';
import 'package:flutter/material.dart';
import 'package:location_share/config/env.dart';
import 'package:location_share/models/participant_location.dart';
import 'package:location_share/providers/group_controller.dart';
import 'package:location_share/providers/sharing_controller.dart';
import 'package:location_share/utils/time_utils.dart';
import 'package:location_share/widgets/amap_privacy_dialog.dart';
import 'package:location_share/widgets/people_sheet.dart';
import 'package:location_share/widgets/person_detail_sheet.dart';
import 'package:provider/provider.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  AMapController? _mapController;

  static const _initial = CameraPosition(
    target: LatLng(39.909187, 116.397451),
    zoom: 14,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensurePrivacy());
  }

  Future<void> _ensurePrivacy() async {
    final c = context.read<SharingController>();
    if (!c.initialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ensurePrivacy();
      });
      return;
    }
    if (c.amapPrivacyAccepted) return;
    await _showPrivacyDialogAndPersist();
  }

  Future<void> _showPrivacyDialogAndPersist() async {
    final c = context.read<SharingController>();
    final ok = await showAmapPrivacyDialog(context);
    if (!mounted) return;
    await c.setAmapPrivacyAccepted(ok);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未同意隐私声明将无法使用地图与定位。')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<SharingController>();

    // 必须在原生侧以 hasAgree=true 首次创建地图，否则会报 E/3dmap 555571。
    if (!c.amapPrivacyAccepted) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('位置共享'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.privacy_tip_outlined,
                  size: 72,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 20),
                Text(
                  '使用高德地图与定位前，请先阅读并同意隐私说明。',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _showPrivacyDialogAndPersist,
                  child: const Text('查看并同意'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final markers = _buildMarkers(c);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          AMapWidget(
            apiKey: AMapApiKey(
              androidKey: Env.amapAndroidKey,
              iosKey: Env.amapIosKey,
            ),
            privacyStatement: const AMapPrivacyStatement(
              hasContains: true,
              hasShow: true,
              hasAgree: true,
            ),
            initialCameraPosition: _initial,
            myLocationStyleOptions: MyLocationStyleOptions(false),
            markers: markers,
            onMapCreated: (ctrl) {
              _mapController = ctrl;
            },
            onTap: (_) => c.selectParticipant(null),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Material(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(14),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                      child: Row(
                        children: [
                          Icon(
                            c.sharingEnabled
                                ? Icons.location_on
                                : Icons.location_off,
                            color: c.sharingEnabled
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  c.sharingEnabled ? '共享中' : '未共享',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  c.statusMessage ??
                                      (c.myLocationTime == null
                                          ? '等待定位…'
                                          : '本机 ${relativeTimeZh(c.myLocationTime!)}'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Consumer<GroupController>(
                            builder: (_, gc, __) {
                              if (gc.groups.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return PopupMenuButton<String>(
                                tooltip: '切换群组',
                                icon: const Icon(Icons.swap_horiz),
                                onSelected: (id) {
                                  gc.setActiveGroup(id);
                                  context
                                      .read<SharingController>()
                                      .setGroupId(id);
                                },
                                itemBuilder: (_) => gc.groups
                                    .map((g) => PopupMenuItem(
                                          value: g.id,
                                          child: Row(
                                            children: [
                                              if (g.id == gc.activeGroupId)
                                                Icon(Icons.check,
                                                    size: 18,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .primary),
                                              if (g.id == gc.activeGroupId)
                                                const SizedBox(width: 8),
                                              Text(g.name),
                                            ],
                                          ),
                                        ))
                                    .toList(),
                              );
                            },
                          ),
                        ],
                      ),
                ),
              ),
            ),
          ),
        ),
          Positioned(
            right: 16,
            bottom: MediaQuery.paddingOf(context).bottom + 200,
            child: FloatingActionButton.small(
              heroTag: 'recenter',
              onPressed: () => _moveToLatLng(c.myLatLng, zoom: 16),
              child: const Icon(Icons.my_location),
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.22,
            minChildSize: 0.14,
            maxChildSize: 0.55,
            builder: (ctx, scrollController) {
              return Material(
                elevation: 8,
                color: Theme.of(context).colorScheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                clipBehavior: Clip.antiAlias,
                child: PeopleSheet(
                  scrollController: scrollController,
                  onPersonTap: (person, isSelf) =>
                      _onPersonChosen(context, person, isSelf),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _onPersonChosen(
    BuildContext context,
    ParticipantLocation person,
    bool isSelf,
  ) async {
    final c = context.read<SharingController>();
    c.selectParticipant(person.participantId);
    await _moveToLatLng(person.latLng, zoom: 16);
    if (!context.mounted) return;
    await showPersonDetailSheet(
      context,
      person: person,
      isSelf: isSelf,
      viewerPosition: c.myLatLng,
    );
  }

  Future<void> _moveToLatLng(LatLng? target, {required double zoom}) async {
    if (target == null || _mapController == null) return;
    await _mapController!.moveCamera(
      CameraUpdate.newLatLngZoom(target, zoom),
    );
  }

  Set<Marker> _buildMarkers(SharingController c) {
    final out = <Marker>{};
    if (c.myLatLng != null) {
      final selfPos = c.myLatLng!;
      final m = Marker(
        position: selfPos,
        icon: BitmapDescriptor.defaultMarkerWithHue(210),
        infoWindow: InfoWindow(title: '${c.displayName}（我）'),
        onTap: (String id) {
          final ctrl = context.read<SharingController>();
          final pos = ctrl.myLatLng;
          if (pos == null) return;
          final me = ParticipantLocation(
            groupId: ctrl.groupId,
            participantId: ctrl.participantId,
            displayName: ctrl.displayName,
            latitude: pos.latitude,
            longitude: pos.longitude,
            accuracy: ctrl.myAccuracy,
            updatedAt: ctrl.myLocationTime ?? DateTime.now(),
            platform: Platform.isIOS ? 'ios' : 'android',
          );
          _onPersonChosen(context, me, true);
        },
      );
      m.setIdForCopy('self_${c.participantId}');
      out.add(m);
    }
    for (final p in c.remoteById.values) {
      if (p.participantId == c.participantId) continue;
      final mk = Marker(
        position: p.latLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(10),
        infoWindow: InfoWindow(title: p.displayName),
        onTap: (String id) {
          _onPersonChosen(context, p, false);
        },
      );
      mk.setIdForCopy('p_${p.participantId}');
      out.add(mk);
    }
    return out;
  }
}

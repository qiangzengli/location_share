import 'package:flutter/material.dart';
import 'package:location_share/config/env.dart';
import 'package:location_share/providers/sharing_controller.dart';
import 'package:location_share/repositories/http_location_sync_repository.dart';
import 'package:location_share/repositories/location_sync_repository.dart';
import 'package:location_share/screens/map_screen.dart';
import 'package:location_share/services/local_prefs.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = LocalPrefs();
  final LocationSyncRepository? sync = Env.hasHttpBackend
      ? HttpLocationSyncRepository(prefs: prefs)
      : null;

  runApp(
    ChangeNotifierProvider(
      create: (_) => SharingController(
        prefs: prefs,
        syncRepository: sync,
      )..initialize(),
      child: const LocationShareApp(),
    ),
  );
}

class LocationShareApp extends StatelessWidget {
  const LocationShareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '位置共享',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0A84FF),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: true),
      ),
      home: const MapScreen(),
    );
  }
}

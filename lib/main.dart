import 'package:flutter/material.dart';
import 'package:location_share/providers/auth_controller.dart';
import 'package:location_share/providers/sharing_controller.dart';
import 'package:location_share/repositories/http_location_sync_repository.dart';
import 'package:location_share/services/http_auth_service.dart';
import 'package:location_share/services/local_prefs.dart';
import 'package:location_share/widgets/app_shell.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = LocalPrefs();
  final authService = HttpAuthService(
    baseUrl: 'http://localhost:8080',
    prefs: prefs,
  );
  final locationSync = HttpLocationSyncRepository(
    baseUrl: 'http://localhost:8080',
    getAccessToken: authService.getAccessToken,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SharingController(
            prefs: prefs,
            syncRepository: locationSync,
          )..initialize(),
        ),
        ChangeNotifierProvider(
          create: (_) => AuthController(
            authService: authService,
          )..initialize(),
        ),
      ],
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
      home: const AppShell(),
    );
  }
}

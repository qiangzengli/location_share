import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:location_share/providers/auth_controller.dart';
import 'package:location_share/providers/sharing_controller.dart';
import 'package:location_share/repositories/firestore_location_sync_repository.dart';
import 'package:location_share/repositories/location_sync_repository.dart';
import 'package:location_share/services/auth_service.dart';
import 'package:location_share/services/firebase_bootstrap.dart';
import 'package:location_share/services/local_prefs.dart';
import 'package:location_share/widgets/app_shell.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final firebaseState = await initializeFirebaseIfConfigured();
  final prefs = LocalPrefs();
  final LocationSyncRepository? sync = firebaseState.isConfigured
      ? FirestoreLocationSyncRepository()
      : null;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SharingController(
            prefs: prefs,
            syncRepository: sync,
          )..initialize(),
        ),
        ChangeNotifierProvider(
          create: (_) => AuthController(
            authService: firebaseState.isConfigured
                ? AuthService(firebaseAuth: FirebaseAuth.instance)
                : null,
          )..initialize(),
        ),
      ],
      child: LocationShareApp(
        firebaseConfigured: firebaseState.isConfigured,
        firebaseErrorMessage: firebaseState.errorMessage,
      ),
    ),
  );
}

class LocationShareApp extends StatelessWidget {
  const LocationShareApp({
    super.key,
    required this.firebaseConfigured,
    this.firebaseErrorMessage,
  });

  final bool firebaseConfigured;
  final String? firebaseErrorMessage;

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
      home: AppShell(
        firebaseConfigured: firebaseConfigured,
        firebaseErrorMessage: firebaseErrorMessage,
      ),
    );
  }
}

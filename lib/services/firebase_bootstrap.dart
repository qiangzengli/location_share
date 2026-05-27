import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:location_share/firebase_options.dart';

class FirebaseBootstrapResult {
  const FirebaseBootstrapResult({
    required this.isConfigured,
    this.errorMessage,
  });

  final bool isConfigured;
  final String? errorMessage;
}

Future<FirebaseBootstrapResult> initializeFirebaseIfConfigured() async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: _nativeOptions());
    }
    return const FirebaseBootstrapResult(isConfigured: true);
  } catch (error) {
    return FirebaseBootstrapResult(
      isConfigured: false,
      errorMessage: error.toString(),
    );
  }
}

FirebaseOptions _nativeOptions() {
  if (Platform.isAndroid) {
    return DefaultFirebaseOptions.android;
  }
  if (Platform.isIOS) {
    return DefaultFirebaseOptions.ios;
  }
  throw UnsupportedError('Unsupported platform for Firebase bootstrap.');
}

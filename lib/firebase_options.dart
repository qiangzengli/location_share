import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';

/// Standard FlutterFire entrypoint.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'This app does not include a web Firebase configuration.',
      );
    }
    if (Platform.isAndroid) {
      return android;
    }
    if (Platform.isIOS) {
      return ios;
    }
    throw UnsupportedError('Unsupported platform for Firebase options.');
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCBNEZYsO51mGbidYqdO6Jx3JPmztKkph8',
    appId: '1:656807295614:android:faf4ba55a49ae54b7ef62f',
    messagingSenderId: '656807295614',
    projectId: 'locationshare-6423f',
    storageBucket: 'locationshare-6423f.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDdkvQKVcKMc6nP59yVg-AJcncoLrxzXKw',
    appId: '1:656807295614:ios:baa28f35f8b191c97ef62f',
    messagingSenderId: '656807295614',
    projectId: 'locationshare-6423f',
    storageBucket: 'locationshare-6423f.firebasestorage.app',
    iosBundleId: 'com.locationshare.locationShare',
  );
}

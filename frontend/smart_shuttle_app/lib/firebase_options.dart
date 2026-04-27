import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default Firebase options for this app.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.windows:
        return windows;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDZVvGX4XPlhgW5NUVKjs9IO2aPXE0WvGM',
    appId: '1:317725246812:web:d50b5dda6ba6ce99826d99',
    messagingSenderId: '317725246812',
    projectId: 'smart-shuttle-ai-b58f8',
    authDomain: 'smart-shuttle-ai-b58f8.firebaseapp.com',
    storageBucket: 'smart-shuttle-ai-b58f8.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBFQNEgT1mR4SjeQNAe-KDlCxWBqI7Aqdw',
    appId: '1:661715418034:android:536c865dd905a35a3c02ab',
    messagingSenderId: '661715418034',
    projectId: 'driver-behavior-detectio-62d10',
    storageBucket: 'driver-behavior-detectio-62d10.firebasestorage.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDZVvGX4XPlhgW5NUVKjs9IO2aPXE0WvGM',
    appId: '1:317725246812:web:d50b5dda6ba6ce99826d99',
    messagingSenderId: '317725246812',
    projectId: 'smart-shuttle-ai-b58f8',
    authDomain: 'smart-shuttle-ai-b58f8.firebaseapp.com',
    storageBucket: 'smart-shuttle-ai-b58f8.firebasestorage.app',
  );
}

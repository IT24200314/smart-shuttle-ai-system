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
    apiKey: 'AIzaSyAZOw-F2Anmqr49D6p29IxMHGgSOcHjyQQ',
    appId: '1:809923084542:web:5c2fb7d2e77ec3e9dda5af',
    messagingSenderId: '809923084542',
    projectId: 'smart-shuttle-198a1',
    authDomain: 'smart-shuttle-198a1.firebaseapp.com',
    storageBucket: 'smart-shuttle-198a1.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCp0ZSSDB57TjWsZeuz8shC2hfsIGS8VHc',
    appId: '1:809923084542:android:5d3e54df9e42b882dda5af',
    messagingSenderId: '809923084542',
    projectId: 'smart-shuttle-198a1',
    storageBucket: 'smart-shuttle-198a1.firebasestorage.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAZOw-F2Anmqr49D6p29IxMHGgSOcHjyQQ',
    appId: '1:809923084542:web:5c2fb7d2e77ec3e9dda5af',
    messagingSenderId: '809923084542',
    projectId: 'smart-shuttle-198a1',
    authDomain: 'smart-shuttle-198a1.firebaseapp.com',
    storageBucket: 'smart-shuttle-198a1.firebasestorage.app',
  );
}

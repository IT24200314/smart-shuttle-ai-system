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
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD79jqbWA26j63wigM2ZJoTa0OhLJ3Em24',
    appId: '1:274381434085:web:7ecb76f3efbd586bfc380c',
    messagingSenderId: '274381434085',
    projectId: 'system-audit-logs',
    authDomain: 'system-audit-logs.firebaseapp.com',
    storageBucket: 'system-audit-logs.firebasestorage.app',
    measurementId: 'G-RJHSG57PYN',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCp0ZSSDB57TjWsZeuz8shC2hfsIGS8VHc',
    appId: '1:809923084542:android:5d3e54df9e42b882dda5af',
    messagingSenderId: '809923084542',
    projectId: 'smart-shuttle-198a1',
    storageBucket: 'smart-shuttle-198a1.firebasestorage.app',
  );
}

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC9O7N5R5LH-MMeINGy6tTM-XUwa7O2Pzs',
    appId: '1:522176211793:android:b1ae3ad36f180ee5f34170',
    messagingSenderId: '522176211793',
    projectId: 'foodchoose-4f82e',
    storageBucket: 'foodchoose-4f82e.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCdSPMXejfhZ8B-OyMypTYRK2vvB97ly0E',
    appId: '1:522176211793:ios:14aa78498ef5bf64f34170',
    messagingSenderId: '522176211793',
    projectId: 'foodchoose-4f82e',
    storageBucket: 'foodchoose-4f82e.firebasestorage.app',
    iosBundleId: 'com.example.foodchoose',
  );
}

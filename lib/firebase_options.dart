import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
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

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAxiSlV2DiK5jAuPZzvlpOrrQXdmEF3TF8',
    appId: '1:1044579725862:web:379b1d870cf8c6fcb3ece7',
    messagingSenderId: '1044579725862',
    projectId: 'ridehome-187ca',
    storageBucket: 'ridehome-187ca.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDQ-VWn-YnmeU4aS7pbVy402j5ulQMuxGM',
    appId: '1:1044579725862:android:3d2c46fbdd7f4e57b3ece7',
    messagingSenderId: '1044579725862',
    projectId: 'ridehome-187ca',
    storageBucket: 'ridehome-187ca.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCd10M-yxEI7quQPgdXrJ3XMd-GYSNbwKc',
    appId: '1:1044579725862:ios:09c820fcb4fea82bb3ece7',
    messagingSenderId: '1044579725862',
    projectId: 'ridehome-187ca',
    storageBucket: 'ridehome-187ca.appspot.com',
    iosBundleId: 'com.example.ride',
  );
}

// File generated for FairScan Firebase project
// Project: fairscan-2026-8a945

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
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBEav2J5vzguzVEh4XNqxc4ytW429hVZHA',
    appId: '1:YOUR_APP_ID:web:YOUR_WEB_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'fairscan-2026-8a945',
    authDomain: 'fairscan-2026-8a945.firebaseapp.com',
    storageBucket: 'fairscan-2026-8a945.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBEav2J5vzguzVEh4XNqxc4ytW429hVZHA',
    appId: '1:YOUR_APP_ID:android:YOUR_ANDROID_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'fairscan-2026-8a945',
    storageBucket: 'fairscan-2026-8a945.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBEav2J5vzguzVEh4XNqxc4ytW429hVZHA',
    appId: '1:YOUR_APP_ID:ios:YOUR_IOS_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'fairscan-2026-8a945',
    iosBundleId: 'com.fairscan.app',
    storageBucket: 'fairscan-2026-8a945.appspot.com',
  );
}

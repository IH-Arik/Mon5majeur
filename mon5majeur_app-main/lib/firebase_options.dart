// File generated manually from google-services.json / GoogleService-Info.plist
// (the `flutterfire configure` CLI wasn't available in this environment).
// If you later run `flutterfire configure` for real, it's safe to overwrite
// this file — just make sure the project stays "mon5majeur".
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web.',
      );
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

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCo6P2P_D65tB8YEYWslcSmdyLXNnm4VCY',
    appId: '1:144976760248:android:78515b2fa27b36a5bf134d',
    messagingSenderId: '144976760248',
    projectId: 'mon5majeur',
    storageBucket: 'mon5majeur.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAANsV2q0rvqyUoya3-WDHsUM0V2YnhBpI',
    appId: '1:144976760248:ios:a65c22128d898502bf134d',
    messagingSenderId: '144976760248',
    projectId: 'mon5majeur',
    storageBucket: 'mon5majeur.firebasestorage.app',
    iosBundleId: 'com.mon5majeur.app',
  );
}

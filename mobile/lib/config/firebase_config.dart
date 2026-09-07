import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Builds [FirebaseOptions] from `--dart-define` for non-mobile platforms only.
class FirebaseConfig {
  static FirebaseOptions optionsFromDefines() {
    const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
    const appId = String.fromEnvironment('FIREBASE_APP_ID');
    const messagingSenderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
    const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
    const storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
    const authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
    const iosBundleId = String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID');
    const measurementId = String.fromEnvironment('FIREBASE_MEASUREMENT_ID');

    if (apiKey.isEmpty ||
        appId.isEmpty ||
        messagingSenderId.isEmpty ||
        projectId.isEmpty) {
      throw StateError(
        'Missing FIREBASE_* --dart-define values. Required for Firebase on '
        '${defaultTargetPlatform.name}. Android/iOS use native config files.',
      );
    }

    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      storageBucket: storageBucket.isEmpty ? null : storageBucket,
      authDomain: authDomain.isEmpty ? null : authDomain,
      iosBundleId: iosBundleId.isEmpty ? null : iosBundleId,
      measurementId: measurementId.isEmpty ? null : measurementId,
    );
  }
}

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Builds [FirebaseOptions] from `.env` for non-mobile platforms only.
class FirebaseConfig {
  static FirebaseOptions optionsFromEnv() {
    String requireEnv(String key) {
      final value = dotenv.env[key]?.trim();
      if (value == null || value.isEmpty) {
        throw StateError(
          'Missing $key in .env. Required for Firebase on '
          '${defaultTargetPlatform.name}. Android/iOS use native config files.',
        );
      }
      return value;
    }

    return FirebaseOptions(
      apiKey: requireEnv('FIREBASE_API_KEY'),
      appId: requireEnv('FIREBASE_APP_ID'),
      messagingSenderId: requireEnv('FIREBASE_MESSAGING_SENDER_ID'),
      projectId: requireEnv('FIREBASE_PROJECT_ID'),
      storageBucket: dotenv.env['FIREBASE_STORAGE_BUCKET']?.trim(),
      authDomain: dotenv.env['FIREBASE_AUTH_DOMAIN']?.trim(),
      iosBundleId: dotenv.env['FIREBASE_IOS_BUNDLE_ID']?.trim(),
      measurementId: dotenv.env['FIREBASE_MEASUREMENT_ID']?.trim(),
    );
  }
}

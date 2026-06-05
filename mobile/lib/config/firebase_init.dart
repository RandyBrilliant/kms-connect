import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'firebase_config.dart';

/// Initializes Firebase without duplicating API keys in Dart source.
///
/// Android and iOS read configuration from [google-services.json] and
/// [GoogleService-Info.plist] (standard FlutterFire setup).
///
/// Web and desktop builds must set the `FIREBASE_*` variables in `.env`
/// (see `.env.example`).
Future<void> initializeFirebaseApp() async {
  if (Firebase.apps.isNotEmpty) {
    return;
  }

  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
      await Firebase.initializeApp();
      return;
    default:
      await Firebase.initializeApp(
        options: FirebaseConfig.optionsFromEnv(),
      );
  }
}

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

/// Handles Google Play in-app updates on Android.
///
/// Notes:
/// - Works only for builds installed from Google Play.
/// - For debug/sideloaded APKs, this safely no-ops.
class AppUpdateService {
  Future<void> checkAndRunPlayStoreUpdate() async {
    if (kIsWeb || !Platform.isAndroid) return;

    try {
      final updateInfo = await InAppUpdate.checkForUpdate();

      if (updateInfo.updateAvailability != UpdateAvailability.updateAvailable) {
        return;
      }

      if (updateInfo.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
        return;
      }

      if (updateInfo.flexibleUpdateAllowed) {
        await InAppUpdate.startFlexibleUpdate();
        await InAppUpdate.completeFlexibleUpdate();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('In-app update skipped: $e');
      }
    }
  }
}

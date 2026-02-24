import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/endpoints.dart';

/// Preference key stored in SharedPreferences.
const _kPushEnabled = 'push_notifications_enabled';

/// Manages the user's in-app push-notification preference.
///
/// Responsibilities:
///   - Persist the on/off toggle via [SharedPreferences].
///   - Register / unregister the FCM device token with the backend.
///   - Surface whether the OS-level permission has been granted.
class NotificationSettingsService {
  static final NotificationSettingsService _instance =
      NotificationSettingsService._internal();
  factory NotificationSettingsService() => _instance;
  NotificationSettingsService._internal();

  /// Returns FirebaseMessaging instance only when Firebase is ready.
  /// Returns null if Firebase was never initialized (e.g. missing config).
  FirebaseMessaging? get _fcm {
    try {
      Firebase.app(); // throws StateError if not initialized
      return FirebaseMessaging.instance;
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Preference helpers
  // ---------------------------------------------------------------------------

  /// Returns the user's saved preference (defaults to [true] on first run).
  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kPushEnabled) ?? true;
  }

  Future<void> _setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPushEnabled, value);
  }

  // ---------------------------------------------------------------------------
  // OS permission helpers
  // ---------------------------------------------------------------------------

  /// Returns whether the OS notification permission is currently granted.
  Future<bool> isOsPermissionGranted() async {
    try {
      if (Platform.isIOS) {
        final settings = await _fcm?.getNotificationSettings();
        if (settings == null) return false;
        return settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
      }
      // Android 13+ requires POST_NOTIFICATIONS; older versions always granted.
      if (Platform.isAndroid) {
        return await Permission.notification.isGranted;
      }
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('isOsPermissionGranted error: $e');
      return false;
    }
  }

  /// Requests the OS notification permission.
  ///
  /// Returns [true] if the user grants (or has already granted) permission.
  Future<bool> requestOsPermission() async {
    try {
      if (Platform.isIOS) {
        final settings = await _fcm?.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        if (settings == null) return false;
        return settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
      }
      if (Platform.isAndroid) {
        final status = await Permission.notification.request();
        return status.isGranted;
      }
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('requestOsPermission error: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Enable / Disable
  // ---------------------------------------------------------------------------

  /// Enable push notifications:
  ///   1. Request OS permission (if not yet granted).
  ///   2. Register FCM token with the backend.
  ///   3. Persist preference.
  ///
  /// Returns [EnableResult] so the caller can react to permission denial.
  Future<EnableResult> enable() async {
    final granted = await requestOsPermission();
    if (!granted) {
      // Persist as disabled — permission was explicitly denied.
      await _setEnabled(false);
      return EnableResult.permissionDenied;
    }

    await _registerToken();
    await _setEnabled(true);
    return EnableResult.success;
  }

  /// Disable push notifications:
  ///   1. Unregister FCM token from the backend.
  ///   2. Persist preference.
  Future<void> disable() async {
    await _unregisterToken();
    await _setEnabled(false);
  }

  // ---------------------------------------------------------------------------
  // Token management
  // ---------------------------------------------------------------------------

  Future<void> _registerToken() async {
    try {
      final token = await _fcm?.getToken();
      if (token == null) return;
      final deviceType = Platform.isIOS ? 'ios' : 'android';
      await ApiClient().dio.post(
        ApiEndpoints.fcmRegister,
        data: {'token': token, 'device_type': deviceType},
      );
      if (kDebugMode) debugPrint('FCM token registered');
    } catch (e) {
      if (kDebugMode) debugPrint('FCM register error: $e');
    }
  }

  Future<void> _unregisterToken() async {
    try {
      final token = await _fcm?.getToken();
      if (token == null) return;
      await ApiClient().dio.post(
        ApiEndpoints.fcmUnregister,
        data: {'token': token},
      );
      if (kDebugMode) debugPrint('FCM token unregistered');
    } catch (e) {
      if (kDebugMode) debugPrint('FCM unregister error: $e');
    }
  }
}

/// Result of calling [NotificationSettingsService.enable].
enum EnableResult {
  /// Permission granted; token registered with backend.
  success,

  /// OS permission was denied. The app cannot send notifications until the
  /// user changes the setting in the system settings.
  permissionDenied,
}

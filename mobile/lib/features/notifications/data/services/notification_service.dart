import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/endpoints.dart';
import '../../../../core/widgets/custom_toast.dart';
import 'notification_settings_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  /// Lazily resolves FirebaseMessaging only after Firebase.initializeApp().
  FirebaseMessaging? get _firebaseMessaging {
    try {
      Firebase.app();
      return FirebaseMessaging.instance;
    } catch (_) {
      return null;
    }
  }

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // Respect user's in-app notification preference.
    final prefs = NotificationSettingsService();
    final userEnabled = await prefs.isEnabled();
    if (!userEnabled) {
      if (kDebugMode) debugPrint('Push notifications disabled by user — skipping init.');
      return;
    }

    // Request / check OS permission.
    final fcm = _firebaseMessaging;
    if (fcm == null) {
      if (kDebugMode) debugPrint('Firebase not initialized — skipping notification init.');
      return;
    }

    NotificationSettings settings = await fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // Initialize local notifications
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings();
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Background messages are handled by top-level function in main.dart

      // Handle notification taps when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpened);

      // Get FCM token and register with backend
      final token = await fcm.getToken();
      if (token != null) {
        if (kDebugMode) debugPrint('FCM Token: $token');
        await _registerTokenWithBackend(token);
      }

      // Listen for token refresh
      fcm.onTokenRefresh.listen((newToken) {
        if (kDebugMode) debugPrint('New FCM Token: $newToken');
        _registerTokenWithBackend(newToken);
      });
    }
  }

  /// Register/update the FCM device token with the backend.
  Future<void> _registerTokenWithBackend(String token) async {
    try {
      final deviceType = Platform.isIOS ? 'ios' : 'android';
      await ApiClient().dio.post(
        ApiEndpoints.fcmRegister,
        data: {
          'token': token,
          'device_type': deviceType,
        },
      );
      if (kDebugMode) debugPrint('FCM token registered with backend');
    } catch (e) {
      // Non-critical — user might not be logged in yet.
      if (kDebugMode) debugPrint('FCM token registration failed: $e');
    }
  }

  /// Unregister the current device token from the backend (call on logout).
  Future<void> unregisterToken() async {
    try {
      final token = await _firebaseMessaging?.getToken();
      if (token != null) {
        await ApiClient().dio.post(
          ApiEndpoints.fcmUnregister,
          data: {'token': token},
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('FCM token unregister failed: $e');
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    // Show local notification when app is in foreground
    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'Notifikasi',
      message.notification?.body ?? '',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'kms_connect_channel',
          'KMS Connect Notifications',
          channelDescription: 'Notifications for job applications and updates',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: message.data.toString(),
    );
  }

  void _handleNotificationOpened(RemoteMessage message) {
    if (kDebugMode) debugPrint('Notification opened: ${message.data}');
    _navigateFromNotificationData(message.data);
  }

  void _onNotificationTapped(NotificationResponse response) {
    if (kDebugMode) debugPrint('Notification tapped: ${response.payload}');
    // Navigate to notifications page — payload parsing would require
    // reconstructing the map from toString(), so go to the list page.
    _navigateToNotifications();
  }

  /// Navigate based on notification payload data.
  void _navigateFromNotificationData(Map<String, dynamic> data) {
    final navigatorKey = rootNavigatorKey;
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final type = data['type'] as String?;
    switch (type) {
      case 'job':
        final jobId = data['job_id'];
        if (jobId != null) {
          navigatorKey.currentState?.pushNamed('/jobs/$jobId');
        } else {
          _navigateToNotifications();
        }
      case 'document':
        navigatorKey.currentState?.pushNamed('/documents');
      case 'application':
        navigatorKey.currentState?.pushNamed('/jobs/my-applications');
      default:
        _navigateToNotifications();
    }
  }

  void _navigateToNotifications() {
    rootNavigatorKey.currentState?.pushNamed('/notifications');
  }

  Future<String?> getToken() async {
    return await _firebaseMessaging?.getToken();
  }

  Future<void> subscribeToTopic(String topic) async {
    await _firebaseMessaging?.subscribeToTopic(topic);
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    await _firebaseMessaging?.unsubscribeFromTopic(topic);
  }
}

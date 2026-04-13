import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

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

  /// The Android notification channel used for all push notifications.
  /// Must be created before any notification arrives (Android 8+).
  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
    'kms_connect_channel',
    'KMS Connect Notifications',
    description: 'Notifications for job applications, chat and updates',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

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

    // Create the Android notification channel BEFORE any notifications arrive.
    // This must happen regardless of permission status — when permission is
    // granted later the channel must already exist or FCM notifications
    // targeting it will be silently dropped.
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    // Initialize local notifications (needed for foreground display + tap handling).
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

    // Request OS permission (shows the prompt on iOS; on Android 13+ triggers
    // the POST_NOTIFICATIONS runtime dialog).
    await fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // iOS: tell the OS to show the system banner, badge, and sound even when
    // the app is in the foreground. Without this, iOS silently delivers the
    // message to onMessage but never shows a visible notification.
    await fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Always attach message handlers — even if permission is currently denied
    // the user may grant it later via system settings. Handlers must be ready.
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Background messages are handled by top-level function in main.dart

    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpened);

    // Handle cold-start: if the app was terminated and launched via a
    // notification tap, getInitialMessage() returns that message once.
    final initialMessage = await fcm.getInitialMessage();
    if (initialMessage != null) {
      // Defer until the first frame so [rootNavigatorKey] has a context.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleNotificationOpened(initialMessage);
      });
    }

    // Only register the FCM token if the user is already authenticated.
    // If not logged in, registerToken() will be called after login instead.
    final token = await fcm.getToken();
    if (token != null) {
      if (kDebugMode) debugPrint('FCM Token: $token');
      final authToken = await ApiClient().getAccessToken();
      if (authToken != null) {
        await _registerTokenWithBackend(token);
      } else {
        if (kDebugMode) debugPrint('FCM: skipping backend registration — not logged in yet');
      }
    }

    // Listen for token refresh
    fcm.onTokenRefresh.listen((newToken) {
      if (kDebugMode) debugPrint('New FCM Token: $newToken');
      _registerTokenWithBackend(newToken);
    });
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

  /// Re-register the current device token with the backend.
  /// Call this after every successful login / registration so the token is
  /// always stored while the user is authenticated.
  Future<void> registerToken() async {
    try {
      final token = await _firebaseMessaging?.getToken();
      if (token != null) {
        await _registerTokenWithBackend(token);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('FCM registerToken failed: $e');
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
    // On iOS, setForegroundNotificationPresentationOptions already tells the
    // OS to display the banner for messages that include a notification
    // payload. Showing a local notification on top of that would duplicate it.
    // On Android, the OS does NOT show foreground notifications, so we still
    // need to surface them via flutter_local_notifications.
    if (Platform.isIOS && message.notification != null) return;

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
      payload: jsonEncode(message.data),
    );
  }

  void _handleNotificationOpened(RemoteMessage message) {
    if (kDebugMode) debugPrint('Notification opened: ${message.data}');
    _navigateFromNotificationData(message.data);
  }

  void _onNotificationTapped(NotificationResponse response) {
    if (kDebugMode) debugPrint('Notification tapped: ${response.payload}');
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty) {
      try {
        final data = jsonDecode(payload) as Map<String, dynamic>;
        _navigateFromNotificationData(data);
        return;
      } catch (_) {
        // Payload wasn't valid JSON — fall through to generic page.
      }
    }
    _navigateToNotifications();
  }

  /// Navigate based on notification payload data using GoRouter.
  void _navigateFromNotificationData(Map<String, dynamic> data) {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;

    final router = GoRouter.of(context);

    final rawNotificationId = data['notification_id'];
    if (rawNotificationId != null) {
      final id = int.tryParse(rawNotificationId.toString());
      if (id != null && id > 0) {
        router.push('/notifications/$id');
        return;
      }
    }

    final type = data['type'] as String?;
    switch (type) {
      case 'job':
        final jobId = data['job_id'];
        if (jobId != null) {
          router.push('/jobs/$jobId');
        } else {
          _navigateToNotifications();
        }
      case 'document':
        router.push('/documents');
      case 'application':
        router.push('/jobs/my-applications');
      case 'chat_message':
        final applicationId = data['application_id'];
        if (applicationId != null) {
          router.push('/jobs/applications/$applicationId/chat');
        } else {
          _navigateToNotifications();
        }
      default:
        _navigateToNotifications();
    }
  }

  void _navigateToNotifications() {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    GoRouter.of(context).push('/notifications');
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

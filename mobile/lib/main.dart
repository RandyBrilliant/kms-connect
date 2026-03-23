import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/api/api_client.dart';
import 'features/notifications/data/services/notification_service.dart';
import 'firebase_options.dart';
import 'app.dart';

// Register background message handler (must be top-level)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  if (kDebugMode) debugPrint('Background message: ${message.messageId}');

  // If the message is data-only (no notification payload), show a local
  // notification so the user sees it in the system notification bar.
  // Messages WITH a notification payload are auto-displayed by the OS.
  if (message.notification == null && message.data.isNotEmpty) {
    final plugin = FlutterLocalNotificationsPlugin();

    // Ensure the channel exists (idempotent on Android 8+).
    await plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          'kms_connect_channel',
          'KMS Connect Notifications',
          description: 'Notifications for job applications, chat and updates',
          importance: Importance.high,
        ));

    final title = message.data['title'] ?? 'KMS Connect';
    final body = message.data['body'] ?? 'Anda memiliki pesan baru';

    await plugin.show(
      message.hashCode,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'kms_connect_channel',
          'KMS Connect Notifications',
          channelDescription: 'Notifications for job applications, chat and updates',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: message.data.containsKey('type')
          ? jsonEncode(message.data)
          : null,
    );
  }
}

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  // Keep the native splash screen visible while we initialise.
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Prevent google_fonts from downloading fonts at runtime.
  // Fonts are resolved from the theme's textTheme which is cached as a static
  // final — this flag avoids network fetches that cause first-render jank.
  GoogleFonts.config.allowRuntimeFetching = false;

  // Limit the Flutter image cache to prevent excessive memory usage when
  // users scroll through long lists of job/news cards with images.
  // Default is 1000 images / 100 MB — reduced for mobile.
  PaintingBinding.instance.imageCache.maximumSizeBytes = 50 * 1024 * 1024; // 50 MB
  PaintingBinding.instance.imageCache.maximumSize = 200; // max 200 decoded images

  // Initialize locale data for intl date formatting (e.g. 'id_ID')
  await initializeDateFormatting('id_ID', null);

  // Load environment variables
  await dotenv.load(fileName: '.env');

  // Initialize API client before Firebase / notifications — FCM registration calls Dio.
  await ApiClient().initialize();

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Register background message handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    // Initialize notifications
    await NotificationService().initialize();
  } catch (e) {
    if (kDebugMode) debugPrint('Firebase initialization failed: $e');
    // Continue without Firebase if initialization fails
  }

  // All heavy init is done — remove the native splash.
  FlutterNativeSplash.remove();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // A single MaterialApp.router is created inside App().
    // Do NOT wrap it in another MaterialApp here — that creates
    // duplicate Navigators/Overlays and breaks toast visibility.
    return const App();
  }
}

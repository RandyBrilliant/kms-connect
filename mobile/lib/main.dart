import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Prevent google_fonts from downloading fonts at runtime.
  // Fonts are resolved from the theme's textTheme which is cached as a static
  // final — this flag avoids network fetches that cause first-render jank.
  GoogleFonts.config.allowRuntimeFetching = false;

  // Initialize locale data for intl date formatting (e.g. 'id_ID')
  await initializeDateFormatting('id_ID', null);

  // Load environment variables
  await dotenv.load(fileName: '.env');

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

  // Initialize API client
  await ApiClient().initialize();

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

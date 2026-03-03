import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks the app lifecycle state (foreground / background / inactive).
///
/// Useful for pausing polling, timers, and other resource-intensive work
/// when the app is not visible. Prevents unnecessary battery drain and
/// network usage for thousands of concurrent users.
///
/// Usage:
/// ```dart
/// final lifecycle = ref.watch(appLifecycleProvider);
/// if (lifecycle == AppLifecycleState.resumed) {
///   // App is in foreground — safe to poll
/// }
/// ```
final appLifecycleProvider =
    StateNotifierProvider<AppLifecycleNotifier, AppLifecycleState>(
  (ref) => AppLifecycleNotifier(),
);

class AppLifecycleNotifier extends StateNotifier<AppLifecycleState>
    with WidgetsBindingObserver {
  AppLifecycleNotifier() : super(AppLifecycleState.resumed) {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    this.state = state;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

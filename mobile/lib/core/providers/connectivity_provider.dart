import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Emits `true` when the device has an active connection, `false` when offline.
///
/// Uses [connectivity_plus] to detect changes. Note: this checks for network
/// interface availability, not actual internet reachability (which would
/// require a ping/DNS check that's too expensive for continuous monitoring).
///
/// Usage:
/// ```dart
/// final isOnline = ref.watch(connectivityProvider);
/// if (!isOnline) showOfflineBanner();
/// ```
final connectivityProvider = StateNotifierProvider<ConnectivityNotifier, bool>(
  (ref) => ConnectivityNotifier(),
);

class ConnectivityNotifier extends StateNotifier<bool> {
  late final StreamSubscription<List<ConnectivityResult>> _sub;

  ConnectivityNotifier() : super(true) {
    _init();
  }

  Future<void> _init() async {
    // Check current status
    final result = await Connectivity().checkConnectivity();
    state = !result.contains(ConnectivityResult.none);

    // Listen for changes
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      state = !results.contains(ConnectivityResult.none);
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

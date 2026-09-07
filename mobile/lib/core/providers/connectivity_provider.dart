import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// True when [results] include any non-[ConnectivityResult.none] interface.
@visibleForTesting
bool isOnlineFromResults(List<ConnectivityResult> results) {
  return !results.contains(ConnectivityResult.none);
}

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
  StreamSubscription<List<ConnectivityResult>>? _sub;
  final Connectivity _connectivity;

  ConnectivityNotifier({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity(),
        super(true) {
    try {
      _sub = _connectivity.onConnectivityChanged.listen((results) {
        if (!mounted) return;
        state = isOnlineFromResults(results);
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Connectivity listen failed: $e');
    }
    unawaited(_prime());
  }

  Future<void> _prime() async {
    try {
      final result = await _connectivity.checkConnectivity();
      if (!mounted) return;
      state = isOnlineFromResults(result);
    } catch (e) {
      if (kDebugMode) debugPrint('Connectivity check failed: $e');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

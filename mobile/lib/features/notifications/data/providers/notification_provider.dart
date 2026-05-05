import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/app_notification.dart';
import '../repositories/notification_repository.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository();
});

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class NotificationState {
  final List<AppNotification> notifications;
  final bool isLoading;
  final String? error;

  const NotificationState({
    this.notifications = const [],
    this.isLoading = false,
    this.error,
  });

  int get unreadCount => notifications.where((n) => !n.isRead).length;

  NotificationState copyWith({
    List<AppNotification>? notifications,
    bool? isLoading,
    String? error,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class NotificationNotifier extends StateNotifier<NotificationState> {
  /// Delay before calling DELETE so the user can undo from the snackbar.
  static const Duration deleteUndoDuration = Duration(seconds: 4);

  final NotificationRepository _repository;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedAppSub;

  final Map<int, Timer> _pendingDeleteTimers = {};
  final Map<int, AppNotification> _pendingDeleteSnapshot = {};
  final Map<int, int> _pendingDeleteIndex = {};

  NotificationNotifier(this._repository) : super(const NotificationState()) {
    load();
    _subscribeToFcm();
  }

  /// Listen for incoming FCM messages so the notification list stays up-to-date
  /// in real-time without the user having to manually refresh.
  void _subscribeToFcm() {
    // Foreground: app is open — new notification arrives → reload list
    _foregroundSub = FirebaseMessaging.onMessage.listen((_) => load());
    // Background/terminated: user taps notification to open app → reload list
    _openedAppSub = FirebaseMessaging.onMessageOpenedApp.listen((_) => load());
  }

  @override
  void dispose() {
    _foregroundSub?.cancel();
    _openedAppSub?.cancel();
    for (final t in _pendingDeleteTimers.values) {
      t.cancel();
    }
    _pendingDeleteTimers.clear();
    if (_pendingDeleteSnapshot.isNotEmpty) {
      var merged = List<AppNotification>.from(state.notifications);
      merged.addAll(_pendingDeleteSnapshot.values);
      merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      state = state.copyWith(notifications: merged);
    }
    _pendingDeleteSnapshot.clear();
    _pendingDeleteIndex.clear();
    super.dispose();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final items = await _repository.getNotifications();
      state = state.copyWith(notifications: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('DioException: ', ''),
      );
    }
  }

  Future<void> markRead(int id) async {
    try {
      final updated = await _repository.markRead(id);
      state = state.copyWith(
        notifications: state.notifications
            .map((n) => n.id == id ? updated : n)
            .toList(),
      );
    } catch (e) {
      // Keep optimistic UI but trigger reload so persisted status stays accurate.
      state = state.copyWith(
        notifications: state.notifications
            .map((n) => n.id == id ? n.copyWith(isRead: true) : n)
            .toList(),
        error: e.toString().replaceAll('DioException: ', ''),
      );
      unawaited(load());
    }
  }

  Future<void> markAllRead() async {
    try {
      await _repository.markAllRead();
      state = state.copyWith(
        notifications: state.notifications
            .map((n) => n.copyWith(isRead: true))
            .toList(),
      );
    } catch (_) {
      // Optimistic update
      state = state.copyWith(
        notifications: state.notifications
            .map((n) => n.copyWith(isRead: true))
            .toList(),
      );
    }
  }

  /// Removes the item immediately; server DELETE runs after [deleteUndoDuration]
  /// unless [cancelPendingDelete] is called (undo).
  void queueDeleteNotification(int id) {
    final list = List<AppNotification>.from(state.notifications);
    final index = list.indexWhere((n) => n.id == id);
    if (index < 0) return;

    _pendingDeleteTimers[id]?.cancel();
    _pendingDeleteSnapshot[id] = list[index];
    _pendingDeleteIndex[id] = index;

    list.removeAt(index);
    state = state.copyWith(notifications: list, error: null);

    _pendingDeleteTimers[id] = Timer(deleteUndoDuration, () {
      _pendingDeleteTimers.remove(id);
      final snap = _pendingDeleteSnapshot.remove(id);
      _pendingDeleteIndex.remove(id);
      if (snap == null) return;
      unawaited(_commitServerDelete(id, snap));
    });
  }

  void cancelPendingDelete(int id) {
    _pendingDeleteTimers[id]?.cancel();
    _pendingDeleteTimers.remove(id);
    final snap = _pendingDeleteSnapshot.remove(id);
    final savedIndex = _pendingDeleteIndex.remove(id);
    if (snap == null || savedIndex == null) return;

    final list = List<AppNotification>.from(state.notifications);
    final safe = savedIndex.clamp(0, list.length);
    list.insert(safe, snap);
    state = state.copyWith(notifications: list);
  }

  Future<void> _commitServerDelete(int id, AppNotification fallbackSnapshot) async {
    try {
      await _repository.deleteNotification(id);
    } catch (e) {
      final list = List<AppNotification>.from(state.notifications);
      list.add(fallbackSnapshot);
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      state = state.copyWith(
        notifications: list,
        error: e.toString().replaceAll('DioException: ', ''),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  return NotificationNotifier(ref.read(notificationRepositoryProvider));
});

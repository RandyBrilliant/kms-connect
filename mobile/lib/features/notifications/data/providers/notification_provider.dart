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
  final NotificationRepository _repository;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedAppSub;

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
    } catch (_) {
      // Optimistic update even on failure — silently ignore network errors.
      state = state.copyWith(
        notifications: state.notifications
            .map((n) => n.id == id ? n.copyWith(isRead: true) : n)
            .toList(),
      );
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
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  return NotificationNotifier(ref.read(notificationRepositoryProvider));
});

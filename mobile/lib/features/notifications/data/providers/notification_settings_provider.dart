import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/notification_settings_service.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/// Immutable snapshot of the notification-settings UI state.
class NotificationSettingsState {
  /// Whether the user has enabled push notifications in-app.
  final bool isEnabled;

  /// Whether the OS permission has been granted.
  final bool osPermissionGranted;

  /// True while an async operation (enable/disable) is in progress.
  final bool isLoading;

  /// Non-null when the last operation produced an error message.
  final String? error;

  const NotificationSettingsState({
    required this.isEnabled,
    required this.osPermissionGranted,
    this.isLoading = false,
    this.error,
  });

  NotificationSettingsState copyWith({
    bool? isEnabled,
    bool? osPermissionGranted,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return NotificationSettingsState(
      isEnabled: isEnabled ?? this.isEnabled,
      osPermissionGranted: osPermissionGranted ?? this.osPermissionGranted,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class NotificationSettingsNotifier
    extends StateNotifier<NotificationSettingsState> {
  final NotificationSettingsService _service;

  NotificationSettingsNotifier(this._service)
      : super(const NotificationSettingsState(
          isEnabled: true,
          osPermissionGranted: true,
        )) {
    _init();
  }

  Future<void> _init() async {
    final enabled = await _service.isEnabled();
    final osGranted = await _service.isOsPermissionGranted();
    if (mounted) {
      state = state.copyWith(
        isEnabled: enabled,
        osPermissionGranted: osGranted,
        clearError: true,
      );
    }
  }

  /// Refresh the OS-permission status (e.g., after user returns from Settings).
  Future<void> refreshOsPermission() async {
    final osGranted = await _service.isOsPermissionGranted();
    if (mounted) {
      state = state.copyWith(osPermissionGranted: osGranted, clearError: true);
    }
  }

  /// Toggle push notifications on / off.
  ///
  /// Returns [EnableResult?]: null when disabling, [EnableResult] when enabling.
  Future<EnableResult?> toggle() async {
    state = state.copyWith(isLoading: true, clearError: true);

    if (state.isEnabled) {
      // Currently ON → turn OFF.
      await _service.disable();
      if (mounted) {
        state = state.copyWith(
          isEnabled: false,
          isLoading: false,
          clearError: true,
        );
      }
      return null;
    } else {
      // Currently OFF → turn ON.
      final result = await _service.enable();
      final osGranted = await _service.isOsPermissionGranted();
      if (mounted) {
        state = state.copyWith(
          isEnabled: result == EnableResult.success,
          osPermissionGranted: osGranted,
          isLoading: false,
          error: result == EnableResult.permissionDenied
              ? 'Izin notifikasi ditolak. Buka Pengaturan > Notifikasi untuk mengaktifkan.'
              : null,
        );
      }
      return result;
    }
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final notificationSettingsServiceProvider =
    Provider<NotificationSettingsService>((_) => NotificationSettingsService());

final notificationSettingsProvider = StateNotifierProvider<
    NotificationSettingsNotifier, NotificationSettingsState>(
  (ref) => NotificationSettingsNotifier(
    ref.read(notificationSettingsServiceProvider),
  ),
);

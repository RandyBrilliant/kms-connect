import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/chat_message.dart';
import '../../domain/models/chat_thread_preview.dart';
import '../repositories/chat_repository.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository();
});

// ---------------------------------------------------------------------------
// Per-thread message provider (used by ChatThreadPage)
// ---------------------------------------------------------------------------

final chatMessagesProvider =
    FutureProvider.autoDispose.family<List<ChatMessage>, int>(
  (ref, applicationId) async {
    final repository = ref.read(chatRepositoryProvider);
    return repository.getMessages(applicationId);
  },
);

// ---------------------------------------------------------------------------
// Chat inbox state
// ---------------------------------------------------------------------------

class ChatInboxState {
  final List<ChatThreadPreview> threads;
  final bool isLoading;
  final String? error;

  const ChatInboxState({
    this.threads = const [],
    this.isLoading = false,
    this.error,
  });

  /// Total unread message count across all threads.
  int get totalUnread =>
      threads.fold(0, (sum, t) => sum + t.unreadCount);

  ChatInboxState copyWith({
    List<ChatThreadPreview>? threads,
    bool? isLoading,
    String? error,
  }) {
    return ChatInboxState(
      threads: threads ?? this.threads,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ---------------------------------------------------------------------------
// Chat inbox notifier
// ---------------------------------------------------------------------------

class ChatInboxNotifier extends StateNotifier<ChatInboxState> {
  final ChatRepository _repository;

  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedAppSub;

  ChatInboxNotifier(this._repository) : super(const ChatInboxState()) {
    load();
    _subscribeToFcm();
  }

  /// Subscribe to FCM events so the inbox refreshes automatically when a
  /// new chat message push arrives — no manual pull-to-refresh required.
  void _subscribeToFcm() {
    _foregroundSub = FirebaseMessaging.onMessage.listen((msg) {
      if (msg.data['type'] == 'chat_message') load();
    });
    _openedAppSub = FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      if (msg.data['type'] == 'chat_message') load();
    });
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
      final threads = await _repository.getThreads();
      state = state.copyWith(threads: threads, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('DioException: ', ''),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final chatInboxProvider =
    StateNotifierProvider<ChatInboxNotifier, ChatInboxState>((ref) {
  return ChatInboxNotifier(ref.read(chatRepositoryProvider));
});

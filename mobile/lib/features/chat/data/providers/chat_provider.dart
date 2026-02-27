import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/chat_message.dart';
import '../repositories/chat_repository.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository();
});

final chatMessagesProvider =
    FutureProvider.autoDispose.family<List<ChatMessage>, int>(
  (ref, applicationId) async {
    final repository = ref.read(chatRepositoryProvider);
    return repository.getMessages(applicationId);
  },
);

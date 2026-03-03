import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../config/colors.dart';
import '../../../../core/providers/app_lifecycle_provider.dart';
import '../../../../core/services/chat_websocket_service.dart';
import '../../../../core/widgets/custom_toast.dart';
import '../../data/providers/chat_provider.dart';
import '../../domain/models/chat_message.dart';

class ChatThreadPage extends ConsumerStatefulWidget {
  const ChatThreadPage({super.key, required this.applicationId});

  final int applicationId;

  @override
  ConsumerState<ChatThreadPage> createState() => _ChatThreadPageState();
}

class _ChatThreadPageState extends ConsumerState<ChatThreadPage> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _isSending = false;

  // WebSocket
  ChatWebSocketService? _ws;
  StreamSubscription<ChatWsEvent>? _wsSub;

  // Typing indicator
  String? _typingUserName;
  Timer? _typingTimer;

  // Debounce outgoing typing events
  Timer? _outgoingTypingTimer;

  // Local messages list (populated from initial REST fetch + WS updates)
  List<ChatMessage> _messages = [];
  bool _initialLoaded = false;

  @override
  void initState() {
    super.initState();

    // Mark as read immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(chatRepositoryProvider)
          .markAsRead(widget.applicationId)
          .ignore();
    });

    _connectWebSocket();
  }

  void _connectWebSocket() {
    _ws = ChatWebSocketService(threadId: widget.applicationId);
    _wsSub = _ws!.events.listen(_onWsEvent);
    _ws!.connect();
  }

  void _onWsEvent(ChatWsEvent event) {
    if (!mounted) return;

    switch (event) {
      case ChatWsNewMessage(:final message):
        // Avoid duplicates (e.g. own message already added optimistically)
        final exists = _messages.any((m) => m.id == message.id);
        if (!exists) {
          setState(() {
            _messages = [..._messages, message];
          });
          // Clear typing indicator when a message arrives
          _clearTyping();
          Future.delayed(const Duration(milliseconds: 150), _scrollToBottom);

          // Auto mark as read if the message is from the other side
          if (message.senderRole != 'APPLICANT') {
            _ws?.sendMarkRead();
          }
        }

      case ChatWsTyping(:final userName):
        setState(() => _typingUserName = userName);
        _typingTimer?.cancel();
        _typingTimer = Timer(const Duration(seconds: 3), _clearTyping);

      case ChatWsRead():
        // Update read status on messages sent by us
        setState(() {
          _messages = _messages.map((m) {
            if (m.senderRole == 'APPLICANT' && !m.isRead) {
              return ChatMessage(
                id: m.id,
                thread: m.thread,
                sender: m.sender,
                senderName: m.senderName,
                senderRole: m.senderRole,
                body: m.body,
                sentAt: m.sentAt,
                isRead: true,
                readAt: DateTime.now(),
              );
            }
            return m;
          }).toList();
        });

      case ChatWsConnectionState(:final connected):
        if (connected) {
          // Re-fetch messages on reconnect to catch anything missed
          ref.invalidate(chatMessagesProvider(widget.applicationId));
        }
    }
  }

  void _clearTyping() {
    if (mounted) {
      setState(() => _typingUserName = null);
    }
  }

  /// Called when the user types — sends typing indicator with debounce.
  void _onTextChanged() {
    if (_outgoingTypingTimer?.isActive ?? false) return;
    _ws?.sendTyping();
    _outgoingTypingTimer = Timer(const Duration(seconds: 2), () {});
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _ws?.dispose();
    _typingTimer?.cancel();
    _outgoingTypingTimer?.cancel();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _textCtrl.text.trim();
    if (body.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    try {
      final msg = await ref
          .read(chatRepositoryProvider)
          .sendMessage(widget.applicationId, body);
      _textCtrl.clear();

      // Add sent message to local list (WS will also deliver it but dedup handles it)
      final exists = _messages.any((m) => m.id == msg.id);
      if (!exists) {
        setState(() {
          _messages = [..._messages, msg];
        });
      }

      await Future.delayed(const Duration(milliseconds: 250));
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        CustomToast.show(
          context,
          title: 'Gagal mengirim',
          message: e.toString(),
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync =
        ref.watch(chatMessagesProvider(widget.applicationId));
    final cs = Theme.of(context).colorScheme;

    // Populate local messages from initial REST fetch
    ref.listen(chatMessagesProvider(widget.applicationId), (_, next) {
      next.whenData((data) {
        if (!_initialLoaded || data.length > _messages.length) {
          setState(() {
            _messages = data;
            _initialLoaded = true;
          });
          Future.delayed(const Duration(milliseconds: 150), _scrollToBottom);
        }
      });
    });

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDarkGreen,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chat dengan Admin',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            if (_typingUserName != null)
              Text('$_typingUserName sedang mengetik...',
                  style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white70,
                      fontStyle: FontStyle.italic))
            else
              const Text('Pesan akan dibalas secepatnya',
                  style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          // ── Message list ─────────────────────────────────────────
          Expanded(
            child: _initialLoaded
                ? _buildMessageList(cs)
                : messagesAsync.when(
                    data: (_) => _buildMessageList(cs),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => Center(
                      child: Text(
                        '$error',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
          ),

          // ── Input bar ────────────────────────────────────────────
          _InputBar(
            controller: _textCtrl,
            isSending: _isSending,
            onSend: _send,
            onChanged: _onTextChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(ColorScheme cs) {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline_rounded,
                size: 56,
                color: cs.onSurfaceVariant.withValues(alpha: 0.35)),
            const SizedBox(height: 12),
            Text(
              'Belum ada pesan',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Text(
              'Mulailah percakapan di bawah',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final isMine = msg.senderRole == 'APPLICANT';

        // Show date header when date changes
        final showDate = index == 0 ||
            !_isSameDay(
              _messages[index - 1].sentAt,
              msg.sentAt,
            );

        return Column(
          children: [
            if (showDate) _DateDivider(date: msg.sentAt),
            _MessageBubble(message: msg, isMine: isMine),
          ],
        );
      },
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ─────────────────────────────────────────────────────────────────────────────
// Date divider
// ─────────────────────────────────────────────────────────────────────────────

class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    String label;
    final d = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    if (d == today) {
      label = 'Hari ini';
    } else if (d == today.subtract(const Duration(days: 1))) {
      label = 'Kemarin';
    } else {
      label = DateFormat('d MMMM yyyy', 'id_ID').format(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(child: Divider(color: cs.outlineVariant)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(child: Divider(color: cs.outlineVariant)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Message bubble
// ─────────────────────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMine});

  final ChatMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final timeFmt = DateFormat('HH:mm', 'id_ID');

    final bgColor = isMine
        ? AppColors.primaryDarkGreen
        : cs.surfaceContainerHighest;
    final textColor = isMine ? Colors.white : cs.onSurface;
    final timeColor =
        isMine ? Colors.white.withValues(alpha: 0.7) : cs.onSurfaceVariant;

    const radius = Radius.circular(16);
    final borderRadius = isMine
        ? const BorderRadius.only(
            topLeft: radius,
            topRight: radius,
            bottomLeft: radius,
            bottomRight: Radius.circular(4),
          )
        : const BorderRadius.only(
            topLeft: radius,
            topRight: radius,
            bottomLeft: Radius.circular(4),
            bottomRight: radius,
          );

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: borderRadius,
          ),
          child: Column(
            crossAxisAlignment:
                isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isMine)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    message.senderName,
                    style: tt.labelSmall?.copyWith(
                      color: AppColors.primaryDarkGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              Text(
                message.body,
                style: tt.bodyMedium?.copyWith(color: textColor),
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timeFmt.format(message.sentAt.toLocal()),
                    style: tt.labelSmall?.copyWith(
                      color: timeColor,
                      fontSize: 10,
                    ),
                  ),
                  if (isMine) ...[
                    const SizedBox(width: 4),
                    Icon(
                      message.isRead
                          ? Icons.done_all_rounded
                          : Icons.done_rounded,
                      size: 13,
                      color: timeColor,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Input bar
// ─────────────────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.isSending,
    required this.onSend,
    this.onChanged,
  });

  final TextEditingController controller;
  final bool isSending;
  final Future<void> Function() onSend;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      padding: EdgeInsets.fromLTRB(
          12, 8, 12, 8 + MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.multiline,
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => onChanged?.call(),
                decoration: InputDecoration(
                  hintText: 'Tulis pesan…',
                  hintStyle: TextStyle(color: cs.onSurfaceVariant),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  filled: true,
                  fillColor: cs.surfaceContainerLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                        color: AppColors.primaryDarkGreen, width: 1.5),
                  ),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),
            isSending
                ? const SizedBox(
                    width: 42,
                    height: 42,
                    child: Padding(
                      padding: EdgeInsets.all(9),
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  )
                : IconButton.filled(
                    onPressed: onSend,
                    icon: const Icon(Icons.send_rounded, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primaryDarkGreen,
                      foregroundColor: Colors.white,
                      fixedSize: const Size(42, 42),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

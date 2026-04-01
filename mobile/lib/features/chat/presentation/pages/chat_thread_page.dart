import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../config/colors.dart';
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
          _scheduleScrollToBottom();

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
      if (!mounted) return;
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
    if (!mounted || !_scrollCtrl.hasClients) return;
    _scrollCtrl.animateTo(
      _scrollCtrl.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _scheduleScrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      _scrollToBottom();
    });
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
          _scheduleScrollToBottom();
        }
      });
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textDark),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chat dengan Admin',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            if (_typingUserName != null)
              Text(
                '$_typingUserName sedang mengetik…',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primaryDarkGreen,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              Text(
                'Pesan akan dibalas secepatnya',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMedium,
                ),
              ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            color: cs.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Message list ─────────────────────────────────────────
          Expanded(
            child: _initialLoaded
                ? _buildMessageList(cs)
                : messagesAsync.when(
                    data: (_) => _buildMessageList(cs),
                    loading: () => const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryDarkGreen,
                        strokeWidth: 2.5,
                      ),
                    ),
                    error: (error, _) => Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.divider.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            '$error',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textMedium,
                            ),
                          ),
                        ),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.divider.withValues(alpha: 0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 48,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.32),
                ),
                const SizedBox(height: 14),
                Text(
                  'Belum ada pesan',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Mulailah percakapan di bawah',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMedium,
                  ),
                ),
              ],
            ),
          ),
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
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textMedium,
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
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: AppColors.primaryDarkGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              Text(
                message.body,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timeFmt.format(message.sentAt.toLocal()),
                    style: GoogleFonts.plusJakartaSans(
                      color: timeColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
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
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, 10 + MediaQuery.of(context).viewInsets.bottom),
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
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDark,
                ),
                onChanged: (_) => onChanged?.call(),
                decoration: InputDecoration(
                  hintText: 'Tulis pesan…',
                  hintStyle: GoogleFonts.plusJakartaSans(
                    color: AppColors.textMedium,
                    fontWeight: FontWeight.w500,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: AppColors.divider.withValues(alpha: 0.45),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: AppColors.divider.withValues(alpha: 0.45),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: AppColors.primaryDarkGreen,
                      width: 1.5,
                    ),
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
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.primaryDarkGreen,
                      ),
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

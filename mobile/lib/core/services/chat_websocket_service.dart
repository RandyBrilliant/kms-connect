import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../config/env.dart';
import '../../../core/api/api_client.dart';
import '../../features/chat/domain/models/chat_message.dart';

/// Events emitted by [ChatWebSocketService].
sealed class ChatWsEvent {
  const ChatWsEvent();
}

/// A new message was received via WebSocket.
class ChatWsNewMessage extends ChatWsEvent {
  final ChatMessage message;
  const ChatWsNewMessage(this.message);
}

/// A remote user is typing.
class ChatWsTyping extends ChatWsEvent {
  final int userId;
  final String userName;
  const ChatWsTyping({required this.userId, required this.userName});
}

/// A remote user read messages.
class ChatWsRead extends ChatWsEvent {
  final int userId;
  final String readAt;
  const ChatWsRead({required this.userId, required this.readAt});
}

/// WebSocket connection state changed.
class ChatWsConnectionState extends ChatWsEvent {
  final bool connected;
  const ChatWsConnectionState(this.connected);
}

/// Manages a single WebSocket connection to a chat thread.
///
/// Usage:
/// ```dart
/// final ws = ChatWebSocketService(threadId: 42);
/// await ws.connect();
/// ws.events.listen((event) { ... });
/// ws.sendTyping();
/// ws.dispose();
/// ```
class ChatWebSocketService {
  final int threadId;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  Timer? _pingTimer;

  final _eventController = StreamController<ChatWsEvent>.broadcast();
  Stream<ChatWsEvent> get events => _eventController.stream;

  bool _disposed = false;
  bool _connected = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;
  static const Duration _pingInterval = Duration(seconds: 30);

  ChatWebSocketService({required this.threadId});

  static const String _wsAuthProtocol = 'kms-auth';

  /// WebSocket URL without credentials (JWT is sent via subprotocol, not query).
  String get _wsUrl {
    final httpBase = Env.apiBaseUrl;
    final wsScheme = httpBase.startsWith('https') ? 'wss' : 'ws';
    final authority = httpBase
        .replaceFirst('https://', '')
        .replaceFirst('http://', '');
    return '$wsScheme://$authority/ws/chat/$threadId/';
  }

  /// Connect to the WebSocket server.
  Future<void> connect() async {
    if (_disposed) return;

    final token = await ApiClient().getAccessToken();
    if (token == null || token.isEmpty) {
      debugPrint('[ChatWS] No access token — cannot connect');
      return;
    }

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse(_wsUrl),
        protocols: [_wsAuthProtocol, token],
      );

      // Wait for the connection to be established
      await _channel!.ready;

      _connected = true;
      _reconnectAttempts = 0;
      _eventController.add(const ChatWsConnectionState(true));

      _startPing();

      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );

      debugPrint('[ChatWS] Connected to thread $threadId');
    } catch (e) {
      debugPrint('[ChatWS] Connection failed: $e');
      _connected = false;
      _eventController.add(const ChatWsConnectionState(false));
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic rawData) {
    try {
      final data = jsonDecode(rawData as String) as Map<String, dynamic>;
      final type = data['type'] as String?;

      switch (type) {
        case 'chat.message':
          final msgData = data['message'] as Map<String, dynamic>;
          final msg = ChatMessage.fromJson(msgData);
          _eventController.add(ChatWsNewMessage(msg));

        case 'chat.typing':
          _eventController.add(ChatWsTyping(
            userId: data['user_id'] as int,
            userName: (data['user_name'] ?? '') as String,
          ));

        case 'chat.read':
          _eventController.add(ChatWsRead(
            userId: data['user_id'] as int,
            readAt: (data['read_at'] ?? '') as String,
          ));

        default:
          debugPrint('[ChatWS] Unknown event type: $type');
      }
    } catch (e) {
      debugPrint('[ChatWS] Parse error: $e');
    }
  }

  void _onError(Object error) {
    debugPrint('[ChatWS] Error: $error');
    _connected = false;
    _eventController.add(const ChatWsConnectionState(false));
  }

  void _onDone() {
    debugPrint('[ChatWS] Connection closed');
    _connected = false;
    _eventController.add(const ChatWsConnectionState(false));
    _stopPing();
    if (!_disposed) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_disposed || _reconnectAttempts >= _maxReconnectAttempts) return;

    _reconnectAttempts++;
    // Exponential backoff: 1s, 2s, 4s, 8s... capped at 30s
    final delay = Duration(
      seconds: (1 << (_reconnectAttempts - 1)).clamp(1, 30),
    );

    debugPrint(
      '[ChatWS] Reconnecting in ${delay.inSeconds}s '
      '(attempt $_reconnectAttempts/$_maxReconnectAttempts)',
    );

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (!_disposed) connect();
    });
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(_pingInterval, (_) {
      if (_connected && _channel != null) {
        try {
          _channel!.sink.add(jsonEncode({'type': 'ping'}));
        } catch (_) {}
      }
    });
  }

  void _stopPing() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  /// Send a typing indicator to the server.
  void sendTyping() {
    if (!_connected || _channel == null) return;
    try {
      _channel!.sink.add(jsonEncode({'type': 'typing'}));
    } catch (_) {}
  }

  /// Send a mark_read event to the server.
  void sendMarkRead() {
    if (!_connected || _channel == null) return;
    try {
      _channel!.sink.add(jsonEncode({'type': 'mark_read'}));
    } catch (_) {}
  }

  /// Whether the WebSocket is currently connected.
  bool get isConnected => _connected;

  /// Disconnect and clean up resources.
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _stopPing();
    _subscription?.cancel();
    _channel?.sink.close();
    _eventController.close();
  }
}

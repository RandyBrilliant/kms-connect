import 'package:dio/dio.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/endpoints.dart';
import '../../domain/models/chat_message.dart';
import '../../domain/models/chat_thread_preview.dart';

class ChatRepository {
  final ApiClient _apiClient = ApiClient();

  /// GET /api/chat/applicant/threads/
  ///
  /// Returns all chat threads for the current applicant, ordered by most
  /// recently updated. Used to populate the Chat inbox screen.
  Future<List<ChatThreadPreview>> getThreads() async {
    try {
      final response = await _apiClient.dio.get(ApiEndpoints.chatThreads);
      final data = response.data;
      if (data is Map<String, dynamic> && data['data'] is List) {
        return (data['data'] as List)
            .map((e) => ChatThreadPreview.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      if (data is List) {
        return data
            .map((e) => ChatThreadPreview.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// GET /api/chat/applicant/thread/{applicationId}/messages/?since=<ISO>&page=<int>
  ///
  /// Handles both the new paginated format `{data: {messages: [...], total, has_more}}`
  /// and the legacy flat `{data: [...]}` format for backward compatibility.
  Future<List<ChatMessage>> getMessages(
    int applicationId, {
    String? since,
    int? page,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (since != null && since.isNotEmpty) {
        queryParams['since'] = since;
      }
      if (page != null) {
        queryParams['page'] = page;
      }

      final response = await _apiClient.dio.get(
        ApiEndpoints.chatMessages(applicationId),
        queryParameters: queryParams,
      );

      final data = response.data;

      // New paginated format: {code, data: {messages: [...], total, has_more}}
      if (data is Map<String, dynamic> &&
          data['data'] is Map<String, dynamic>) {
        final inner = data['data'] as Map<String, dynamic>;
        if (inner.containsKey('messages') && inner['messages'] is List) {
          return (inner['messages'] as List)
              .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }

      // Legacy: {data: [...]}
      if (data is Map<String, dynamic> && data['data'] is List) {
        return (data['data'] as List)
            .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      if (data is List) {
        return data
            .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// POST /api/chat/applicant/thread/{applicationId}/send/
  Future<ChatMessage> sendMessage(int applicationId, String body) async {
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.chatSend(applicationId),
        data: {'body': body},
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        // May be a direct message object or wrapped in {data: ...}
        if (data.containsKey('id')) {
          return ChatMessage.fromJson(data);
        }
        if (data['data'] is Map<String, dynamic>) {
          return ChatMessage.fromJson(data['data'] as Map<String, dynamic>);
        }
      }
      throw DioException(
        requestOptions: response.requestOptions,
        message: 'Gagal mengirim pesan',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// POST /api/chat/applicant/thread/{applicationId}/mark-read/
  Future<void> markAsRead(int applicationId) async {
    try {
      await _apiClient.dio.post(ApiEndpoints.chatMarkRead(applicationId));
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  DioException _handleError(DioException error) {
    if (error.response != null) {
      final data = error.response!.data;
      if (data is Map<String, dynamic>) {
        final detail = data['detail'] as String?;
        if (detail != null) {
          return DioException(
            requestOptions: error.requestOptions,
            response: error.response,
            type: error.type,
            message: detail,
          );
        }
      }
    }
    return error;
  }
}

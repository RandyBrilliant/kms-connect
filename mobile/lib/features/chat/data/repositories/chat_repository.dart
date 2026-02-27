import 'package:dio/dio.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/endpoints.dart';
import '../../domain/models/chat_message.dart';

class ChatRepository {
  final ApiClient _apiClient = ApiClient();

  /// GET /api/chat/applicant/thread/{applicationId}/messages/?since=<ISO>
  Future<List<ChatMessage>> getMessages(
    int applicationId, {
    String? since,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (since != null && since.isNotEmpty) {
        queryParams['since'] = since;
      }

      final response = await _apiClient.dio.get(
        ApiEndpoints.chatMessages(applicationId),
        queryParameters: queryParams,
      );

      final data = response.data;
      // Backend returns {"data": [...]}
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

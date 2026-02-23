import 'package:dio/dio.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/endpoints.dart';
import '../../../../core/models/api_response.dart';
import '../../domain/models/app_notification.dart';

class NotificationRepository {
  final ApiClient _apiClient = ApiClient();

  /// Fetch all notifications for the current user (newest first).
  Future<List<AppNotification>> getNotifications() async {
    try {
      final response = await _apiClient.dio.get(ApiEndpoints.notifications);

      // The backend may return a paginated object or a plain list wrapped in
      // ApiResponse. Handle both gracefully.
      final raw = response.data;
      List<dynamic> items;

      if (raw is Map<String, dynamic>) {
        // Standard ApiResponse wrapper: { code, data: [...] }
        if (raw['data'] is List) {
          items = raw['data'] as List<dynamic>;
        } else if (raw['results'] is List) {
          // DRF pagination fallback
          items = raw['results'] as List<dynamic>;
        } else {
          items = [];
        }
      } else if (raw is List) {
        items = raw;
      } else {
        items = [];
      }

      return items
          .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Mark a single notification as read.
  Future<AppNotification> markRead(int id) async {
    try {
      final response = await _apiClient.dio.patch(
        ApiEndpoints.markNotificationRead(id),
      );

      final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );

      return AppNotification.fromJson(apiResponse.data!);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Mark all unread notifications as read.
  Future<void> markAllRead() async {
    try {
      await _apiClient.dio.post(ApiEndpoints.markAllNotificationsRead);
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

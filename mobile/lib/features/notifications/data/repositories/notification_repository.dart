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

  /// Fetch a single notification by id (GET /api/notifications/{id}/).
  Future<AppNotification> getNotification(int id) async {
    try {
      final response =
          await _apiClient.dio.get(ApiEndpoints.notificationDetail(id));
      final raw = response.data;
      Map<String, dynamic> map;
      if (raw is Map<String, dynamic>) {
        if (raw['data'] is Map<String, dynamic>) {
          map = raw['data'] as Map<String, dynamic>;
        } else {
          map = raw;
        }
      } else {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          message: 'Format respons tidak valid',
        );
      }
      return AppNotification.fromJson(map);
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
      return _parseNotificationFromAny(response.data, response);
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

  /// Delete a notification owned by current user.
  Future<void> deleteNotification(int id) async {
    try {
      await _apiClient.dio.delete(ApiEndpoints.notificationDetail(id));
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  AppNotification _parseNotificationFromAny(dynamic raw, Response response) {
    if (raw is Map<String, dynamic>) {
      if (raw['data'] is Map<String, dynamic>) {
        return AppNotification.fromJson(raw['data'] as Map<String, dynamic>);
      }

      // Some responses may already be the notification object itself.
      if (raw.containsKey('id') && raw.containsKey('title')) {
        return AppNotification.fromJson(raw);
      }
    }

    // Keep the old ApiResponse fallback for compatibility.
    try {
      final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
        raw as Map<String, dynamic>,
        (data) => data as Map<String, dynamic>,
      );
      if (apiResponse.data != null) {
        return AppNotification.fromJson(apiResponse.data!);
      }
    } catch (_) {
      // Fall through to a normalized error.
    }

    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
      message: 'Format respons notifikasi tidak valid',
    );
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

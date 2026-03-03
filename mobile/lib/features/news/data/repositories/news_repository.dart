import 'package:dio/dio.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/endpoints.dart';
import '../../../../core/models/paginated_state.dart';
import '../../domain/models/news.dart';

class NewsRepository {
  final ApiClient _apiClient = ApiClient();

  /// Get public news list (paginated).
  ///
  /// Backend returns DRF `PageNumberPagination` format:
  /// `{ "count": N, "next": "…?page=X", "previous": …, "results": [...] }`
  Future<PaginatedResponse<News>> getNews({
    String? search,
    int page = 1,
  }) async {
    try {
      final queryParams = <String, dynamic>{'page': page};
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final response = await _apiClient.dio.get(
        ApiEndpoints.publicNews,
        queryParameters: queryParams,
      );

      final data = response.data;

      // Handle paginated envelope { count, next, results }
      if (data is Map<String, dynamic> && data['results'] is List) {
        final results = (data['results'] as List)
            .map((json) => News.fromJson(json as Map<String, dynamic>))
            .toList();
        return PaginatedResponse<News>(
          count: (data['count'] as num?)?.toInt() ?? results.length,
          results: results,
          hasNext: data['next'] != null,
        );
      }

      // Fallback: raw array (shouldn't happen after backend change)
      if (data is List) {
        final results = data
            .map((json) => News.fromJson(json as Map<String, dynamic>))
            .toList();
        return PaginatedResponse<News>(
          count: results.length,
          results: results,
          hasNext: false,
        );
      }

      return const PaginatedResponse<News>(
          count: 0, results: [], hasNext: false);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Get news detail
  Future<News> getNewsDetail(int id) async {
    try {
      final response = await _apiClient.dio.get(ApiEndpoints.newsDetail(id));
      // Detail endpoints return a plain JSON object (no envelope).
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          message: 'Gagal mengambil detail berita',
        );
      }
      return News.fromJson(data);
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

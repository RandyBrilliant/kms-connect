import 'package:dio/dio.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/endpoints.dart';
import '../../domain/models/news.dart';

class NewsRepository {
  final ApiClient _apiClient = ApiClient();

  /// Get public news list
  Future<List<News>> getNews({String? search}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final response = await _apiClient.dio.get(
        ApiEndpoints.publicNews,
        queryParameters: queryParams,
      );

      // Public endpoints return a raw JSON array (pagination_class = None).
      final data = response.data;
      if (data is! List) return [];

      return data
          .map((json) => News.fromJson(json as Map<String, dynamic>))
          .toList();
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

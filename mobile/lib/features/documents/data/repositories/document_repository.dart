import 'package:dio/dio.dart';
import 'dart:io';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/endpoints.dart';
import '../../../../core/models/api_response.dart';
import '../../domain/models/document_type.dart';
import '../../domain/models/applicant_document.dart';

class DocumentRepository {
  final ApiClient _apiClient = ApiClient();

  /// Get public document types
  Future<List<DocumentType>> getDocumentTypes() async {
    try {
      final response = await _apiClient.dio.get(ApiEndpoints.publicDocumentTypes);
      final apiResponse = ApiResponse<List<dynamic>>.fromJson(
        response.data,
        (data) => data as List<dynamic>,
      );

      if (!apiResponse.isSuccess || apiResponse.data == null) {
        return [];
      }

      return (apiResponse.data as List)
          .map((json) => DocumentType.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Get my documents
  /// Handles DRF paginated response {count, results} or plain list.
  Future<List<ApplicantDocument>> getMyDocuments() async {
    try {
      final response = await _apiClient.dio.get(ApiEndpoints.myDocuments);
      final body = response.data;

      List<dynamic> items;
      if (body is List) {
        items = body;
      } else if (body is Map<String, dynamic>) {
        if (body.containsKey('results')) {
          // Paginated DRF: {count, next, previous, results}
          items = body['results'] as List<dynamic>? ?? [];
        } else if (body.containsKey('data')) {
          // Wrapped ApiResponse: {code, data}
          if (body['code'] != 'success') return [];
          items = body['data'] as List<dynamic>? ?? [];
        } else {
          items = [];
        }
      } else {
        items = [];
      }

      return items
          .map((json) => ApplicantDocument.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Upload document
  Future<ApplicantDocument> uploadDocument({
    required int documentTypeId,
    required File file,
  }) async {
    try {
      final formData = FormData.fromMap({
        'document_type': documentTypeId,
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split('/').last,
        ),
      });

      final response = await _apiClient.dio.post(
        ApiEndpoints.myDocuments,
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      final body = response.data;
      Map<String, dynamic> docJson;

      if (body is Map<String, dynamic>) {
        if (body.containsKey('data') && body['code'] == 'success') {
          // Wrapped ApiResponse
          docJson = body['data'] as Map<String, dynamic>;
        } else if (body.containsKey('id')) {
          // Raw DRF serializer response (ModelViewSet default)
          docJson = body;
        } else {
          throw DioException(
            requestOptions: response.requestOptions,
            response: response,
            type: DioExceptionType.badResponse,
            message: body['detail']?.toString() ?? 'Gagal mengunggah dokumen',
          );
        }
      } else {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          message: 'Gagal mengunggah dokumen',
        );
      }

      return ApplicantDocument.fromJson(docJson);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Delete document
  Future<void> deleteDocument(int id) async {
    try {
      await _apiClient.dio.delete('${ApiEndpoints.myDocuments}$id/');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Get OCR prefill data for KTP
  Future<Map<String, dynamic>> getOcrPrefill(int documentId) async {
    try {
      final response = await _apiClient.dio.get(
        ApiEndpoints.documentOcrPrefill(documentId),
      );
      final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );

      if (!apiResponse.isSuccess || apiResponse.data == null) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          message: apiResponse.detail ?? 'Gagal mengambil data OCR',
        );
      }

      return apiResponse.data!;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  DioException _handleError(DioException error) {
    if (error.response != null) {
      final data = error.response!.data;
      if (data is Map<String, dynamic>) {
        // Prefer the first field-level validation error (most specific).
        final errors = data['errors'];
        if (errors is Map<String, dynamic> && errors.isNotEmpty) {
          final firstField = errors.values.first;
          String? fieldMsg;
          if (firstField is List && firstField.isNotEmpty) {
            fieldMsg = firstField.first?.toString();
          } else if (firstField is String) {
            fieldMsg = firstField;
          }
          if (fieldMsg != null && fieldMsg.isNotEmpty) {
            return DioException(
              requestOptions: error.requestOptions,
              response: error.response,
              type: error.type,
              message: fieldMsg,
            );
          }
        }
        // Fallback to generic detail message.
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

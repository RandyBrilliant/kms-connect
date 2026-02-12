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
  Future<List<ApplicantDocument>> getMyDocuments() async {
    try {
      final response = await _apiClient.dio.get(ApiEndpoints.myDocuments);
      final apiResponse = ApiResponse<List<dynamic>>.fromJson(
        response.data,
        (data) => data as List<dynamic>,
      );

      if (!apiResponse.isSuccess || apiResponse.data == null) {
        return [];
      }

      return (apiResponse.data as List)
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

      final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );

      if (!apiResponse.isSuccess || apiResponse.data == null) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          message: apiResponse.detail ?? 'Gagal mengunggah dokumen',
        );
      }

      return ApplicantDocument.fromJson(apiResponse.data!);
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

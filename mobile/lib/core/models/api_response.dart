/// Standard API response wrapper
class ApiResponse<T> {
  final String code;
  final String? detail;
  final T? data;
  final Map<String, dynamic>? errors;

  ApiResponse({
    required this.code,
    this.detail,
    this.data,
    this.errors,
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json, T Function(dynamic)? fromJsonT) {
    return ApiResponse<T>(
      code: json['code'] as String,
      detail: json['detail'] as String?,
      data: json['data'] != null && fromJsonT != null ? fromJsonT(json['data']) : json['data'] as T?,
      errors: json['errors'] as Map<String, dynamic>?,
    );
  }

  bool get isSuccess => code == 'success';
  bool get hasError => !isSuccess;
}

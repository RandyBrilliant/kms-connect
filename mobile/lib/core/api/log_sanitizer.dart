import 'package:dio/dio.dart';

/// Keys whose values must never appear in debug logs (case-insensitive).
/// Also matches keys that *contain* password, token, secret, or authorization.
const _exactSensitiveKeys = {
  'password',
  'password_confirm',
  'old_password',
  'new_password',
  'current_password',
  'confirm_password',
  'refresh',
  'access',
  'token',
  'access_token',
  'refresh_token',
  'authorization',
  'otp',
  'otp_code',
  'nik',
  'ktp_number',
  'id_number',
  'secret',
  'api_key',
  'client_secret',
  'id_token',
  'identity_token',
  'auth_code',
  'authorization_code',
};

bool isSensitiveLogKey(String key) {
  final normalized = key.toLowerCase().replaceAll('-', '_');
  if (_exactSensitiveKeys.contains(normalized)) return true;
  return normalized.contains('password') ||
      normalized.contains('token') ||
      normalized.contains('secret') ||
      normalized.contains('authorization');
}

/// Returns a log-safe copy of [value]: sensitive keys redacted, long strings
/// truncated, binary payloads summarized. Safe to call on request/response
/// bodies that may contain passwords, JWTs, or PII.
Object? sanitizeForLog(Object? value, {int maxString = 200, int depth = 0}) {
  if (value == null) return null;
  if (depth > 6) return '<truncated>';

  if (value is String) {
    if (value.length <= maxString) return value;
    return '${value.substring(0, maxString)}…';
  }

  if (value is Map) {
    return <String, Object?>{
      for (final entry in value.entries)
        entry.key.toString(): isSensitiveLogKey(entry.key.toString())
            ? '<redacted>'
            : sanitizeForLog(entry.value, maxString: maxString, depth: depth + 1),
    };
  }

  if (value is FormData) {
    return <String, Object?>{
      'fields': <String, Object?>{
        for (final field in value.fields)
          field.key: isSensitiveLogKey(field.key)
              ? '<redacted>'
              : sanitizeForLog(field.value, maxString: maxString, depth: depth + 1),
      },
      'files': [
        for (final file in value.files)
          '${file.key}: ${file.value.filename ?? 'file'} (${file.value.length} bytes)',
      ],
    };
  }

  if (value is List<int> && value.length > 32) {
    return '<binary ${value.length} bytes>';
  }

  if (value is Iterable) {
    final list = value.toList();
    final preview = list
        .take(20)
        .map((item) => sanitizeForLog(item, maxString: maxString, depth: depth + 1))
        .toList();
    if (list.length > 20) {
      preview.add('… (${list.length - 20} more)');
    }
    return preview;
  }

  final asString = value.toString();
  if (asString.length <= maxString) return asString;
  return '${asString.substring(0, maxString)}…';
}

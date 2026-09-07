import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api/log_sanitizer.dart';

void main() {
  test('redacts password and token fields in maps', () {
    final sanitized = sanitizeForLog({
      'email': 'user@example.com',
      'password': 'super-secret',
      'refresh': 'jwt-refresh',
      'access_token': 'jwt-access',
      'Authorization': 'Bearer abc',
    }) as Map<String, Object?>;

    expect(sanitized['email'], 'user@example.com');
    expect(sanitized['password'], '<redacted>');
    expect(sanitized['refresh'], '<redacted>');
    expect(sanitized['access_token'], '<redacted>');
    expect(sanitized['Authorization'], '<redacted>');
  });

  test('redacts nested and FormData password fields', () {
    final nested = sanitizeForLog({
      'user': {'password_confirm': 'secret', 'name': 'Ada'},
    }) as Map<String, Object?>;
    final user = nested['user'] as Map<String, Object?>;
    expect(user['password_confirm'], '<redacted>');
    expect(user['name'], 'Ada');

    final form = FormData.fromMap({
      'email': 'a@b.c',
      'password': 'hunter2',
    });
    final sanitizedForm = sanitizeForLog(form) as Map<String, Object?>;
    final fields = sanitizedForm['fields'] as Map<String, Object?>;
    expect(fields['email'], 'a@b.c');
    expect(fields['password'], '<redacted>');
  });

  test('truncates long strings and summarizes binary payloads', () {
    final long = 'x' * 250;
    expect((sanitizeForLog(long) as String).endsWith('…'), isTrue);
    expect(
      sanitizeForLog(List<int>.filled(100, 1)),
      '<binary 100 bytes>',
    );
  });
}

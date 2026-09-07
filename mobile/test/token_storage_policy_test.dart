import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api/token_storage_policy.dart';

void main() {
  test('plaintext token fallback is allowed only in debug', () {
    expect(allowInsecureTokenFallback(debugMode: true), isTrue);
    expect(allowInsecureTokenFallback(debugMode: false), isFalse);
  });

  test('SecureStorageUnavailableException has a user-facing message', () {
    const error = SecureStorageUnavailableException();
    expect(error.toString(), contains('Penyimpanan aman tidak tersedia'));
  });
}

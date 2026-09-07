import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/data/user_session_cache.dart';
import 'package:mobile/features/auth/domain/models/user.dart';

void main() {
  test('session cache omits social ids', () {
    final user = User(
      id: 7,
      email: 'a@example.com',
      fullName: 'Ada',
      role: 'APPLICANT',
      isActive: true,
      emailVerified: true,
      googleId: 'gid',
      appleId: 'aid',
    );
    final payload = sessionCachePayload(user);
    expect(payload.containsKey('google_id'), isFalse);
    expect(payload.containsKey('apple_id'), isFalse);
    expect(payload['email'], 'a@example.com');
    expect(payload['full_name'], 'Ada');

    final restored = userFromSessionCache(payload);
    expect(restored.id, 7);
    expect(restored.googleId, isNull);
    expect(restored.appleId, isNull);
  });
}

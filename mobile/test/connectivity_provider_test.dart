import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/providers/connectivity_provider.dart';

void main() {
  test('isOnlineFromResults is false when none is present', () {
    expect(isOnlineFromResults([ConnectivityResult.wifi]), isTrue);
    expect(isOnlineFromResults([ConnectivityResult.mobile]), isTrue);
    expect(isOnlineFromResults([ConnectivityResult.none]), isFalse);
    expect(
      isOnlineFromResults([ConnectivityResult.wifi, ConnectivityResult.none]),
      isFalse,
    );
  });
}

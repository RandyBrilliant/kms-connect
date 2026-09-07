import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/update/app_update_service.dart';

void main() {
  test('compareStoreVersions treats a higher store version as newer', () {
    expect(compareStoreVersions('1.0.22', '1.0.21'), greaterThan(0));
    expect(compareStoreVersions('1.0.9', '1.0.21'), lessThan(0));
    expect(compareStoreVersions('1.0.21', '1.0.21'), 0);
    expect(compareStoreVersions('2.0.0', '1.9.9'), greaterThan(0));
  });
}

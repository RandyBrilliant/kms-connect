import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/config/env.dart';

void main() {
  test('defaults to production API when dart-define is empty', () {
    expect(resolveApiBaseUrl(fromDefine: ''), kProductionApiBaseUrl);
    expect(resolveApiBaseUrl(fromDefine: '   '), kProductionApiBaseUrl);
  });

  test('honors an explicit dart-define, trimming whitespace', () {
    expect(
      resolveApiBaseUrl(fromDefine: ' http://localhost:8000 '),
      'http://localhost:8000',
    );
  });
}

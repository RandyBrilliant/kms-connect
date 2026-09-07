import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/utils/image_compressor.dart';

void main() {
  test('writeBytesToPath writes the payload to disk', () {
    final dir = Directory.systemTemp.createTempSync('kms_compress');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/out.bin';
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    writeBytesToPath((path: path, bytes: bytes));
    expect(File(path).readAsBytesSync(), bytes);
  });
}

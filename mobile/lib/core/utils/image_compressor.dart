import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Utility for compressing images before upload.
///
/// Reduces camera photos (often 5-10 MB) to a reasonable size while
/// preserving quality for document legibility (KTP, certificates, etc.).
class ImageCompressor {
  const ImageCompressor._();

  /// Default max dimension (width or height) for compressed images.
  static const int defaultMaxDimension = 1920;

  /// Default JPEG quality (0-100). 80 gives a good balance between
  /// file size and readability for document photos.
  static const int defaultQuality = 80;

  /// Maximum file size target in bytes (500 KB).
  static const int maxFileSizeBytes = 500 * 1024;

  /// Compress an image [file] and return a new [File] at a temp path.
  ///
  /// - If the file is already under [maxFileSizeBytes], it is returned as-is
  ///   (no work done).
  /// - Supports JPEG, PNG, and WebP inputs.
  /// - Output is always JPEG for smaller size.
  static Future<File> compress(
    File file, {
    int maxDimension = defaultMaxDimension,
    int quality = defaultQuality,
  }) async {
    final originalSize = await file.length();

    // Skip compression for small files.
    if (originalSize <= maxFileSizeBytes) {
      if (kDebugMode) {
        debugPrint(
          'ImageCompressor: file already small '
          '(${(originalSize / 1024).toStringAsFixed(0)} KB) — skipping',
        );
      }
      return file;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final targetPath = p.join(
        tempDir.path,
        'compressed_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      final Uint8List? result =
          await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        minWidth: maxDimension,
        minHeight: maxDimension,
        quality: quality,
        format: CompressFormat.jpeg,
      );

      if (result == null || result.isEmpty) {
        if (kDebugMode) debugPrint('ImageCompressor: compression returned null — using original');
        return file;
      }

      final compressedFile = File(targetPath)..writeAsBytesSync(result);

      if (kDebugMode) {
        final compressedSize = compressedFile.lengthSync();
        final ratio = ((1 - compressedSize / originalSize) * 100).toStringAsFixed(0);
        debugPrint(
          'ImageCompressor: '
          '${(originalSize / 1024).toStringAsFixed(0)} KB → '
          '${(compressedSize / 1024).toStringAsFixed(0)} KB '
          '($ratio% reduction)',
        );
      }

      return compressedFile;
    } catch (e) {
      if (kDebugMode) debugPrint('ImageCompressor: error $e — using original');
      return file;
    }
  }

  /// Compress a KTP/document image with settings optimised for legibility.
  ///
  /// Uses a slightly higher quality (85) and lower max dimension (1600)
  /// since documents need to stay readable for OCR.
  static Future<File> compressDocument(File file) {
    return compress(
      file,
      maxDimension: 1600,
      quality: 85,
    );
  }
}

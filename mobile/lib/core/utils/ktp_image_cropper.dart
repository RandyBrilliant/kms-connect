import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

/// Crops camera capture based on the on-screen KTP guide rectangle.
class KtpImageCropper {
  static Future<File> cropFromGuide({
    required File sourceFile,
    required Size screenSize,
    required Rect guideRect,
  }) async {
    final bytes = await sourceFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return sourceFile;

    // Respect EXIF orientation so crop mapping matches camera preview.
    final oriented = img.bakeOrientation(decoded);

    final srcW = oriented.width.toDouble();
    final srcH = oriented.height.toDouble();
    final screenW = screenSize.width;
    final screenH = screenSize.height;

    // Match preview rendering logic: BoxFit.cover inside full-screen viewport.
    final scale = (screenW / srcW) > (screenH / srcH)
        ? (screenW / srcW)
        : (screenH / srcH);
    final displayedW = srcW * scale;
    final displayedH = srcH * scale;
    final offsetX = (screenW - displayedW) / 2;
    final offsetY = (screenH - displayedH) / 2;

    int cropX = ((guideRect.left - offsetX) / scale).round();
    int cropY = ((guideRect.top - offsetY) / scale).round();
    int cropW = (guideRect.width / scale).round();
    int cropH = (guideRect.height / scale).round();

    cropX = cropX.clamp(0, oriented.width - 1);
    cropY = cropY.clamp(0, oriented.height - 1);
    cropW = cropW.clamp(1, oriented.width - cropX);
    cropH = cropH.clamp(1, oriented.height - cropY);

    final cropped = img.copyCrop(
      oriented,
      x: cropX,
      y: cropY,
      width: cropW,
      height: cropH,
    );

    final dir = p.dirname(sourceFile.path);
    final base = p.basenameWithoutExtension(sourceFile.path);
    final outPath = p.join(dir, '${base}_ktp_crop.jpg');
    final outFile = File(outPath);
    await outFile.writeAsBytes(img.encodeJpg(cropped, quality: 92));
    return outFile;
  }

  /// Crops the image to a centered fixed aspect ratio (e.g. KTP 1.586:1).
  static Future<File> cropToAspectRatioCentered({
    required File sourceFile,
    required double ratioX,
    required double ratioY,
  }) async {
    final bytes = await sourceFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return sourceFile;

    final oriented = img.bakeOrientation(decoded);
    final srcW = oriented.width;
    final srcH = oriented.height;
    final targetRatio = ratioX / ratioY;
    final srcRatio = srcW / srcH;

    int cropW;
    int cropH;
    if (srcRatio > targetRatio) {
      // Source is wider than target ratio: trim left/right.
      cropH = srcH;
      cropW = (cropH * targetRatio).round();
    } else {
      // Source is taller than target ratio: trim top/bottom.
      cropW = srcW;
      cropH = (cropW / targetRatio).round();
    }

    cropW = cropW.clamp(1, srcW);
    cropH = cropH.clamp(1, srcH);
    final cropX = ((srcW - cropW) / 2).round().clamp(0, srcW - cropW);
    final cropY = ((srcH - cropH) / 2).round().clamp(0, srcH - cropH);

    final cropped = img.copyCrop(
      oriented,
      x: cropX,
      y: cropY,
      width: cropW,
      height: cropH,
    );

    final dir = p.dirname(sourceFile.path);
    final base = p.basenameWithoutExtension(sourceFile.path);
    final outPath = p.join(dir, '${base}_ktp_ratio_crop.jpg');
    final outFile = File(outPath);
    await outFile.writeAsBytes(img.encodeJpg(cropped, quality: 92));
    return outFile;
  }
}

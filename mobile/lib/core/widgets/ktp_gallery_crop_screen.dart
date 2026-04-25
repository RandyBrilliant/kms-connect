import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../../config/colors.dart';

/// Manual KTP crop screen for gallery images using pan/zoom interaction.
/// Returns the cropped file when user taps "Gunakan".
class KtpGalleryCropScreen extends StatefulWidget {
  const KtpGalleryCropScreen({
    super.key,
    required this.sourceFile,
    this.ratioX = 1.586,
    this.ratioY = 1,
    this.title = 'Sesuaikan Bingkai Dokumen',
    this.instruction = 'Geser & zoom foto agar dokumen pas di dalam bingkai',
  });

  final File sourceFile;
  final double ratioX;
  final double ratioY;
  final String title;
  final String instruction;

  @override
  State<KtpGalleryCropScreen> createState() => _KtpGalleryCropScreenState();
}

class _KtpGalleryCropScreenState extends State<KtpGalleryCropScreen> {
  final TransformationController _transformController =
      TransformationController();

  bool _isSaving = false;
  Size? _sourceSize;
  bool _isLoadingSize = true;

  double get _guideRatio => widget.ratioX / widget.ratioY;

  @override
  void initState() {
    super.initState();
    _loadImageSize();
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _loadImageSize() async {
    try {
      final bytes = await widget.sourceFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final img = frame.image;
      if (!mounted) return;
      setState(() {
        _sourceSize = Size(img.width.toDouble(), img.height.toDouble());
        _isLoadingSize = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingSize = false);
    }
  }

  Future<void> _onUsePressed({
    required Rect imageRect,
    required Rect guideRect,
  }) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final out = await _cropByCurrentTransform(
        sourceFile: widget.sourceFile,
        imageRect: imageRect,
        guideRect: guideRect,
        transform: _transformController.value,
      );
      if (!mounted) return;
      Navigator.pop(context, out);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Gagal crop foto', style: GoogleFonts.plusJakartaSans()),
          backgroundColor: AppColors.error,
        ),
      );
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingSize) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    if (_sourceSize == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'Gagal memuat gambar',
            style: GoogleFonts.plusJakartaSans(color: Colors.white),
          ),
        ),
      );
    }

    final screen = MediaQuery.sizeOf(context);
    final guide = _guideRect(screen);

    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final viewport = Size(constraints.maxWidth, constraints.maxHeight);
          final imageRect = _imageContainRect(
            viewport: viewport,
            sourceSize: _sourceSize!,
          );

          return Stack(
            children: [
              Positioned.fromRect(
                rect: imageRect,
                child: ClipRect(
                  child: InteractiveViewer(
                    transformationController: _transformController,
                    minScale: 1,
                    maxScale: 5,
                    constrained: false,
                    panEnabled: true,
                    scaleEnabled: true,
                    boundaryMargin: const EdgeInsets.all(300),
                    child: SizedBox(
                      width: imageRect.width,
                      height: imageRect.height,
                      child: RepaintBoundary(
                        child: Image.file(
                          widget.sourceFile,
                          fit: BoxFit.fill,
                          filterQuality: FilterQuality.low,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              IgnorePointer(
                child: _KtpMaskOverlay(guideRect: guide),
              ),
              SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close, color: Colors.white),
                          ),
                          Expanded(
                            child: Text(
                              widget.title,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          widget.instruction,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _isSaving
                              ? null
                              : () => _onUsePressed(
                                    imageRect: imageRect,
                                    guideRect: guide,
                                  ),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primaryDarkGreen,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Gunakan',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Rect _guideRect(Size size) {
    final frameWidth = size.width * 0.85;
    final frameHeight = frameWidth / _guideRatio;
    final left = (size.width - frameWidth) / 2;
    final top = (size.height - frameHeight) / 2;
    return Rect.fromLTWH(left, top, frameWidth, frameHeight);
  }

  Rect _imageContainRect({required Size viewport, required Size sourceSize}) {
    final srcW = sourceSize.width;
    final srcH = sourceSize.height;
    final scale = (viewport.width / srcW) < (viewport.height / srcH)
        ? (viewport.width / srcW)
        : (viewport.height / srcH);
    final w = srcW * scale;
    final h = srcH * scale;
    final left = (viewport.width - w) / 2;
    final top = (viewport.height - h) / 2;
    return Rect.fromLTWH(left, top, w, h);
  }

  Future<File> _cropByCurrentTransform({
    required File sourceFile,
    required Rect imageRect,
    required Rect guideRect,
    required Matrix4 transform,
  }) async {
    final bytes = await sourceFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return sourceFile;
    final oriented = img.bakeOrientation(decoded);

    final srcW = oriented.width.toDouble();
    final srcH = oriented.height.toDouble();
    final displayW = imageRect.width;
    final displayH = imageRect.height;

    final ratioX = srcW / displayW;
    final ratioY = srcH / displayH;
    final s = transform.storage[0];
    final tx = transform.storage[12];
    final ty = transform.storage[13];

    int mapX(double screenX) =>
        (((screenX - imageRect.left - tx) / s) * ratioX).round();
    int mapY(double screenY) =>
        (((screenY - imageRect.top - ty) / s) * ratioY).round();

    int x1 = mapX(guideRect.left);
    int y1 = mapY(guideRect.top);
    int x2 = mapX(guideRect.right);
    int y2 = mapY(guideRect.bottom);

    if (x2 < x1) {
      final t = x1;
      x1 = x2;
      x2 = t;
    }
    if (y2 < y1) {
      final t = y1;
      y1 = y2;
      y2 = t;
    }

    x1 = x1.clamp(0, oriented.width - 1);
    y1 = y1.clamp(0, oriented.height - 1);
    x2 = x2.clamp(x1 + 1, oriented.width);
    y2 = y2.clamp(y1 + 1, oriented.height);

    final cropW = (x2 - x1).clamp(1, oriented.width - x1);
    final cropH = (y2 - y1).clamp(1, oriented.height - y1);

    final cropped = img.copyCrop(
      oriented,
      x: x1,
      y: y1,
      width: cropW,
      height: cropH,
    );

    final dir = p.dirname(sourceFile.path);
    final base = p.basenameWithoutExtension(sourceFile.path);
    final outPath = p.join(dir, '${base}_ktp_manual_crop.jpg');
    final outFile = File(outPath);
    await outFile.writeAsBytes(img.encodeJpg(cropped, quality: 92));
    return outFile;
  }
}

class _KtpMaskOverlay extends StatelessWidget {
  const _KtpMaskOverlay({required this.guideRect});

  final Rect guideRect;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: MediaQuery.sizeOf(context),
      painter: _KtpMaskPainter(guideRect: guideRect),
    );
  }
}

class _KtpMaskPainter extends CustomPainter {
  const _KtpMaskPainter({required this.guideRect});

  final Rect guideRect;

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = Colors.black.withValues(alpha: 0.55);
    final path = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(guideRect, const Radius.circular(12)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, bgPaint);

    final borderPaint = Paint()
      ..color = AppColors.primaryDarkGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(guideRect, const Radius.circular(12)),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _KtpMaskPainter oldDelegate) {
    return oldDelegate.guideRect != guideRect;
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/colors.dart';

/// Custom camera screen with KTP alignment guidelines overlay.
/// Returns `File` on successful capture, `null` on cancel.
class KtpCameraScreen extends StatefulWidget {
  const KtpCameraScreen({super.key});

  @override
  State<KtpCameraScreen> createState() => _KtpCameraScreenState();
}

class _KtpCameraScreenState extends State<KtpCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isCapturing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeController();
    super.dispose();
  }

  void _disposeController() {
    _controller?.dispose();
    _controller = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Don't handle lifecycle if controller is not ready
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      _disposeController();
      if (mounted) setState(() => _isInitialized = false);
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() => _errorMessage = 'Kamera tidak tersedia');
        }
        return;
      }

      // Pick back camera, fallback to first
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();

      // Lock focus mode for crisper images
      if (controller.value.isInitialized) {
        try {
          await controller.setFocusMode(FocusMode.auto);
          await controller.setFlashMode(FlashMode.off);
        } catch (_) {
          // Not all devices support focus/flash control
        }
      }

      if (!mounted) {
        controller.dispose();
        return;
      }

      _controller = controller;
      setState(() {
        _isInitialized = true;
        _errorMessage = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Gagal membuka kamera');
      }
    }
  }

  Future<void> _takePicture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _isCapturing) {
      return;
    }

    setState(() => _isCapturing = true);

    try {
      final XFile image = await controller.takePicture();
      if (mounted) {
        Navigator.pop(context, File(image.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengambil foto',
                style: GoogleFonts.plusJakartaSans()),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() => _isCapturing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // Error state
    if (_errorMessage != null) {
      return _buildErrorView();
    }

    // Loading state
    if (!_isInitialized || _controller == null) {
      return _buildLoadingView();
    }

    // Camera ready
    return _buildCameraView();
  }

  Widget _buildLoadingView() {
    return SafeArea(
      child: Column(
        children: [
          _buildTopBar(),
          const Expanded(
            child: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return SafeArea(
      child: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      color: Colors.white54, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () {
                      setState(() => _errorMessage = null);
                      _initializeCamera();
                    },
                    child: Text(
                      'Coba Lagi',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.primaryDarkGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Widget _buildCameraView() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview — fill screen
        Center(child: CameraPreview(_controller!)),

        // KTP frame overlay
        const _KtpOverlay(),

        // UI controls on top
        SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              const SizedBox(height: 8),

              // Instructions card
              _buildInstructionsCard(),

              const Spacer(),

              // Bottom controls
              _buildBottomControls(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionsCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Posisikan KTP di dalam bingkai',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Pastikan foto jelas dan tidak blur',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tip badge
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primaryDarkGreen.withOpacity(0.85),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lightbulb_outline,
                    color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Gunakan pencahayaan yang cukup',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Capture button
          GestureDetector(
            onTap: _isCapturing ? null : _takePicture,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isCapturing ? Colors.grey : Colors.white,
                border: Border.all(
                  color: AppColors.primaryDarkGreen,
                  width: 4,
                ),
              ),
              child: _isCapturing
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primaryDarkGreen,
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.camera_alt,
                      color: AppColors.primaryDarkGreen,
                      size: 32,
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Ketuk untuk mengambil foto',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Lightweight overlay widget — uses RepaintBoundary so it only paints once.
class _KtpOverlay extends StatelessWidget {
  const _KtpOverlay();

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _KtpOverlayPainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _KtpOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double frameWidth = size.width * 0.85;
    final double frameHeight = frameWidth / 1.586; // KTP standard ~85.6x54mm ≈ 1.586
    final double left = (size.width - frameWidth) / 2;
    final double top = (size.height - frameHeight) / 2;
    final double right = left + frameWidth;
    final double bottom = top + frameHeight;
    final frameRect = Rect.fromLTRB(left, top, right, bottom);

    // Semi-transparent background with cutout
    final bgPaint = Paint()..color = Colors.black.withOpacity(0.5);
    final bgPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(frameRect, const Radius.circular(12)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(bgPath, bgPaint);

    // Frame border
    final framePaint = Paint()
      ..color = AppColors.primaryDarkGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(frameRect, const Radius.circular(12)),
      framePaint,
    );

    // Corner brackets
    const double cl = 28;
    final cornerPaint = Paint()
      ..color = AppColors.primaryDarkGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    // TL
    canvas.drawLine(Offset(left, top + cl), Offset(left, top), cornerPaint);
    canvas.drawLine(Offset(left, top), Offset(left + cl, top), cornerPaint);
    // TR
    canvas.drawLine(Offset(right - cl, top), Offset(right, top), cornerPaint);
    canvas.drawLine(Offset(right, top), Offset(right, top + cl), cornerPaint);
    // BL
    canvas.drawLine(Offset(left, bottom - cl), Offset(left, bottom), cornerPaint);
    canvas.drawLine(Offset(left, bottom), Offset(left + cl, bottom), cornerPaint);
    // BR
    canvas.drawLine(Offset(right - cl, bottom), Offset(right, bottom), cornerPaint);
    canvas.drawLine(Offset(right, bottom), Offset(right, bottom - cl), cornerPaint);

    // Center guidelines
    final guidePaint = Paint()
      ..color = AppColors.secondaryLightGreen.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(left + 20, top + frameHeight / 2),
      Offset(right - 20, top + frameHeight / 2),
      guidePaint,
    );
    canvas.drawLine(
      Offset(left + frameWidth / 2, top + 20),
      Offset(left + frameWidth / 2, bottom - 20),
      guidePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

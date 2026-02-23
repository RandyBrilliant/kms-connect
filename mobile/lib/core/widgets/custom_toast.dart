import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum ToastType { success, error, warning, info }

/// Global navigator key.
///
/// Assign this to [MaterialApp.router]'s `key` or pass it as
/// [GoRouter]'s `navigatorKey` so that [CustomToast] can always find
/// the **root** [Overlay] — one that lives above every route and is
/// never destroyed by page transitions.
///
/// Usage in `app.dart`:
/// ```dart
/// GoRouter(navigatorKey: rootNavigatorKey, ...)
/// ```
final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'rootNav');

class CustomToast {
  /// Show an animated toast that persists across route transitions.
  ///
  /// The toast is inserted into the **root** overlay so it stays visible
  /// even when the current route is replaced (e.g. login → home).
  ///
  /// [context] is only used as a fallback when [rootNavigatorKey] has no
  /// attached navigator (e.g. in tests or before the first frame).
  static void show(
    BuildContext context, {
    required String message,
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    // Prefer the root overlay so the toast survives route changes.
    final OverlayState overlay;
    final rootOverlay = rootNavigatorKey.currentState?.overlay;
    if (rootOverlay != null) {
      overlay = rootOverlay;
    } else {
      // Fallback: use whatever overlay the caller's context can see.
      overlay = Overlay.of(context);
    }

    _insert(overlay, message: message, type: type, duration: duration);
  }

  /// Show a toast **without** a [BuildContext].
  ///
  /// Uses [rootNavigatorKey] exclusively, so it works from Riverpod
  /// providers, interceptors, or any non-widget code. If the root
  /// navigator is not yet attached the call is silently ignored.
  static void showGlobal({
    required String message,
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay = rootNavigatorKey.currentState?.overlay;
    if (overlay == null) return;
    _insert(overlay, message: message, type: type, duration: duration);
  }

  static void _insert(
    OverlayState overlay, {
    required String message,
    required ToastType type,
    required Duration duration,
  }) {
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (_) => _ToastWidget(
        message: message,
        type: type,
        duration: duration,
        onDismiss: () {
          if (overlayEntry.mounted) overlayEntry.remove();
        },
      ),
    );

    overlay.insert(overlayEntry);
    // Auto-remove after duration + slide-out animation
    Future.delayed(duration + const Duration(milliseconds: 450), () {
      if (overlayEntry.mounted) overlayEntry.remove();
    });
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final ToastType type;
  final Duration duration;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.message,
    required this.type,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with TickerProviderStateMixin {
  late final AnimationController _slideController;
  late final AnimationController _progressController;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _progressController = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 2.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _slideController.forward();
    _progressController.forward().then((_) => _dismiss());
  }

  @override
  void dispose() {
    _slideController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  Color get _typeColor {
    switch (widget.type) {
      case ToastType.success:
        return const Color(0xFF00C853);
      case ToastType.error:
        return const Color(0xFFFF3D00);
      case ToastType.warning:
        return const Color(0xFFFF9100);
      case ToastType.info:
        return const Color(0xFF2979FF);
    }
  }

  Color get _typeLightColor {
    switch (widget.type) {
      case ToastType.success:
        return const Color(0xFFE8F5E9);
      case ToastType.error:
        return const Color(0xFFFFEBEE);
      case ToastType.warning:
        return const Color(0xFFFFF8E1);
      case ToastType.info:
        return const Color(0xFFE3F2FD);
    }
  }

  IconData get _icon {
    switch (widget.type) {
      case ToastType.success:
        return Icons.check_circle_rounded;
      case ToastType.error:
        return Icons.error_rounded;
      case ToastType.warning:
        return Icons.warning_rounded;
      case ToastType.info:
        return Icons.info_rounded;
    }
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    await _slideController.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 24,
      left: 20,
      right: 20,
      child: SlideTransition(
        position: _slideAnimation,
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 24,
                  spreadRadius: 0,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: _typeColor.withValues(alpha: 0.18),
                  blurRadius: 16,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: _typeLightColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(_icon, color: _typeColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.message,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1A1A2E),
                              height: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _dismiss,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2F2F2),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 15,
                              color: Color(0xFF888888),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Animated depletion progress bar
                  AnimatedBuilder(
                    animation: _progressController,
                    builder: (_, child) => LinearProgressIndicator(
                      value: 1.0 - _progressController.value,
                      backgroundColor: const Color(0xFFF0F0F0),
                      valueColor: AlwaysStoppedAnimation<Color>(_typeColor),
                      minHeight: 3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

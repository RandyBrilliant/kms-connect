import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The semantic type of a toast notification.
enum ToastType { success, error, warning, info }

/// Global navigator key  must be registered as [GoRouter]'s navigatorKey.
///
/// ```dart
/// GoRouter(navigatorKey: rootNavigatorKey, ...)
/// ```
final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'rootNav');

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

class CustomToast {
  /// Show a toast anchored to the **top-center** of the screen.
  ///
  /// Prefers the root overlay so the toast survives route transitions.
  static void show(
    BuildContext context, {
    required String message,
    String? title,
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay =
        rootNavigatorKey.currentState?.overlay ?? Overlay.of(context);
    _insert(overlay, message: message, title: title, type: type, duration: duration);
  }

  /// Show a toast without a [BuildContext]  safe to call from providers,
  /// interceptors, or any non-widget code.
  static void showGlobal({
    required String message,
    String? title,
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay = rootNavigatorKey.currentState?.overlay;
    if (overlay == null) return;
    _insert(overlay, message: message, title: title, type: type, duration: duration);
  }

  static void _insert(
    OverlayState overlay, {
    required String message,
    String? title,
    required ToastType type,
    required Duration duration,
  }) {
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ToastWidget(
        message: message,
        title: title,
        type: type,
        duration: duration,
        onDismiss: () {
          if (entry.mounted) entry.remove();
        },
      ),
    );

    overlay.insert(entry);
    // Safety net: force-remove after animation window closes.
    Future.delayed(duration + const Duration(milliseconds: 500), () {
      if (entry.mounted) entry.remove();
    });
  }
}

// ---------------------------------------------------------------------------
// Internal widget
// ---------------------------------------------------------------------------

class _ToastWidget extends StatefulWidget {
  final String message;
  final String? title;
  final ToastType type;
  final Duration duration;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.message,
    this.title,
    required this.type,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with TickerProviderStateMixin {
  late final AnimationController _slideCtrl;
  late final AnimationController _progressCtrl;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;

  double _dragOffset = 0;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();

    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _progressCtrl = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    // Slide in from the top
    _slideAnim = Tween<Offset>(
      begin: const Offset(0.0, -1.6),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideCtrl,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _slideCtrl,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _slideCtrl.forward();
    _progressCtrl.forward().then((_) => _dismiss());
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _progressCtrl.dispose();
    super.dispose();
  }

  //  Type tokens 

  /// Container color  a tonal surface matching each type.
  Color get _containerColor {
    switch (widget.type) {
      case ToastType.success:
        return const Color(0xFF1B5E20);
      case ToastType.error:
        return const Color(0xFFB3261E);
      case ToastType.warning:
        return const Color(0xFF7A4F00);
      case ToastType.info:
        return const Color(0xFF004E8C);
    }
  }

  /// Icon badge background  a lighter tonal version using surface.
  Color get _badgeColor {
    switch (widget.type) {
      case ToastType.success:
        return const Color(0xFF2E7D32).withValues(alpha: 0.28);
      case ToastType.error:
        return Colors.white.withValues(alpha: 0.15);
      case ToastType.warning:
        return Colors.white.withValues(alpha: 0.15);
      case ToastType.info:
        return Colors.white.withValues(alpha: 0.15);
    }
  }

  /// Progress bar color  slightly lighter than the container.
  Color get _progressColor {
    switch (widget.type) {
      case ToastType.success:
        return const Color(0xFF66BB6A);
      case ToastType.error:
        return const Color(0xFFEF9A9A);
      case ToastType.warning:
        return const Color(0xFFFFCC80);
      case ToastType.info:
        return const Color(0xFF90CAF9);
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

  String get _label {
    switch (widget.type) {
      case ToastType.success:
        return 'Berhasil';
      case ToastType.error:
        return 'Kesalahan';
      case ToastType.warning:
        return 'Perhatian';
      case ToastType.info:
        return 'Informasi';
    }
  }

  //  Dismiss logic 

  Future<void> _dismiss() async {
    if (_dismissing || !mounted) return;
    _dismissing = true;
    _progressCtrl.stop();
    await _slideCtrl.reverse();
    widget.onDismiss();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (_dismissing) return;
    setState(() {
      // Only allow dragging upward
      _dragOffset = (_dragOffset + d.delta.dy).clamp(-120.0, 12.0);
    });
    // If dragged far enough up, dismiss
    if (_dragOffset <= -80) _dismiss();
  }

  void _onDragEnd(DragEndDetails d) {
    if (_dismissing) return;
    if (_dragOffset <= -40 || d.primaryVelocity != null && d.primaryVelocity! < -400) {
      _dismiss();
    } else {
      // Spring back
      setState(() => _dragOffset = 0);
    }
  }

  //  Build 

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + 12,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnim,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Transform.translate(
            offset: Offset(0, _dragOffset),
            child: GestureDetector(
              onVerticalDragUpdate: _onDragUpdate,
              onVerticalDragEnd: _onDragEnd,
              child: Material(
                color: Colors.transparent,
                child: _ToastCard(
                  type: widget.type,
                  message: widget.message,
                  containerColor: _containerColor,
                  badgeColor: _badgeColor,
                  progressColor: _progressColor,
                  icon: _icon,
                  label: widget.title ?? _label,
                  progressAnimation: _progressCtrl,
                  onClose: _dismiss,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Toast card  pure visual component, no state
// ---------------------------------------------------------------------------

class _ToastCard extends StatelessWidget {
  final ToastType type;
  final String message;
  final Color containerColor;
  final Color badgeColor;
  final Color progressColor;
  final IconData icon;
  final String label;
  final Animation<double> progressAnimation;
  final VoidCallback onClose;

  const _ToastCard({
    required this.type,
    required this.message,
    required this.containerColor,
    required this.badgeColor,
    required this.progressColor,
    required this.icon,
    required this.label,
    required this.progressAnimation,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    const onColor = Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: containerColor.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 6),
            spreadRadius: -2,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            //  Progress bar at TOP 
            AnimatedBuilder(
              animation: progressAnimation,
              builder: (_, _) => LinearProgressIndicator(
                value: 1.0 - progressAnimation.value,
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                minHeight: 2.5,
              ),
            ),

            //  Content row 
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Icon badge
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: onColor, size: 22),
                  ),
                  const SizedBox(width: 12),

                  // Text block
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: onColor.withValues(alpha: 0.65),
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          message,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: onColor,
                            height: 1.35,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Close button
                  GestureDetector(
                    onTap: onClose,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: onColor.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
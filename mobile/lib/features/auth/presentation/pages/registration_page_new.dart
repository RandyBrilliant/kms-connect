import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/widgets/auth_wave_header.dart';
import '../providers/registration_provider.dart';
import 'steps/registration_step1_credentials.dart';
import 'steps/registration_step2_ktp.dart';

/// Multi-step registration shell.
///
/// Hosts the animated green-wave header (same visual language as [LoginPage])
/// with a live step-progress indicator, entrance animations, and an
/// [AnimatedSwitcher] that fades/slides between steps.
class RegistrationPageNew extends ConsumerStatefulWidget {
  const RegistrationPageNew({super.key});

  @override
  ConsumerState<RegistrationPageNew> createState() =>
      _RegistrationPageNewState();
}

class _RegistrationPageNewState extends ConsumerState<RegistrationPageNew>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _headerOpacity;
  late final Animation<double> _headerScale;
  late final Animation<Offset> _panelSlide;
  late final Animation<double> _panelOpacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _headerOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0.0, 0.55, curve: Curves.easeOut)),
    );
    _headerScale = Tween<double>(begin: 0.88, end: 1).animate(
      CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0.0, 0.75, curve: Curves.easeOutBack)),
    );
    _panelSlide = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.15, 1.0, curve: Curves.easeOutCubic),
    ));
    _panelOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0.0, 0.65, curve: Curves.easeOut)),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _ctrl.forward());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _handleBack(int currentStep) {
    if (currentStep == 0) {
      context.go('/login');
    } else {
      ref.read(registrationProvider.notifier).previousStep();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentStep = ref.watch(registrationProvider).currentStep;
    final cs = Theme.of(context).colorScheme;
    final size = MediaQuery.sizeOf(context);
    // NOTE: do NOT read viewInsetsOf here — keyboard animation would rebuild
    // the entire tree on every frame. The _BottomInsetSpacer leaf widget
    // isolates that dependency so only the spacer itself rebuilds.
    final safePad = MediaQuery.paddingOf(context);
    final isCompact = size.height < 740;
    final headerH = math.max(size.height * 0.30, isCompact ? 185.0 : 220.0);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: cs.surface,
      body: Stack(
        fit: StackFit.expand,
        children: [
          //  Green wave header 
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: headerH,
            child: FadeTransition(
              opacity: _headerOpacity,
              child: ScaleTransition(
                scale: _headerScale,
                alignment: Alignment.topCenter,
                child: AuthWaveHeader(height: headerH),
              ),
            ),
          ),

          //  Scrollable content 
          SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const ClampingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: headerH * 0.18),

                // Header content (logo + title + step pills)
                FadeTransition(
                  opacity: _headerOpacity,
                  child: ScaleTransition(
                    scale: _headerScale,
                    child: _RegHeaderContent(currentStep: currentStep),
                  ),
                ),

                // Form panel
                SlideTransition(
                  position: _panelSlide,
                  child: FadeTransition(
                    opacity: _panelOpacity,
                    child: Container(
                      color: cs.surface,
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.04, 0),
                              end: Offset.zero,
                            ).animate(anim),
                            child: child,
                          ),
                        ),
                        child: currentStep == 0
                            ? const RegistrationStep1Credentials(
                                key: ValueKey(0))
                            : const RegistrationStep2Ktp(key: ValueKey(1)),
                      ),
                    ),
                  ),
                ),

                // Listens to keyboard inset independently — only this leaf
                // widget rebuilds during keyboard animation, not the form tree.
                const _BottomInsetSpacer(),
              ],
            ),
          ),

          //  Back button — LAST in stack so it renders above everything 
          Positioned(
            top: safePad.top + 4,
            left: 4,
            child: FadeTransition(
              opacity: _headerOpacity,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 20),
                onPressed: () => _handleBack(currentStep),
                tooltip: currentStep == 0
                    ? 'Kembali ke login'
                    : 'Langkah sebelumnya',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

//  Header content (logo + title + step progress) 

class _RegHeaderContent extends StatelessWidget {
  final int currentStep;
  const _RegHeaderContent({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo badge
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/logo.png',
              width: 72,
              height: 72,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(
                Icons.eco_rounded,
                size: 36,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Buat Akun Baru',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 14),
        _StepProgressIndicator(currentStep: currentStep),
        const SizedBox(height: 28),
      ],
    );
  }
}

//  Step progress indicator 

class _StepProgressIndicator extends StatelessWidget {
  final int currentStep;
  const _StepProgressIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepCircle(number: 1, isActive: currentStep == 0, isComplete: currentStep > 0),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 48,
          height: 2,
          decoration: BoxDecoration(
            color: currentStep > 0
                ? Colors.white.withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        _StepCircle(number: 2, isActive: currentStep == 1, isComplete: false),
      ],
    );
  }
}

class _StepCircle extends StatelessWidget {
  final int number;
  final bool isActive;
  final bool isComplete;
  const _StepCircle(
      {required this.number, required this.isActive, required this.isComplete});

  @override
  Widget build(BuildContext context) {
    final filled = isActive || isComplete;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled
            ? Colors.white.withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.22),
        border: Border.all(
          color: filled ? Colors.transparent : Colors.white.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Center(
        child: isComplete
            ? Icon(Icons.check_rounded,
                size: 16,
                color: const Color(0xFF2B6E36))
            : Text(
                '$number',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isActive
                      ? const Color(0xFF2B6E36)
                      : Colors.white.withValues(alpha: 0.7),
                ),
              ),
      ),
    );
  }
}

// ── Keyboard inset spacer ────────────────────────────────────────────────────
//
// Isolates MediaQuery.viewInsetsOf into a leaf widget so only this one node
// rebuilds during keyboard animation — the form fields above are untouched.
class _BottomInsetSpacer extends StatelessWidget {
  const _BottomInsetSpacer();

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return SizedBox(height: inset + 24);
  }
}

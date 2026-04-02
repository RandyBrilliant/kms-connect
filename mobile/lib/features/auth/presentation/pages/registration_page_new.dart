import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../config/colors.dart';
import '../../../../core/widgets/professional/professional_gradient_background.dart';
import '../../../../core/widgets/professional/professional_card.dart';
import '../providers/registration_provider.dart';
import 'steps/registration_step1_credentials.dart';
import 'steps/registration_step2_ktp.dart';

/// Professional multi-step registration shell.
///
/// Uses ProfessionalGradientBackground for consistent visual language with login.
/// Features smooth step transitions and a modern progress indicator.
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
  late final Animation<double> _cardSlide;
  late final Animation<double> _cardOpacity;

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
    _cardSlide = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic)),
    );
    _cardOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0.3, 0.9, curve: Curves.easeOut)),
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

  Widget _buildProgressIndicator(int currentStep) {
    return FadeTransition(
      opacity: _headerOpacity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Row(
          children: [
            // Step 1
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Step 2
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: currentStep >= 1
                      ? Colors.white.withOpacity(0.9)
                      : Colors.white.withOpacity(0.3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentStep = ref.watch(registrationProvider).currentStep;
    final size = MediaQuery.sizeOf(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: ProfessionalGradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: bottomInset + 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: size.height - 48),
              child: Column(
                children: [
                  const SizedBox(height: 16),

                  // Header with back button and title
                  FadeTransition(
                    opacity: _headerOpacity,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => _handleBack(currentStep),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.15),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 1.0,
                                ),
                              ),
                              child: const Icon(
                                Icons.arrow_back_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            'Daftar Akun',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Header with logo and progress
                  FadeTransition(
                    opacity: _headerOpacity,
                    child: Column(
                      children: [
                        // Logo
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: AppColors.cardShadow,
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/logo.png',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.gradientStart,
                                      AppColors.gradientEnd,
                                    ],
                                  ),
                                ),
                                child: const Icon(
                                  Icons.business_center_rounded,
                                  size: 40,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // App title
                        Text(
                          'KMS Connect',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 8),

                        Text(
                          'Bergabunglah dengan platform profesional',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.9),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Progress indicator
                        _buildProgressIndicator(currentStep),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Registration form card
                  AnimatedBuilder(
                    animation: _ctrl,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _cardSlide.value),
                        child: FadeTransition(
                          opacity: _cardOpacity,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: ProfessionalCard(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 280),
                                  transitionBuilder: (child, animation) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: SlideTransition(
                                        position: Tween<Offset>(
                                          begin: const Offset(0.1, 0),
                                          end: Offset.zero,
                                        ).animate(animation),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: currentStep == 0
                                      ? const RegistrationStep1Credentials()
                                      : const RegistrationStep2Ktp(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
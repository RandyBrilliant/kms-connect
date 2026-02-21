import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/colors.dart';
import '../providers/registration_provider.dart';
import 'steps/registration_step1_credentials.dart';
import 'steps/registration_step2_ktp.dart';

class RegistrationPageNew extends ConsumerWidget {
  const RegistrationPageNew({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(registrationProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundOffWhite,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textDark),
          onPressed: () {
            if (state.currentStep == 0) {
              context.go('/login');
            } else {
              ref.read(registrationProvider.notifier).previousStep();
            }
          },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: IndexedStack(
              index: state.currentStep,
              children: const [
                RegistrationStep1Credentials(),
                RegistrationStep2Ktp(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

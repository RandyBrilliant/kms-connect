import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/colors.dart';
import '../providers/app_lifecycle_provider.dart';
import '../widgets/professional/professional_button.dart';
import '../widgets/professional/professional_gradient_background.dart';
import 'app_update_service.dart';

class ForceUpdateState {
  const ForceUpdateState({
    this.updateRequired = false,
    this.storeUrl = '',
    this.androidImmediateAvailable = false,
  });

  final bool updateRequired;
  final String storeUrl;
  final bool androidImmediateAvailable;
}

class ForceUpdateNotifier extends StateNotifier<ForceUpdateState> {
  ForceUpdateNotifier(this._service) : super(const ForceUpdateState());

  final AppUpdateService _service;
  bool _immediateStarted = false;

  Future<void> check() async {
    final result = await _service.evaluate();
    if (!mounted) return;
    state = ForceUpdateState(
      updateRequired: result.updateRequired,
      storeUrl: result.storeUrl,
      androidImmediateAvailable: result.androidImmediateAvailable,
    );
    if (result.updateRequired &&
        result.androidImmediateAvailable &&
        !_immediateStarted) {
      _immediateStarted = true;
      await _service.startAndroidImmediateUpdate();
    }
  }

  Future<void> openStore() async {
    if (state.storeUrl.isEmpty) return;
    await _service.openStore(state.storeUrl);
  }
}

final forceUpdateProvider =
    StateNotifierProvider<ForceUpdateNotifier, ForceUpdateState>((ref) {
  return ForceUpdateNotifier(AppUpdateService());
});

/// Replaces the app UI with a non-dismissible update screen when the store
/// has a newer published version.
class ForceUpdateGate extends ConsumerStatefulWidget {
  const ForceUpdateGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ForceUpdateGate> createState() => _ForceUpdateGateState();
}

class _ForceUpdateGateState extends ConsumerState<ForceUpdateGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(forceUpdateProvider.notifier).check();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AppLifecycleState>(appLifecycleProvider, (previous, next) {
      if (previous != AppLifecycleState.resumed &&
          next == AppLifecycleState.resumed) {
        ref.read(forceUpdateProvider.notifier).check();
      }
    });

    final update = ref.watch(forceUpdateProvider);
    if (!update.updateRequired) return widget.child;

    return const _ForceUpdateScreen();
  }
}

class _ForceUpdateScreen extends ConsumerWidget {
  const _ForceUpdateScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: ProfessionalGradientBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(),
                  Container(
                    width: 96,
                    height: 96,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.system_update_alt_rounded,
                      size: 44,
                      color: AppColors.primaryDarkGreen,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Pembaruan diperlukan',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Versi baru KMS Connect sudah tersedia di toko aplikasi. '
                    'Perbarui sekarang untuk terus menggunakan layanan.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.9),
                      height: 1.45,
                    ),
                  ),
                  const Spacer(),
                  ProfessionalButton(
                    label: 'Perbarui sekarang',
                    icon: Icons.open_in_new_rounded,
                    onPressed: () =>
                        ref.read(forceUpdateProvider.notifier).openStore(),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

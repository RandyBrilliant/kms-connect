import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/widgets/auth_wave_header.dart';
import '../../../../core/widgets/phone_input_field.dart';
import '../../data/providers/staff_referrers_provider.dart';
import '../providers/registration_provider.dart';
import 'steps/registration_step2_ktp.dart';

/// Completion flow for users who signed in via Google but have no KTP / NIK
/// on file yet.
///
/// Step 0 — collect referral code (staff picker) + phone number.
/// Step 1 — upload KTP, OCR, confirm NIK / name (reuses [RegistrationStep2Ktp]).
class GoogleCompleteRegistrationPage extends ConsumerStatefulWidget {
  const GoogleCompleteRegistrationPage({super.key});

  @override
  ConsumerState<GoogleCompleteRegistrationPage> createState() =>
      _GoogleCompleteRegistrationPageState();
}

class _GoogleCompleteRegistrationPageState
    extends ConsumerState<GoogleCompleteRegistrationPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _headerOpacity;
  late final Animation<double> _headerScale;
  late final Animation<Offset> _panelSlide;
  late final Animation<double> _panelOpacity;

  @override
  void initState() {
    super.initState();

    // Mark this session as a Google completion flow so RegistrationStep2Ktp
    // knows to call completeGoogleRegistration() instead of completeRegistration().
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(registrationProvider.notifier).reset();
      ref.read(registrationProvider.notifier).setGoogleFlowData();
    });

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
    if (currentStep > 0) {
      ref.read(registrationProvider.notifier).previousStep();
    }
    // We intentionally do NOT navigate back to login from step 0 —
    // the user is already logged in via Google at this point.
  }

  @override
  Widget build(BuildContext context) {
    final currentStep = ref.watch(registrationProvider).currentStep;
    final cs = Theme.of(context).colorScheme;
    final size = MediaQuery.sizeOf(context);
    final safePad = MediaQuery.paddingOf(context);
    final headerH = math.max(size.height * 0.30, 220.0);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: cs.surface,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Wave header
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

          // Scrollable content
          SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const ClampingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: headerH * 0.18),

                // Header content
                FadeTransition(
                  opacity: _headerOpacity,
                  child: ScaleTransition(
                    scale: _headerScale,
                    child: _HeaderContent(currentStep: currentStep),
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
                            ? const _GoogleStep1(key: ValueKey(0))
                            : const RegistrationStep2Ktp(key: ValueKey(1)),
                      ),
                    ),
                  ),
                ),

                const _BottomInsetSpacer(),
              ],
            ),
          ),

          // Back button — only visible on step 1
          if (currentStep > 0)
            Positioned(
              top: safePad.top + 4,
              left: 4,
              child: FadeTransition(
                opacity: _headerOpacity,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 20),
                  onPressed: () => _handleBack(currentStep),
                  tooltip: 'Langkah sebelumnya',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header content
// ---------------------------------------------------------------------------

class _HeaderContent extends StatelessWidget {
  final int currentStep;
  const _HeaderContent({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Text(
          'Lengkapi Profil',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Akun Google berhasil terhubung.\nLengkapi data untuk melanjutkan.',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 16),
        _StepProgress(currentStep: currentStep),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _StepProgress extends StatelessWidget {
  final int currentStep;
  const _StepProgress({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Pill(active: currentStep == 0, label: '1'),
        const SizedBox(width: 8),
        Container(width: 24, height: 2, color: Colors.white54),
        const SizedBox(width: 8),
        _Pill(active: currentStep == 1, label: '2'),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final bool active;
  final String label;
  const _Pill({required this.active, required this.label});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: active ? 36 : 28,
      height: 28,
      decoration: BoxDecoration(
        color: active ? Colors.white : Colors.white.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: active
              ? Theme.of(context).colorScheme.primary
              : Colors.white.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 1 — staff picker + phone number
// ---------------------------------------------------------------------------

class _GoogleStep1 extends ConsumerStatefulWidget {
  const _GoogleStep1({super.key});

  @override
  ConsumerState<_GoogleStep1> createState() => _GoogleStep1State();
}

class _GoogleStep1State extends ConsumerState<_GoogleStep1> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _phoneFocus = FocusNode();

  StaffReferrer? _selectedStaff;

  @override
  void initState() {
    super.initState();
    // Pre-fetch staff list
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(staffReferrersProvider);
      // Restore state if user navigated back
      final s = ref.read(registrationProvider);
      if (s.phoneNumber?.isNotEmpty == true) {
        _phoneCtrl.text = s.phoneNumber!;
      }
    });
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  void _onStaffTap() async {
    final staffAsync = ref.read(staffReferrersProvider);
    final selected = await showModalBottomSheet<StaffReferrer>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StaffPickerSheet(
        staffAsync: staffAsync,
        initialSelected: _selectedStaff,
      ),
    );
    if (selected != null && mounted) {
      setState(() => _selectedStaff = selected);
    }
  }

  void _next() {
    if (!_formKey.currentState!.validate()) return;

    ref.read(registrationProvider.notifier).setGoogleFlowData(
          referralCode: _selectedStaff?.referralCode,
          phoneNumber: _phoneCtrl.text.trim().isEmpty
              ? null
              : _phoneCtrl.text.trim(),
        );
    ref.read(registrationProvider.notifier).nextStep();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 20),
          Text(
            'Data Pendukung',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pilih petugas pendamping dan masukkan nomor telepon Anda.',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 24),

          // Staff referrer picker
          _StaffReferrerField(
            selectedStaff: _selectedStaff,
            onTap: _onStaffTap,
          ),
          const SizedBox(height: 16),

          // Phone number
          PhoneInputField(
            controller: _phoneCtrl,
            focusNode: _phoneFocus,
            label: 'Nomor HP',
            validator: (v) {
              if (v == null || v.trim().isEmpty) return null;
              return validatePhoneNumber(v);
            },
          ),
          const SizedBox(height: 28),

          // Continue button
          FilledButton(
            onPressed: _next,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              'Lanjutkan',
              style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Staff referrer field (identical pattern to registration_step1_credentials)
// ---------------------------------------------------------------------------

class _StaffReferrerField extends StatelessWidget {
  final StaffReferrer? selectedStaff;
  final VoidCallback onTap;

  const _StaffReferrerField({
    required this.selectedStaff,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hasValue = selectedStaff != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Petugas Pendamping (Opsional)',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          suffixIcon: const Icon(Icons.arrow_drop_down),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        child: hasValue
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(selectedStaff!.fullName,
                      style: tt.bodyMedium
                          ?.copyWith(color: cs.onSurface)),
                  Text(
                    'Kode: ${selectedStaff!.referralCode}',
                    style: tt.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              )
            : Text(
                'Pilih petugas...',
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Staff picker bottom sheet (self-contained, with search)
// ---------------------------------------------------------------------------

class _StaffPickerSheet extends ConsumerStatefulWidget {
  final AsyncValue<List<StaffReferrer>> staffAsync;
  final StaffReferrer? initialSelected;

  const _StaffPickerSheet({
    required this.staffAsync,
    this.initialSelected,
  });

  @override
  ConsumerState<_StaffPickerSheet> createState() => _StaffPickerSheetState();
}

class _StaffPickerSheetState extends ConsumerState<_StaffPickerSheet> {
  final _searchCtrl = TextEditingController();
  List<StaffReferrer> _filtered = [];
  List<StaffReferrer> _all = [];

  @override
  void initState() {
    super.initState();
    widget.staffAsync.whenData((list) {
      _all = list;
      _filtered = list;
    });
    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.toLowerCase();
      setState(() {
        _filtered = q.isEmpty
            ? _all
            : _all
                .where((s) =>
                    s.fullName.toLowerCase().contains(q) ||
                    s.referralCode.toLowerCase().contains(q))
                .toList();
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final staffAsync = ref.watch(staffReferrersProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Pilih Petugas Pendamping',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Cari nama atau kode...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: staffAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Gagal memuat data',
                          style: TextStyle(color: cs.error)),
                      TextButton(
                        onPressed: () => ref.invalidate(staffReferrersProvider),
                        child: const Text('Coba lagi'),
                      ),
                    ],
                  ),
                ),
                data: (_) => ListView.builder(
                  controller: scrollController,
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) {
                    final staff = _filtered[i];
                    final isSelected =
                        staff.referralCode ==
                            widget.initialSelected?.referralCode;
                    return ListTile(
                      selected: isSelected,
                      selectedTileColor: cs.primaryContainer,
                      leading: CircleAvatar(
                        backgroundColor: cs.primaryContainer,
                        child: Text(
                          staff.fullName.isNotEmpty
                              ? staff.fullName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                              color: cs.onPrimaryContainer,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      title: Text(staff.fullName,
                          style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w600)),
                      subtitle: Text('Kode: ${staff.referralCode}'),
                      onTap: () => Navigator.of(context).pop(staff),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Keyboard inset spacer — isolates inset rebuild
// ---------------------------------------------------------------------------

class _BottomInsetSpacer extends StatelessWidget {
  const _BottomInsetSpacer();

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return SizedBox(height: math.max(inset + 24, 48));
  }
}

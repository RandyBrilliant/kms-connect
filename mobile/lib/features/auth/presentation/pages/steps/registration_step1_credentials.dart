import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/widgets/custom_toast.dart';
import '../../../../../core/widgets/google_logo_icon.dart';
import '../../../../../core/widgets/m3_text_field.dart';
import '../../../data/providers/staff_referrers_provider.dart';
import '../../providers/registration_provider.dart';

/// Step 1 of 2  email, password, confirm password, optional referral code.
///
/// Intentionally contains no header / step-indicator (the parent
/// [RegistrationPageNew] owns that).  Only the form and CTAs live here.
///
/// Performance note: text fields use [M3TextField] which derives all
/// [TextStyle]s from the ambient [Theme], avoiding per-keystroke
/// [TextStyle] allocations.
class RegistrationStep1Credentials extends ConsumerStatefulWidget {
  const RegistrationStep1Credentials({super.key});

  @override
  ConsumerState<RegistrationStep1Credentials> createState() =>
      _RegistrationStep1CredentialsState();
}

class _RegistrationStep1CredentialsState
    extends ConsumerState<RegistrationStep1Credentials> {
  final _formKey = GlobalKey<FormState>();

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  /// The currently selected staff referrer.
  StaffReferrer? _selectedStaff;

  @override
  void initState() {
    super.initState();
    // Restore email when returning from step 2.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = ref.read(registrationProvider);
      if (s.email?.isNotEmpty == true) _emailCtrl.text = s.email!;
      // Warm-up: pre-fetch staff list so the picker opens instantly.
      ref.read(staffReferrersProvider);
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  void _handleNext() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStaff == null) {
      CustomToast.show(
        context,
        message: 'Pilih staff penerima rujukan terlebih dahulu',
        type: ToastType.warning,
      );
      return;
    }
    ref.read(registrationProvider.notifier).setCredentials(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          referralCode: _selectedStaff!.referralCode,
        );
    ref.read(registrationProvider.notifier).nextStep();
  }

  /// Opens a searchable bottom-sheet to pick a staff referrer.
  Future<void> _showStaffPicker() async {
    final cs = Theme.of(context).colorScheme;
    final staffAsync = ref.read(staffReferrersProvider);

    final selected = await showModalBottomSheet<StaffReferrer>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => _StaffPickerSheet(
        staffAsync: staffAsync,
        initialSelected: _selectedStaff,
      ),
    );

    if (selected != null && mounted) {
      setState(() => _selectedStaff = selected);
    }
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
          //  Section label 
          const SizedBox(height: 20),
          Text(
            'Informasi Akun',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Langkah 1 dari 2  Masukkan email dan kata sandi',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 28),

          //  Email 
          M3TextField(
            controller: _emailCtrl,
            focusNode: _emailFocus,
            nextFocusNode: _passwordFocus,
            label: 'Email',
            hint: 'contoh@email.com',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email wajib diisi';
              if (!v.contains('@')) return 'Format email tidak valid';
              return null;
            },
          ),
          const SizedBox(height: 16),

          //  Password 
          M3TextField(
            controller: _passwordCtrl,
            focusNode: _passwordFocus,
            nextFocusNode: _confirmFocus,
            label: 'Kata Sandi',
            hint: 'Minimal 8 karakter',
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            suffixWidget: _VisibilityToggle(
              obscure: _obscurePassword,
              onTap: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Kata sandi wajib diisi';
              if (v.length < 8) return 'Minimal 8 karakter';
              return null;
            },
          ),
          const SizedBox(height: 16),

          //  Confirm password 
          M3TextField(
            controller: _confirmCtrl,
            focusNode: _confirmFocus,
            label: 'Konfirmasi Kata Sandi',
            hint: 'Ulangi kata sandi',
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: _obscureConfirm,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _handleNext(),
            suffixWidget: _VisibilityToggle(
              obscure: _obscureConfirm,
              onTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            validator: (v) {
              if (v != _passwordCtrl.text) return 'Kata sandi tidak cocok';
              return null;
            },
          ),
          const SizedBox(height: 16),

          //  Staff referrer picker 
          _StaffReferrerField(
            selectedStaff: _selectedStaff,
            onTap: _showStaffPicker,
          ),
          const SizedBox(height: 28),

          //  Next button 
          FilledButton(
            onPressed: _handleNext,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              'Selanjutnya',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(height: 28),

          //  OR divider 
          Row(
            children: [
              Expanded(child: Divider(color: cs.outlineVariant)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  'ATAU',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurfaceVariant,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              Expanded(child: Divider(color: cs.outlineVariant)),
            ],
          ),
          const SizedBox(height: 20),

          //  Google sign-up 
          OutlinedButton.icon(
            onPressed: () => CustomToast.show(
              context,
              message: 'Google Sign-In akan segera tersedia',
              type: ToastType.info,
            ),
            icon: const GoogleLogoIcon(),
            label: Text(
              'Daftar dengan Google',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: cs.onSurface,
              backgroundColor: cs.surface,
              side: BorderSide(color: cs.outlineVariant),
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 28),

          //  Login link 
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Sudah punya akun? ',
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              GestureDetector(
                onTap: () => context.go('/login'),
                child: Text(
                  'Masuk',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: cs.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

//  Reusable visibility-toggle icon 

class _VisibilityToggle extends StatelessWidget {
  final bool obscure;
  final VoidCallback onTap;
  const _VisibilityToggle({required this.obscure, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        size: 20,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onPressed: onTap,
      tooltip: obscure ? 'Tampilkan' : 'Sembunyikan',
    );
  }
}

// ── Staff referrer picker field ──────────────────────────────────────────────

/// Read-only tap-to-pick field that shows the selected staff name.
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
    final hasSelection = selectedStaff != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Staff Penerima Rujukan',
          floatingLabelBehavior: FloatingLabelBehavior.always,
          hintText: 'Pilih staff...',
          prefixIcon: Icon(Icons.person_outline_rounded,
              size: 20, color: cs.onSurfaceVariant),
          suffixIcon: Icon(Icons.arrow_drop_down_rounded,
              color: cs.onSurfaceVariant),
          errorText: null,
        ),
        isEmpty: !hasSelection,
        child: Text(
          hasSelection ? selectedStaff!.fullName : '',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: hasSelection ? cs.onSurface : cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

// ── Staff picker bottom sheet ─────────────────────────────────────────────────

/// Bottom sheet with a live-search list of staff referrers.
/// Wraps in [DraggableScrollableSheet] so it expands to full screen on
/// phones with many staff entries.
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
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearch);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch() {
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
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final staffAsync = ref.watch(staffReferrersProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (ctx, scrollController) {
        return Column(
          children: [
            // Handle
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                'Pilih Staff Penerima Rujukan',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
            ),
            // Search box
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Cari nama staff...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            FocusScope.of(context).unfocus();
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const Divider(height: 1),
            // Staff list
            Expanded(
              child: staffAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator.adaptive(),
                ),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.wifi_off_rounded,
                            size: 40, color: cs.onSurfaceVariant),
                        const SizedBox(height: 12),
                        Text(
                          'Gagal memuat daftar staff.\nPastikan koneksi internet aktif.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.tonal(
                          onPressed: () =>
                              ref.invalidate(staffReferrersProvider),
                          child: const Text('Coba lagi'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (list) {
                  // Sync full list once data arrives (covers the case where
                  // the sheet opened before the future resolved).
                  if (_all.isEmpty && list.isNotEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      setState(() {
                        _all = list;
                        _filtered = list;
                      });
                    });
                  }
                  if (_filtered.isEmpty) {
                    return Center(
                      child: Text(
                        'Tidak ada staff ditemukan',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: scrollController,
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final staff = _filtered[i];
                      final isSelected =
                          widget.initialSelected?.id == staff.id;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isSelected
                              ? cs.primary
                              : cs.primaryContainer,
                          child: Text(
                            staff.fullName.isNotEmpty
                                ? staff.fullName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: isSelected
                                  ? cs.onPrimary
                                  : cs.onPrimaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        title: Text(
                          staff.fullName,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          'Kode: ${staff.referralCode}',
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle_rounded,
                                color: cs.primary)
                            : null,
                        onTap: () => Navigator.of(context).pop(staff),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
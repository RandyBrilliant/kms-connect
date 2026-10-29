import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/utils/safe_navigation.dart';
import '../../../../core/widgets/custom_toast.dart';
import '../../../../core/widgets/professional/professional_button.dart';
import '../../../../core/widgets/professional/professional_card.dart';
import '../../../../core/widgets/professional/professional_gradient_background.dart';
import '../../../../core/widgets/professional_text_field.dart';
import '../../data/providers/profile_provider.dart';
import '../../domain/indonesian_banks.dart';
import '../../domain/models/applicant_profile.dart';
import '../widgets/option_picker_field.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

/// Data Rekening PMI — unlocked after lulus interview (like post-interview
/// documents). Saved separately from Edit Profil so it stays editable after
/// the profile is ACCEPTED (backend allows rekening-only PATCH then).
class BankAccountPage extends ConsumerStatefulWidget {
  const BankAccountPage({super.key});

  @override
  ConsumerState<BankAccountPage> createState() => _BankAccountPageState();
}

class _BankAccountPageState extends ConsumerState<BankAccountPage> {
  final _formKey = GlobalKey<FormState>();
  final _holder = TextEditingController();
  final _noRek = TextEditingController();
  String? _bank;
  bool _populated = false;

  @override
  void dispose() {
    _holder.dispose();
    _noRek.dispose();
    super.dispose();
  }

  void _populate(ApplicantProfile p) {
    _populated = true;
    final bank = (p.bank ?? '').trim().toUpperCase();
    _bank = bank.isEmpty ? null : bank;
    _holder.text = (p.bankAccountHolder ?? '').toUpperCase();
    _noRek.text = p.noRek ?? '';
  }

  Future<void> _handleSave() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final notifier = ref.read(profileNotifierProvider.notifier);
    final success = await notifier.updateProfile({
      'bank': _bank,
      'bank_account_holder': _holder.text.trim(),
      'no_rek': _noRek.text.trim(),
    });
    if (!mounted) return;
    if (!success) {
      CustomToast.show(
        context,
        message: ref.read(profileNotifierProvider).error ??
            'Gagal menyimpan data rekening.',
        type: ToastType.error,
      );
      return;
    }
    CustomToast.showGlobal(
      message: 'Data rekening berhasil disimpan.',
      type: ToastType.success,
    );
    runWhenNavigatorUnlocked(() {
      if (!mounted) return;
      Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileNotifierProvider);
    final profile = profileState.profile;
    if (profile != null && !_populated) _populate(profile);

    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    const accent = Color(0xFF0A7A43);
    final unlocked = profile?.hasLulusInterview ?? false;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.transparent,
      body: ProfessionalGradientBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 20, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white),
                      tooltip: 'Kembali',
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Data Rekening PMI',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Rekening untuk pengembalian biaya / transfer',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.88),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: profile == null
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          4,
                          20,
                          24 + bottomInset + bottomPad,
                        ),
                        child: ProfessionalCard(
                          child: Padding(
                            padding: const EdgeInsets.all(22),
                            child: unlocked
                                ? _buildForm(profileState.isLoading, accent)
                                : _buildLocked(accent),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocked(Color accent) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.lock_outline_rounded, size: 22, color: accent),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Data rekening dapat diisi setelah Anda lulus interview.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForm(bool isSaving, Color accent) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withValues(alpha: 0.22)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 20, color: accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Pastikan nama penerima dan nomor rekening sesuai buku '
                    'tabungan agar transfer tidak gagal.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          OptionPickerField<String>(
            label: 'Bank',
            prefixIcon: Icons.account_balance_outlined,
            value: _bank,
            hint: 'Cari atau pilih bank',
            emptyErrorText: 'Bank wajib dipilih',
            items: kIndonesianBanks,
            onChanged: (v) => setState(() => _bank = v),
          ),
          const SizedBox(height: 14),
          ProfessionalTextField(
            controller: _holder,
            label: 'Nama Penerima',
            hintText: 'Sesuai buku tabungan',
            prefixIcon: Icons.person_outline_rounded,
            upperCase: true,
            emptyErrorText: 'Nama penerima wajib diisi',
          ),
          const SizedBox(height: 14),
          ProfessionalTextField(
            controller: _noRek,
            label: 'Nomor Rekening',
            hintText: 'Angka saja',
            prefixIcon: Icons.numbers_rounded,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            emptyErrorText: 'Nomor rekening wajib diisi',
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onSubmitted: (_) => _handleSave(),
          ),
          const SizedBox(height: 28),
          ProfessionalButton(
            label: 'Simpan Data Rekening',
            icon: Icons.save_rounded,
            isLoading: isSaving,
            onPressed: isSaving ? null : _handleSave,
          ),
        ],
      ),
    );
  }
}

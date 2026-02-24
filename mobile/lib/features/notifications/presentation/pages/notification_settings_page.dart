import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../config/colors.dart';
import '../../../../core/widgets/auth_wave_header.dart';
import '../../../../core/widgets/custom_toast.dart';
import '../../data/providers/notification_settings_provider.dart';
import '../../data/services/notification_settings_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class NotificationSettingsPage extends ConsumerStatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  ConsumerState<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState
    extends ConsumerState<NotificationSettingsPage> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // Re-check OS permission when user returns from system Settings.
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh OS permission status in case the user changed it in Settings.
      ref.read(notificationSettingsProvider.notifier).refreshOsPermission();
    }
  }

  Future<void> _onToggle() async {
    final result =
        await ref.read(notificationSettingsProvider.notifier).toggle();

    if (!mounted) return;

    if (result == EnableResult.permissionDenied) {
      CustomToast.show(
        context,
        message: 'Izin notifikasi ditolak oleh sistem.',
        type: ToastType.warning,
      );
      // Offer to open system settings.
      _showPermissionDialog();
    } else if (result == EnableResult.success) {
      CustomToast.show(
        context,
        message: 'Notifikasi push berhasil diaktifkan.',
        type: ToastType.success,
      );
    }
  }

  void _showPermissionDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Izin Diperlukan'),
        content: const Text(
          'Aktifkan izin notifikasi untuk aplikasi ini di Pengaturan sistem agar dapat menerima pemberitahuan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Nanti'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryDarkGreen),
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Buka Pengaturan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsState = ref.watch(notificationSettingsProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    const headerH = 140.0;
    final topPad = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      body: Column(
        children: [
          // ── Wave header ──────────────────────────────────────────────────
          SizedBox(
            height: headerH + topPad,
            child: Stack(
              children: [
                Positioned.fill(child: AuthWaveHeader(height: headerH + topPad)),
                Padding(
                  padding: EdgeInsets.fromLTRB(16, topPad + 10, 16, 0),
                  child: Row(
                    children: [
                      _CircleBackButton(onTap: () => Navigator.pop(context)),
                      const SizedBox(width: 14),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pengaturan Notifikasi',
                            style: tt.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Kelola preferensi notifikasi',
                            style: tt.bodySmall
                                ?.copyWith(color: Colors.white70),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Body ─────────────────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              children: [
                // Push notifications toggle card
                _SettingsCard(
                  children: [
                    _ToggleRow(
                      icon: Icons.notifications_rounded,
                      iconColor: AppColors.primaryDarkGreen,
                      iconBg: AppColors.secondaryLightGreen,
                      title: 'Notifikasi Push',
                      subtitle: settingsState.isLoading
                          ? 'Memproses…'
                          : settingsState.isEnabled
                              ? 'Aktif — pesan baru akan dikirim ke perangkat ini'
                              : 'Nonaktif — tidak ada notifikasi yang akan dikirim',
                      value: settingsState.isEnabled,
                      isLoading: settingsState.isLoading,
                      onChanged: settingsState.isLoading ? null : (_) => _onToggle(),
                    ),
                  ],
                ),

                // OS permission warning
                if (!settingsState.osPermissionGranted && settingsState.isEnabled) ...[
                  const SizedBox(height: 12),
                  _PermissionWarningCard(
                    onOpenSettings: _showPermissionDialog,
                  ),
                ],

                const SizedBox(height: 20),

                // Info section ─ what kinds of notifications we send
                _SettingsCard(
                  label: 'Jenis Notifikasi',
                  children: [
                    _InfoRow(
                      icon: Icons.work_outline_rounded,
                      iconColor: const Color(0xFF2563EB),
                      iconBg: const Color(0xFFDBEAFE),
                      title: 'Lowongan Pekerjaan',
                      subtitle: 'Pemberitahuan lowongan baru yang sesuai profil Anda',
                    ),
                    _Divider(),
                    _InfoRow(
                      icon: Icons.folder_open_outlined,
                      iconColor: const Color(0xFFD97706),
                      iconBg: const Color(0xFFFEF3C7),
                      title: 'Status Dokumen',
                      subtitle: 'Hasil review dokumen yang Anda unggah',
                    ),
                    _Divider(),
                    _InfoRow(
                      icon: Icons.assignment_outlined,
                      iconColor: AppColors.success,
                      iconBg: const Color(0xFFD1FAE5),
                      title: 'Status Lamaran',
                      subtitle: 'Pembaruan status pengajuan lamaran Anda',
                    ),
                    _Divider(),
                    _InfoRow(
                      icon: Icons.campaign_outlined,
                      iconColor: AppColors.info,
                      iconBg: const Color(0xFFCFFAFE),
                      title: 'Pengumuman',
                      subtitle: 'Informasi dan pengumuman dari KMS Connect',
                    ),
                  ],
                ),

                // Error banner (if any)
                if (settingsState.error != null) ...[
                  const SizedBox(height: 16),
                  _ErrorBanner(message: settingsState.error!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _CircleBackButton extends StatelessWidget {
  const _CircleBackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.18),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children, this.label});
  final List<Widget> children;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              label!,
              style: tt.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
        Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.isLoading,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final bool value;
  final bool isLoading;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: tt.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style:
                      tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          isLoading
              ? const SizedBox(
                  width: 36,
                  height: 20,
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : Switch.adaptive(
                  value: value,
                  onChanged: onChanged,
                  activeThumbColor: AppColors.primaryDarkGreen,
                  activeTrackColor: AppColors.secondaryLightGreen,
                ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: tt.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  style: tt.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 68,
      endIndent: 0,
      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
    );
  }
}

class _PermissionWarningCard extends StatelessWidget {
  const _PermissionWarningCard({required this.onOpenSettings});
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.warning, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Izin sistem belum diberikan',
                    style: tt.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF92400E),
                    )),
                const SizedBox(height: 2),
                Text(
                  'Anda harus mengizinkan notifikasi di Pengaturan sistem agar push notification dapat diterima.',
                  style: tt.bodySmall
                      ?.copyWith(color: const Color(0xFF92400E)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            style: TextButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                    color: AppColors.warning.withValues(alpha: 0.6)),
              ),
            ),
            onPressed: onOpenSettings,
            child: Text(
              'Izinkan',
              style: tt.labelSmall?.copyWith(
                color: AppColors.warning,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE4E6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: tt.bodySmall
                  ?.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

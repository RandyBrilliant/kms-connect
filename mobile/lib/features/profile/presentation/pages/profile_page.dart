import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../config/colors.dart';
import '../../../../config/strings.dart';
import '../../../home/presentation/widgets/bottom_nav_bar.dart';
import '../../data/providers/profile_provider.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.profile),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              context.push('/profile/edit');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: profileAsync.when(
              data: (profile) => _buildProfileContent(context, ref, profile),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                    const SizedBox(height: 16),
                    Text('Error: $error'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.refresh(profileProvider),
                      child: const Text(AppStrings.retry),
                    ),
                  ],
                ),
              ),
            ),
          ),
          BottomNavBar(currentRoute: '/profile'),
        ],
      ),
    );
  }

  Widget _buildProfileContent(
    BuildContext context,
    WidgetRef ref,
    profile,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Card
          Card(
            color: _getStatusColor(profile.verificationStatus),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    _getStatusIcon(profile.verificationStatus),
                    color: AppColors.white,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Status Verifikasi',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.white.withOpacity(0.9),
                              ),
                        ),
                        Text(
                          profile.verificationStatusDisplay,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: AppColors.white,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (profile.canSubmit)
                    ElevatedButton(
                      onPressed: () => _handleSubmitForVerification(context, ref),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.white,
                        foregroundColor: AppColors.primaryDarkGreen,
                      ),
                      child: const Text('Kirim'),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Personal Data Section
          _buildSection(
            context,
            'Data Pribadi',
            [
              _buildInfoRow('Nama Lengkap', profile.fullName ?? '-'),
              _buildInfoRow('NIK', profile.nik ?? '-'),
              _buildInfoRow('Tempat Lahir', profile.birthPlace ?? '-'),
              _buildInfoRow(
                'Tanggal Lahir',
                profile.birthDate != null
                    ? DateFormat('dd MMMM yyyy', 'id_ID').format(profile.birthDate!)
                    : '-',
              ),
              _buildInfoRow('Jenis Kelamin', profile.gender == 'M' ? 'Laki-laki' : profile.gender == 'F' ? 'Perempuan' : '-'),
              _buildInfoRow('Alamat', profile.address ?? '-'),
              _buildInfoRow('No. HP', profile.contactPhone ?? '-'),
            ],
          ),

          const SizedBox(height: 16),

          // Family Data Section (Optional)
          if (profile.fatherName != null ||
              profile.motherName != null ||
              profile.spouseName != null)
            _buildSection(
              context,
              'Data Keluarga',
              [
                if (profile.fatherName != null) ...[
                  _buildInfoRow('Nama Ayah', profile.fatherName ?? '-'),
                  _buildInfoRow('Umur Ayah', profile.fatherAge?.toString() ?? '-'),
                  _buildInfoRow('Pekerjaan Ayah', profile.fatherOccupation ?? '-'),
                ],
                if (profile.motherName != null) ...[
                  _buildInfoRow('Nama Ibu', profile.motherName ?? '-'),
                  _buildInfoRow('Umur Ibu', profile.motherAge?.toString() ?? '-'),
                  _buildInfoRow('Pekerjaan Ibu', profile.motherOccupation ?? '-'),
                ],
                if (profile.spouseName != null) ...[
                  _buildInfoRow('Nama Suami/Istri', profile.spouseName ?? '-'),
                  _buildInfoRow('Umur Suami/Istri', profile.spouseAge?.toString() ?? '-'),
                  _buildInfoRow('Pekerjaan Suami/Istri', profile.spouseOccupation ?? '-'),
                ],
                if (profile.familyAddress != null)
                  _buildInfoRow('Alamat Keluarga', profile.familyAddress ?? '-'),
                if (profile.familyContactPhone != null)
                  _buildInfoRow('No. HP Keluarga', profile.familyContactPhone ?? '-'),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDarkGreen,
                  ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: AppColors.textMedium,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppColors.textDark),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'DRAFT':
        return AppColors.textLight;
      case 'SUBMITTED':
        return AppColors.info;
      case 'ACCEPTED':
        return AppColors.success;
      case 'REJECTED':
        return AppColors.error;
      default:
        return AppColors.textLight;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'DRAFT':
        return Icons.edit_outlined;
      case 'SUBMITTED':
        return Icons.hourglass_empty;
      case 'ACCEPTED':
        return Icons.check_circle;
      case 'REJECTED':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  Future<void> _handleSubmitForVerification(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(profileNotifierProvider.notifier);
    final success = await notifier.submitForVerification();

    if (context.mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil berhasil dikirim untuk verifikasi'),
            backgroundColor: AppColors.success,
          ),
        );
        ref.refresh(profileProvider);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(notifier.state.error ?? 'Gagal mengirim profil'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

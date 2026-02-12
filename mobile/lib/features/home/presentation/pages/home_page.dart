import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/colors.dart';
import '../../../../config/strings.dart';
import '../../../auth/data/providers/auth_provider.dart';
import '../widgets/bottom_nav_bar.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authStateProvider.notifier).logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    Text(
                      'Selamat Datang!',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    if (user != null) ...[
                      Text(
                        user.email,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      if (user.fullName != null && user.fullName!.isNotEmpty)
                        Text(
                          user.fullName!,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.textMedium,
                              ),
                        ),
                    ],
                    const SizedBox(height: 32),
                    // Quick Actions
                    Text(
                      'Akses Cepat',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.5,
                      children: [
                        _buildQuickActionCard(
                          context,
                          icon: Icons.person,
                          title: 'Profil',
                          color: AppColors.primaryDarkGreen,
                          onTap: () => context.push('/profile'),
                        ),
                        _buildQuickActionCard(
                          context,
                          icon: Icons.folder,
                          title: 'Dokumen',
                          color: AppColors.info,
                          onTap: () => context.push('/documents'),
                        ),
                        _buildQuickActionCard(
                          context,
                          icon: Icons.work,
                          title: 'Lowongan',
                          color: AppColors.success,
                          onTap: () => context.go('/jobs'),
                        ),
                        _buildQuickActionCard(
                          context,
                          icon: Icons.article,
                          title: 'Berita',
                          color: AppColors.warning,
                          onTap: () => context.go('/news'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            BottomNavBar(currentRoute: '/home'),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

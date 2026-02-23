import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/colors.dart';

class BottomNavBar extends StatelessWidget {
  final String currentRoute;

  const BottomNavBar({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFF1F5F9), width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
          child: Row(
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Beranda',
                isActive: currentRoute == '/home',
                onTap: () => context.go('/home'),
              ),
              _NavItem(
                icon: Icons.work_outline,
                activeIcon: Icons.work,
                label: 'Lowongan',
                isActive: currentRoute == '/jobs',
                onTap: () => context.go('/jobs'),
              ),
              _NavItem(
                icon: Icons.newspaper_outlined,
                activeIcon: Icons.newspaper,
                label: 'Berita',
                isActive: currentRoute == '/news',
                onTap: () => context.go('/news'),
              ),
              _NavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Profil',
                isActive: currentRoute == '/profile',
                onTap: () => context.go('/profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pill background only on active tab
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              height: 36,
              width: isActive ? 64 : 36,
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.primaryDarkGreen.withOpacity(0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Icon(
                  isActive ? activeIcon : icon,
                  size: 24,
                  color: isActive
                      ? AppColors.primaryDarkGreen
                      : const Color(0xFF94A3B8),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight:
                    isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive
                    ? AppColors.primaryDarkGreen
                    : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

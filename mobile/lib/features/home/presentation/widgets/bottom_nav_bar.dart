import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../config/colors.dart';

// Professional navigation destinations with enhanced icons
const _kDestinations = [
  _NavDestination(
    route: '/home',
    icon: Icons.dashboard_outlined,
    activeIcon: Icons.dashboard_rounded,
    label: 'Beranda',
  ),
  _NavDestination(
    route: '/jobs',
    icon: Icons.work_outline_rounded,
    activeIcon: Icons.work_rounded,
    label: 'Lowongan',
  ),
  _NavDestination(
    route: '/jobs/my-applications',
    icon: Icons.description_outlined,
    activeIcon: Icons.description_rounded,
    label: 'Lamaranku',
  ),
  _NavDestination(
    route: '/news',
    icon: Icons.campaign_outlined,
    activeIcon: Icons.campaign_rounded,
    label: 'Berita',
  ),
  _NavDestination(
    route: '/profile',
    icon: Icons.person_outline_rounded,
    activeIcon: Icons.person_rounded,
    label: 'Profil',
  ),
];

/// Professional bottom navigation bar with enhanced Material Design 3 styling.
///
/// Features:
/// - Clean professional appearance with subtle shadows
/// - Enhanced active state indicators
/// - Professional icon selection
/// - Consistent green theming
/// - Smooth animations and interactions
class BottomNavBar extends ConsumerWidget {
  const BottomNavBar({super.key, required this.currentRoute});

  final String currentRoute;

  int get _selectedIndex {
    final idx = _kDestinations.indexWhere((d) => d.route == currentRoute);
    return idx < 0 ? 0 : idx;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: AppColors.divider.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: 80, // Increased height to prevent overflow
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12), // Adjusted padding
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (int i = 0; i < _kDestinations.length; i++)
                _ProfessionalNavItem(
                  destination: _kDestinations[i],
                  isSelected: i == _selectedIndex,
                  onTap: () {
                    final target = _kDestinations[i].route;
                    if (target == currentRoute) return;
                    context.go(target);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Individual navigation item with professional styling
class _ProfessionalNavItem extends StatelessWidget {
  const _ProfessionalNavItem({
    required this.destination,
    required this.isSelected,
    required this.onTap,
  });

  final _NavDestination destination;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6), // Reduced padding
            decoration: BoxDecoration(
              color: isSelected 
                  ? AppColors.primaryDarkGreen.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon with enhanced styling
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.all(2), // Reduced padding around icon
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? AppColors.primaryDarkGreen.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isSelected ? destination.activeIcon : destination.icon,
                    size: 20, // Slightly smaller icon
                    color: isSelected 
                        ? AppColors.primaryDarkGreen 
                        : AppColors.textMedium,
                  ),
                ),
                
                const SizedBox(height: 2), // Reduced spacing
                
                // Label with professional typography
                Flexible( // Use Flexible to prevent overflow
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10, // Slightly smaller font
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected 
                          ? AppColors.primaryDarkGreen 
                          : AppColors.textMedium,
                      letterSpacing: 0.2,
                    ),
                    child: Text(
                      destination.label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal data holder
// ─────────────────────────────────────────────────────────────────────────────

class _NavDestination {
  const _NavDestination({
    required this.route,
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final String route;
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

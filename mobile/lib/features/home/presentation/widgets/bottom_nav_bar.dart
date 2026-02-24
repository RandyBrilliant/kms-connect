import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/colors.dart';

// Ordered list of destinations — index maps directly to the M3 NavigationBar.
const _kDestinations = [
  _NavDestination(
    route: '/home',
    icon: Icons.home_outlined,
    activeIcon: Icons.home_rounded,
    label: 'Beranda',
  ),
  _NavDestination(
    route: '/jobs',
    icon: Icons.work_outline_rounded,
    activeIcon: Icons.work_rounded,
    label: 'Lowongan',
  ),
  _NavDestination(
    route: '/news',
    icon: Icons.newspaper_outlined,
    activeIcon: Icons.newspaper_rounded,
    label: 'Berita',
  ),
  _NavDestination(
    route: '/profile',
    icon: Icons.person_outline_rounded,
    activeIcon: Icons.person_rounded,
    label: 'Profil',
  ),
];

/// M3 bottom navigation bar shared across all main screens.
///
/// Pass [currentRoute] from the active page so the correct destination is
/// highlighted. Uses Flutter's [NavigationBar] widget which provides the M3
/// indicator pill, label animation, and ink ripple out of the box.
class BottomNavBar extends StatelessWidget {
  const BottomNavBar({super.key, required this.currentRoute});

  final String currentRoute;

  int get _selectedIndex {
    final idx = _kDestinations.indexWhere((d) => d.route == currentRoute);
    return idx < 0 ? 0 : idx;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return NavigationBar(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (i) => context.go(_kDestinations[i].route),
      backgroundColor: cs.surface,
      indicatorColor: AppColors.primaryDarkGreen.withValues(alpha: 0.12),
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      height: 64,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: [
        for (final d in _kDestinations)
          NavigationDestination(
            icon: Icon(d.icon),
            selectedIcon: Icon(d.activeIcon,
                color: AppColors.primaryDarkGreen),
            label: d.label,
          ),
      ],
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



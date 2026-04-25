import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Tracks bottom-tab navigation direction so route transitions can slide
/// according to tab order.
class MainTabTransition {
  static int _lastTabIndex = 0;

  static int tabIndexForLocation(String location) {
    if (location == '/home') return 0;
    if (location == '/jobs') return 1;
    if (location == '/jobs/my-applications') return 2;
    if (location == '/news') return 3;
    if (location == '/profile') return 4;
    return -1;
  }

  /// Returns:
  /// -1 when moving to a lower-index tab
  ///  1 when moving to a higher-index tab
  ///  0 when unchanged/unknown
  static int consumeDirectionFor(String location) {
    final next = tabIndexForLocation(location);
    if (next < 0) return 0;
    final prev = _lastTabIndex;
    _lastTabIndex = next;
    if (next == prev) return 0;
    return next > prev ? 1 : -1;
  }

  static CustomTransitionPage<void> buildPage({
    required LocalKey key,
    required Widget child,
    required String location,
  }) {
    final direction = consumeDirectionFor(location);
    final begin = switch (direction) {
      1 => const Offset(-0.10, 0), // higher index: left -> right movement
      -1 => const Offset(0.10, 0), // lower index: right -> left movement
      _ => Offset.zero,
    };

    return CustomTransitionPage<void>(
      key: key,
      child: child,
      transitionDuration: const Duration(milliseconds: 240),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      transitionsBuilder: (context, animation, secondaryAnimation, pageChild) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(begin: begin, end: Offset.zero).animate(curved),
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.94, end: 1).animate(curved),
            child: pageChild,
          ),
        );
      },
    );
  }
}

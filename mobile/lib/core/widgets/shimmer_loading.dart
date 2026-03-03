import 'package:flutter/material.dart';

/// A lightweight shimmer/skeleton loading placeholder.
///
/// Renders an animated gradient sweep that gives visual feedback while
/// content is loading — much better UX than a centered spinner for list-heavy
/// screens like Jobs, News, Documents, etc.
///
/// Usage:
/// ```dart
/// ShimmerBox(width: 120, height: 16) // text line
/// ShimmerBox(width: double.infinity, height: 80, borderRadius: 16) // card
/// ```
class ShimmerBox extends StatefulWidget {
  const ShimmerBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 8,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = cs.surfaceContainerHighest.withValues(alpha: 0.5);
    final highlight = cs.surfaceContainerHighest.withValues(alpha: 0.15);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _ctrl.value, 0),
              end: Alignment(1.0 + 2.0 * _ctrl.value, 0),
              colors: [base, highlight, base],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// Pre-built shimmer skeleton for a card-style list item.
/// Mimics a typical job/news card layout.
class ShimmerCard extends StatelessWidget {
  const ShimmerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const ShimmerBox(width: 46, height: 46, borderRadius: 12),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(
                        width: MediaQuery.of(context).size.width * 0.45,
                        height: 14,
                      ),
                      const SizedBox(height: 8),
                      const ShimmerBox(width: 100, height: 12),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const ShimmerBox(width: double.infinity, height: 1),
            const SizedBox(height: 14),
            Row(
              children: [
                const ShimmerBox(width: 80, height: 24, borderRadius: 8),
                const SizedBox(width: 8),
                const ShimmerBox(width: 80, height: 24, borderRadius: 8),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A column of [count] shimmer cards for list loading states.
class ShimmerList extends StatelessWidget {
  const ShimmerList({super.key, this.count = 5});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(count, (_) => const ShimmerCard()),
    );
  }
}

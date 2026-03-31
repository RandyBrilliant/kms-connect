import 'package:flutter/material.dart';

/// Elevated white card used by redesigned auth screens.
class ProfessionalCard extends StatelessWidget {
  const ProfessionalCard({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 6,
      borderRadius: BorderRadius.circular(20),
      child: child,
    );
  }
}

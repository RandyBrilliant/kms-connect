import 'package:flutter/material.dart';

/// Shared primary button for redesigned auth flow.
class ProfessionalButton extends StatelessWidget {
  const ProfessionalButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final disabled = isLoading || onPressed == null;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        onPressed: disabled ? null : onPressed,
        icon: isLoading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: cs.onPrimary,
                ),
              )
            : Icon(icon ?? Icons.arrow_forward_rounded, size: 18),
        label: Text(label),
      ),
    );
  }
}

/// Outlined companion to [ProfessionalButton] (e.g. secondary actions on auth screens).
class ProfessionalOutlinedButton extends StatelessWidget {
  const ProfessionalOutlinedButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final disabled = isLoading || onPressed == null;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: disabled ? null : onPressed,
        icon: isLoading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: cs.primary,
                ),
              )
            : Icon(icon ?? Icons.arrow_forward_rounded, size: 18),
        label: Text(label),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../utils/safe_navigation.dart';

/// Tappable read-only dropdown-like input field.
class ProfessionalDropdownField extends StatelessWidget {
  const ProfessionalDropdownField({
    super.key,
    this.controller,
    this.valueText,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    required this.onTap,
    this.validator,
    this.enabled = true,
  }) : assert(
          controller != null || valueText != null,
          'Either controller or valueText must be provided.',
        );

  final TextEditingController? controller;
  final String? valueText;
  final String label;
  final String hint;
  final IconData prefixIcon;
  final VoidCallback onTap;
  final String? Function(String?)? validator;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextFormField(
      key: controller == null ? ValueKey(valueText ?? '') : null,
      controller: controller,
      initialValue: controller == null ? (valueText ?? '') : null,
      enabled: enabled,
      readOnly: true,
      canRequestFocus: false,
      onTap: enabled
          ? () {
              runWhenNavigatorUnlocked(onTap);
            }
          : null,
      validator: validator,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
        hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.45),
              fontWeight: FontWeight.w500,
            ),
        prefixIcon: Icon(prefixIcon, size: 20, color: cs.onSurfaceVariant),
        suffixIcon: Icon(Icons.arrow_drop_down_rounded, color: cs.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.error, width: 1.6),
        ),
      ),
    );
  }
}

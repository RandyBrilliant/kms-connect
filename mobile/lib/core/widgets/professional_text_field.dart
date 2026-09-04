import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/formatters.dart';
import '../utils/safe_navigation.dart';

/// Redesigned auth text field with explicit visual style.
class ProfessionalTextField extends StatefulWidget {
  const ProfessionalTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hintText,
    required this.prefixIcon,
    this.focusNode,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.validator,
    this.obscureText = false,
    this.suffixIcon,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.upperCase = false,
    this.readOnly = false,
    this.onTap,
    this.maxLines = 1,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final IconData prefixIcon;
  final FocusNode? focusNode;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final String? Function(String?)? validator;
  final bool obscureText;
  final Widget? suffixIcon;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  /// When true, typed text is forced to uppercase. Opt in for KTP/biodata
  /// fields only — never for email, password, or codes.
  final bool upperCase;
  final bool readOnly;
  final VoidCallback? onTap;
  final int maxLines;
  final bool enabled;

  @override
  State<ProfessionalTextField> createState() => _ProfessionalTextFieldState();
}

class _ProfessionalTextFieldState extends State<ProfessionalTextField> {
  FocusNode? _internalNode;
  FocusNode? _listenedNode;

  FocusNode get _focusNode => widget.focusNode ?? (_internalNode ??= FocusNode());

  void _handleFocusChange() {
    if (!_focusNode.hasFocus) return;
    Future.delayed(const Duration(milliseconds: 250), () {
      if (!mounted || !_focusNode.hasFocus) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeInOut,
        alignment: 0.25,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _listenedNode = _focusNode;
    _listenedNode?.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant ProfessionalTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      _listenedNode?.removeListener(_handleFocusChange);
      _listenedNode = _focusNode;
      _listenedNode?.addListener(_handleFocusChange);
    }
  }

  @override
  void dispose() {
    _listenedNode?.removeListener(_handleFocusChange);
    _internalNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return TextFormField(
      controller: widget.controller,
      focusNode: _focusNode,
      enabled: widget.enabled,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onSubmitted,
      validator: widget.validator,
      obscureText: widget.obscureText,
      readOnly: widget.readOnly,
      onTap: widget.onTap == null
          ? null
          : () {
              runWhenNavigatorUnlocked(() {
                if (!mounted) return;
                widget.onTap!();
              });
            },
      maxLines: widget.maxLines,
      autocorrect: !widget.obscureText &&
          widget.keyboardType != TextInputType.emailAddress,
      enableSuggestions: !widget.obscureText &&
          widget.keyboardType != TextInputType.emailAddress,
      inputFormatters: [
        if (widget.upperCase) const UpperCaseTextInputFormatter(),
        ...?widget.inputFormatters,
      ],
      textCapitalization: widget.textCapitalization,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hintText,
        prefixIcon: Icon(widget.prefixIcon, size: 20, color: cs.primary),
        suffixIcon: widget.suffixIcon,
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

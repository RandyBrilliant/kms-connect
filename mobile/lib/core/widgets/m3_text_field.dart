import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/formatters.dart';

/// Reusable M3 "filled" text field.
///
/// All colours and text styles come from the ambient [Theme] rather than
/// being allocated inline with [GoogleFonts], which prevents per-keystroke
/// [TextStyle] allocations and keeps input feeling smooth.
///
/// Implemented as a [StatefulWidget] so the derived [TextStyle] is cached in
/// [didChangeDependencies] — it is only recomputed when the theme actually
/// changes (essentially once at startup), not on every parent rebuild.
///
/// For read-only picker-style fields pass [readOnly] = `true` and supply an
/// [onTap] handler. The cursor is hidden automatically in that mode.
class M3TextField extends StatefulWidget {
  const M3TextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    this.focusNode,
    this.nextFocusNode,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.textCapitalization = TextCapitalization.none,
    this.suffixWidget,
    this.inputFormatters,
    this.validator,
    this.onSubmitted,
    this.maxLines = 1,
    this.readOnly = false,
    this.onTap,
    this.autofillHints,
    this.upperCase = false,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final FocusNode? nextFocusNode;
  final String label;
  final String hint;
  final IconData prefixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final TextCapitalization textCapitalization;
  final Widget? suffixWidget;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;
  final int maxLines;
  final bool readOnly;
  final VoidCallback? onTap;
  final Iterable<String>? autofillHints;

  /// When `true`, forces all typed characters to uppercase and sets keyboard
  /// capitalisation to [TextCapitalization.characters].
  /// Programmatic assignments to [controller] must also call `.toUpperCase()`.
  final bool upperCase;

  @override
  State<M3TextField> createState() => _M3TextFieldState();
}

class _M3TextFieldState extends State<M3TextField> {
  // Cached once per theme change — zero allocation on every build() call.
  late TextStyle _style;
  late Color _iconColor;
  late FocusNode _effectiveFocusNode;
  bool _ownsNode = false;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode != null) {
      _effectiveFocusNode = widget.focusNode!;
    } else {
      _effectiveFocusNode = FocusNode();
      _ownsNode = true;
    }
    _effectiveFocusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_effectiveFocusNode.hasFocus) return;
    // Defer until the keyboard has finished animating so ensureVisible has the
    // correct final layout to scroll to.
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.5,
      );
    });
  }

  @override
  void didUpdateWidget(M3TextField old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      _effectiveFocusNode.removeListener(_onFocusChange);
      if (_ownsNode) {
        _effectiveFocusNode.dispose();
        _ownsNode = false;
      }
      if (widget.focusNode != null) {
        _effectiveFocusNode = widget.focusNode!;
      } else {
        _effectiveFocusNode = FocusNode();
        _ownsNode = true;
      }
      _effectiveFocusNode.addListener(_onFocusChange);
    }
  }

  @override
  void dispose() {
    _effectiveFocusNode.removeListener(_onFocusChange);
    if (_ownsNode) _effectiveFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final cs = Theme.of(context).colorScheme;
    // textTheme already uses Plus Jakarta Sans (set globally in theme.dart),
    // so this copyWith is the only allocation and it only runs on theme change.
    _style = (Theme.of(context).textTheme.bodyLarge ?? const TextStyle())
        .copyWith(color: cs.onSurface, fontWeight: FontWeight.w500);
    _iconColor = cs.onSurfaceVariant;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveCapitalization = widget.upperCase
        ? TextCapitalization.characters
        : widget.textCapitalization;
    final effectiveFormatters = widget.upperCase
        ? [const UpperCaseTextInputFormatter(), ...?widget.inputFormatters]
        : widget.inputFormatters;

    return TextFormField(
      controller: widget.controller,
      focusNode: _effectiveFocusNode,
      obscureText: widget.obscureText,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      textCapitalization: effectiveCapitalization,
      inputFormatters: effectiveFormatters,

      maxLines: widget.maxLines,
      readOnly: widget.readOnly,
      showCursor: !widget.readOnly,
      autofillHints: widget.autofillHints,
      onTap: widget.onTap,
      onFieldSubmitted: widget.onSubmitted ??
          (widget.nextFocusNode != null
              ? (_) =>
                  FocusScope.of(context).requestFocus(widget.nextFocusNode)
              : null),
      style: _style,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        prefixIcon: Icon(widget.prefixIcon, size: 20, color: _iconColor),
        suffixIcon: widget.suffixWidget,
        // All borders, fill colour, content padding, and label/hint styles
        // are inherited from InputDecorationTheme in config/theme.dart.
      ),
      validator: widget.validator,
    );
  }
}

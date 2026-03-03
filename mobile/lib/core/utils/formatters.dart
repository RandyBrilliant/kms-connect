import 'package:flutter/services.dart';

/// Forces all user-typed text to uppercase in real time.
///
/// Pair with [TextCapitalization.characters] on the field for the keyboard
/// to also open in CAPS mode on supporting IMEs.
///
/// Note: This formatter only runs on *user input*. Always call
/// `.toUpperCase()` when assigning values programmatically via a controller.
class UpperCaseTextInputFormatter extends TextInputFormatter {
  const UpperCaseTextInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final upper = newValue.text.toUpperCase();
    if (upper == newValue.text) return newValue;
    return newValue.copyWith(
      text: upper,
      selection: newValue.selection,
      composing: newValue.composing,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Country option for the phone input dropdown.
class CountryOption {
  final String code;
  final String name;
  final String dialCode;
  final String flag;

  const CountryOption({
    required this.code,
    required this.name,
    required this.dialCode,
    required this.flag,
  });
}

/// Predefined list of countries matching the frontend phone-input component.
const List<CountryOption> kCountries = [
  CountryOption(code: 'ID', name: 'Indonesia', dialCode: '+62', flag: '🇮🇩'),
  CountryOption(code: 'MY', name: 'Malaysia', dialCode: '+60', flag: '🇲🇾'),
  CountryOption(code: 'SG', name: 'Singapore', dialCode: '+65', flag: '🇸🇬'),
  CountryOption(code: 'TH', name: 'Thailand', dialCode: '+66', flag: '🇹🇭'),
  CountryOption(code: 'PH', name: 'Philippines', dialCode: '+63', flag: '🇵🇭'),
  CountryOption(code: 'VN', name: 'Vietnam', dialCode: '+84', flag: '🇻🇳'),
  CountryOption(code: 'BN', name: 'Brunei', dialCode: '+673', flag: '🇧🇳'),
  CountryOption(code: 'KH', name: 'Cambodia', dialCode: '+855', flag: '🇰🇭'),
  CountryOption(code: 'LA', name: 'Laos', dialCode: '+856', flag: '🇱🇦'),
  CountryOption(code: 'MM', name: 'Myanmar', dialCode: '+95', flag: '🇲🇲'),
  CountryOption(code: 'IN', name: 'India', dialCode: '+91', flag: '🇮🇳'),
  CountryOption(code: 'CN', name: 'China', dialCode: '+86', flag: '🇨🇳'),
  CountryOption(code: 'JP', name: 'Japan', dialCode: '+81', flag: '🇯🇵'),
  CountryOption(code: 'KR', name: 'South Korea', dialCode: '+82', flag: '🇰🇷'),
];

/// Validates a phone number string.
///
/// Mirrors the frontend `validatePhone()` logic:
/// - `+62XXXXXXXXX` (9-13 digits after +62)
/// - `0XXXXXXXXX`   (9-12 digits after leading 0)
/// - `62XXXXXXXXX`  (9-13 digits after 62)
///
/// For non-Indonesian dial codes, just checks digit length (7-15).
///
/// Returns `null` if valid, or an error message string.
String? validatePhoneNumber(String? fullPhone) {
  if (fullPhone == null || fullPhone.trim().isEmpty) {
    return 'Nomor telepon wajib diisi';
  }

  final cleaned = fullPhone.replaceAll(RegExp(r'[\s\-]'), '');

  // Indonesian-specific patterns
  final patterns = [
    RegExp(r'^\+62\d{9,13}$'), // +6281234567890
    RegExp(r'^0\d{9,12}$'), // 081234567890
    RegExp(r'^62\d{9,13}$'), // 6281234567890
  ];

  if (cleaned.startsWith('+62') || cleaned.startsWith('62') || cleaned.startsWith('0')) {
    final isValid = patterns.any((p) => p.hasMatch(cleaned));
    if (!isValid) {
      return 'Format nomor telepon tidak valid (contoh: 81234567890)';
    }
    return null;
  }

  // For other countries, check the number starts with the dial code
  // and total digits (excluding +) is 7-15
  final digitsOnly = cleaned.replaceAll('+', '');
  if (!RegExp(r'^\d+$').hasMatch(digitsOnly)) {
    return 'Nomor telepon harus berisi angka saja';
  }
  if (digitsOnly.length < 7 || digitsOnly.length > 15) {
    return 'Nomor telepon harus 7-15 digit';
  }

  return null;
}

/// Phone input field with a country-code dropdown, matching the frontend
/// `<PhoneInput>` component.
///
/// The [value] and [onChanged] use the *full* international format, e.g.
/// `+6281234567890`. The local part is displayed in the text field (without
/// the leading zero), and the country dropdown shows the dial-code prefix.
///
/// Defaults to Indonesia (+62).
class PhoneInputField extends StatefulWidget {
  const PhoneInputField({
    super.key,
    required this.controller,
    this.focusNode,
    this.nextFocusNode,
    this.onChanged,
    this.validator,
    this.enabled = true,
    this.label = 'Nomor Telepon',
    this.hint = 'Contoh: 81234567890',
    this.textInputAction = TextInputAction.next,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final FocusNode? nextFocusNode;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;
  final bool enabled;
  final String label;
  final String hint;
  final TextInputAction textInputAction;

  @override
  State<PhoneInputField> createState() => _PhoneInputFieldState();
}

class _PhoneInputFieldState extends State<PhoneInputField> {
  late CountryOption _selectedCountry;
  late TextEditingController _localController;
  bool _updatingFromLocal = false;

  @override
  void initState() {
    super.initState();
    _selectedCountry = _deriveCountry(widget.controller.text);
    _localController = TextEditingController(
        text: _localPart(widget.controller.text));
    widget.controller.addListener(_onOuterControllerChanged);
  }

  void _onOuterControllerChanged() {
    if (_updatingFromLocal) return; // avoid feedback loop
    final newLocal = _localPart(widget.controller.text);
    if (_localController.text != newLocal) {
      _localController.text = newLocal;
      final newCountry = _deriveCountry(widget.controller.text);
      if (newCountry.code != _selectedCountry.code && mounted) {
        setState(() => _selectedCountry = newCountry);
      }
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onOuterControllerChanged);
    _localController.dispose();
    super.dispose();
  }

  /// Derive the matching country from the current full-value.
  /// Handles +62..., 62..., and 0... (Indonesian local) formats.
  CountryOption _deriveCountry(String value) {
    if (value.isEmpty) return kCountries[0]; // default Indonesia
    // Check explicit dial codes first (e.g. +62, +60)
    for (final c in kCountries) {
      if (value.startsWith(c.dialCode)) return c;
    }
    // Indonesian local format: 0812... → Indonesia
    // Indonesian without + : 62812... → Indonesia
    if (value.startsWith('0') || value.startsWith('62')) return kCountries[0];
    return kCountries[0];
  }

  /// Extract the local part (without dial code) for display.
  /// Strips +62 / 62 prefix and leading 0 so only the subscriber number shows.
  String _localPart(String value) {
    if (value.isEmpty) return '';
    // Standard +62 format
    if (value.startsWith(_selectedCountry.dialCode)) {
      return value.substring(_selectedCountry.dialCode.length);
    }
    // 62... format (without +)
    if (_selectedCountry.code == 'ID' && value.startsWith('62')) {
      return value.substring(2);
    }
    // 0... local format — strip the leading 0
    if (_selectedCountry.code == 'ID' && value.startsWith('0')) {
      return value.substring(1);
    }
    return value;
  }

  /// Build the full phone string from the country + local part, stripping
  /// leading zeros (matching frontend behaviour).
  void _updateValue(CountryOption country, String localRaw) {
    final trimmed = localRaw.replaceAll(RegExp(r'\s+'), '');
    // Remove leading zeros from local part (e.g. 0812 → 812)
    final withoutLeadingZero = trimmed.replaceFirst(RegExp(r'^0+'), '');
    final full = withoutLeadingZero.isEmpty
        ? ''
        : '${country.dialCode}$withoutLeadingZero';

    _updatingFromLocal = true;
    widget.controller.text = full;
    // Keep cursor at the end
    widget.controller.selection = TextSelection.collapsed(
      offset: widget.controller.text.length,
    );
    _updatingFromLocal = false;
    widget.onChanged?.call(full);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return FormField<String>(
      initialValue: widget.controller.text,
      validator: (_) {
        if (widget.validator != null) {
          return widget.validator!(widget.controller.text);
        }
        return validatePhoneNumber(widget.controller.text);
      },
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 4),
              child: Text(
                widget.label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: field.hasError
                      ? cs.error
                      : cs.onSurfaceVariant,
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Country code dropdown
                _CountryDropdown(
                  selected: _selectedCountry,
                  enabled: widget.enabled,
                  hasError: field.hasError,
                  onChanged: (country) {
                    final local = _localController.text;
                    setState(() => _selectedCountry = country);
                    _updateValue(country, local);
                    field.didChange(widget.controller.text);
                  },
                ),
                const SizedBox(width: 8),
                // Phone number text field
                Expanded(
                  child: TextFormField(
                    controller: _localController,
                    focusNode: widget.focusNode,
                    enabled: widget.enabled,
                    keyboardType: TextInputType.phone,
                    textInputAction: widget.textInputAction,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(15),
                    ],
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                    decoration: InputDecoration(
                      hintText: widget.hint,
                      prefixIcon: Icon(
                        Icons.phone_outlined,
                        size: 20,
                        color: cs.onSurfaceVariant,
                      ),
                      errorStyle: const TextStyle(height: 0, fontSize: 0),
                    ),
                    onChanged: (local) {
                      _updateValue(_selectedCountry, local);
                      field.didChange(widget.controller.text);
                    },
                    onFieldSubmitted: (_) {
                      if (widget.nextFocusNode != null) {
                        FocusScope.of(context)
                            .requestFocus(widget.nextFocusNode);
                      }
                    },
                  ),
                ),
              ],
            ),
            // Error text
            if (field.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 14),
                child: Text(
                  field.errorText!,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: cs.error,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Internal dropdown button for country selection.
class _CountryDropdown extends StatelessWidget {
  final CountryOption selected;
  final bool enabled;
  final bool hasError;
  final ValueChanged<CountryOption> onChanged;

  const _CountryDropdown({
    required this.selected,
    required this.enabled,
    required this.hasError,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return PopupMenuButton<CountryOption>(
      enabled: enabled,
      onSelected: onChanged,
      offset: const Offset(0, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (ctx) => kCountries.map((country) {
        final isSelected = country.code == selected.code;
        return PopupMenuItem<CountryOption>(
          value: country,
          child: Row(
            children: [
              Text(country.flag, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                country.dialCode,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  country.name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: cs.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isSelected)
                Icon(Icons.check_rounded, size: 18, color: cs.primary),
            ],
          ),
        );
      }).toList(),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasError ? cs.error : cs.outline,
            width: hasError ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(selected.flag, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 4),
            Text(
              selected.dialCode,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            Icon(Icons.arrow_drop_down_rounded,
                size: 20, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/safe_navigation.dart';

/// Reusable professional phone input with country code segment.
class ProfessionalPhoneField extends StatefulWidget {
  const ProfessionalPhoneField({
    super.key,
    required this.controller,
    required this.label,
    required this.hintText,
    this.focusNode,
    this.textInputAction = TextInputAction.next,
    this.countryFlag = '🇮🇩',
    this.countryCode = '+62',
    this.onCountryTap,
    this.enabled = true,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final FocusNode? focusNode;
  final TextInputAction textInputAction;
  final String countryFlag;
  final String countryCode;
  final VoidCallback? onCountryTap;
  final bool enabled;
  final String? Function(String?)? validator;

  static String normalizeIndonesiaNumber(String input) {
    var digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('62')) digits = digits.substring(2);
    while (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return digits;
  }

  static String toIndonesiaE164(String input) {
    final local = normalizeIndonesiaNumber(input);
    if (local.isEmpty) return '';
    return '+62$local';
  }

  @override
  State<ProfessionalPhoneField> createState() => _ProfessionalPhoneFieldState();
}

class _ProfessionalPhoneFieldState extends State<ProfessionalPhoneField> {
  FocusNode? _internalNode;
  FocusNode? _listenedNode;
  _CountryDial _selectedDial = const _CountryDial(
    flag: '🇮🇩',
    country: 'Indonesia',
    code: '+62',
  );

  static const List<_CountryDial> _dialOptions = [
    _CountryDial(flag: '🇮🇩', country: 'Indonesia', code: '+62'),
    _CountryDial(flag: '🇲🇾', country: 'Malaysia', code: '+60'),
    _CountryDial(flag: '🇸🇬', country: 'Singapore', code: '+65'),
    _CountryDial(flag: '🇹🇭', country: 'Thailand', code: '+66'),
    _CountryDial(flag: '🇻🇳', country: 'Vietnam', code: '+84'),
    _CountryDial(flag: '🇵🇭', country: 'Philippines', code: '+63'),
    _CountryDial(flag: '🇮🇳', country: 'India', code: '+91'),
    _CountryDial(flag: '🇯🇵', country: 'Japan', code: '+81'),
    _CountryDial(flag: '🇰🇷', country: 'South Korea', code: '+82'),
    _CountryDial(flag: '🇨🇳', country: 'China', code: '+86'),
    _CountryDial(flag: '🇦🇺', country: 'Australia', code: '+61'),
    _CountryDial(flag: '🇳🇿', country: 'New Zealand', code: '+64'),
    _CountryDial(flag: '🇬🇧', country: 'United Kingdom', code: '+44'),
    _CountryDial(flag: '🇩🇪', country: 'Germany', code: '+49'),
    _CountryDial(flag: '🇫🇷', country: 'France', code: '+33'),
    _CountryDial(flag: '🇳🇱', country: 'Netherlands', code: '+31'),
    _CountryDial(flag: '🇸🇦', country: 'Saudi Arabia', code: '+966'),
    _CountryDial(flag: '🇦🇪', country: 'United Arab Emirates', code: '+971'),
    _CountryDial(flag: '🇪🇬', country: 'Egypt', code: '+20'),
    _CountryDial(flag: '🇿🇦', country: 'South Africa', code: '+27'),
    _CountryDial(flag: '🇨🇦', country: 'Canada', code: '+1'),
    _CountryDial(flag: '🇺🇸', country: 'United States', code: '+1'),
    _CountryDial(flag: '🇧🇷', country: 'Brazil', code: '+55'),
    _CountryDial(flag: '🇲🇽', country: 'Mexico', code: '+52'),
  ];

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
    _selectedDial = _resolveDialFromWidget();
    _listenedNode = _focusNode;
    _listenedNode?.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant ProfessionalPhoneField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      _listenedNode?.removeListener(_handleFocusChange);
      _listenedNode = _focusNode;
      _listenedNode?.addListener(_handleFocusChange);
    }
    if (oldWidget.countryCode != widget.countryCode ||
        oldWidget.countryFlag != widget.countryFlag) {
      _selectedDial = _resolveDialFromWidget();
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
    final borderColor = cs.outlineVariant.withValues(alpha: 0.9);
    final radius = BorderRadius.circular(14);
    final enabled = widget.enabled;
    final fieldTextColor = enabled ? cs.onSurface : cs.onSurface.withValues(alpha: 0.5);
    final fieldHintColor =
        enabled ? cs.onSurfaceVariant.withValues(alpha: 0.7) : cs.onSurfaceVariant.withValues(alpha: 0.45);

    return TextFormField(
      controller: widget.controller,
      focusNode: _focusNode,
      enabled: enabled,
      keyboardType: TextInputType.phone,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
      inputFormatters: [
        const _IndonesiaPhoneInputFormatter(maxDigits: 13),
      ],
      style: TextStyle(color: fieldTextColor),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hintText,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        hintStyle: TextStyle(color: fieldHintColor),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        prefixIconConstraints: const BoxConstraints(minWidth: 116, minHeight: 0),
        prefixIcon: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: enabled
                ? () {
                    runWhenNavigatorUnlocked(() {
                      if (!mounted) return;
                      _handleCountryTap();
                    });
                  }
                : null,
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_selectedDial.flag, style: const TextStyle(fontSize: 17)),
                  const SizedBox(width: 6),
                  Text(
                    _selectedDial.code,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: fieldTextColor,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.arrow_drop_down_rounded, size: 18, color: cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Container(width: 1, height: 24, color: borderColor),
                ],
              ),
            ),
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: cs.primary, width: 1.6),
        ),
      ),
      validator: widget.validator ??
          (value) {
            final v = ProfessionalPhoneField.normalizeIndonesiaNumber(value ?? '');
            if (v.isEmpty) return 'Nomor telepon wajib diisi';
            if (v.length < 8 || v.length > 13) return 'Nomor telepon harus 8-13 digit';
            return null;
          },
    );
  }

  Future<void> _handleCountryTap() async {
    if (widget.onCountryTap != null) {
      widget.onCountryTap!.call();
      return;
    }

    final selected = await showModalBottomSheet<_CountryDial>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _CountryCodePickerSheet(
        initialValue: _selectedDial,
        options: _dialOptions,
      ),
    );

    if (!mounted || selected == null) return;
    setState(() => _selectedDial = selected);
  }

  _CountryDial _resolveDialFromWidget() {
    return _dialOptions.firstWhere(
      (d) => d.code == widget.countryCode && d.flag == widget.countryFlag,
      orElse: () => _dialOptions.firstWhere(
        (d) => d.code == widget.countryCode,
        orElse: () => _dialOptions.first,
      ),
    );
  }
}

class _CountryCodePickerSheet extends StatefulWidget {
  const _CountryCodePickerSheet({
    required this.initialValue,
    required this.options,
  });

  final _CountryDial initialValue;
  final List<_CountryDial> options;

  @override
  State<_CountryCodePickerSheet> createState() => _CountryCodePickerSheetState();
}

class _CountryCodePickerSheetState extends State<_CountryCodePickerSheet> {
  late final TextEditingController _searchCtrl;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filtered = widget.options.where((item) {
      final q = _query.trim().toLowerCase();
      if (q.isEmpty) return true;
      return item.country.toLowerCase().contains(q) || item.code.contains(q);
    }).toList();

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  hintText: 'Cari negara atau kode telepon',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    final isSelected = item.code == widget.initialValue.code &&
                        item.country == widget.initialValue.country;
                    return ListTile(
                      onTap: () => Navigator.of(context).pop(item),
                      leading: Text(item.flag, style: const TextStyle(fontSize: 22)),
                      title: Text(item.country),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.code,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.check_rounded, size: 18, color: cs.primary),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountryDial {
  const _CountryDial({
    required this.flag,
    required this.country,
    required this.code,
  });

  final String flag;
  final String country;
  final String code;
}

class _IndonesiaPhoneInputFormatter extends TextInputFormatter {
  const _IndonesiaPhoneInputFormatter({required this.maxDigits});

  final int maxDigits;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = ProfessionalPhoneField.normalizeIndonesiaNumber(newValue.text);
    if (digits.length > maxDigits) {
      digits = digits.substring(0, maxDigits);
    }

    final formatted = _formatIndo(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _formatIndo(String digits) {
    if (digits.length <= 3) return digits;
    if (digits.length <= 7) {
      return '${digits.substring(0, 3)} ${digits.substring(3)}';
    }
    if (digits.length <= 11) {
      return '${digits.substring(0, 3)} ${digits.substring(3, 7)} ${digits.substring(7)}';
    }
    return '${digits.substring(0, 3)} ${digits.substring(3, 7)} ${digits.substring(7, 11)} ${digits.substring(11)}';
  }
}

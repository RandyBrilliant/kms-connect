import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../config/colors.dart';
import '../../../../core/widgets/professional_dropdown_field.dart';

/// Searchable option picker (bottom sheet) shared by Edit Profil and
/// Data Rekening PMI.
class OptionPick<T> {
  const OptionPick(this.value);
  final T? value;
}

String? optionLabelForValue<T>(T? value, List<(T, String)> items) {
  if (value == null) return null;
  for (final i in items) {
    if (i.$1 == value) return i.$2;
  }
  if (value is String) {
    final vu = value.toUpperCase();
    for (final i in items) {
      if (i.$1 is String && (i.$1 as String).toUpperCase() == vu) {
        return i.$2;
      }
    }
  }
  return null;
}

/// Generic dropdown field matching professional white style + registration sheets.
class OptionPickerField<T> extends StatelessWidget {
  const OptionPickerField({
    required this.label,
    required this.prefixIcon,
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
    this.emptyErrorText,
    super.key,
  });

  final String label;
  final IconData prefixIcon;
  final T? value;
  final String hint;
  /// Each item is `(value, displayLabel)`.
  final List<(T, String)> items;
  final ValueChanged<T?> onChanged;
  final String? emptyErrorText;

  @override
  Widget build(BuildContext context) {
    final selectedLabel = optionLabelForValue(value, items);
    return ProfessionalDropdownField(
      valueText: selectedLabel ?? '',
      label: label,
      hint: hint,
      prefixIcon: prefixIcon,
      emptyErrorText: emptyErrorText,
      onTap: () async {
        final result = await showModalBottomSheet<OptionPick<T>?>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _OptionPickerSheet<T>(
            title: label,
            hint: hint,
            value: value,
            items: items,
          ),
        );
        if (result == null) return;
        onChanged(result.value);
      },
    );
  }
}

class _OptionPickerSheet<T> extends StatefulWidget {
  const _OptionPickerSheet({
    required this.title,
    required this.hint,
    required this.value,
    required this.items,
  });

  final String title;
  final String hint;
  final T? value;
  final List<(T, String)> items;

  @override
  State<_OptionPickerSheet<T>> createState() => _OptionPickerSheetState<T>();
}

class _OptionPickerSheetState<T> extends State<_OptionPickerSheet<T>> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _selected(T? a, T? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a == b) return true;
    if (a is String && b is String) {
      return (a as String).toUpperCase() == (b as String).toUpperCase();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final q = _searchCtrl.text.trim().toLowerCase();
    final filtered = widget.items
        .where((i) => i.$2.toLowerCase().contains(q))
        .toList();
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: AppColors.textMedium),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 14, color: AppColors.textDark),
                  decoration: InputDecoration(
                    hintText: 'Cari...',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: AppColors.textLight,
                    ),
                    prefixIcon:
                        Icon(Icons.search, color: AppColors.textMedium, size: 20),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear,
                                color: AppColors.textMedium, size: 18),
                            onPressed: () => _searchCtrl.clear(),
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.backgroundOffWhite,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.primaryDarkGreen,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Divider(height: 1, color: AppColors.divider),
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  itemCount: filtered.length + 1,
                  itemBuilder: (_, index) {
                    if (index == 0) {
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 2),
                        title: Text(
                          'Kosongkan pilihan',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMedium,
                          ),
                        ),
                        onTap: () => Navigator.pop(
                            context, OptionPick<T>(null)),
                      );
                    }
                    final item = filtered[index - 1];
                    final selected = _selected(item.$1, widget.value);
                    return ListTile(
                      onTap: () => Navigator.pop(
                          context, OptionPick<T>(item.$1)),
                      selected: selected,
                      selectedTileColor:
                          AppColors.primaryDarkGreen.withValues(alpha: 0.1),
                      tileColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 2),
                      title: Text(
                        item.$2,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected
                              ? AppColors.primaryDarkGreen
                              : AppColors.textDark,
                        ),
                      ),
                      trailing: selected
                          ? Icon(Icons.check_circle_rounded,
                              color: AppColors.primaryDarkGreen, size: 20)
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

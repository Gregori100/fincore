import 'package:fincore/constants/category_catalog.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:flutter/material.dart';

/// Grid de los 10 colores curados del catálogo. Selección por tap.
class ColorPicker extends StatelessWidget {
  final String? selectedSlug;
  final ValueChanged<String> onChanged;

  const ColorPicker({super.key, required this.selectedSlug, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: kCategoryColors.map((c) {
        final selected = c.slug == selectedSlug;
        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => onChanged(c.slug),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: c.color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? FincoreColors.textPrimary : Colors.transparent,
                width: 3,
              ),
            ),
            child: selected
                ? const Icon(Icons.check, size: 22, color: FincoreColors.canvas)
                : null,
          ),
        );
      }).toList(),
    );
  }
}

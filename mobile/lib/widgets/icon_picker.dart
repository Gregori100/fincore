import 'package:fincore/constants/category_catalog.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:flutter/material.dart';

/// Grid de los ~30 íconos curados del catálogo. Selección por tap.
/// El color de selección se toma de la categoría que se está editando para que
/// se vea coherente con el color elegido.
class IconPicker extends StatelessWidget {
  final String? selectedSlug;
  final Color selectionColor;
  final ValueChanged<String> onChanged;

  const IconPicker({
    super.key,
    required this.selectedSlug,
    required this.selectionColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: kCategoryIcons.map((i) {
        final selected = i.slug == selectedSlug;
        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => onChanged(i.slug),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: selected ? selectionColor.withValues(alpha: 0.2) : FincoreColors.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? selectionColor : FincoreColors.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: Icon(
              i.icon,
              size: 22,
              color: selected ? selectionColor : FincoreColors.textMuted,
            ),
          ),
        );
      }).toList(),
    );
  }
}

import 'package:fincore/constants/category_catalog.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:flutter/material.dart';

class CategoryPicker extends StatelessWidget {
  final List<Category> categories;
  final List<String> validAppliesTo;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  const CategoryPicker({
    super.key,
    required this.categories,
    required this.validAppliesTo,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final visible = categories
        .where((c) => c.deletedAt == null && validAppliesTo.contains(c.appliesTo))
        .toList();
    final hasValid = visible.any((c) => c.id == selectedId);

    return LayoutBuilder(
      builder: (context, constraints) {
        return DropdownMenu<String?>(
          width: constraints.maxWidth,
          label: const Text('Categoría (opcional)'),
          initialSelection: hasValid ? selectedId : null,
          requestFocusOnTap: false,
          enableSearch: false,
          textStyle: const TextStyle(color: FincoreColors.textPrimary),
          inputDecorationTheme: const InputDecorationTheme(
            filled: true,
            fillColor: FincoreColors.surface,
            border: OutlineInputBorder(),
          ),
          menuStyle: MenuStyle(
            backgroundColor: WidgetStateProperty.all(FincoreColors.surfaceElevated),
            maximumSize: WidgetStateProperty.all(
              Size(constraints.maxWidth, 320),
            ),
          ),
          onSelected: onChanged,
          dropdownMenuEntries: [
            const DropdownMenuEntry<String?>(
              value: null,
              label: 'Sin categoría',
            ),
            ...visible.map((c) => DropdownMenuEntry<String?>(
                  value: c.id,
                  label: c.name,
                  leadingIcon: Icon(
                    iconBySlug(c.iconSlug),
                    color: colorBySlug(c.colorSlug),
                    size: 18,
                  ),
                  style: ButtonStyle(
                    foregroundColor:
                        WidgetStateProperty.all(FincoreColors.textPrimary),
                  ),
                )),
          ],
        );
      },
    );
  }
}

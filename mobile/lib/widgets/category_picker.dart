import 'package:fincore/constants/category_catalog.dart';
import 'package:fincore/models/category.dart';
import 'package:flutter/material.dart';

/// Dropdown de categorías filtradas por applies_to válido para un kind.
/// Permite "Sin categoría" (null) para todos los kinds que aceptan categoría
/// (la categoría es opcional en backend para income/expense/credit_expense).
class CategoryPicker extends StatelessWidget {
  final List<Category> categories;
  final List<String> validAppliesTo; // Ej: ['expense', 'both'] para un gasto.
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
        .where((c) => !c.isArchived && validAppliesTo.contains(c.appliesTo))
        .toList();

    return DropdownButtonFormField<String?>(
      value: selectedId,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Categoría (opcional)'),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('Sin categoría')),
        ...visible.map((c) {
          return DropdownMenuItem<String?>(
            value: c.id,
            child: Row(
              children: [
                Icon(iconBySlug(c.iconSlug), color: colorBySlug(c.colorSlug), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(c.name, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          );
        }),
      ],
      onChanged: onChanged,
    );
  }
}

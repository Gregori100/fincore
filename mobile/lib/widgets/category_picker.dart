import 'package:fincore/data/database.dart' as db;
import 'package:fincore/models/category.dart' as model;
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/theme/fincore_radii.dart';
import 'package:fincore/theme/fincore_spacing.dart';
import 'package:fincore/theme/fincore_typography.dart' as typo;
import 'package:fincore/widgets/category_badge.dart';
import 'package:flutter/material.dart';

/// Field compacto de categoría que abre un `showModalBottomSheet` con
/// búsqueda + agrupación + MRU en memoria.
///
/// Reemplaza el `DropdownMenu` original por un patrón search-first
/// consistente con los pickers del sprint `flutter-entry-form-redesign-v1`.
class CategoryPicker extends StatelessWidget {
  final List<db.Category> categories;
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
        .where((c) =>
            c.deletedAt == null && validAppliesTo.contains(c.appliesTo))
        .toList();

    db.Category? selected;
    for (final c in visible) {
      if (c.id == selectedId) {
        selected = c;
        break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Categoría (opcional)', style: typo.label),
        const SizedBox(height: kSpaceXs),
        InkWell(
          borderRadius: BorderRadius.circular(kRadiusMd),
          onTap: () => _openSheet(context, visible),
          child: Container(
            padding: kEdgeListItem,
            decoration: BoxDecoration(
              color: FincoreColors.surface,
              borderRadius: BorderRadius.circular(kRadiusMd),
              border: Border.all(color: FincoreColors.border, width: 1),
            ),
            child: Row(
              children: [
                if (selected != null)
                  CategoryBadge(category: _toModelCategory(selected))
                else
                  Text(
                    'Sin categoría',
                    style: typo.bodyM.copyWith(color: FincoreColors.textMuted),
                  ),
                const Spacer(),
                const Icon(
                  Icons.chevron_right,
                  color: FincoreColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openSheet(
    BuildContext context,
    List<db.Category> visible,
  ) async {
    final result = await showModalBottomSheet<_SheetResult?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: FincoreColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(kRadiusXl)),
      ),
      builder: (ctx) => _CategoryPickerSheet(
        categories: visible,
        validAppliesTo: validAppliesTo,
        selectedId: selectedId,
      ),
    );

    if (result != null) {
      onChanged(result.categoryId);
    }
  }
}

/// Wrapper para poder distinguir "usuario cerró sin elegir" (null result)
/// de "usuario eligió 'Sin categoría'" (result con categoryId == null).
class _SheetResult {
  final String? categoryId;
  const _SheetResult(this.categoryId);
}

class _CategoryPickerSheet extends StatefulWidget {
  final List<db.Category> categories;
  final List<String> validAppliesTo;
  final String? selectedId;

  const _CategoryPickerSheet({
    required this.categories,
    required this.validAppliesTo,
    required this.selectedId,
  });

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  /// MRU en memoria persistente durante la sesión de la app (se pierde al
  /// restart). Máx 5 IDs, más reciente al inicio.
  static final List<String> _sessionMRU = [];

  static const int _mruLimit = 5;
  static const int _autofocusThreshold = 12;

  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _touchMRU(String id) {
    _sessionMRU.remove(id);
    _sessionMRU.insert(0, id);
    if (_sessionMRU.length > _mruLimit) {
      _sessionMRU.removeRange(_mruLimit, _sessionMRU.length);
    }
  }

  bool _matchesQuery(db.Category c) {
    if (_query.isEmpty) return true;
    return c.name.toLowerCase().contains(_query.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    // Categorías filtradas por query (para la lista principal + empty state).
    final filtered =
        widget.categories.where(_matchesQuery).toList(growable: false);

    // Determina si el sheet muestra headers de sección (income/expense/both).
    final showsGroupHeaders = widget.validAppliesTo.contains('income') &&
        widget.validAppliesTo.contains('expense');

    // MRU visible: sólo IDs que sigan en el listado válido/activo y matcheen
    // la query. Se muestra la sección si quedan ≥2 items.
    final mruVisible = <db.Category>[];
    for (final id in _sessionMRU) {
      for (final c in filtered) {
        if (c.id == id) {
          mruVisible.add(c);
          break;
        }
      }
    }
    final showMru = mruVisible.length >= 2;

    // Lista principal, opcionalmente agrupada.
    final sections = <_Section>[];
    if (showsGroupHeaders) {
      final income = filtered.where((c) => c.appliesTo == 'income').toList();
      final expense = filtered.where((c) => c.appliesTo == 'expense').toList();
      final both = filtered.where((c) => c.appliesTo == 'both').toList();
      if (income.isNotEmpty) sections.add(_Section('INGRESOS', income));
      if (expense.isNotEmpty) sections.add(_Section('GASTOS', expense));
      if (both.isNotEmpty) sections.add(_Section('AMBOS', both));
    } else {
      if (filtered.isNotEmpty) sections.add(_Section(null, filtered));
    }

    // Construimos una lista plana de items para el ListView.builder.
    final items = <_ListItem>[];
    for (final s in sections) {
      if (s.header != null) {
        items.add(_HeaderItem(s.header!));
      }
      for (final c in s.categories) {
        items.add(_CategoryItem(c));
      }
    }

    return Padding(
      padding: EdgeInsets.only(
        left: kSpaceLg,
        right: kSpaceLg,
        top: kSpaceXs,
        // token-exception: viewInsets + viewPadding + kSpaceXl es la fórmula
        // canónica de este proyecto para respetar la nav bar gestual de
        // Android (bug documentado en el sprint weekly-budgets).
        bottom: media.viewInsets.bottom + media.viewPadding.bottom + kSpaceXl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: Text('Elige una categoría', style: typo.headingL),
          ),
          const SizedBox(height: kSpaceMd),
          TextField(
            controller: _searchCtrl,
            autofocus: widget.categories.length > _autofocusThreshold,
            style: typo.bodyM,
            decoration: InputDecoration(
              hintText: 'Buscar categoría...',
              hintStyle:
                  typo.bodyM.copyWith(color: FincoreColors.textMuted),
              prefixIcon: const Icon(
                Icons.search_outlined,
                color: FincoreColors.textMuted,
              ),
              filled: true,
              fillColor: FincoreColors.surfaceElevated,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(kRadiusMd),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(kRadiusMd),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(kRadiusMd),
                borderSide: const BorderSide(
                  color: FincoreColors.accent,
                  width: 1,
                ),
              ),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: kSpaceMd),
          // Opción fija "Sin categoría" — no se filtra por query.
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.block_outlined,
              color: FincoreColors.textMuted,
            ),
            title: Text(
              'Sin categoría',
              style: typo.bodyM.copyWith(color: FincoreColors.textMuted),
            ),
            onTap: () => Navigator.of(context).pop(const _SheetResult(null)),
          ),
          const Divider(color: FincoreColors.border, height: 1),
          const SizedBox(height: kSpaceSm),
          // Cuerpo scrollable.
          Flexible(
            child: (items.isEmpty && !showMru)
                ? const _EmptyState()
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount:
                        (showMru ? mruVisible.length + 2 : 0) + items.length,
                    itemBuilder: (context, index) {
                      var i = index;
                      if (showMru) {
                        if (i == 0) return _headerRow('RECIENTES');
                        i -= 1;
                        if (i < mruVisible.length) {
                          return _categoryRow(mruVisible[i]);
                        }
                        i -= mruVisible.length;
                        if (i == 0) {
                          return const Divider(
                            color: FincoreColors.border,
                            height: 1,
                          );
                        }
                        i -= 1;
                      }
                      final item = items[i];
                      if (item is _HeaderItem) return _headerRow(item.text);
                      if (item is _CategoryItem) {
                        return _categoryRow(item.category);
                      }
                      return const SizedBox.shrink();
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _headerRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: kSpaceMd, bottom: kSpaceXs),
      child: Text(text, style: typo.overline),
    );
  }

  Widget _categoryRow(db.Category c) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CategoryBadge(category: _toModelCategory(c), compact: true),
      title: Text(c.name, style: typo.bodyM),
      onTap: () {
        _touchMRU(c.id);
        Navigator.of(context).pop(_SheetResult(c.id));
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: kSpaceXl),
      child: Center(
        child: Text(
          'No hay categorías que coincidan.',
          style: typo.bodyM.copyWith(color: FincoreColors.textMuted),
        ),
      ),
    );
  }
}

class _Section {
  final String? header;
  final List<db.Category> categories;
  const _Section(this.header, this.categories);
}

abstract class _ListItem {
  const _ListItem();
}

class _HeaderItem extends _ListItem {
  final String text;
  const _HeaderItem(this.text);
}

class _CategoryItem extends _ListItem {
  final db.Category category;
  const _CategoryItem(this.category);
}

/// Convierte una `db.Category` (drift) al `model.Category` que consume
/// `CategoryBadge`. Duplicado a propósito con `movement_row.dart` porque no
/// existe (todavía) un helper global; mantener alineados si cambia el
/// modelo. Ver sprint `flutter-entry-form-redesign-v1`.
model.Category _toModelCategory(db.Category c) {
  return model.Category(
    id: c.id,
    name: c.name,
    appliesTo: c.appliesTo,
    colorSlug: c.colorSlug,
    iconSlug: c.iconSlug,
    monthlyLimit: c.monthlyLimit,
    deletedAt: c.deletedAt,
  );
}

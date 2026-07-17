import 'package:fincore/constants/category_catalog.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/theme/fincore_radii.dart';
import 'package:fincore/theme/fincore_spacing.dart';
import 'package:fincore/theme/fincore_typography.dart' as typo;
import 'package:flutter/material.dart';

/// Sprint flutter-entries-bulk-recategorize-v1: resultado del sheet.
/// `Navigator.pop(context, null)` = canceló (default de sheet).
/// `Navigator.pop(context, BulkCategoryResult.assign(id))` = asignó.
/// `Navigator.pop(context, BulkCategoryResult.clear())` = "Sin categoría".
///
/// El caller distingue asignar de desasignar por `categoryId` null vs. no
/// null, y `null` como retorno del `showModalBottomSheet` significa
/// simplemente que se cerró el sheet sin acción.
class BulkCategoryResult {
  final String? categoryId;
  const BulkCategoryResult._(this.categoryId);
  const BulkCategoryResult.assign(String id) : this._(id);
  const BulkCategoryResult.clear() : this._(null);
}

/// Bottom sheet para reasignar categoría a N movimientos seleccionados.
///
/// Filtra las categorías activas por compatibilidad con TODOS los kinds
/// del batch. Reglas:
/// - batch solo income → `applies_to ∈ {income, both}`.
/// - batch solo expense/credit_expense → `applies_to ∈ {expense, both}`.
/// - batch mixto (income + expense-like) → solo `applies_to = both`.
///
/// El botón "Sin categoría" siempre está disponible (desasignar cualquier
/// combinación no rompe RN-011).
///
/// Header: `N movimientos seleccionados` + hint contextual del batch
/// ("solo ingresos" / "solo gastos" / "ingresos y gastos"). Si el filtro
/// deja 0 categorías compatibles, muestra estado vacío con CTA a
/// "Sin categoría" únicamente.
class BulkCategorySheet extends StatelessWidget {
  final int selectedCount;
  final Set<String> batchKinds;
  final List<Category> categories;

  const BulkCategorySheet({
    super.key,
    required this.selectedCount,
    required this.batchKinds,
    required this.categories,
  });

  bool _matches(Category c) {
    // batchKinds ya viene del DAO — puede tener kinds no-categorizables si
    // el usuario los seleccionó por atajo (no debería, pero por defensa).
    // Los ignoramos para el filtro; el DAO rechazará el bulk igual.
    final relevantKinds = batchKinds
        .where(
          (k) => k == 'income' || k == 'expense' || k == 'credit_expense',
        )
        .toSet();
    if (relevantKinds.isEmpty) return false;

    final hasIncome = relevantKinds.contains('income');
    final hasExpense = relevantKinds.contains('expense') ||
        relevantKinds.contains('credit_expense');
    if (hasIncome && hasExpense) {
      return c.appliesTo == 'both';
    }
    if (hasIncome) {
      return c.appliesTo == 'income' || c.appliesTo == 'both';
    }
    // solo expense-like.
    return c.appliesTo == 'expense' || c.appliesTo == 'both';
  }

  String _batchHint() {
    final relevantKinds = batchKinds
        .where(
          (k) => k == 'income' || k == 'expense' || k == 'credit_expense',
        )
        .toSet();
    final hasIncome = relevantKinds.contains('income');
    final hasExpense = relevantKinds.contains('expense') ||
        relevantKinds.contains('credit_expense');
    if (hasIncome && hasExpense) return 'ingresos y gastos';
    if (hasIncome) return 'solo ingresos';
    return 'solo gastos';
  }

  @override
  Widget build(BuildContext context) {
    final compatibles = categories
        .where((c) => c.deletedAt == null)
        .where(_matches)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: kSpaceLg,
          right: kSpaceLg,
          top: kSpaceLg,
          bottom: MediaQuery.of(context).viewInsets.bottom + kSpaceLg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              selectedCount == 1
                  ? '1 movimiento seleccionado'
                  : '$selectedCount movimientos seleccionados',
              style: typo.headingM,
            ),
            const SizedBox(height: kSpaceXs),
            Text(
              'Batch: ${_batchHint()}. Categorías compatibles:',
              style: typo.bodyS.copyWith(color: FincoreColors.textMuted),
            ),
            const SizedBox(height: kSpaceMd),
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: compatibles.isEmpty
                    ? const _NoCategoriesEmptyState()
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: compatibles.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: kSpaceSm),
                        itemBuilder: (_, i) {
                          final c = compatibles[i];
                          return _CategoryTile(
                            category: c,
                            onTap: () => Navigator.of(context).pop(
                              BulkCategoryResult.assign(c.id),
                            ),
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(height: kSpaceMd),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(
                const BulkCategoryResult.clear(),
              ),
              icon: const Icon(Icons.label_off_outlined, size: 18),
              label: const Text('Quitar categoría'),
              style: OutlinedButton.styleFrom(
                foregroundColor: FincoreColors.textSubtle,
                minimumSize: const Size.fromHeight(44),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final Category category;
  final VoidCallback onTap;

  const _CategoryTile({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = colorBySlug(category.colorSlug);
    return Material(
      color: FincoreColors.surface,
      borderRadius: BorderRadius.circular(kRadiusLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadiusLg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: kSpaceMd,
            vertical: kSpaceMd,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kRadiusLg),
            border: Border.all(color: FincoreColors.border, width: 1),
          ),
          child: Row(
            children: [
              Container(
                // token-exception: 32 leading estándar.
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: FincoreColors.alphaTint),
                  borderRadius: BorderRadius.circular(kRadiusMd),
                ),
                child: Icon(
                  iconBySlug(category.iconSlug),
                  size: 16,
                  color: color,
                ),
              ),
              const SizedBox(width: kSpaceMd),
              Expanded(
                child: Text(
                  category.name,
                  style: typo.bodyM.copyWith(fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: FincoreColors.textSubtle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoCategoriesEmptyState extends StatelessWidget {
  const _NoCategoriesEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: kSpaceXl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.category_outlined,
            size: 40,
            color: FincoreColors.textSubtle,
          ),
          const SizedBox(height: kSpaceSm),
          Text(
            'No hay categorías compatibles con la selección actual.',
            style: typo.bodyM.copyWith(color: FincoreColors.textMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: kSpaceXs),
          Text(
            'Puedes quitar la categoría o cerrar y ajustar la selección.',
            style: typo.bodyS.copyWith(color: FincoreColors.textSubtle),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

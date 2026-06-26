import 'package:fincore/constants/date_range_presets.dart';
import 'package:fincore/constants/filter_tokens.dart';
import 'package:fincore/constants/kinds.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/data/entries_filters.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/widgets/amount_formatter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Barra horizontal de chips de filtros activos en el header de
/// `EntriesListScreen`. Cada chip muestra una dimensión (fecha, tipo,
/// cuenta, categoría) y tiene un tap target de 32x32 con InkResponse
/// para removerla (M2 del quality review v1).
///
/// Las listas de `accounts` y `categories` se mantienen resueltas en el
/// padre vía `StreamSubscription` directa (perf v1) para evitar
/// `StreamBuilder` anidados que re-suscriben en cada rebuild.
class EntriesActiveFiltersBar extends StatelessWidget {
  final EntriesFilters filters;
  final List<Account> accounts;
  final List<Category> categories;
  final void Function(FilterDimension) onRemove;

  const EntriesActiveFiltersBar({
    super.key,
    required this.filters,
    required this.accounts,
    required this.categories,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMM', 'es_MX');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: FincoreColors.border, width: 1),
        ),
      ),
      child: SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            if (filters.datePreset != DateRangePreset.thisMonth)
              _ActiveChip(
                label:
                    '${dateFormat.format(filters.from)} – ${dateFormat.format(filters.to)}',
                onRemove: () => onRemove(FilterDimension.date),
              ),
            if (filters.kinds.isNotEmpty)
              _ActiveChip(
                label: _kindsLabel(filters.kinds),
                onRemove: () => onRemove(FilterDimension.kinds),
              ),
            if (filters.accountIds.isNotEmpty)
              _ActiveChip(
                label: _accountsLabel(filters.accountIds),
                onRemove: () => onRemove(FilterDimension.accounts),
              ),
            if (filters.categoryIds.isNotEmpty)
              _ActiveChip(
                label: _categoriesLabel(filters.categoryIds),
                onRemove: () => onRemove(FilterDimension.categories),
              ),
            if (filters.minAmount != null || filters.maxAmount != null)
              _ActiveChip(
                label: _amountLabel(filters.minAmount, filters.maxAmount),
                onRemove: () => onRemove(FilterDimension.amount),
              ),
          ],
        ),
      ),
    );
  }

  String _amountLabel(double? min, double? max) {
    if (min != null && max != null) {
      return '${formatAmount(min)} – ${formatAmount(max)}';
    }
    if (min != null) {
      return '≥ ${formatAmount(min)}';
    }
    return '≤ ${formatAmount(max!)}';
  }

  String _kindsLabel(List<String> kinds) {
    if (kinds.length == 1) {
      return parseJournalKind(kinds.first).label;
    }
    return '${kinds.length} tipos';
  }

  String _accountsLabel(List<String> ids) {
    if (ids.length == 1) {
      for (final a in accounts) {
        if (a.id == ids.first) return a.name;
      }
      return 'Cuenta (archivada)';
    }
    return '${ids.length} cuentas';
  }

  String _categoriesLabel(List<String> ids) {
    if (ids.length == 1) {
      if (ids.first == kUncategorizedFilterToken) return 'Sin categoría';
      for (final c in categories) {
        if (c.id == ids.first) return c.name;
      }
      return 'Categoría (archivada)';
    }
    return '${ids.length} categorías';
  }
}

class _ActiveChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _ActiveChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: FincoreColors.accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: FincoreColors.accent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  color: FincoreColors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 32,
              height: 32,
              child: InkResponse(
                onTap: onRemove,
                radius: 22,
                child: const Center(
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: FincoreColors.accent,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

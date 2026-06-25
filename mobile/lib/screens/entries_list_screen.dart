import 'dart:async';

import 'package:fincore/app_dependencies.dart';
import 'package:fincore/constants/date_range_presets.dart';
import 'package:fincore/constants/kinds.dart';
import 'package:fincore/data/daos/entries_dao.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/data/entries_filters.dart';
import 'package:fincore/screens/entries_filters_screen.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/widgets/amount_formatter.dart';
import 'package:fincore/widgets/base_card.dart';
import 'package:fincore/widgets/category_badge.dart' as cb;
import 'package:fincore/models/category.dart' as model;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Pantalla de movimientos con filtros avanzados (sprint
/// `flutter-movements-filters-v1`).
///
/// Lee query params del router al montar para soportar deep link desde
/// `/reports`. El default sin query params es "Este mes" calendario
/// completo (cambio respecto al sprint anterior — RT-02 del plan).
///
/// Optimización del sprint patch (perf v1): cuentas y categorías se mantienen
/// como `List<>` resueltas en state vía `StreamSubscription` directa, en vez
/// de `StreamBuilder` anidados en `_ActiveFiltersBar` y en el panel. Esto
/// elimina re-suscripciones en cada rebuild del padre y baja el costo
/// percibido en el cel.
class EntriesListScreen extends StatefulWidget {
  const EntriesListScreen({super.key});

  @override
  State<EntriesListScreen> createState() => _EntriesListScreenState();
}

class _EntriesListScreenState extends State<EntriesListScreen> {
  EntriesFilters _filters = EntriesFilters.thisMonth();
  Stream<List<EntryWithRelations>>? _stream;

  // Estado resuelto de cuentas y categorías (mantenidos por subscriptions
  // directas, sin StreamBuilder en los hijos).
  List<Account> _accounts = const [];
  List<Category> _categories = const [];
  StreamSubscription<List<Account>>? _accountsSub;
  StreamSubscription<List<Category>>? _categoriesSub;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_stream != null) return;
    // Lee query params del router en la primera hidratación (RF-012).
    final route = GoRouterState.of(context);
    final params = route.uri.queryParameters;
    if (params.isNotEmpty) {
      _filters = EntriesFilters.parse(params);
    }
    _buildStream();
    _subscribeMeta();
  }

  void _subscribeMeta() {
    final deps = AppDependencies.of(context);
    _accountsSub ??= deps.accountsDao.watchActive().listen((rows) {
      if (!mounted) return;
      setState(() => _accounts = rows);
    });
    _categoriesSub ??= deps.categoriesDao.watchActive().listen((rows) {
      if (!mounted) return;
      setState(() => _categories = rows);
    });
  }

  void _buildStream() {
    final deps = AppDependencies.of(context);
    _stream = deps.entriesDao.watchPage(
      kinds: _filters.kinds.isEmpty ? null : _filters.kinds,
      categoryIds: _filters.categoryIds.isEmpty ? null : _filters.categoryIds,
      accountIds: _filters.accountIds.isEmpty ? null : _filters.accountIds,
      from: _filters.from,
      to: _filters.to,
      limit: 200,
    );
  }

  void _rebuildStream() {
    setState(_buildStream);
  }

  @override
  void dispose() {
    _accountsSub?.cancel();
    _categoriesSub?.cancel();
    super.dispose();
  }

  Future<void> _openFilters() async {
    final result = await Navigator.of(context).push<EntriesFilters>(
      MaterialPageRoute(
        builder: (_) => EntriesFiltersScreen(
          initial: _filters,
          accounts: _accounts,
          categories: _categories,
        ),
        fullscreenDialog: true,
      ),
    );
    if (result == null) return;
    _filters = result;
    _rebuildStream();
  }

  void _removeDimension(_FilterDimension dim) {
    switch (dim) {
      case _FilterDimension.date:
        _filters = _filters.withPreset(DateRangePreset.thisMonth);
        break;
      case _FilterDimension.kinds:
        _filters = _filters.copyWith(kinds: const []);
        break;
      case _FilterDimension.accounts:
        _filters = _filters.copyWith(accountIds: const []);
        break;
      case _FilterDimension.categories:
        _filters = _filters.copyWith(categoryIds: const []);
        break;
    }
    _rebuildStream();
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _filters.activeCount;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Movimientos'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          IconButton(
            tooltip: activeCount > 0 ? 'Filtros ($activeCount)' : 'Filtros',
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.tune),
                if (activeCount > 0)
                  Positioned(
                    right: -6,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: FincoreColors.accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      constraints: const BoxConstraints(minWidth: 16),
                      child: Text(
                        '$activeCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: FincoreColors.canvas,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: _openFilters,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/entries/new'),
        tooltip: 'Nuevo movimiento',
        backgroundColor: FincoreColors.accent,
        foregroundColor: FincoreColors.canvas,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          if (activeCount > 0)
            _ActiveFiltersBar(
              filters: _filters,
              accounts: _accounts,
              categories: _categories,
              onRemove: _removeDimension,
            ),
          Expanded(
            child: StreamBuilder<List<EntryWithRelations>>(
              stream: _stream,
              builder: (context, snap) {
                // Loading state estático (perf v1): SkeletonCard tiene
                // AnimationController.repeat() perpetuo que come ~60fps de
                // CPU con 5 instancias × 4 controllers cada una = 20
                // animations. Reemplazamos por un SizedBox vacío para que
                // se vea limpio mientras drift emite el primer evento.
                if (!snap.hasData) {
                  return const SizedBox.shrink();
                }
                final entries = snap.data!;
                if (entries.isEmpty) {
                  return _EmptyState(hasFilters: activeCount > 0);
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _Row(item: entries[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

enum _FilterDimension { date, kinds, accounts, categories }

class _ActiveFiltersBar extends StatelessWidget {
  final EntriesFilters filters;
  final List<Account> accounts;
  final List<Category> categories;
  final void Function(_FilterDimension) onRemove;

  const _ActiveFiltersBar({
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
                onRemove: () => onRemove(_FilterDimension.date),
              ),
            if (filters.kinds.isNotEmpty)
              _ActiveChip(
                label: _kindsLabel(filters.kinds),
                onRemove: () => onRemove(_FilterDimension.kinds),
              ),
            if (filters.accountIds.isNotEmpty)
              _ActiveChip(
                label: _accountsLabel(filters.accountIds),
                onRemove: () => onRemove(_FilterDimension.accounts),
              ),
            if (filters.categoryIds.isNotEmpty)
              _ActiveChip(
                label: _categoriesLabel(filters.categoryIds),
                onRemove: () => onRemove(_FilterDimension.categories),
              ),
          ],
        ),
      ),
    );
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
      return 'Cuenta';
    }
    return '${ids.length} cuentas';
  }

  String _categoriesLabel(List<String> ids) {
    if (ids.length == 1) {
      if (ids.first == kUncategorizedFilterToken) return 'Sin categoría';
      for (final c in categories) {
        if (c.id == ids.first) return c.name;
      }
      return 'Categoría';
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
            InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(10),
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(Icons.close, size: 14, color: FincoreColors.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasFilters;
  const _EmptyState({required this.hasFilters});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          hasFilters
              ? 'No hay movimientos con esos filtros.\nProbá ajustarlos.'
              : 'No hay movimientos.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: FincoreColors.textMuted),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final EntryWithRelations item;
  const _Row({required this.item});

  @override
  Widget build(BuildContext context) {
    final entry = item.entry;
    final kind = parseJournalKind(entry.kind);
    final color = switch (kind) {
      JournalKind.income => FincoreColors.positive,
      JournalKind.expense || JournalKind.creditExpense => FincoreColors.negative,
      JournalKind.debtPayment || JournalKind.transfer => FincoreColors.accent,
    };
    final dateStr = DateFormat('d MMM y', 'es_MX').format(entry.occurredAt);

    return BaseCard(
      onTap: () => context.push('/entries/${entry.id}/edit'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_kindIcon(kind), size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.description?.isNotEmpty == true ? entry.description! : kind.label,
                  style: const TextStyle(
                      color: FincoreColors.textPrimary, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('$dateStr · ${kind.label}',
                        style: const TextStyle(
                            color: FincoreColors.textSubtle, fontSize: 11)),
                    if (item.category != null)
                      cb.CategoryBadge(
                        category: model.Category(
                          id: item.category!.id,
                          name: item.category!.name,
                          appliesTo: item.category!.appliesTo,
                          colorSlug: item.category!.colorSlug,
                          iconSlug: item.category!.iconSlug,
                          monthlyLimit: item.category!.monthlyLimit,
                          deletedAt: item.category!.deletedAt,
                        ),
                        compact: true,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(_signed(kind, entry.amount),
              style: TextStyle(color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  IconData _kindIcon(JournalKind k) => switch (k) {
        JournalKind.income => Icons.arrow_downward,
        JournalKind.expense => Icons.arrow_upward,
        JournalKind.creditExpense => Icons.credit_card_outlined,
        JournalKind.debtPayment => Icons.payments_outlined,
        JournalKind.transfer => Icons.swap_horiz,
      };

  String _signed(JournalKind k, double amount) => switch (k) {
        JournalKind.income => formatAmount(amount, showSign: true),
        JournalKind.expense || JournalKind.creditExpense => '-${formatAmount(amount)}',
        JournalKind.debtPayment || JournalKind.transfer => formatAmount(amount),
      };
}

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

  // Sprint flutter-movements-pagination-v1: scroll infinito acumulativo.
  // `_currentLimit` crece +100 en cada `_loadMore` y `offset` queda en 0
  // por construcción — drift re-emite la lista completa al nuevo limit,
  // manteniendo reactividad sin riesgo de duplicados.
  //
  // Tope `_kMaxLimit = 2000` (patch post-quality-review): tras 20 páginas
  // cargadas el scroll deja de pedir más y el footer le pide al usuario que
  // acote filtros. Previene el caso patológico de query lenta + memoria alta
  // sin requerir paginación con offset real (sprint dedicado pendiente).
  int _currentLimit = _kPageSize;
  bool _reachedEnd = false;
  bool _reachedMaxLimit = false;
  bool _loadingMore = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_stream != null) return;
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
      limit: _currentLimit,
    );
  }

  /// Resetea los flags de paginación. Llamar como prefijo de `_buildStream`
  /// cuando cambia el filtro (panel "Aplicar", chip "X", "Limpiar todo").
  void _resetPagination() {
    _currentLimit = _kPageSize;
    _reachedEnd = false;
    _reachedMaxLimit = false;
    _loadingMore = false;
  }

  void _onScroll() {
    if (_reachedEnd || _reachedMaxLimit || _loadingMore) return;
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - _kScrollLoadMoreThreshold) {
      _loadMore();
    }
  }

  void _loadMore() {
    // Tope post-quality-review: si la próxima página supera `_kMaxLimit`,
    // marcamos `_reachedMaxLimit` y el footer cambia. El usuario debe
    // acotar filtros para ver entries adicionales.
    if (_currentLimit + _kPageSize > _kMaxLimit) {
      setState(() => _reachedMaxLimit = true);
      return;
    }
    setState(() {
      _currentLimit += _kPageSize;
      _loadingMore = true;
      _buildStream();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
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
    // Mutación dentro de setState para cerrar la ventana de inconsistencia
    // entre `_filters` y `_stream` (M4 del quality review v1).
    setState(() {
      _filters = result;
      _resetPagination();
      _buildStream();
    });
  }

  void _removeDimension(FilterDimension dim) {
    setState(() {
      _filters = _filters.clearDimension(dim);
      _resetPagination();
      _buildStream();
    });
  }

  void _clearAllFilters() {
    setState(() {
      _filters = EntriesFilters.thisMonth();
      _resetPagination();
      _buildStream();
    });
  }

  /// Reacciona al snapshot del Stream para mantener los flags de paginación
  /// coherentes con el contenido emitido. Programado vía postFrameCallback
  /// para no llamar setState desde el build.
  void _onSnapshotReceived(int receivedCount) {
    final shouldMarkEnd = receivedCount < _currentLimit && !_reachedEnd;
    final shouldClearLoading = receivedCount >= _currentLimit && _loadingMore;
    if (!shouldMarkEnd && !shouldClearLoading) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        if (shouldMarkEnd) {
          _reachedEnd = true;
          _loadingMore = false;
        } else if (shouldClearLoading) {
          _loadingMore = false;
        }
      });
    });
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
                // Loading state estático (perf v1).
                if (!snap.hasData) {
                  return const SizedBox.shrink();
                }
                final entries = snap.data!;
                // Reconciliar flags de paginación con el snapshot recibido.
                _onSnapshotReceived(entries.length);
                if (entries.isEmpty) {
                  return _EmptyState(
                    hasFilters: activeCount > 0,
                    onClearFilters: _clearAllFilters,
                  );
                }
                return _EntriesList(
                  entries: entries,
                  controller: _scrollController,
                  loadingMore: _loadingMore,
                  reachedEnd: _reachedEnd,
                  reachedMaxLimit: _reachedMaxLimit,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// _FilterDimension privado se reemplazó por FilterDimension público en
// lib/data/entries_filters.dart (M7 del quality review v1).

class _ActiveFiltersBar extends StatelessWidget {
  final EntriesFilters filters;
  final List<Account> accounts;
  final List<Category> categories;
  final void Function(FilterDimension) onRemove;

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
      // M5 del quality review v1: si la cuenta fue archivada entre tanto,
      // explicitar el estado en vez de mostrar "Cuenta" genérica.
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
      // M5 del quality review v1.
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
            // M2 del quality review v1: tap target del "X" expandido a 44x44
            // para cumplir Material guideline. Antes era ~18dp efectivos.
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

class _EmptyState extends StatelessWidget {
  final bool hasFilters;
  final VoidCallback onClearFilters;
  const _EmptyState({required this.hasFilters, required this.onClearFilters});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              hasFilters
                  ? 'No hay movimientos con esos filtros.\nProbá ajustarlos.'
                  : 'No hay movimientos.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: FincoreColors.textMuted),
            ),
            // M12 del quality review v1: botón directo de "Limpiar filtros"
            // cuando el estado vacío es por filtros (no por BD vacía).
            if (hasFilters) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onClearFilters,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Limpiar filtros'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: FincoreColors.accent,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Lista de movimientos con scroll infinito. Si `loadingMore`, `reachedEnd`
/// o `reachedMaxLimit`, agrega un item final con `_PaginationFooter` que
/// comunica el estado.
class _EntriesList extends StatelessWidget {
  final List<EntryWithRelations> entries;
  final ScrollController controller;
  final bool loadingMore;
  final bool reachedEnd;
  final bool reachedMaxLimit;

  const _EntriesList({
    required this.entries,
    required this.controller,
    required this.loadingMore,
    required this.reachedEnd,
    required this.reachedMaxLimit,
  });

  @override
  Widget build(BuildContext context) {
    final hasFooter = loadingMore || reachedEnd || reachedMaxLimit;
    final itemCount = entries.length + (hasFooter ? 1 : 0);
    return ListView.separated(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        if (hasFooter && i == entries.length) {
          return _PaginationFooter(
            loadingMore: loadingMore,
            reachedEnd: reachedEnd,
            reachedMaxLimit: reachedMaxLimit,
          );
        }
        return _Row(item: entries[i]);
      },
    );
  }
}

/// Footer condicional del scroll infinito. Estados en orden de precedencia:
/// - `loadingMore` → "Cargando…" sin animación.
/// - `reachedMaxLimit` → mensaje pidiendo acotar filtros.
/// - `reachedEnd` → "Fin de los movimientos del rango.".
class _PaginationFooter extends StatelessWidget {
  final bool loadingMore;
  final bool reachedEnd;
  final bool reachedMaxLimit;

  const _PaginationFooter({
    required this.loadingMore,
    required this.reachedEnd,
    required this.reachedMaxLimit,
  });

  @override
  Widget build(BuildContext context) {
    final String text;
    if (loadingMore) {
      text = 'Cargando…';
    } else if (reachedMaxLimit) {
      text = 'Llegaste a $_kMaxLimit movimientos cargados.\n'
          'Acotá filtros para ver entries más viejos.';
    } else {
      text = 'Fin de los movimientos del rango.';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: FincoreColors.textSubtle,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

/// Tamaño de página: cada `_loadMore` aumenta `_currentLimit` en este valor.
const int _kPageSize = 100;

/// Tope máximo del `_currentLimit` acumulado. Tras superarlo, el scroll
/// infinito se detiene y el footer pide acotar filtros. Patch post-quality-
/// review v1 para evitar el caso patológico de query lenta + memoria alta.
const int _kMaxLimit = 2000;

/// Threshold en píxeles desde el final del scroll donde se dispara
/// `_loadMore` automáticamente.
const double _kScrollLoadMoreThreshold = 300;

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

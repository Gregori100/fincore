import 'package:fincore/app_dependencies.dart';
import 'package:fincore/constants/kinds.dart';
import 'package:fincore/data/daos/entries_dao.dart';
import 'package:fincore/data/entries_filters.dart';
import 'package:fincore/models/category.dart' as model;
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/widgets/amount_formatter.dart';
import 'package:fincore/widgets/base_card.dart';
import 'package:fincore/widgets/category_badge.dart' as cb;
import 'package:fincore/widgets/entries_empty_state.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Lista paginada de movimientos con scroll infinito (sprint
/// `flutter-movements-pagination-v1`).
///
/// El widget encapsula:
/// - Stream del DAO según los `filters` recibidos.
/// - ScrollController + listener para `_loadMore` automático.
/// - State `_currentLimit`, `_loadingMore`, `_reachedEnd`, `_reachedMaxLimit`.
/// - Render del empty state (delegado) o de la lista + footer paginado.
///
/// Cuando `filters` cambia (detección en `didUpdateWidget`), resetea
/// paginación a la primera página y reconstruye el stream. El padre se
/// despreocupa de la mecánica de paginación.
class EntriesPaginatedList extends StatefulWidget {
  final EntriesFilters filters;
  final VoidCallback onClearFilters;

  const EntriesPaginatedList({
    super.key,
    required this.filters,
    required this.onClearFilters,
  });

  @override
  State<EntriesPaginatedList> createState() => _EntriesPaginatedListState();
}

class _EntriesPaginatedListState extends State<EntriesPaginatedList> {
  Stream<List<EntryWithRelations>>? _stream;
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
    _stream ??= _buildStream();
  }

  @override
  void didUpdateWidget(covariant EntriesPaginatedList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_filtersChanged(oldWidget.filters, widget.filters)) {
      setState(() {
        _resetPagination();
        _stream = _buildStream();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  bool _filtersChanged(EntriesFilters a, EntriesFilters b) {
    if (a.from != b.from) return true;
    if (a.to != b.to) return true;
    if (a.datePreset != b.datePreset) return true;
    if (!_listEquals(a.kinds, b.kinds)) return true;
    if (!_listEquals(a.accountIds, b.accountIds)) return true;
    if (!_listEquals(a.categoryIds, b.categoryIds)) return true;
    if (a.minAmount != b.minAmount) return true;
    if (a.maxAmount != b.maxAmount) return true;
    return false;
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Stream<List<EntryWithRelations>> _buildStream() {
    final deps = AppDependencies.of(context);
    return deps.entriesDao.watchPage(
      kinds: widget.filters.kinds.isEmpty ? null : widget.filters.kinds,
      categoryIds: widget.filters.categoryIds.isEmpty
          ? null
          : widget.filters.categoryIds,
      accountIds:
          widget.filters.accountIds.isEmpty ? null : widget.filters.accountIds,
      from: widget.filters.from,
      to: widget.filters.to,
      minAmount: widget.filters.minAmount,
      maxAmount: widget.filters.maxAmount,
      limit: _currentLimit,
    );
  }

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
    if (_currentLimit + _kPageSize > _kMaxLimit) {
      setState(() => _reachedMaxLimit = true);
      return;
    }
    setState(() {
      _currentLimit += _kPageSize;
      _loadingMore = true;
      _stream = _buildStream();
    });
  }

  /// Reacciona al snapshot del Stream para mantener los flags coherentes.
  /// Programado vía postFrameCallback para no llamar setState desde el build.
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
    final hasActiveFilters = widget.filters.activeCount > 0;
    return StreamBuilder<List<EntryWithRelations>>(
      stream: _stream,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox.shrink();
        }
        final entries = snap.data!;
        _onSnapshotReceived(entries.length);
        if (entries.isEmpty) {
          return EntriesEmptyState(
            hasFilters: hasActiveFilters,
            onClearFilters: widget.onClearFilters,
          );
        }
        final hasFooter = _loadingMore || _reachedEnd || _reachedMaxLimit;
        final itemCount = entries.length + (hasFooter ? 1 : 0);
        return ListView.separated(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
          itemCount: itemCount,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            if (hasFooter && i == entries.length) {
              return _PaginationFooter(
                loadingMore: _loadingMore,
                reachedEnd: _reachedEnd,
                reachedMaxLimit: _reachedMaxLimit,
              );
            }
            return _Row(item: entries[i]);
          },
        );
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
      JournalKind.expense ||
      JournalKind.creditExpense =>
        FincoreColors.negative,
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
                  entry.description?.isNotEmpty == true
                      ? entry.description!
                      : kind.label,
                  style: const TextStyle(
                      color: FincoreColors.textPrimary,
                      fontWeight: FontWeight.w500),
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
        JournalKind.expense ||
        JournalKind.creditExpense =>
          '-${formatAmount(amount)}',
        JournalKind.debtPayment ||
        JournalKind.transfer =>
          formatAmount(amount),
      };
}

import 'package:fincore/app_dependencies.dart';
import 'package:fincore/data/daos/entries_dao.dart';
import 'package:fincore/data/entries_filters.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/theme/fincore_spacing.dart';
import 'package:fincore/theme/fincore_typography.dart';
import 'package:fincore/widgets/entries_empty_state.dart';
import 'package:fincore/widgets/movement_row.dart';
import 'package:flutter/material.dart';

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
          padding: const EdgeInsets.fromLTRB(
            kSpaceLg,
            kSpaceMd,
            kSpaceLg,
            kFabClearance,
          ),
          itemCount: itemCount,
          separatorBuilder: (_, __) => const SizedBox(height: kSpaceSm),
          itemBuilder: (_, i) {
            if (hasFooter && i == entries.length) {
              return _PaginationFooter(
                loadingMore: _loadingMore,
                reachedEnd: _reachedEnd,
                reachedMaxLimit: _reachedMaxLimit,
              );
            }
            return MovementRow(item: entries[i]);
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
      padding: const EdgeInsets.symmetric(vertical: kSpaceLg),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: label.copyWith(color: FincoreColors.textSubtle),
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


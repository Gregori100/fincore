import 'dart:async';

import 'package:fincore/app_dependencies.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/data/entries_filters.dart';
import 'package:fincore/screens/entries_filters_screen.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/widgets/entries_active_filters_bar.dart';
import 'package:fincore/widgets/entries_paginated_list.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Pantalla de movimientos con filtros avanzados (sprint
/// `flutter-movements-filters-v1`).
///
/// Lee query params del router al montar para soportar deep link desde
/// `/reports`. El default sin query params es "Este mes" calendario completo.
///
/// **Arquitectura post-refactor (`flutter-entries-list-refactor-v1`)**:
/// - Esta pantalla maneja solo el shell: AppBar, FAB, state de filtros y
///   subscripciones a accounts/categories para alimentar la bar y el panel.
/// - La paginación + stream + scroll + lista + footer + row se delegaron a
///   [`EntriesPaginatedList`]. Recibe `filters` como prop y resetea
///   paginación cuando cambian.
/// - La bar de filtros activos vive en [`EntriesActiveFiltersBar`].
/// - El empty state vive en [`EntriesEmptyState`] (usado internamente por
///   `EntriesPaginatedList`).
///
/// Cuentas y categorías se mantienen como `List<>` resueltas vía
/// `StreamSubscription` directa (perf v1) para evitar `StreamBuilder`
/// anidados en el bar y el panel.
class EntriesListScreen extends StatefulWidget {
  const EntriesListScreen({super.key});

  @override
  State<EntriesListScreen> createState() => _EntriesListScreenState();
}

class _EntriesListScreenState extends State<EntriesListScreen> {
  EntriesFilters _filters = EntriesFilters.thisMonth();
  bool _parsedDeepLink = false;

  List<Account> _accounts = const [];
  List<Category> _categories = const [];
  StreamSubscription<List<Account>>? _accountsSub;
  StreamSubscription<List<Category>>? _categoriesSub;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_parsedDeepLink) {
      _parsedDeepLink = true;
      final route = GoRouterState.of(context);
      final params = route.uri.queryParameters;
      if (params.isNotEmpty) {
        _filters = EntriesFilters.parse(params);
      }
    }
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
    setState(() => _filters = result);
  }

  void _removeDimension(FilterDimension dim) {
    setState(() => _filters = _filters.clearDimension(dim));
  }

  void _clearAllFilters() {
    setState(() => _filters = EntriesFilters.thisMonth());
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
            EntriesActiveFiltersBar(
              filters: _filters,
              accounts: _accounts,
              categories: _categories,
              onRemove: _removeDimension,
            ),
          Expanded(
            child: EntriesPaginatedList(
              filters: _filters,
              onClearFilters: _clearAllFilters,
            ),
          ),
        ],
      ),
    );
  }
}

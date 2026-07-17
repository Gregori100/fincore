import 'dart:async';

import 'package:fincore/app_dependencies.dart';
import 'package:fincore/data/daos/entries_dao.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/data/entries_filters.dart';
import 'package:fincore/screens/entries_filters_screen.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/screens/saved_views_list_screen.dart';
import 'package:fincore/widgets/bulk_category_sheet.dart';
import 'package:fincore/widgets/entries_active_filters_bar.dart';
import 'package:fincore/widgets/entries_paginated_list.dart';
import 'package:fincore/widgets/error_snackbar.dart';
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

  // Sprint flutter-entries-bulk-recategorize-v1: modo selección múltiple.
  // Long-press activa. Tap toggle. Back nativo (o botón "cerrar" del AppBar
  // contextual) sale. Al ejecutar la acción bulk se sale automáticamente.
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};
  // Kinds únicos actualmente seleccionados. Determina qué categorías
  // ofrece el sheet (compatibilidad por applies_to). Se rehidrata desde el
  // snapshot del stream cuando se abre la acción, no se mantiene aquí.

  void _enterSelectionMode(String id) {
    setState(() {
      _selectionMode = true;
      _selectedIds
        ..clear()
        ..add(id);
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
      // Si quedó vacío, salir de modo selección. Coherente con el patrón
      // de weekly_budgets/list_screen: la ausencia total de selección
      // significa que el usuario ya no quiere estar en el modo.
      if (_selectedIds.isEmpty) {
        _selectionMode = false;
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  /// Abre el bottom sheet con las categorías compatibles con TODOS los
  /// kinds del batch. `bulkUpdateCategory` valida server-side igual, pero
  /// filtrar en la UI evita que el usuario intente asignar algo que sabemos
  /// que va a fallar.
  Future<void> _openBulkCategorySheet() async {
    if (_selectedIds.isEmpty) return;
    final deps = AppDependencies.of(context);
    // Fetch kinds del batch en 1 query (menos ida-vuelta que iterar).
    final entries = await deps.entriesDao.findByIds(_selectedIds.toList());
    if (!mounted) return;
    final kinds = entries.map((e) => e.kind).toSet();
    final result = await showModalBottomSheet<BulkCategoryResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FincoreColors.surface,
      builder: (_) => BulkCategorySheet(
        selectedCount: _selectedIds.length,
        batchKinds: kinds,
        categories: _categories,
      ),
    );
    if (result == null || !mounted) return;
    await _applyBulkCategory(result.categoryId);
  }

  Future<void> _applyBulkCategory(String? categoryId) async {
    final deps = AppDependencies.of(context);
    final ids = _selectedIds.toList();
    final count = ids.length;
    try {
      await deps.entriesDao.bulkUpdateCategory(
        entryIds: ids,
        categoryId: categoryId,
      );
      if (!mounted) return;
      final msg = categoryId == null
          ? '$count movimientos sin categoría'
          : '$count movimientos actualizados';
      showSuccessSnackbar(context, msg);
      _exitSelectionMode();
    } on EntriesDaoError catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    }
  }

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

  /// Sprint `flutter-entries-saved-views-v1` + patch UX v4: push a la
  /// pantalla full-screen con la lista de vistas guardadas. Si retorna
  /// filtros (Diego tappeó una vista), los aplica.
  ///
  /// Cambió de `showModalBottomSheet` a `MaterialPageRoute` para eliminar
  /// la interacción problemática sheet-sobre-sheet (shrink visual del
  /// padre cuando un sheet hijo abría teclado).
  Future<void> _openSavedViews() async {
    final result = await Navigator.of(context).push<EntriesFilters>(
      MaterialPageRoute(
        builder: (_) => const SavedViewsListScreen(),
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
    return PopScope(
      // En modo selección el back nativo sale del modo en vez de cerrar la
      // pantalla — mismo patrón que weekly_budgets/list_screen.
      canPop: !_selectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_selectionMode) _exitSelectionMode();
      },
      child: Scaffold(
        appBar: _buildAppBar(activeCount),
        floatingActionButton: _selectionMode
            ? null
            : FloatingActionButton(
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
                selectionMode: _selectionMode,
                selectedIds: _selectedIds,
                onEnterSelection: _enterSelectionMode,
                onToggleSelection: _toggleSelection,
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(int activeCount) {
    if (_selectionMode) {
      final count = _selectedIds.length;
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Salir de selección',
          onPressed: _exitSelectionMode,
        ),
        title: Text(
          count == 1 ? '1 seleccionado' : '$count seleccionados',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.local_offer_outlined),
            tooltip: 'Asignar categoría',
            onPressed: _selectedIds.isEmpty ? null : _openBulkCategorySheet,
          ),
        ],
      );
    }
    return AppBar(
      title: const Text('Movimientos'),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      actions: [
        // Sprint `flutter-entries-saved-views-v1` (RF-007): icono de
        // vistas guardadas. Tap abre sheet con CRUD.
        IconButton(
          tooltip: 'Mis vistas',
          icon: const Icon(Icons.bookmark_outline),
          onPressed: _openSavedViews,
        ),
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
    );
  }
}

import 'package:fincore/app_dependencies.dart';
import 'package:fincore/data/daos/weekly_budgets_dao.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/data/weekly_budgets.dart';
import 'package:fincore/screens/weekly_budgets/widgets/edit_label_dialog.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/widgets/amount_formatter.dart';
import 'package:fincore/widgets/base_card.dart';
import 'package:fincore/widgets/confirm_dialog.dart';
import 'package:fincore/widgets/error_snackbar.dart';
import 'package:fincore/widgets/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Listado agrupado de presupuestos semanales (T020 del sprint
/// `flutter-weekly-budgets-v1`).
///
/// 3 secciones (`Esta semana` / `Próximas` / `Pasadas`) calculadas con
/// `groupBudgetsByRange` — secciones vacías no se renderan. Sin presupuestos
/// en absoluto → empty state con CTA. FAB dual: "En blanco" (siempre) o
/// "Desde plantilla" (solo si hay >=1 plantilla activa).
class WeeklyBudgetsListScreen extends StatefulWidget {
  const WeeklyBudgetsListScreen({super.key});

  @override
  State<WeeklyBudgetsListScreen> createState() =>
      _WeeklyBudgetsListScreenState();
}

class _WeeklyBudgetsListScreenState extends State<WeeklyBudgetsListScreen> {
  Stream<List<WeeklyBudgetRow>>? _budgetsStream;
  Stream<List<WeeklyBudgetRow>>? _templatesStream;
  int? _weekStartDow;

  // Multi-select (fix UX/UI): long-press en una card entra en modo
  // selección; tap alterna selección de otras cards mientras dura el modo.
  bool _selectionMode = false;
  Set<String> _selectedIds = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Guard de "solo una vez", mismo patrón que `DashboardScreen`. No se usa
    // `initState` para el fetch async de `weekStartDow` porque
    // `AppDependencies.of(context)` depende de `dependOnInheritedWidgetOfExactType`,
    // que el framework no permite invocar antes de `didChangeDependencies`.
    if (_budgetsStream != null) return;
    final deps = AppDependencies.of(context);
    _budgetsStream = deps.weeklyBudgetsDao.watchAll();
    _templatesStream = deps.weeklyBudgetsDao.watchTemplates();
    _loadWeekStartDow(deps);
  }

  Future<void> _loadWeekStartDow(AppDependencies deps) async {
    final dow = await deps.appPreferencesDao.weekStartDow();
    if (!mounted) return;
    setState(() => _weekStartDow = dow);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Back nativo: si estamos en modo selección, el back sale del modo en
      // vez de cerrar la pantalla. Fuera de ese modo, back normal.
      canPop: !_selectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_selectionMode) _exitSelectionMode();
      },
      child: StreamBuilder<List<WeeklyBudgetRow>>(
        stream: _budgetsStream,
        builder: (context, snap) {
          if (snap.hasError) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) showErrorSnackbar(context, snap.error!);
            });
          }
          if (!snap.hasData || _weekStartDow == null) {
            return Scaffold(
              appBar: _buildAppBar(const []),
              floatingActionButton: _buildFab(),
              body: _buildLoadingSkeleton(),
            );
          }
          final budgets = snap.data!;
          final now = DateTime.now();
          final weekStartDow = _weekStartDow!;
          final grouped = groupBudgetsByRange(
            budgets: budgets,
            now: now,
            weekStartDow: weekStartDow,
          );
          final thisWeek = grouped[BudgetSection.thisWeek]!;
          final upcoming = grouped[BudgetSection.upcoming]!;
          final past = grouped[BudgetSection.past]!;
          final isEmpty = thisWeek.isEmpty && upcoming.isEmpty && past.isEmpty;

          return Scaffold(
            appBar: _buildAppBar(budgets),
            // Fix UX/UI (pass post quality-review): con la lista vacía, el
            // CTA único vive en `_EmptyState` — el FAB del Scaffold se
            // oculta para no duplicar la acción de crear el primer
            // presupuesto. Tampoco se muestra en modo selección.
            floatingActionButton:
                (isEmpty || _selectionMode) ? null : _buildFab(),
            body:
                isEmpty
                    ? _EmptyState(onCreate: _openCreateSheet)
                    : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                      children: [
                        if (thisWeek.isNotEmpty)
                          ..._buildSection(
                            'Esta semana',
                            thisWeek,
                            allBudgets: budgets,
                          ),
                        if (upcoming.isNotEmpty)
                          ..._buildSection(
                            'Próximas',
                            upcoming,
                            allBudgets: budgets,
                          ),
                        if (past.isNotEmpty)
                          ..._buildSection(
                            'Pasadas',
                            past,
                            allBudgets: budgets,
                            dimmed: true,
                          ),
                      ],
                    ),
          );
        },
      ),
    );
  }

  AppBar _buildAppBar(List<WeeklyBudgetRow> budgets) {
    if (_selectionMode) {
      final count = _selectedIds.length;
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Salir de selección',
          onPressed: _exitSelectionMode,
        ),
        title: Text(count == 1 ? '1 seleccionado' : '$count seleccionados'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Eliminar seleccionados',
            onPressed: _selectedIds.isEmpty ? null : _bulkDelete,
          ),
        ],
      );
    }
    return AppBar(
      title: const Text('Presupuestos semanales'),
      actions: [
        IconButton(
          icon: const Icon(Icons.calendar_view_month),
          tooltip: 'Vista calendario',
          onPressed: () => context.push('/budgets/calendar'),
        ),
        PopupMenuButton<String>(
          tooltip: 'Más opciones',
          onSelected: (action) {
            if (action == 'delete_all') {
              _deleteAllBudgets();
            } else if (action == 'select_mode') {
              setState(() => _selectionMode = true);
            }
          },
          itemBuilder:
              (_) => [
                // Sin `Expanded` estos labels desbordan el ancho fijo del
                // menú (~256px) — mismo fix L1 aplicado en
                // `detail_screen.dart` y en el `PopupMenuButton` de la card.
                if (budgets.isNotEmpty)
                  const PopupMenuItem(
                    value: 'delete_all',
                    child: Row(
                      children: [
                        Icon(Icons.delete_sweep_outlined, size: 18),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Eliminar todos',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'select_mode',
                  child: Row(
                    children: [
                      Icon(Icons.checklist, size: 18),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Seleccionar presupuestos',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
        ),
      ],
    );
  }

  // ===========================================================================
  // Multi-select bulk actions
  // ===========================================================================

  void _enterSelectionMode(String id) {
    setState(() {
      _selectionMode = true;
      _selectedIds = {id};
    });
  }

  void _toggleSelected(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _bulkDelete() async {
    final deps = AppDependencies.of(context);
    final ids = _selectedIds.toList();
    final count = ids.length;

    final confirmed = await showConfirmDialog(
      context,
      title: 'Eliminar presupuestos',
      message:
          'Eliminar $count presupuestos y todos sus renglones? Esta '
          'acción no se puede deshacer.',
      confirmLabel: 'Eliminar',
    );
    if (!confirmed) return;
    if (!mounted) return;

    try {
      for (final id in ids) {
        await deps.weeklyBudgetsDao.deleteBudget(id);
      }
      if (!mounted) return;
      setState(() {
        _selectionMode = false;
        _selectedIds.clear();
      });
      showSuccessSnackbar(context, '$count presupuestos eliminados.');
    } on WeeklyBudgetsDaoError catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    }
  }

  /// "Eliminar todos" desde el `PopupMenuButton` del AppBar normal (fuera de
  /// modo selección). Usa el stream cacheado para conocer todos los ids
  /// existentes al momento de confirmar.
  Future<void> _deleteAllBudgets() async {
    final budgetsStream = _budgetsStream;
    if (budgetsStream == null) return;
    final deps = AppDependencies.of(context);
    final all = await budgetsStream.first;
    if (!mounted || all.isEmpty) return;
    final count = all.length;

    final confirmed = await showConfirmDialog(
      context,
      title: 'Eliminar todos los presupuestos',
      message:
          'Eliminar los $count presupuestos y todos sus renglones? '
          'Esta acción no se puede deshacer.',
      confirmLabel: 'Eliminar',
    );
    if (!confirmed) return;
    if (!mounted) return;

    try {
      for (final b in all) {
        await deps.weeklyBudgetsDao.deleteBudget(b.id);
      }
      if (mounted) {
        showSuccessSnackbar(context, '$count presupuestos eliminados.');
      }
    } on WeeklyBudgetsDaoError catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    }
  }

  Widget _buildFab() {
    return FloatingActionButton.extended(
      onPressed: _openCreateSheet,
      tooltip: 'Nuevo presupuesto',
      icon: const Icon(Icons.add),
      label: const Text('Presupuesto'),
      backgroundColor: FincoreColors.accent,
      foregroundColor: FincoreColors.canvas,
    );
  }

  Widget _buildLoadingSkeleton() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: const [
        SkeletonCard(),
        SizedBox(height: 8),
        SkeletonCard(),
        SizedBox(height: 8),
        SkeletonCard(),
      ],
    );
  }

  /// `dimmed: true` atenúa cada card (usado en la sección "Pasadas" — quick
  /// win QW2: jerarquía visual entre presupuestos vigentes y ya cerrados).
  ///
  /// `allBudgets`: la lista completa (las 3 secciones sin agrupar), no solo
  /// la de esta sección — `_BudgetCard` la necesita para calcular sus
  /// "hermanos" de la misma semana (entry point de "Comparar con...", sprint
  /// `flutter-weekly-budgets-v1`), que pueden caer en otra sección si el
  /// caller pidió `upcoming`/`past` (ambas mezclan semanas distintas).
  List<Widget> _buildSection(
    String title,
    List<WeeklyBudgetRow> budgets, {
    required List<WeeklyBudgetRow> allBudgets,
    bool dimmed = false,
  }) {
    return [
      SectionTitle(title),
      const SizedBox(height: 8),
      for (var i = 0; i < budgets.length; i++) ...[
        if (i > 0) const SizedBox(height: 8),
        if (dimmed)
          Opacity(
            opacity: 0.7,
            child: _BudgetCard(
              budget: budgets[i],
              allBudgets: allBudgets,
              selectionMode: _selectionMode,
              selected: _selectedIds.contains(budgets[i].id),
              onToggleSelect: _toggleSelected,
              onEnterSelection: _enterSelectionMode,
            ),
          )
        else
          _BudgetCard(
            budget: budgets[i],
            allBudgets: allBudgets,
            selectionMode: _selectionMode,
            selected: _selectedIds.contains(budgets[i].id),
            onToggleSelect: _toggleSelected,
            onEnterSelection: _enterSelectionMode,
          ),
      ],
      const SizedBox(height: 24),
    ];
  }

  // ===========================================================================
  // FAB "Presupuesto" — bottom sheet dual + flows de creación
  // ===========================================================================

  Future<void> _openCreateSheet() async {
    final templatesStream = _templatesStream;
    if (templatesStream == null) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: FincoreColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StreamBuilder<List<WeeklyBudgetRow>>(
          stream: templatesStream,
          builder: (context, snap) {
            final hasTemplates =
                (snap.data ?? const <WeeklyBudgetRow>[]).isNotEmpty;
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.note_add_outlined,
                      color: FincoreColors.textPrimary,
                    ),
                    title: const Text(
                      'En blanco',
                      style: TextStyle(color: FincoreColors.textPrimary),
                    ),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _createBlankBudgetFlow();
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.description_outlined,
                      color:
                          hasTemplates
                              ? FincoreColors.textPrimary
                              : FincoreColors.textSubtle,
                    ),
                    title: Text(
                      'Desde plantilla',
                      style: TextStyle(
                        color:
                            hasTemplates
                                ? FincoreColors.textPrimary
                                : FincoreColors.textSubtle,
                      ),
                    ),
                    enabled: hasTemplates,
                    onTap:
                        hasTemplates
                            ? () {
                              Navigator.of(sheetContext).pop();
                              _createFromTemplateFlow();
                            }
                            : null,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _createBlankBudgetFlow() async {
    final deps = AppDependencies.of(context);
    final weekStartDate = await _pickWeekStartDate();
    if (weekStartDate == null || !mounted) return;
    final label = await deps.weeklyBudgetsDao.generateAutoLabel(weekStartDate);
    if (!mounted) return;

    try {
      final id = await deps.weeklyBudgetsDao.createBudget(
        weekStartDate: weekStartDate,
        label: label,
      );
      if (mounted) context.push('/budgets/$id');
    } on WeeklyBudgetsDaoError catch (e) {
      if (mounted) showWarningSnackbar(context, e.message);
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    }
  }

  Future<void> _createFromTemplateFlow() async {
    final templatesStream = _templatesStream;
    if (templatesStream == null) return;
    final template = await showModalBottomSheet<WeeklyBudgetRow>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: FincoreColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (sheetContext) =>
              _TemplatePickerSheet(templatesStream: templatesStream),
    );
    if (template == null || !mounted) return;

    final deps = AppDependencies.of(context);
    final weekStartDate = await _pickWeekStartDate();
    if (weekStartDate == null || !mounted) return;
    final label = await deps.weeklyBudgetsDao.generateAutoLabel(weekStartDate);
    if (!mounted) return;

    try {
      final id = await deps.weeklyBudgetsDao.createBudgetFromTemplate(
        weekStartDate: weekStartDate,
        label: label,
        templateId: template.id,
      );
      if (mounted) context.push('/budgets/$id');
    } on WeeklyBudgetsDaoError catch (e) {
      if (mounted) showWarningSnackbar(context, e.message);
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    }
  }

  Future<DateTime?> _pickWeekStartDate() async {
    final now = DateTime.now();
    final suggested = suggestedWeekStartDate(
      now: now,
      weekStartDow: _weekStartDow ?? 5,
    );
    return showDatePicker(
      context: context,
      initialDate: suggested,
      firstDate: DateTime(now.year - 2, now.month, now.day),
      lastDate: DateTime(now.year + 2, now.month, now.day),
      helpText: 'Semana del presupuesto',
    );
  }
}

/// Capitaliza la primera letra de un string formateado por `DateFormat`
/// (`intl` en español devuelve minúsculas: "vie", "mar").
String _capitalize(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

/// Formatea el rango de una semana como "Vie 17 mar - Jue 23 mar".
String _formatRangeLabel(DateTime start, DateTime endExclusive) {
  final end = endExclusive.subtract(const Duration(days: 1));
  final fmt = DateFormat('EEE d MMM', 'es_MX');
  return '${_capitalize(fmt.format(start))} - ${_capitalize(fmt.format(end))}';
}

class _BudgetCard extends StatelessWidget {
  final WeeklyBudgetRow budget;
  final List<WeeklyBudgetRow> allBudgets;

  /// Multi-select (fix UX/UI): mientras `selectionMode == true`, el tap
  /// normal alterna selección en vez de navegar y el `PopupMenuButton` de
  /// acciones rápidas se esconde a favor del `Checkbox`.
  final bool selectionMode;
  final bool selected;
  final ValueChanged<String> onToggleSelect;
  final ValueChanged<String> onEnterSelection;

  const _BudgetCard({
    required this.budget,
    required this.allBudgets,
    this.selectionMode = false,
    this.selected = false,
    required this.onToggleSelect,
    required this.onEnterSelection,
  });

  /// Otros presupuestos (activos — hard delete, `allBudgets` ya solo trae
  /// los existentes) de la misma `week_start_date`, excluyendo este mismo.
  /// Determina si "Comparar con..." aparece en el menú (sprint
  /// `flutter-weekly-budgets-v1`).
  List<WeeklyBudgetRow> get _sameWeekSiblings =>
      allBudgets
          .where(
            (b) =>
                b.id != budget.id &&
                b.weekStartDate.isAtSameMomentAs(budget.weekStartDate),
          )
          .toList();

  @override
  Widget build(BuildContext context) {
    final deps = AppDependencies.of(context);
    final range = weekRangeOf(budget.weekStartDate);
    return BaseCard(
      onTap:
          selectionMode
              ? () => onToggleSelect(budget.id)
              : () => context.push('/budgets/${budget.id}'),
      onLongPress: selectionMode ? null : () => onEnterSelection(budget.id),
      backgroundColor:
          selected ? FincoreColors.accent.withValues(alpha: 0.1) : null,
      borderColor: selected ? FincoreColors.accent : null,
      borderWidth: selected ? 2 : 1,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selectionMode) ...[
                Checkbox(
                  value: selected,
                  activeColor: FincoreColors.accent,
                  onChanged: (_) => onToggleSelect(budget.id),
                ),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            budget.label,
                            style: const TextStyle(
                              color: FincoreColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Badge de plantilla (refactor 2026-07-14): un
                        // budget marcado con `is_template` muestra este
                        // ícono junto a su label, tanto acá como en el
                        // AppBar de `detail_screen.dart`.
                        if (budget.isTemplate) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.bookmark,
                            size: 16,
                            color: FincoreColors.accent,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatRangeLabel(range.start, range.endExclusive),
                      style: const TextStyle(
                        color: FincoreColors.textSubtle,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Fix UX/UI (pass post quality-review): acciones rápidas
              // editar/eliminar sin entrar al detalle. Tamaño chico + padding
              // cero para no romper el layout del row de la card.
              // Multi-select: se esconde durante el modo selección — el
              // `Checkbox` a la izquierda es la única affordance de tap.
              if (!selectionMode)
                PopupMenuButton<String>(
                  tooltip: 'Más acciones',
                  padding: EdgeInsets.zero,
                  iconSize: 20,
                  icon: const Icon(
                    Icons.more_vert,
                    size: 20,
                    color: FincoreColors.textSubtle,
                  ),
                  onSelected: (action) {
                    if (action == 'edit_label') {
                      _onEditLabel(context);
                    } else if (action == 'delete') {
                      _onDelete(context);
                    } else if (action == 'compare') {
                      _onCompare(context);
                    } else if (action == 'toggleTemplate') {
                      _onToggleTemplate(context);
                    }
                  },
                  itemBuilder:
                      (_) => [
                        const PopupMenuItem(
                          value: 'edit_label',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 18),
                              SizedBox(width: 12),
                              Text('Editar label'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'toggleTemplate',
                          child: Row(
                            children: [
                              const Icon(Icons.bookmark_outline, size: 18),
                              const SizedBox(width: 12),
                              // Sin `Expanded` este label desborda el ancho fijo
                              // del menú (~256px) — mismo fix L1 aplicado en
                              // `detail_screen.dart`.
                              Expanded(
                                child: Text(
                                  budget.isTemplate
                                      ? 'Quitar de plantillas'
                                      : 'Marcar como plantilla',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Condicional (sprint `flutter-weekly-budgets-v1`): solo
                        // aparece si hay >=1 otro presupuesto activo en la misma
                        // semana.
                        if (_sameWeekSiblings.isNotEmpty)
                          const PopupMenuItem(
                            value: 'compare',
                            child: Row(
                              children: [
                                Icon(Icons.compare_arrows, size: 18),
                                SizedBox(width: 12),
                                Text('Comparar con...'),
                              ],
                            ),
                          ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: FincoreColors.negative,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Eliminar',
                                style: TextStyle(color: FincoreColors.negative),
                              ),
                            ],
                          ),
                        ),
                      ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: StreamBuilder<List<WeeklyBudgetItemRow>>(
                  stream: deps.weeklyBudgetsDao.watchBudgetItems(budget.id),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Skeleton(width: 100, height: 12);
                    }
                    final items = snap.data!;
                    final incomeCount =
                        items.where((i) => i.kind == 'income').length;
                    final expenseCount =
                        items.where((i) => i.kind == 'expense').length;
                    return Text(
                      '$incomeCount ingresos · $expenseCount gastos',
                      style: const TextStyle(
                        color: FincoreColors.textSubtle,
                        fontSize: 12,
                      ),
                    );
                  },
                ),
              ),
              StreamBuilder<double>(
                stream: deps.weeklyBudgetsDao.watchBudgetBalance(budget.id),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Skeleton(width: 70, height: 14);
                  }
                  final balance = snap.data!;
                  final String label;
                  final Color color;
                  if (balance > 0) {
                    label = 'Sobra ${formatAmount(balance)}';
                    color = FincoreColors.positive;
                  } else if (balance < 0) {
                    label = 'Faltan ${formatAmount(balance.abs())}';
                    color = FincoreColors.negative;
                  } else {
                    label = 'En equilibrio';
                    color = FincoreColors.textMuted;
                  }
                  return Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _onEditLabel(BuildContext context) async {
    final deps = AppDependencies.of(context);
    final result = await showEditLabelDialog(
      context,
      currentLabel: budget.label,
    );
    if (result == null) return;
    if (!context.mounted) return;

    try {
      await deps.weeklyBudgetsDao.updateBudget(budget.id, label: result);
      if (context.mounted) showSuccessSnackbar(context, 'Nombre actualizado.');
    } on WeeklyBudgetsDaoError catch (e) {
      if (context.mounted) showErrorSnackbar(context, e);
    }
  }

  Future<void> _onToggleTemplate(BuildContext context) async {
    final deps = AppDependencies.of(context);
    final wasTemplate = budget.isTemplate;
    try {
      await deps.weeklyBudgetsDao.toggleTemplateFlag(budget.id);
      if (context.mounted) {
        showSuccessSnackbar(
          context,
          wasTemplate
              ? 'Se quitó la marca de plantilla.'
              : 'Presupuesto marcado como plantilla.',
        );
      }
    } on WeeklyBudgetsDaoError catch (e) {
      if (context.mounted) showErrorSnackbar(context, e);
    }
  }

  /// Abre un bottom sheet con los otros presupuestos de la misma semana
  /// (nombre + balance). Al elegir uno, navega a `/budgets/compare/A/B`.
  Future<void> _onCompare(BuildContext context) async {
    final others = _sameWeekSiblings;
    final deps = AppDependencies.of(context);
    final other = await showModalBottomSheet<WeeklyBudgetRow>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: FincoreColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Comparar con...',
                  style: TextStyle(
                    color: FincoreColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                for (final sibling in others)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      sibling.label,
                      style: const TextStyle(color: FincoreColors.textPrimary),
                    ),
                    subtitle: StreamBuilder<double>(
                      stream: deps.weeklyBudgetsDao.watchBudgetBalance(
                        sibling.id,
                      ),
                      builder: (context, snap) {
                        if (!snap.hasData) {
                          return const Skeleton(width: 80, height: 12);
                        }
                        final balance = snap.data!;
                        final String label;
                        final Color color;
                        if (balance > 0) {
                          label = 'Sobra ${formatAmount(balance)}';
                          color = FincoreColors.positive;
                        } else if (balance < 0) {
                          label = 'Faltan ${formatAmount(balance.abs())}';
                          color = FincoreColors.negative;
                        } else {
                          label = 'En equilibrio';
                          color = FincoreColors.textMuted;
                        }
                        return Text(label, style: TextStyle(color: color));
                      },
                    ),
                    onTap: () => Navigator.of(sheetContext).pop(sibling),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (other == null || !context.mounted) return;
    context.push('/budgets/compare/${budget.id}/${other.id}');
  }

  Future<void> _onDelete(BuildContext context) async {
    final deps = AppDependencies.of(context);
    final currentItems =
        await deps.weeklyBudgetsDao.watchBudgetItems(budget.id).first;
    if (!context.mounted) return;

    final confirmed = await showConfirmDialog(
      context,
      title: 'Eliminar presupuesto',
      message:
          'Esto borrará el presupuesto y sus ${currentItems.length} '
          'renglones. Esta acción no se puede deshacer.',
      confirmLabel: 'Eliminar',
    );
    if (!confirmed) return;
    if (!context.mounted) return;

    try {
      await deps.weeklyBudgetsDao.deleteBudget(budget.id);
      if (context.mounted) {
        showSuccessSnackbar(context, 'Presupuesto eliminado.');
      }
    } on WeeklyBudgetsDaoError catch (e) {
      if (context.mounted) showErrorSnackbar(context, e);
    }
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.calendar_month_outlined,
              size: 48,
              color: FincoreColors.textSubtle,
            ),
            const SizedBox(height: 16),
            const Text(
              'No hay presupuestos todavía.',
              textAlign: TextAlign.center,
              style: TextStyle(color: FincoreColors.textMuted),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Crear primer presupuesto'),
              style: FilledButton.styleFrom(
                backgroundColor: FincoreColors.accent,
                foregroundColor: FincoreColors.canvas,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet de selección de plantilla con preview de sus renglones.
/// Usado por `_createFromTemplateFlow`. Retorna la plantilla elegida (o
/// `null` si se cancela) vía `Navigator.pop`.
class _TemplatePickerSheet extends StatefulWidget {
  final Stream<List<WeeklyBudgetRow>> templatesStream;
  const _TemplatePickerSheet({required this.templatesStream});

  @override
  State<_TemplatePickerSheet> createState() => _TemplatePickerSheetState();
}

class _TemplatePickerSheetState extends State<_TemplatePickerSheet> {
  WeeklyBudgetRow? _selected;

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    // `useSafeArea: true` en showModalBottomSheet NO cubre la nav bar
    // gestual de Android; solo protege el status bar. Sumamos viewPadding
    // (nav bar) + viewInsets (teclado) al padding inferior para que los
    // botones "Cancelar/Continuar" no queden tapados por el sistema.
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 4,
        bottom: media.viewInsets.bottom + media.viewPadding.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Elige un presupuesto marcado',
              style: TextStyle(
                color: FincoreColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<WeeklyBudgetRow>>(
              stream: widget.templatesStream,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: FincoreColors.accent,
                      ),
                    ),
                  );
                }
                final templates = snap.data!;
                if (templates.isEmpty) {
                  return const Text(
                    'No hay plantillas disponibles.',
                    style: TextStyle(color: FincoreColors.textMuted),
                  );
                }
                return Column(
                  children: [
                    for (final template in templates)
                      RadioListTile<String>(
                        value: template.id,
                        groupValue: selected?.id,
                        activeColor: FincoreColors.accent,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          template.label,
                          style: const TextStyle(
                            color: FincoreColors.textPrimary,
                          ),
                        ),
                        onChanged: (_) => setState(() => _selected = template),
                      ),
                  ],
                );
              },
            ),
            if (selected != null) ...[
              const SizedBox(height: 8),
              const Divider(color: FincoreColors.border),
              const SizedBox(height: 8),
              Text(
                'Renglones de "${selected.label}"',
                style: const TextStyle(
                  color: FincoreColors.textSubtle,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              StreamBuilder<List<WeeklyBudgetItemRow>>(
                stream: AppDependencies.of(
                  context,
                ).weeklyBudgetsDao.watchBudgetItems(selected.id),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Skeleton(width: double.infinity, height: 40);
                  }
                  final items = snap.data!;
                  if (items.isEmpty) {
                    return const Text(
                      'Sin renglones todavía.',
                      style: TextStyle(
                        color: FincoreColors.textSubtle,
                        fontSize: 12,
                      ),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final item in items)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.name,
                                  style: const TextStyle(
                                    color: FincoreColors.textPrimary,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                formatAmount(item.amount),
                                style: TextStyle(
                                  color:
                                      item.kind == 'income'
                                          ? FincoreColors.positive
                                          : FincoreColors.negative,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: FincoreColors.textSubtle,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: FincoreColors.border),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed:
                        selected == null
                            ? null
                            : () => Navigator.of(context).pop(selected),
                    style: FilledButton.styleFrom(
                      backgroundColor: FincoreColors.accent,
                      foregroundColor: FincoreColors.canvas,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Continuar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

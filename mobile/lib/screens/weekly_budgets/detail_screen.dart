import 'package:fincore/app_dependencies.dart';
import 'package:fincore/data/daos/weekly_budgets_dao.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/models/category.dart' as model;
import 'package:fincore/screens/weekly_budgets/widgets/balance_footer.dart';
import 'package:fincore/screens/weekly_budgets/widgets/budget_item_form_sheet.dart';
import 'package:fincore/screens/weekly_budgets/widgets/edit_label_dialog.dart';
import 'package:fincore/screens/weekly_budgets/widgets/items_section.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/widgets/category_badge.dart';
import 'package:fincore/widgets/confirm_dialog.dart';
import 'package:fincore/widgets/error_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Detalle de un presupuesto semanal (`WeeklyBudgetRow` +
/// `WeeklyBudgetItemRow`), sprint `flutter-weekly-budgets-v1` (T019).
///
/// AppBar con nombre editable + menú (marcar/quitar plantilla vía
/// `is_template` / eliminar), dos `ItemsSection` (ingresos/gastos) con
/// drag&drop y `BalanceFooter`. El AppBar muestra un subtítulo con el rango
/// de fechas de la semana y, si el budget está marcado como plantilla
/// (refactor 2026-07-14), un ícono de bookmark junto al label. El
/// `BudgetTotals` del footer (refactor "Opción C") se compone localmente a
/// partir de `_itemsStream` — `weeklyBudgetsDao.watchBudgetBalance` sigue
/// vivo para el balance inline de `list_screen.dart`.
class WeeklyBudgetScreen extends StatefulWidget {
  final String budgetId;

  const WeeklyBudgetScreen({super.key, required this.budgetId});

  @override
  State<WeeklyBudgetScreen> createState() => _WeeklyBudgetScreenState();
}

class _WeeklyBudgetScreenState extends State<WeeklyBudgetScreen> {
  bool _bootstrapped = false;
  bool _redirected = false;
  Stream<WeeklyBudgetRow?>? _budgetStream;
  Stream<List<WeeklyBudgetItemRow>>? _itemsStream;
  Stream<BudgetTotals>? _totalsStream;
  Map<String, Category> _categoryById = const {};
  bool _categoriesLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bootstrapped) return;
    _bootstrapped = true;
    final deps = AppDependencies.of(context);
    _budgetStream = deps.weeklyBudgetsDao.watchAll().map((budgets) {
      for (final b in budgets) {
        if (b.id == widget.budgetId) return b;
      }
      return null;
    });
    _itemsStream = deps.weeklyBudgetsDao.watchBudgetItems(widget.budgetId);
    // Cacheado una sola vez (no inline en `build`): `.map()` sobre un stream
    // crea un objeto `Stream` nuevo en cada invocación, y el `StreamBuilder`
    // de `BalanceFooter` reinicia su `ConnectionState` a `waiting` cada vez
    // que recibe una instancia distinta — provocaba parpadeo del `Skeleton`
    // en cada rebuild de esta pantalla (regla del repo: streams cacheados
    // en el State, no recreados en cada `setState`/`build`).
    _totalsStream = _itemsStream!.map((items) {
      final income = items
          .where((i) => i.kind == 'income')
          .fold<double>(0, (acc, i) => acc + i.amount);
      final expense = items
          .where((i) => i.kind == 'expense')
          .fold<double>(0, (acc, i) => acc + i.amount);
      return BudgetTotals(income: income, expense: expense);
    });
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final deps = AppDependencies.of(context);
    final categories = await deps.categoriesDao.listAll();
    if (!mounted) return;
    setState(() {
      _categoryById = {for (final c in categories) c.id: c};
      _categoriesLoaded = true;
    });
  }

  /// Si el presupuesto desaparece (borrado desde otro punto de la app o al
  /// terminar de cargar y no existir), volvemos al listado con snackbar.
  /// El `addPostFrameCallback` evita hacer `pop` en medio de un `build`.
  void _redirectMissing() {
    if (_redirected) return;
    _redirected = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showWarningSnackbar(context, 'El presupuesto ya no existe.');
      Navigator.of(context).maybePop();
    });
  }

  Future<void> _editLabel(WeeklyBudgetRow budget) async {
    final result = await showEditLabelDialog(
      context,
      currentLabel: budget.label,
    );
    if (result == null) return;
    if (!mounted) return;

    try {
      await AppDependencies.of(
        context,
      ).weeklyBudgetsDao.updateBudget(widget.budgetId, label: result);
    } on WeeklyBudgetsDaoError catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    }
  }

  /// Invierte `is_template` del budget abierto (refactor 2026-07-14): ya no
  /// se crea una entidad de plantilla separada, se marca/desmarca este
  /// mismo presupuesto.
  Future<void> _toggleTemplate(WeeklyBudgetRow budget) async {
    final wasTemplate = budget.isTemplate;
    try {
      await AppDependencies.of(
        context,
      ).weeklyBudgetsDao.toggleTemplateFlag(widget.budgetId);
      if (mounted) {
        showSuccessSnackbar(
          context,
          wasTemplate
              ? 'Se quitó la marca de plantilla.'
              : 'Presupuesto marcado como plantilla.',
        );
      }
    } on WeeklyBudgetsDaoError catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    }
  }

  Future<void> _confirmDeleteBudget() async {
    final deps = AppDependencies.of(context);
    final currentItems =
        await deps.weeklyBudgetsDao.watchBudgetItems(widget.budgetId).first;
    if (!mounted) return;

    final confirmed = await showConfirmDialog(
      context,
      title: 'Eliminar presupuesto',
      message:
          'Esto borrará el presupuesto y sus ${currentItems.length} '
          'renglones. Esta acción no se puede deshacer.',
      confirmLabel: 'Eliminar',
    );
    if (!confirmed) return;
    if (!mounted) return;

    try {
      await deps.weeklyBudgetsDao.deleteBudget(widget.budgetId);
      if (mounted) context.pop();
    } on WeeklyBudgetsDaoError catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    }
  }

  void _openItemForm({WeeklyBudgetItemRow? item, String? initialKind}) {
    final deps = AppDependencies.of(context);
    BudgetItemFormSheet.show(
      context: context,
      initial:
          item == null
              ? null
              : BudgetItemFormData(
                name: item.name,
                categoryId: item.categoryId,
                amount: item.amount,
                kind: item.kind,
              ),
      initialKind: initialKind,
      onSubmit: (data) async {
        if (item == null) {
          await deps.weeklyBudgetsDao.addItem(
            budgetId: widget.budgetId,
            name: data.name,
            categoryId: data.categoryId,
            amount: data.amount,
            kind: data.kind,
          );
        } else {
          await deps.weeklyBudgetsDao.updateItem(
            item.id,
            name: data.name,
            categoryId: data.categoryId,
            clearCategory: data.categoryId == null,
            amount: data.amount,
            kind: data.kind,
          );
        }
      },
    );
  }

  Future<void> _deleteItem(String itemId, String name) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Eliminar renglón',
      message: "¿Eliminar el renglón '$name'?",
      confirmLabel: 'Eliminar',
    );
    if (!confirmed) return;
    if (!mounted) return;

    try {
      await AppDependencies.of(context).weeklyBudgetsDao.deleteItem(itemId);
    } on WeeklyBudgetsDaoError catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    }
  }

  Future<void> _reorder(List<String> orderedIds) {
    return AppDependencies.of(
      context,
    ).weeklyBudgetsDao.reorderItems(widget.budgetId, orderedIds);
  }

  Widget _categoryBadge(String? categoryId) {
    final category = categoryId == null ? null : _categoryById[categoryId];
    return CategoryBadge(
      category: category == null ? null : _toModelCategory(category),
      compact: true,
    );
  }

  // `CategoriesDao` retorna el `Category` generado por drift
  // (`data/database.dart`), pero `CategoryBadge` consume el modelo de
  // dominio `models/category.dart` — mismo mapeo 1:1 que `MovementRow`.
  model.Category _toModelCategory(Category c) {
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

  String _dateRangeLabel(DateTime weekStart) {
    final weekEnd = weekStart.add(const Duration(days: 6));
    final start = _capitalize(
      DateFormat('EEE d MMM', 'es_MX').format(weekStart),
    );
    final end = _capitalize(DateFormat('EEE d MMM', 'es_MX').format(weekEnd));
    return '$start → $end';
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<WeeklyBudgetRow?>(
      stream: _budgetStream,
      builder: (context, budgetSnap) {
        if (!budgetSnap.hasData || !_categoriesLoaded) {
          // Sprint quality-review (M3): AppBar minimal durante loading —
          // sin esto la pantalla queda sin botón back visual mientras
          // resuelven el stream del presupuesto y la carga de categorías.
          return Scaffold(
            appBar: AppBar(title: const Text('Cargando…')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final budget = budgetSnap.data;
        if (budget == null) {
          _redirectMissing();
          return Scaffold(
            appBar: AppBar(title: const Text('Cargando…')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        return _buildLoaded(context, budget);
      },
    );
  }

  Widget _buildLoaded(BuildContext context, WeeklyBudgetRow budget) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: InkWell(
          onTap: () => _editLabel(budget),
          borderRadius: BorderRadius.circular(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(budget.label, overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.edit_outlined, size: 16),
                  if (budget.isTemplate) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.bookmark, size: 16),
                  ],
                ],
              ),
              Text(
                _dateRangeLabel(budget.weekStartDate),
                style: const TextStyle(
                  color: FincoreColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Más acciones',
            onSelected: (value) {
              if (value == 'toggle_template') {
                _toggleTemplate(budget);
              } else if (value == 'delete') {
                _confirmDeleteBudget();
              }
            },
            itemBuilder:
                (ctx) => [
                  PopupMenuItem(
                    value: 'toggle_template',
                    child: Row(
                      children: [
                        const Icon(Icons.bookmark_outline, size: 18),
                        const SizedBox(width: 12),
                        // L1: sin `Expanded`, este label largo desborda el
                        // ancho fijo del menú (~256px) y el texto termina
                        // renderizado fuera de la pantalla, imposibilitando
                        // el tap (detectado por widget tests del sprint
                        // flutter-weekly-budgets-v1).
                        Expanded(
                          child: Text(
                            budget.isTemplate
                                ? 'Quitar marca de plantilla'
                                : 'Marcar como plantilla',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
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
                        Expanded(
                          child: Text(
                            'Eliminar presupuesto',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: FincoreColors.negative),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
          ),
        ],
      ),
      body: StreamBuilder<List<WeeklyBudgetItemRow>>(
        stream: _itemsStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          final incomeItems = items.where((i) => i.kind == 'income').toList();
          final expenseItems = items.where((i) => i.kind == 'expense').toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ItemsSection(
                  title: 'Ingresos esperados',
                  kind: 'income',
                  items: [
                    for (final i in incomeItems)
                      BudgetItemDisplay(
                        id: i.id,
                        name: i.name,
                        categoryId: i.categoryId,
                        amount: i.amount,
                      ),
                  ],
                  onTapItem: (itemId) {
                    final item = items.firstWhere((i) => i.id == itemId);
                    _openItemForm(item: item);
                  },
                  onDeleteItem: (itemId) {
                    final item = items.firstWhere((i) => i.id == itemId);
                    _deleteItem(itemId, item.name);
                  },
                  onReorder: _reorder,
                  onAddItem: () => _openItemForm(initialKind: 'income'),
                  categoryBadgeBuilder: _categoryBadge,
                ),
                const SizedBox(height: 24),
                ItemsSection(
                  title: 'Gastos planeados',
                  kind: 'expense',
                  items: [
                    for (final i in expenseItems)
                      BudgetItemDisplay(
                        id: i.id,
                        name: i.name,
                        categoryId: i.categoryId,
                        amount: i.amount,
                      ),
                  ],
                  onTapItem: (itemId) {
                    final item = items.firstWhere((i) => i.id == itemId);
                    _openItemForm(item: item);
                  },
                  onDeleteItem: (itemId) {
                    final item = items.firstWhere((i) => i.id == itemId);
                    _deleteItem(itemId, item.name);
                  },
                  onReorder: _reorder,
                  onAddItem: () => _openItemForm(initialKind: 'expense'),
                  categoryBadgeBuilder: _categoryBadge,
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: BalanceFooter(totalsStream: _totalsStream!),
      ),
    );
  }
}

import 'package:fincore/app_dependencies.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/data/weekly_budgets.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/utils/money.dart';
import 'package:fincore/widgets/base_card.dart';
import 'package:fincore/widgets/error_snackbar.dart';
import 'package:flutter/material.dart';

/// Comparación side-by-side de 2 presupuestos de la misma semana (sprint
/// `flutter-weekly-budgets-v1`).
///
/// Vista de solo lectura: para editar un renglón o el label, el usuario
/// vuelve al detalle individual (`WeeklyBudgetScreen`) de cada presupuesto.
///
/// Restricciones defensivas (la UI de entrada ya las evita, pero esta
/// pantalla las revalida porque puede recibir ids arbitrarios vía deep
/// link/back-stack):
/// - `budgetIdA == budgetIdB` → snackbar de error + pop.
/// - alguno de los dos ids no existe → snackbar de error + pop.
/// - semanas distintas (`week_start_date` no coincide) → snackbar de
///   warning + pop.
class BudgetCompareScreen extends StatefulWidget {
  final String budgetIdA;
  final String budgetIdB;

  const BudgetCompareScreen({
    super.key,
    required this.budgetIdA,
    required this.budgetIdB,
  });

  @override
  State<BudgetCompareScreen> createState() => _BudgetCompareScreenState();
}

class _BudgetCompareScreenState extends State<BudgetCompareScreen> {
  bool _bootstrapped = false;
  bool _redirected = false;
  bool _loading = true;
  WeeklyBudgetRow? _budgetA;
  WeeklyBudgetRow? _budgetB;
  Stream<List<WeeklyBudgetItemRow>>? _itemsAStream;
  Stream<List<WeeklyBudgetItemRow>>? _itemsBStream;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bootstrapped) return;
    _bootstrapped = true;

    if (widget.budgetIdA == widget.budgetIdB) {
      _redirectWithMessage(
        'No puedes comparar un presupuesto contigo mismo',
        kind: _RedirectKind.error,
      );
      return;
    }
    _loadBudgets();
  }

  Future<void> _loadBudgets() async {
    final deps = AppDependencies.of(context);
    final budgetA = await deps.weeklyBudgetsDao.findById(widget.budgetIdA);
    final budgetB = await deps.weeklyBudgetsDao.findById(widget.budgetIdB);
    if (!mounted) return;

    if (budgetA == null || budgetB == null) {
      _redirectWithMessage(
        'Uno de los presupuestos ya no existe',
        kind: _RedirectKind.error,
      );
      return;
    }
    if (!budgetA.weekStartDate.isAtSameMomentAs(budgetB.weekStartDate)) {
      _redirectWithMessage(
        'Solo puedes comparar presupuestos de la misma semana',
        kind: _RedirectKind.warning,
      );
      return;
    }

    setState(() {
      _budgetA = budgetA;
      _budgetB = budgetB;
      _itemsAStream = deps.weeklyBudgetsDao.watchBudgetItems(widget.budgetIdA);
      _itemsBStream = deps.weeklyBudgetsDao.watchBudgetItems(widget.budgetIdB);
      _loading = false;
    });
  }

  /// Programa el snackbar + pop para después del frame actual: `pop` no se
  /// puede invocar en medio de un `build`/`didChangeDependencies`. Mismo
  /// patrón que `_redirectMissing` de `WeeklyBudgetScreen`.
  void _redirectWithMessage(String message, {required _RedirectKind kind}) {
    if (_redirected) return;
    _redirected = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (kind == _RedirectKind.warning) {
        showWarningSnackbar(context, message);
      } else {
        showErrorSnackbar(context, Exception(message));
      }
      Navigator.of(context).maybePop();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_redirected || _loading || _budgetA == null || _budgetB == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cargando…')),
        body: const Center(
          child: CircularProgressIndicator(color: FincoreColors.accent),
        ),
      );
    }
    return _buildLoaded(context, _budgetA!, _budgetB!);
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text('Comparar'),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    );
  }

  Widget _buildLoaded(
    BuildContext context,
    WeeklyBudgetRow budgetA,
    WeeklyBudgetRow budgetB,
  ) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: StreamBuilder<List<WeeklyBudgetItemRow>>(
        stream: _itemsAStream,
        builder: (context, snapA) {
          return StreamBuilder<List<WeeklyBudgetItemRow>>(
            stream: _itemsBStream,
            builder: (context, snapB) {
              if (!snapA.hasData || !snapB.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: FincoreColors.accent),
                );
              }
              final itemsA = snapA.data!;
              final itemsB = snapB.data!;
              final incomeA =
                  itemsA.where((i) => i.kind == 'income').toList();
              final incomeB =
                  itemsB.where((i) => i.kind == 'income').toList();
              final expenseA =
                  itemsA.where((i) => i.kind == 'expense').toList();
              final expenseB =
                  itemsB.where((i) => i.kind == 'expense').toList();

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CompareHeader(
                      labelA: budgetA.label,
                      labelB: budgetB.label,
                      balanceA: calculateBalance(itemsA),
                      balanceB: calculateBalance(itemsB),
                    ),
                    const SizedBox(height: 20),
                    _CompareSection(
                      title: 'Ingresos esperados',
                      itemsA: incomeA,
                      itemsB: incomeB,
                    ),
                    const SizedBox(height: 20),
                    _CompareSection(
                      title: 'Gastos planeados',
                      itemsA: expenseA,
                      itemsB: expenseB,
                    ),
                    const SizedBox(height: 20),
                    _CompareFooter(
                      itemsA: itemsA,
                      itemsB: itemsB,
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

enum _RedirectKind { error, warning }

/// Header con los 2 labels + balance de cada presupuesto, separados por un
/// divider vertical.
class _CompareHeader extends StatelessWidget {
  final String labelA;
  final String labelB;
  final int balanceA;
  final int balanceB;

  const _CompareHeader({
    required this.labelA,
    required this.labelB,
    required this.balanceA,
    required this.balanceB,
  });

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: _MiniBudgetHeader(label: labelA, balance: balanceA)),
          const SizedBox(
            height: 56,
            child: VerticalDivider(color: FincoreColors.border, width: 24),
          ),
          Expanded(child: _MiniBudgetHeader(label: labelB, balance: balanceB)),
        ],
      ),
    );
  }
}

class _MiniBudgetHeader extends StatelessWidget {
  final String label;
  final int balance;

  const _MiniBudgetHeader({required this.label, required this.balance});

  @override
  Widget build(BuildContext context) {
    final String balanceLabel;
    final Color color;
    if (balance > 0) {
      balanceLabel = 'Sobra ${formatCents(balance)}';
      color = FincoreColors.positive;
    } else if (balance < 0) {
      balanceLabel = 'Faltan ${formatCents(balance.abs())}';
      color = FincoreColors.negative;
    } else {
      balanceLabel = r'$0';
      color = FincoreColors.textMuted;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: FincoreColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          balanceLabel,
          style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ],
    );
  }
}

/// Un renglón "matcheado" entre A y B. `itemA`/`itemB` son `null` cuando el
/// renglón es exclusivo de un lado.
class _MatchedRow {
  final WeeklyBudgetItemRow? itemA;
  final WeeklyBudgetItemRow? itemB;

  const _MatchedRow({this.itemA, this.itemB});
}

/// Matchea `itemsA`/`itemsB` por `name.trim().toLowerCase()` (RN de la spec:
/// el nombre libre manda, `categoryId` se ignora).
///
/// Orden del resultado: compartidos primero (en el orden — `sort_order` — de
/// `itemsA`), luego exclusivos de A, luego exclusivos de B. Ambas listas de
/// entrada ya vienen ordenadas por `sort_order` desde
/// `WeeklyBudgetsDao.watchBudgetItems`.
List<_MatchedRow> _matchBudgetItems(
  List<WeeklyBudgetItemRow> itemsA,
  List<WeeklyBudgetItemRow> itemsB,
) {
  final byNameB = <String, WeeklyBudgetItemRow>{};
  for (final item in itemsB) {
    byNameB[item.name.trim().toLowerCase()] = item;
  }

  final matchedNames = <String>{};
  final shared = <_MatchedRow>[];
  final exclusiveA = <_MatchedRow>[];
  for (final itemA in itemsA) {
    final key = itemA.name.trim().toLowerCase();
    final itemB = byNameB[key];
    if (itemB != null) {
      shared.add(_MatchedRow(itemA: itemA, itemB: itemB));
      matchedNames.add(key);
    } else {
      exclusiveA.add(_MatchedRow(itemA: itemA));
    }
  }

  final exclusiveB = <_MatchedRow>[];
  for (final itemB in itemsB) {
    final key = itemB.name.trim().toLowerCase();
    if (!matchedNames.contains(key)) {
      exclusiveB.add(_MatchedRow(itemB: itemB));
    }
  }

  return [...shared, ...exclusiveA, ...exclusiveB];
}

class _CompareSection extends StatelessWidget {
  final String title;
  final List<WeeklyBudgetItemRow> itemsA;
  final List<WeeklyBudgetItemRow> itemsB;

  const _CompareSection({
    required this.title,
    required this.itemsA,
    required this.itemsB,
  });

  @override
  Widget build(BuildContext context) {
    final rows = _matchBudgetItems(itemsA, itemsB);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(title),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Sin renglones de ningún lado.',
              style: TextStyle(color: FincoreColors.textSubtle, fontSize: 12),
            ),
          )
        else
          BaseCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++)
                  _CompareItemRow(row: rows[i], alt: i.isOdd),
              ],
            ),
          ),
      ],
    );
  }
}

class _CompareItemRow extends StatelessWidget {
  final _MatchedRow row;
  final bool alt;

  const _CompareItemRow({required this.row, required this.alt});

  @override
  Widget build(BuildContext context) {
    int? delta;
    final itemA = row.itemA;
    final itemB = row.itemB;
    if (itemA != null && itemB != null) {
      delta = itemB.amount - itemA.amount;
    }
    return Container(
      color: alt
          ? FincoreColors.surfaceElevated.withValues(alpha: 0.4)
          : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _ItemCell(
              item: itemA,
              // Delta se muestra al lado del monto MAYOR (RN de la spec).
              // Si B > A, delta positivo se muestra junto a B; si B < A,
              // delta negativo (magnitud A-B) se muestra junto a A.
              deltaText: (delta != null && delta < 0)
                  ? '−${formatCents(delta.abs())}'
                  : null,
              deltaColor: FincoreColors.warning,
            ),
          ),
          const SizedBox(width: 8),
          Container(width: 1, height: 32, color: FincoreColors.border),
          const SizedBox(width: 8),
          Expanded(
            child: _ItemCell(
              item: itemB,
              deltaText: (delta != null && delta > 0)
                  ? '+${formatCents(delta)}'
                  : null,
              deltaColor: FincoreColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemCell extends StatelessWidget {
  final WeeklyBudgetItemRow? item;
  final String? deltaText;
  final Color deltaColor;

  const _ItemCell({
    required this.item,
    required this.deltaText,
    required this.deltaColor,
  });

  @override
  Widget build(BuildContext context) {
    final currentItem = item;
    if (currentItem == null) {
      return const Text(
        '—',
        style: TextStyle(color: FincoreColors.textSubtle, fontSize: 13),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          currentItem.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: FincoreColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          children: [
            Text(
              formatCents(currentItem.amount),
              style: const TextStyle(
                color: FincoreColors.textMuted,
                fontSize: 13,
              ),
            ),
            if (deltaText != null)
              Text(
                deltaText!,
                style: TextStyle(
                  color: deltaColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _CompareFooter extends StatelessWidget {
  final List<WeeklyBudgetItemRow> itemsA;
  final List<WeeklyBudgetItemRow> itemsB;

  const _CompareFooter({required this.itemsA, required this.itemsB});

  int _sum(List<WeeklyBudgetItemRow> items, String kind) =>
      items.where((i) => i.kind == kind).fold(0, (sum, i) => sum + i.amount);

  @override
  Widget build(BuildContext context) {
    final incomeA = _sum(itemsA, 'income');
    final incomeB = _sum(itemsB, 'income');
    final expenseA = _sum(itemsA, 'expense');
    final expenseB = _sum(itemsB, 'expense');
    final balanceA = incomeA - expenseA;
    final balanceB = incomeB - expenseB;

    return BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TOTALES',
            style: TextStyle(
              color: FincoreColors.textSubtle,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          _TotalRow(
            label: 'Total ingresos',
            valueA: incomeA,
            valueB: incomeB,
          ),
          const SizedBox(height: 8),
          _TotalRow(
            label: 'Total gastos',
            valueA: expenseA,
            valueB: expenseB,
          ),
          const Divider(color: FincoreColors.border, height: 20),
          _TotalRow(
            label: 'Balance',
            valueA: balanceA,
            valueB: balanceB,
            emphasized: true,
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final int valueA;
  final int valueB;
  final bool emphasized;

  const _TotalRow({
    required this.label,
    required this.valueA,
    required this.valueB,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final delta = valueB - valueA;
    final String? deltaText;
    final Color deltaColor;
    if (delta == 0) {
      deltaText = null;
      deltaColor = FincoreColors.textMuted;
    } else if (delta > 0) {
      deltaText = '+${formatCents(delta)}';
      deltaColor = FincoreColors.accent;
    } else {
      deltaText = '−${formatCents(delta.abs())}';
      deltaColor = FincoreColors.warning;
    }

    return Text.rich(
      TextSpan(
        style: TextStyle(
          color: FincoreColors.textPrimary,
          fontSize: emphasized ? 15 : 13,
          fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
        ),
        children: [
          TextSpan(
            text:
                '$label: A ${formatCents(valueA)} vs B ${formatCents(valueB)}',
          ),
          if (deltaText != null)
            TextSpan(
              text: ' ($deltaText)',
              style: TextStyle(color: deltaColor, fontWeight: FontWeight.w700),
            ),
        ],
      ),
    );
  }
}

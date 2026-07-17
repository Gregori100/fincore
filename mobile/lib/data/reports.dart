import 'package:drift/drift.dart';
import 'package:fincore/constants/reports_tokens.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/data/date_helpers.dart';

/// Reporte agregado de gasto por categoría en un rango temporal.
///
/// Inmutable. Construido por [ReportsService.spendingByCategory]. Cubre los
/// requisitos RF-002/RF-003 del sprint `flutter-reports-v1`:
/// - `total`: suma de `journal_entries.amount` en el rango filtrado por kind.
/// - `count`: cantidad de entries que contribuyen al total.
/// - `buckets`: agrupación por categoría con orden RF-005 (monto desc,
///   tiebreak alfabético asc).
class SpendingReport {
  final double total;
  final int count;
  final DateTime from;
  final DateTime to;
  final List<SpendingBucket> buckets;

  const SpendingReport({
    required this.total,
    required this.count,
    required this.from,
    required this.to,
    required this.buckets,
  });

  bool get isEmpty => buckets.isEmpty;
}

/// Reporte agregado de ingreso por categoría en un rango temporal. Sprint
/// `flutter-reports-income-by-category-v1`.
///
/// Simétrico a [SpendingReport] pero para `kind='income'`. Cubre RF-001 del
/// sprint: `total`, `count`, `from`, `to`, `buckets`.
class IncomeReport {
  final double total;
  final int count;
  final DateTime from;
  final DateTime to;
  final List<IncomeBucket> buckets;

  const IncomeReport({
    required this.total,
    required this.count,
    required this.from,
    required this.to,
    required this.buckets,
  });

  bool get isEmpty => buckets.isEmpty;
}

/// Bucket de ingreso por categoría. Simétrico a [SpendingBucket]. Cubre
/// RF-002 del sprint `flutter-reports-income-by-category-v1`.
///
/// - `categoryId` es null cuando representa el bucket "Sin categoría"
///   (entries con `category_id IS NULL`, categoría archivada, o categoría
///   con `applies_to='expense'` — los 3 merge en un solo bucket gracias al
///   `LEFT JOIN ... AND deleted_at IS NULL AND applies_to != 'expense'`
///   que deja `c.id` en NULL en todos esos casos).
/// - `colorSlug`/`iconSlug` null → fallback gris + label_outline.
/// - `percent` en [0.0, 1.0]. Si `report.total == 0` retorna 0 (defensivo).
class IncomeBucket {
  final String? categoryId;
  final String name;
  final String? colorSlug;
  final String? iconSlug;
  final double total;
  final double percent;
  final int count;

  const IncomeBucket({
    required this.categoryId,
    required this.name,
    required this.colorSlug,
    required this.iconSlug,
    required this.total,
    required this.percent,
    required this.count,
  });
}

/// Bucket de gasto por categoría.
///
/// - `categoryId` es null cuando representa el bucket especial "Sin categoría"
///   (entries con `category_id IS NULL` o categoría archivada — RN-R03/R04).
/// - `colorSlug` y `iconSlug` son null para el bucket "Sin categoría"; el
///   render UI usa `colorBySlug(null)` / `iconBySlug(null)` que retornan los
///   fallback definidos en `category_catalog.dart` (gris + label_outline).
/// - `percent` en [0.0, 1.0]. Cuando `report.total == 0` retorna 0 (protección
///   contra división por cero).
class SpendingBucket {
  final String? categoryId;
  final String name;
  final String? colorSlug;
  final String? iconSlug;
  final double total;
  final double percent;
  final int count;

  const SpendingBucket({
    required this.categoryId,
    required this.name,
    required this.colorSlug,
    required this.iconSlug,
    required this.total,
    required this.percent,
    required this.count,
  });
}

/// Nombre literal del bucket "Sin categoría" (RN-R08). Diferenciado en el sort
/// por nombre del resto: cuando empata con una categoría activa por monto, el
/// tiebreak alfabético lo posiciona después de la "S".
const String kUncategorizedBucketName = 'Sin categoría';

/// Actividad diaria agregada para el calendario mensual (sprint
/// `flutter-reports-movements-calendar-v1`). Compacto: solo 3 booleanos +
/// conteo total del día. La clave del `Map` que lo contiene es la fecha
/// normalizada a `DateTime(y, m, d)` con hora 0 (RN-CAL03).
///
/// Los booleanos representan **presencia** de al menos 1 movimiento del grupo:
/// - `hasIncome`: hubo `kind='income'`.
/// - `hasSpending`: hubo `kind ∈ {expense, credit_expense}` (RN-CAL01 agrupa).
/// - `hasInternal`: hubo `kind ∈ {transfer, debt_payment}` (RN-CAL01 agrupa).
///
/// `totalCount` no distingue por kind; sirve para tooltips futuros o para
/// decidir si el día es "activo" en el `markerBuilder`. El heatmap del
/// próximo sprint puede extender este modelo con un `totalAmount` por kind
/// sin romper compat.
class DayActivity {
  final bool hasIncome;
  final bool hasSpending;
  final bool hasInternal;
  final int totalCount;

  const DayActivity({
    required this.hasIncome,
    required this.hasSpending,
    required this.hasInternal,
    required this.totalCount,
  });

  /// True si al menos 1 marcador debe pintarse. Usado por el `markerBuilder`
  /// del `TableCalendar` para short-circuit.
  bool get hasAny => hasIncome || hasSpending || hasInternal;
}

/// Nivel de intensidad de gasto para el heatmap anual (sprint
/// `flutter-reports-spending-heatmap-v1`, RN-HM06). Los 5 niveles
/// se calculan por cuartiles relativos al año en foco.
enum IntensityLevel { none, low, medium, high, veryHigh }

/// Reporte del heatmap anual de gastos (sprint
/// `flutter-reports-spending-heatmap-v1`). Contiene el mapa día→total de
/// los gastos (`kind ∈ {expense, credit_expense}`) del año, cuartiles
/// precalculados y agregados para la leyenda.
///
/// - `daySpending`: solo días con gasto > 0. Claves normalizadas a
///   `DateTime(y, m, d)` con hora 0 (RN-HM02).
/// - `total`: suma anual de todos los gastos.
/// - `daysWithSpending`: número de días con gasto > 0.
/// - `p25`/`p50`/`p75`: cuartiles calculados sobre los valores de
///   `daySpending`. Con `daysWithSpending < 4` se aplica el fallback
///   RN-HM05 (todos igual a `max`), lo que pinta todos los días con
///   gasto como `veryHigh`.
///
/// El método [intensityFor] mapea un día al color correspondiente:
///
/// - Clave ausente o `total == 0` → [IntensityLevel.none].
/// - `0 < total ≤ p25` → [IntensityLevel.low].
/// - `p25 < total ≤ p50` → [IntensityLevel.medium].
/// - `p50 < total ≤ p75` → [IntensityLevel.high].
/// - `total > p75` → [IntensityLevel.veryHigh].
class SpendingHeatmap {
  final Map<DateTime, double> daySpending;
  final double total;
  final int daysWithSpending;
  final double p25;
  final double p50;
  final double p75;

  const SpendingHeatmap({
    required this.daySpending,
    required this.total,
    required this.daysWithSpending,
    required this.p25,
    required this.p50,
    required this.p75,
  });

  IntensityLevel intensityFor(DateTime day) {
    final normalized = DateTime(day.year, day.month, day.day);
    final value = daySpending[normalized];
    if (value == null || value <= 0) return IntensityLevel.none;
    if (value <= p25) return IntensityLevel.low;
    if (value <= p50) return IntensityLevel.medium;
    if (value <= p75) return IntensityLevel.high;
    return IntensityLevel.veryHigh;
  }
}

/// Reporte del heatmap anual de ingresos (sprint
/// `flutter-reports-income-heatmap-v1`). Simétrico a [SpendingHeatmap]
/// pero para `kind='income'`. Contiene el mapa día→total de ingresos
/// del año, cuartiles precalculados y agregados para la leyenda.
///
/// - `dayIncome`: solo días con ingreso > 0. Claves normalizadas a
///   `DateTime(y, m, d)` con hora 0 (RN-IHM02).
/// - `total`: suma anual de todos los ingresos.
/// - `daysWithIncome`: número de días con ingreso > 0.
/// - `p25`/`p50`/`p75`: cuartiles calculados sobre los valores de
///   `dayIncome`. Con `daysWithIncome < 4` se aplica el fallback
///   RN-IHM05 (cuartiles = 0), lo que pinta todos los días con
///   ingreso como `veryHigh`.
///
/// Reusa el enum [IntensityLevel] (5 niveles) del heatmap gastos.
class IncomeHeatmap {
  final Map<DateTime, double> dayIncome;
  final double total;
  final int daysWithIncome;
  final double p25;
  final double p50;
  final double p75;

  const IncomeHeatmap({
    required this.dayIncome,
    required this.total,
    required this.daysWithIncome,
    required this.p25,
    required this.p50,
    required this.p75,
  });

  IntensityLevel intensityFor(DateTime day) {
    final normalized = DateTime(day.year, day.month, day.day);
    final value = dayIncome[normalized];
    if (value == null || value <= 0) return IntensityLevel.none;
    if (value <= p25) return IntensityLevel.low;
    if (value <= p50) return IntensityLevel.medium;
    if (value <= p75) return IntensityLevel.high;
    return IntensityLevel.veryHigh;
  }
}

/// Interpolación estándar de cuartiles sobre una lista ordenada asc.
/// Con `sortedValues.length < 4` retorna `(max, max, max)` como fallback
/// (RN-HM05): con tan pocos datos los cuartiles no son estadísticamente
/// significativos, así que todos los días con gasto se pintan como
/// `veryHigh` (visualmente uniforme).
(double, double, double) _computeQuartiles(List<double> sortedValues) {
  if (sortedValues.isEmpty) return (0, 0, 0);
  if (sortedValues.length < 4) {
    // RN-HM05: con < 4 datos los cuartiles no son significativos.
    // Retornamos (0, 0, 0) para que TODOS los días con gasto caigan en
    // `veryHigh` (value > p75 = 0). Visualmente uniforme.
    return (0, 0, 0);
  }
  double percentile(double p) {
    final rank = (sortedValues.length - 1) * p;
    final lower = rank.floor();
    final upper = rank.ceil();
    if (lower == upper) return sortedValues[lower];
    final weight = rank - lower;
    return sortedValues[lower] * (1 - weight) + sortedValues[upper] * weight;
  }
  return (percentile(0.25), percentile(0.5), percentile(0.75));
}

/// Servicio de reportes agregados sobre `journal_entries` + `categories`.
///
/// Independiente de `FinancialStateService` para no contaminar los streams BO/
/// DE/CR del Dashboard con la query del reporte. Sin cache propio: cada
/// llamada a [spendingByCategory] arma un Stream nuevo apropiado al rango
/// pedido. El consumidor (la UI) administra el ciclo de vida con
/// `StreamBuilder`.
class ReportsService {
  final FincoreDatabase _db;
  ReportsService(this._db);

  /// Gasto por categoría agregado en el rango `[from, to]` inclusivo en ambos
  /// extremos (RN-R05).
  ///
  /// Filtros:
  /// - Kind ∈ {`expense`, `credit_expense`} (RN-R01). Excluye `transfer`,
  ///   `debt_payment`, `income` (RN-R02).
  /// - `journal_entries.deleted_at IS NULL` (RN-R07).
  /// - Entries con `category_id` NULL o categoría archivada agrupan en bucket
  ///   "Sin categoría" gracias al `LEFT JOIN ... AND deleted_at IS NULL` que
  ///   deja c.id en NULL para esos casos (RN-R03/R04).
  /// - Sprint `flutter-reports-drilldown-parity-v1` (RN-P04): el JOIN también
  ///   filtra `c.applies_to != 'income'` para blindar el edge legacy en el
  ///   que un expense tiene categoría cuyo `applies_to` fue cambiado a
  ///   `income` post-facto. Esos entries caen en "Sin categoría" en lugar
  ///   de mostrar el nombre de la categoría income-only. Simétrico al filtro
  ///   `!= 'expense'` de `incomeByCategory`.
  ///
  /// Reactividad: el Stream re-emite cuando cambian `journal_entries` o
  /// `categories` (declarado en `readsFrom`).
  ///
  /// Orden: monto desc, tiebreak alfabético asc por nombre (RF-005).
  Stream<SpendingReport> spendingByCategory({
    required DateTime from,
    required DateTime to,
  }) {
    // SQLite trata NULL == NULL en GROUP BY, así que todas las filas con
    // c.id IS NULL (NULL en journal o categoría archivada) caen en el mismo
    // grupo. No hace falta colapsar manualmente después.
    //
    // Sprint flutter-loans-v1 (RN-L17): la query original se UNION-ALLea con
    // un renglón sintético "Intereses de préstamos" que suma
    // `journal_entries.interest_amount` de todos los `loan_payment` del
    // periodo. Sólo aparece cuando el total > 0. El category_id sintético es
    // `kLoanInterestSyntheticId` — los widgets que consumen el reporte lo
    // tratan como "sin drill-down por category_id" (o navegación a /loans).
    final sql = '''
      SELECT
        c.id AS category_id,
        c.name AS category_name,
        c.color_slug AS color_slug,
        c.icon_slug AS icon_slug,
        SUM(j.amount) AS total,
        COUNT(*) AS count
      FROM journal_entries j
      LEFT JOIN categories c
        ON c.id = j.category_id
        AND c.deleted_at IS NULL
        AND c.applies_to != 'income'
      WHERE j.kind IN ('expense', 'credit_expense')
        AND j.deleted_at IS NULL
        AND j.occurred_at >= ?
        AND j.occurred_at <= ?
      GROUP BY c.id, c.name, c.color_slug, c.icon_slug

      UNION ALL

      SELECT
        '$kLoanInterestSyntheticId' AS category_id,
        'Intereses de préstamos' AS category_name,
        'orange' AS color_slug,
        'trending-down' AS icon_slug,
        SUM(interest_amount) AS total,
        -- Hotfix branch-quality-review (M8 / F-SQL-02): emitimos 0 (no
        -- COUNT(*)) porque `SpendingReport.count` representa "cantidad de
        -- entries de gasto reales". Los loan_payments no son entries de
        -- gasto convencionales — su parte de intereses se agrega al total
        -- pero no debe inflar el contador del header del reporte, que
        -- luego no coincidiría con el drill-down (que ni siquiera navega
        -- a la lista de entries — va a /loans).
        0 AS count
      FROM journal_entries
      WHERE kind = 'loan_payment'
        AND deleted_at IS NULL
        AND interest_amount > 0
        AND occurred_at >= ?
        AND occurred_at <= ?
      -- HAVING crítico: sin él, este SELECT emite 1 fila con total=NULL
      -- cuando no hay loan_payments en el periodo, y `_buildReport` haría
      -- `row.read<double>('total')` sobre null → crash.
      HAVING SUM(interest_amount) > 0

      UNION ALL

      -- Hotfix smoke Diego v4: renglón sintético "Pago a capital de
      -- préstamos" análogo al de intereses pero sumando principal_amount.
      -- Color blue para distinguirlo visualmente del naranja de intereses.
      SELECT
        '$kLoanCapitalSyntheticId' AS category_id,
        'Pago a capital de préstamos' AS category_name,
        'blue' AS color_slug,
        'savings' AS icon_slug,
        SUM(principal_amount) AS total,
        0 AS count
      FROM journal_entries
      WHERE kind = 'loan_payment'
        AND deleted_at IS NULL
        AND principal_amount > 0
        AND occurred_at >= ?
        AND occurred_at <= ?
      HAVING SUM(principal_amount) > 0
    ''';
    return _db
        .customSelect(
          sql,
          variables: [
            Variable.withDateTime(from),
            Variable.withDateTime(to),
            Variable.withDateTime(from),
            Variable.withDateTime(to),
            Variable.withDateTime(from),
            Variable.withDateTime(to),
          ],
          readsFrom: {_db.journalEntries, _db.categories},
        )
        .watch()
        .map((rows) => _buildReport(rows, from: from, to: to));
  }

  /// Cashflow mensual agregado en el rango `[from, to]` inclusivo
  /// (RN-C05). Sprint `flutter-reports-cashflow-v1`.
  ///
  /// Filtros:
  /// - Kind ∈ {`income`, `expense`, `credit_expense`} (RN-C01/C02).
  /// - `transfer` y `debt_payment` excluidos (RN-C03 — son movimientos
  ///   internos que doble-contarían).
  /// - `journal_entries.deleted_at IS NULL`.
  ///
  /// Reactividad: el Stream re-emite cuando cambia `journal_entries`. NO
  /// joinea `categories` porque el cashflow es agregado, no desglosa por
  /// categoría — minimiza el costo de la query y elimina la dependencia
  /// reactiva en categorías archivadas (un archive no debe re-emitir el
  /// cashflow).
  ///
  /// Agrupación: por `strftime('%Y-%m', occurred_at)`. RN-C06 obliga a
  /// rellenar meses sin entries con ceros — se hace en Dart sobre el
  /// resultado de la query (la query SQL solo emite filas para meses con
  /// datos).
  ///
  /// Orden: cronológico ascendente (RN-C08).
  Stream<CashflowReport> cashflowByMonth({
    required DateTime from,
    required DateTime to,
  }) {
    const sql = '''
      SELECT
        strftime('%Y-%m', occurred_at) AS month_key,
        SUM(CASE WHEN kind = 'income' THEN amount ELSE 0 END) AS income,
        SUM(CASE WHEN kind IN ('expense', 'credit_expense') THEN amount ELSE 0 END) AS expense
      FROM journal_entries
      WHERE kind IN ('income', 'expense', 'credit_expense')
        AND deleted_at IS NULL
        AND occurred_at >= ?
        AND occurred_at <= ?
      GROUP BY strftime('%Y-%m', occurred_at)
    ''';
    return _db
        .customSelect(
          sql,
          variables: [
            Variable.withDateTime(from),
            Variable.withDateTime(to),
          ],
          readsFrom: {_db.journalEntries},
        )
        .watch()
        .map((rows) => _buildCashflowReport(rows, from: from, to: to));
  }

  /// Itera los meses calendario desde el mes de `from` hasta el mes de `to`
  /// (inclusive en ambos extremos). Retorna `DateTime(year, month, 1)` por
  /// cada mes. Usado por `_buildCashflowReport` para rellenar meses vacíos
  /// (RN-C06).
  ///
  /// Sin tocar zona horaria — el constructor `DateTime(y, m, 1)` queda en
  /// local del dispositivo, coherente con el resto de la app.
  List<DateTime> _iterateMonthsBetween(DateTime from, DateTime to) {
    final result = <DateTime>[];
    var cursor = DateTime(from.year, from.month, 1);
    final end = DateTime(to.year, to.month, 1);
    while (!cursor.isAfter(end)) {
      result.add(cursor);
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }
    return result;
  }

  CashflowReport _buildCashflowReport(
    List<QueryRow> rows, {
    required DateTime from,
    required DateTime to,
  }) {
    final byKey = <String, ({double income, double expense})>{};
    for (final row in rows) {
      final key = row.read<String>('month_key');
      final income = row.read<double>('income');
      final expense = row.read<double>('expense');
      byKey[key] = (income: income, expense: expense);
    }
    final months = <MonthCashflow>[];
    var totalIncome = 0.0;
    var totalExpense = 0.0;
    for (final first in _iterateMonthsBetween(from, to)) {
      final key =
          '${first.year.toString().padLeft(4, '0')}-${first.month.toString().padLeft(2, '0')}';
      final data = byKey[key] ?? (income: 0.0, expense: 0.0);
      final income = data.income;
      final expense = data.expense;
      totalIncome += income;
      totalExpense += expense;
      months.add(MonthCashflow(
        monthKey: key,
        firstDay: first,
        income: income,
        expense: expense,
        net: income - expense,
      ));
    }
    return CashflowReport(
      from: from,
      to: to,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      net: totalIncome - totalExpense,
      months: months,
    );
  }

  /// Desglose por categoría del mes específico `monthAnchor`. Sprint
  /// `flutter-cashflow-monthly-breakdown-v1`.
  ///
  /// Filtros:
  /// - `strftime('%Y-%m', occurred_at, 'localtime') = 'YYYY-MM'` para respetar
  ///   la zona horaria local (patrón calendar/heatmap). Difiere del cashflow
  ///   base que agrupa por UTC — divergencia aceptada (R6 del plan).
  /// - `kind IN ('income', 'expense', 'credit_expense')` (RN-CB02);
  ///   `transfer` y `debt_payment` excluidos (movimientos internos).
  /// - `journal_entries.deleted_at IS NULL` (RN-CB10).
  ///
  /// El `LEFT JOIN categories` filtra `deleted_at IS NULL` — categorías
  /// archivadas caen al bucket "Sin categoría" (RN-CB11).
  ///
  /// Reactivo sobre `journal_entries` + `categories` para reflejar rename
  /// o archive en tiempo real.
  Stream<MonthBreakdown> cashflowMonthBreakdown({
    required DateTime monthAnchor,
  }) {
    String monthKey(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';
    final firstDay = DateTime(monthAnchor.year, monthAnchor.month, 1);
    // Sprint flutter-cashflow-breakdown-prev-comparison-v1: la query
    // incluye también el mes calendario anterior para calcular el delta
    // en un solo `customSelect.watch()`. `DateTime(y, m-1, 1)` normaliza
    // enero → diciembre año anterior (RN-CP01 + CB-10).
    final previousDay = DateTime(monthAnchor.year, monthAnchor.month - 1, 1);
    final currentKey = monthKey(firstDay);
    final previousKey = monthKey(previousDay);
    const sql = '''
      SELECT
        j.kind AS kind,
        j.category_id AS category_id,
        c.name AS category_name,
        c.color_slug AS color_slug,
        c.icon_slug AS icon_slug,
        c.applies_to AS applies_to,
        SUM(j.amount) AS total,
        strftime('%Y-%m', j.occurred_at, 'localtime') AS month_key
      FROM journal_entries j
      LEFT JOIN categories c
        ON c.id = j.category_id AND c.deleted_at IS NULL
      WHERE j.deleted_at IS NULL
        AND j.kind IN ('income', 'expense', 'credit_expense')
        AND strftime('%Y-%m', j.occurred_at, 'localtime') IN (?, ?)
      GROUP BY j.kind, j.category_id, c.name, c.color_slug, c.icon_slug,
               c.applies_to, month_key
    ''';
    return _db
        .customSelect(
          sql,
          variables: [
            Variable.withString(currentKey),
            Variable.withString(previousKey),
          ],
          readsFrom: {_db.journalEntries, _db.categories},
        )
        .watch()
        .map((rows) => _buildMonthBreakdown(
              rows,
              firstDay: firstDay,
              currentKey: currentKey,
              previousKey: previousKey,
            ));
  }

  MonthBreakdown _buildMonthBreakdown(
    List<QueryRow> rows, {
    required DateTime firstDay,
    required String currentKey,
    required String previousKey,
  }) {
    // Sprint flutter-cashflow-breakdown-prev-comparison-v1: 4 acumuladores
    // (2 lados × 2 meses) para computar la comparación bucket-por-bucket.
    final currentIncome = <String?, _BreakdownAccumulator>{};
    final currentExpense = <String?, _BreakdownAccumulator>{};
    final previousIncome = <String?, _BreakdownAccumulator>{};
    final previousExpense = <String?, _BreakdownAccumulator>{};

    for (final row in rows) {
      final total = row.read<double>('total');
      // CB-P03/CB-P04: filtrar buckets con amount <= 0 (edge legacy).
      if (total <= 0) continue;

      final kind = row.read<String>('kind');
      final rawCategoryId = row.readNullable<String>('category_id');
      final categoryName = row.readNullable<String>('category_name');
      final colorSlug = row.readNullable<String>('color_slug');
      final iconSlug = row.readNullable<String>('icon_slug');
      final appliesTo = row.readNullable<String>('applies_to');
      final monthKey = row.read<String>('month_key');

      // Determinar el lado según kind.
      final isIncomeSide = kind == 'income';

      // Categoría archivada o FK huérfana: el LEFT JOIN filtró por
      // `c.deleted_at IS NULL`, así que si `applies_to` es null aquí es
      // porque no hay categoría activa asociada. Colapsar todo el bucket a
      // "Sin categoría" (RN-CB11 + CB-P02).
      //
      // Dependencia con schema: `Categories.appliesTo` está declarado NOT
      // NULL (`database.dart`). Si algún día se vuelve nullable, esta
      // sentinela deja de ser confiable y hay que sustituirla por un
      // chequeo explícito sobre otra columna del JOIN (ej. `c.name`).
      final isJoinEmpty = appliesTo == null;

      // Aplicar simetría RN-CB03/CB04: categoría con applies_to incompatible
      // se colapsa a "Sin categoría".
      final incompatibleSide =
          (isIncomeSide && appliesTo == 'expense') ||
              (!isIncomeSide && appliesTo == 'income');
      final collapseToUncategorized = isJoinEmpty || incompatibleSide;
      final effectiveCategoryId =
          collapseToUncategorized ? null : rawCategoryId;
      final effectiveName = collapseToUncategorized ? null : categoryName;
      final effectiveColor = collapseToUncategorized ? null : colorSlug;
      final effectiveIcon = collapseToUncategorized ? null : iconSlug;

      // Seleccionar acumulador según (mes, lado).
      final Map<String?, _BreakdownAccumulator> target;
      if (monthKey == currentKey) {
        target = isIncomeSide ? currentIncome : currentExpense;
      } else if (monthKey == previousKey) {
        target = isIncomeSide ? previousIncome : previousExpense;
      } else {
        // Defensivo: solo deberían venir filas de estos 2 meses por el
        // WHERE. Skip silencioso.
        continue;
      }

      final existing = target[effectiveCategoryId];
      if (existing == null) {
        target[effectiveCategoryId] = _BreakdownAccumulator(
          categoryId: effectiveCategoryId,
          label: effectiveName ?? 'Sin categoría',
          colorSlug: effectiveColor,
          iconSlug: effectiveIcon,
          amount: total,
        );
      } else {
        target[effectiveCategoryId] = existing.plus(total);
      }
    }

    final totalIncome =
        currentIncome.values.fold<double>(0, (a, b) => a + b.amount);
    final totalExpense =
        currentExpense.values.fold<double>(0, (a, b) => a + b.amount);
    final previousTotalIncome =
        previousIncome.values.fold<double>(0, (a, b) => a + b.amount);
    final previousTotalExpense =
        previousExpense.values.fold<double>(0, (a, b) => a + b.amount);

    List<CategoryFlow> flowsFrom(
      Map<String?, _BreakdownAccumulator> current,
      Map<String?, _BreakdownAccumulator> previous,
      double total,
    ) {
      final list = current.values.map((a) {
        final prev = previous[a.categoryId];
        final delta = _computeDelta(a.amount, prev?.amount ?? 0);
        return CategoryFlow(
          categoryId: a.categoryId,
          label: a.label,
          colorSlug: a.colorSlug,
          iconSlug: a.iconSlug,
          amount: a.amount,
          percent: total > 0 ? (a.amount / total) * 100 : 0.0,
          delta: delta,
        );
      }).toList()
        ..sort((a, b) => b.amount.compareTo(a.amount));
      return list;
    }

    return MonthBreakdown(
      firstDay: firstDay,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      net: totalIncome - totalExpense,
      incomeBuckets: flowsFrom(currentIncome, previousIncome, totalIncome),
      expenseBuckets:
          flowsFrom(currentExpense, previousExpense, totalExpense),
      // Delta de totales: usa magnitudes (RN-CP08). Neto que salta signo
      // se maneja como cualquier cambio numérico — el delta refleja
      // magnitud del cambio con dirección según `current > previous`.
      deltaIncome: _computeDelta(totalIncome, previousTotalIncome),
      deltaExpense: _computeDelta(totalExpense, previousTotalExpense),
      deltaNet: _computeDelta(
        totalIncome - totalExpense,
        previousTotalIncome - previousTotalExpense,
      ),
    );
  }

  /// Comparación % entre `current` y `previous` (RN-CP03..CP04, CP09).
  ///
  /// - `previous <= 0` → `null` (RN-CP09 evita `+∞%`/`+100%` engañoso).
  /// - `abs(diff) < 0.01` → `flat` con `percent = 0` (RN-CP04, blindaje
  ///   contra floating-point drift).
  /// - `current > previous` → `up`, `percent = |(c-p)/|p|| × 100`.
  /// - `current < previous` → `down`, percent con misma fórmula.
  ///
  /// Nota (RN-CP08): para el neto que puede saltar signo, `previous`
  /// negativo también dispara la guard `previous <= 0` → `null`. Esa es
  /// la decisión conservadora — no interpretar "empeoré de +100 a -50"
  /// como "-150% del previo" porque el usuario podría confundirse.
  DeltaPercent? _computeDelta(double current, double previous) {
    if (previous <= 0) return null;
    final diff = current - previous;
    if (diff.abs() < 0.01) {
      return const DeltaPercent(percent: 0, direction: DeltaDirection.flat);
    }
    final magnitude = diff.abs() / previous.abs() * 100;
    return DeltaPercent(
      percent: magnitude,
      direction: diff > 0 ? DeltaDirection.up : DeltaDirection.down,
    );
  }

  /// Resumen del día calendario local para la card "Hoy" del dashboard.
  /// Sprint `flutter-dashboard-bundle-v1`.
  ///
  /// Filtros:
  /// - `strftime('%Y-%m-%d', occurred_at, 'localtime') = ?` con el día
  ///   local del `now` (RN-DB02, timezone-safe).
  /// - `kind IN ('income', 'expense', 'credit_expense')` (RN-DB01);
  ///   `transfer` y `debt_payment` excluidos.
  /// - `deleted_at IS NULL` (RN-DB03).
  ///
  /// Reactivo sobre `journal_entries`.
  Stream<TodaySummary> watchTodaySummary({DateTime? now}) {
    final reference = now ?? DateTime.now();
    final day = DateTime(reference.year, reference.month, reference.day);
    final key =
        '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    // Sprint quality-review: bracket `occurred_at` para que SQLite pueda
    // usar el índice `idx_entries_occurred_active` en vez de recomputar
    // `strftime` sobre toda la tabla. El bracket UTC es un superset
    // seguro (día local completo cabe dentro de ±1 día UTC); el
    // `strftime('localtime')` sigue como red de seguridad para el borde
    // DST y para el día calendario exacto local. Patrón heredado de
    // `movementsByDay`.
    final dayStartUtc = day.toUtc();
    final dayEndUtc = day.add(const Duration(days: 1)).toUtc();
    const sql = '''
      SELECT
        COALESCE(SUM(CASE WHEN kind = 'income' THEN amount ELSE 0 END), 0) AS income,
        COALESCE(SUM(CASE WHEN kind IN ('expense', 'credit_expense') THEN amount ELSE 0 END), 0) AS expense
      FROM journal_entries
      WHERE deleted_at IS NULL
        AND kind IN ('income', 'expense', 'credit_expense')
        AND occurred_at >= ?
        AND occurred_at < ?
        AND strftime('%Y-%m-%d', occurred_at, 'localtime') = ?
    ''';
    return _db
        .customSelect(
          sql,
          variables: [
            Variable.withDateTime(dayStartUtc),
            Variable.withDateTime(dayEndUtc),
            Variable.withString(key),
          ],
          readsFrom: {_db.journalEntries},
        )
        .watch()
        .map((rows) {
      final row = rows.isEmpty ? null : rows.first;
      final income = row?.read<double>('income') ?? 0.0;
      final expense = row?.read<double>('expense') ?? 0.0;
      return TodaySummary(
        day: day,
        totalIncome: income,
        totalExpense: expense,
        net: income - expense,
      );
    });
  }

  /// Serie de saldo diario para el sparkline de cada `_TotalCard`.
  /// Sprint `flutter-dashboard-bundle-v1`.
  ///
  /// `kind ∈ {'bo', 'de', 'cr'}` determina el agregado:
  /// - `bo` = suma de balances (cash + debit).
  /// - `de` = suma de deudas de credit (invertido: origin - destination).
  /// - `cr` = suma de `(credit_limit - deuda)` de credit.
  ///
  /// Retorna exactamente 30 puntos (RN-DB05), del día `hoy - 29` al `hoy`
  /// (inclusive), con backfill del saldo del día previo cuando no hay
  /// movimientos ese día.
  ///
  /// Reactivo sobre `journal_entries` y `accounts` (para reflejar
  /// cambios de límite, archivado y nuevas cuentas).
  ///
  /// Nota RN-DB01: la exclusión de `transfer` y `debt_payment` que aplica
  /// a `watchTodaySummary` (flujo del día) NO aplica aquí. Este método
  /// computa BALANCES agregados; `transfer` y `debt_payment` son
  /// movimientos internos que se autocancelan matemáticamente entre
  /// origen y destino dentro del mismo agregado (ej. un transfer
  /// Bolsa→Débito suma 0 al agregado `bo`). Excluirlos rompería el
  /// saldo derivado.
  Stream<List<DailyBalance>> watchDailyBalance30d({
    required String kind,
    DateTime? now,
  }) {
    // Sprint quality-review: assert defensivo contra `kind` inválido.
    // Sin este chequeo, un typo (`'BO'`, `'balance'`, string vacío)
    // produce silenciosamente 30 puntos con balance 0 — sparkline plano
    // indistinguible de "sin actividad". El error grita en QA.
    assert(kind == 'bo' || kind == 'de' || kind == 'cr',
        'kind inválido: "$kind". Debe ser uno de {bo, de, cr}.');
    final reference = now ?? DateTime.now();
    final today = DateTime(reference.year, reference.month, reference.day);
    final rangeStart = today.subtract(const Duration(days: 29));
    // El SQL trae los movimientos del rango con `month_key` de día y su
    // desglose por cuenta. La query intencional es "amplia": trae 1 fila
    // por (day, account_id) del rango + una fila con el saldo inicial de
    // cada cuenta antes del rango. Se procesa todo en Dart.
    //
    // `readsFrom: {journalEntries, accounts}` para reactividad completa.
    final rangeStartIso = rangeStart.toUtc().toIso8601String();
    const sqlChanges = '''
      SELECT
        a.id AS account_id,
        a.type AS account_type,
        a.credit_limit AS credit_limit,
        strftime('%Y-%m-%d', j.occurred_at, 'localtime') AS day_key,
        COALESCE(SUM(CASE WHEN j.account_destination_id = a.id THEN j.amount ELSE 0 END), 0)
          - COALESCE(SUM(CASE WHEN j.account_origin_id = a.id THEN j.amount ELSE 0 END), 0)
          AS delta
      FROM accounts a
      LEFT JOIN journal_entries j
        ON (j.account_origin_id = a.id OR j.account_destination_id = a.id)
        AND j.deleted_at IS NULL
        AND j.occurred_at >= ?
      WHERE a.deleted_at IS NULL
      GROUP BY a.id, a.type, a.credit_limit,
               strftime('%Y-%m-%d', j.occurred_at, 'localtime')
    ''';
    const sqlInitial = '''
      SELECT
        a.id AS account_id,
        a.type AS account_type,
        a.credit_limit AS credit_limit,
        COALESCE(SUM(CASE WHEN j.account_destination_id = a.id THEN j.amount ELSE 0 END), 0)
          - COALESCE(SUM(CASE WHEN j.account_origin_id = a.id THEN j.amount ELSE 0 END), 0)
          AS initial_balance
      FROM accounts a
      LEFT JOIN journal_entries j
        ON (j.account_origin_id = a.id OR j.account_destination_id = a.id)
        AND j.deleted_at IS NULL
        AND j.occurred_at < ?
      WHERE a.deleted_at IS NULL
      GROUP BY a.id, a.type, a.credit_limit
    ''';
    // 2 streams paralelos combinados via rxdart... pero el proyecto no
    // usa rxdart. Simplificamos usando `Stream.multi` no; mejor: 1 sola
    // query "big" que trae ambas cosas concatenadas. Voto por 2 queries
    // separadas con readsFrom sobre el mismo par y combinar en el .map
    // usando el patrón `customSelect(sql, readsFrom).watch()` para uno
    // y `.get()` para el otro dentro del map. El .get() se reevalúa
    // cada re-emit del principal — coincide semánticamente porque
    // ambos dependen de {journalEntries, accounts}.
    return _db
        .customSelect(
          sqlChanges,
          variables: [Variable.withString(rangeStartIso)],
          readsFrom: {_db.journalEntries, _db.accounts},
        )
        .watch()
        .asyncMap((changeRows) async {
      // `readsFrom` NO se pasa aquí: `.get()` es one-shot y no participa
      // del sistema reactivo de drift; el parámetro sería dead code y
      // podría confundir en refactors futuros. La reactividad del stream
      // vive en el driver principal (`sqlChanges.watch()`).
      //
      // TD conocido: cada re-emit dispara este `.get()` de nuevo. Con 3
      // sparklines suscritos (bo/de/cr), cualquier cambio dispara 6
      // queries (3 changes + 3 initials). Aceptable en single-user
      // <20k entries. Optimización futura: fusionar ambos SQL en un
      // solo `UNION ALL` con sentinel `day_key = 'initial'` para lograr
      // 3 queries por cambio en vez de 6.
      final initialRows = await _db
          .customSelect(
            sqlInitial,
            variables: [Variable.withString(rangeStartIso)],
          )
          .get();
      return _buildDailyBalance30d(
        kind: kind,
        today: today,
        initialRows: initialRows,
        changeRows: changeRows,
      );
    });
  }

  /// Helper puro que arma los 30 puntos del sparkline.
  List<DailyBalance> _buildDailyBalance30d({
    required String kind,
    required DateTime today,
    required List<QueryRow> initialRows,
    required List<QueryRow> changeRows,
  }) {
    // Balance inicial por cuenta (al cierre del día `rangeStart - 1`).
    final initialByAccount = <String, _AccountBalanceMeta>{};
    for (final row in initialRows) {
      final id = row.read<String>('account_id');
      initialByAccount[id] = _AccountBalanceMeta(
        type: row.read<String>('account_type'),
        creditLimit: row.read<double>('credit_limit'),
        balance: row.read<double>('initial_balance'),
      );
    }

    // Deltas por (accountId, day_key). day_key puede ser null si la
    // cuenta no tiene movimientos en el rango (LEFT JOIN).
    final deltasByAccount = <String, Map<String, double>>{};
    for (final row in changeRows) {
      final id = row.read<String>('account_id');
      final dayKey = row.readNullable<String>('day_key');
      if (dayKey == null) continue; // fila vacía del LEFT JOIN.
      final delta = row.read<double>('delta');
      deltasByAccount.putIfAbsent(id, () => <String, double>{})[dayKey] = delta;

      // Asegurar que la cuenta esté en initial (por si no tuvo mov
      // pre-rango; el sqlInitial la trajo con balance 0).
      initialByAccount.putIfAbsent(
        id,
        () => _AccountBalanceMeta(
          type: row.read<String>('account_type'),
          creditLimit: row.read<double>('credit_limit'),
          balance: 0,
        ),
      );
    }

    // Backfill día a día por cuenta y agregar al total según kind.
    final result = <DailyBalance>[];
    // Balance actual por cuenta (arranca en initial).
    final runningBalance = <String, double>{};
    for (final entry in initialByAccount.entries) {
      runningBalance[entry.key] = entry.value.balance;
    }

    for (var i = 0; i < 30; i++) {
      final day = today.subtract(Duration(days: 29 - i));
      final dayKey =
          '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

      // Aplicar deltas del día a cada cuenta.
      for (final acctId in runningBalance.keys) {
        final delta = deltasByAccount[acctId]?[dayKey] ?? 0.0;
        runningBalance[acctId] = runningBalance[acctId]! + delta;
      }

      // Colapsar al agregado según kind.
      double aggregated = 0.0;
      for (final entry in runningBalance.entries) {
        final meta = initialByAccount[entry.key]!;
        final rawBalance = entry.value;
        switch (kind) {
          case 'bo':
            if (meta.type == 'cash' || meta.type == 'debit') {
              aggregated += rawBalance;
            }
            break;
          case 'de':
            if (meta.type == 'credit') {
              // Deuda: invertida vs cash/debit. rawBalance actual usa la
              // convención cash (dest - origin). Para credit debemos
              // invertir el signo — deuda positiva sube con `origin`
              // (cargos).
              aggregated += -rawBalance;
            }
            break;
          case 'cr':
            if (meta.type == 'credit') {
              // Disponible = creditLimit - deuda. deuda = -rawBalance.
              final debt = -rawBalance;
              aggregated += meta.creditLimit - debt;
            }
            break;
        }
      }

      result.add(DailyBalance(day: day, balance: aggregated));
    }

    return result;
  }

  SpendingReport _buildReport(
    List<QueryRow> rows, {
    required DateTime from,
    required DateTime to,
  }) {
    if (rows.isEmpty) {
      return SpendingReport(
        total: 0,
        count: 0,
        from: from,
        to: to,
        buckets: const [],
      );
    }
    double total = 0;
    int count = 0;
    final raws = <_RawBucket>[];
    for (final row in rows) {
      final categoryId = row.read<String?>('category_id');
      final categoryName = row.read<String?>('category_name');
      final colorSlug = row.read<String?>('color_slug');
      final iconSlug = row.read<String?>('icon_slug');
      final bucketTotal = row.read<double>('total');
      final bucketCount = row.read<int>('count');
      total += bucketTotal;
      count += bucketCount;
      final isUncategorized = categoryId == null || categoryName == null;
      raws.add(_RawBucket(
        categoryId: isUncategorized ? null : categoryId,
        name: isUncategorized ? kUncategorizedBucketName : categoryName,
        colorSlug: isUncategorized ? null : colorSlug,
        iconSlug: isUncategorized ? null : iconSlug,
        total: bucketTotal,
        count: bucketCount,
      ));
    }
    final buckets = raws.map((r) {
      return SpendingBucket(
        categoryId: r.categoryId,
        name: r.name,
        colorSlug: r.colorSlug,
        iconSlug: r.iconSlug,
        total: r.total,
        percent: total > 0 ? r.total / total : 0,
        count: r.count,
      );
    }).toList();
    buckets.sort((a, b) {
      final cmp = b.total.compareTo(a.total);
      if (cmp != 0) return cmp;
      return a.name.compareTo(b.name);
    });
    return SpendingReport(
      total: total,
      count: count,
      from: from,
      to: to,
      buckets: buckets,
    );
  }

  /// Ingreso por categoría agregado en el rango `[from, to]` inclusivo en
  /// ambos extremos. Sprint `flutter-reports-income-by-category-v1`.
  ///
  /// Simétrico a [spendingByCategory] pero para `kind='income'` y con
  /// filtro adicional `c.applies_to != 'expense'` en el LEFT JOIN. El
  /// simétrico `!= 'income'` de [spendingByCategory] se agregó después
  /// en el sprint `flutter-reports-drilldown-parity-v1`.
  ///
  /// Filtros:
  /// - `kind = 'income'` (RN-I01). Excluye expense, credit_expense,
  ///   debt_payment, transfer.
  /// - `journal_entries.deleted_at IS NULL` (RN-I02).
  /// - Bucket "Sin categoría" acumula 3 casos gracias al `LEFT JOIN`:
  ///   (a) entries con `category_id NULL`;
  ///   (b) entries con categoría archivada (`c.deleted_at IS NOT NULL`);
  ///   (c) entries con categoría de tipo `applies_to='expense'` (edge
  ///   legacy, RN-I05). El filtro se aplica en el JOIN — NO en el WHERE —
  ///   porque en el WHERE excluiría el income entero en vez de asignarlo
  ///   al bucket "Sin categoría".
  ///
  /// Reactividad: el Stream re-emite ante cambios en `journal_entries` o
  /// `categories`.
  ///
  /// Orden RN-I06: monto desc, tiebreak alfabético asc por nombre.
  Stream<IncomeReport> incomeByCategory({
    required DateTime from,
    required DateTime to,
  }) {
    const sql = '''
      SELECT
        c.id AS category_id,
        c.name AS category_name,
        c.color_slug AS color_slug,
        c.icon_slug AS icon_slug,
        SUM(j.amount) AS total,
        COUNT(*) AS count
      FROM journal_entries j
      LEFT JOIN categories c
        ON c.id = j.category_id
        AND c.deleted_at IS NULL
        AND c.applies_to != 'expense'
      WHERE j.kind = 'income'
        AND j.deleted_at IS NULL
        AND j.occurred_at >= ?
        AND j.occurred_at <= ?
      GROUP BY c.id, c.name, c.color_slug, c.icon_slug
    ''';
    return _db
        .customSelect(
          sql,
          variables: [
            Variable.withDateTime(from),
            Variable.withDateTime(to),
          ],
          readsFrom: {_db.journalEntries, _db.categories},
        )
        .watch()
        .map((rows) => _buildIncomeReport(rows, from: from, to: to));
  }

  IncomeReport _buildIncomeReport(
    List<QueryRow> rows, {
    required DateTime from,
    required DateTime to,
  }) {
    if (rows.isEmpty) {
      return IncomeReport(
        total: 0,
        count: 0,
        from: from,
        to: to,
        buckets: const [],
      );
    }
    double total = 0;
    int count = 0;
    final raws = <_RawBucket>[];
    for (final row in rows) {
      final categoryId = row.read<String?>('category_id');
      final categoryName = row.read<String?>('category_name');
      final colorSlug = row.read<String?>('color_slug');
      final iconSlug = row.read<String?>('icon_slug');
      final bucketTotal = row.read<double>('total');
      final bucketCount = row.read<int>('count');
      total += bucketTotal;
      count += bucketCount;
      final isUncategorized = categoryId == null || categoryName == null;
      raws.add(_RawBucket(
        categoryId: isUncategorized ? null : categoryId,
        name: isUncategorized ? kUncategorizedBucketName : categoryName,
        colorSlug: isUncategorized ? null : colorSlug,
        iconSlug: isUncategorized ? null : iconSlug,
        total: bucketTotal,
        count: bucketCount,
      ));
    }
    final buckets = raws.map((r) {
      return IncomeBucket(
        categoryId: r.categoryId,
        name: r.name,
        colorSlug: r.colorSlug,
        iconSlug: r.iconSlug,
        total: r.total,
        percent: total > 0 ? r.total / total : 0,
        count: r.count,
      );
    }).toList();
    buckets.sort((a, b) {
      final cmp = b.total.compareTo(a.total);
      if (cmp != 0) return cmp;
      return a.name.compareTo(b.name);
    });
    return IncomeReport(
      total: total,
      count: count,
      from: from,
      to: to,
      buckets: buckets,
    );
  }

  /// Top N movimientos por monto descendente del rango. Sprint
  /// `flutter-reports-top-movements-v1`.
  ///
  /// Filtros:
  /// - `kind IN (kinds)` — los kinds seleccionados por el usuario en el
  ///   header del tab (RN-T02). Si `kinds.isEmpty`, atajo defensivo:
  ///   retorna reporte vacío sin tocar BD (evita SQL inválido con `IN ()`
  ///   y respeta el contrato del empty state forzado).
  /// - `journal_entries.deleted_at IS NULL` (RN-T04).
  /// - Rango `[from, to]` inclusivo (RN-T03). `to` se extiende hasta el
  ///   fin del día (23:59:59.999) coherente con el resto del DAO.
  /// - Categoría archivada: el `LEFT JOIN ... AND deleted_at IS NULL`
  ///   deja `cat_id` en NULL — la UI muestra el entry sin badge (RN-T07).
  ///
  /// Orden: `amount DESC, occurred_at DESC, created_at DESC` (RN-T06,
  /// tiebreak determinístico).
  ///
  /// Limit: `limit` filas (default 20 por RN-T08).
  ///
  /// Reactividad: re-emite cuando cambian `journal_entries` o
  /// `categories` (archivar mueve buckets).
  Stream<TopMovementsReport> topMovements({
    required DateTime from,
    required DateTime to,
    required List<String> kinds,
    int limit = 20,
  }) {
    if (kinds.isEmpty) {
      return Stream.value(_buildEmptyTopReport(from, to));
    }
    final inclusiveTo = DateTime(to.year, to.month, to.day, 23, 59, 59, 999);
    // Construir el placeholders dinámico para el `IN (?, ?, ...)` según
    // la cantidad de kinds. Drift no permite `Variable.withStringList`
    // como `IN (...)` directo en customSelect; lo hacemos manual.
    final placeholders = List.filled(kinds.length, '?').join(', ');
    final sql = '''
      SELECT
        j.id AS j_id,
        j.kind AS j_kind,
        j.amount AS j_amount,
        j.occurred_at AS j_occurred_at,
        j.description AS j_description,
        c.id AS c_id,
        c.name AS c_name,
        c.color_slug AS c_color_slug,
        c.icon_slug AS c_icon_slug
      FROM journal_entries j
      LEFT JOIN categories c
        ON c.id = j.category_id AND c.deleted_at IS NULL
      WHERE j.kind IN ($placeholders)
        AND j.deleted_at IS NULL
        AND j.occurred_at >= ?
        AND j.occurred_at <= ?
      ORDER BY j.amount DESC, j.occurred_at DESC, j.created_at DESC
      LIMIT ?
    ''';
    return _db
        .customSelect(
          sql,
          variables: [
            for (final k in kinds) Variable.withString(k),
            Variable.withDateTime(from),
            Variable.withDateTime(inclusiveTo),
            Variable.withInt(limit),
          ],
          readsFrom: {_db.journalEntries, _db.categories},
        )
        .watch()
        .map((rows) => _buildTopReport(rows, from: from, to: to));
  }

  TopMovementsReport _buildEmptyTopReport(DateTime from, DateTime to) {
    return TopMovementsReport(from: from, to: to, entries: const []);
  }

  TopMovementsReport _buildTopReport(
    List<QueryRow> rows, {
    required DateTime from,
    required DateTime to,
  }) {
    final entries = <TopMovementEntry>[];
    for (final row in rows) {
      final catId = row.read<String?>('c_id');
      final catName = row.read<String?>('c_name');
      final colorSlug = row.read<String?>('c_color_slug');
      final iconSlug = row.read<String?>('c_icon_slug');
      final category = (catId != null && catName != null)
          ? TopMovementCategory(
              id: catId,
              name: catName,
              colorSlug: colorSlug,
              iconSlug: iconSlug,
            )
          : null;
      entries.add(TopMovementEntry(
        id: row.read<String>('j_id'),
        kind: row.read<String>('j_kind'),
        amount: row.read<double>('j_amount'),
        occurredAt: row.read<DateTime>('j_occurred_at'),
        description: row.read<String?>('j_description'),
        category: category,
      ));
    }
    return TopMovementsReport(from: from, to: to, entries: entries);
  }

  /// Saldo de BO/DE/CR a una fecha pasada arbitraria via replay del journal
  /// hasta el fin del día de `asOf` (RN-B04 inclusivo). Sprint
  /// `flutter-reports-balance-at-date-v1`.
  ///
  /// Una sola query SQL devuelve una fila por cuenta activa con su balance
  /// individual a la fecha. Los 3 totales (BO/DE/CR) se calculan en Dart
  /// agregando sobre las filas — evita 4 queries separadas a BD.
  ///
  /// Filtros:
  /// - `accounts.deleted_at IS NULL` (RN-B05 — solo cuentas activas hoy).
  /// - `journal_entries.deleted_at IS NULL`.
  /// - `journal_entries.occurred_at <= endOfDay(asOf)`.
  ///
  /// Orden: cash → debit → credit, alfabético dentro de cada tipo
  /// (RN-B08).
  ///
  /// Reactividad: re-emite cuando cambian `accounts` o `journal_entries`.
  Stream<BalanceAtDateReport> balanceAtDate({required DateTime asOf}) {
    final endOfDay = _endOfDay(asOf);
    final endOfToday = _endOfDay(DateTime.now());
    const sql = '''
      SELECT
        a.id AS a_id,
        a.name AS a_name,
        a.type AS a_type,
        a.credit_limit AS a_credit_limit,
        (CASE
          WHEN a.type IN ('cash', 'debit') THEN
            (COALESCE((SELECT SUM(amount) FROM journal_entries
                        WHERE account_destination_id = a.id
                        AND deleted_at IS NULL
                        AND occurred_at <= ?), 0)
             - COALESCE((SELECT SUM(amount) FROM journal_entries
                        WHERE account_origin_id = a.id
                        AND deleted_at IS NULL
                        AND occurred_at <= ?), 0))
          WHEN a.type = 'credit' THEN
            (COALESCE((SELECT SUM(amount) FROM journal_entries
                        WHERE account_origin_id = a.id
                        AND deleted_at IS NULL
                        AND occurred_at <= ?), 0)
             - COALESCE((SELECT SUM(amount) FROM journal_entries
                        WHERE account_destination_id = a.id
                        AND deleted_at IS NULL
                        AND occurred_at <= ?), 0))
          ELSE 0
        END) AS balance,
        (CASE
          WHEN a.type IN ('cash', 'debit') THEN
            (COALESCE((SELECT SUM(amount) FROM journal_entries
                        WHERE account_destination_id = a.id
                        AND deleted_at IS NULL
                        AND occurred_at <= ?), 0)
             - COALESCE((SELECT SUM(amount) FROM journal_entries
                        WHERE account_origin_id = a.id
                        AND deleted_at IS NULL
                        AND occurred_at <= ?), 0))
          WHEN a.type = 'credit' THEN
            (COALESCE((SELECT SUM(amount) FROM journal_entries
                        WHERE account_origin_id = a.id
                        AND deleted_at IS NULL
                        AND occurred_at <= ?), 0)
             - COALESCE((SELECT SUM(amount) FROM journal_entries
                        WHERE account_destination_id = a.id
                        AND deleted_at IS NULL
                        AND occurred_at <= ?), 0))
          ELSE 0
        END) AS balance_now
      FROM accounts a
      WHERE a.deleted_at IS NULL
      ORDER BY
        CASE a.type
          WHEN 'cash' THEN 1
          WHEN 'debit' THEN 2
          WHEN 'credit' THEN 3
          ELSE 4
        END ASC,
        a.name ASC
    ''';
    return _db
        .customSelect(
          sql,
          variables: [
            // 4 placeholders para `balance` (asOf).
            Variable.withDateTime(endOfDay),
            Variable.withDateTime(endOfDay),
            Variable.withDateTime(endOfDay),
            Variable.withDateTime(endOfDay),
            // 4 placeholders para `balance_now` (hoy).
            Variable.withDateTime(endOfToday),
            Variable.withDateTime(endOfToday),
            Variable.withDateTime(endOfToday),
            Variable.withDateTime(endOfToday),
          ],
          readsFrom: {_db.accounts, _db.journalEntries},
        )
        .watch()
        .map((rows) => _buildBalanceAtDateReport(rows, asOf: asOf));
  }

  /// Extiende `asOf` al final del día (23:59:59.999) para que entries
  /// ocurridos cualquier hora del día seleccionado entren al replay. RN-B04.
  DateTime _endOfDay(DateTime asOf) {
    return DateTime(asOf.year, asOf.month, asOf.day, 23, 59, 59, 999);
  }

  BalanceAtDateReport _buildBalanceAtDateReport(
    List<QueryRow> rows, {
    required DateTime asOf,
  }) {
    var bo = 0.0;
    var de = 0.0;
    var cr = 0.0;
    var boNow = 0.0;
    var deNow = 0.0;
    var crNow = 0.0;
    final accounts = <AccountBalanceAtDate>[];
    for (final row in rows) {
      final type = row.read<String>('a_type');
      final balance = row.read<double>('balance');
      final balanceNow = row.read<double>('balance_now');
      // Post-schema v5 (sprint flutter-reports-credit-cards-v1), `credit_limit`
      // es NOT NULL DEFAULT 0. Toda tarjeta contribuye a CR con
      // `creditLimit - balance` (puede ser negativo si `debt > limit`).
      final creditLimit = row.read<double>('a_credit_limit');
      if (type == 'cash' || type == 'debit') {
        bo += balance;
        boNow += balanceNow;
      } else if (type == 'credit') {
        de += balance;
        deNow += balanceNow;
        cr += creditLimit - balance;
        crNow += creditLimit - balanceNow;
      }
      accounts.add(AccountBalanceAtDate(
        id: row.read<String>('a_id'),
        name: row.read<String>('a_name'),
        type: type,
        creditLimit: creditLimit,
        balance: balance,
        balanceNow: balanceNow,
      ));
    }
    return BalanceAtDateReport(
      asOf: asOf,
      bo: bo,
      de: de,
      cr: cr,
      boNow: boNow,
      deNow: deNow,
      crNow: crNow,
      accounts: accounts,
    );
  }

  /// Promedio mensual prorrateado al día actual + gasto del mes en curso.
  /// Sprint `flutter-reports-monthly-average-v1`.
  ///
  /// Calcula el gasto promedio histórico de los últimos `monthsBack` meses
  /// cerrados, prorrateado al mismo día del mes que `now` (RN-A07), y lo
  /// compara contra el gasto acumulado del mes en curso desde el día 1
  /// hasta `now` (RN-A05).
  ///
  /// Filtros:
  /// - Kind ∈ {`expense`, `credit_expense`} (RN-A01). Excluye `transfer`,
  ///   `debt_payment`, `income`.
  /// - `journal_entries.deleted_at IS NULL` (RN-A06).
  /// - Entries con categoría NULL o archivada agrupan en bucket "Sin
  ///   categoría" (RN-A09).
  ///
  /// Prorrateo (RN-A07 + RN-A08): el filtro
  /// `CAST(strftime('%d', occurred_at) AS INTEGER) <= D` excluye días
  /// posteriores al D del mes. Para meses cortos (e.g. febrero con D=31)
  /// no excluye nada porque el filtro es inclusivo a un día que no existe
  /// — equivalente a "usar último día disponible" sin lógica adicional.
  ///
  /// Una sola query agregada: combina histórico prorrateado + mes en curso
  /// vía condición compuesta. Procesamiento en Dart para promediar y armar
  /// el desglose.
  ///
  /// Reactividad: re-emite cuando cambian `journal_entries` o `categories`
  /// (archivar mueve buckets — RN-A09).
  ///
  /// `now` opcional para tests deterministas. Default `DateTime.now()`.
  Stream<MonthlyAverageReport> monthlyAverage({
    required int monthsBack,
    DateTime? now,
  }) {
    final nowValue = now ?? DateTime.now();
    final currentDay = nowValue.day;
    final firstDayOfCurrentMonth =
        DateTime(nowValue.year, nowValue.month, 1);
    final closedMonths = _iterateClosedMonths(nowValue, monthsBack);
    // `windowFrom` = primer día del mes histórico más antiguo. Si
    // monthsBack == 0 (caso defensivo, no esperado por UI), windowFrom
    // colapsa al firstDayOfCurrentMonth.
    final windowFrom = closedMonths.isEmpty
        ? firstDayOfCurrentMonth
        : closedMonths.first;
    // Fin del rango inclusivo: fin del día de `now`.
    final windowTo = DateTime(
        nowValue.year, nowValue.month, nowValue.day, 23, 59, 59, 999);
    // SQLite trata NULL == NULL en GROUP BY → entries con c.id IS NULL
    // (categoría null o archivada) caen al mismo grupo, igual que en
    // `spendingByCategory`.
    const sql = '''
      SELECT
        strftime('%Y-%m', j.occurred_at) AS month_key,
        c.id AS category_id,
        c.name AS category_name,
        c.color_slug AS color_slug,
        c.icon_slug AS icon_slug,
        SUM(j.amount) AS total
      FROM journal_entries j
      LEFT JOIN categories c
        ON c.id = j.category_id AND c.deleted_at IS NULL
      WHERE j.kind IN ('expense', 'credit_expense')
        AND j.deleted_at IS NULL
        AND j.occurred_at >= ?
        AND j.occurred_at <= ?
        AND (
          (j.occurred_at < ? AND CAST(strftime('%d', j.occurred_at) AS INTEGER) <= ?)
          OR j.occurred_at >= ?
        )
      GROUP BY month_key, c.id, c.name, c.color_slug, c.icon_slug
    ''';
    return _db
        .customSelect(
          sql,
          variables: [
            Variable.withDateTime(windowFrom),
            Variable.withDateTime(windowTo),
            // Cutoff entre histórico y mes actual: primer día del mes en curso.
            Variable.withDateTime(firstDayOfCurrentMonth),
            Variable.withInt(currentDay),
            Variable.withDateTime(firstDayOfCurrentMonth),
          ],
          readsFrom: {_db.journalEntries, _db.categories},
        )
        .watch()
        .map((rows) => _buildMonthlyAverageReport(
              rows,
              monthsRequested: monthsBack,
              closedMonths: closedMonths,
              firstDayOfCurrentMonth: firstDayOfCurrentMonth,
              now: nowValue,
              windowFrom: windowFrom,
              windowTo: windowTo,
            ));
  }

  /// Construye la lista de `DateTime(year, month, 1)` para los `monthsBack`
  /// meses cerrados anteriores al mes en curso de `now`. Orden ascendente.
  /// Si `monthsBack <= 0` retorna lista vacía.
  List<DateTime> _iterateClosedMonths(DateTime now, int monthsBack) {
    if (monthsBack <= 0) return const [];
    final result = <DateTime>[];
    // Primer mes cerrado = mes anterior al actual.
    var year = now.year;
    var month = now.month - 1;
    if (month == 0) {
      month = 12;
      year -= 1;
    }
    // Construir hacia atrás los `monthsBack` meses.
    for (var i = 0; i < monthsBack; i++) {
      result.add(DateTime(year, month, 1));
      month -= 1;
      if (month == 0) {
        month = 12;
        year -= 1;
      }
    }
    // Ordenar ascendente para que windowFrom sea el primero.
    return result.reversed.toList();
  }

  MonthlyAverageReport _buildMonthlyAverageReport(
    List<QueryRow> rows, {
    required int monthsRequested,
    required List<DateTime> closedMonths,
    required DateTime firstDayOfCurrentMonth,
    required DateTime now,
    required DateTime windowFrom,
    required DateTime windowTo,
  }) {
    // Agrupar filas por categoría y por bucket histórico vs actual.
    // categoryKey = categoryId ?? '__uncategorized__' para mantener nullable
    // y diferenciar el bucket "Sin categoría".
    const uncategorizedKey = '__uncategorized__';
    // Por categoría: (monthKey → total) de filas históricas + total del mes
    // actual.
    final historicalByCategory =
        <String, Map<String, double>>{}; // catKey → (monthKey → total)
    final currentByCategory = <String, double>{}; // catKey → total
    // Metadata por categoría (solo se setea la primera vez que aparece).
    final categoryMeta = <String, _MonthlyAverageCategoryMeta>{};
    final currentMonthKey = _monthKey(firstDayOfCurrentMonth);
    final closedMonthKeys = closedMonths.map(_monthKey).toSet();

    for (final row in rows) {
      final monthKey = row.read<String>('month_key');
      final categoryId = row.read<String?>('category_id');
      final categoryName = row.read<String?>('category_name');
      final colorSlug = row.read<String?>('color_slug');
      final iconSlug = row.read<String?>('icon_slug');
      final total = row.read<double>('total');
      final isUncategorized = categoryId == null || categoryName == null;
      final catKey = isUncategorized ? uncategorizedKey : categoryId;
      categoryMeta.putIfAbsent(
        catKey,
        () => _MonthlyAverageCategoryMeta(
          categoryId: isUncategorized ? null : categoryId,
          name: isUncategorized ? kUncategorizedBucketName : categoryName,
          colorSlug: isUncategorized ? null : colorSlug,
          iconSlug: isUncategorized ? null : iconSlug,
        ),
      );
      if (monthKey == currentMonthKey) {
        currentByCategory[catKey] = (currentByCategory[catKey] ?? 0) + total;
      } else if (closedMonthKeys.contains(monthKey)) {
        final perMonth =
            historicalByCategory.putIfAbsent(catKey, () => {});
        perMonth[monthKey] = (perMonth[monthKey] ?? 0) + total;
      }
      // Filas con monthKey fuera de la ventana (e.g. drift en zona horaria,
      // o futuro) se ignoran defensivamente.
    }

    // Calcular `monthsAvailable`: meses cerrados que aportan al menos un
    // entry de cualquier categoría. Si M=0, reporte vacío.
    final monthsWithData = <String>{};
    for (final perMonth in historicalByCategory.values) {
      monthsWithData.addAll(perMonth.keys);
    }
    final monthsAvailable = monthsWithData.length;

    if (monthsAvailable == 0 && currentByCategory.isEmpty) {
      return MonthlyAverageReport(
        monthsRequested: monthsRequested,
        monthsAvailable: 0,
        windowFrom: windowFrom,
        windowTo: windowTo,
        currentDayOfMonth: now.day,
        historicalAverage: 0,
        currentMonthSpent: 0,
        deltaAbsolute: 0,
        deltaPercent: null,
        categoryBreakdown: const [],
      );
    }

    // Construir breakdown por categoría.
    final allCategoryKeys = <String>{
      ...historicalByCategory.keys,
      ...currentByCategory.keys,
    };
    final breakdown = <CategoryAverageDelta>[];
    var globalHistoricalSum = 0.0;
    var globalCurrent = 0.0;
    for (final catKey in allCategoryKeys) {
      final perMonth = historicalByCategory[catKey] ?? const {};
      // Suma del histórico de esta categoría dividida por el N **global**
      // (monthsAvailable), no por la cantidad de meses en que ESTA categoría
      // tuvo gasto. Razón: queremos el promedio mensual de la categoría,
      // tratando los meses sin gasto como 0 (consistencia con global).
      // Si monthsAvailable == 0, la división se omite (historicalAverage=0).
      final categoryHistoricalSum =
          perMonth.values.fold<double>(0, (a, b) => a + b);
      final categoryHistoricalAverage =
          monthsAvailable == 0 ? 0.0 : categoryHistoricalSum / monthsAvailable;
      final categoryCurrent = currentByCategory[catKey] ?? 0;
      final categoryDelta = categoryCurrent - categoryHistoricalAverage;
      final double? categoryPercent;
      if (categoryHistoricalAverage == 0) {
        categoryPercent = null;
      } else {
        categoryPercent =
            (categoryDelta / categoryHistoricalAverage) * 100;
      }
      final meta = categoryMeta[catKey]!;
      breakdown.add(CategoryAverageDelta(
        categoryId: meta.categoryId,
        name: meta.name,
        colorSlug: meta.colorSlug,
        iconSlug: meta.iconSlug,
        historicalAverage: categoryHistoricalAverage,
        currentMonthSpent: categoryCurrent,
        deltaAbsolute: categoryDelta,
        deltaPercent: categoryPercent,
      ));
      globalHistoricalSum += categoryHistoricalSum;
      globalCurrent += categoryCurrent;
    }

    // Orden del breakdown (RN-A12): delta absoluto descendente, tiebreak
    // alfabético por nombre.
    breakdown.sort((a, b) {
      final cmp = b.deltaAbsolute.compareTo(a.deltaAbsolute);
      if (cmp != 0) return cmp;
      return a.name.compareTo(b.name);
    });

    final globalHistoricalAverage =
        monthsAvailable == 0 ? 0.0 : globalHistoricalSum / monthsAvailable;
    final globalDelta = globalCurrent - globalHistoricalAverage;
    final double? globalPercent;
    if (globalHistoricalAverage == 0) {
      globalPercent = null;
    } else {
      globalPercent = (globalDelta / globalHistoricalAverage) * 100;
    }

    return MonthlyAverageReport(
      monthsRequested: monthsRequested,
      monthsAvailable: monthsAvailable,
      windowFrom: windowFrom,
      windowTo: windowTo,
      currentDayOfMonth: now.day,
      historicalAverage: globalHistoricalAverage,
      currentMonthSpent: globalCurrent,
      deltaAbsolute: globalDelta,
      deltaPercent: globalPercent,
      categoryBreakdown: breakdown,
    );
  }

  /// `'2026-06'` para `DateTime(2026, 6, 1)`. Mantiene el formato que produce
  /// `strftime('%Y-%m', ...)` en la query.
  String _monthKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$y-$m';
  }

  /// Estado actual de las tarjetas de crédito activas del sprint
  /// `flutter-reports-credit-cards-v1`.
  ///
  /// Emite `List<CreditCardStatus>` reactivamente cuando cambian `accounts`
  /// (metadata o archive) o `journal_entries` (cargo o pago que mueve la
  /// deuda). Un StreamBuilder en el UI recibe la lista actualizada sin
  /// refresh manual.
  ///
  /// Cálculos:
  /// - Deuda = `Σ origin.amount − Σ destination.amount` para la cuenta
  ///   (patrón credit del `FinancialStateService`).
  /// - `%usado`, `disponible`, `pagoMínimo`, `próximo corte/pago`,
  ///   `daysTo*` se calculan en Dart post-fetch (ver `CreditCardStatus`).
  /// - Orden: RN-CC09 — con deuda por proximidad de pago asc; sin deuda
  ///   alfabético asc al final.
  Stream<List<CreditCardStatus>> watchCreditCards({DateTime? now}) {
    const sql = '''
      SELECT
        a.id AS account_id,
        a.name AS name,
        a.description AS description,
        a.credit_limit AS credit_limit,
        a.closing_day AS closing_day,
        a.payment_day AS payment_day,
        COALESCE(SUM(CASE WHEN j.account_origin_id = a.id THEN j.amount ELSE 0 END), 0)
          - COALESCE(SUM(CASE WHEN j.account_destination_id = a.id THEN j.amount ELSE 0 END), 0)
          AS debt
      FROM accounts a
      LEFT JOIN journal_entries j
        ON (j.account_origin_id = a.id OR j.account_destination_id = a.id)
        AND j.deleted_at IS NULL
      WHERE a.deleted_at IS NULL
        AND a.type = 'credit'
      GROUP BY a.id, a.name, a.description, a.credit_limit,
               a.closing_day, a.payment_day
    ''';
    return _db
        .customSelect(
          sql,
          readsFrom: {_db.accounts, _db.journalEntries},
        )
        .watch()
        .map((rows) {
      final referenceDate = now ?? DateTime.now();
      final statuses = rows.map((row) {
        return CreditCardStatus.compute(
          accountId: row.read<String>('account_id'),
          name: row.read<String>('name'),
          description: row.readNullable<String>('description'),
          creditLimit: row.read<double>('credit_limit'),
          debt: row.read<double>('debt'),
          closingDay: row.readNullable<int>('closing_day'),
          paymentDay: row.readNullable<int>('payment_day'),
          today: referenceDate,
        );
      }).toList();
      statuses.sort(CreditCardStatus.compareForReport);
      return statuses;
    });
  }

  /// Progreso del mes en curso por categoría con presupuesto, del sprint
  /// `flutter-budgets-v1`.
  ///
  /// Retorna `Stream<List<BudgetProgress>>` reactivo. Re-emite cuando cambian
  /// `categories` (edición de `monthly_limit`, archive) o `journal_entries`
  /// (registro/cancelación de gastos en el mes).
  ///
  /// Filtros:
  /// - Categorías activas (`c.deleted_at IS NULL`) con `monthly_limit != null`.
  /// - Excluye categorías `applies_to='income'` (RN-B07, blindaje contra edge
  ///   legacy: import de backup con la combinación inválida no rechaza pero
  ///   el reporte la filtra).
  /// - `spent` = suma de gastos activos con `kind ∈ {expense, credit_expense}`
  ///   en el rango del mes en curso, con `category_id` que coincide con la
  ///   categoría (LEFT JOIN acepta 0 gastos).
  ///
  /// Orden RN-B11 en Dart post-fetch (ver `BudgetProgress.compareForReport`).
  ///
  /// Trade-off de reactividad temporal: `monthAnchor` se evalúa al construir
  /// el Stream (una sola vez). Si el usuario deja el tab abierto y cruza
  /// medianoche del último día del mes, el rango [from, to] sigue apuntando
  /// al mes cerrado hasta que se registre cualquier evento reactivo o se
  /// re-monte el tab. Consistente con el patrón de `watchCreditCards`;
  /// aceptable para uso single-user esporádico.
  Stream<List<BudgetProgress>> watchBudgetsProgress({DateTime? monthAnchor}) {
    final anchor = monthAnchor ?? DateTime.now();
    final range = monthRange(anchor);
    const sql = '''
      SELECT
        c.id AS category_id,
        c.name AS category_name,
        c.color_slug AS color_slug,
        c.icon_slug AS icon_slug,
        c.monthly_limit AS monthly_limit,
        COALESCE(SUM(j.amount), 0) AS spent
      FROM categories c
      LEFT JOIN journal_entries j
        ON j.category_id = c.id
        AND j.deleted_at IS NULL
        AND j.kind IN ('expense', 'credit_expense')
        AND j.occurred_at >= ?
        AND j.occurred_at <= ?
      WHERE c.deleted_at IS NULL
        AND c.monthly_limit IS NOT NULL
        AND c.applies_to != 'income'
      GROUP BY c.id, c.name, c.color_slug, c.icon_slug, c.monthly_limit
    ''';
    return _db
        .customSelect(
          sql,
          variables: [
            Variable.withDateTime(range.from),
            Variable.withDateTime(range.to),
          ],
          readsFrom: {_db.categories, _db.journalEntries},
        )
        .watch()
        .map((rows) {
      final progresses = rows.map((row) {
        return BudgetProgress.compute(
          categoryId: row.read<String>('category_id'),
          categoryName: row.read<String>('category_name'),
          colorSlug: row.read<String>('color_slug'),
          iconSlug: row.read<String>('icon_slug'),
          monthlyLimit: row.read<double>('monthly_limit'),
          spent: row.read<double>('spent'),
        );
      }).toList();
      progresses.sort(BudgetProgress.compareForReport);
      return progresses;
    });
  }

  /// Actividad diaria del mes en foco para el calendario de movimientos
  /// (sprint `flutter-reports-movements-calendar-v1`).
  ///
  /// - `monthAnchor` es cualquier `DateTime` del mes deseado; se normaliza a
  ///   `firstDayOfMonth 00:00:00` y `lastDayOfMonth 23:59:59.999` internamente.
  /// - Consulta `journal_entries` acotado al rango del mes (RN-CAL10).
  /// - Excluye soft-deleted (RN-CAL02).
  /// - Agrupa por día vía `strftime('%Y-%m-%d', occurred_at, 'localtime')`
  ///   — fecha local del cel (RN-CAL03). Sin `'localtime'` entries cerca
  ///   de medianoche caerían en el día equivocado (drift almacena UTC).
  /// - Categoriza cada kind según RN-CAL01:
  ///   income → `hasIncome`; expense + credit_expense → `hasSpending`;
  ///   transfer + debt_payment → `hasInternal`.
  ///
  /// Reactividad: `readsFrom: {journalEntries}` — re-emite ante cualquier
  /// cambio en la tabla (incluye cancelaciones y edits).
  ///
  /// Retorna un `Map<DateTime, DayActivity>` cuya clave es la fecha
  /// normalizada a `DateTime(y, m, d)` con hora 0. Días sin actividad no
  /// están en el `Map` (el caller usa `map[day] ?? null` en el
  /// `markerBuilder`).
  Stream<Map<DateTime, DayActivity>> movementsByDay({
    required DateTime monthAnchor,
  }) {
    final from = DateTime(monthAnchor.year, monthAnchor.month, 1);
    // Último día del mes: día 0 del mes siguiente = último del actual.
    final lastDay = DateTime(monthAnchor.year, monthAnchor.month + 1, 0);
    final to = DateTime(lastDay.year, lastDay.month, lastDay.day, 23, 59, 59, 999);
    // `'localtime'` es CRÍTICO: drift persiste DateTime como TEXT UTC con
    // sufijo Z (por `store_date_time_values_as_text: true` en build.yaml).
    // Sin `'localtime'`, `date()` extrae YYYY-MM-DD del UTC, y un entry a
    // las 23:00 local del día 30 (que en UTC son las 05:00 del 31) caería
    // en el día 31 según el reporte. `'localtime'` convierte al huso
    // horario del dispositivo, que es lo que el usuario espera ver.
    const sql = '''
      SELECT strftime('%Y-%m-%d', occurred_at, 'localtime') AS day,
             kind,
             COUNT(*) AS count
      FROM journal_entries
      WHERE deleted_at IS NULL
        AND occurred_at >= ?
        AND occurred_at <= ?
      GROUP BY day, kind
    ''';
    return _db
        .customSelect(
          sql,
          variables: [
            Variable.withDateTime(from),
            Variable.withDateTime(to),
          ],
          readsFrom: {_db.journalEntries},
        )
        .watch()
        .map((rows) => _buildDayActivityMap(rows));
  }

  Map<DateTime, DayActivity> _buildDayActivityMap(List<QueryRow> rows) {
    // Estructura intermedia por día: agregamos flags según kind y sumamos count.
    final buckets = <String, _DayBucket>{};
    for (final row in rows) {
      final dayStr = row.read<String>('day');
      final kind = row.read<String>('kind');
      final count = row.read<int>('count');
      final bucket = buckets.putIfAbsent(dayStr, _DayBucket.new);
      bucket.totalCount += count;
      switch (kind) {
        case 'income':
          bucket.hasIncome = true;
        case 'expense':
        case 'credit_expense':
          bucket.hasSpending = true;
        case 'transfer':
        case 'debt_payment':
          bucket.hasInternal = true;
      }
    }
    final result = <DateTime, DayActivity>{};
    for (final entry in buckets.entries) {
      final parts = entry.key.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);
      result[DateTime(year, month, day)] = DayActivity(
        hasIncome: entry.value.hasIncome,
        hasSpending: entry.value.hasSpending,
        hasInternal: entry.value.hasInternal,
        totalCount: entry.value.totalCount,
      );
    }
    return result;
  }

  /// Heatmap anual de gastos (sprint
  /// `flutter-reports-spending-heatmap-v1`).
  ///
  /// - `year` es el año calendario a consultar (1900..2100 aceptables).
  /// - Consulta `journal_entries` con `kind IN ('expense', 'credit_expense')`
  ///   (RN-HM01). Excluye `income`, `transfer`, `debt_payment`.
  /// - Excluye soft-deleted (RN-HM03).
  /// - Rango: `firstDayOfYear 00:00:00` a `lastDayOfYear 23:59:59.999`
  ///   (RN-HM08).
  /// - Agrupa por día vía `strftime('%Y-%m-%d', occurred_at, 'localtime')`
  ///   (RN-HM02, fecha local del cel). Sin `'localtime'` entries cerca de
  ///   medianoche caerían en el día equivocado (drift almacena UTC).
  ///
  /// Reactividad: `readsFrom: {journalEntries}` — re-emite ante cualquier
  /// cambio en la tabla (incluye cancelaciones y edits). No lee
  /// `categories`, así que archivar/desarchivar categorías no dispara
  /// re-emit (RN-HM12).
  ///
  /// Retorna un [SpendingHeatmap] con `daySpending` (solo días con gasto
  /// > 0), `total`, `daysWithSpending` y cuartiles precalculados
  /// (RN-HM04/HM05).
  Stream<SpendingHeatmap> spendingHeatmap({required int year}) {
    final from = DateTime(year, 1, 1);
    final to = DateTime(year, 12, 31, 23, 59, 59, 999);
    const sql = '''
      SELECT strftime('%Y-%m-%d', occurred_at, 'localtime') AS day,
             SUM(amount) AS total
      FROM journal_entries
      WHERE kind IN ('expense', 'credit_expense')
        AND deleted_at IS NULL
        AND occurred_at >= ?
        AND occurred_at <= ?
      GROUP BY day
    ''';
    return _db
        .customSelect(
          sql,
          variables: [
            Variable.withDateTime(from),
            Variable.withDateTime(to),
          ],
          readsFrom: {_db.journalEntries},
        )
        .watch()
        .map(_buildSpendingHeatmap);
  }

  SpendingHeatmap _buildSpendingHeatmap(List<QueryRow> rows) {
    final daySpending = <DateTime, double>{};
    var total = 0.0;
    for (final row in rows) {
      final dayStr = row.read<String>('day');
      final dayTotal = row.read<double>('total');
      // Un día con SUM=0 (edge legacy con amount=0) NO entra al Map — el
      // heatmap solo cuenta días con gasto real.
      if (dayTotal <= 0) continue;
      final parts = dayStr.split('-');
      final y = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      final d = int.parse(parts[2]);
      daySpending[DateTime(y, m, d)] = dayTotal;
      total += dayTotal;
    }
    final sortedValues = daySpending.values.toList()..sort();
    final (p25, p50, p75) = _computeQuartiles(sortedValues);
    return SpendingHeatmap(
      daySpending: daySpending,
      total: total,
      daysWithSpending: daySpending.length,
      p25: p25,
      p50: p50,
      p75: p75,
    );
  }

  /// Heatmap anual de ingresos (sprint
  /// `flutter-reports-income-heatmap-v1`). Simétrico a [spendingHeatmap]
  /// pero con `kind = 'income'`.
  ///
  /// - `year` es el año calendario a consultar.
  /// - Consulta `journal_entries` con `kind = 'income'` (RN-IHM01).
  ///   Excluye `expense`, `credit_expense`, `transfer`, `debt_payment`.
  /// - Excluye soft-deleted (RN-IHM03).
  /// - Rango: `firstDayOfYear 00:00:00` a `lastDayOfYear 23:59:59.999`
  ///   (RN-IHM08).
  /// - Agrupa por día vía `strftime('%Y-%m-%d', occurred_at, 'localtime')`
  ///   (RN-IHM02, fecha local del cel).
  ///
  /// Reactividad: `readsFrom: {journalEntries}` — re-emite ante cualquier
  /// cambio en la tabla. No lee `categories`, así que archivar/
  /// desarchivar categorías no dispara re-emit (RN-IHM12).
  ///
  /// Retorna un [IncomeHeatmap] con `dayIncome` (solo días con ingreso
  /// > 0), `total`, `daysWithIncome` y cuartiles precalculados
  /// (RN-IHM04/IHM05).
  Stream<IncomeHeatmap> incomeHeatmap({required int year}) {
    final from = DateTime(year, 1, 1);
    final to = DateTime(year, 12, 31, 23, 59, 59, 999);
    const sql = '''
      SELECT strftime('%Y-%m-%d', occurred_at, 'localtime') AS day,
             SUM(amount) AS total
      FROM journal_entries
      WHERE kind = 'income'
        AND deleted_at IS NULL
        AND occurred_at >= ?
        AND occurred_at <= ?
      GROUP BY day
    ''';
    return _db
        .customSelect(
          sql,
          variables: [
            Variable.withDateTime(from),
            Variable.withDateTime(to),
          ],
          readsFrom: {_db.journalEntries},
        )
        .watch()
        .map(_buildIncomeHeatmap);
  }

  IncomeHeatmap _buildIncomeHeatmap(List<QueryRow> rows) {
    final dayIncome = <DateTime, double>{};
    var total = 0.0;
    for (final row in rows) {
      final dayStr = row.read<String>('day');
      final dayTotal = row.read<double>('total');
      // Un día con SUM=0 (edge legacy con amount=0) NO entra al Map.
      if (dayTotal <= 0) continue;
      final parts = dayStr.split('-');
      final y = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      final d = int.parse(parts[2]);
      dayIncome[DateTime(y, m, d)] = dayTotal;
      total += dayTotal;
    }
    final sortedValues = dayIncome.values.toList()..sort();
    final (p25, p50, p75) = _computeQuartiles(sortedValues);
    return IncomeHeatmap(
      dayIncome: dayIncome,
      total: total,
      daysWithIncome: dayIncome.length,
      p25: p25,
      p50: p50,
      p75: p75,
    );
  }
}

/// Acumulador interno de `_buildMonthBreakdown`. Sprint
/// `flutter-cashflow-monthly-breakdown-v1`.
///
/// Cuando varias filas caen al mismo bucket `categoryId=null` (archivada +
/// FK huérfana + `applies_to` incompatible + `NULL` explícito), el primer
/// insert setea la metadata (`label='Sin categoría'`, slugs=null) y las
/// siguientes solo suman via `plus`. El resultado es estable porque el
/// colapso siempre nulifica la metadata. Si algún día se cambia el colapso
/// para preservar la metadata original (ej. mostrar nombre en gris), hay
/// que replantear la clave del acumulador o hacer merge explícito.
/// Metadata + saldo por cuenta del helper `_buildDailyBalance30d`.
/// Sprint `flutter-dashboard-bundle-v1`.
class _AccountBalanceMeta {
  final String type;
  final double creditLimit;
  final double balance;
  const _AccountBalanceMeta({
    required this.type,
    required this.creditLimit,
    required this.balance,
  });
}

class _BreakdownAccumulator {
  final String? categoryId;
  final String label;
  final String? colorSlug;
  final String? iconSlug;
  final double amount;

  const _BreakdownAccumulator({
    required this.categoryId,
    required this.label,
    required this.colorSlug,
    required this.iconSlug,
    required this.amount,
  });

  _BreakdownAccumulator plus(double delta) => _BreakdownAccumulator(
        categoryId: categoryId,
        label: label,
        colorSlug: colorSlug,
        iconSlug: iconSlug,
        amount: amount + delta,
      );
}

class _DayBucket {
  bool hasIncome = false;
  bool hasSpending = false;
  bool hasInternal = false;
  int totalCount = 0;
}

/// Reporte de cashflow mensual del sprint `flutter-reports-cashflow-v1`.
///
/// Inmutable. Construido por [ReportsService.cashflowByMonth]. Agrega
/// ingresos vs gastos por mes calendario dentro del rango
/// `[from, to]` inclusivo en ambos extremos (RN-C05).
class CashflowReport {
  final DateTime from;
  final DateTime to;
  final double totalIncome;
  final double totalExpense;
  final double net;
  final List<MonthCashflow> months;

  const CashflowReport({
    required this.from,
    required this.to,
    required this.totalIncome,
    required this.totalExpense,
    required this.net,
    required this.months,
  });

  /// True cuando el rango no tiene ni ingresos ni gastos. Útil para mostrar
  /// el empty state (RF-010). Los meses pueden estar poblados con ceros por
  /// RN-C06, así que la verificación correcta es sobre los totales.
  bool get isEmpty => totalIncome == 0 && totalExpense == 0;
}

/// Cashflow de un mes calendario.
///
/// - `monthKey`: `YYYY-MM` (string). Útil para tests y debug.
/// - `firstDay`: primer día del mes a las 00:00 del local. Útil para el eje
///   del bar chart.
/// - `income`, `expense`: sumas en el mes (RN-C01/C02).
/// - `net`: `income - expense`. Puede ser negativo.
class MonthCashflow {
  final String monthKey;
  final DateTime firstDay;
  final double income;
  final double expense;
  final double net;

  const MonthCashflow({
    required this.monthKey,
    required this.firstDay,
    required this.income,
    required this.expense,
    required this.net,
  });
}

/// Desglose por categoría de un mes específico. Sprint
/// `flutter-cashflow-monthly-breakdown-v1`.
///
/// Construido por [ReportsService.cashflowMonthBreakdown]. Separa las
/// categorías por lado (ingresos vs gastos). Cada lado puede estar vacío
/// (RN-CB07). Los totales se calculan sobre los buckets efectivos.
class MonthBreakdown {
  final DateTime firstDay;
  final double totalIncome;
  final double totalExpense;
  final double net;
  final List<CategoryFlow> incomeBuckets;
  final List<CategoryFlow> expenseBuckets;
  /// Sprint flutter-cashflow-breakdown-prev-comparison-v1: delta % del
  /// total de ingresos vs el mismo total del mes calendario anterior.
  /// `null` cuando el mes previo tuvo `totalIncome == 0` (RN-CP09) o
  /// cuando no hay dato previo (mes anterior fuera del rango de la BD).
  final DeltaPercent? deltaIncome;
  final DeltaPercent? deltaExpense;
  final DeltaPercent? deltaNet;

  const MonthBreakdown({
    required this.firstDay,
    required this.totalIncome,
    required this.totalExpense,
    required this.net,
    required this.incomeBuckets,
    required this.expenseBuckets,
    this.deltaIncome,
    this.deltaExpense,
    this.deltaNet,
  });
}

/// Bucket individual dentro de [MonthBreakdown]. `categoryId == null` +
/// `label == 'Sin categoría'` para el bucket residual que agrupa
/// movimientos sin categoría, con categoría archivada, o con
/// `applies_to` incompatible (RN-CB03/CB04 — simetría con drilldown-parity).
class CategoryFlow {
  final String? categoryId;
  final String label;
  final String? colorSlug;
  final String? iconSlug;
  final double amount;
  final double percent;
  /// Sprint flutter-cashflow-breakdown-prev-comparison-v1: comparación vs
  /// el mismo bucket (mismo `categoryId`, incluso null para "Sin
  /// categoría") del mes calendario inmediato anterior. `null` cuando no
  /// hay bucket previo con esa categoría (categoría nueva o mes previo
  /// vacío) — la UI muestra `—` en textMuted (RN-CP05).
  final DeltaPercent? delta;

  const CategoryFlow({
    required this.categoryId,
    required this.label,
    required this.colorSlug,
    required this.iconSlug,
    required this.amount,
    required this.percent,
    this.delta,
  });
}

/// Dirección del cambio vs el mes anterior. Sprint
/// `flutter-cashflow-breakdown-prev-comparison-v1`. `flat` cuando el
/// monto es idéntico dentro de una tolerancia de 0.01 (RN-CP04) para
/// blindar contra drift de floating-point.
enum DeltaDirection { up, down, flat }

/// Comparación % entre el mes actual y el mes calendario inmediato
/// anterior. `percent` es siempre no negativo (magnitud); el signo se
/// representa por `direction`. Sprint
/// `flutter-cashflow-breakdown-prev-comparison-v1`.
class DeltaPercent {
  final double percent;
  final DeltaDirection direction;

  const DeltaPercent({
    required this.percent,
    required this.direction,
  });
}

/// Resumen del día actual para la card "Hoy" del dashboard. Sprint
/// `flutter-dashboard-bundle-v1` (RN-DB01..DB04). Excluye `transfer`
/// y `debt_payment` (movimientos internos).
class TodaySummary {
  final DateTime day;
  final double totalIncome;
  final double totalExpense;
  final double net;

  const TodaySummary({
    required this.day,
    required this.totalIncome,
    required this.totalExpense,
    required this.net,
  });
}

/// Punto en el sparkline de saldo diario. Sprint
/// `flutter-dashboard-bundle-v1`. `day` es normalizado a 00:00 local
/// (fecha calendario); `balance` es el saldo agregado al fin de ese día.
class DailyBalance {
  final DateTime day;
  final double balance;

  const DailyBalance({required this.day, required this.balance});
}

/// Reporte de top N movimientos del sprint `flutter-reports-top-movements-v1`.
///
/// Inmutable. Construido por [ReportsService.topMovements]. Lista los
/// hasta N entries más grandes del rango ordenados por monto desc
/// (RN-T06).
class TopMovementsReport {
  final DateTime from;
  final DateTime to;
  final List<TopMovementEntry> entries;

  const TopMovementsReport({
    required this.from,
    required this.to,
    required this.entries,
  });

  bool get isEmpty => entries.isEmpty;
}

/// Una entrada del top. Subset minimalista del journal entry — solo lo
/// necesario para renderear la row y permitir la navegación a edit.
class TopMovementEntry {
  final String id;
  final String kind;
  final double amount;
  final DateTime occurredAt;
  final String? description;
  final TopMovementCategory? category;

  const TopMovementEntry({
    required this.id,
    required this.kind,
    required this.amount,
    required this.occurredAt,
    required this.description,
    required this.category,
  });
}

/// Categoría asociada al entry (badge). Null si el entry no tiene
/// categoría o si la categoría está archivada (RN-T07).
class TopMovementCategory {
  final String id;
  final String name;
  final String? colorSlug;
  final String? iconSlug;

  const TopMovementCategory({
    required this.id,
    required this.name,
    required this.colorSlug,
    required this.iconSlug,
  });
}

/// Reporte de saldo a fecha del sprint
/// `flutter-reports-balance-at-date-v1`.
///
/// Inmutable. Construido por [ReportsService.balanceAtDate]. Replay del
/// journal hasta el fin del día de `asOf` (RN-B04). Útil para reconciliar
/// contra estados de cuenta del banco a fecha de corte.
class BalanceAtDateReport {
  final DateTime asOf;
  final double bo;
  final double de;
  final double cr;
  /// Saldos a hoy (`DateTime.now()` al construir el reporte). Permiten
  /// calcular el delta sin que el usuario tenga que ir al dashboard.
  /// Patch v1 (decisión post-smoke con Diego — eliminar comparación
  /// mental).
  final double boNow;
  final double deNow;
  final double crNow;
  final List<AccountBalanceAtDate> accounts;

  const BalanceAtDateReport({
    required this.asOf,
    required this.bo,
    required this.de,
    required this.cr,
    required this.boNow,
    required this.deNow,
    required this.crNow,
    required this.accounts,
  });

  /// True cuando no hay cuentas activas en BD (caso extremo —
  /// improbable si hay Bolsa, pero defensivo para empty state).
  bool get isEmpty => accounts.isEmpty;

  /// Delta hoy menos fecha. Positivo = el indicador subió. La
  /// interpretación buena/mala depende del indicador (RN-B09).
  double get boDelta => boNow - bo;
  double get deDelta => deNow - de;
  double get crDelta => crNow - cr;
}

/// Saldo individual de una cuenta a la fecha del reporte.
///
/// - `balance` para cash/debit: monto disponible (puede ser negativo si la
///   cuenta tuvo overdraft histórico).
/// - `balance` para credit: deuda acumulada (positivo cuando hay deuda).
/// - `creditLimit` solo aplica a credit; null para cash/debit y para
///   credit sin límite seteado.
class AccountBalanceAtDate {
  final String id;
  final String name;
  final String type;
  final double? creditLimit;
  final double balance;
  /// Saldo a hoy de la cuenta (patch v1). Permite delta automático en
  /// la lista de cuentas.
  final double balanceNow;

  const AccountBalanceAtDate({
    required this.id,
    required this.name,
    required this.type,
    required this.creditLimit,
    required this.balance,
    required this.balanceNow,
  });

  /// Delta hoy menos fecha. Para cash/debit: positivo = ganó plata,
  /// negativo = gastó. Para credit: positivo = más deuda, negativo =
  /// pagó deuda.
  double get balanceDelta => balanceNow - balance;
}

/// Reporte de promedio mensual prorrateado al día actual.
/// Sprint `flutter-reports-monthly-average-v1`.
///
/// Inmutable. Construido por [ReportsService.monthlyAverage]. La métrica
/// global compara el gasto promedio mensual de los últimos `monthsRequested`
/// meses cerrados (prorrateado al día D = `currentDayOfMonth`) contra el
/// gasto acumulado del mes en curso desde el día 1 hasta hoy.
///
/// El campo `categoryBreakdown` desglosa la misma comparación por categoría,
/// ordenado por `deltaAbsolute` descendente (mayor desviación al alza
/// primero). Cuando `historicalAverage == 0` (BD reciente o sin gasto
/// histórico), `deltaPercent` es null y la UI debe mostrar "—".
///
/// `isEmpty == true` cuando no hay gasto histórico ni gasto del mes en curso.
class MonthlyAverageReport {
  final int monthsRequested;
  final int monthsAvailable;
  final DateTime windowFrom;
  final DateTime windowTo;
  final int currentDayOfMonth;
  final double historicalAverage;
  final double currentMonthSpent;
  final double deltaAbsolute;
  final double? deltaPercent;
  final List<CategoryAverageDelta> categoryBreakdown;

  const MonthlyAverageReport({
    required this.monthsRequested,
    required this.monthsAvailable,
    required this.windowFrom,
    required this.windowTo,
    required this.currentDayOfMonth,
    required this.historicalAverage,
    required this.currentMonthSpent,
    required this.deltaAbsolute,
    required this.deltaPercent,
    required this.categoryBreakdown,
  });

  /// True cuando no hay meses cerrados con datos y tampoco hay gasto del mes
  /// en curso. Diferencia el caso "BD recién instalada / sin uso" del caso
  /// "tengo gasto este mes pero sin histórico aún" (donde `monthsAvailable
  /// == 0` pero `currentMonthSpent > 0` y debe renderizarse igual con
  /// `deltaPercent == null`).
  bool get isEmpty =>
      monthsAvailable == 0 && currentMonthSpent == 0;
}

/// Fila del desglose por categoría del [MonthlyAverageReport].
///
/// - `categoryId == null` representa el bucket especial "Sin categoría"
///   (entries con `category_id` NULL o categoría archivada — RN-A09).
/// - `colorSlug` y `iconSlug` son null para el bucket "Sin categoría"; la UI
///   usa los fallback de `category_catalog.dart`.
/// - `historicalAverage` está prorrateado al día D = `currentDayOfMonth` del
///   reporte padre.
/// - `deltaPercent == null` cuando `historicalAverage == 0` (RN-A11): la UI
///   debe mostrar "—" en lugar del porcentaje.
class CategoryAverageDelta {
  final String? categoryId;
  final String name;
  final String? colorSlug;
  final String? iconSlug;
  final double historicalAverage;
  final double currentMonthSpent;
  final double deltaAbsolute;
  final double? deltaPercent;

  const CategoryAverageDelta({
    required this.categoryId,
    required this.name,
    required this.colorSlug,
    required this.iconSlug,
    required this.historicalAverage,
    required this.currentMonthSpent,
    required this.deltaAbsolute,
    required this.deltaPercent,
  });
}

/// Metadata privada que el `_buildMonthlyAverageReport` usa para no
/// recalcular nombre/slugs por cada fila de la query agrupada.
class _MonthlyAverageCategoryMeta {
  final String? categoryId;
  final String name;
  final String? colorSlug;
  final String? iconSlug;

  const _MonthlyAverageCategoryMeta({
    required this.categoryId,
    required this.name,
    required this.colorSlug,
    required this.iconSlug,
  });
}

class _RawBucket {
  final String? categoryId;
  final String name;
  final String? colorSlug;
  final String? iconSlug;
  final double total;
  final int count;

  const _RawBucket({
    required this.categoryId,
    required this.name,
    required this.colorSlug,
    required this.iconSlug,
    required this.total,
    required this.count,
  });
}

/// Estado inmutable de una tarjeta de crédito para el reporte del sprint
/// `flutter-reports-credit-cards-v1`.
///
/// Construido por [ReportsService.watchCreditCards] usando el constructor
/// factory [CreditCardStatus.compute], que aplica RN-CC04..CC08:
///
/// - `usedPct`: `min(debt / creditLimit, 1.0) * 100`; `null` si `creditLimit == 0`.
/// - `availableCredit`: `max(creditLimit - debt, 0)`; nunca negativo.
/// - `nextClosingDate` / `nextPaymentDate`: siguiente ocurrencia del día
///   objetivo con clamp al último día del mes (helper `nextOccurrenceOfDay`).
/// - `isOverdue`: `debt > creditLimit && creditLimit > 0`. Cuando el límite es
///   0 (tarjeta sin cupo formal o límite indefinido), NO marcamos overdue —
///   la card muestra "—" en el ring y disponible=0 sin badge de warning.
///   Decisión de producto: 0 significa "límite indefinido", no "cupo cero".
/// - `isDebtFree`: `debt <= 0`.
class CreditCardStatus {
  final String accountId;
  final String name;
  final String? description;
  final double creditLimit;
  final double debt;
  final double availableCredit;
  final double? usedPct;
  final int? closingDay;
  final int? paymentDay;
  final DateTime? nextClosingDate;
  final DateTime? nextPaymentDate;
  final int? daysToClosing;
  final int? daysToPayment;
  final bool isOverdue;
  final bool isDebtFree;

  const CreditCardStatus({
    required this.accountId,
    required this.name,
    required this.description,
    required this.creditLimit,
    required this.debt,
    required this.availableCredit,
    required this.usedPct,
    required this.closingDay,
    required this.paymentDay,
    required this.nextClosingDate,
    required this.nextPaymentDate,
    required this.daysToClosing,
    required this.daysToPayment,
    required this.isOverdue,
    required this.isDebtFree,
  });

  factory CreditCardStatus.compute({
    required String accountId,
    required String name,
    required String? description,
    required double creditLimit,
    required double debt,
    required int? closingDay,
    required int? paymentDay,
    required DateTime today,
  }) {
    final normalizedDebt = debt < 0 ? 0.0 : debt;
    final available = creditLimit - normalizedDebt;
    final availableCredit = available < 0 ? 0.0 : available;

    double? usedPct;
    if (creditLimit > 0) {
      final ratio = normalizedDebt / creditLimit;
      usedPct = (ratio > 1.0 ? 1.0 : ratio) * 100;
    }

    final isOverdue = normalizedDebt > creditLimit && creditLimit > 0;
    final isDebtFree = normalizedDebt <= 0;

    final DateTime todayMidnight = DateTime(today.year, today.month, today.day);
    DateTime? nextClosing;
    int? daysToClosing;
    if (closingDay != null) {
      nextClosing = nextOccurrenceOfDay(todayMidnight, closingDay);
      daysToClosing = nextClosing.difference(todayMidnight).inDays;
    }
    DateTime? nextPayment;
    int? daysToPayment;
    if (paymentDay != null) {
      nextPayment = nextOccurrenceOfDay(todayMidnight, paymentDay);
      daysToPayment = nextPayment.difference(todayMidnight).inDays;
    }

    return CreditCardStatus(
      accountId: accountId,
      name: name,
      description: description,
      creditLimit: creditLimit,
      debt: normalizedDebt,
      availableCredit: availableCredit,
      usedPct: usedPct,
      closingDay: closingDay,
      paymentDay: paymentDay,
      nextClosingDate: nextClosing,
      nextPaymentDate: nextPayment,
      daysToClosing: daysToClosing,
      daysToPayment: daysToPayment,
      isOverdue: isOverdue,
      isDebtFree: isDebtFree,
    );
  }

  /// Orden RN-CC09 — con deuda por proximidad de pago asc; sin `paymentDay`
  /// van después de las que sí tienen día, ordenadas por deuda desc; sin
  /// deuda al final ordenadas alfabéticamente asc por nombre.
  static int compareForReport(CreditCardStatus a, CreditCardStatus b) {
    // 1) sin deuda al final.
    if (a.isDebtFree != b.isDebtFree) {
      return a.isDebtFree ? 1 : -1;
    }
    if (a.isDebtFree && b.isDebtFree) {
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    }
    // 2) con deuda: las que tienen paymentDay van antes que las que no.
    final aHasPayment = a.daysToPayment != null;
    final bHasPayment = b.daysToPayment != null;
    if (aHasPayment != bHasPayment) {
      return aHasPayment ? -1 : 1;
    }
    if (aHasPayment && bHasPayment) {
      final cmp = a.daysToPayment!.compareTo(b.daysToPayment!);
      if (cmp != 0) return cmp;
      // Empate en días → deuda desc → nombre asc (tiebreak final).
      final debtCmp = b.debt.compareTo(a.debt);
      if (debtCmp != 0) return debtCmp;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    }
    // Sin paymentDay ambos → deuda desc → nombre asc. El tiebreak alfabético
    // final garantiza orden determinístico entre re-emits del stream cuando
    // dos tarjetas tienen métricas idénticas (evita reordenamiento visual).
    final debtCmp = b.debt.compareTo(a.debt);
    if (debtCmp != 0) return debtCmp;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }
}

/// Progreso del presupuesto de una categoría en el mes en curso. Sprint
/// `flutter-budgets-v1`.
///
/// Inmutable. Construido por [ReportsService.watchBudgetsProgress] usando el
/// constructor factory [BudgetProgress.compute].
///
/// Cálculos aplicados (RN-B08, RN-B09):
/// - `usedPct`: `min(spent / monthlyLimit, 1.0) * 100`; `null` si
///   `monthlyLimit == 0` (no calculable).
/// - `available`: `max(monthlyLimit - spent, 0)`; nunca negativo.
/// - `overBy`: `spent - monthlyLimit` cuando el gasto excede el límite;
///   `null` en caso contrario.
/// - Estados: `isOverBudget` (spent > limit), `isWarning` (80-100% sin
///   exceder), `isNoSpend` (spent == 0). Son mutuamente excluyentes con
///   `isOverBudget` prevaleciendo cuando `monthlyLimit == 0 && spent > 0`.
class BudgetProgress {
  final String categoryId;
  final String categoryName;
  final String colorSlug;
  final String iconSlug;
  final double monthlyLimit;
  final double spent;
  final double available;
  final double? usedPct;
  final double? overBy;
  final bool isOverBudget;
  final bool isWarning;
  final bool isNoSpend;

  const BudgetProgress({
    required this.categoryId,
    required this.categoryName,
    required this.colorSlug,
    required this.iconSlug,
    required this.monthlyLimit,
    required this.spent,
    required this.available,
    required this.usedPct,
    required this.overBy,
    required this.isOverBudget,
    required this.isWarning,
    required this.isNoSpend,
  });

  factory BudgetProgress.compute({
    required String categoryId,
    required String categoryName,
    required String colorSlug,
    required String iconSlug,
    required double monthlyLimit,
    required double spent,
  }) {
    final normalizedSpent = spent < 0 ? 0.0 : spent;
    final available = monthlyLimit - normalizedSpent;
    final availableClamped = available < 0 ? 0.0 : available;

    double? usedPct;
    if (monthlyLimit > 0) {
      final ratio = normalizedSpent / monthlyLimit;
      usedPct = (ratio > 1.0 ? 1.0 : ratio) * 100;
    }

    final isOverBudget =
        normalizedSpent > monthlyLimit && normalizedSpent > 0;
    final isNoSpend = normalizedSpent <= 0;
    // Warning: 80% ≤ % < 100% del límite. No aplica si ya está excedido
    // ni si `monthlyLimit == 0` (usedPct null).
    final isWarning = !isOverBudget &&
        !isNoSpend &&
        usedPct != null &&
        usedPct >= 80;

    double? overBy;
    if (isOverBudget) {
      overBy = normalizedSpent - monthlyLimit;
    }

    return BudgetProgress(
      categoryId: categoryId,
      categoryName: categoryName,
      colorSlug: colorSlug,
      iconSlug: iconSlug,
      monthlyLimit: monthlyLimit,
      spent: normalizedSpent,
      available: availableClamped,
      usedPct: usedPct,
      overBy: overBy,
      isOverBudget: isOverBudget,
      isWarning: isWarning,
      isNoSpend: isNoSpend,
    );
  }

  /// Orden RN-B11:
  /// 1. Excedidas primero, ordenadas por `overBy` desc (la que peor va,
  ///    primero — más útil que ordenar por `usedPct` que se clampa a 100
  ///    y termina empatando todas las excedidas).
  /// 2. Warning (mayor `usedPct` desc).
  /// 3. OK con gasto (mayor `usedPct` desc).
  /// 4. Sin gasto al final (alfabético por nombre asc).
  /// Tiebreak final por nombre asc para orden determinístico entre re-emits.
  static int compareForReport(BudgetProgress a, BudgetProgress b) {
    // 1) Sin gasto siempre al final.
    if (a.isNoSpend != b.isNoSpend) {
      return a.isNoSpend ? 1 : -1;
    }
    if (a.isNoSpend && b.isNoSpend) {
      return a.categoryName
          .toLowerCase()
          .compareTo(b.categoryName.toLowerCase());
    }
    // 2) Excedidas antes que el resto.
    if (a.isOverBudget != b.isOverBudget) {
      return a.isOverBudget ? -1 : 1;
    }
    // 3) Ambas excedidas: ordenar por `overBy` desc (la que peor va primero).
    //    Sin este paso, todas las excedidas terminan con usedPct=100 (clamp)
    //    y caen al tiebreak alfabético, escondiendo la más grave.
    if (a.isOverBudget && b.isOverBudget) {
      if (a.overBy != null && b.overBy != null) {
        final cmp = b.overBy!.compareTo(a.overBy!);
        if (cmp != 0) return cmp;
      } else if (a.overBy == null && b.overBy != null) {
        return 1;
      } else if (a.overBy != null && b.overBy == null) {
        return -1;
      }
    } else {
      // 4) Dentro de Warning u OK: ordenar por `usedPct` desc.
      if (a.usedPct != null && b.usedPct != null) {
        final cmp = b.usedPct!.compareTo(a.usedPct!);
        if (cmp != 0) return cmp;
      } else if (a.usedPct == null && b.usedPct != null) {
        return 1;
      } else if (a.usedPct != null && b.usedPct == null) {
        return -1;
      }
    }
    // Tiebreak alfabético asc.
    return a.categoryName
        .toLowerCase()
        .compareTo(b.categoryName.toLowerCase());
  }
}

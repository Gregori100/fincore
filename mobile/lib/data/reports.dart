import 'package:drift/drift.dart';
import 'package:fincore/data/database.dart';

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
        ON c.id = j.category_id AND c.deleted_at IS NULL
      WHERE j.kind IN ('expense', 'credit_expense')
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
      final creditLimit = row.read<double?>('a_credit_limit');
      if (type == 'cash' || type == 'debit') {
        bo += balance;
        boNow += balanceNow;
      } else if (type == 'credit') {
        de += balance;
        deNow += balanceNow;
        if (creditLimit != null) {
          cr += creditLimit - balance;
          crNow += creditLimit - balanceNow;
        }
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

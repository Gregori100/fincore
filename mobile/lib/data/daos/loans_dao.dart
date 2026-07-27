import 'package:drift/drift.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/data/uuid.dart';

part 'loans_dao.g.dart';

/// Errores de dominio del DAO de préstamos. Cada uno mapea a un mensaje
/// específico en `domainErrorToMessage` (`lib/widgets/error_snackbar.dart`).
class LoansDaoError implements Exception {
  final String code;
  final String message;
  const LoansDaoError(this.code, this.message);

  @override
  String toString() => 'LoansDaoError($code): $message';
}

@DriftAccessor(tables: [Loans, JournalEntries, Accounts])
class LoansDao extends DatabaseAccessor<FincoreDatabase>
    with _$LoansDaoMixin {
  LoansDao(super.db);

  // -----------------------------------------------------------------------
  // Reads
  // -----------------------------------------------------------------------

  /// Préstamos activos (no cerrados y no eliminados). Stream reactivo.
  Stream<List<Loan>> watchActive() {
    return (select(loans)
          ..where((l) => l.deletedAt.isNull() & l.closedAt.isNull())
          ..orderBy([
            (l) => OrderingTerm(expression: l.name),
          ]))
        .watch();
  }

  /// Préstamos cerrados (paid o manual), no eliminados. Orden `closed_at DESC`
  /// para que el más reciente aparezca primero.
  Stream<List<Loan>> watchClosed() {
    return (select(loans)
          ..where((l) => l.deletedAt.isNull() & l.closedAt.isNotNull())
          ..orderBy([
            (l) => OrderingTerm(
                expression: l.closedAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  /// Devuelve el préstamo incluyendo cerrados. Excluye eliminados.
  Future<Loan?> findById(String id) {
    return (select(loans)
          ..where((l) => l.id.equals(id) & l.deletedAt.isNull()))
        .getSingleOrNull();
  }

  /// Stream reactivo de un préstamo por id. Hotfix smoke Diego: el detalle
  /// necesita re-renderizar tras un `updateLoan` desde el form de edición
  /// (que hace `pop()` y vuelve al detail). Sin este stream, el `_loan`
  /// cacheado en el State queda stale y el usuario no ve los cambios
  /// aplicados hasta salir y volver a entrar.
  Stream<Loan?> watchById(String id) {
    return (select(loans)
          ..where((l) => l.id.equals(id) & l.deletedAt.isNull()))
        .watchSingleOrNull();
  }

  /// Saldo actual del préstamo = principal - Σ principal_amount de pagos
  /// activos. Se recomputa on-the-fly (nunca persistido, RN-L10).
  ///
  /// Hotfix branch-quality-review (L1 / F-SQL-01): omitimos `readsFrom` en
  /// el `.getSingle()` — es metadata que sólo aplica a `.watch()`. En un
  /// one-shot es ruido y confunde a lectores futuros. La reactividad vive
  /// en `watchBalance`.
  Future<int> balanceOf(String id) async {
    final row = await customSelect(
      'SELECT (SELECT principal_amount FROM loans WHERE id = ?1 AND deleted_at IS NULL) '
      '- COALESCE((SELECT SUM(principal_amount) FROM journal_entries '
      "WHERE loan_id = ?1 AND kind = 'loan_payment' AND deleted_at IS NULL), 0) "
      'AS balance',
      variables: [Variable.withString(id)],
    ).getSingle();
    return row.read<int?>('balance') ?? 0;
  }

  /// Stream reactivo del saldo. Reemite cuando cambian `loans` o
  /// `journal_entries`.
  Stream<int> watchBalance(String id) {
    return customSelect(
      'SELECT (SELECT principal_amount FROM loans WHERE id = ?1 AND deleted_at IS NULL) '
      '- COALESCE((SELECT SUM(principal_amount) FROM journal_entries '
      'WHERE loan_id = ?1 AND kind = \'loan_payment\' AND deleted_at IS NULL), 0) '
      'AS balance',
      variables: [Variable.withString(id)],
      readsFrom: {loans, attachedDatabase.journalEntries},
    ).watchSingle().map((row) => row.read<int?>('balance') ?? 0);
  }

  /// Cuenta los pagos activos de un préstamo. Usado por el DestructiveDialog
  /// para poblar el chip de impacto antes de confirmar la eliminación.
  Future<int> countActivePayments(String loanId) async {
    final row = await (selectOnly(attachedDatabase.journalEntries)
          ..addColumns([attachedDatabase.journalEntries.id.count()])
          ..where(attachedDatabase.journalEntries.loanId.equals(loanId) &
              attachedDatabase.journalEntries.kind.equals('loan_payment') &
              attachedDatabase.journalEntries.deletedAt.isNull()))
        .getSingle();
    return row.read<int>(attachedDatabase.journalEntries.id.count()) ?? 0;
  }

  // -----------------------------------------------------------------------
  // Writes
  // -----------------------------------------------------------------------

  /// Crea un préstamo + el `income` inicial ligado en una única transacción.
  /// Si cualquiera falla, ninguna fila queda persistida.
  ///
  /// Validaciones:
  ///   - `name` no vacío (max 100 chars).
  ///   - `principalAmount > 0`, `monthlyPayment > 0`, `initialDurationMonths > 0`.
  ///   - `paymentDay ∈ [1, 28]`.
  ///   - `destinationAccountId` existe, tipo cash|debit, no archivada, no eliminada.
  Future<String> create({
    required String name,
    required int principalAmount,
    required int monthlyPayment,
    required int initialDurationMonths,
    required int paymentDay,
    required DateTime contractDate,
    required String destinationAccountId,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 100) {
      throw const LoansDaoError(
        'invalid_loan_data',
        'El nombre del préstamo es requerido (máx. 100 caracteres).',
      );
    }
    // El guard `isFinite` del hotfix F-SEC-01 (branch-quality-review) ya no
    // hace falta: desde el sprint flutter-integer-cents-v1 los montos son
    // `int` en centavos, y un `int` de Dart nunca puede ser NaN ni Infinity.
    // La clase entera de bug "NaN persistido en BD que corrompe balanceOf"
    // desaparece con el cambio de tipo. Queda sólo la guarda de dominio.
    if (principalAmount <= 0) {
      throw const LoansDaoError(
        'invalid_loan_data',
        'El monto del préstamo debe ser un número mayor a cero.',
      );
    }
    if (monthlyPayment <= 0) {
      throw const LoansDaoError(
        'invalid_loan_data',
        'El pago mensual debe ser un número mayor a cero.',
      );
    }
    if (initialDurationMonths <= 0) {
      throw const LoansDaoError(
        'invalid_loan_data',
        'La duración del préstamo debe ser mayor a cero meses.',
      );
    }
    if (paymentDay < 1 || paymentDay > 28) {
      throw const LoansDaoError(
        'invalid_payment_day',
        'El día de pago debe estar entre 1 y 28 (para evitar meses cortos).',
      );
    }

    final account = await (select(attachedDatabase.accounts)
          ..where((a) =>
              a.id.equals(destinationAccountId) & a.deletedAt.isNull()))
        .getSingleOrNull();
    if (account == null) {
      throw const LoansDaoError(
        'not_found',
        'La cuenta destino no existe.',
      );
    }
    if (account.archivedAt != null) {
      throw const LoansDaoError(
        'invalid_account_type',
        'La cuenta destino está archivada. Elige una activa.',
      );
    }
    if (account.type != 'cash' && account.type != 'debit') {
      throw const LoansDaoError(
        'invalid_account_type',
        'El préstamo se deposita en una cuenta débito o Bolsa.',
      );
    }

    final now = DateTime.now();
    final loanId = UuidV7.generate();
    final incomeId = UuidV7.generate();

    await transaction(() async {
      await into(loans).insert(LoansCompanion.insert(
        id: loanId,
        name: trimmed,
        principalAmount: principalAmount,
        monthlyPayment: monthlyPayment,
        initialDurationMonths: initialDurationMonths,
        currentDurationMonths: initialDurationMonths,
        paymentDay: paymentDay,
        contractDate: contractDate,
        destinationAccountId: destinationAccountId,
        createdAt: now,
        updatedAt: now,
      ));
      await into(attachedDatabase.journalEntries).insert(
        JournalEntriesCompanion.insert(
          id: incomeId,
          kind: 'income',
          accountDestinationId: Value(destinationAccountId),
          amount: principalAmount,
          occurredAt: contractDate,
          loanId: Value(loanId),
          createdAt: now,
          updatedAt: now,
        ),
      );
    });
    return loanId;
  }

  /// Actualiza los campos editables del contrato. `principal_amount` y
  /// `destination_account_id` son inmutables (RN-L01, RN-L02).
  Future<void> updateLoan({
    required String id,
    String? name,
    int? monthlyPayment,
    int? currentDurationMonths,
    int? paymentDay,
    DateTime? contractDate,
  }) async {
    final existing = await findById(id);
    if (existing == null) {
      throw const LoansDaoError('not_found', 'El préstamo no existe.');
    }
    if (name != null) {
      final trimmed = name.trim();
      if (trimmed.isEmpty || trimmed.length > 100) {
        throw const LoansDaoError(
          'invalid_loan_data',
          'El nombre del préstamo es requerido (máx. 100 caracteres).',
        );
      }
    }
    if (monthlyPayment != null &&
        (!monthlyPayment.isFinite || monthlyPayment <= 0)) {
      throw const LoansDaoError(
        'invalid_loan_data',
        'El pago mensual debe ser un número mayor a cero.',
      );
    }
    // Hotfix smoke Diego: `currentDurationMonths` debe ser >= 1. `0` es
    // confuso (el préstamo está activo pero "sin meses restantes") y no
    // hay UX para representarlo. Si Diego terminó de pagar, el auto-close
    // paid se dispara solo por saldo=0, no por meses=0.
    if (currentDurationMonths != null && currentDurationMonths < 1) {
      throw const LoansDaoError(
        'invalid_loan_data',
        'Los meses restantes deben ser al menos 1.',
      );
    }
    if (paymentDay != null && (paymentDay < 1 || paymentDay > 28)) {
      throw const LoansDaoError(
        'invalid_payment_day',
        'El día de pago debe estar entre 1 y 28.',
      );
    }

    await (update(loans)..where((l) => l.id.equals(id))).write(
      LoansCompanion(
        name: name != null ? Value(name.trim()) : const Value.absent(),
        monthlyPayment: monthlyPayment != null
            ? Value(monthlyPayment)
            : const Value.absent(),
        currentDurationMonths: currentDurationMonths != null
            ? Value(currentDurationMonths)
            : const Value.absent(),
        paymentDay:
            paymentDay != null ? Value(paymentDay) : const Value.absent(),
        contractDate: contractDate != null
            ? Value(contractDate)
            : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Hotfix quality-review M2: aplica auto-cierre `paid` / auto-reapertura
  /// según el balance actual del préstamo. Debe llamarse DENTRO de una
  /// transacción del caller (registerLoanPayment, updateLoanPayment,
  /// deleteLoanPayment) — no abre transacción propia. Idempotente: si el
  /// estado ya coincide con la política, no escribe.
  ///
  /// Reglas (RN-L11/L12/L13):
  ///  • Si `closeReason == 'manual'`: nunca toca (RN-L13).
  ///  • `balance <= 0.005` + no cerrado → cerrar paid.
  ///  • `balance > 0.005` + cerrado por paid → reabrir.
  Future<void> applyPaymentSideEffects({
    required String loanId,
    required DateTime now,
  }) async {
    final loan = await (select(loans)
          ..where((l) => l.id.equals(loanId) & l.deletedAt.isNull()))
        .getSingleOrNull();
    if (loan == null) return;
    if (loan.closeReason == 'manual') return;
    final balance = await balanceOf(loanId);
    if (balance <= 0.005 && loan.closedAt == null) {
      await (update(loans)..where((l) => l.id.equals(loanId))).write(
        LoansCompanion(
          closedAt: Value(now),
          closeReason: const Value('paid'),
          updatedAt: Value(now),
        ),
      );
    } else if (balance > 0.005 && loan.closeReason == 'paid') {
      await (update(loans)..where((l) => l.id.equals(loanId))).write(
        LoansCompanion(
          closedAt: const Value(null),
          closeReason: const Value(null),
          updatedAt: Value(now),
        ),
      );
    }
  }

  /// Cierre manual (RN-L14, reversible via `reopen`). Idempotente si el
  /// préstamo ya está cerrado (silencioso).
  Future<void> closeManual(String id) async {
    final existing = await findById(id);
    if (existing == null) {
      throw const LoansDaoError('not_found', 'El préstamo no existe.');
    }
    if (existing.closedAt != null) {
      // Ya cerrado (paid o manual): no-op.
      return;
    }
    final now = DateTime.now();
    await (update(loans)..where((l) => l.id.equals(id))).write(
      LoansCompanion(
        closedAt: Value(now),
        closeReason: const Value('manual'),
        updatedAt: Value(now),
      ),
    );
  }

  /// Reabre un préstamo cerrado manualmente. Rechaza reabrir un `paid`
  /// (RN-L13). Sobre un préstamo abierto es no-op.
  Future<void> reopen(String id) async {
    final existing = await findById(id);
    if (existing == null) {
      throw const LoansDaoError('not_found', 'El préstamo no existe.');
    }
    if (existing.closedAt == null) {
      // Ya abierto: no-op.
      return;
    }
    if (existing.closeReason == 'paid') {
      throw const LoansDaoError(
        'cannot_reopen_paid',
        'Un préstamo pagado no puede reabrirse. Elimina un pago para reactivarlo o elimina el préstamo entero.',
      );
    }
    final now = DateTime.now();
    await (update(loans)..where((l) => l.id.equals(id))).write(
      LoansCompanion(
        closedAt: const Value(null),
        closeReason: const Value(null),
        updatedAt: Value(now),
      ),
    );
  }

  /// Elimina el préstamo en cascada: `deleted_at` en el `Loan`, en el `income`
  /// inicial y en todos los `loan_payment`s (RN-L16). Los streams de balances
  /// (BO/DE/CR y por cuenta) re-emiten automáticamente vía `readsFrom` sobre
  /// `journal_entries` — no requiere invalidación manual del cache.
  ///
  /// Hotfix quality-review B6: se removió el parámetro `FinancialStateService?
  /// stateService` opcional (era un rezago del patrón manual pre-M4 del
  /// sprint `flutter-local-hardening-v4`). Convención consistente con el
  /// resto de DAOs: los streams cacheados invalidan solos con `readsFrom`.
  Future<void> deleteLoan(String id) async {
    final existing = await findById(id);
    if (existing == null) {
      throw const LoansDaoError('not_found', 'El préstamo no existe.');
    }
    final now = DateTime.now();
    await transaction(() async {
      // Cascada sobre journal_entries ligados al préstamo (income + pagos).
      await (update(attachedDatabase.journalEntries)
            ..where((e) =>
                e.loanId.equals(id) & e.deletedAt.isNull()))
          .write(JournalEntriesCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      ));
      await (update(loans)..where((l) => l.id.equals(id))).write(
        LoansCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
    });
  }

  /// Devuelve el id del préstamo que usa esta cuenta como destino, si existe
  /// alguno activo o cerrado (no eliminado). Usado por `AccountsDao.deleteAccount`
  /// como pre-check (RN-L09).
  Future<Loan?> findByDestinationAccount(String accountId) async {
    return (select(loans)
          ..where((l) =>
              l.destinationAccountId.equals(accountId) & l.deletedAt.isNull())
          ..limit(1))
        .getSingleOrNull();
  }

  /// Stream reactivo con todos los `loan_payment` activos del préstamo,
  /// ordenados por `occurred_at DESC`. Usado por `loan_detail_screen` para
  /// pintar la lista de pagos.
  Stream<List<JournalEntry>> watchPayments(String loanId) {
    return (select(attachedDatabase.journalEntries)
          ..where((e) =>
              e.loanId.equals(loanId) &
              e.kind.equals('loan_payment') &
              e.deletedAt.isNull())
          ..orderBy([
            (e) =>
                OrderingTerm(expression: e.occurredAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  /// Hotfix smoke Diego: cuenta los "pagos del mes" (loan_payment con
  /// interest > 0) del préstamo. Usado para el chip "N / M meses pagados"
  /// en el header del detalle. Los abonos a capital NO se cuentan porque
  /// no representan un mes cubierto — son extras del mes ya pagado.
  Stream<int> watchCountMonthlyPayments(String loanId) {
    return customSelect(
      "SELECT COUNT(*) AS c FROM journal_entries "
      "WHERE loan_id = ? AND kind = 'loan_payment' "
      "AND deleted_at IS NULL AND is_monthly_payment = 1",
      variables: [Variable.withString(loanId)],
      readsFrom: {attachedDatabase.journalEntries},
    ).watchSingle().map((row) => row.read<int>('c'));
  }

  /// Hotfix smoke Diego: el chip "PRÓXIMO PAGO" del Dashboard se debe
  /// ocultar cuando el pago del mes actual ya se registró. Retorna true
  /// si existe algún `loan_payment` con `interest_amount > 0` en el mes
  /// calendario indicado (proxy consistente con la regla de unicidad de
  /// `registerLoanPayment`).
  Future<bool> hasMonthlyPaymentIn(String loanId, int year, int month) async {
    final monthKey =
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
    final row = await customSelect(
      "SELECT COUNT(*) AS c FROM journal_entries "
      "WHERE loan_id = ? AND kind = 'loan_payment' "
      "AND deleted_at IS NULL AND is_monthly_payment = 1 "
      "AND strftime('%Y-%m', occurred_at) = ?",
      variables: [
        Variable.withString(loanId),
        Variable.withString(monthKey),
      ],
    ).getSingle();
    return row.read<int>('c') > 0;
  }

  /// Stream reactivo de `hasMonthlyPaymentIn` — usado por
  /// `_UpcomingPaymentsRow` para re-evaluar al registrar/eliminar pagos.
  Stream<bool> watchHasMonthlyPaymentIn(
      String loanId, int year, int month) {
    final monthKey =
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
    return customSelect(
      "SELECT COUNT(*) AS c FROM journal_entries "
      "WHERE loan_id = ? AND kind = 'loan_payment' "
      "AND deleted_at IS NULL AND is_monthly_payment = 1 "
      "AND strftime('%Y-%m', occurred_at) = ?",
      variables: [
        Variable.withString(loanId),
        Variable.withString(monthKey),
      ],
      readsFrom: {attachedDatabase.journalEntries},
    ).watchSingle().map((row) => row.read<int>('c') > 0);
  }

  /// Sprint flutter-loans-v1 (hotfix smoke Diego v4): cuenta cuántos "pagos
  /// del mes" faltan desde que arrancó el préstamo hasta hoy. Un mes está
  /// "en atraso" si:
  ///   • hoy ya pasó el `paymentDay` de ese mes calendario (o hoy está en
  ///     un mes calendario posterior);
  ///   • el préstamo ya existía (contract_date <= último día del mes);
  ///   • no hay un `loan_payment` con `is_monthly_payment=1` cuyo mes
  ///     calendario (strftime %Y-%m) coincida con ese mes.
  ///
  /// El mes calendario del `contract_date` sólo se cuenta como esperado si
  /// `contract_day <= paymentDay` (el pago cabe dentro del mes de contrato).
  /// Ej: contrato el 20/mayo con paymentDay=5 → primer mes esperado = junio.
  /// Contrato el 1/julio con paymentDay=1 → primer mes esperado = julio.
  ///
  /// Stream reactivo: se recalcula si cambian `loans` o `journal_entries`.
  Stream<int> watchMonthsOverdue({
    required String loanId,
    required DateTime today,
    required DateTime contractDate,
    required int paymentDay,
  }) {
    final expected = _expectedPaymentMonths(
      contractDate: contractDate,
      today: today,
      paymentDay: paymentDay,
    );
    if (expected.isEmpty) {
      // Aun así regresamos un stream reactivo del cambio de journal_entries
      // para consistencia visual, pero siempre 0.
      return Stream.value(0);
    }
    final placeholders = List.filled(expected.length, '?').join(',');
    return customSelect(
      "SELECT COUNT(DISTINCT strftime('%Y-%m', occurred_at)) AS c "
      "FROM journal_entries "
      "WHERE loan_id = ? AND kind = 'loan_payment' "
      "AND deleted_at IS NULL AND is_monthly_payment = 1 "
      "AND strftime('%Y-%m', occurred_at) IN ($placeholders)",
      variables: [
        Variable.withString(loanId),
        ...expected.map(Variable.withString),
      ],
      readsFrom: {attachedDatabase.journalEntries},
    ).watchSingle().map((row) => expected.length - row.read<int>('c'));
  }

  /// Lista los meses calendario `YYYY-MM` que deberían tener pago del mes
  /// según `contractDate`, `today` y `paymentDay`. Ver `watchMonthsOverdue`.
  /// Público para permitir tests unitarios sin BD.
  static List<String> expectedPaymentMonths({
    required DateTime contractDate,
    required DateTime today,
    required int paymentDay,
  }) =>
      _expectedPaymentMonths(
        contractDate: contractDate,
        today: today,
        paymentDay: paymentDay,
      );

  /// Hotfix quality-review B5: cap sanitario para evitar SqliteException
  /// "too many SQL variables". Con `SQLITE_MAX_VARIABLE_NUMBER = 999` en
  /// sqlite <3.32, un préstamo con `contract_date` remoto (ej. legacy o
  /// backup manipulado con 1900-01-01) generaría cientos de meses en el
  /// `IN (?,?,?...)` de `watchMonthsOverdue`. Recortar a los últimos 60
  /// meses cubre el uso real (más de 5 años atrasados no aporta info
  /// distinta al usuario) sin perder correctitud.
  static const int _maxOverdueMonthsWindow = 60;

  /// Hotfix quality-review M5: expone el cálculo de "días hasta el próximo
  /// `paymentDay`" (con roll al mes siguiente si ya pasó) como API pública
  /// del DAO. Antes vivía en `dashboard_screen._daysUntilPayment`, sin
  /// test unitario.
  static int daysUntilNextPaymentDay(int paymentDay, {DateTime? now}) {
    final actualNow = now ?? DateTime.now();
    DateTime target =
        DateTime(actualNow.year, actualNow.month, paymentDay);
    final today =
        DateTime(actualNow.year, actualNow.month, actualNow.day);
    if (target.isBefore(today)) {
      target = DateTime(actualNow.year, actualNow.month + 1, paymentDay);
    }
    final diff = target.difference(today).inDays;
    return diff < 0 ? 0 : diff;
  }

  static List<String> _expectedPaymentMonths({
    required DateTime contractDate,
    required DateTime today,
    required int paymentDay,
  }) {
    // Primer mes esperado: mes del contrato si contract_day <= paymentDay,
    // sino el mes siguiente. La igualdad SÍ cuenta el mes del contrato:
    // hotfix smoke Diego v5 — préstamo contratado el 1/julio con paymentDay=1
    // debe exigir el pago de julio ese mismo día, no saltar a agosto.
    DateTime first;
    if (contractDate.day <= paymentDay) {
      first = DateTime(contractDate.year, contractDate.month, 1);
    } else {
      first = DateTime(contractDate.year, contractDate.month + 1, 1);
    }
    // Último mes esperado: si today.day >= paymentDay, el mes actual; sino
    // el mes anterior.
    DateTime last;
    if (today.day >= paymentDay) {
      last = DateTime(today.year, today.month, 1);
    } else {
      last = DateTime(today.year, today.month - 1, 1);
    }
    if (last.isBefore(first)) return const <String>[];
    final months = <String>[];
    var cursor = first;
    while (!cursor.isAfter(last)) {
      months.add(
        '${cursor.year.toString().padLeft(4, '0')}-'
        '${cursor.month.toString().padLeft(2, '0')}',
      );
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }
    // Hotfix quality-review B5: recorta al windows de los últimos 60 meses.
    // El count de "meses atrasados" queda saturado a 60 para contract_dates
    // extremos, que es lo esperado (chip UI corta en 12+ igual).
    if (months.length > _maxOverdueMonthsWindow) {
      return months.sublist(months.length - _maxOverdueMonthsWindow);
    }
    return months;
  }

  /// Retorna el `id` del `income` inicial del préstamo (creado en `create`).
  /// Usado por el enlace "Ver ingreso inicial" del detalle. Null si por algún
  /// motivo la entrada no existe (préstamo eliminado o corrupción).
  Future<String?> findIncomeEntryId(String loanId) async {
    final row = await (select(attachedDatabase.journalEntries)
          ..where((e) =>
              e.loanId.equals(loanId) &
              e.kind.equals('income') &
              e.deletedAt.isNull())
          ..limit(1))
        .getSingleOrNull();
    return row?.id;
  }
}

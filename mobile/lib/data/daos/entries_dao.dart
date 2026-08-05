import 'package:drift/drift.dart';
import 'package:fincore/constants/filter_tokens.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/data/financial_state.dart';
import 'package:fincore/data/uuid.dart';
import 'package:fincore/utils/money.dart';

// Re-export para que callers que ya importan `entries_dao.dart` (por
// compatibilidad con código previo) sigan teniendo acceso al token sin
// cambiar el import. Marcado para retirar en sprint posterior junto con
// la deprecación de `kind`/`accountId` singulares.
export 'package:fincore/constants/filter_tokens.dart' show kUncategorizedFilterToken;

part 'entries_dao.g.dart';

class EntriesDaoError implements Exception {
  final String code;
  final String message;
  const EntriesDaoError(this.code, this.message);

  @override
  String toString() => 'EntriesDaoError($code): $message';
}

/// Entry con sus relaciones resueltas (account_origin, account_destination, category).
/// Versión de read del DAO que joinea para la lista de movimientos.
class EntryWithRelations {
  final JournalEntry entry;
  final Account? accountOrigin;
  final Account? accountDestination;
  final Category? category;

  const EntryWithRelations({
    required this.entry,
    this.accountOrigin,
    this.accountDestination,
    this.category,
  });
}

const _validKinds = {
  'income',
  'expense',
  'credit_expense',
  'debt_payment',
  'transfer',
  // Sprint flutter-loans-v1: pago de préstamo. Origen cash|debit, destino
  // null, loan_id != null, principal_amount + interest_amount = amount.
  'loan_payment',
};

// `kUncategorizedFilterToken` se movió a `lib/constants/filter_tokens.dart`
// tras el quality review v1 (M1). El re-export al inicio del archivo
// mantiene la compatibilidad con callers que importan desde el DAO.

@DriftAccessor(tables: [JournalEntries, Accounts, Categories])
class EntriesDao extends DatabaseAccessor<FincoreDatabase>
    with _$EntriesDaoMixin {
  // RF-001 a RF-003 del sprint flutter-local-hardening-v4: EntriesDao ya NO
  // recibe FinancialStateService. La única operación que lo requería
  // (`accountBalanceNow` en `registerDebtPayment`) ahora usa la función pura
  // `accountBalanceAtomic` de `financial_state.dart`. Constructor compatible
  // con `@DriftDatabase(daos: [...])` codegen.
  EntriesDao(super.db);

  /// Lista paginada con filtros. Stream reactivo: drift reemite al cambiar
  /// cualquier tabla involucrada.
  ///
  /// - `kinds`: lista de kinds a incluir (`WHERE kind IN (...)`). Si null o
  ///   vacía, no filtra por kind.
  /// - `accountIds`: lista de cuentas a incluir (`WHERE origin IN (...) OR
  ///   destination IN (...)`). Si null o vacía, no filtra por cuenta.
  /// - `categoryIds`: lista de category ids a incluir (`WHERE category_id IN
  ///   (...)`). Soporta el token especial [kUncategorizedFilterToken] para
  ///   matchear NULL + categorías archivadas. Si null o vacía, no filtra por
  ///   categoría.
  /// Sprint `flutter-movements-amount-filter-v1`:
  /// - `minAmount`: si presente, agrega `amount >= min` (RN-A02, inclusivo).
  /// - `maxAmount`: si presente, agrega `amount <= max` (RN-A03, inclusivo).
  /// - Ambos opcionales con default null para preservar callers existentes.
  Stream<List<EntryWithRelations>> watchPage({
    List<String>? kinds,
    List<String>? accountIds,
    List<String>? categoryIds,
    DateTime? from,
    DateTime? to,
    int? minAmount,
    int? maxAmount,
    int offset = 0,
    int limit = 50,
  }) {
    final effectiveKinds = (kinds != null && kinds.isNotEmpty) ? kinds : null;
    final effectiveAccountIds =
        (accountIds != null && accountIds.isNotEmpty) ? accountIds : null;

    final origin = alias(accounts, 'origin');
    final dest = alias(accounts, 'dest');

    final query = select(journalEntries).join([
      leftOuterJoin(origin, origin.id.equalsExp(journalEntries.accountOriginId)),
      leftOuterJoin(dest, dest.id.equalsExp(journalEntries.accountDestinationId)),
      // RN-H03 + RF-015: el join filtra categorías archivadas para que la UI
      // muestre "Sin categoría" en entries cuyo categoryId apunta a una
      // categoría con deletedAt != null. Sin este filtro, los listados del
      // Dashboard y de Movimientos siguen pintando el badge de la archivada.
      // Bonus del sprint flutter-movements-filters-v1: este JOIN también
      // permite que el filtro `__null__` use `categories.id.isNull()` para
      // cubrir NULL + archivadas en una sola condición.
      leftOuterJoin(
        categories,
        categories.id.equalsExp(journalEntries.categoryId) &
            categories.deletedAt.isNull(),
      ),
    ])
      ..where(journalEntries.deletedAt.isNull());

    // Multi-kind via WHERE kind IN (...) — RF-002, RN-M01.
    if (effectiveKinds != null && effectiveKinds.isNotEmpty) {
      query.where(journalEntries.kind.isIn(effectiveKinds));
    }
    // Multi-cuenta via WHERE (origin IN (...) OR destination IN (...)).
    if (effectiveAccountIds != null && effectiveAccountIds.isNotEmpty) {
      query.where(
        journalEntries.accountOriginId.isIn(effectiveAccountIds) |
            journalEntries.accountDestinationId.isIn(effectiveAccountIds),
      );
    }
    // Multi-categoría con token especial __null__ — RF-003, RN-M02/M03.
    // Sprint `flutter-reports-drilldown-parity-v1` (RN-P01/P02/P03): la
    // definición operativa de "Sin categoría" se amplía cuando el filtro
    // está restringido a un único tipo de flujo, para blindar el edge en
    // el que una categoría fue editada de `applies_to=income` a `expense`
    // (o simétrico) después de tener entries asociadas.
    // - kinds efectivo == {'income'}          → agrega applies_to='expense'
    // - kinds efectivo ⊆ {'expense','credit_expense'} → agrega applies_to='income'
    // - resto (null, mixto, transfer, debt_payment, …) → solo `id IS NULL`
    //   (comportamiento clásico). Ver plan/plan.md del slug para detalle.
    if (categoryIds != null && categoryIds.isNotEmpty) {
      final hasNullToken = categoryIds.contains(kUncategorizedFilterToken);
      final realIds = categoryIds
          .where((id) => id != kUncategorizedFilterToken)
          .toList(growable: false);
      final Expression<bool> uncategorizedCondition =
          _uncategorizedCondition(effectiveKinds);
      if (hasNullToken && realIds.isEmpty) {
        query.where(uncategorizedCondition);
      } else if (hasNullToken) {
        query.where(
          journalEntries.categoryId.isIn(realIds) | uncategorizedCondition,
        );
      } else {
        query.where(journalEntries.categoryId.isIn(realIds));
      }
    }
    if (from != null) {
      query.where(journalEntries.occurredAt.isBiggerOrEqualValue(from));
    }
    if (to != null) {
      // Incluye el día completo (hasta 23:59:59.999) — alineado con el backend
      // tras el sprint entries-by-bucket-fixes.
      final inclusiveTo = DateTime(to.year, to.month, to.day, 23, 59, 59, 999);
      query.where(journalEntries.occurredAt.isSmallerOrEqualValue(inclusiveTo));
    }
    if (minAmount != null) {
      query.where(journalEntries.amount.isBiggerOrEqualValue(minAmount));
    }
    if (maxAmount != null) {
      query.where(journalEntries.amount.isSmallerOrEqualValue(maxAmount));
    }

    query
      ..orderBy([
        OrderingTerm(expression: journalEntries.occurredAt, mode: OrderingMode.desc),
        OrderingTerm(expression: journalEntries.createdAt, mode: OrderingMode.desc),
      ])
      ..limit(limit, offset: offset);

    return query.watch().map((rows) {
      return rows.map((row) {
        return EntryWithRelations(
          entry: row.readTable(journalEntries),
          accountOrigin: row.readTableOrNull(origin),
          accountDestination: row.readTableOrNull(dest),
          category: row.readTableOrNull(categories),
        );
      }).toList();
    });
  }

  /// Sprint flutter-entries-bulk-recategorize-v1: fetch por lista de ids.
  /// Devuelve solo las columnas `JournalEntry` (sin joins). Filtra los
  /// soft-deleted. Sirve para saber los `kind`s del batch antes de abrir
  /// el sheet de asignar categoría.
  Future<List<JournalEntry>> findByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    return await (select(journalEntries)
          ..where((e) => e.id.isIn(ids) & e.deletedAt.isNull()))
        .get();
  }

  Future<EntryWithRelations?> findById(String id) async {
    final origin = alias(accounts, 'origin');
    final dest = alias(accounts, 'dest');
    final rows = await (select(journalEntries).join([
      leftOuterJoin(origin, origin.id.equalsExp(journalEntries.accountOriginId)),
      leftOuterJoin(dest, dest.id.equalsExp(journalEntries.accountDestinationId)),
      // RN-H03 + RF-015: el join filtra categorías archivadas para que la UI
      // muestre "Sin categoría" en entries cuyo categoryId apunta a una
      // categoría con deletedAt != null. Sin este filtro, los listados del
      // Dashboard y de Movimientos siguen pintando el badge de la archivada.
      leftOuterJoin(
        categories,
        categories.id.equalsExp(journalEntries.categoryId) &
            categories.deletedAt.isNull(),
      ),
    ])
          ..where(journalEntries.id.equals(id)))
        .get();
    if (rows.isEmpty) return null;
    final row = rows.first;
    return EntryWithRelations(
      entry: row.readTable(journalEntries),
      accountOrigin: row.readTableOrNull(origin),
      accountDestination: row.readTableOrNull(dest),
      category: row.readTableOrNull(categories),
    );
  }

  // ===========================================================================
  // Registro por kind
  // ===========================================================================

  Future<String> registerIncome({
    required String accountDestinationId,
    required int amount,
    required DateTime occurredAt,
    String? description,
    String? categoryId,
  }) =>
      _register(
        kind: 'income',
        accountDestinationId: accountDestinationId,
        amount: amount,
        occurredAt: occurredAt,
        description: description,
        categoryId: categoryId,
      );

  Future<String> registerExpense({
    required String accountOriginId,
    required int amount,
    required DateTime occurredAt,
    String? description,
    String? categoryId,
  }) =>
      _register(
        kind: 'expense',
        accountOriginId: accountOriginId,
        amount: amount,
        occurredAt: occurredAt,
        description: description,
        categoryId: categoryId,
      );

  Future<String> registerCreditExpense({
    required String accountOriginId,
    required int amount,
    required DateTime occurredAt,
    String? description,
    String? categoryId,
  }) =>
      _register(
        kind: 'credit_expense',
        accountOriginId: accountOriginId,
        amount: amount,
        occurredAt: occurredAt,
        description: description,
        categoryId: categoryId,
      );

  Future<String> registerDebtPayment({
    required String accountOriginId,
    required String accountDestinationId,
    required int amount,
    required DateTime occurredAt,
    String? description,
  }) async {
    // Validamos tipos de cuenta PRIMERO (RN-011): el destino debe ser credit.
    // Si no, devolvemos invalid_account_type sin chequear OverpayDebt.
    await _validateAccountTypes(
      kind: 'debt_payment',
      originId: accountOriginId,
      destinationId: accountDestinationId,
    );
    // OverpayDebt + insert dentro de la MISMA transacción: el check del saldo
    // y la inserción del entry quedan atómicos. Sin esto, dos taps muy rápidos
    // del botón Guardar podrían ambos pasar el check con la misma deuda y
    // dejar la tarjeta con saldo a favor.
    return transaction(() async {
      final deuda =
          await accountBalanceAtomic(attachedDatabase, accountDestinationId);
      // Comparación estricta (RN-IC-05). El sprint
      // flutter-integer-cents-v1 eliminó la tolerancia `+ 0.005` que este
      // check necesitaba mientras los montos eran `double`: la deuda se
      // derivaba de sumas/restas IEEE 754 y podía quedar en 173.7699999...
      // cuando el usuario esperaba 173.77, haciendo fallar el pago exacto.
      // Con centavos enteros la resta es exacta y el `>` recupera su
      // semántica literal.
      if (amount > deuda) {
        throw const EntriesDaoError(
          'overpay_debt',
          'El pago no puede ser mayor a la deuda de la tarjeta.',
        );
      }
      return _register(
        kind: 'debt_payment',
        accountOriginId: accountOriginId,
        accountDestinationId: accountDestinationId,
        amount: amount,
        occurredAt: occurredAt,
        description: description,
      );
    });
  }

  /// Sprint flutter-loans-v1: registra un pago de préstamo con split declarado
  /// por el usuario (principal + interest = amount). El préstamo se cierra
  /// automáticamente en `paid` si el saldo cae a ≤ 0 (RN-L11), todo en la
  /// misma transacción.
  Future<String> registerLoanPayment({
    required String loanId,
    required String accountOriginId,
    required int amount,
    required int principalAmount,
    required int interestAmount,
    required DateTime occurredAt,
    String? description,
    // Hotfix smoke Diego: distingue "Pago del mes" (que valida unicidad
    // dentro del mismo mes calendario del `occurredAt`) del "Abono a
    // capital" (múltiples permitidos por mes). Se pasa desde la UI:
    // `LoanMonthlyPaymentForm` → true, `LoanCapitalPaymentForm` → false.
    // La detección de "ya hubo pago del mes" usa `interest_amount > 0`
    // como proxy — los abonos capital tienen `interest_amount = 0` por
    // definición, así que no bloquean.
    bool isMonthlyPayment = false,
  }) async {
    // Validaciones del split antes de tocar BD (RN-L08).
    //
    // El guard `isFinite` del hotfix F-SEC-01 se retiró en el sprint
    // flutter-integer-cents-v1: con montos `int` en centavos, NaN e Infinity
    // son inexpresables, así que la clase de bug que cubría no existe.
    if (amount <= 0) {
      throw const EntriesDaoError(
        'invalid_amount',
        'El monto debe ser mayor a 0.',
      );
    }
    if (principalAmount < 0 || interestAmount < 0) {
      throw const EntriesDaoError(
        'invalid_loan_split',
        'Capital e intereses no pueden ser negativos.',
      );
    }
    // Igualdad exacta (RN-IC-05): en centavos enteros la suma es exacta, así
    // que el margen `.abs() >= 0.005` que compensaba el error IEEE 754 ya no
    // tiene sentido.
    if (principalAmount + interestAmount != amount) {
      throw const EntriesDaoError(
        'invalid_loan_split',
        'La suma de capital + intereses debe ser igual al monto total.',
      );
    }

    // Validar préstamo (existe, abierto, no eliminado).
    final loan = await (select(attachedDatabase.loans)
          ..where((l) => l.id.equals(loanId) & l.deletedAt.isNull()))
        .getSingleOrNull();
    if (loan == null) {
      throw const EntriesDaoError('not_found', 'El préstamo no existe.');
    }
    if (loan.closedAt != null) {
      throw const EntriesDaoError(
        'loan_closed',
        'No se pueden registrar pagos sobre un préstamo cerrado.',
      );
    }

    // Hotfix smoke Diego: pago no puede ser anterior a la fecha del contrato.
    // Aceptamos futuro (Diego quiere poder pagar antes del payment_day).
    // El contract_date se compara truncado a día para evitar off-by-ms.
    final contractDay = DateTime(
        loan.contractDate.year, loan.contractDate.month, loan.contractDate.day);
    final paymentDay =
        DateTime(occurredAt.year, occurredAt.month, occurredAt.day);
    if (paymentDay.isBefore(contractDay)) {
      throw const EntriesDaoError(
        'payment_before_contract',
        'El pago no puede ser anterior a la fecha del contrato del préstamo.',
      );
    }

    // Validar cuenta origen (existe, cash|debit, no archivada, no eliminada).
    // Este check no depende del estado transaccional del préstamo, va afuera.
    await _validateAccountTypes(
      kind: 'loan_payment',
      originId: accountOriginId,
      destinationId: null,
    );

    final id = UuidV7.generate();
    final now = DateTime.now();

    await transaction(() async {
      // Hotfix quality-review M1: el check de overpay corre DENTRO de la
      // transacción re-computando estado. Antes vivía fuera y dos submits
      // paralelos podían pasar ambos con foto stale (balance negativo
      // silencioso).
      //
      // Sprint flutter-loans-flexible-payments-v1: aquí vivían además los
      // candados `duplicate_monthly_payment` (un solo pago del mes por mes
      // calendario) y `capital_before_monthly` (todo abono a capital exige
      // pago del mes previo). Ambos asumían que un préstamo se paga una vez
      // al mes; el préstamo real de Diego es quincenal, así que la
      // suposición era falsa. `is_monthly_payment` sobrevive como etiqueta
      // descriptiva, sin poder de validación (RN-LF-03).
      //
      // `overpay_loan` NO se relajó: es la única regla contable del
      // préstamo y sigue impidiendo que la suma de capitales exceda el
      // saldo, ahora también con ajustes en la fórmula.
      final freshLoan = await (select(attachedDatabase.loans)
            ..where((l) => l.id.equals(loanId) & l.deletedAt.isNull()))
          .getSingleOrNull();
      if (freshLoan == null) {
        throw const EntriesDaoError('not_found', 'El préstamo no existe.');
      }
      if (freshLoan.closedAt != null) {
        throw const EntriesDaoError(
          'loan_closed',
          'No se pueden registrar pagos sobre un préstamo cerrado.',
        );
      }
      final currentBalance =
          await attachedDatabase.loansDao.balanceOf(loanId);
      if (principalAmount > currentBalance) {
        throw EntriesDaoError(
          'overpay_loan',
          'El capital del pago (${formatCents(principalAmount)}) excede el saldo pendiente del préstamo (${formatCents(currentBalance)}).',
        );
      }
      await into(journalEntries).insert(JournalEntriesCompanion.insert(
        id: id,
        kind: 'loan_payment',
        accountOriginId: Value(accountOriginId),
        amount: amount,
        description: Value(description),
        occurredAt: occurredAt,
        loanId: Value(loanId),
        principalAmount: Value(principalAmount),
        interestAmount: Value(interestAmount),
        isMonthlyPayment: Value(isMonthlyPayment),
        createdAt: now,
        updatedAt: now,
      ));
      // Hotfix quality-review M2: auto-close/reopen unificado en helper.
      await attachedDatabase.loansDao
          .recalculateLoanState(loanId: loanId, now: now);
    });
    return id;
  }

  /// Hotfix smoke Diego: edita un `loan_payment` existente. Permite cambiar
  /// monto, split, fecha y descripción. `loan_id`, `kind`, `account_origin`
  /// se preservan (inmutables por trazabilidad — para cambiar la cuenta
  /// origen el usuario elimina y crea uno nuevo).
  ///
  /// Post-update recomputa el balance y aplica auto-close paid /
  /// reapertura auto según los mismos criterios que register/delete.
  ///
  /// Regla clave: si el edit cambia el mes calendario, se re-validan las
  /// reglas de unicidad (monthly único por mes) y orden (capital requiere
  /// monthly del mismo mes) excluyendo el propio entry del conteo.
  Future<void> updateLoanPayment({
    required String entryId,
    required int amount,
    required int principalAmount,
    required int interestAmount,
    required DateTime occurredAt,
    String? description,
  }) async {
    // El guard de finitos (F-SEC-01 replicada) se retiró en el sprint
    // flutter-integer-cents-v1: `int` no admite NaN ni Infinity.
    if (amount <= 0) {
      throw const EntriesDaoError(
        'invalid_amount',
        'El monto debe ser mayor a 0.',
      );
    }
    if (principalAmount < 0 || interestAmount < 0) {
      throw const EntriesDaoError(
        'invalid_loan_split',
        'Capital e intereses no pueden ser negativos.',
      );
    }
    // Igualdad exacta (RN-IC-05) — ver nota en registerLoanPayment.
    if (principalAmount + interestAmount != amount) {
      throw const EntriesDaoError(
        'invalid_loan_split',
        'La suma de capital + intereses debe ser igual al monto total.',
      );
    }

    final existing = await (select(journalEntries)
          ..where((e) => e.id.equals(entryId)))
        .getSingleOrNull();
    if (existing == null) {
      throw const EntriesDaoError('not_found', 'El pago no existe.');
    }
    if (existing.kind != 'loan_payment') {
      throw const EntriesDaoError(
        'not_loan_payment',
        'Este método sólo edita pagos de préstamo.',
      );
    }
    if (existing.deletedAt != null) {
      throw const EntriesDaoError('not_found', 'El pago ya fue eliminado.');
    }
    final loanId = existing.loanId;
    if (loanId == null) {
      throw const EntriesDaoError(
        'invalid_kind',
        'Este pago no está ligado a un préstamo.',
      );
    }

    // Validar préstamo abierto + fecha >= contract_date.
    final loan = await (select(attachedDatabase.loans)
          ..where((l) => l.id.equals(loanId) & l.deletedAt.isNull()))
        .getSingleOrNull();
    if (loan == null) {
      throw const EntriesDaoError('not_found', 'El préstamo no existe.');
    }
    final contractDay = DateTime(
        loan.contractDate.year, loan.contractDate.month, loan.contractDate.day);
    final paymentDay =
        DateTime(occurredAt.year, occurredAt.month, occurredAt.day);
    if (paymentDay.isBefore(contractDay)) {
      throw const EntriesDaoError(
        'payment_before_contract',
        'El pago no puede ser anterior a la fecha del contrato del préstamo.',
      );
    }

    // El tipo del pago (monthly vs capital) se preserva del entry existente
    // — el edit NO permite cambiar el tipo (para eso hay que eliminar y
    // recrear).
    final oldPrincipal = existing.principalAmount ?? 0;
    final now = DateTime.now();

    await transaction(() async {
      // Hotfix quality-review M1: el check de overpay corre DENTRO de la
      // transacción con estado fresco. Antes vivía afuera y dos edits
      // paralelos podían pasar la validación con foto stale.
      //
      // Sprint flutter-loans-flexible-payments-v1: se retiraron los mismos
      // dos candados de mes que `registerLoanPayment` (ver la nota extensa
      // ahí). Mover un pago a un mes que ya tiene pago del mes ahora es
      // válido.
      final currentBalance =
          await attachedDatabase.loansDao.balanceOf(loanId);
      final availableBalance = currentBalance + oldPrincipal;
      if (principalAmount > availableBalance) {
        throw EntriesDaoError(
          'overpay_loan',
          'El capital del pago (${formatCents(principalAmount)}) excede el saldo pendiente disponible (${formatCents(availableBalance)}).',
        );
      }
      await (update(journalEntries)..where((e) => e.id.equals(entryId))).write(
        JournalEntriesCompanion(
          amount: Value(amount),
          principalAmount: Value(principalAmount),
          interestAmount: Value(interestAmount),
          occurredAt: Value(occurredAt),
          description: Value(description),
          updatedAt: Value(now),
        ),
      );
      // Hotfix quality-review M2: auto-close/reopen unificado.
      await attachedDatabase.loansDao
          .recalculateLoanState(loanId: loanId, now: now);
    });
  }

  /// Sprint flutter-loans-v1: elimina un `loan_payment`. Reabre el préstamo
  /// automáticamente si estaba `paid` y ahora el saldo vuelve a > 0 (RN-L12).
  /// Los cerrados manualmente (`manual`) no se tocan.
  ///
  /// Sprint flutter-loans-flexible-payments-v1: se retiró el parámetro
  /// `cascadeCapitalInMonth`, que borraba en cascada los abonos a capital del
  /// mismo mes calendario. Existía únicamente para sostener el invariante
  /// `capital_before_monthly`; sin ese candado, la cascada pasaba a ser un
  /// borrado destructivo sin justificación (RN-LF-04). Cada pago se elimina
  /// ahora de forma independiente.
  Future<void> deleteLoanPayment(String entryId) async {
    final existing = await (select(journalEntries)
          ..where((e) => e.id.equals(entryId)))
        .getSingleOrNull();
    if (existing == null) {
      throw const EntriesDaoError('not_found', 'El movimiento no existe.');
    }
    if (existing.kind != 'loan_payment') {
      throw const EntriesDaoError(
        'invalid_kind',
        'Este método sólo elimina pagos de préstamo.',
      );
    }
    if (existing.deletedAt != null) {
      // Idempotente.
      return;
    }
    // Hotfix branch-quality-review (F-SEC-04): defense en profundidad
    // contra un backup manipulado con `kind='loan_payment' AND loan_id IS NULL`.
    final loanId = existing.loanId;
    if (loanId == null) {
      throw const EntriesDaoError(
        'invalid_kind',
        'Este pago no está ligado a un préstamo.',
      );
    }
    final now = DateTime.now();
    await transaction(() async {
      await (update(journalEntries)..where((e) => e.id.equals(entryId))).write(
        JournalEntriesCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      // Hotfix quality-review M2: auto-close/reopen unificado. Respeta
      // RN-L13 (cerrado manual nunca reabre) porque el helper filtra
      // closeReason == 'manual' antes de tocar.
      await attachedDatabase.loansDao
          .recalculateLoanState(loanId: loanId, now: now);
    });
  }

  Future<String> registerTransfer({
    required String accountOriginId,
    required String accountDestinationId,
    required int amount,
    required DateTime occurredAt,
    String? description,
  }) {
    if (accountOriginId == accountDestinationId) {
      throw const EntriesDaoError(
        'invalid_account_type',
        'La cuenta origen y destino no pueden ser la misma.',
      );
    }
    return _register(
      kind: 'transfer',
      accountOriginId: accountOriginId,
      accountDestinationId: accountDestinationId,
      amount: amount,
      occurredAt: occurredAt,
      description: description,
    );
  }

  Future<String> _register({
    required String kind,
    required int amount,
    required DateTime occurredAt,
    String? accountOriginId,
    String? accountDestinationId,
    String? description,
    String? categoryId,
  }) async {
    if (!_validKinds.contains(kind)) {
      throw const EntriesDaoError('invalid_kind', 'Kind inválido.');
    }
    if (amount <= 0) {
      throw const EntriesDaoError(
        'invalid_amount',
        'El monto debe ser mayor a 0.',
      );
    }
    await _validateAccountTypes(
      kind: kind,
      originId: accountOriginId,
      destinationId: accountDestinationId,
    );
    if (categoryId != null) {
      await _validateCategoryForKind(kind, categoryId);
    }

    final id = UuidV7.generate();
    final now = DateTime.now();
    await into(journalEntries).insert(JournalEntriesCompanion.insert(
      id: id,
      kind: kind,
      accountOriginId: Value(accountOriginId),
      accountDestinationId: Value(accountDestinationId),
      amount: amount,
      description: Value(description),
      occurredAt: occurredAt,
      categoryId: Value(categoryId),
      createdAt: now,
      updatedAt: now,
    ));
    return id;
  }

  /// Editar entry. kind inmutable.
  Future<void> updateEntry({
    required String id,
    int? amount,
    String? description,
    DateTime? occurredAt,
    String? accountOriginId,
    String? accountDestinationId,
    String? categoryId,
    bool clearCategory = false,
  }) async {
    final existing = await (select(journalEntries)..where((e) => e.id.equals(id)))
        .getSingleOrNull();
    if (existing == null) {
      throw const EntriesDaoError('not_found', 'El movimiento no existe.');
    }
    // Sprint flutter-loans-v1 (RN-L15): los movimientos ligados a un préstamo
    // (income inicial + loan_payment) son inmutables desde updateEntry. La
    // corrección es eliminar el pago y crear uno nuevo, o eliminar el
    // préstamo entero para el income inicial.
    if (existing.loanId != null) {
      throw const EntriesDaoError(
        'immutable_loan_payment',
        'Este movimiento pertenece a un préstamo. Se administra desde /loans.',
      );
    }
    if (amount != null && amount <= 0) {
      throw const EntriesDaoError(
        'invalid_amount',
        'El monto debe ser mayor a 0.',
      );
    }
    final effectiveOrigin = accountOriginId ?? existing.accountOriginId;
    final effectiveDestination =
        accountDestinationId ?? existing.accountDestinationId;
    await _validateAccountTypes(
      kind: existing.kind,
      originId: effectiveOrigin,
      destinationId: effectiveDestination,
    );
    // Resolución de categoría con RN-H03 del sprint flutter-local-hardening:
    // si el caller NO cambia categoryId pero la heredada apunta a una
    // categoría archivada, forzamos categoryId = null en el write sin lanzar
    // error (limpieza silenciosa del FK colgante). Si el caller cambia
    // categoryId explícitamente, el flujo de validación es el de siempre.
    var forceClearCategory = false;
    final effectiveCategoryId =
        clearCategory ? null : (categoryId ?? existing.categoryId);
    if (effectiveCategoryId != null) {
      final isExplicitChange = categoryId != null;
      if (isExplicitChange) {
        // El caller asignó una categoría nueva: validar como hasta hoy.
        await _validateCategoryForKind(existing.kind, effectiveCategoryId);
      } else {
        // Categoría heredada (existing.categoryId). Si está archivada,
        // limpiar silenciosamente. Si está activa pero incompatible, igual
        // dejamos pasar para no romper edits de un entry que tenía categoría
        // válida en su momento. Sin embargo, debt_payment/transfer siguen
        // sin aceptar categoría: si el entry heredado la tenía (caso raro),
        // limpiamos.
        // RF-008 del sprint flutter-local-hardening-v2: delegación al helper
        // canónico de CategoriesDao (RF-015) ahora que CategoriesDao se
        // registra en @DriftDatabase(daos: [...]) y queda accesible vía
        // `attachedDatabase.categoriesDao` sin instanciar manualmente.
        final active = await attachedDatabase.categoriesDao
            .findActiveById(effectiveCategoryId);
        if (active == null) {
          forceClearCategory = true;
        } else if (existing.kind == 'transfer' ||
            existing.kind == 'debt_payment') {
          forceClearCategory = true;
        }
      }
    }

    await (update(journalEntries)..where((e) => e.id.equals(id))).write(
      JournalEntriesCompanion(
        amount: amount != null ? Value(amount) : const Value.absent(),
        description: description != null
            ? Value(description.isEmpty ? null : description)
            : const Value.absent(),
        occurredAt: occurredAt != null ? Value(occurredAt) : const Value.absent(),
        accountOriginId: accountOriginId != null
            ? Value(accountOriginId)
            : const Value.absent(),
        accountDestinationId: accountDestinationId != null
            ? Value(accountDestinationId)
            : const Value.absent(),
        categoryId: (clearCategory || forceClearCategory)
            ? const Value(null)
            : (categoryId != null ? Value(categoryId) : const Value.absent()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Sprint flutter-entries-bulk-recategorize-v1: reasigna la categoría de
  /// varios movimientos en una sola transacción. Cada entry se valida con
  /// `_validateCategoryForKind` (misma lógica que `updateEntry`). Al primer
  /// conflicto la transacción aborta y nada se persiste.
  ///
  /// - `entryIds`: journal_entries.id a actualizar. Deben existir y NO
  ///   estar soft-deleted; caso contrario, `not_found` global.
  /// - `categoryId`: nueva categoría (activa, compatible con TODOS los
  ///   kinds del batch) o `null` para desasignar (limpieza universal —
  ///   cualquier kind admite null).
  ///
  /// Errores tipados posibles:
  /// - `not_found` — algún id no existe o está soft-deleted.
  /// - `immutable_loan_payment` — algún entry pertenece a un préstamo.
  /// - `invalid_category_applies_to` — la categoría no aplica a algún
  ///   kind del batch, o el batch contiene entries de kind no-categorizable
  ///   (`transfer`/`debt_payment`/`loan_payment`) con `categoryId != null`.
  ///
  /// Retorna el número de filas actualizadas.
  Future<int> bulkUpdateCategory({
    required List<String> entryIds,
    required String? categoryId,
  }) async {
    if (entryIds.isEmpty) return 0;
    return await transaction(() async {
      final rows = await (select(journalEntries)
            ..where((e) => e.id.isIn(entryIds) & e.deletedAt.isNull()))
          .get();
      if (rows.length != entryIds.toSet().length) {
        throw const EntriesDaoError(
          'not_found',
          'Uno o más movimientos no existen o están cancelados.',
        );
      }
      // Defensa idéntica a `updateEntry`/`cancel`: entries ligados a un
      // préstamo se administran solo desde /loans. Bloquear el bulk aunque
      // el usuario los haya seleccionado por accidente.
      for (final row in rows) {
        if (row.loanId != null) {
          throw const EntriesDaoError(
            'immutable_loan_payment',
            'Uno o más movimientos pertenecen a un préstamo y no pueden '
                're-categorizarse desde acá.',
          );
        }
      }
      // categoryId == null → desasignación universal, cualquier kind lo
      // admite (incluidos transfer/debt_payment que ya deberían tener null).
      if (categoryId != null) {
        for (final row in rows) {
          await _validateCategoryForKind(row.kind, categoryId);
        }
      }
      await (update(journalEntries)..where((e) => e.id.isIn(entryIds))).write(
        JournalEntriesCompanion(
          categoryId: Value(categoryId),
          updatedAt: Value(DateTime.now()),
        ),
      );
      return rows.length;
    });
  }

  /// Cancelar (soft delete). Terminal — sin reactivación.
  Future<void> cancel(String id) async {
    final existing = await (select(journalEntries)..where((e) => e.id.equals(id)))
        .getSingleOrNull();
    if (existing == null) {
      throw const EntriesDaoError('not_found', 'El movimiento no existe.');
    }
    if (existing.deletedAt != null) {
      // Idempotente: si ya estaba cancelado, no hace nada.
      return;
    }
    // Hotfix branch-quality-review (F-TX-03): defensa en profundidad.
    // Entries ligados a un préstamo (income inicial + loan_payment) no
    // pueden cancelarse por esta ruta. Los pagos van por deleteLoanPayment
    // (que dispara reapertura auto). El income inicial sólo se elimina
    // vía LoansDao.deleteLoan (cascada completa). Bloquear cualquier
    // caller alternativo (bulk actions, deep-links, scripts).
    if (existing.loanId != null) {
      throw const EntriesDaoError(
        'immutable_loan_payment',
        'Este movimiento pertenece a un préstamo. Se administra desde /loans.',
      );
    }
    await (update(journalEntries)..where((e) => e.id.equals(id))).write(
      JournalEntriesCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> _validateAccountTypes({
    required String kind,
    String? originId,
    String? destinationId,
  }) async {
    Future<Account?> get(String? id) async {
      if (id == null) return null;
      return (select(accounts)..where((a) => a.id.equals(id))).getSingleOrNull();
    }

    final origin = await get(originId);
    final destination = await get(destinationId);

    if (origin != null && origin.deletedAt != null) {
      throw const EntriesDaoError(
        'invalid_account_type',
        'La cuenta origen ya no está activa.',
      );
    }
    if (destination != null && destination.deletedAt != null) {
      throw const EntriesDaoError(
        'invalid_account_type',
        'La cuenta destino ya no está activa.',
      );
    }

    switch (kind) {
      case 'income':
        if (origin != null) {
          throw const EntriesDaoError('invalid_account_type', 'Ingreso no lleva cuenta origen.');
        }
        if (destination == null ||
            (destination.type != 'cash' && destination.type != 'debit')) {
          throw const EntriesDaoError(
            'invalid_account_type',
            'Ingreso requiere cuenta destino tipo efectivo o débito.',
          );
        }
        break;
      case 'expense':
        if (destination != null) {
          throw const EntriesDaoError('invalid_account_type', 'Gasto no lleva cuenta destino.');
        }
        if (origin == null ||
            (origin.type != 'cash' && origin.type != 'debit')) {
          throw const EntriesDaoError(
            'invalid_account_type',
            'Gasto requiere cuenta origen tipo efectivo o débito.',
          );
        }
        break;
      case 'credit_expense':
        if (destination != null) {
          throw const EntriesDaoError(
              'invalid_account_type', 'Gasto a tarjeta no lleva cuenta destino.');
        }
        if (origin == null || origin.type != 'credit') {
          throw const EntriesDaoError(
            'invalid_account_type',
            'Gasto a tarjeta requiere tarjeta de crédito como origen.',
          );
        }
        if (origin.archivedAt != null) {
          throw const EntriesDaoError(
            'invalid_account_type',
            'La cuenta origen está archivada.',
          );
        }
        break;
      case 'debt_payment':
        if (origin == null ||
            (origin.type != 'cash' && origin.type != 'debit')) {
          throw const EntriesDaoError(
            'invalid_account_type',
            'Pago de tarjeta requiere efectivo o débito como origen.',
          );
        }
        if (destination == null || destination.type != 'credit') {
          throw const EntriesDaoError(
            'invalid_account_type',
            'Pago de tarjeta requiere tarjeta de crédito como destino.',
          );
        }
        break;
      case 'transfer':
        if (origin == null ||
            (origin.type != 'cash' && origin.type != 'debit')) {
          throw const EntriesDaoError(
            'invalid_account_type',
            'Transferencia requiere efectivo o débito como origen.',
          );
        }
        if (destination == null ||
            (destination.type != 'cash' && destination.type != 'debit')) {
          throw const EntriesDaoError(
            'invalid_account_type',
            'Transferencia requiere efectivo o débito como destino.',
          );
        }
        if (origin.id == destination.id) {
          throw const EntriesDaoError(
            'invalid_account_type',
            'La cuenta origen y destino no pueden ser la misma.',
          );
        }
        break;
      case 'loan_payment':
        // Sprint flutter-loans-v1: origen cash|debit no archivada, destino
        // null (el destino es el préstamo, no una Account).
        if (destination != null) {
          throw const EntriesDaoError(
            'invalid_account_type',
            'Pago de préstamo no lleva cuenta destino.',
          );
        }
        if (origin == null ||
            (origin.type != 'cash' && origin.type != 'debit')) {
          throw const EntriesDaoError(
            'invalid_account_type',
            'Pago de préstamo requiere efectivo o débito como origen.',
          );
        }
        if (origin.archivedAt != null) {
          throw const EntriesDaoError(
            'invalid_account_type',
            'La cuenta origen está archivada.',
          );
        }
        break;
    }
  }

  Future<void> _validateCategoryForKind(String kind, String categoryId) async {
    if (kind == 'transfer' || kind == 'debt_payment') {
      throw const EntriesDaoError(
        'invalid_category_applies_to',
        'Este tipo de movimiento no acepta categoría.',
      );
    }
    final cat = await (select(categories)..where((c) => c.id.equals(categoryId)))
        .getSingleOrNull();
    if (cat == null) {
      throw const EntriesDaoError(
        'invalid_category_applies_to',
        'La categoría no existe.',
      );
    }
    if (cat.deletedAt != null) {
      throw const EntriesDaoError(
        'invalid_category_applies_to',
        'La categoría está archivada.',
      );
    }
    final valid = switch (kind) {
      'income' => cat.appliesTo == 'income' || cat.appliesTo == 'both',
      'expense' || 'credit_expense' =>
        cat.appliesTo == 'expense' || cat.appliesTo == 'both',
      _ => false,
    };
    if (!valid) {
      throw const EntriesDaoError(
        'invalid_category_applies_to',
        'La categoría no aplica a este tipo de movimiento.',
      );
    }
  }

  // Sprint `flutter-reports-drilldown-parity-v1` (RN-P01/P02/P03).
  // Devuelve la condición que representa "Sin categoría" para el filtro
  // `kUncategorizedFilterToken` según el conjunto efectivo de kinds:
  // - {'income'}                       → id IS NULL OR applies_to='expense'
  // - subset no vacío de gastos        → id IS NULL OR applies_to='income'
  // - resto (null/mixto/transfer/…)    → id IS NULL (clásico)
  //
  // La expansión captura el edge de categorías editadas post-facto (una
  // categoría income cuyo applies_to fue cambiado a expense, o simétrico)
  // que el reporte trata como "Sin categoría" gracias al filtro del JOIN
  // en `ReportsService.incomeByCategory` / `spendingByCategory`. Alinear
  // la definición aquí garantiza paridad reporte↔drill-down.
  Expression<bool> _uncategorizedCondition(List<String>? effectiveKinds) {
    final base = categories.id.isNull();
    if (effectiveKinds == null || effectiveKinds.isEmpty) {
      return base;
    }
    final kindSet = effectiveKinds.toSet();
    if (kindSet.length == 1 && kindSet.contains('income')) {
      return base | categories.appliesTo.equals('expense');
    }
    const spendingKinds = {'expense', 'credit_expense'};
    if (kindSet.every(spendingKinds.contains)) {
      return base | categories.appliesTo.equals('income');
    }
    return base;
  }
}

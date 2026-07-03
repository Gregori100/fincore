import 'package:drift/drift.dart';
import 'package:fincore/constants/filter_tokens.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/data/financial_state.dart';
import 'package:fincore/data/uuid.dart';

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

const _validKinds = {'income', 'expense', 'credit_expense', 'debt_payment', 'transfer'};

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
    double? minAmount,
    double? maxAmount,
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
    required double amount,
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
    required double amount,
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
    required double amount,
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
    required double amount,
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

  Future<String> registerTransfer({
    required String accountOriginId,
    required String accountDestinationId,
    required double amount,
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
    required double amount,
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
    double? amount,
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

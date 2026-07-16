import 'package:drift/drift.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/data/financial_state.dart';
import 'package:fincore/data/uuid.dart';

part 'accounts_dao.g.dart';

/// Errores de dominio del DAO de cuentas. Cada uno mapea a un mensaje
/// específico en domainErrorToMessage (lib/widgets/error_snackbar.dart).
class AccountsDaoError implements Exception {
  final String code;
  final String message;
  const AccountsDaoError(this.code, this.message);

  @override
  String toString() => 'AccountsDaoError($code): $message';
}

@DriftAccessor(tables: [Accounts])
class AccountsDao extends DatabaseAccessor<FincoreDatabase>
    with _$AccountsDaoMixin {
  AccountsDao(super.db);

  /// Cuentas activas (no archivadas y no eliminadas), ordenadas por tipo y
  /// nombre. Stream reactivo: se reemite cuando algo cambia en `accounts`.
  ///
  /// Sprint flutter-accounts-archive-v1: además de `deleted_at IS NULL`, exige
  /// `archived_at IS NULL` para excluir cuentas archivadas de los pickers de
  /// nuevo movimiento y de la vista principal de /accounts.
  Stream<List<Account>> watchActive() {
    return (select(accounts)
          ..where((a) => a.deletedAt.isNull() & a.archivedAt.isNull())
          ..orderBy([
            (a) => OrderingTerm(expression: a.type),
            (a) => OrderingTerm(expression: a.name),
          ]))
        .watch();
  }

  /// Cuentas archivadas (soft-archive, reversible). Stream reactivo. Preserva
  /// el histórico contable: los movimientos donde figuran siguen intactos y
  /// aparecen en reportes.
  Stream<List<Account>> watchArchived() {
    return (select(accounts)
          ..where((a) => a.deletedAt.isNull() & a.archivedAt.isNotNull())
          ..orderBy([
            (a) => OrderingTerm(expression: a.type),
            (a) => OrderingTerm(expression: a.name),
          ]))
        .watch();
  }

  /// Todas las cuentas no eliminadas. Cuando `includeArchived` es false
  /// (default) sólo devuelve activas; cuando true incluye también las
  /// archivadas. Las eliminadas (`deleted_at IS NOT NULL`) nunca se devuelven.
  Future<List<Account>> listAll({bool includeArchived = false}) {
    final query = select(accounts)..where((a) => a.deletedAt.isNull());
    if (!includeArchived) {
      query.where((a) => a.archivedAt.isNull());
    }
    query.orderBy([
      (a) => OrderingTerm(expression: a.type),
      (a) => OrderingTerm(expression: a.name),
    ]);
    return query.get();
  }

  Future<Account?> findById(String id) {
    return (select(accounts)..where((a) => a.id.equals(id))).getSingleOrNull();
  }

  /// Busca una cuenta por id incluyendo archivadas (pero no eliminadas). Útil
  /// para pantallas read-only (edición bloqueada de entries con cuenta
  /// archivada, badges en /entries).
  Future<Account?> findActiveOrArchivedById(String id) {
    return (select(accounts)
          ..where((a) => a.id.equals(id) & a.deletedAt.isNull()))
        .getSingleOrNull();
  }

  /// Crea cuenta debit o credit. La Bolsa (cash) se crea solo via createBolsa.
  /// Valida nombre único entre activas + metadata de credit válida.
  Future<String> create({
    required String name,
    required String type, // 'debit' | 'credit'
    String? description,
    double? creditLimit,
    int? closingDay,
    int? paymentDay,
    double? interestRate,
    double? minimumPaymentPct,
  }) async {
    if (type == 'cash') {
      throw const AccountsDaoError(
        'invalid_account_type',
        'La Bolsa se crea automáticamente. No se pueden crear más cuentas tipo efectivo.',
      );
    }
    if (type != 'debit' && type != 'credit') {
      throw const AccountsDaoError(
        'invalid_account_type',
        'Tipo de cuenta inválido.',
      );
    }
    await _validateNameUnique(name);
    if (type == 'credit') {
      // Sprint flutter-reports-credit-cards-v1: `credit_limit` es obligatorio
      // explícito para type=credit. Aunque el schema tiene DEFAULT 0, la app
      // exige que el usuario lo declare (aunque sea como 0) para evitar cuentas
      // credit "creadas por accidente" sin datos.
      if (creditLimit == null) {
        throw const AccountsDaoError(
          'invalid_credit_limit',
          'El límite de crédito es obligatorio.',
        );
      }
      _validateCreditMetadata(
        closingDay: closingDay,
        paymentDay: paymentDay,
        creditLimit: creditLimit,
      );
    }

    final now = DateTime.now();
    final id = UuidV7.generate();
    await into(accounts).insert(AccountsCompanion.insert(
      id: id,
      name: name,
      type: type,
      description: Value(description),
      // Para type=credit siempre pasamos el valor (validado no-null arriba).
      // Para cash/debit no pasamos nada — el schema aplica DEFAULT 0.
      creditLimit: type == 'credit'
          ? Value(creditLimit!)
          : const Value.absent(),
      closingDay: Value(type == 'credit' ? closingDay : null),
      paymentDay: Value(type == 'credit' ? paymentDay : null),
      interestRate: Value(type == 'credit' ? interestRate : null),
      minimumPaymentPct: Value(type == 'credit' ? minimumPaymentPct : null),
      createdAt: now,
      updatedAt: now,
    ));
    return id;
  }

  /// Crea la Bolsa singleton. Idempotente: si ya existe una cash activa, no hace nada.
  Future<String> createBolsa() async {
    final existing = await (select(accounts)
          ..where((a) => a.type.equals('cash') & a.deletedAt.isNull()))
        .getSingleOrNull();
    if (existing != null) return existing.id;

    final now = DateTime.now();
    final id = UuidV7.generate();
    await into(accounts).insert(AccountsCompanion.insert(
      id: id,
      name: 'Bolsa',
      type: 'cash',
      isProtected: const Value(true),
      createdAt: now,
      updatedAt: now,
    ));
    return id;
  }

  /// Editar nombre, descripción o metadata de credit. Rechaza si is_protected.
  /// El type es inmutable (no se expone como parámetro).
  ///
  /// Semántica de parámetros nullable (`creditLimit`, `closingDay`, etc.):
  /// `null` significa "no modificar" (usa el valor existente). Post-schema v5
  /// `credit_limit` no puede ser null en BD, así que **no hay forma de "bajar
  /// el límite a null" desde este DAO** — para dejar el límite en 0, pasar
  /// `creditLimit: 0` explícito. Esta es una asimetría deliberada con
  /// `create`, que sí rechaza `creditLimit: null` para type=credit.
  Future<void> updateAccount({
    required String id,
    String? name,
    String? description,
    double? creditLimit,
    int? closingDay,
    int? paymentDay,
    double? interestRate,
    double? minimumPaymentPct,
  }) async {
    final existing = await findById(id);
    if (existing == null) {
      throw const AccountsDaoError('not_found', 'La cuenta no existe.');
    }
    if (existing.isProtected) {
      throw const AccountsDaoError(
        'protected_account',
        'La Bolsa no se puede modificar ni eliminar.',
      );
    }
    if (name != null && name != existing.name) {
      await _validateNameUnique(name, excludeId: id);
    }
    if (existing.type == 'credit') {
      _validateCreditMetadata(
        closingDay: closingDay ?? existing.closingDay,
        paymentDay: paymentDay ?? existing.paymentDay,
        creditLimit: creditLimit ?? existing.creditLimit,
      );
    }

    await (update(accounts)..where((a) => a.id.equals(id))).write(
      AccountsCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        description: description != null
            ? Value(description.isEmpty ? null : description)
            : const Value.absent(),
        creditLimit: existing.type == 'credit' && creditLimit != null
            ? Value(creditLimit)
            : const Value.absent(),
        closingDay: existing.type == 'credit' && closingDay != null
            ? Value(closingDay)
            : const Value.absent(),
        paymentDay: existing.type == 'credit' && paymentDay != null
            ? Value(paymentDay)
            : const Value.absent(),
        interestRate: existing.type == 'credit' && interestRate != null
            ? Value(interestRate)
            : const Value.absent(),
        minimumPaymentPct: existing.type == 'credit' && minimumPaymentPct != null
            ? Value(minimumPaymentPct)
            : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Archivar (soft-archive reversible): marca la cuenta como archivada. NO
  /// toca los movimientos. La cuenta desaparece de pickers de alta y del
  /// segmento "Activas" de /accounts, pero sigue apareciendo en /entries,
  /// filtros con `includeArchived`, reportes y KPIs (BO/DE/CR).
  ///
  /// Es reversible via `unarchive`. Idempotente: llamar sobre una cuenta ya
  /// archivada sobrescribe `archived_at` con el nuevo timestamp sin lanzar
  /// error. Rechaza la Bolsa (`is_protected=true`).
  Future<void> archive(String id) async {
    final existing = await findById(id);
    if (existing == null) {
      throw const AccountsDaoError('not_found', 'La cuenta no existe.');
    }
    if (existing.isProtected) {
      throw const AccountsDaoError(
        'protected_account',
        'La Bolsa no se puede archivar.',
      );
    }
    final now = DateTime.now();
    await (update(accounts)..where((a) => a.id.equals(id))).write(
      AccountsCompanion(
        archivedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  /// Desarchivar: devuelve la cuenta al estado Activa. Idempotente sobre
  /// cuentas que ya estén activas (no-op silencioso). Rechaza la Bolsa por
  /// consistencia (nunca debería estar archivada, pero si por algún motivo
  /// llega ahí, el DAO se resiste).
  Future<void> unarchive(String id) async {
    final existing = await findById(id);
    if (existing == null) {
      throw const AccountsDaoError('not_found', 'La cuenta no existe.');
    }
    if (existing.isProtected) {
      throw const AccountsDaoError(
        'protected_account',
        'La Bolsa no se puede desarchivar.',
      );
    }
    final now = DateTime.now();
    await (update(accounts)..where((a) => a.id.equals(id))).write(
      AccountsCompanion(
        archivedAt: const Value(null),
        updatedAt: Value(now),
      ),
    );
  }

  /// Eliminar en cascada (destructivo): cancela en bloque todos los
  /// movimientos donde la cuenta aparezca como origin o destination (sin
  /// importar el kind, incluidos pagos a tarjeta y transferencias) y después
  /// marca la cuenta como eliminada (`deleted_at`). Es definitivo: ni la
  /// cuenta ni los movimientos se reactivan.
  ///
  /// Sprint flutter-accounts-archive-v1: este método reemplaza al antiguo
  /// `archive` (que hacía justamente esto). El nuevo `archive` es reversible
  /// y no toca movimientos. Nombrado `deleteAccount` (no `delete`) para no
  /// chocar con `DatabaseConnectionUser.delete` de drift — mismo patrón que
  /// `updateAccount`.
  ///
  /// El stateService quedó como parámetro opcional para compatibilidad de
  /// callers; ya no se usa para validar saldo (libreta libre completa).
  Future<void> deleteAccount(String id,
      [FinancialStateService? stateService]) async {
    final existing = await findById(id);
    if (existing == null) {
      throw const AccountsDaoError('not_found', 'La cuenta no existe.');
    }
    if (existing.isProtected) {
      throw const AccountsDaoError(
        'protected_account',
        'La Bolsa no se puede eliminar.',
      );
    }
    final now = DateTime.now();
    // Cascade soft-delete dentro de una transacción: entries + cuenta quedan
    // canceladas atómicamente. Los entries asociados a esta cuenta dejan de
    // sumar a BO/DE/CR y desaparecen de las listas activas.
    await transaction(() async {
      await (update(attachedDatabase.journalEntries)
            ..where((e) =>
                (e.accountOriginId.equals(id) |
                    e.accountDestinationId.equals(id)) &
                e.deletedAt.isNull()))
          .write(JournalEntriesCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      ));
      await (update(accounts)..where((a) => a.id.equals(id))).write(
        AccountsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
    });
    stateService?.invalidateAccount(id);
  }

  /// Cuenta cuántos movimientos activos (no cancelados) tocan esta cuenta como
  /// origin o destination. La UI lo usa para mostrar al usuario qué tanto va
  /// a afectar el archive antes de confirmar.
  Future<int> countAssociatedEntries(String accountId) async {
    final query = selectOnly(attachedDatabase.journalEntries)
      ..addColumns([attachedDatabase.journalEntries.id.count()])
      ..where((attachedDatabase.journalEntries.accountOriginId.equals(accountId) |
              attachedDatabase.journalEntries.accountDestinationId.equals(accountId)) &
          attachedDatabase.journalEntries.deletedAt.isNull());
    final row = await query.getSingle();
    return row.read<int>(attachedDatabase.journalEntries.id.count()) ?? 0;
  }

  Future<void> _validateNameUnique(String name, {String? excludeId}) async {
    final query = select(accounts)
      ..where((a) => a.name.equals(name) & a.deletedAt.isNull());
    if (excludeId != null) {
      query.where((a) => a.id.equals(excludeId).not());
    }
    final existing = await query.getSingleOrNull();
    if (existing != null) {
      throw const AccountsDaoError(
        'duplicate_account_name',
        'Ya existe una cuenta con ese nombre.',
      );
    }
  }

  void _validateCreditMetadata({
    int? closingDay,
    int? paymentDay,
    double? creditLimit,
  }) {
    if (closingDay != null && (closingDay < 1 || closingDay > 31)) {
      throw const AccountsDaoError(
        'invalid_credit_metadata',
        'El día de corte debe estar entre 1 y 31.',
      );
    }
    if (paymentDay != null && (paymentDay < 1 || paymentDay > 31)) {
      throw const AccountsDaoError(
        'invalid_credit_metadata',
        'El día de pago debe estar entre 1 y 31.',
      );
    }
    if (closingDay != null && paymentDay != null && closingDay == paymentDay) {
      throw const AccountsDaoError(
        'invalid_credit_metadata',
        'El día de corte y el día de pago no pueden ser el mismo.',
      );
    }
    // Sprint flutter-reports-credit-cards-v1: el límite pasa a NOT NULL DEFAULT 0
    // en el schema (v5). Se acepta 0 como valor válido (tarjeta departamental o
    // sin límite formal). Solo se rechazan valores negativos.
    if (creditLimit != null && creditLimit < 0) {
      throw const AccountsDaoError(
        'invalid_credit_limit',
        'El límite de crédito no puede ser negativo.',
      );
    }
  }

}

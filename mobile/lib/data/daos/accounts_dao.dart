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

  /// Cuentas activas (no archivadas), ordenadas por tipo y luego por nombre.
  /// Stream reactivo: se reemite cuando algo cambia en la tabla accounts.
  Stream<List<Account>> watchActive() {
    return (select(accounts)
          ..where((a) => a.deletedAt.isNull())
          ..orderBy([
            (a) => OrderingTerm(expression: a.type),
            (a) => OrderingTerm(expression: a.name),
          ]))
        .watch();
  }

  /// Todas las cuentas, incluyendo archivadas si se solicita.
  Future<List<Account>> listAll({bool includeArchived = false}) {
    final query = select(accounts);
    if (!includeArchived) {
      query.where((a) => a.deletedAt.isNull());
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
      creditLimit: Value(type == 'credit' ? creditLimit : null),
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

  /// Archivar (soft delete) en cascada: cancela en bloque todos los movimientos
  /// donde la cuenta aparezca como origin o destination (sin importar el kind,
  /// incluidos pagos a tarjeta y transferencias) y después marca la cuenta como
  /// archivada. Es definitivo: ni la cuenta ni los movimientos se reactivan.
  ///
  /// El stateService quedó como parámetro opcional para compatibilidad de
  /// callers; ya no se usa para validar saldo (libreta libre completa).
  Future<void> archive(String id, [FinancialStateService? stateService]) async {
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
        'Ya tenés una cuenta con ese nombre.',
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
    if (creditLimit != null && creditLimit <= 0) {
      throw const AccountsDaoError(
        'invalid_credit_limit',
        'El límite de crédito debe ser mayor a 0.',
      );
    }
  }

}

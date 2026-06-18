import 'package:drift/drift.dart';
import 'package:fincore/data/database.dart';

/// Calcula saldos derivados (BO, DE, CR, saldo por cuenta) sobre la marcha.
/// Usa drift streams: el StreamBuilder solo recibe nuevos valores cuando
/// cambia el contenido de accounts o journal_entries (drift detecta el `readsFrom`).
///
/// Índices en journal_entries (account_origin_id, account_destination_id, deleted_at)
/// garantizan que las SUM agregadas corren en milisegundos incluso con 50k+ entries.
class FinancialStateService {
  final FincoreDatabase _db;
  FinancialStateService(this._db);

  /// Saldo derivado de una cuenta específica.
  ///
  /// - cash/debit: saldo = Σ destination − Σ origin (intuitivo: ingreso suma, gasto resta).
  /// - credit:     saldo = Σ origin − Σ destination (deuda actual; cargos suben, pagos bajan).
  Stream<double> watchAccountBalance(String accountId, String accountType) {
    final isCredit = accountType == 'credit';
    final sql = isCredit
        ? 'SELECT COALESCE(SUM(CASE WHEN account_origin_id = ? THEN amount ELSE 0 END), 0) '
            '- COALESCE(SUM(CASE WHEN account_destination_id = ? THEN amount ELSE 0 END), 0) AS balance '
            'FROM journal_entries WHERE deleted_at IS NULL'
        : 'SELECT COALESCE(SUM(CASE WHEN account_destination_id = ? THEN amount ELSE 0 END), 0) '
            '- COALESCE(SUM(CASE WHEN account_origin_id = ? THEN amount ELSE 0 END), 0) AS balance '
            'FROM journal_entries WHERE deleted_at IS NULL';
    return _db
        .customSelect(
          sql,
          variables: [Variable.withString(accountId), Variable.withString(accountId)],
          readsFrom: {_db.journalEntries},
        )
        .map((row) => row.read<double>('balance'))
        .watchSingle();
  }

  /// Versión sincrónica para validaciones (ej. archive con saldo != 0).
  Future<double> accountBalanceNow(String accountId) async {
    final account = await (_db.select(_db.accounts)
          ..where((a) => a.id.equals(accountId)))
        .getSingleOrNull();
    if (account == null) return 0;
    final isCredit = account.type == 'credit';
    final sql = isCredit
        ? 'SELECT COALESCE(SUM(CASE WHEN account_origin_id = ? THEN amount ELSE 0 END), 0) '
            '- COALESCE(SUM(CASE WHEN account_destination_id = ? THEN amount ELSE 0 END), 0) AS balance '
            'FROM journal_entries WHERE deleted_at IS NULL'
        : 'SELECT COALESCE(SUM(CASE WHEN account_destination_id = ? THEN amount ELSE 0 END), 0) '
            '- COALESCE(SUM(CASE WHEN account_origin_id = ? THEN amount ELSE 0 END), 0) AS balance '
            'FROM journal_entries WHERE deleted_at IS NULL';
    final row = await _db
        .customSelect(
          sql,
          variables: [Variable.withString(accountId), Variable.withString(accountId)],
        )
        .getSingle();
    return row.read<double>('balance');
  }

  /// BO = Σ saldo de cuentas (cash + debit) activas.
  Stream<double> watchBo() {
    const sql = '''
      SELECT COALESCE(SUM(saldo), 0) AS total FROM (
        SELECT a.id,
          (COALESCE((SELECT SUM(amount) FROM journal_entries
                     WHERE account_destination_id = a.id AND deleted_at IS NULL), 0)
          - COALESCE((SELECT SUM(amount) FROM journal_entries
                     WHERE account_origin_id = a.id AND deleted_at IS NULL), 0)) AS saldo
        FROM accounts a
        WHERE a.deleted_at IS NULL AND a.type IN ('cash', 'debit')
      )
    ''';
    return _db
        .customSelect(sql, readsFrom: {_db.accounts, _db.journalEntries})
        .map((row) => row.read<double>('total'))
        .watchSingle();
  }

  /// DE = Σ deuda de cuentas credit activas.
  Stream<double> watchDe() {
    const sql = '''
      SELECT COALESCE(SUM(deuda), 0) AS total FROM (
        SELECT a.id,
          (COALESCE((SELECT SUM(amount) FROM journal_entries
                     WHERE account_origin_id = a.id AND deleted_at IS NULL), 0)
          - COALESCE((SELECT SUM(amount) FROM journal_entries
                     WHERE account_destination_id = a.id AND deleted_at IS NULL), 0)) AS deuda
        FROM accounts a
        WHERE a.deleted_at IS NULL AND a.type = 'credit'
      )
    ''';
    return _db
        .customSelect(sql, readsFrom: {_db.accounts, _db.journalEntries})
        .map((row) => row.read<double>('total'))
        .watchSingle();
  }

  /// CR = Σ (credit_limit − deuda) para cuentas credit activas con credit_limit set.
  Stream<double> watchCr() {
    const sql = '''
      SELECT COALESCE(SUM(libre), 0) AS total FROM (
        SELECT a.id,
          (a.credit_limit
          - (COALESCE((SELECT SUM(amount) FROM journal_entries
                       WHERE account_origin_id = a.id AND deleted_at IS NULL), 0)
            - COALESCE((SELECT SUM(amount) FROM journal_entries
                       WHERE account_destination_id = a.id AND deleted_at IS NULL), 0))) AS libre
        FROM accounts a
        WHERE a.deleted_at IS NULL AND a.type = 'credit' AND a.credit_limit IS NOT NULL
      )
    ''';
    return _db
        .customSelect(sql, readsFrom: {_db.accounts, _db.journalEntries})
        .map((row) => row.read<double>('total'))
        .watchSingle();
  }
}

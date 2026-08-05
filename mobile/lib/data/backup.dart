import 'dart:convert';

import 'package:characters/characters.dart';
import 'package:drift/drift.dart';
import 'package:fincore/constants/category_catalog.dart';
import 'package:fincore/data/daos/loans_dao.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/data/financial_state.dart';
import 'package:fincore/utils/money.dart';

/// Excepción al importar un backup inválido o incompatible.
class BackupError implements Exception {
  final String code;
  final String message;
  const BackupError(this.code, this.message);

  @override
  String toString() => 'BackupError($code): $message';
}

/// Reporte resultado del import: cuántos elementos se insertaron.
///
/// `adjustedAccountsCount` (sprint `flutter-reports-credit-cards-v1`):
/// cantidad de cuentas credit del JSON legacy que traían `credit_limit=null`
/// y fueron ajustadas a 0 al persistir. 0 en la mayoría de imports.
class ImportReport {
  final int accountsCount;
  final int categoriesCount;
  final int entriesCount;
  final int adjustedAccountsCount;
  final DateTime importedAt;

  const ImportReport({
    required this.accountsCount,
    required this.categoriesCount,
    required this.entriesCount,
    this.adjustedAccountsCount = 0,
    required this.importedAt,
  });
}

/// Sprint flutter-loans-v1: bump a v2 con nuevos campos:
///   - `loans` array (opcional en v1, requerido en v2).
///   - `accounts[].archived_at` (nullable, del sprint anterior).
///   - `journal_entries[].loan_id`, `.principal_amount`, `.interest_amount`
///     (opcionales, sólo poblados para income inicial y loan_payment).
///
/// Sprint flutter-integer-cents-v1: bump a v3. Todos los montos se emiten
/// como `int` en **centavos** en vez de `double` en unidades:
///   - `journal_entries[].amount`, `.principal_amount`, `.interest_amount`
///   - `accounts[].credit_limit`, `.minimum_floor`
///   - `loans[].principal_amount`, `.monthly_payment`
///   - `categories[].monthly_limit`
/// Los ratios 0-1 (`interest_rate`, `minimum_payment_pct`,
/// `minimum_capital_pct`) siguen siendo `double` — no son montos (RN-IC-02).
///
/// Ejemplo: `{"amount": 17377}` (v3) donde v2 emitía `{"amount": 173.77}`.
///
/// Sprint flutter-loans-flexible-payments-v1: bump a v4 con la clave
/// `loan_adjustments`. Son ajustes manuales del saldo de un préstamo, dato
/// financiero irrecuperable si se pierde, así que entran al respaldo (a
/// diferencia de `weekly_budgets`, `saved_views` y `app_preferences`, que
/// siguen fuera por decisión de diseño).
///
/// El export SIEMPRE emite v4. El import acepta v1, v2, v3 y v4:
///   - v1/v2 → los montos llegan como `double` y se convierten con
///     `centsFromDouble` (redondeo, nunca truncado).
///   - v3/v4 → los montos llegan como `int` y se usan tal cual. Un `double` en
///     un payload v3+ es un error de formato (`invalid_amount_format`), no se
///     convierte silenciosamente: rompería la invariante "v3+ = enteros".
///   - v1/v2/v3 → sin `loan_adjustments`; se trata como lista vacía y el
///     saldo de cada préstamo queda en la fórmula de dos términos.
///
/// Ruptura hacia atrás: un export v4 NO es importable por 0.33.0 ni
/// anteriores (`unsupported_version`). El respaldo v3 previo es el único
/// punto de retorno hacia esas versiones.
const _supportedVersion = 4;
const _minSupportedVersion = 1;

/// Primera versión del backup que expresa los montos en centavos enteros.
const _firstIntegerCentsVersion = 3;

/// Service de backup JSON v1.
///
/// Formato producido por export y aceptado por import. Compatible 1:1 con
/// el JSON que producía `/api/finance/backup/export` del backend legacy.
///
/// Export: serializa BD activa (sin soft-deleted) a JSON.
/// Import: parsea, valida, ejecuta dentro de transacción que primero borra
/// todo y luego inserta lo importado. Si algo falla, transacción aborta y
/// la BD existente queda intacta.
// Constantes de validación del import (RF-001..RF-006, RN-H01).
// Mantener sincronizadas con las del DAO (`_validKinds` en entries_dao.dart,
// catálogo de slugs en category_catalog.dart). El import valida aquí antes de
// construir el Companion para que payloads corruptos NO toquen la BD.

const Set<String> _validKinds = {
  'income',
  'expense',
  'credit_expense',
  'debt_payment',
  'transfer',
  // Sprint flutter-loans-v1: kind nuevo en journal_entries.
  'loan_payment',
};
const Set<String> _validCloseReasons = {'paid', 'manual'};
const Set<String> _validAccountTypes = {'cash', 'debit', 'credit'};
const Set<String> _validAppliesToTypes = {'income', 'expense', 'both'};

const int _kMaxNameLength = 200;
const int _kMaxDescriptionLength = 1000;

// UUID v4 o v7: octava nibble es 4 o 7; nono nibble alto es 8/9/a/b (RFC 4122
// variant). Aceptamos hex en mayúsculas y minúsculas.
final RegExp _uuidRegex = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[47][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
);

class BackupService {
  final FincoreDatabase _db;
  // Opcional para no romper callers de test; se inyecta desde AppDependencies
  // para que `wipeAll()` y `importFromJson()` puedan limpiar el cache de
  // streams de saldos cuando reemplazan toda la BD (RF-012).
  final FinancialStateService? _state;
  BackupService(this._db, [this._state]);

  Future<String> exportToJson() async {
    final activeAccounts = await (_db.select(_db.accounts)
          ..where((a) => a.deletedAt.isNull()))
        .get();
    final activeCategories = await (_db.select(_db.categories)
          ..where((c) => c.deletedAt.isNull()))
        .get();
    final activeEntries = await (_db.select(_db.journalEntries)
          ..where((e) => e.deletedAt.isNull()))
        .get();
    // Sprint flutter-loans-v1: loans activos + cerrados (no eliminados) se
    // exportan al array `loans` de v2. Los cerrados también se preservan
    // para poder consultar histórico al reimportar.
    final activeLoans = await (_db.select(_db.loans)
          ..where((l) => l.deletedAt.isNull()))
        .get();
    // Sprint flutter-loans-flexible-payments-v1: los ajustes de saldo son
    // parte del estado financiero del préstamo — sin ellos el saldo
    // restaurado sería distinto del que el usuario tenía.
    final allActiveAdjustments = await (_db.select(_db.loanAdjustments)
          ..where((a) => a.deletedAt.isNull()))
        .get();
    // Hallazgo B1 de la revisión de rama (2026-08-05): guardrail defensivo.
    // El import rechaza con `invalid_reference` cualquier ajuste cuyo
    // préstamo no venga en el payload, así que un ajuste huérfano no sólo
    // se pierde: hace que el respaldo ENTERO deje de ser importable, y el
    // usuario se entera al restaurar, no al exportar.
    //
    // La causa raíz (la cascada faltante en `deleteLoan`) ya está corregida,
    // pero este filtro sigue siendo necesario para que las instalaciones que
    // ya generaron huérfanos con la versión defectuosa puedan volver a
    // producir respaldos válidos. Preferimos perder un ajuste que ya no
    // significa nada (su préstamo no existe) antes que emitir un archivo
    // inservible.
    final exportedLoanIds = activeLoans.map((l) => l.id).toSet();
    final activeAdjustments = allActiveAdjustments
        .where((a) => exportedLoanIds.contains(a.loanId))
        .toList();

    // Sprint flutter-weekly-budgets-v1 (RN-B13): las 4 tablas del planeador
    // semanal (weekly_budgets, weekly_budget_items
    // budget_template_items) NO se incluyen en el backup por decisión de
    // diseño (P-001). El usuario acepta perderlas en cada restore.
    final payload = <String, dynamic>{
      'version': _supportedVersion,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'accounts': activeAccounts.map(_accountToJson).toList(),
      'categories': activeCategories.map(_categoryToJson).toList(),
      'journal_entries': activeEntries.map(_entryToJson).toList(),
      'loans': activeLoans.map(_loanToJson).toList(),
      'loan_adjustments':
          activeAdjustments.map(_loanAdjustmentToJson).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Parsea TODO antes de tocar la BD; ejecuta el reemplazo total dentro de
  /// una transacción. Si algo falla, aborta y la BD existente queda intacta.
  Future<ImportReport> importFromJson(String rawJson) async {
    final Map<String, dynamic> payload;
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map<String, dynamic>) {
        throw const BackupError(
          'invalid_json',
          'El archivo no tiene la estructura de un respaldo FinCore.',
        );
      }
      payload = decoded;
    } on FormatException {
      throw const BackupError(
        'invalid_json',
        'El archivo no es un JSON válido.',
      );
    }

    final version = payload['version'];
    if (version is! int) {
      throw const BackupError(
        'invalid_json',
        'Falta el campo "version" en el respaldo.',
      );
    }
    if (version > _supportedVersion) {
      throw BackupError(
        'unsupported_version',
        'Este respaldo es de una versión más nueva (v$version) que esta app puede leer.',
      );
    }
    if (version < _minSupportedVersion) {
      throw BackupError(
        'unsupported_version',
        'Versión de respaldo no soportada (v$version).',
      );
    }
    // v1 y v2 aceptados. v1 = sin loans (loans queda vacío tras el import).
    // v2 = con loans + campos nuevos de journal_entries.

    // Sprint flutter-weekly-budgets-v1: el shape solo se valida para
    // accounts/categories/journal_entries. Si el payload trae además arrays
    // 'weekly_budgets' / 'weekly_budget_items' (backup de un fork o de una
    // versión futura que sí los exporte), se ignoran silenciosamente: no se
    // leen ni se valida su ausencia. No hay allowlist estricta de keys del
    // payload a propósito.
    final accountsRaw = payload['accounts'];
    final categoriesRaw = payload['categories'];
    final entriesRaw = payload['journal_entries'];
    if (accountsRaw is! List ||
        categoriesRaw is! List ||
        entriesRaw is! List) {
      throw const BackupError(
        'invalid_json',
        'Estructura del respaldo incorrecta (faltan accounts/categories/journal_entries).',
      );
    }
    // Sprint flutter-loans-v1: `loans` es opcional en v1 (compat total). En
    // v2 puede venir como array vacío. Si viene como algo distinto de List
    // o ausente, tratamos como vacío en v1 y como error en v2.
    final loansRaw = payload['loans'];
    if (loansRaw != null && loansRaw is! List) {
      throw const BackupError(
        'invalid_json',
        'El campo `loans` debe ser una lista.',
      );
    }
    // Sprint flutter-loans-flexible-payments-v1: `loan_adjustments` es
    // opcional en v1/v2/v3 y en cualquier v4 que venga sin ajustes. Ausente
    // → lista vacía. Presente pero no-List → error de estructura.
    final adjustmentsRaw = payload['loan_adjustments'];
    if (adjustmentsRaw != null && adjustmentsRaw is! List) {
      throw const BackupError(
        'invalid_json',
        'El campo `loan_adjustments` debe ser una lista.',
      );
    }

    // Pre-parseo (lanza si algo inválido) ANTES de tocar la BD.
    // Sprint flutter-reports-credit-cards-v1: `_accountFromJson` retorna un
    // record con el companion y un flag `adjusted` (true cuando el JSON legacy
    // traía `credit_limit=null` y fue ajustado a 0 sin romper el import).
    //
    // Hotfix branch-quality-review (F-SEC-02): envolvemos el parseo entero
    // en try/catch de TypeError. Los casteos `as String`, `as int`, `as num`
    // en los parsers explotan con `_CastError` no tipado cuando el JSON
    // trae `null` o tipo equivocado. El wrapper lo remapea a un `BackupError`
    // amigable en vez de propagar el stack trace a la UI.
    final List<({AccountsCompanion companion, bool adjusted})>
        accountsParsedRaw;
    final List<AccountsCompanion> accountsParsed;
    final int adjustedAccountsCount;
    final List<CategoriesCompanion> categoriesParsed;
    final List<JournalEntriesCompanion> entriesParsed;
    final List<LoansCompanion> loansParsed;
    final List<LoanAdjustmentsCompanion> adjustmentsParsed;
    try {
      accountsParsedRaw = accountsRaw
          .map((e) => _accountFromJson(e as Map<String, dynamic>, version))
          .toList();
      accountsParsed = accountsParsedRaw.map((r) => r.companion).toList();
      adjustedAccountsCount =
          accountsParsedRaw.where((r) => r.adjusted).length;
      categoriesParsed = categoriesRaw
          .map((e) => _categoryFromJson(e as Map<String, dynamic>, version))
          .toList();
      entriesParsed = entriesRaw
          .map((e) => _entryFromJson(e as Map<String, dynamic>, version))
          .toList();
      // Loans se parsean sólo si vienen; en v1 loansRaw==null → lista vacía.
      loansParsed = (loansRaw as List?)
              ?.map((e) => _loanFromJson(e as Map<String, dynamic>, version))
              .toList() ??
          <LoansCompanion>[];
      adjustmentsParsed = (adjustmentsRaw as List?)
              ?.map((e) =>
                  _loanAdjustmentFromJson(e as Map<String, dynamic>, version))
              .toList() ??
          <LoanAdjustmentsCompanion>[];
    } on TypeError catch (e) {
      throw BackupError(
        'invalid_json',
        'El respaldo tiene un campo con tipo inválido: ${e.toString().replaceFirst('type ', '').split('\n').first}',
      );
    }

    // Debe haber al menos una Bolsa (type='cash').
    final hasBolsa = accountsParsed.any((a) => a.type.value == 'cash');
    if (!hasBolsa) {
      throw const BackupError(
        'missing_bolsa',
        'El respaldo no incluye la Bolsa. No se puede importar.',
      );
    }

    // M1 (quality review 2026-06-19): solo una Bolsa singleton + protección
    // exclusiva del tipo cash. Sin esto, dos cuentas protegidas o una cuenta
    // debit/credit con is_protected=true rompen invariantes del Dashboard.
    final protectedAccounts =
        accountsParsed.where((a) => a.isProtected.value).toList();
    if (protectedAccounts.length > 1) {
      throw const BackupError(
        'missing_bolsa',
        'El respaldo tiene más de una cuenta protegida (Bolsa singleton).',
      );
    }
    if (protectedAccounts.any((a) => a.type.value != 'cash')) {
      throw const BackupError(
        'protected_account',
        'Solo una Bolsa (type=cash) puede tener is_protected=true.',
      );
    }

    // Validación de FKs antes de la transacción.
    final accountIds = accountsParsed.map((a) => a.id.value).toSet();
    final categoryIds = categoriesParsed.map((c) => c.id.value).toSet();
    // Sprint flutter-loans-v1: FK check para loans + loan_id de entries.
    final loanIds = loansParsed.map((l) => l.id.value).toSet();
    for (final loan in loansParsed) {
      final dest = loan.destinationAccountId.value;
      if (!accountIds.contains(dest)) {
        throw BackupError(
          'invalid_reference',
          'El préstamo "${loan.name.value}" referencia una cuenta destino que no existe ($dest).',
        );
      }
    }
    // Sprint flutter-loans-flexible-payments-v1: todo ajuste debe apuntar a
    // un préstamo presente en el propio payload. Con `PRAGMA foreign_keys=ON`
    // el insert reventaría igual, pero como `SqliteException` sin tipar: el
    // check explícito da el error de dominio correcto.
    for (final adj in adjustmentsParsed) {
      final target = adj.loanId.value;
      if (!loanIds.contains(target)) {
        throw BackupError(
          'invalid_reference',
          'Un ajuste de saldo referencia un préstamo que no existe ($target).',
        );
      }
    }
    // Hotfix quality-review B4: cada Loan del payload debe tener exactamente
    // 1 income inicial en journal_entries con {kind:'income',
    // loan_id=loan.id, account_destination_id=loan.destination_account_id,
    // amount ≈ loan.principal_amount}. Sin este check, un backup manipulado
    // deja Loans "sin origen contable" y BO/DE reportan saldos inconsistentes
    // sin error tipado. Ojo: los cerrados/eliminados también aplican porque
    // el export sólo emite loans con deleted_at IS NULL.
    for (final loan in loansParsed) {
      final loanId = loan.id.value;
      final expectedDest = loan.destinationAccountId.value;
      final expectedAmount = loan.principalAmount.value;
      final loanIncomes = entriesParsed.where((e) =>
          e.kind.value == 'income' &&
          e.loanId.value == loanId &&
          e.accountDestinationId.value == expectedDest &&
          e.amount.value == expectedAmount);
      if (loanIncomes.isEmpty) {
        throw BackupError(
          'invalid_reference',
          'El préstamo "${loan.name.value}" no tiene un ingreso inicial válido '
          'en journal_entries (kind=income con loan_id, cuenta destino y '
          'principal_amount correspondientes).',
        );
      }
      if (loanIncomes.length > 1) {
        throw BackupError(
          'invalid_reference',
          'El préstamo "${loan.name.value}" tiene múltiples ingresos iniciales '
          '(esperado exactamente 1).',
        );
      }
    }

    for (final entry in entriesParsed) {
      final origin = entry.accountOriginId.value;
      if (origin != null && !accountIds.contains(origin)) {
        throw BackupError(
          'invalid_reference',
          'El respaldo referencia una cuenta origen que no existe ($origin).',
        );
      }
      final dest = entry.accountDestinationId.value;
      if (dest != null && !accountIds.contains(dest)) {
        throw BackupError(
          'invalid_reference',
          'El respaldo referencia una cuenta destino que no existe ($dest).',
        );
      }
      final cat = entry.categoryId.value;
      if (cat != null && !categoryIds.contains(cat)) {
        throw BackupError(
          'invalid_reference',
          'El respaldo referencia una categoría que no existe ($cat).',
        );
      }
      final loanRef = entry.loanId.value;
      if (loanRef != null && !loanIds.contains(loanRef)) {
        throw BackupError(
          'invalid_reference',
          'El movimiento referencia un préstamo que no existe ($loanRef).',
        );
      }
    }

    final importedAt = DateTime.now();

    await _db.transaction(() async {
      // Reemplazo total: borrar TODO físicamente. Single-user, sin tombstones.
      await _wipeTablesInternal();

      // Insertar respetando orden: primero cuentas + categorías, luego loans
      // (que referencian cuentas), después entries (que referencian a los
      // 3 anteriores por sus FKs opcionales).
      await _db.batch((b) {
        b.insertAll(_db.accounts, accountsParsed);
        b.insertAll(_db.categories, categoriesParsed);
        b.insertAll(_db.loans, loansParsed);
        b.insertAll(_db.journalEntries, entriesParsed);
        // Después de `loans`: la FK `loan_adjustments.loan_id` se valida en
        // runtime con `PRAGMA foreign_keys=ON`.
        b.insertAll(_db.loanAdjustments, adjustmentsParsed);
      });
    });
    // Invalidar cache de streams tras reemplazo total (RF-012). Las nuevas
    // suscripciones quedarán contra los datos recién importados.
    _state?.invalidateAll();

    return ImportReport(
      accountsCount: accountsParsed.length,
      categoriesCount: categoriesParsed.length,
      entriesCount: entriesParsed.length,
      adjustedAccountsCount: adjustedAccountsCount,
      importedAt: importedAt,
    );
  }

  /// Borra TODA la BD (cuentas + categorías + movimientos), incluyendo la
  /// Bolsa singleton. Usado para "Reiniciar cuenta" en Settings. El caller es
  /// responsable de mandar al usuario a /first-run para reseed.
  Future<void> wipeAll() async {
    await _db.transaction(_wipeTablesInternal);
    // Invalidar cache de streams DESPUÉS del wipe (RF-012). Si llamamos antes,
    // un nuevo suscriptor podría crear una entrada nueva con el stream viejo.
    _state?.invalidateAll();
  }

  Future<void> _wipeTablesInternal() async {
    // Sprint flutter-weekly-budgets-v1 (RN-B13): las 4 tablas nuevas no van
    // al backup, pero se borran en wipeAll para dejar la BD como recién
    // instalada. Items primero (FK a su parent y, en el caso de los items,
    // a categories) y luego los parents.
    await _db.delete(_db.weeklyBudgetItems).go();
    await _db.delete(_db.weeklyBudgets).go();
    // Sprint flutter-loans-v1: journal_entries → loans → accounts respetando
    // FKs (los entries pueden referenciar loans; loans referencian accounts).
    await _db.delete(_db.journalEntries).go();
    // Sprint flutter-loans-flexible-payments-v1: los ajustes referencian
    // `loans`, así que van ANTES que los préstamos o el delete viola la FK.
    await _db.delete(_db.loanAdjustments).go();
    await _db.delete(_db.loans).go();
    await _db.delete(_db.categories).go();
    await _db.delete(_db.accounts).go();
    // Sprint `flutter-entries-saved-views-v1` (RN-V10): las vistas
    // guardadas son preferencias de UI; al "arrancar limpio" también
    // se borran para mantener coherencia.
    await _db.delete(_db.savedViews).go();
    // Sprint `flutter-onboarding-for-testers-v1` (RN-O04): las
    // preferencias de la app (flag de onboarding, último export) también
    // se resetean — el usuario queda como recién instalado, incluyendo
    // volver a ver el onboarding tras el wipe.
    await _db.delete(_db.appPreferences).go();
  }

  // ===========================================================================
  // Serialización
  // ===========================================================================

  Map<String, dynamic> _accountToJson(Account a) => <String, dynamic>{
        'id': a.id,
        'name': a.name,
        'type': a.type,
        'description': a.description,
        'is_protected': a.isProtected,
        'credit_limit': a.creditLimit,
        'closing_day': a.closingDay,
        'payment_day': a.paymentDay,
        'interest_rate': a.interestRate,
        'minimum_payment_pct': a.minimumPaymentPct,
        // Sprint flutter-accounts-archive-v1: archived_at nullable.
        if (a.archivedAt != null)
          'archived_at': a.archivedAt!.toUtc().toIso8601String(),
        'created_at': a.createdAt.toUtc().toIso8601String(),
        'updated_at': a.updatedAt.toUtc().toIso8601String(),
      };

  Map<String, dynamic> _categoryToJson(Category c) => <String, dynamic>{
        'id': c.id,
        'name': c.name,
        'applies_to': c.appliesTo,
        'color_slug': c.colorSlug,
        'icon_slug': c.iconSlug,
        'monthly_limit': c.monthlyLimit,
        'created_at': c.createdAt.toUtc().toIso8601String(),
        'updated_at': c.updatedAt.toUtc().toIso8601String(),
      };

  Map<String, dynamic> _entryToJson(JournalEntry e) => <String, dynamic>{
        'id': e.id,
        'kind': e.kind,
        'account_origin_id': e.accountOriginId,
        'account_destination_id': e.accountDestinationId,
        'amount': e.amount,
        'description': e.description,
        'occurred_at': e.occurredAt.toUtc().toIso8601String(),
        'category_id': e.categoryId,
        // Sprint flutter-loans-v1: campos nuevos, sólo si aplican.
        if (e.loanId != null) 'loan_id': e.loanId,
        if (e.principalAmount != null) 'principal_amount': e.principalAmount,
        if (e.interestAmount != null) 'interest_amount': e.interestAmount,
        // Hotfix quality-review B1: sin este flag el round-trip convierte
        // TODOS los loan_payment en capital (default 0 del schema) y rompe
        // `watchHasMonthlyPaymentIn` después de cualquier import. Desde
        // flutter-loans-flexible-payments-v1 `is_monthly_payment` ya no
        // gobierna validaciones (RN-LF-03), pero sigue distinguiendo el tipo
        // de pago en el historial y alimentando el chip de próximo pago.
        if (e.kind == 'loan_payment')
          'is_monthly_payment': e.isMonthlyPayment,
        'created_at': e.createdAt.toUtc().toIso8601String(),
        'updated_at': e.updatedAt.toUtc().toIso8601String(),
      };

  /// Sprint flutter-loans-v1: serialización de préstamo. Incluye cerrados
  /// (paid/manual). Los eliminados nunca se exportan (deleted_at IS NULL en
  /// la query de export).
  Map<String, dynamic> _loanToJson(Loan l) => <String, dynamic>{
        'id': l.id,
        'name': l.name,
        'principal_amount': l.principalAmount,
        'monthly_payment': l.monthlyPayment,
        'initial_duration_months': l.initialDurationMonths,
        'current_duration_months': l.currentDurationMonths,
        'payment_day': l.paymentDay,
        'contract_date': l.contractDate.toUtc().toIso8601String(),
        'destination_account_id': l.destinationAccountId,
        if (l.closedAt != null)
          'closed_at': l.closedAt!.toUtc().toIso8601String(),
        if (l.closeReason != null) 'close_reason': l.closeReason,
        'created_at': l.createdAt.toUtc().toIso8601String(),
        'updated_at': l.updatedAt.toUtc().toIso8601String(),
      };

  /// Sprint flutter-loans-flexible-payments-v1: serialización de un ajuste de
  /// saldo. `amount` va con signo (positivo sube la deuda).
  Map<String, dynamic> _loanAdjustmentToJson(LoanAdjustment a) =>
      <String, dynamic>{
        'id': a.id,
        'loan_id': a.loanId,
        'amount': a.amount,
        if (a.reason != null) 'reason': a.reason,
        'occurred_at': a.occurredAt.toUtc().toIso8601String(),
        'created_at': a.createdAt.toUtc().toIso8601String(),
        'updated_at': a.updatedAt.toUtc().toIso8601String(),
      };

  /// Sprint flutter-integer-cents-v1: lee un monto del payload y lo devuelve
  /// en centavos enteros, según la versión del backup.
  ///
  /// - **v3+**: el valor ya viene en centavos. Debe ser `int`; un `double`
  ///   se rechaza con `invalid_amount_format` en vez de convertirse en
  ///   silencio — si un consumidor externo emite `173.77` en un payload v3,
  ///   es un bug suyo y prefiero que sea ruidoso.
  /// - **v1/v2**: el valor viene en unidades como `double`. Se convierte con
  ///   `centsFromDouble`, que redondea (nunca trunca) para recuperar el
  ///   centavo correcto de valores con residuo IEEE 754 (`173.7699999` →
  ///   `17377`).
  ///
  /// Devuelve `null` si el campo está ausente o es null.
  int? _moneyFromJson(String field, Object? raw, int version) {
    if (raw == null) return null;
    if (version >= _firstIntegerCentsVersion) {
      if (raw is int) return raw;
      throw BackupError(
        'invalid_amount_format',
        'El campo "$field" debe ser un entero en centavos en respaldos v$version '
            '(recibido: $raw).',
      );
    }
    if (raw is! num) {
      throw BackupError(
        'invalid_amount_format',
        'El campo "$field" debe ser numérico (recibido: $raw).',
      );
    }
    final asDouble = raw.toDouble();
    if (!asDouble.isFinite) {
      throw BackupError(
        'invalid_amount',
        'El campo "$field" no es un número finito.',
      );
    }
    return centsFromDouble(asDouble);
  }

  ({AccountsCompanion companion, bool adjusted}) _accountFromJson(
      Map<String, dynamic> json, int version) {
    final id = json['id'] as String;
    final name = json['name'] as String;
    final type = json['type'] as String;
    final description = json['description'] as String?;
    final isProtected = (json['is_protected'] as bool?) ?? false;
    var creditLimit = _moneyFromJson('accounts.credit_limit', json['credit_limit'], version);
    final closingDay = json['closing_day'] as int?;
    final paymentDay = json['payment_day'] as int?;
    final interestRate = (json['interest_rate'] as num?)?.toDouble();
    final minimumPaymentPct = (json['minimum_payment_pct'] as num?)?.toDouble();
    _validateUuid('accounts.id', id);
    _validateLength('accounts.name', name, _kMaxNameLength);
    _validateDescription('accounts.description', description);
    if (!_validAccountTypes.contains(type)) {
      throw BackupError(
        'invalid_account_type',
        'El tipo de cuenta no es válido (esperado: cash, debit o credit; recibido: "$type").',
      );
    }
    // Sprint flutter-reports-credit-cards-v1: `credit_limit` es NOT NULL DEFAULT
    // 0 en el schema v5. Se acepta null en JSON legacy (auto-ajuste a 0 con
    // log en `ImportReport.adjustedAccountsCount`). Se acepta 0 como valor
    // válido. Se rechaza < 0.
    var adjusted = false;
    if (type == 'credit') {
      if (creditLimit == null) {
        creditLimit = 0;
        adjusted = true;
      } else if (creditLimit < 0) {
        throw BackupError('invalid_credit_limit',
            'La cuenta de crédito "$name" tiene credit_limit negativo (recibido: $creditLimit).');
      }
      if (closingDay == null || closingDay < 1 || closingDay > 31) {
        throw BackupError('invalid_credit_metadata',
            'La cuenta "$name" debe tener closing_day entre 1 y 31 (recibido: $closingDay).');
      }
      if (paymentDay == null || paymentDay < 1 || paymentDay > 31) {
        throw BackupError('invalid_credit_metadata',
            'La cuenta "$name" debe tener payment_day entre 1 y 31 (recibido: $paymentDay).');
      }
      if (closingDay == paymentDay) {
        throw BackupError('invalid_credit_metadata',
            'La cuenta "$name" no puede tener closing_day == payment_day (ambos = $closingDay).');
      }
    }
    if (interestRate != null && (interestRate < 0 || interestRate > 1)) {
      throw BackupError('invalid_credit_metadata',
          'La cuenta "$name" tiene interest_rate fuera de rango [0, 1] (recibido: $interestRate).');
    }
    if (minimumPaymentPct != null &&
        (minimumPaymentPct < 0 || minimumPaymentPct > 1)) {
      throw BackupError('invalid_credit_metadata',
          'La cuenta "$name" tiene minimum_payment_pct fuera de rango [0, 1] (recibido: $minimumPaymentPct).');
    }
    // Para cuentas non-credit del JSON legacy con credit_limit=null, dejamos
    // que el DEFAULT 0 del schema aplique — no seteamos el campo.
    final companion = AccountsCompanion.insert(
      id: id,
      name: name,
      type: type,
      description: Value(description),
      isProtected: Value(isProtected),
      creditLimit: creditLimit != null
          ? Value(creditLimit)
          : const Value.absent(),
      closingDay: Value(closingDay),
      paymentDay: Value(paymentDay),
      interestRate: Value(interestRate),
      minimumPaymentPct: Value(minimumPaymentPct),
      // Sprint flutter-accounts-archive-v1: archived_at opcional en JSON.
      archivedAt: Value(_parseDate(json['archived_at'])),
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
      updatedAt: _parseDate(json['updated_at']) ?? DateTime.now(),
    );
    return (companion: companion, adjusted: adjusted);
  }

  CategoriesCompanion _categoryFromJson(Map<String, dynamic> json, int version) {
    final id = json['id'] as String;
    final name = json['name'] as String;
    final appliesTo = json['applies_to'] as String;
    final colorSlug = json['color_slug'] as String;
    final iconSlug = json['icon_slug'] as String;
    _validateUuid('categories.id', id);
    _validateLength('categories.name', name, _kMaxNameLength);
    if (!_validAppliesToTypes.contains(appliesTo)) {
      throw BackupError(
        'invalid_applies_to',
        'El campo applies_to no es válido (esperado: income, expense o both; recibido: "$appliesTo").',
      );
    }
    // M2 (quality review 2026-06-19): validar slugs contra catálogo.
    if (!kCategoryColors.any((c) => c.slug == colorSlug)) {
      throw BackupError('invalid_color_slug',
          'La categoría "$name" tiene color_slug fuera del catálogo (recibido: "$colorSlug").');
    }
    if (!kCategoryIcons.any((i) => i.slug == iconSlug)) {
      throw BackupError('invalid_icon_slug',
          'La categoría "$name" tiene icon_slug fuera del catálogo (recibido: "$iconSlug").');
    }
    return CategoriesCompanion.insert(
      id: id,
      name: name,
      appliesTo: appliesTo,
      colorSlug: colorSlug,
      iconSlug: iconSlug,
      monthlyLimit: Value(
          _moneyFromJson('categories.monthly_limit', json['monthly_limit'], version)),
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
      updatedAt: _parseDate(json['updated_at']) ?? DateTime.now(),
    );
  }

  JournalEntriesCompanion _entryFromJson(Map<String, dynamic> json, int version) {
    final id = json['id'] as String;
    final kind = json['kind'] as String;
    final amount = _moneyFromJson('journal_entries.amount', json['amount'], version)!;
    final description = json['description'] as String?;
    final originId = json['account_origin_id'] as String?;
    final destId = json['account_destination_id'] as String?;
    final categoryId = json['category_id'] as String?;
    _validateUuid('journal_entries.id', id);
    if (!_validKinds.contains(kind)) {
      // Hotfix branch-quality-review (F-SEC-06 / L2): mensaje derivado del
      // set para que no se desincronice con futuros kinds nuevos.
      throw BackupError(
        'invalid_kind',
        'El kind del movimiento no es válido '
        '(esperado: ${_validKinds.join(", ")}; recibido: "$kind").',
      );
    }
    // Hotfix branch-quality-review (F-SEC-01): NaN/Infinity en JSON válido
    // (`1e400 → Infinity`) pasarían la guarda `<= 0`. Bloquear antes.
    if (amount <= 0) {
      throw BackupError(
        'invalid_amount',
        'El monto del movimiento debe ser un número finito mayor a 0 (recibido: $amount).',
      );
    }
    _validateDescription('journal_entries.description', description);
    if (originId != null) {
      _validateUuid('journal_entries.account_origin_id', originId);
    }
    if (destId != null) {
      _validateUuid('journal_entries.account_destination_id', destId);
    }
    if (categoryId != null) {
      _validateUuid('journal_entries.category_id', categoryId);
    }
    // Sprint flutter-loans-v1: campos nuevos, opcionales en v1.
    final loanId = json['loan_id'] as String?;
    if (loanId != null) {
      _validateUuid('journal_entries.loan_id', loanId);
    }
    final principalAmount = _moneyFromJson(
        'journal_entries.principal_amount', json['principal_amount'], version);
    final interestAmount = _moneyFromJson(
        'journal_entries.interest_amount', json['interest_amount'], version);
    if (kind == 'loan_payment') {
      // Hotfix branch-quality-review (F-SEC-03): shape check equivalente
      // a `EntriesDao._validateAccountTypes case 'loan_payment'`. Un
      // backup manipulado con {origin=null, dest=credit-uuid, loan_id=X}
      // pasaba el parseo y entraba a BD con RN-011 rota.
      if (originId == null) {
        throw const BackupError(
          'invalid_loan_data',
          'Un loan_payment requiere account_origin_id (cuenta cash o débito).',
        );
      }
      if (destId != null) {
        throw const BackupError(
          'invalid_loan_data',
          'Un loan_payment no lleva account_destination_id.',
        );
      }
      if (loanId == null) {
        throw const BackupError(
          'invalid_loan_data',
          'Un loan_payment debe tener loan_id.',
        );
      }
      if (principalAmount == null || interestAmount == null) {
        throw const BackupError(
          'invalid_loan_data',
          'Un loan_payment debe tener principal_amount e interest_amount.',
        );
      }
      // El guard de NaN/Infinity del hotfix F-SEC-01 se movió a
      // `_moneyFromJson`, que valida `isFinite` sobre el `double` crudo del
      // payload v1/v2 ANTES de convertirlo a centavos. Post-conversión los
      // montos son `int` y la clase de bug no existe.
      if (principalAmount < 0 || interestAmount < 0) {
        throw const BackupError(
          'invalid_loan_split',
          'principal_amount e interest_amount no pueden ser negativos.',
        );
      }
      // Igualdad exacta en centavos (RN-IC-05).
      if (principalAmount + interestAmount != amount) {
        throw const BackupError(
          'invalid_loan_split',
          'La suma principal + interest debe ser igual al amount total.',
        );
      }
    }
    // Hotfix quality-review B1: leer `is_monthly_payment` con default false
    // para backups v1 (no tenían el campo). Es NOT NULL en el schema.
    final isMonthlyPayment =
        (json['is_monthly_payment'] as bool?) ?? false;
    return JournalEntriesCompanion.insert(
      id: id,
      kind: kind,
      accountOriginId: Value(originId),
      accountDestinationId: Value(destId),
      amount: amount,
      description: Value(description),
      occurredAt: _parseDate(json['occurred_at']) ?? DateTime.now(),
      categoryId: Value(categoryId),
      loanId: Value(loanId),
      principalAmount: Value(principalAmount),
      interestAmount: Value(interestAmount),
      isMonthlyPayment: Value(isMonthlyPayment),
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
      updatedAt: _parseDate(json['updated_at']) ?? DateTime.now(),
    );
  }

  /// Sprint flutter-loans-v1: parseo de un préstamo desde JSON v2. Valida
  /// UUID, campos obligatorios y rangos.
  LoansCompanion _loanFromJson(Map<String, dynamic> json, int version) {
    final id = json['id'] as String;
    final name = json['name'] as String;
    final principalAmount =
        _moneyFromJson('loans.principal_amount', json['principal_amount'], version)!;
    final monthlyPayment =
        _moneyFromJson('loans.monthly_payment', json['monthly_payment'], version)!;
    final initialDuration = json['initial_duration_months'] as int;
    final currentDuration = json['current_duration_months'] as int;
    final paymentDay = json['payment_day'] as int;
    final destinationAccountId = json['destination_account_id'] as String;
    final closeReason = json['close_reason'] as String?;
    _validateUuid('loans.id', id);
    _validateLength('loans.name', name, _kMaxNameLength);
    _validateUuid('loans.destination_account_id', destinationAccountId);
    // Hotfix branch-quality-review (F-SEC-01): NaN/Infinity via JSON.
    if (principalAmount <= 0) {
      throw BackupError('invalid_loan_data',
          'El préstamo "$name" tiene principal_amount inválido (esperado número finito > 0, recibido: $principalAmount).');
    }
    if (monthlyPayment <= 0) {
      throw BackupError('invalid_loan_data',
          'El préstamo "$name" tiene monthly_payment inválido (esperado número finito > 0, recibido: $monthlyPayment).');
    }
    if (initialDuration <= 0 || currentDuration < 0) {
      throw BackupError('invalid_loan_data',
          'El préstamo "$name" tiene duración inválida.');
    }
    if (paymentDay < 1 || paymentDay > 28) {
      throw BackupError('invalid_payment_day',
          'El préstamo "$name" tiene payment_day fuera de rango 1-28 (recibido: $paymentDay).');
    }
    if (closeReason != null && !_validCloseReasons.contains(closeReason)) {
      throw BackupError('invalid_loan_data',
          'El préstamo "$name" tiene close_reason inválido (recibido: "$closeReason").');
    }
    return LoansCompanion.insert(
      id: id,
      name: name,
      principalAmount: principalAmount,
      monthlyPayment: monthlyPayment,
      initialDurationMonths: initialDuration,
      currentDurationMonths: currentDuration,
      paymentDay: paymentDay,
      contractDate: _parseDate(json['contract_date']) ?? DateTime.now(),
      destinationAccountId: destinationAccountId,
      closedAt: Value(_parseDate(json['closed_at'])),
      closeReason: Value(closeReason),
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
      updatedAt: _parseDate(json['updated_at']) ?? DateTime.now(),
    );
  }

  /// Sprint flutter-loans-flexible-payments-v1: parseo de un ajuste de saldo.
  ///
  /// El monto se valida contra cero por la misma razón que en el DAO: un
  /// ajuste de cero no significa nada. Sin este check, un payload podría
  /// meter por la puerta trasera un estado que `registerAdjustment` prohíbe.
  ///
  /// NO se valida el signo (un ajuste negativo es legítimo) ni que el saldo
  /// resultante sea positivo: el import es un reemplazo total y el conjunto
  /// de pagos que lo acompaña puede justificar cualquier neto. Esa validación
  /// pertenece a la captura interactiva, no a la restauración.
  LoanAdjustmentsCompanion _loanAdjustmentFromJson(
      Map<String, dynamic> json, int version) {
    final id = json['id'] as String;
    final loanId = json['loan_id'] as String;
    final amount =
        _moneyFromJson('loan_adjustments.amount', json['amount'], version)!;
    final reason = json['reason'] as String?;
    _validateUuid('loan_adjustments.id', id);
    _validateUuid('loan_adjustments.loan_id', loanId);
    if (reason != null) {
      // Hallazgo M1: alineado al límite del DAO (200), no al genérico de
      // descripciones (1000). El import no debe admitir un estado que
      // `registerAdjustment` rechaza.
      _validateLength('loan_adjustments.reason', reason,
          LoansDao.kMaxAdjustmentReasonLength);
    }
    if (amount == 0) {
      throw const BackupError(
        'invalid_amount_format',
        'Un ajuste de saldo no puede ser de cero.',
      );
    }
    return LoanAdjustmentsCompanion.insert(
      id: id,
      loanId: loanId,
      amount: amount,
      reason: Value(reason),
      occurredAt: _parseDate(json['occurred_at']) ?? DateTime.now(),
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
      updatedAt: _parseDate(json['updated_at']) ?? DateTime.now(),
    );
  }

  void _validateUuid(String field, String value) {
    if (!_uuidRegex.hasMatch(value)) {
      // RF-011 del sprint flutter-local-hardening-v2: `substring(0, 16)` opera
      // sobre code units UTF-16. Si llega un emoji o un char multi-byte,
      // partir entre code units puede dejar un surrogate huérfano y romper
      // el snackbar. `characters.take(16)` corta por grapheme clusters.
      final chars = value.characters;
      final preview =
          chars.length <= 16 ? value : '${chars.take(16).toString()}…';
      throw BackupError(
        'invalid_uuid_format',
        'El campo $field tiene un ID inválido (esperado UUID v4 o v7, recibido: "$preview").',
      );
    }
  }

  void _validateLength(String field, String value, int max) {
    if (value.length > max) {
      throw BackupError(
        'string_too_long',
        'El campo $field excede el límite de $max caracteres '
        '(longitud observada: ${value.length}).',
      );
    }
  }

  void _validateDescription(String field, String? value) {
    if (value == null) return;
    _validateLength(field, value, _kMaxDescriptionLength);
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw is! String) return null;
    try {
      return DateTime.parse(raw);
    } on FormatException {
      // B1 (quality review 2026-06-19): un timestamp inválido no debe abortar
      // el import sin error tipado. Lanzamos BackupError para que el wrapper
      // común haga rollback y el snackbar muestre mensaje amigable.
      // RF-011 del sprint flutter-local-hardening-v2: truncado grapheme-safe.
      final chars = raw.characters;
      final preview =
          chars.length <= 32 ? raw : '${chars.take(32).toString()}…';
      throw BackupError(
        'invalid_date_format',
        'El respaldo tiene un timestamp inválido: "$preview".',
      );
    }
  }
}

import 'dart:convert';

import 'package:characters/characters.dart';
import 'package:drift/drift.dart';
import 'package:fincore/constants/category_catalog.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/data/financial_state.dart';

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

const _supportedVersion = 1;

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
};
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
    if (version < _supportedVersion) {
      // Por ahora no hay migración entre versiones; al introducir v2,
      // este bloque manejará upgrades.
      throw BackupError(
        'unsupported_version',
        'Versión de respaldo no soportada (v$version).',
      );
    }

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

    // Pre-parseo (lanza si algo inválido) ANTES de tocar la BD.
    // Sprint flutter-reports-credit-cards-v1: `_accountFromJson` retorna un
    // record con el companion y un flag `adjusted` (true cuando el JSON legacy
    // traía `credit_limit=null` y fue ajustado a 0 sin romper el import).
    final accountsParsedRaw = accountsRaw
        .map((e) => _accountFromJson(e as Map<String, dynamic>))
        .toList();
    final accountsParsed =
        accountsParsedRaw.map((r) => r.companion).toList();
    final adjustedAccountsCount =
        accountsParsedRaw.where((r) => r.adjusted).length;
    final categoriesParsed = categoriesRaw
        .map((e) => _categoryFromJson(e as Map<String, dynamic>))
        .toList();
    final entriesParsed = entriesRaw
        .map((e) => _entryFromJson(e as Map<String, dynamic>))
        .toList();

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
    }

    final importedAt = DateTime.now();

    await _db.transaction(() async {
      // Reemplazo total: borrar TODO físicamente. Single-user, sin tombstones.
      await _wipeTablesInternal();

      // Insertar respetando orden: primero cuentas + categorías, después entries
      // que referencian a las dos.
      await _db.batch((b) {
        b.insertAll(_db.accounts, accountsParsed);
        b.insertAll(_db.categories, categoriesParsed);
        b.insertAll(_db.journalEntries, entriesParsed);
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
    await _db.delete(_db.journalEntries).go();
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
        'created_at': e.createdAt.toUtc().toIso8601String(),
        'updated_at': e.updatedAt.toUtc().toIso8601String(),
      };

  ({AccountsCompanion companion, bool adjusted}) _accountFromJson(
      Map<String, dynamic> json) {
    final id = json['id'] as String;
    final name = json['name'] as String;
    final type = json['type'] as String;
    final description = json['description'] as String?;
    final isProtected = (json['is_protected'] as bool?) ?? false;
    var creditLimit = (json['credit_limit'] as num?)?.toDouble();
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
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
      updatedAt: _parseDate(json['updated_at']) ?? DateTime.now(),
    );
    return (companion: companion, adjusted: adjusted);
  }

  CategoriesCompanion _categoryFromJson(Map<String, dynamic> json) {
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
      monthlyLimit: Value((json['monthly_limit'] as num?)?.toDouble()),
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
      updatedAt: _parseDate(json['updated_at']) ?? DateTime.now(),
    );
  }

  JournalEntriesCompanion _entryFromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final kind = json['kind'] as String;
    final amount = (json['amount'] as num).toDouble();
    final description = json['description'] as String?;
    final originId = json['account_origin_id'] as String?;
    final destId = json['account_destination_id'] as String?;
    final categoryId = json['category_id'] as String?;
    _validateUuid('journal_entries.id', id);
    if (!_validKinds.contains(kind)) {
      throw BackupError(
        'invalid_kind',
        'El kind del movimiento no es válido '
        '(esperado: income, expense, credit_expense, debt_payment o transfer; '
        'recibido: "$kind").',
      );
    }
    if (amount <= 0) {
      throw BackupError(
        'invalid_amount',
        'El monto del movimiento debe ser mayor a 0 (recibido: $amount).',
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
    return JournalEntriesCompanion.insert(
      id: id,
      kind: kind,
      accountOriginId: Value(originId),
      accountDestinationId: Value(destId),
      amount: amount,
      description: Value(description),
      occurredAt: _parseDate(json['occurred_at']) ?? DateTime.now(),
      categoryId: Value(categoryId),
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

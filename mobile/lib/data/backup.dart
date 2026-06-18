import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:fincore/data/database.dart';

/// Excepción al importar un backup inválido o incompatible.
class BackupError implements Exception {
  final String code;
  final String message;
  const BackupError(this.code, this.message);

  @override
  String toString() => 'BackupError($code): $message';
}

/// Reporte resultado del import: cuántos elementos se insertaron.
class ImportReport {
  final int accountsCount;
  final int categoriesCount;
  final int entriesCount;
  final DateTime importedAt;

  const ImportReport({
    required this.accountsCount,
    required this.categoriesCount,
    required this.entriesCount,
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
class BackupService {
  final FincoreDatabase _db;
  BackupService(this._db);

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
    final accountsParsed = accountsRaw
        .map((e) => _accountFromJson(e as Map<String, dynamic>))
        .toList();
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

    return ImportReport(
      accountsCount: accountsParsed.length,
      categoriesCount: categoriesParsed.length,
      entriesCount: entriesParsed.length,
      importedAt: importedAt,
    );
  }

  /// Borra TODA la BD (cuentas + categorías + movimientos), incluyendo la
  /// Bolsa singleton. Usado para "Reiniciar cuenta" en Settings. El caller es
  /// responsable de mandar al usuario a /first-run para reseed.
  Future<void> wipeAll() async {
    await _db.transaction(_wipeTablesInternal);
  }

  Future<void> _wipeTablesInternal() async {
    await _db.delete(_db.journalEntries).go();
    await _db.delete(_db.categories).go();
    await _db.delete(_db.accounts).go();
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

  AccountsCompanion _accountFromJson(Map<String, dynamic> json) {
    return AccountsCompanion.insert(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      description: Value(json['description'] as String?),
      isProtected: Value((json['is_protected'] as bool?) ?? false),
      creditLimit: Value((json['credit_limit'] as num?)?.toDouble()),
      closingDay: Value(json['closing_day'] as int?),
      paymentDay: Value(json['payment_day'] as int?),
      interestRate: Value((json['interest_rate'] as num?)?.toDouble()),
      minimumPaymentPct: Value((json['minimum_payment_pct'] as num?)?.toDouble()),
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
      updatedAt: _parseDate(json['updated_at']) ?? DateTime.now(),
    );
  }

  CategoriesCompanion _categoryFromJson(Map<String, dynamic> json) {
    return CategoriesCompanion.insert(
      id: json['id'] as String,
      name: json['name'] as String,
      appliesTo: json['applies_to'] as String,
      colorSlug: json['color_slug'] as String,
      iconSlug: json['icon_slug'] as String,
      monthlyLimit: Value((json['monthly_limit'] as num?)?.toDouble()),
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
      updatedAt: _parseDate(json['updated_at']) ?? DateTime.now(),
    );
  }

  JournalEntriesCompanion _entryFromJson(Map<String, dynamic> json) {
    return JournalEntriesCompanion.insert(
      id: json['id'] as String,
      kind: json['kind'] as String,
      accountOriginId: Value(json['account_origin_id'] as String?),
      accountDestinationId: Value(json['account_destination_id'] as String?),
      amount: (json['amount'] as num).toDouble(),
      description: Value(json['description'] as String?),
      occurredAt: _parseDate(json['occurred_at']) ?? DateTime.now(),
      categoryId: Value(json['category_id'] as String?),
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
      updatedAt: _parseDate(json['updated_at']) ?? DateTime.now(),
    );
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw is String) return DateTime.parse(raw);
    return null;
  }
}

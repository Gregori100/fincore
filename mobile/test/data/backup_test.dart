import 'dart:convert';

import 'package:drift/native.dart';
import 'package:fincore/data/backup.dart';
import 'package:fincore/data/bootstrap.dart';
import 'package:fincore/data/daos/accounts_dao.dart';
import 'package:fincore/data/daos/categories_dao.dart';
import 'package:fincore/data/daos/entries_dao.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/data/entries_filters.dart';
import 'package:fincore/data/financial_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sqlite_override.dart';

void main() {
  setUpAll(initSqliteOverride);

  late FincoreDatabase db;
  late FinancialStateService state;
  late BackupService backup;
  late AccountsDao accountsDao;
  late CategoriesDao categoriesDao;
  late EntriesDao entriesDao;

  setUp(() async {
    db = FincoreDatabase(NativeDatabase.memory());
    state = FinancialStateService(db);
    accountsDao = AccountsDao(db);
    categoriesDao = CategoriesDao(db);
    entriesDao = EntriesDao(db);
    backup = BackupService(db, state);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seed() async {
    final bolsa = await accountsDao.createBolsa();
    final debit = await accountsDao.create(name: 'Banamex', type: 'debit');
    final cat = await categoriesDao.create(
      name: 'Comida',
      appliesTo: 'expense',
      colorSlug: 'orange',
      iconSlug: 'shopping-cart',
    );
    await entriesDao.registerIncome(
      accountDestinationId: bolsa,
      amount: 100000,
      occurredAt: DateTime.utc(2026, 6, 17, 12, 0, 0, 123),
    );
    await entriesDao.registerExpense(
      accountOriginId: debit,
      amount: 20000,
      occurredAt: DateTime.utc(2026, 6, 17, 13, 30, 0, 456),
      categoryId: cat,
    );
  }

  test('Round-trip: BD con datos → export → wipe → import → contenido idéntico', () async {
    await seed();
    final json1 = await backup.exportToJson();
    final accountsBefore = await accountsDao.listAll();
    final categoriesBefore = await categoriesDao.listAll();
    final entriesBefore = await entriesDao.watchPage().first;

    await backup.importFromJson(json1);

    final accountsAfter = await accountsDao.listAll();
    final categoriesAfter = await categoriesDao.listAll();
    final entriesAfter = await entriesDao.watchPage().first;

    expect(accountsAfter.length, accountsBefore.length);
    expect(categoriesAfter.length, categoriesBefore.length);
    expect(entriesAfter.length, entriesBefore.length);
    // IDs preservados.
    expect(
      accountsAfter.map((a) => a.id).toSet(),
      accountsBefore.map((a) => a.id).toSet(),
    );
    // Subsegundos preservados (gotcha de drift sin store_date_time_values_as_text).
    final occurredAfter = entriesAfter.map((e) => e.entry.occurredAt).toList();
    expect(occurredAfter.any((d) => d.millisecond == 123), isTrue);
    expect(occurredAfter.any((d) => d.millisecond == 456), isTrue);
  });

  test('Import de JSON inválido NO toca la BD existente', () async {
    await seed();
    final before = (await accountsDao.listAll()).length;
    expect(
      () => backup.importFromJson('esto no es JSON{'),
      throwsA(isA<BackupError>().having((e) => e.code, 'code', 'invalid_json')),
    );
    expect((await accountsDao.listAll()).length, before);
  });

  test('Import con version > la soportada rechaza', () async {
    // Sprint flutter-loans-flexible-payments-v1: export emite v4. Cualquier
    // version superior (v5, v99, futura) sigue siendo rechazada con
    // unsupported_version.
    await seed();
    final json = await backup.exportToJson();
    final bumped = json.replaceFirst('"version": 4', '"version": 99');
    expect(
      () => backup.importFromJson(bumped),
      throwsA(isA<BackupError>()
          .having((e) => e.code, 'code', 'unsupported_version')),
    );
  });

  test('Import v1 legacy sigue siendo aceptado (compat total)', () async {
    // Sprint flutter-loans-v1: import de v1 debe seguir funcionando aunque
    // el export ahora sea v2. Un backup v1 sin loans importa OK con loans=[].
    const v1Legacy = '''
{
  "version": 1,
  "exported_at": "2026-07-15T12:00:00.000Z",
  "accounts": [
    {
      "id": "01234567-89ab-7cde-8def-0123456789ab",
      "name": "Bolsa",
      "type": "cash",
      "is_protected": true,
      "credit_limit": 0,
      "created_at": "2026-07-15T12:00:00.000Z",
      "updated_at": "2026-07-15T12:00:00.000Z"
    }
  ],
  "categories": [],
  "journal_entries": []
}
''';
    final report = await backup.importFromJson(v1Legacy);
    expect(report.accountsCount, 1);
  });

  test('Import con accounts vacío rechaza missing_bolsa', () async {
    const empty = '''
{
  "version": 1,
  "exported_at": "2026-06-17T12:00:00.000Z",
  "accounts": [],
  "categories": [],
  "journal_entries": []
}
''';
    expect(
      () => backup.importFromJson(empty),
      throwsA(
          isA<BackupError>().having((e) => e.code, 'code', 'missing_bolsa')),
    );
  });

  test('Import con FK rota rechaza invalid_reference', () async {
    const broken = '''
{
  "version": 1,
  "exported_at": "2026-06-17T12:00:00.000Z",
  "accounts": [
    {
      "id": "01234567-0123-7000-8000-000000000001",
      "name": "Bolsa",
      "type": "cash",
      "description": null,
      "is_protected": true,
      "credit_limit": null,
      "closing_day": null,
      "payment_day": null,
      "interest_rate": null,
      "minimum_payment_pct": null,
      "created_at": "2026-06-17T12:00:00.000Z",
      "updated_at": "2026-06-17T12:00:00.000Z"
    }
  ],
  "categories": [],
  "journal_entries": [
    {
      "id": "01234567-0123-7000-8000-000000000002",
      "kind": "expense",
      "account_origin_id": "00000000-0000-7000-8000-fffffffffff0",
      "account_destination_id": null,
      "amount": 100,
      "description": null,
      "occurred_at": "2026-06-17T12:00:00.000Z",
      "category_id": null,
      "created_at": "2026-06-17T12:00:00.000Z",
      "updated_at": "2026-06-17T12:00:00.000Z"
    }
  ]
}
''';
    expect(
      () => backup.importFromJson(broken),
      throwsA(isA<BackupError>()
          .having((e) => e.code, 'code', 'invalid_reference')),
    );
  });

  test('Round-trip dos veces consecutivas es idempotente', () async {
    await seed();
    final json = await backup.exportToJson();
    await backup.importFromJson(json);
    await backup.importFromJson(json);
    expect((await accountsDao.listAll()).length, 2);
    expect((await categoriesDao.listAll()).length, 1);
    expect((await entriesDao.watchPage().first).length, 2);
  });

  test('Export con BD vacía produce JSON v4 con arrays vacíos', () async {
    await accountsDao.createBolsa(); // mínimo: solo bolsa
    final json = await backup.exportToJson();
    expect(json, contains('"version": 4'));
    expect(json, contains('"loans"'));
    expect(json, contains('"accounts"'));
    expect(json, contains('"categories": []'));
    expect(json, contains('"journal_entries": []'));
  });

  // Validaciones de entrada del import (RF-001..RF-006 + RN-H01 del sprint
  // flutter-local-hardening). El payload base es válido; cada test cambia una
  // sola key para verificar que la validación correspondiente dispara.
  String buildPayload({
    String accountId = '01a2b3c4-5678-7abc-9def-0123456789ab',
    String accountType = 'cash',
    String accountName = 'Bolsa',
    String? accountDescription,
    String categoryId = '01a2b3c4-5678-7abc-9def-0123456789ac',
    String appliesTo = 'expense',
    String categoryName = 'Comida',
    String entryId = '01a2b3c4-5678-7abc-9def-0123456789ad',
    String kind = 'expense',
    double amount = 100,
    String? entryDescription,
  }) {
    String esc(String? s) => s == null ? 'null' : '"$s"';
    return '''
{
  "version": 1,
  "exported_at": "2026-06-18T12:00:00.000Z",
  "accounts": [
    {
      "id": "$accountId",
      "name": "$accountName",
      "type": "$accountType",
      "description": ${esc(accountDescription)},
      "is_protected": true,
      "credit_limit": null,
      "closing_day": null,
      "payment_day": null,
      "interest_rate": null,
      "minimum_payment_pct": null,
      "created_at": "2026-06-18T12:00:00.000Z",
      "updated_at": "2026-06-18T12:00:00.000Z"
    }
  ],
  "categories": [
    {
      "id": "$categoryId",
      "name": "$categoryName",
      "applies_to": "$appliesTo",
      "color_slug": "orange",
      "icon_slug": "shopping-cart",
      "created_at": "2026-06-18T12:00:00.000Z",
      "updated_at": "2026-06-18T12:00:00.000Z"
    }
  ],
  "journal_entries": [
    {
      "id": "$entryId",
      "kind": "$kind",
      "account_origin_id": "$accountId",
      "account_destination_id": null,
      "amount": $amount,
      "description": ${esc(entryDescription)},
      "occurred_at": "2026-06-18T12:00:00.000Z",
      "category_id": "$categoryId",
      "created_at": "2026-06-18T12:00:00.000Z",
      "updated_at": "2026-06-18T12:00:00.000Z"
    }
  ]
}
''';
  }

  test('Import con kind inválido rechaza con invalid_kind', () async {
    expect(
      () => backup.importFromJson(buildPayload(kind: 'hacked')),
      throwsA(isA<BackupError>().having((e) => e.code, 'code', 'invalid_kind')),
    );
  });

  test('Import con type inválido rechaza con invalid_account_type', () async {
    expect(
      () => backup.importFromJson(buildPayload(accountType: 'savings')),
      throwsA(isA<BackupError>()
          .having((e) => e.code, 'code', 'invalid_account_type')),
    );
  });

  test('Import con applies_to inválido rechaza con invalid_applies_to', () async {
    expect(
      () => backup.importFromJson(buildPayload(appliesTo: 'any')),
      throwsA(
          isA<BackupError>().having((e) => e.code, 'code', 'invalid_applies_to')),
    );
  });

  test('Import con amount = 0 rechaza con invalid_amount', () async {
    expect(
      () => backup.importFromJson(buildPayload(amount: 0)),
      throwsA(
          isA<BackupError>().having((e) => e.code, 'code', 'invalid_amount')),
    );
  });

  test('Import con amount < 0 rechaza con invalid_amount', () async {
    expect(
      () => backup.importFromJson(buildPayload(amount: -5000)),
      throwsA(
          isA<BackupError>().having((e) => e.code, 'code', 'invalid_amount')),
    );
  });

  test('Import con name > 200 chars rechaza con string_too_long', () async {
    final huge = 'X' * 201;
    expect(
      () => backup.importFromJson(buildPayload(categoryName: huge)),
      throwsA(
          isA<BackupError>().having((e) => e.code, 'code', 'string_too_long')),
    );
  });

  test('Import con description > 1000 chars rechaza con string_too_long', () async {
    final huge = 'D' * 1001;
    expect(
      () => backup.importFromJson(buildPayload(entryDescription: huge)),
      throwsA(
          isA<BackupError>().having((e) => e.code, 'code', 'string_too_long')),
    );
  });

  test('Import con id no UUID rechaza con invalid_uuid_format', () async {
    expect(
      () => backup.importFromJson(buildPayload(entryId: 'abc')),
      throwsA(isA<BackupError>()
          .having((e) => e.code, 'code', 'invalid_uuid_format')),
    );
  });

  test('Import con UUID v4 válido pasa la validación de formato', () async {
    // v4: 4 en la primera nibble del 3er grupo. El test no espera que importe
    // por completo (necesitaría un payload coherente con la cuenta Bolsa),
    // pero sí que NO falle por invalid_uuid_format antes.
    const v4 = '01a2b3c4-5678-4abc-9def-0123456789ad';
    try {
      await backup.importFromJson(buildPayload(entryId: v4));
    } catch (e) {
      expect(e, isA<BackupError>());
      expect((e as BackupError).code, isNot('invalid_uuid_format'));
    }
  });

  test('Import con timestamp inválido rechaza con invalid_date_format', () async {
    // B1 (quality review 2026-06-19).
    final payload = buildPayload().replaceFirst(
      '"occurred_at": "2026-06-18T12:00:00.000Z"',
      '"occurred_at": "not-a-date"',
    );
    expect(
      () => backup.importFromJson(payload),
      throwsA(isA<BackupError>()
          .having((e) => e.code, 'code', 'invalid_date_format')),
    );
  });

  test('Import con credit_limit <= 0 rechaza con invalid_credit_limit', () async {
    // B3 (quality review 2026-06-19).
    const credit = '''
{
  "version": 1,
  "exported_at": "2026-06-19T12:00:00.000Z",
  "accounts": [
    {
      "id": "01a2b3c4-5678-7abc-9def-0123456789ab",
      "name": "Bolsa",
      "type": "cash",
      "description": null,
      "is_protected": true,
      "credit_limit": null,
      "closing_day": null,
      "payment_day": null,
      "interest_rate": null,
      "minimum_payment_pct": null,
      "created_at": "2026-06-19T12:00:00.000Z",
      "updated_at": "2026-06-19T12:00:00.000Z"
    },
    {
      "id": "01a2b3c4-5678-7abc-9def-0123456789ac",
      "name": "Visa",
      "type": "credit",
      "description": null,
      "is_protected": false,
      "credit_limit": -100,
      "closing_day": 15,
      "payment_day": 5,
      "interest_rate": 0.5,
      "minimum_payment_pct": 0.05,
      "created_at": "2026-06-19T12:00:00.000Z",
      "updated_at": "2026-06-19T12:00:00.000Z"
    }
  ],
  "categories": [],
  "journal_entries": []
}
''';
    expect(
      () => backup.importFromJson(credit),
      throwsA(isA<BackupError>()
          .having((e) => e.code, 'code', 'invalid_credit_limit')),
    );
  });

  test('Import con closing_day fuera de rango rechaza con invalid_credit_metadata',
      () async {
    // B3 (quality review 2026-06-19).
    const badDay = '''
{
  "version": 1,
  "exported_at": "2026-06-19T12:00:00.000Z",
  "accounts": [
    {
      "id": "01a2b3c4-5678-7abc-9def-0123456789ab",
      "name": "Bolsa",
      "type": "cash",
      "description": null,
      "is_protected": true,
      "credit_limit": null,
      "closing_day": null,
      "payment_day": null,
      "interest_rate": null,
      "minimum_payment_pct": null,
      "created_at": "2026-06-19T12:00:00.000Z",
      "updated_at": "2026-06-19T12:00:00.000Z"
    },
    {
      "id": "01a2b3c4-5678-7abc-9def-0123456789ac",
      "name": "Visa",
      "type": "credit",
      "description": null,
      "is_protected": false,
      "credit_limit": 50000,
      "closing_day": 99,
      "payment_day": 5,
      "interest_rate": null,
      "minimum_payment_pct": null,
      "created_at": "2026-06-19T12:00:00.000Z",
      "updated_at": "2026-06-19T12:00:00.000Z"
    }
  ],
  "categories": [],
  "journal_entries": []
}
''';
    expect(
      () => backup.importFromJson(badDay),
      throwsA(isA<BackupError>()
          .having((e) => e.code, 'code', 'invalid_credit_metadata')),
    );
  });

  test('Import con color_slug fuera del catálogo rechaza con invalid_color_slug',
      () async {
    // M2 (quality review 2026-06-19).
    expect(
      () => backup.importFromJson(buildPayload().replaceFirst(
        '"color_slug": "orange"',
        '"color_slug": "magenta_loco"',
      )),
      throwsA(isA<BackupError>()
          .having((e) => e.code, 'code', 'invalid_color_slug')),
    );
  });

  test('Import con dos cuentas protegidas rechaza', () async {
    // M1 (quality review 2026-06-19): Bolsa singleton.
    const twoBolsas = '''
{
  "version": 1,
  "exported_at": "2026-06-19T12:00:00.000Z",
  "accounts": [
    {"id": "01a2b3c4-5678-7abc-9def-000000000001","name": "Bolsa","type": "cash","description": null,"is_protected": true,"credit_limit": null,"closing_day": null,"payment_day": null,"interest_rate": null,"minimum_payment_pct": null,"created_at": "2026-06-19T12:00:00.000Z","updated_at": "2026-06-19T12:00:00.000Z"},
    {"id": "01a2b3c4-5678-7abc-9def-000000000002","name": "Otra Bolsa","type": "cash","description": null,"is_protected": true,"credit_limit": null,"closing_day": null,"payment_day": null,"interest_rate": null,"minimum_payment_pct": null,"created_at": "2026-06-19T12:00:00.000Z","updated_at": "2026-06-19T12:00:00.000Z"}
  ],
  "categories": [],
  "journal_entries": []
}
''';
    expect(
      () => backup.importFromJson(twoBolsas),
      throwsA(isA<BackupError>().having((e) => e.code, 'code', 'missing_bolsa')),
    );
  });

  test('Import con name vacío pasa la validación de longitud', () async {
    // Length 0 cumple <= 200. El DAO rechazaría "" en runtime, pero el import
    // solo valida longitud máxima.
    try {
      await backup.importFromJson(buildPayload(categoryName: ''));
    } catch (e) {
      expect(e, isA<BackupError>());
      expect((e as BackupError).code, isNot('string_too_long'));
    }
  });

  test('Import con name de 200 chars exactos pasa validación de longitud', () async {
    // RF-003 del sprint flutter-local-hardening-v2: el límite es inclusivo
    // (`value.length > max` rechaza). Sin este test, una regresión a `>=`
    // pasaría desapercibida.
    //
    // M3 del quality review v2 (2026-06-19): assert directo sobre el
    // `ImportReport`. El patrón previo (try/catch que solo valida que el
    // código no sea `string_too_long`) daba verde aunque el import lanzara
    // por otro motivo. Acá exigimos que el import complete sin excepción y
    // que efectivamente persista 1 categoría con el nombre boundary.
    final boundary = 'A' * 200;
    final report = await backup.importFromJson(
      buildPayload(categoryName: boundary),
    );
    expect(report.categoriesCount, equals(1));
    final categories = await categoriesDao.listAll();
    expect(categories.single.name, equals(boundary));
    expect(categories.single.name.length, equals(200));
  });

  test('wipeAll vacía las 5 tablas y deja la BD lista para reseed', () async {
    await seed();
    // RN-V10 (sprint flutter-saved-views-polish-v1 / H10 quality review):
    // sembrar también una saved_view para validar que wipeAll la borra.
    await db.savedViewsDao.create(
      name: 'Pre-wipe',
      filters: EntriesFilters.thisMonth(),
    );
    // Sprint `flutter-onboarding-for-testers-v1` (RN-O04): sembrar
    // también una preferencia para validar que wipeAll la borra.
    await db.appPreferencesDao.set('test_pre_wipe', 'true');
    expect((await accountsDao.listAll()).length, greaterThan(0));
    expect((await categoriesDao.listAll()).length, greaterThan(0));
    expect((await entriesDao.watchPage().first).length, greaterThan(0));
    expect((await db.savedViewsDao.listAll()).length, greaterThan(0));
    expect(await db.appPreferencesDao.get('test_pre_wipe'), 'true');

    await backup.wipeAll();

    expect(await accountsDao.listAll(), isEmpty);
    expect(await categoriesDao.listAll(), isEmpty);
    expect(await entriesDao.watchPage().first, isEmpty);
    expect(await db.savedViewsDao.listAll(), isEmpty);
    expect(await db.appPreferencesDao.get('test_pre_wipe'), isNull,
        reason: 'wipeAll debe borrar app_preferences (RN-O04)');
    // Sin Bolsa: hasBolsa = false → router debe redirigir a /first-run.
    expect(await hasBolsa(db), isFalse);
  });

  // Sprint flutter-reports-credit-cards-v1: relajación de validación
  // credit_limit + counter adjustedAccountsCount.
  group('Import — credit_limit (sprint credit-cards)', () {
    const jsonWithNullLimit = '''
{
  "version": 1,
  "exported_at": "2026-06-19T12:00:00.000Z",
  "accounts": [
    {
      "id": "01a2b3c4-5678-7abc-9def-0123456789a1",
      "name": "Bolsa",
      "type": "cash",
      "description": null,
      "is_protected": true,
      "credit_limit": null,
      "closing_day": null,
      "payment_day": null,
      "interest_rate": null,
      "minimum_payment_pct": null,
      "created_at": "2026-06-19T12:00:00.000Z",
      "updated_at": "2026-06-19T12:00:00.000Z"
    },
    {
      "id": "01a2b3c4-5678-7abc-9def-0123456789a2",
      "name": "VisaSinLimite",
      "type": "credit",
      "description": null,
      "is_protected": false,
      "credit_limit": null,
      "closing_day": 15,
      "payment_day": 5,
      "interest_rate": null,
      "minimum_payment_pct": null,
      "created_at": "2026-06-19T12:00:00.000Z",
      "updated_at": "2026-06-19T12:00:00.000Z"
    },
    {
      "id": "01a2b3c4-5678-7abc-9def-0123456789a3",
      "name": "AmexConLimite",
      "type": "credit",
      "description": null,
      "is_protected": false,
      "credit_limit": 30000,
      "closing_day": 10,
      "payment_day": 20,
      "interest_rate": null,
      "minimum_payment_pct": null,
      "created_at": "2026-06-19T12:00:00.000Z",
      "updated_at": "2026-06-19T12:00:00.000Z"
    }
  ],
  "categories": [],
  "journal_entries": []
}
''';

    test('DT-01: credit_limit=null se ajusta a 0 + adjustedAccountsCount', () async {
      final report = await backup.importFromJson(jsonWithNullLimit);
      expect(report.accountsCount, 3);
      expect(report.adjustedAccountsCount, 1,
          reason: 'solo VisaSinLimite tenía credit_limit=null');
      final all = await accountsDao.listAll();
      final visa = all.firstWhere((a) => a.name == 'VisaSinLimite');
      expect(visa.creditLimit, 0);
      final amex = all.firstWhere((a) => a.name == 'AmexConLimite');
      expect(amex.creditLimit, 3000000);
    });

    test('DT-03: credit_limit=0 se acepta (antes rechazado por <=0)', () async {
      const jsonZero = '''
{
  "version": 1,
  "exported_at": "2026-06-19T12:00:00.000Z",
  "accounts": [
    {
      "id": "01a2b3c4-5678-7abc-9def-0123456789b1",
      "name": "Bolsa",
      "type": "cash",
      "description": null,
      "is_protected": true,
      "credit_limit": null,
      "closing_day": null,
      "payment_day": null,
      "interest_rate": null,
      "minimum_payment_pct": null,
      "created_at": "2026-06-19T12:00:00.000Z",
      "updated_at": "2026-06-19T12:00:00.000Z"
    },
    {
      "id": "01a2b3c4-5678-7abc-9def-0123456789b2",
      "name": "Palacio",
      "type": "credit",
      "description": null,
      "is_protected": false,
      "credit_limit": 0,
      "closing_day": 15,
      "payment_day": 5,
      "interest_rate": null,
      "minimum_payment_pct": null,
      "created_at": "2026-06-19T12:00:00.000Z",
      "updated_at": "2026-06-19T12:00:00.000Z"
    }
  ],
  "categories": [],
  "journal_entries": []
}
''';
      final report = await backup.importFromJson(jsonZero);
      expect(report.accountsCount, 2);
      expect(report.adjustedAccountsCount, 0,
          reason: '0 explícito no cuenta como ajuste');
    });

    test('DT-04: sin cuentas credit → adjustedAccountsCount=0', () async {
      const jsonNoCredit = '''
{
  "version": 1,
  "exported_at": "2026-06-19T12:00:00.000Z",
  "accounts": [
    {
      "id": "01a2b3c4-5678-7abc-9def-0123456789c1",
      "name": "Bolsa",
      "type": "cash",
      "description": null,
      "is_protected": true,
      "credit_limit": null,
      "closing_day": null,
      "payment_day": null,
      "interest_rate": null,
      "minimum_payment_pct": null,
      "created_at": "2026-06-19T12:00:00.000Z",
      "updated_at": "2026-06-19T12:00:00.000Z"
    }
  ],
  "categories": [],
  "journal_entries": []
}
''';
      final report = await backup.importFromJson(jsonNoCredit);
      expect(report.accountsCount, 1);
      expect(report.adjustedAccountsCount, 0);
    });

    test('DT-05: round-trip preserva credit_limit (export siempre lo incluye)',
        () async {
      // Sembrar 1 Bolsa + 1 credit + 1 debit.
      await accountsDao.createBolsa();
      await accountsDao.create(
        name: 'AmexRoundTrip',
        type: 'credit',
        creditLimit: 1500000,
        closingDay: 10,
        paymentDay: 20,
      );
      await accountsDao.create(name: 'BanamexRoundTrip', type: 'debit');
      final jsonExported = await backup.exportToJson();
      await backup.wipeAll();
      final report = await backup.importFromJson(jsonExported);
      expect(report.adjustedAccountsCount, 0,
          reason: 'export post-sprint siempre incluye credit_limit → sin ajustes');
      final all = await accountsDao.listAll();
      final amex = all.firstWhere((a) => a.name == 'AmexRoundTrip');
      expect(amex.creditLimit, 1500000);
    });
  });

  // ===========================================================================
  // Sprint flutter-weekly-budgets-v1 (RN-B13), refactor 2026-07-14: las 2
  // tablas del planeador semanal (`weekly_budgets` + `weekly_budget_items`,
  // ya sin las tablas separadas de plantilla — el flag `is_template` vive en
  // `weekly_budgets`) NO viajan en el backup JSON v1, y `wipeAll` (disparado
  // por el reemplazo total del import) las borra. RG-01..RG-04 del test-plan.
  // ===========================================================================
  group('Backup — weekly budgets (RN-B13, sprint flutter-weekly-budgets-v1)',
      () {
    // Sprint flutter-loans-v1: el objeto raíz gana `loans` en v2. Se
    // preserva el invariante de "no leak de weekly_budgets" en el resto de
    // las expectativas del grupo.
    const rootKeys = {
      'version',
      'exported_at',
      'accounts',
      'categories',
      'journal_entries',
      'loans',
      // Sprint flutter-loans-flexible-payments-v1 (backup v4).
      'loan_adjustments',
    };

    test(
        'RG-01: export sin budgets → mismas keys del sprint previo '
        '(sin "weekly_budgets" ni afines)', () async {
      await seed();
      final json = await backup.exportToJson();
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      expect(decoded.keys.toSet(), rootKeys);
      expect(json, isNot(contains('weekly_budgets')));
      expect(json, isNot(contains('weekly_budget_items')));
    });

    test(
        'RG-02: export CON budgets (incluyendo uno marcado como plantilla) '
        '→ tampoco los incluye (mismas keys del objeto raíz)', () async {
      await seed();
      final budgetId = await db.weeklyBudgetsDao.createBudget(
        weekStartDate: DateTime(2026, 7, 17),
        label: 'Presupuesto RG-02',
      );
      await db.weeklyBudgetsDao.addItem(
        budgetId: budgetId,
        name: 'Renta',
        amount: 500000,
        kind: 'expense',
      );
      final templateId = await db.weeklyBudgetsDao.createBudget(
        weekStartDate: DateTime(2026, 7, 24),
        label: 'Plantilla RG-02',
      );
      await db.weeklyBudgetsDao.toggleTemplateFlag(templateId);

      final json = await backup.exportToJson();
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      expect(decoded.keys.toSet(), rootKeys,
          reason: 'el objeto raíz del backup no debe ganar keys nuevas '
              'aunque existan budgets/plantillas activos');
      expect(json, isNot(contains('weekly_budget')));
      expect(json, isNot(contains('Plantilla RG-02')));
      expect(json, isNot(contains('Presupuesto RG-02')));
    });

    test(
        'RG-03: import de JSON v1 legacy sobre BD con budgets activos → '
        'wipeAll los borra (count=0) + data legacy poblada',
        () async {
      // BD "existente" con budgets (uno plantilla) + su propio ledger.
      await seed();
      final budgetId = await db.weeklyBudgetsDao.createBudget(
        weekStartDate: DateTime(2026, 7, 17),
        label: 'Presupuesto pre-import',
      );
      await db.weeklyBudgetsDao.addItem(
        budgetId: budgetId,
        name: 'Renglón pre-import',
        amount: 100000,
        kind: 'expense',
      );
      final templateId = await db.weeklyBudgetsDao.createBudget(
        weekStartDate: DateTime(2026, 7, 24),
        label: 'Plantilla pre-import',
      );
      await db.weeklyBudgetsDao.toggleTemplateFlag(templateId);
      expect((await db.weeklyBudgetsDao.watchAll().first).length, 2);

      // JSON legacy v1 (formato sin conocimiento de budgets, como el de
      // cualquier sprint previo a este).
      final report = await backup.importFromJson(buildPayload());

      expect(report.accountsCount, 1);
      expect(report.categoriesCount, 1);
      expect(report.entriesCount, 1);
      // Las 2 tablas quedan vacías tras el reemplazo total.
      expect(await db.weeklyBudgetsDao.watchAll().first, isEmpty);
      final wbItemsCount = await db
          .customSelect('SELECT COUNT(*) AS c FROM weekly_budget_items',
              readsFrom: const {})
          .getSingle();
      expect(wbItemsCount.data['c'], 0);
      // Data legacy sí quedó poblada.
      final accounts = await accountsDao.listAll();
      expect(accounts, isNotEmpty);
    });

    test(
        'RG-04: import de JSON con array "weekly_budgets" spurio no crashea '
        '→ mismo resultado que RG-03 (se ignora silenciosamente)', () async {
      await seed();
      final budgetId = await db.weeklyBudgetsDao.createBudget(
        weekStartDate: DateTime(2026, 7, 17),
        label: 'Presupuesto pre-import RG-04',
      );
      await db.weeklyBudgetsDao.addItem(
        budgetId: budgetId,
        name: 'Renglón RG-04',
        amount: 20000,
        kind: 'income',
      );
      final templateId = await db.weeklyBudgetsDao.createBudget(
        weekStartDate: DateTime(2026, 7, 24),
        label: 'Plantilla RG-04',
      );
      await db.weeklyBudgetsDao.toggleTemplateFlag(templateId);

      // Payload legacy válido + un array inesperado 'weekly_budgets'.
      final payload = jsonDecode(buildPayload()) as Map<String, dynamic>;
      payload['weekly_budgets'] = [
        {
          'id': 'spurious-id-no-uuid',
          'label': 'No debería leerse',
        }
      ];
      final spuriousJson = jsonEncode(payload);

      final report = await backup.importFromJson(spuriousJson);

      expect(report.accountsCount, 1);
      expect(report.categoriesCount, 1);
      expect(report.entriesCount, 1);
      expect(await db.weeklyBudgetsDao.watchAll().first, isEmpty,
          reason:
              'el array spurio "weekly_budgets" del JSON se ignora; wipeAll '
              'igual borra los budgets pre-existentes');
    });
  });

  // ==========================================================================
  // Sprint flutter-loans-v1 (RN-L18 + hotfix branch-quality-review B6):
  // round-trip real de loans + validaciones de referencia + shape del
  // loan_payment. La cobertura previa (v > 2 rechaza, v1 legacy acepta,
  // export contiene "loans") no verificaba que los datos persistan
  // bit-a-bit ni que las FKs se validaran.
  // ==========================================================================
  group('Backup — loans v2 (hotfix B6)', () {
    test('Round-trip: export v2 con loans + splits → wipe → import → idéntico',
        () async {
      await accountsDao.createBolsa();
      final loanId = await db.loansDao.create(
        name: 'BBVA Round-trip',
        principalAmount: 1500000,
        monthlyPayment: 75000,
        initialDurationMonths: 24,
        paymentDay: 5,
        contractDate: DateTime.utc(2026, 6, 1),
        destinationAccountId: (await accountsDao.listAll())
            .firstWhere((a) => a.type == 'cash')
            .id,
      );
      await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: (await accountsDao.listAll())
            .firstWhere((a) => a.type == 'cash')
            .id,
        amount: 75000,
        principalAmount: 50000,
        interestAmount: 25000,
        occurredAt: DateTime.utc(2026, 7, 5),
        isMonthlyPayment: true,
      );

      final json = await backup.exportToJson();
      await backup.wipeAll();
      await accountsDao.createBolsa(); // Re-seed Bolsa por wipeAll.
      await backup.importFromJson(json);

      final loansAfter = await db.loansDao.watchActive().first;
      expect(loansAfter, hasLength(1));
      expect(loansAfter.first.name, 'BBVA Round-trip');
      expect(loansAfter.first.principalAmount, 1500000);
      expect(loansAfter.first.monthlyPayment, 75000);
      expect(loansAfter.first.paymentDay, 5);
      // Verificar loan_payment reimportado con splits intactos.
      final payments =
          await db.loansDao.watchPayments(loansAfter.first.id).first;
      expect(payments, hasLength(1));
      expect(payments.first.amount, 75000);
      expect(payments.first.principalAmount, 50000);
      expect(payments.first.interestAmount, 25000);
      // Hotfix quality-review B3: la brecha que dejó pasar B1.
      expect(payments.first.isMonthlyPayment, isTrue,
          reason: 'is_monthly_payment DEBE preservarse en el round-trip v2');
    });

    test(
        'Round-trip preserva is_monthly_payment mixto (monthly + capital del mismo mes)',
        () async {
      await accountsDao.createBolsa();
      final bolsaId = (await accountsDao.listAll())
          .firstWhere((a) => a.type == 'cash')
          .id;
      final loanId = await db.loansDao.create(
        name: 'BBVA Mixto',
        principalAmount: 1000000,
        monthlyPayment: 50000,
        initialDurationMonths: 24,
        paymentDay: 5,
        contractDate: DateTime.utc(2026, 6, 1),
        destinationAccountId: bolsaId,
      );
      final monthlyId = await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 50000,
        principalAmount: 40000,
        interestAmount: 10000,
        occurredAt: DateTime.utc(2026, 7, 5),
        isMonthlyPayment: true,
      );
      final capitalId = await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 20000,
        principalAmount: 20000,
        interestAmount: 0,
        occurredAt: DateTime.utc(2026, 7, 20),
        isMonthlyPayment: false,
      );

      final json = await backup.exportToJson();
      await backup.wipeAll();
      await accountsDao.createBolsa();
      await backup.importFromJson(json);

      final monthlyAfter = await entriesDao.findById(monthlyId);
      final capitalAfter = await entriesDao.findById(capitalId);
      expect(monthlyAfter?.entry.isMonthlyPayment, isTrue,
          reason: 'El pago del mes debe seguir siendo monthly');
      expect(capitalAfter?.entry.isMonthlyPayment, isFalse,
          reason: 'El abono a capital debe seguir siendo capital');
    });

    test('Import v1 legacy sin is_monthly_payment: cae a false por default',
        () async {
      // v1 no tenía loan_payment, pero por robustez validamos el default
      // del mapper para cualquier entry sin el flag.
      const jsonV2SinFlag = '''
{
  "version": 2,
  "exported_at": "2026-07-15T12:00:00.000Z",
  "accounts": [
    {
      "id": "01888888-89ab-7cde-8def-000000000001",
      "name": "Bolsa",
      "type": "cash",
      "is_protected": true,
      "credit_limit": 0,
      "created_at": "2026-07-15T12:00:00.000Z",
      "updated_at": "2026-07-15T12:00:00.000Z"
    }
  ],
  "categories": [],
  "loans": [
    {
      "id": "01888888-89ab-7cde-8def-000000000002",
      "name": "Legacy",
      "principal_amount": 1000,
      "monthly_payment": 100,
      "initial_duration_months": 10,
      "current_duration_months": 10,
      "payment_day": 5,
      "contract_date": "2026-06-01T00:00:00.000Z",
      "destination_account_id": "01888888-89ab-7cde-8def-000000000001",
      "created_at": "2026-07-15T12:00:00.000Z",
      "updated_at": "2026-07-15T12:00:00.000Z"
    }
  ],
  "journal_entries": [
    {
      "id": "01888888-89ab-7cde-8def-000000000003",
      "kind": "income",
      "account_destination_id": "01888888-89ab-7cde-8def-000000000001",
      "amount": 1000,
      "occurred_at": "2026-06-01T00:00:00.000Z",
      "loan_id": "01888888-89ab-7cde-8def-000000000002",
      "created_at": "2026-06-01T00:00:00.000Z",
      "updated_at": "2026-06-01T00:00:00.000Z"
    }
  ]
}
''';
      await backup.wipeAll();
      await backup.importFromJson(jsonV2SinFlag);
      final entry = await entriesDao
          .findById('01888888-89ab-7cde-8def-000000000003');
      expect(entry?.entry.isMonthlyPayment, isFalse,
          reason: 'Default false cuando el JSON no trae el flag');
    });

    test('Import v2 con loan.destination_account_id inexistente → invalid_reference',
        () async {
      const badJson = '''
{
  "version": 2,
  "exported_at": "2026-07-15T12:00:00.000Z",
  "accounts": [
    {
      "id": "01234567-89ab-7cde-8def-0123456789ab",
      "name": "Bolsa",
      "type": "cash",
      "is_protected": true,
      "credit_limit": 0,
      "created_at": "2026-07-15T12:00:00.000Z",
      "updated_at": "2026-07-15T12:00:00.000Z"
    }
  ],
  "categories": [],
  "journal_entries": [],
  "loans": [
    {
      "id": "01888888-89ab-7cde-8def-0123456789ab",
      "name": "Ghost Loan",
      "principal_amount": 1000,
      "monthly_payment": 100,
      "initial_duration_months": 12,
      "current_duration_months": 12,
      "payment_day": 5,
      "contract_date": "2026-07-15T12:00:00.000Z",
      "destination_account_id": "01ffffff-89ab-7cde-8def-0123456789ab",
      "created_at": "2026-07-15T12:00:00.000Z",
      "updated_at": "2026-07-15T12:00:00.000Z"
    }
  ]
}
''';
      expect(
        () => backup.importFromJson(badJson),
        throwsA(isA<BackupError>()
            .having((e) => e.code, 'code', 'invalid_reference')),
      );
    });

    test('Import v2 con journal_entries[].loan_id inexistente → invalid_reference',
        () async {
      const badJson = '''
{
  "version": 2,
  "exported_at": "2026-07-15T12:00:00.000Z",
  "accounts": [
    {
      "id": "01234567-89ab-7cde-8def-0123456789ab",
      "name": "Bolsa",
      "type": "cash",
      "is_protected": true,
      "credit_limit": 0,
      "created_at": "2026-07-15T12:00:00.000Z",
      "updated_at": "2026-07-15T12:00:00.000Z"
    }
  ],
  "categories": [],
  "journal_entries": [
    {
      "id": "01aaaaaa-89ab-7cde-8def-0123456789ab",
      "kind": "loan_payment",
      "account_origin_id": "01234567-89ab-7cde-8def-0123456789ab",
      "account_destination_id": null,
      "amount": 500,
      "occurred_at": "2026-07-15T12:00:00.000Z",
      "loan_id": "01ffffff-89ab-7cde-8def-0123456789ab",
      "principal_amount": 400,
      "interest_amount": 100,
      "created_at": "2026-07-15T12:00:00.000Z",
      "updated_at": "2026-07-15T12:00:00.000Z"
    }
  ],
  "loans": []
}
''';
      expect(
        () => backup.importFromJson(badJson),
        throwsA(isA<BackupError>()
            .having((e) => e.code, 'code', 'invalid_reference')),
      );
    });

    test('Import v2 con close_reason inválido → invalid_loan_data', () async {
      const badJson = '''
{
  "version": 2,
  "exported_at": "2026-07-15T12:00:00.000Z",
  "accounts": [
    {
      "id": "01234567-89ab-7cde-8def-0123456789ab",
      "name": "Bolsa",
      "type": "cash",
      "is_protected": true,
      "credit_limit": 0,
      "created_at": "2026-07-15T12:00:00.000Z",
      "updated_at": "2026-07-15T12:00:00.000Z"
    }
  ],
  "categories": [],
  "journal_entries": [],
  "loans": [
    {
      "id": "01888888-89ab-7cde-8def-0123456789ab",
      "name": "Bad State",
      "principal_amount": 1000,
      "monthly_payment": 100,
      "initial_duration_months": 12,
      "current_duration_months": 12,
      "payment_day": 5,
      "contract_date": "2026-07-15T12:00:00.000Z",
      "destination_account_id": "01234567-89ab-7cde-8def-0123456789ab",
      "closed_at": "2026-08-01T12:00:00.000Z",
      "close_reason": "cancelled_by_user",
      "created_at": "2026-07-15T12:00:00.000Z",
      "updated_at": "2026-07-15T12:00:00.000Z"
    }
  ]
}
''';
      expect(
        () => backup.importFromJson(badJson),
        throwsA(isA<BackupError>()
            .having((e) => e.code, 'code', 'invalid_loan_data')),
      );
    });

    test(
        'Import v2 con loan_payment que tiene destination_account_id (violación shape) → invalid_loan_data',
        () async {
      // Hotfix F-SEC-03: bloquear entries corruptos donde loan_payment
      // tiene destino a una cuenta.
      const badJson = '''
{
  "version": 2,
  "exported_at": "2026-07-15T12:00:00.000Z",
  "accounts": [
    {
      "id": "01234567-89ab-7cde-8def-0123456789ab",
      "name": "Bolsa",
      "type": "cash",
      "is_protected": true,
      "credit_limit": 0,
      "created_at": "2026-07-15T12:00:00.000Z",
      "updated_at": "2026-07-15T12:00:00.000Z"
    },
    {
      "id": "01cccccc-89ab-7cde-8def-0123456789ab",
      "name": "Tarjeta Fantasma",
      "type": "credit",
      "credit_limit": 5000,
      "closing_day": 15,
      "payment_day": 5,
      "created_at": "2026-07-15T12:00:00.000Z",
      "updated_at": "2026-07-15T12:00:00.000Z"
    }
  ],
  "categories": [],
  "journal_entries": [
    {
      "id": "01aaaaaa-89ab-7cde-8def-0123456789ab",
      "kind": "loan_payment",
      "account_origin_id": "01234567-89ab-7cde-8def-0123456789ab",
      "account_destination_id": "01cccccc-89ab-7cde-8def-0123456789ab",
      "amount": 500,
      "occurred_at": "2026-07-15T12:00:00.000Z",
      "loan_id": "01888888-89ab-7cde-8def-0123456789ab",
      "principal_amount": 400,
      "interest_amount": 100,
      "created_at": "2026-07-15T12:00:00.000Z",
      "updated_at": "2026-07-15T12:00:00.000Z"
    }
  ],
  "loans": [
    {
      "id": "01888888-89ab-7cde-8def-0123456789ab",
      "name": "Legit",
      "principal_amount": 1000,
      "monthly_payment": 100,
      "initial_duration_months": 12,
      "current_duration_months": 12,
      "payment_day": 5,
      "contract_date": "2026-07-15T12:00:00.000Z",
      "destination_account_id": "01234567-89ab-7cde-8def-0123456789ab",
      "created_at": "2026-07-15T12:00:00.000Z",
      "updated_at": "2026-07-15T12:00:00.000Z"
    }
  ]
}
''';
      expect(
        () => backup.importFromJson(badJson),
        throwsA(isA<BackupError>()
            .having((e) => e.code, 'code', 'invalid_loan_data')),
      );
    });
  });

  // ==========================================================================
  // Sprint flutter-loans-flexible-payments-v1 — backup v4 con loan_adjustments
  // ==========================================================================

  group('backup v4: loan_adjustments', () {
    /// Préstamo + un pago + dos ajustes de signo opuesto.
    Future<String> seedLoanConAjustes() async {
      final bolsa = await accountsDao.createBolsa();
      final loanId = await db.loansDao.create(
        name: 'BBVA',
        principalAmount: 3700000,
        monthlyPayment: 250000,
        initialDurationMonths: 24,
        paymentDay: 5,
        contractDate: DateTime.utc(2026, 5, 1),
        destinationAccountId: bolsa,
      );
      await db.entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsa,
        amount: 250000,
        principalAmount: 210000,
        interestAmount: 40000,
        occurredAt: DateTime.utc(2026, 6, 5),
        isMonthlyPayment: true,
      );
      await db.loansDao.registerAdjustment(
        loanId: loanId,
        amount: 10000,
        occurredAt: DateTime.utc(2026, 8, 5),
        reason: 'Ajuste del banco',
      );
      await db.loansDao.registerAdjustment(
        loanId: loanId,
        amount: -5000,
        occurredAt: DateTime.utc(2026, 8, 10),
      );
      return loanId;
    }

    test('IT-LF-01: el export declara v4 y trae los ajustes', () async {
      await seedLoanConAjustes();
      final json = await backup.exportToJson();
      final decoded = jsonDecode(json) as Map<String, dynamic>;

      expect(decoded['version'], 4);
      final adjustments = decoded['loan_adjustments'] as List;
      expect(adjustments, hasLength(2));
      // Montos con signo, en centavos enteros (RN-IC-01).
      final amounts = adjustments.map((a) => a['amount']).toList();
      expect(amounts, containsAll(<int>[10000, -5000]));
      expect(amounts.every((a) => a is int), isTrue);
      expect(adjustments.first['reason'], isNotNull);
    });

    test('IT-LF-02: sin ajustes la clave existe y viene vacía (CB-15)',
        () async {
      await seed();
      final decoded =
          jsonDecode(await backup.exportToJson()) as Map<String, dynamic>;
      expect(decoded.containsKey('loan_adjustments'), isTrue);
      expect(decoded['loan_adjustments'], isEmpty);
    });

    test(
        'IT-LF-03: round-trip export → wipe → import conserva saldo y ajustes',
        () async {
      final loanId = await seedLoanConAjustes();
      final saldoAntes = await db.loansDao.balanceOf(loanId);
      // 3700000 + 10000 - 5000 - 210000.
      expect(saldoAntes, 3495000);

      final json = await backup.exportToJson();
      await backup.wipeAll();
      await backup.importFromJson(json);

      final loans = await db.loansDao.watchActive().first;
      expect(loans, hasLength(1));
      final restored = loans.first.id;
      expect(await db.loansDao.watchAdjustments(restored).first, hasLength(2));
      expect(await db.loansDao.balanceOf(restored), saldoAntes);
    });

    test('IT-LF-04: un backup v3 importa sin ajustes (CA-12)', () async {
      final loanId = await seedLoanConAjustes();
      final v4 = await backup.exportToJson();
      // Degradar el payload a v3: quitar la clave y bajar la versión.
      final decoded = jsonDecode(v4) as Map<String, dynamic>;
      decoded['version'] = 3;
      decoded.remove('loan_adjustments');

      await backup.wipeAll();
      await backup.importFromJson(jsonEncode(decoded));

      final loans = await db.loansDao.watchActive().first;
      final restored = loans.first.id;
      expect(await db.loansDao.watchAdjustments(restored).first, isEmpty);
      // Saldo por la fórmula de dos términos: 3700000 - 210000.
      expect(await db.loansDao.balanceOf(restored), 3490000);
      expect(loanId, isNotEmpty);
    });

    test('IT-LF-06: v4 sin la clave loan_adjustments se trata como vacío',
        () async {
      await seedLoanConAjustes();
      final decoded =
          jsonDecode(await backup.exportToJson()) as Map<String, dynamic>;
      decoded.remove('loan_adjustments');
      await backup.wipeAll();
      // No debe crashear: la clave es opcional incluso en v4.
      await backup.importFromJson(jsonEncode(decoded));
      final loans = await db.loansDao.watchActive().first;
      expect(await db.loansDao.watchAdjustments(loans.first.id).first, isEmpty);
    });

    test('IT-LF-07: un ajuste con loan_id inexistente rechaza', () async {
      await seedLoanConAjustes();
      final decoded =
          jsonDecode(await backup.exportToJson()) as Map<String, dynamic>;
      (decoded['loan_adjustments'] as List).first['loan_id'] =
          '01999999-89ab-7cde-8def-0123456789ab';
      expect(
        () => backup.importFromJson(jsonEncode(decoded)),
        throwsA(isA<BackupError>()
            .having((e) => e.code, 'code', 'invalid_reference')),
      );
    });

    test('IT-LF-08: un ajuste con amount double rechaza en v4', () async {
      await seedLoanConAjustes();
      final decoded =
          jsonDecode(await backup.exportToJson()) as Map<String, dynamic>;
      (decoded['loan_adjustments'] as List).first['amount'] = 100.5;
      expect(
        () => backup.importFromJson(jsonEncode(decoded)),
        throwsA(isA<BackupError>()
            .having((e) => e.code, 'code', 'invalid_amount_format')),
      );
    });

    test('IT-LF-09: un ajuste con amount 0 rechaza (CB-18)', () async {
      await seedLoanConAjustes();
      final decoded =
          jsonDecode(await backup.exportToJson()) as Map<String, dynamic>;
      (decoded['loan_adjustments'] as List).first['amount'] = 0;
      expect(
        () => backup.importFromJson(jsonEncode(decoded)),
        throwsA(isA<BackupError>()
            .having((e) => e.code, 'code', 'invalid_amount_format')),
      );
    });

    test('loan_adjustments con tipo no-List rechaza con invalid_json',
        () async {
      await seedLoanConAjustes();
      final decoded =
          jsonDecode(await backup.exportToJson()) as Map<String, dynamic>;
      decoded['loan_adjustments'] = 'no soy una lista';
      expect(
        () => backup.importFromJson(jsonEncode(decoded)),
        throwsA(
            isA<BackupError>().having((e) => e.code, 'code', 'invalid_json')),
      );
    });

    test('wipeAll borra los ajustes sin violar la FK contra loans', () async {
      await seedLoanConAjustes();
      await backup.wipeAll();
      final rows =
          await db.customSelect('SELECT COUNT(*) AS c FROM loan_adjustments')
              .getSingle();
      expect(rows.read<int>('c'), 0);
    });

    test(
        'B1: el respaldo de una BD con un préstamo eliminado que tenía '
        'ajustes SIGUE siendo importable', () async {
      // Regresión del hallazgo bloqueante de la revisión de rama. Antes de
      // la corrección, el export emitía el ajuste huérfano (su propio
      // `deleted_at` seguía nulo) pero omitía el préstamo, y el import
      // rechazaba el archivo ENTERO con `invalid_reference`. El usuario no
      // se enteraba al exportar sino al intentar restaurar.
      final loanId = await seedLoanConAjustes();
      await db.loansDao.deleteLoan(loanId);

      final json = await backup.exportToJson();
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      expect(decoded['loans'], isEmpty);
      expect(decoded['loan_adjustments'], isEmpty,
          reason: 'los ajustes del préstamo eliminado no deben exportarse');

      // Y el archivo se importa sin error.
      await backup.importFromJson(json);
      expect(await db.loansDao.watchActive().first, isEmpty);
    });

    test(
        'B1: el guardrail del export filtra huérfanos aunque la cascada no '
        'los haya marcado', () async {
      // Simula una BD generada por la versión con el bug: el préstamo está
      // eliminado pero sus ajustes siguen activos. El export debe producir
      // igualmente un archivo importable, para que quien ya tenga ese estado
      // pueda recuperar respaldos válidos.
      final loanId = await seedLoanConAjustes();
      final nowIso = DateTime.now().toIso8601String();
      // Reproduce EXACTAMENTE lo que hacía `deleteLoan` antes del fix:
      // cascadeaba el préstamo y sus movimientos, pero no los ajustes.
      await db.customStatement(
        'UPDATE loans SET deleted_at = ? WHERE id = ?', [nowIso, loanId]);
      await db.customStatement(
        'UPDATE journal_entries SET deleted_at = ? WHERE loan_id = ?',
        [nowIso, loanId]);
      final huerfanos = await db.select(db.loanAdjustments).get();
      expect(huerfanos.every((a) => a.deletedAt == null), isTrue,
          reason: 'precondición: ajustes activos con préstamo eliminado');

      final json = await backup.exportToJson();
      expect((jsonDecode(json) as Map<String, dynamic>)['loan_adjustments'],
          isEmpty);
      await backup.importFromJson(json);
    });

    test('M1: un motivo de más de 200 caracteres rechaza el import',
        () async {
      await seedLoanConAjustes();
      final decoded =
          jsonDecode(await backup.exportToJson()) as Map<String, dynamic>;
      (decoded['loan_adjustments'] as List).first['reason'] = 'x' * 201;
      expect(
        () => backup.importFromJson(jsonEncode(decoded)),
        throwsA(isA<BackupError>()),
        reason: 'el import no debe admitir un estado que el DAO rechaza',
      );
    });
  });
}

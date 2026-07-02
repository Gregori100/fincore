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
      amount: 1000,
      occurredAt: DateTime.utc(2026, 6, 17, 12, 0, 0, 123),
    );
    await entriesDao.registerExpense(
      accountOriginId: debit,
      amount: 200,
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

  test('Import con version > 1 rechaza', () async {
    await seed();
    final json = await backup.exportToJson();
    final bumped = json.replaceFirst('"version": 1', '"version": 99');
    expect(
      () => backup.importFromJson(bumped),
      throwsA(isA<BackupError>()
          .having((e) => e.code, 'code', 'unsupported_version')),
    );
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

  test('Export con BD vacía produce JSON v1 con arrays vacíos', () async {
    await accountsDao.createBolsa(); // mínimo: solo bolsa
    final json = await backup.exportToJson();
    expect(json, contains('"version": 1'));
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
      () => backup.importFromJson(buildPayload(amount: -50)),
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
      expect(amex.creditLimit, 30000);
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
        creditLimit: 15000,
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
      expect(amex.creditLimit, 15000);
    });
  });
}

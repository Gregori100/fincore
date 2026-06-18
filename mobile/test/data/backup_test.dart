import 'package:drift/native.dart';
import 'package:fincore/data/backup.dart';
import 'package:fincore/data/bootstrap.dart';
import 'package:fincore/data/daos/accounts_dao.dart';
import 'package:fincore/data/daos/categories_dao.dart';
import 'package:fincore/data/daos/entries_dao.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/data/financial_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sqlite_override.dart';

void main() {
  setUpAll(initSqliteOverride);

  late FincoreDatabase db;
  late BackupService backup;
  late AccountsDao accountsDao;
  late CategoriesDao categoriesDao;
  late EntriesDao entriesDao;

  setUp(() async {
    db = FincoreDatabase(NativeDatabase.memory());
    final state = FinancialStateService(db);
    accountsDao = AccountsDao(db);
    categoriesDao = CategoriesDao(db);
    entriesDao = EntriesDao(db, state);
    backup = BackupService(db);
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
      "account_origin_id": "ID-INEXISTENTE",
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

  test('wipeAll vacía las 3 tablas y deja la BD lista para reseed', () async {
    await seed();
    expect((await accountsDao.listAll()).length, greaterThan(0));
    expect((await categoriesDao.listAll()).length, greaterThan(0));
    expect((await entriesDao.watchPage().first).length, greaterThan(0));

    await backup.wipeAll();

    expect(await accountsDao.listAll(), isEmpty);
    expect(await categoriesDao.listAll(), isEmpty);
    expect(await entriesDao.watchPage().first, isEmpty);
    // Sin Bolsa: hasBolsa = false → router debe redirigir a /first-run.
    expect(await hasBolsa(db), isFalse);
  });
}

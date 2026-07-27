import 'package:drift/native.dart';
import 'package:fincore/data/category_suggestion.dart';
import 'package:fincore/data/daos/accounts_dao.dart';
import 'package:fincore/data/daos/categories_dao.dart';
import 'package:fincore/data/daos/entries_dao.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/data/seed.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sqlite_override.dart';

/// Tests del `CategorySuggestionService` **algoritmo v2** post uso real.
/// Sprint `flutter-entries-category-suggestion-v1` v2.
///
/// El algoritmo v2 se simplificó a un único criterio (match por substring
/// de descripción). Eliminados los pasos de monto+cuenta y "más usada"
/// del v1 — ver `clarificaciones.md` v2 para el racional.
void main() {
  setUpAll(initSqliteOverride);

  late FincoreDatabase db;
  late AccountsDao accountsDao;
  late CategoriesDao categoriesDao;
  late EntriesDao entriesDao;
  late CategorySuggestionService service;

  late String bolsa;
  late String debit;
  late String credit;
  late String catComida; // expense
  late String catCafe; // expense
  late String catTransporte; // expense
  late String catSalario; // income
  late String catMisc; // both
  late String catOld; // expense, archivada en tests que lo necesitan

  setUp(() async {
    db = FincoreDatabase(NativeDatabase.memory());
    accountsDao = AccountsDao(db);
    categoriesDao = CategoriesDao(db);
    entriesDao = EntriesDao(db);
    service = CategorySuggestionService(db);

    await seedDefaults(
      db: db,
      accountsDao: accountsDao,
      categoriesDao: categoriesDao,
    );

    bolsa = (await accountsDao.listAll())
        .firstWhere((a) => a.type == 'cash')
        .id;
    debit = await accountsDao.create(name: 'Banamex_T', type: 'debit');
    credit = await accountsDao.create(
      name: 'Visa_T',
      type: 'credit',
      creditLimit: 5000000,
    );

    catComida = await categoriesDao.create(
      name: 'Comida_T',
      appliesTo: 'expense',
      colorSlug: 'red',
      iconSlug: 'restaurant',
    );
    catCafe = await categoriesDao.create(
      name: 'Cafe_T',
      appliesTo: 'expense',
      colorSlug: 'orange',
      iconSlug: 'local-cafe',
    );
    catTransporte = await categoriesDao.create(
      name: 'Transporte_T',
      appliesTo: 'expense',
      colorSlug: 'blue',
      iconSlug: 'directions-car',
    );
    catSalario = await categoriesDao.create(
      name: 'Salario_T',
      appliesTo: 'income',
      colorSlug: 'green',
      iconSlug: 'savings',
    );
    catMisc = await categoriesDao.create(
      name: 'Misc_T',
      appliesTo: 'both',
      colorSlug: 'gray',
      iconSlug: 'tag',
    );
    catOld = await categoriesDao.create(
      name: 'Old_T',
      appliesTo: 'expense',
      colorSlug: 'gray',
      iconSlug: 'tag',
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('CategorySuggestionService — match exacto (caso base)', () {
    test('UT-01: BD sin entries → null', () async {
      final result = await service.suggestForNewEntry(
        kind: 'expense',
        description: 'Café',
      );
      expect(result, isNull);
    });

    test('UT-02: match exacto retorna la categoría del entry histórico',
        () async {
      await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 5000,
        occurredAt: DateTime(2026, 5, 10),
        description: 'Café',
        categoryId: catCafe,
      );
      final result = await service.suggestForNewEntry(
        kind: 'expense',
        description: 'Café',
      );
      expect(result, catCafe);
    });

    test('UT-03: normaliza espacios y mayúsculas ASCII', () async {
      await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 5000,
        occurredAt: DateTime(2026, 5, 10),
        description: 'cafe',
        categoryId: catCafe,
      );
      final result = await service.suggestForNewEntry(
        kind: 'expense',
        description: '  CAFE  ',
      );
      expect(result, catCafe);
    });

    test('UT-04: ignora categorías archivadas (sin fallback en v2)',
        () async {
      await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 20000,
        occurredAt: DateTime(2026, 6, 10),
        description: 'Genérico',
        categoryId: catOld,
      );
      await categoriesDao.archive(catOld);
      // v1 antes caía al paso 3; v2 NO tiene fallback → debe retornar null.
      final result = await service.suggestForNewEntry(
        kind: 'expense',
        description: 'Genérico',
      );
      expect(result, isNull,
          reason:
              'sin paso 3, categoría archivada significa "sin sugerencia"');
    });

    test('UT-05: ignora applies_to incompatible (income vs expense)',
        () async {
      await entriesDao.registerIncome(
        accountDestinationId: bolsa,
        amount: 500000,
        occurredAt: DateTime(2026, 5, 10),
        description: 'Salario',
        categoryId: catSalario,
      );
      // catSalario tiene applies_to='income' → no compatible con expense.
      final result = await service.suggestForNewEntry(
        kind: 'expense',
        description: 'Salario',
      );
      expect(result, isNull);
    });

    test('UT-06: kind=income retorna categoría con applies_to=income',
        () async {
      await entriesDao.registerIncome(
        accountDestinationId: bolsa,
        amount: 500000,
        occurredAt: DateTime(2026, 6, 10),
        description: 'Salario MGT',
        categoryId: catSalario,
      );
      final result = await service.suggestForNewEntry(
        kind: 'income',
        description: 'Salario MGT',
      );
      expect(result, catSalario);
    });
  });

  group('CategorySuggestionService — substring (caso de Diego)', () {
    test(
        'UT-07: "Café para mi novia" matchea histórico "Café"',
        () async {
      await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 5000,
        occurredAt: DateTime(2026, 5, 10),
        description: 'Café',
        categoryId: catCafe,
      );
      final result = await service.suggestForNewEntry(
        kind: 'expense',
        description: 'Café para mi novia',
      );
      expect(result, catCafe);
    });

    test(
        'UT-08: "Café del amigo Juan" también matchea histórico "Café"',
        () async {
      await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 5000,
        occurredAt: DateTime(2026, 5, 10),
        description: 'Café',
        categoryId: catCafe,
      );
      final result = await service.suggestForNewEntry(
        kind: 'expense',
        description: 'Café del amigo Juan',
      );
      expect(result, catCafe);
    });

    test(
        'UT-09: substring también funciona en medio de la descripción',
        () async {
      await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 5000,
        occurredAt: DateTime(2026, 5, 10),
        description: 'pizza',
        categoryId: catComida,
      );
      // "Compré pizza" contiene "pizza" → matchea.
      final result = await service.suggestForNewEntry(
        kind: 'expense',
        description: 'Compré pizza ayer',
      );
      expect(result, catComida);
    });

    test(
        'UT-10: histórico <3 chars no matchea (filtro defensivo)',
        () async {
      // Si el histórico es "ok", LENGTH(ok)=2 → excluido.
      // "Sin él, cualquier descripción nueva que contenga 'ok' (e.g.
      // "Compré ok") matchearía spuriamente.
      await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 5000,
        occurredAt: DateTime(2026, 5, 10),
        description: 'ok',
        categoryId: catComida,
      );
      final result = await service.suggestForNewEntry(
        kind: 'expense',
        description: 'Compré ok',
      );
      expect(result, isNull,
          reason: 'descripción histórica <3 chars no participa');
    });

    test(
        'UT-11: tipeo nuevo <3 chars no matchea (corto-circuito)',
        () async {
      await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 5000,
        occurredAt: DateTime(2026, 5, 10),
        description: 'Café',
        categoryId: catCafe,
      );
      final result = await service.suggestForNewEntry(
        kind: 'expense',
        description: 'Ca',
      );
      expect(result, isNull,
          reason: 'tipeo <3 chars retorna null sin tocar BD');
    });

    test(
        'UT-12 (rama bidireccional): "fisca" matchea histórico "fiscal" '
        '(histórica contiene nueva)',
        () async {
      // Caso real reportado por Diego: histórico tiene descripción
      // "fiscal" (categoría Salario). Al tipear "fisca" (5 chars,
      // prefijo), debería matchear porque la histórica contiene la
      // nueva. Sin esto el match solo funcionaba al terminar de
      // escribir.
      await entriesDao.registerIncome(
        accountDestinationId: bolsa,
        amount: 500000,
        occurredAt: DateTime(2026, 5, 10),
        description: 'fiscal',
        categoryId: catSalario,
      );
      final result = await service.suggestForNewEntry(
        kind: 'income',
        description: 'fisca',
      );
      expect(result, catSalario);
    });

    test(
        'UT-13: múltiples matches retorna el más reciente',
        () async {
      await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 5000,
        occurredAt: DateTime(2026, 5, 10),
        description: 'Café',
        categoryId: catCafe,
      );
      // Mismo substring "Café" pero con otra categoría más reciente.
      await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 6000,
        occurredAt: DateTime(2026, 6, 1),
        description: 'Café',
        categoryId: catMisc,
      );
      final result = await service.suggestForNewEntry(
        kind: 'expense',
        description: 'Café para Juan',
      );
      expect(result, catMisc,
          reason: 'el match más reciente gana (ORDER BY occurred_at DESC)');
    });
  });

  group('CategorySuggestionService — edge cases', () {
    test('UT-14: description null o empty retorna null', () async {
      final r1 = await service.suggestForNewEntry(
        kind: 'expense',
        description: null,
      );
      expect(r1, isNull);
      final r2 = await service.suggestForNewEntry(
        kind: 'expense',
        description: '',
      );
      expect(r2, isNull);
      final r3 = await service.suggestForNewEntry(
        kind: 'expense',
        description: '   ',
      );
      expect(r3, isNull);
    });

    test('UT-15: entry con category_id=null no aparece (INNER JOIN)',
        () async {
      await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 5000,
        occurredAt: DateTime(2026, 6, 10),
        description: 'Pan',
        categoryId: null,
      );
      final result = await service.suggestForNewEntry(
        kind: 'expense',
        description: 'Pan integral',
      );
      expect(result, isNull);
    });

    test('UT-16: soft-deleted entry no contribuye', () async {
      await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 5000,
        occurredAt: DateTime(2026, 6, 10),
        description: 'Café',
        categoryId: catCafe,
      );
      final entries = await entriesDao.watchPage().first;
      await entriesDao.cancel(entries.first.entry.id);
      final result = await service.suggestForNewEntry(
        kind: 'expense',
        description: 'Café',
      );
      expect(result, isNull);
    });

    test(
        'UT-17: kinds no soportados (transfer, debt_payment) retornan null sin tocar BD',
        () async {
      final r1 = await service.suggestForNewEntry(
        kind: 'transfer',
        description: 'Cualquier cosa con más de 3 chars',
      );
      expect(r1, isNull);
      final r2 = await service.suggestForNewEntry(
        kind: 'debt_payment',
        description: 'Otra descripción válida',
      );
      expect(r2, isNull);
    });

    test('UT-18: credit_expense usa applies_to=expense compatibility',
        () async {
      // Histórico credit_expense con categoría both.
      await entriesDao.registerCreditExpense(
        accountOriginId: credit,
        amount: 35000,
        occurredAt: DateTime(2026, 6, 10),
        description: 'Compra online',
        categoryId: catMisc,
      );
      final result = await service.suggestForNewEntry(
        kind: 'credit_expense',
        description: 'Compra online del lunes',
      );
      expect(result, catMisc);
    });

    test(
        'UT-19: histórico tiene la misma descripción pero archivada → null (sin fallback)',
        () async {
      // El único entry con match tiene categoría archivada.
      await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 10000,
        occurredAt: DateTime(2026, 6, 10),
        description: 'Compras varias',
        categoryId: catOld,
      );
      // También sembrar otro entry expense (sin descripción matcheable)
      // para confirmar que el v2 NO cae a "más usada".
      await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 6000,
        occurredAt: DateTime(2026, 6, 12),
        categoryId: catTransporte,
      );
      await categoriesDao.archive(catOld);
      final result = await service.suggestForNewEntry(
        kind: 'expense',
        description: 'Compras varias del finde',
      );
      expect(result, isNull,
          reason: 'v2 sin paso 3: no hay fallback estadístico');
    });
  });
}

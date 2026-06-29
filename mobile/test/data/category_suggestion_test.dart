import 'package:drift/native.dart';
import 'package:fincore/data/category_suggestion.dart';
import 'package:fincore/data/daos/accounts_dao.dart';
import 'package:fincore/data/daos/categories_dao.dart';
import 'package:fincore/data/daos/entries_dao.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/data/seed.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sqlite_override.dart';

/// Tests del `CategorySuggestionService`. Sprint
/// `flutter-entries-category-suggestion-v1`.
///
/// Cubre la cascada de 3 pasos (RN-S03) + edge cases del test-plan
/// (CB-D01..CB-D17 de la spec).
void main() {
  setUpAll(initSqliteOverride);

  late FincoreDatabase db;
  late AccountsDao accountsDao;
  late CategoriesDao categoriesDao;
  late EntriesDao entriesDao;
  late CategorySuggestionService service;

  // Datos seedeados en setUp.
  late String bolsa;
  late String debit;
  late String credit;
  late String catComida; // expense
  late String catCafe; // expense
  late String catTransporte; // expense
  late String catSalario; // income
  late String catMisc; // both
  late String catOld; // expense, archivada antes de los tests

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
      creditLimit: 50000,
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
    // NO archivar en setUp: algunos tests necesitan registrar entries
    // con catOld antes de archivarla. Cada test que la usa hace
    // `categoriesDao.archive(catOld)` después de sembrar.
  });

  tearDown(() async {
    await db.close();
  });

  group('CategorySuggestionService — cascada paso 1 (descripción)', () {
    test('UT-01: BD sin entries → null', () async {
      final result = await service.suggestForNewEntry(
        kind: 'expense',
        accountId: debit,
        description: 'Café',
        amount: 100,
        now: DateTime(2026, 6, 20),
      );
      expect(result, isNull);
    });

    test('UT-02: paso 1 match exacto', () async {
      await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 50,
        occurredAt: DateTime(2026, 5, 10),
        description: 'Café',
        categoryId: catCafe,
      );
      final result = await service.suggestForNewEntry(
        kind: 'expense',
        accountId: debit,
        description: 'Café',
        amount: null,
        now: DateTime(2026, 6, 20),
      );
      expect(result, catCafe);
    });

    test('UT-03: paso 1 normaliza espacios y mayúsculas ASCII', () async {
      await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 50,
        occurredAt: DateTime(2026, 5, 10),
        description: 'cafe',
        categoryId: catCafe,
      );
      final result = await service.suggestForNewEntry(
        kind: 'expense',
        accountId: debit,
        description: '  CAFE  ',
        amount: null,
        now: DateTime(2026, 6, 20),
      );
      expect(result, catCafe);
    });

    test(
        'UT-04: paso 1 ignora categorías archivadas y baja al paso 3 (más usada)',
        () async {
      // Histórico match descripción con categoría que SERÁ archivada.
      await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 200,
        occurredAt: DateTime(2026, 6, 10),
        description: 'Genérico',
        categoryId: catOld,
      );
      // Más usada reciente para fallback: 2 entries de Comida.
      await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 80,
        occurredAt: DateTime(2026, 6, 12),
        categoryId: catComida,
      );
      await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 90,
        occurredAt: DateTime(2026, 6, 14),
        categoryId: catComida,
      );
      // Archivar catOld DESPUÉS de sembrar (`registerExpense` rechaza
      // categoría archivada).
      await categoriesDao.archive(catOld);
      final result = await service.suggestForNewEntry(
        kind: 'expense',
        accountId: debit,
        description: 'Genérico',
        amount: null,
        now: DateTime(2026, 6, 20),
      );
      expect(result, catComida,
          reason: 'paso 1 falla por archivada; paso 3 retorna la más usada');
    });

    test(
        'UT-05: paso 1 ignora applies_to incompatible (income vs expense)',
        () async {
      // Histórico income con descripción "Salario" y categoría income.
      await entriesDao.registerIncome(
        accountDestinationId: bolsa,
        amount: 5000,
        occurredAt: DateTime(2026, 5, 10),
        description: 'Salario',
        categoryId: catSalario,
      );
      // Query con kind=expense → catSalario tiene applies_to='income', no compatible.
      final result = await service.suggestForNewEntry(
        kind: 'expense',
        accountId: debit,
        description: 'Salario',
        amount: null,
        now: DateTime(2026, 6, 20),
      );
      expect(result, isNull);
    });
  });

  group('CategorySuggestionService — cascada paso 2 (monto+cuenta)', () {
    test('UT-06: paso 2 match monto + cuenta + kind reciente', () async {
      await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 1500,
        occurredAt: DateTime(2026, 6, 10),
        categoryId: catTransporte,
      );
      final result = await service.suggestForNewEntry(
        kind: 'expense',
        accountId: debit,
        description: null,
        amount: 1500,
        now: DateTime(2026, 6, 20),
      );
      expect(result, catTransporte);
    });

    test('UT-07: paso 2 ignora entries fuera de 90 días', () async {
      // Entry a 91 días atrás: 2026-03-21 con now=2026-06-20.
      await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 1500,
        occurredAt: DateTime(2026, 3, 21),
        categoryId: catTransporte,
      );
      final result = await service.suggestForNewEntry(
        kind: 'expense',
        accountId: debit,
        description: null,
        amount: 1500,
        now: DateTime(2026, 6, 20),
      );
      expect(result, isNull);
    });

    test(
        'UT-08: kind=income usa account_destination_id, no account_origin_id',
        () async {
      // Histórico income → destino bolsa.
      await entriesDao.registerIncome(
        accountDestinationId: bolsa,
        amount: 5000,
        occurredAt: DateTime(2026, 6, 10),
        categoryId: catSalario,
      );
      // Para sugerir income con accountId=bolsa, debería matchear paso 2.
      final result = await service.suggestForNewEntry(
        kind: 'income',
        accountId: bolsa,
        description: null,
        amount: 5000,
        now: DateTime(2026, 6, 20),
      );
      expect(result, catSalario);
      // Sanity check: si pasamos accountId=debit (cuenta sin entries
      // income destinados a ella), no debería matchear.
      final result2 = await service.suggestForNewEntry(
        kind: 'income',
        accountId: debit,
        description: null,
        amount: 5000,
        now: DateTime(2026, 6, 20),
      );
      expect(result2, isNull);
    });
  });

  group('CategorySuggestionService — cascada paso 3 (más usada)', () {
    test('UT-09: más usada por kind+cuenta últimos 30 días', () async {
      // 3 Comida vs 1 Transporte → Comida gana.
      for (var i = 1; i <= 3; i++) {
        await entriesDao.registerExpense(
          accountOriginId: debit,
          amount: 100 * i.toDouble(),
          occurredAt: DateTime(2026, 6, i + 5),
          categoryId: catComida,
        );
      }
      await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 500,
        occurredAt: DateTime(2026, 6, 15),
        categoryId: catTransporte,
      );
      final result = await service.suggestForNewEntry(
        kind: 'expense',
        accountId: debit,
        description: null,
        amount: null,
        now: DateTime(2026, 6, 20),
      );
      expect(result, catComida);
    });

    test('UT-10: tiebreak en paso 3 por MAX(occurred_at) DESC', () async {
      // 2 Comida vs 2 Transporte → empate en count.
      // Comida más reciente: 2026-06-15.
      // Transporte más reciente: 2026-06-17 → debería ganar.
      await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 100,
        occurredAt: DateTime(2026, 6, 10),
        categoryId: catComida,
      );
      await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 100,
        occurredAt: DateTime(2026, 6, 15),
        categoryId: catComida,
      );
      await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 200,
        occurredAt: DateTime(2026, 6, 12),
        categoryId: catTransporte,
      );
      await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 200,
        occurredAt: DateTime(2026, 6, 17),
        categoryId: catTransporte,
      );
      final result = await service.suggestForNewEntry(
        kind: 'expense',
        accountId: debit,
        description: null,
        amount: null,
        now: DateTime(2026, 6, 20),
      );
      expect(result, catTransporte);
    });
  });

  group('CategorySuggestionService — short-circuits y edge cases', () {
    test('UT-11: cascada sin matches retorna null', () async {
      // Sembrar un credit_expense (cuenta credit) con datos que no
      // coinciden con la query: kind distinto, distinta cuenta, fuera
      // de ventanas.
      await entriesDao.registerCreditExpense(
        accountOriginId: credit,
        amount: 999,
        occurredAt: DateTime(2026, 1, 1),
        categoryId: catMisc,
      );
      final result = await service.suggestForNewEntry(
        kind: 'expense',
        accountId: debit, // distinta cuenta
        description: 'Cualquier',
        amount: 100,
        now: DateTime(2026, 6, 20),
      );
      expect(result, isNull);
    });

    test('UT-12: accountId null saltea pasos 2 y 3', () async {
      // Solo el paso 1 debería evaluarse. Sembrar match descripción.
      await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 50,
        occurredAt: DateTime(2026, 6, 10),
        description: 'Pan',
        categoryId: catComida,
      );
      final result = await service.suggestForNewEntry(
        kind: 'expense',
        accountId: null,
        description: 'Pan',
        amount: 50,
        now: DateTime(2026, 6, 20),
      );
      expect(result, catComida);
      // Sin descripción matcheable y accountId null, debe ser null.
      final result2 = await service.suggestForNewEntry(
        kind: 'expense',
        accountId: null,
        description: null,
        amount: 50,
        now: DateTime(2026, 6, 20),
      );
      expect(result2, isNull);
    });

    test('UT-13: description null/empty saltea paso 1', () async {
      // Sin entries históricos → cascada cae a null. Solo verificamos
      // que no crashea con description null o empty.
      final r1 = await service.suggestForNewEntry(
        kind: 'expense',
        accountId: debit,
        description: null,
        amount: 100,
        now: DateTime(2026, 6, 20),
      );
      expect(r1, isNull);
      final r2 = await service.suggestForNewEntry(
        kind: 'expense',
        accountId: debit,
        description: '   ',
        amount: 100,
        now: DateTime(2026, 6, 20),
      );
      expect(r2, isNull);
    });

    test('UT-14: amount null/0 saltea paso 2', () async {
      // Sembrar match en paso 3 (más usada): catTransporte.
      await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 200,
        occurredAt: DateTime(2026, 6, 10),
        categoryId: catTransporte,
      );
      // Con amount=0 debería saltar paso 2 y caer al paso 3.
      final r1 = await service.suggestForNewEntry(
        kind: 'expense',
        accountId: debit,
        description: null,
        amount: 0,
        now: DateTime(2026, 6, 20),
      );
      expect(r1, catTransporte);
      // Con amount=null mismo comportamiento.
      final r2 = await service.suggestForNewEntry(
        kind: 'expense',
        accountId: debit,
        description: null,
        amount: null,
        now: DateTime(2026, 6, 20),
      );
      expect(r2, catTransporte);
    });

    test('UT-15: now inyectable: paso 3 respeta ventana 30 días', () async {
      // Entry a 31 días atrás de now = 2026-04-19 con now=2026-05-20.
      // 30 días atrás de 2026-05-20 es 2026-04-20. Entry de 2026-04-19
      // queda fuera → no contribuye al paso 3.
      await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 100,
        occurredAt: DateTime(2026, 4, 19),
        categoryId: catComida,
      );
      final result = await service.suggestForNewEntry(
        kind: 'expense',
        accountId: debit,
        description: null,
        amount: null,
        now: DateTime(2026, 5, 20),
      );
      expect(result, isNull);
      // Mover el entry a 2026-04-21 → dentro de ventana → contribuye.
      // Reset por simpleza: agregar otro entry dentro de ventana.
      await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 100,
        occurredAt: DateTime(2026, 4, 25),
        categoryId: catComida,
      );
      final result2 = await service.suggestForNewEntry(
        kind: 'expense',
        accountId: debit,
        description: null,
        amount: null,
        now: DateTime(2026, 5, 20),
      );
      expect(result2, catComida);
    });

    test('UT-16: soft-deleted entry no contribuye a ningún paso',
        () async {
      // Entry con match descripción.
      await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 50,
        occurredAt: DateTime(2026, 6, 10),
        description: 'Café',
        categoryId: catCafe,
      );
      // Soft-delete.
      final entries = await entriesDao.watchPage().first;
      await entriesDao.cancel(entries.first.entry.id);
      final result = await service.suggestForNewEntry(
        kind: 'expense',
        accountId: debit,
        description: 'Café',
        amount: null,
        now: DateTime(2026, 6, 20),
      );
      expect(result, isNull);
    });
  });

  group('CategorySuggestionService — cobertura quality review v1', () {
    test(
        'UT-19 (CB-D05): paso 1 con múltiples matches retorna el más reciente',
        () async {
      // Dos entries con misma descripción pero categorías distintas.
      // El SQL hace ORDER BY occurred_at DESC LIMIT 1 → más reciente gana.
      await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 100,
        occurredAt: DateTime(2026, 5, 10),
        description: 'Restaurante',
        categoryId: catComida,
      );
      await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 120,
        occurredAt: DateTime(2026, 6, 1),
        description: 'Restaurante',
        categoryId: catMisc,
      );
      final result = await service.suggestForNewEntry(
        kind: 'expense',
        accountId: debit,
        description: 'Restaurante',
        amount: null,
        now: DateTime(2026, 6, 20),
      );
      expect(result, catMisc,
          reason: 'el match más reciente (2026-06-01) debe ganar');
    });

    test(
        'UT-20 (CB-D06): entry con category_id=null no aparece como sugerencia',
        () async {
      // Entry sin categoría con descripción que matchea → el INNER JOIN
      // con `categories` lo excluye porque c.id sería null.
      await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 100,
        occurredAt: DateTime(2026, 6, 10),
        description: 'Sin categoría',
        categoryId: null,
      );
      final result = await service.suggestForNewEntry(
        kind: 'expense',
        accountId: debit,
        description: 'Sin categoría',
        amount: null,
        now: DateTime(2026, 6, 20),
      );
      expect(result, isNull,
          reason: 'entries sin categoría no contribuyen a la cascada');
    });

    test(
        'UT-21 (CB-D08): paso 3 con ventana sin entries en últimos 30 días → null',
        () async {
      // Entry a 35 días atrás (fuera de la ventana de 30 días del paso 3).
      // Sin descripción matcheable y sin amount → solo el paso 3 puede
      // disparar, y debe retornar null por ventana vacía.
      await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 100,
        occurredAt: DateTime(2026, 5, 15),
        categoryId: catComida,
      );
      final result = await service.suggestForNewEntry(
        kind: 'expense',
        accountId: debit,
        description: null,
        amount: null,
        now: DateTime(2026, 6, 20),
      );
      expect(result, isNull,
          reason: 'ningún entry en últimos 30 días → paso 3 retorna null');
    });
  });

  group('CategorySuggestionService — otros kinds', () {
    test('UT-17: kind no sugerido (transfer/debt_payment) retorna null sin tocar BD',
        () async {
      final r1 = await service.suggestForNewEntry(
        kind: 'transfer',
        accountId: debit,
        description: 'X',
        amount: 100,
        now: DateTime(2026, 6, 20),
      );
      expect(r1, isNull);
      final r2 = await service.suggestForNewEntry(
        kind: 'debt_payment',
        accountId: debit,
        description: 'X',
        amount: 100,
        now: DateTime(2026, 6, 20),
      );
      expect(r2, isNull);
    });

    test(
        'UT-18: kind=credit_expense usa account_origin_id (la tarjeta) como cuenta relevante',
        () async {
      // credit_expense desde tarjeta de crédito.
      await entriesDao.registerCreditExpense(
        accountOriginId: credit,
        amount: 350,
        occurredAt: DateTime(2026, 6, 10),
        description: 'Compra online',
        categoryId: catMisc,
      );
      // Sugerencia paso 1 con misma descripción y kind credit_expense.
      // catMisc tiene applies_to='both' → compatible con credit_expense.
      final result = await service.suggestForNewEntry(
        kind: 'credit_expense',
        accountId: credit,
        description: 'Compra online',
        amount: null,
        now: DateTime(2026, 6, 20),
      );
      expect(result, catMisc);
    });
  });
}

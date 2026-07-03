import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:fincore/data/daos/accounts_dao.dart';
import 'package:fincore/data/daos/categories_dao.dart';
import 'package:fincore/data/daos/entries_dao.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/data/financial_state.dart';
import 'package:fincore/data/seed.dart';
import 'package:fincore/data/uuid.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/factories.dart';
import '../helpers/sqlite_override.dart';

void main() {
  setUpAll(initSqliteOverride);

  late FincoreDatabase db;
  late AccountsDao accountsDao;
  late CategoriesDao categoriesDao;
  late EntriesDao entriesDao;
  late FinancialStateService stateService;

  setUp(() {
    db = FincoreDatabase(NativeDatabase.memory());
    stateService = FinancialStateService(db);
    accountsDao = AccountsDao(db);
    categoriesDao = CategoriesDao(db);
    entriesDao = EntriesDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Schema', () {
    test('arranca con tablas vacías', () async {
      expect(await accountsDao.listAll(), isEmpty);
      expect(await categoriesDao.listAll(), isEmpty);
      final entries = await entriesDao.watchPage().first;
      expect(entries, isEmpty);
    });

    test('PRAGMA foreign_keys está activo (constraint se enforza)', () async {
      // Insertar entry con FK inválida debe fallar.
      expect(
        () async => await db.into(db.journalEntries).insert(
              JournalEntriesCompanion.insert(
                id: UuidV7.generate(),
                kind: 'expense',
                accountOriginId: const Value('uuid-inexistente'),
                amount: 100,
                occurredAt: DateTime.now(),
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
    });
  });

  group('AccountsDao', () {
    test('createBolsa crea cash singleton e is idempotente', () async {
      final id1 = await accountsDao.createBolsa();
      final id2 = await accountsDao.createBolsa();
      expect(id1, id2);
      final all = await accountsDao.listAll();
      expect(all.length, 1);
      expect(all.first.type, 'cash');
      expect(all.first.isProtected, isTrue);
    });

    test('create rechaza type=cash', () async {
      expect(
        () => accountsDao.create(name: 'X', type: 'cash'),
        throwsA(isA<AccountsDaoError>()
            .having((e) => e.code, 'code', 'invalid_account_type')),
      );
    });

    test('create rechaza nombre duplicado entre activas', () async {
      await accountsDao.create(name: 'Banamex', type: 'debit');
      expect(
        () => accountsDao.create(name: 'Banamex', type: 'debit'),
        throwsA(isA<AccountsDaoError>()
            .having((e) => e.code, 'code', 'duplicate_account_name')),
      );
    });

    test('create credit rechaza closing_day == payment_day', () async {
      expect(
        () => accountsDao.create(
          name: 'Visa',
          type: 'credit',
          creditLimit: 50000,
          closingDay: 15,
          paymentDay: 15,
        ),
        throwsA(isA<AccountsDaoError>()
            .having((e) => e.code, 'code', 'invalid_credit_metadata')),
      );
    });

    test('updateAccount rechaza is_protected (Bolsa)', () async {
      final bolsaId = await accountsDao.createBolsa();
      expect(
        () => accountsDao.updateAccount(id: bolsaId, name: 'Otra'),
        throwsA(isA<AccountsDaoError>()
            .having((e) => e.code, 'code', 'protected_account')),
      );
    });

    test('archive sin movimientos asociados OK y oculta de listAll', () async {
      final id = await accountsDao.create(name: 'X', type: 'debit');
      await accountsDao.archive(id);
      final all = await accountsDao.listAll();
      expect(all, isEmpty);
    });

    test('archive en cascada cancela todos los movimientos asociados', () async {
      final bolsa = await accountsDao.createBolsa();
      final debit = await accountsDao.create(name: 'Banamex', type: 'debit');
      final credit = await accountsDao.create(
        name: 'Visa',
        type: 'credit',
        creditLimit: 50000,
        closingDay: 15,
        paymentDay: 5,
      );
      // 3 movimientos donde debit aparece: income (destino), expense (origen),
      // transfer (origen). El 4to (credit_expense) NO toca debit.
      await entriesDao.registerIncome(
        accountDestinationId: debit, amount: 1000, occurredAt: DateTime.now(),
      );
      await entriesDao.registerExpense(
        accountOriginId: debit, amount: 200, occurredAt: DateTime.now(),
      );
      await entriesDao.registerTransfer(
        accountOriginId: debit,
        accountDestinationId: bolsa,
        amount: 300,
        occurredAt: DateTime.now(),
      );
      await entriesDao.registerCreditExpense(
        accountOriginId: credit, amount: 500, occurredAt: DateTime.now(),
      );

      expect(await accountsDao.countAssociatedEntries(debit), 3);
      expect((await entriesDao.watchPage().first).length, 4);

      await accountsDao.archive(debit);

      // Cuenta archivada + movimientos asociados cancelados (3).
      expect(await accountsDao.listAll(), hasLength(2)); // Bolsa + credit
      final remaining = await entriesDao.watchPage().first;
      expect(remaining, hasLength(1)); // solo el credit_expense
      expect(remaining.first.entry.kind, 'credit_expense');
    });

    test('archive de Bolsa rechaza con protected_account', () async {
      final bolsaId = await accountsDao.createBolsa();
      expect(
        () => accountsDao.archive(bolsaId),
        throwsA(isA<AccountsDaoError>()
            .having((e) => e.code, 'code', 'protected_account')),
      );
    });

    test('archive de cuenta con saldo > 0 ahora se permite (libreta libre)', () async {
      final debitId = await accountsDao.create(name: 'Banamex', type: 'debit');
      await entriesDao.registerIncome(
        accountDestinationId: debitId,
        amount: 100,
        occurredAt: DateTime.now(),
      );
      // El archive NO rechaza: cancela el income y archiva la cuenta.
      await accountsDao.archive(debitId);
      expect(await accountsDao.listAll(), isEmpty);
      expect(await entriesDao.watchPage().first, isEmpty);
    });

    test('watchActive emite cambios reactivos', () async {
      final stream = accountsDao.watchActive();
      expect(await stream.first, isEmpty);
      await accountsDao.create(name: 'A', type: 'debit');
      final after = await stream.first;
      expect(after.length, 1);
    });
  });

  group('CategoriesDao', () {
    test('create acepta applies_to válido', () async {
      for (final ap in ['income', 'expense', 'both']) {
        final id = await categoriesDao.create(
          name: 'Cat-$ap',
          appliesTo: ap,
          colorSlug: 'blue',
          iconSlug: 'tag',
        );
        expect(id, isNotEmpty);
      }
    });

    test('create rechaza applies_to inválido', () async {
      expect(
        () => categoriesDao.create(
          name: 'X',
          appliesTo: 'other',
          colorSlug: 'blue',
          iconSlug: 'tag',
        ),
        throwsA(isA<CategoriesDaoError>()
            .having((e) => e.code, 'code', 'invalid_category_applies_to')),
      );
    });

    test('create rechaza color_slug fuera del catálogo', () async {
      expect(
        () => categoriesDao.create(
          name: 'X',
          appliesTo: 'expense',
          colorSlug: 'cyan-glow',
          iconSlug: 'tag',
        ),
        throwsA(isA<CategoriesDaoError>()
            .having((e) => e.code, 'code', 'invalid_color_slug')),
      );
    });

    test('create rechaza icon_slug fuera del catálogo', () async {
      expect(
        () => categoriesDao.create(
          name: 'X',
          appliesTo: 'expense',
          colorSlug: 'blue',
          iconSlug: 'rocket-9000',
        ),
        throwsA(isA<CategoriesDaoError>()
            .having((e) => e.code, 'code', 'invalid_icon_slug')),
      );
    });

    test('archive funciona y oculta de watchActive', () async {
      final id = await categoriesDao.create(
        name: 'Comida',
        appliesTo: 'expense',
        colorSlug: 'orange',
        iconSlug: 'shopping-cart',
      );
      await categoriesDao.archive(id);
      final active = await categoriesDao.watchActive().first;
      expect(active, isEmpty);
      // Pero listAll(includeArchived: true) la incluye.
      final all = await categoriesDao.listAll(includeArchived: true);
      expect(all.length, 1);
    });
  });

  group('EntriesDao — los 5 kinds', () {
    late String bolsaId, debitId, creditId, categoryExpenseId;

    setUp(() async {
      bolsaId = await accountsDao.createBolsa();
      debitId = await accountsDao.create(name: 'Banamex', type: 'debit');
      creditId = await accountsDao.create(
        name: 'Visa',
        type: 'credit',
        creditLimit: 50000,
        closingDay: 15,
        paymentDay: 5,
      );
      categoryExpenseId = await categoriesDao.create(
        name: 'Comida',
        appliesTo: 'expense',
        colorSlug: 'orange',
        iconSlug: 'shopping-cart',
      );
    });

    test('income aumenta el saldo de la cuenta destino', () async {
      await entriesDao.registerIncome(
        accountDestinationId: bolsaId,
        amount: 1000,
        occurredAt: DateTime.now(),
      );
      expect(await stateService.accountBalanceNow(bolsaId), 1000);
    });

    test('expense baja el saldo de la cuenta origen', () async {
      await entriesDao.registerIncome(
        accountDestinationId: debitId,
        amount: 500,
        occurredAt: DateTime.now(),
      );
      await entriesDao.registerExpense(
        accountOriginId: debitId,
        amount: 200,
        occurredAt: DateTime.now(),
        categoryId: categoryExpenseId,
      );
      expect(await stateService.accountBalanceNow(debitId), 300);
    });

    test('credit_expense aumenta deuda de la tarjeta', () async {
      await entriesDao.registerCreditExpense(
        accountOriginId: creditId,
        amount: 5000,
        occurredAt: DateTime.now(),
        categoryId: categoryExpenseId,
      );
      expect(await stateService.accountBalanceNow(creditId), 5000);
    });

    test('debt_payment baja deuda + saldo origin', () async {
      // Cargar tarjeta primero.
      await entriesDao.registerIncome(
        accountDestinationId: debitId,
        amount: 10000,
        occurredAt: DateTime.now(),
      );
      await entriesDao.registerCreditExpense(
        accountOriginId: creditId,
        amount: 5000,
        occurredAt: DateTime.now(),
      );
      // Pagar 3000 de la tarjeta.
      await entriesDao.registerDebtPayment(
        accountOriginId: debitId,
        accountDestinationId: creditId,
        amount: 3000,
        occurredAt: DateTime.now(),
      );
      expect(await stateService.accountBalanceNow(creditId), 2000); // deuda restante
      expect(await stateService.accountBalanceNow(debitId), 7000);
    });

    test('debt_payment OverpayDebt rechaza', () async {
      // Deuda = 1000.
      await entriesDao.registerIncome(
        accountDestinationId: debitId,
        amount: 5000,
        occurredAt: DateTime.now(),
      );
      await entriesDao.registerCreditExpense(
        accountOriginId: creditId,
        amount: 1000,
        occurredAt: DateTime.now(),
      );
      // Intentar pagar 2000 (más de la deuda) debe rechazar.
      expect(
        () => entriesDao.registerDebtPayment(
          accountOriginId: debitId,
          accountDestinationId: creditId,
          amount: 2000,
          occurredAt: DateTime.now(),
        ),
        throwsA(isA<EntriesDaoError>()
            .having((e) => e.code, 'code', 'overpay_debt')),
      );
    });

    test('transfer mueve dinero sin cambiar BO', () async {
      await entriesDao.registerIncome(
        accountDestinationId: bolsaId,
        amount: 1000,
        occurredAt: DateTime.now(),
      );
      await entriesDao.registerTransfer(
        accountOriginId: bolsaId,
        accountDestinationId: debitId,
        amount: 400,
        occurredAt: DateTime.now(),
      );
      expect(await stateService.accountBalanceNow(bolsaId), 600);
      expect(await stateService.accountBalanceNow(debitId), 400);
    });

    test('transfer con origin == destination rechaza', () async {
      expect(
        () => entriesDao.registerTransfer(
          accountOriginId: bolsaId,
          accountDestinationId: bolsaId,
          amount: 100,
          occurredAt: DateTime.now(),
        ),
        throwsA(isA<EntriesDaoError>()
            .having((e) => e.code, 'code', 'invalid_account_type')),
      );
    });

    test('debt_payment con destino que no es credit rechaza', () async {
      expect(
        () => entriesDao.registerDebtPayment(
          accountOriginId: debitId,
          accountDestinationId: bolsaId, // cash, debería ser credit
          amount: 100,
          occurredAt: DateTime.now(),
        ),
        throwsA(isA<EntriesDaoError>()
            .having((e) => e.code, 'code', 'invalid_account_type')),
      );
    });

    test('cancel soft-deletea y desaparece de listas', () async {
      final id = await entriesDao.registerIncome(
        accountDestinationId: bolsaId,
        amount: 100,
        occurredAt: DateTime.now(),
      );
      expect(await stateService.accountBalanceNow(bolsaId), 100);
      await entriesDao.cancel(id);
      expect(await stateService.accountBalanceNow(bolsaId), 0);
      final entries = await entriesDao.watchPage().first;
      expect(entries, isEmpty);
    });

    test('cancel es idempotente', () async {
      final id = await entriesDao.registerIncome(
        accountDestinationId: bolsaId,
        amount: 100,
        occurredAt: DateTime.now(),
      );
      await entriesDao.cancel(id);
      await entriesDao.cancel(id); // no debe lanzar
    });

    test('cancel idempotente preserva balance (no doble reversión)', () async {
      // RF-021 del sprint flutter-local-hardening. Si una regresión hiciera
      // que el segundo cancel volviera a restar el monto, este test lo agarra.
      final id = await entriesDao.registerIncome(
        accountDestinationId: bolsaId,
        amount: 500,
        occurredAt: DateTime.now(),
      );
      // Pre-condición: balance = 500.
      expect(await stateService.accountBalanceNow(bolsaId), 500);
      await entriesDao.cancel(id);
      final afterFirst = await stateService.accountBalanceNow(bolsaId);
      expect(afterFirst, 0);
      await entriesDao.cancel(id);
      final afterSecond = await stateService.accountBalanceNow(bolsaId);
      expect(afterSecond, afterFirst);
      expect(afterSecond, 0);
    });

    test('credit_expense con categoría income rechaza', () async {
      final incomeCat = await categoriesDao.create(
        name: 'Sueldo',
        appliesTo: 'income',
        colorSlug: 'green',
        iconSlug: 'banknotes',
      );
      expect(
        () => entriesDao.registerCreditExpense(
          accountOriginId: creditId,
          amount: 100,
          occurredAt: DateTime.now(),
          categoryId: incomeCat,
        ),
        throwsA(isA<EntriesDaoError>()
            .having((e) => e.code, 'code', 'invalid_category_applies_to')),
      );
    });
  });

  // Matriz de transiciones de updateEntry (RF-022 del sprint flutter-local-hardening).
  // Cubre combinaciones reales que el usuario puede hacer en el form de edición.
  group('EntriesDao.updateEntry transiciones', () {
    late FincoreDatabase db;
    late AccountsDao accountsDao;
    late CategoriesDao categoriesDao;
    late EntriesDao entriesDao;
    late String bolsaId;
    late String debitId;
    late String catComida;
    late String catSueldo;

    setUp(() async {
      db = FincoreDatabase(NativeDatabase.memory());
      accountsDao = AccountsDao(db);
      categoriesDao = CategoriesDao(db);
      entriesDao = EntriesDao(db);
      bolsaId = await accountsDao.createBolsa();
      debitId = await accountsDao.create(name: 'Banamex', type: 'debit');
      catComida = await categoriesDao.create(
        name: 'Comida',
        appliesTo: 'expense',
        colorSlug: 'orange',
        iconSlug: 'shopping-cart',
      );
      catSueldo = await categoriesDao.create(
        name: 'Sueldo',
        appliesTo: 'income',
        colorSlug: 'green',
        iconSlug: 'banknotes',
      );
    });

    tearDown(() => db.close());

    test('edita amount + description + occurredAt simultáneo', () async {
      final id = await entriesDao.registerIncome(
        accountDestinationId: bolsaId,
        amount: 100,
        occurredAt: DateTime.utc(2026, 1, 1),
        description: 'inicial',
      );
      await entriesDao.updateEntry(
        id: id,
        amount: 250,
        description: 'editado',
        occurredAt: DateTime.utc(2026, 6, 15),
      );
      final entries = await entriesDao.watchPage().first;
      final e = entries.first.entry;
      expect(e.amount, 250);
      expect(e.description, 'editado');
      expect(e.occurredAt.year, 2026);
      expect(e.occurredAt.month, 6);
      expect(e.occurredAt.day, 15);
    });

    test('cambia categoryId a una compatible', () async {
      final id = await entriesDao.registerIncome(
        accountDestinationId: bolsaId,
        amount: 100,
        occurredAt: DateTime.now(),
      );
      await entriesDao.updateEntry(id: id, categoryId: catSueldo);
      final entries = await entriesDao.watchPage().first;
      expect(entries.first.entry.categoryId, catSueldo);
    });

    test('cambia categoryId a una incompatible rechaza', () async {
      final id = await entriesDao.registerIncome(
        accountDestinationId: bolsaId,
        amount: 100,
        occurredAt: DateTime.now(),
      );
      expect(
        () => entriesDao.updateEntry(id: id, categoryId: catComida),
        throwsA(isA<EntriesDaoError>()
            .having((e) => e.code, 'code', 'invalid_category_applies_to')),
      );
    });

    test('cambia accountOriginId a otra cuenta activa', () async {
      final otra = await accountsDao.create(name: 'Santander', type: 'debit');
      final id = await entriesDao.registerExpense(
        accountOriginId: debitId,
        amount: 50,
        occurredAt: DateTime.now(),
      );
      await entriesDao.updateEntry(id: id, accountOriginId: otra);
      final entries = await entriesDao.watchPage().first;
      expect(entries.first.entry.accountOriginId, otra);
    });

    test('updateEntry sobre entry con categoría heredada archivada limpia silenciosamente', () async {
      // RF-014 + RN-H03: la categoría se archiva DESPUÉS del insert.
      // updateEntry sin tocar categoryId debe persistir el entry con
      // categoryId = null y sin lanzar error.
      final id = await entriesDao.registerExpense(
        accountOriginId: debitId,
        amount: 80,
        occurredAt: DateTime.now(),
        categoryId: catComida,
      );
      await categoriesDao.archive(catComida);
      await entriesDao.updateEntry(id: id, amount: 90);
      final entries = await entriesDao.watchPage().first;
      expect(entries.first.entry.categoryId, equals(null));
      expect(entries.first.entry.amount, 90);
    });

    test('updateEntry con categoryId explícito archivado rechaza', () async {
      // M5 (quality review 2026-06-19): si el caller pasa explícitamente una
      // categoryId que está archivada, debe lanzar invalid_category_applies_to.
      // RN-H03 solo limpia silenciosamente cuando la categoría es heredada
      // (categoryId == null en el call).
      final id = await entriesDao.registerIncome(
        accountDestinationId: bolsaId,
        amount: 100,
        occurredAt: DateTime.now(),
      );
      await categoriesDao.archive(catSueldo);
      expect(
        () => entriesDao.updateEntry(id: id, categoryId: catSueldo),
        throwsA(isA<EntriesDaoError>()
            .having((e) => e.code, 'code', 'invalid_category_applies_to')),
      );
    });

    test('updateEntry con clearCategory=true ignora categoryId pasado', () async {
      final id = await entriesDao.registerIncome(
        accountDestinationId: bolsaId,
        amount: 100,
        occurredAt: DateTime.now(),
        categoryId: catSueldo,
      );
      await entriesDao.updateEntry(
        id: id,
        clearCategory: true,
        categoryId: catSueldo,
      );
      final entries = await entriesDao.watchPage().first;
      expect(entries.first.entry.categoryId, equals(null));
    });

    test('watchPage no incluye badge para categorías archivadas (RF-005)', () async {
      // Defensa contra la regresión post-smoke del sprint anterior: el join
      // de drift en watchPage filtra `categories.deletedAt.isNull()`, así
      // que un entry con categoryId apuntando a una categoría archivada
      // retorna `category = null`.
      await entriesDao.registerIncome(
        accountDestinationId: bolsaId,
        amount: 100,
        occurredAt: DateTime.now(),
        categoryId: catSueldo,
      );
      // El entry persiste con su categoryId; archivamos la categoría.
      await categoriesDao.archive(catSueldo);
      final entries = await entriesDao.watchPage().first;
      expect(entries, hasLength(1));
      expect(entries.first.entry.categoryId, equals(catSueldo),
          reason: 'categoryId del entry se preserva tras archive');
      expect(entries.first.category, equals(null),
          reason: 'el join filtra categorías archivadas → no hay badge');
    });
  });

  group('seed.dart', () {
    test('seedDefaults crea Bolsa + 10 categorías', () async {
      await seedDefaults(
        db: db,
        accountsDao: accountsDao,
        categoriesDao: categoriesDao,
      );
      final accounts = await accountsDao.listAll();
      expect(accounts.length, 1);
      expect(accounts.first.type, 'cash');
      final categories = await categoriesDao.listAll();
      expect(categories.length, 10);
      final income = categories.where((c) => c.appliesTo == 'income').length;
      final expense = categories.where((c) => c.appliesTo == 'expense').length;
      expect(income, 3);
      expect(expense, 7);
    });

    test('seedDefaults idempotente: segunda llamada no agrega filas', () async {
      await seedDefaults(
        db: db,
        accountsDao: accountsDao,
        categoriesDao: categoriesDao,
      );
      await seedDefaults(
        db: db,
        accountsDao: accountsDao,
        categoriesDao: categoriesDao,
      );
      expect((await accountsDao.listAll()).length, 1);
      expect((await categoriesDao.listAll()).length, 10);
    });
  });

  group('Factories helper', () {
    test('Factories produce companions válidos para insert directo', () async {
      await db.into(db.accounts).insert(Factories.bolsa());
      await db.into(db.accounts).insert(Factories.debit(name: 'X'));
      await db.into(db.accounts).insert(
            Factories.credit(name: 'Y', closingDay: 10, paymentDay: 5),
          );
      final all = await accountsDao.listAll();
      expect(all.length, 3);
    });
  });

  // Sprint flutter-reports-credit-cards-v1: validación reforzada de
  // `credit_limit` (obligatorio, >= 0) + migración v4 → v5.
  group('AccountsDao — credit_limit (sprint credit-cards)', () {
    test('UT-01: create(type=credit, creditLimit=null) tira invalid_credit_limit',
        () async {
      await expectLater(
        accountsDao.create(
          name: 'VisaSinLimite',
          type: 'credit',
          closingDay: 15,
          paymentDay: 5,
          // creditLimit no se pasa
        ),
        throwsA(isA<AccountsDaoError>()
            .having((e) => e.code, 'code', 'invalid_credit_limit')
            .having((e) => e.message, 'message', contains('obligatorio'))),
      );
    });

    test('UT-02: updateAccount con creditLimit inválido (< 0) tira error',
        () async {
      final id = await accountsDao.create(
        name: 'Amex',
        type: 'credit',
        creditLimit: 10000,
        closingDay: 15,
        paymentDay: 5,
      );
      await expectLater(
        accountsDao.updateAccount(id: id, creditLimit: -100),
        throwsA(isA<AccountsDaoError>()
            .having((e) => e.code, 'code', 'invalid_credit_limit')),
      );
    });

    test('UT-03: create(type=credit, creditLimit=0) es válido (RN-CC01)',
        () async {
      final id = await accountsDao.create(
        name: 'Palacio',
        type: 'credit',
        creditLimit: 0,
        closingDay: 15,
        paymentDay: 5,
      );
      final account = await accountsDao.findById(id);
      expect(account != null, isTrue);
      expect(account!.creditLimit, 0);
    });

    test('UT-04: create(type=cash, creditLimit=null) es válido (no aplica validación)',
        () async {
      final id = await accountsDao.createBolsa();
      final account = await accountsDao.findById(id);
      expect(account != null, isTrue);
      // Post-schema v5, cash queda con credit_limit=0 por DEFAULT.
      expect(account!.creditLimit, 0);
    });

    test('UT-B01: CategoriesDao.create(applies_to=income, monthlyLimit=100) → invalid_monthly_limit_for_income', () async {
      await expectLater(
        categoriesDao.create(
          name: 'Sueldo',
          appliesTo: 'income',
          colorSlug: 'green',
          iconSlug: 'briefcase',
          monthlyLimit: 100,
        ),
        throwsA(isA<CategoriesDaoError>()
            .having((e) => e.code, 'code', 'invalid_monthly_limit_for_income')),
      );
    });

    test('UT-B02: CategoriesDao.create(applies_to=expense, monthlyLimit=-50) → invalid_monthly_limit', () async {
      await expectLater(
        categoriesDao.create(
          name: 'Comida',
          appliesTo: 'expense',
          colorSlug: 'red',
          iconSlug: 'shopping-cart',
          monthlyLimit: -50,
        ),
        throwsA(isA<CategoriesDaoError>()
            .having((e) => e.code, 'code', 'invalid_monthly_limit')),
      );
    });

    test('UT-B03: updateCategory con monthlyLimit=-1 sobre expense → invalid_monthly_limit', () async {
      final id = await categoriesDao.create(
        name: 'Transporte',
        appliesTo: 'expense',
        colorSlug: 'blue',
        iconSlug: 'truck',
      );
      await expectLater(
        categoriesDao.updateCategory(id: id, monthlyLimit: const Value(-1)),
        throwsA(isA<CategoriesDaoError>()
            .having((e) => e.code, 'code', 'invalid_monthly_limit')),
      );
    });

    test('UT-B04: create(applies_to=both, monthlyLimit=0) OK', () async {
      final id = await categoriesDao.create(
        name: 'Salud',
        appliesTo: 'both',
        colorSlug: 'green',
        iconSlug: 'heart',
        monthlyLimit: 0,
      );
      final cat = await categoriesDao.findById(id);
      expect(cat != null, isTrue);
      expect(cat!.monthlyLimit, 0);
    });

    test('UT-19: onUpgrade(4→5) sobre BD limpia es idempotente', () async {
      // La BD in-memory ya está en v5. Correr onUpgrade otra vez no debe
      // romper (backfill sin nulls + alterTable sobre schema actual + CREATE
      // INDEX IF NOT EXISTS).
      await db.customStatement(
        'CREATE INDEX IF NOT EXISTS idx_accounts_deleted ON accounts(deleted_at)',
      );
      // No hay excepción → OK. Y las tablas siguen existiendo.
      expect(await accountsDao.listAll(), isEmpty);
    });
  });
}

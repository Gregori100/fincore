import 'package:drift/native.dart';
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
  late AccountsDao accounts;
  late CategoriesDao categories;
  late EntriesDao entries;
  late FinancialStateService state;

  late String bolsa, debit, credit;

  setUp(() async {
    db = FincoreDatabase(NativeDatabase.memory());
    state = FinancialStateService(db);
    accounts = AccountsDao(db);
    categories = CategoriesDao(db);
    entries = EntriesDao(db);

    bolsa = await accounts.createBolsa();
    debit = await accounts.create(name: 'Banamex', type: 'debit');
    credit = await accounts.create(
      name: 'Visa',
      type: 'credit',
      creditLimit: 50000,
      closingDay: 15,
      paymentDay: 5,
    );
  });

  tearDown(() => db.close());

  test('Libreta libre: expense que deja saldo negativo se acepta', () async {
    // BO = 0 antes; expense por 1000 → BO = -1000. Debe pasar.
    await entries.registerExpense(
      accountOriginId: debit,
      amount: 1000,
      occurredAt: DateTime.now(),
    );
    expect(await state.accountBalanceNow(debit), -1000);
  });

  test('Libreta libre: credit_expense que excede credit_limit se acepta', () async {
    // credit_limit = 50000; cargar 60000 → deuda 60000 > limit. Acepta libreta libre.
    await entries.registerCreditExpense(
      accountOriginId: credit,
      amount: 60000,
      occurredAt: DateTime.now(),
    );
    expect(await state.accountBalanceNow(credit), 60000);
    // CR queda negativo (sobre-girado).
    expect(await state.watchCr().first, -10000);
  });

  test('Crear movimiento con cuenta archivada como origin rechaza', () async {
    // Archivar debit (sin movimientos, saldo 0).
    await accounts.archive(debit);
    expect(
      () => entries.registerExpense(
        accountOriginId: debit,
        amount: 100,
        occurredAt: DateTime.now(),
      ),
      throwsA(isA<EntriesDaoError>()
          .having((e) => e.code, 'code', 'invalid_account_type')),
    );
  });

  test('income editado con origin != null rechaza', () async {
    // Crear income limpio.
    final id = await entries.registerIncome(
      accountDestinationId: bolsa,
      amount: 100,
      occurredAt: DateTime.now(),
    );
    // Intentar agregar origin via update → debe rechazar (income no lleva origin).
    expect(
      () => entries.updateEntry(id: id, accountOriginId: debit),
      throwsA(isA<EntriesDaoError>()
          .having((e) => e.code, 'code', 'invalid_account_type')),
    );
  });

  test('credit_expense con origin no credit rechaza', () async {
    expect(
      () => entries.registerCreditExpense(
        accountOriginId: debit, // debit, debería ser credit
        amount: 100,
        occurredAt: DateTime.now(),
      ),
      throwsA(isA<EntriesDaoError>()
          .having((e) => e.code, 'code', 'invalid_account_type')),
    );
  });

  test('transfer con destino credit rechaza', () async {
    expect(
      () => entries.registerTransfer(
        accountOriginId: debit,
        accountDestinationId: credit, // credit no es cash/debit
        amount: 100,
        occurredAt: DateTime.now(),
      ),
      throwsA(isA<EntriesDaoError>()
          .having((e) => e.code, 'code', 'invalid_account_type')),
    );
  });

  test('debt_payment con categoría rechaza', () async {
    final cat = await categories.create(
      name: 'X',
      appliesTo: 'expense',
      colorSlug: 'blue',
      iconSlug: 'tag',
    );
    // Setup: meter algo de deuda primero para que no caiga en OverpayDebt.
    await entries.registerCreditExpense(
      accountOriginId: credit,
      amount: 500,
      occurredAt: DateTime.now(),
    );
    // El método registerDebtPayment no acepta categoryId, así que el "rechazo"
    // se verifica via updateEntry que sí lo intenta.
    final id = await entries.registerDebtPayment(
      accountOriginId: debit,
      accountDestinationId: credit,
      amount: 100,
      occurredAt: DateTime.now(),
    );
    expect(
      () => entries.updateEntry(id: id, categoryId: cat),
      throwsA(isA<EntriesDaoError>()
          .having((e) => e.code, 'code', 'invalid_category_applies_to')),
    );
  });

  test('updateEntry rechaza cuenta archivada como nuevo origin', () async {
    final id = await entries.registerExpense(
      accountOriginId: debit,
      amount: 100,
      occurredAt: DateTime.now(),
    );
    // Otra cuenta debit para archivar.
    final other = await accounts.create(name: 'Santander', type: 'debit');
    await accounts.archive(other);
    expect(
      () => entries.updateEntry(id: id, accountOriginId: other),
      throwsA(isA<EntriesDaoError>()
          .having((e) => e.code, 'code', 'invalid_account_type')),
    );
  });
}

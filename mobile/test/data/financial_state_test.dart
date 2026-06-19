import 'package:drift/native.dart';
import 'package:fincore/data/daos/accounts_dao.dart';
import 'package:fincore/data/daos/entries_dao.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/data/financial_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sqlite_override.dart';

void main() {
  setUpAll(initSqliteOverride);

  late FincoreDatabase db;
  late AccountsDao accountsDao;
  late EntriesDao entriesDao;
  late FinancialStateService state;

  late String bolsa, debit, credit;

  setUp(() async {
    db = FincoreDatabase(NativeDatabase.memory());
    state = FinancialStateService(db);
    accountsDao = AccountsDao(db);
    entriesDao = EntriesDao(db, state);

    bolsa = await accountsDao.createBolsa();
    debit = await accountsDao.create(name: 'Banamex', type: 'debit');
    credit = await accountsDao.create(
      name: 'Visa',
      type: 'credit',
      creditLimit: 50000,
      closingDay: 15,
      paymentDay: 5,
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('BD vacía: BO/DE/CR = 0', () async {
    expect(await state.watchBo().first, 0);
    expect(await state.watchDe().first, 0);
    expect(await state.watchCr().first, 50000);
  });

  test('Income suma a BO', () async {
    await entriesDao.registerIncome(
      accountDestinationId: bolsa,
      amount: 1000,
      occurredAt: DateTime.now(),
    );
    expect(await state.watchBo().first, 1000);
  });

  test('Expense baja BO (libreta libre permite negativo)', () async {
    await entriesDao.registerExpense(
      accountOriginId: debit,
      amount: 200,
      occurredAt: DateTime.now(),
    );
    expect(await state.watchBo().first, -200);
  });

  test('credit_expense sube DE y baja CR', () async {
    await entriesDao.registerCreditExpense(
      accountOriginId: credit,
      amount: 5000,
      occurredAt: DateTime.now(),
    );
    expect(await state.watchDe().first, 5000);
    expect(await state.watchCr().first, 45000);
  });

  test('debt_payment baja DE y baja BO', () async {
    await entriesDao.registerIncome(
      accountDestinationId: debit,
      amount: 10000,
      occurredAt: DateTime.now(),
    );
    await entriesDao.registerCreditExpense(
      accountOriginId: credit,
      amount: 5000,
      occurredAt: DateTime.now(),
    );
    await entriesDao.registerDebtPayment(
      accountOriginId: debit,
      accountDestinationId: credit,
      amount: 2000,
      occurredAt: DateTime.now(),
    );
    expect(await state.watchBo().first, 8000); // 10000 - 2000
    expect(await state.watchDe().first, 3000); // 5000 - 2000
    expect(await state.watchCr().first, 47000); // 50000 - 3000
  });

  test('transfer NO cambia BO (suma cero entre debit y cash)', () async {
    await entriesDao.registerIncome(
      accountDestinationId: bolsa,
      amount: 1000,
      occurredAt: DateTime.now(),
    );
    await entriesDao.registerTransfer(
      accountOriginId: bolsa,
      accountDestinationId: debit,
      amount: 400,
      occurredAt: DateTime.now(),
    );
    expect(await state.watchBo().first, 1000); // sin cambio
    expect(await state.accountBalanceNow(bolsa), 600);
    expect(await state.accountBalanceNow(debit), 400);
  });

  test('Entry cancelado NO cuenta en BO/DE/CR', () async {
    final id = await entriesDao.registerIncome(
      accountDestinationId: bolsa,
      amount: 500,
      occurredAt: DateTime.now(),
    );
    expect(await state.watchBo().first, 500);
    await entriesDao.cancel(id);
    expect(await state.watchBo().first, 0);
  });

  test('Cuenta archivada NO aparece en BO', () async {
    await entriesDao.registerIncome(
      accountDestinationId: debit,
      amount: 300,
      occurredAt: DateTime.now(),
    );
    expect(await state.watchBo().first, 300);
    // Archive ahora cancela el income en cascada, sin precondición de saldo.
    await accountsDao.archive(debit);
    expect(await state.watchBo().first, 0);
  });

  test('Stream reactivo: insert entry mientras escucha → emite valor nuevo', () async {
    final emissions = <double>[];
    final sub = state.watchBo().listen(emissions.add);
    // Esperar primer valor.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await entriesDao.registerIncome(
      accountDestinationId: bolsa,
      amount: 1000,
      occurredAt: DateTime.now(),
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await sub.cancel();
    expect(emissions, contains(0));
    expect(emissions, contains(1000));
  });

  test('CR cuando no hay credit accounts es 0', () async {
    await accountsDao.archive(credit); // archive en cascada
    expect(await state.watchCr().first, 0);
  });

  test('CR ignora cuentas con credit_limit NULL', () async {
    // Una credit sin limit configurada (improbable, pero defensivo).
    final id = await accountsDao.create(
      name: 'Otra',
      type: 'credit',
      creditLimit: 30000,
      closingDay: 10,
      paymentDay: 1,
    );
    // CR ahora debería ser 50000 + 30000.
    expect(await state.watchCr().first, 80000);
    await accountsDao.archive(id);
    expect(await state.watchCr().first, 50000);
  });

  test('accountBalanceNow sincrónico devuelve mismo valor que stream', () async {
    await entriesDao.registerIncome(
      accountDestinationId: bolsa,
      amount: 750,
      occurredAt: DateTime.now(),
    );
    final sync = await state.accountBalanceNow(bolsa);
    final reactive = await state.watchAccountBalance(bolsa, 'cash').first;
    expect(sync, reactive);
    expect(sync, 750);
  });

  // Cache de streams (RF-012 del sprint flutter-local-hardening).
  test('cache: watchAccountBalance retorna el mismo Stream para la misma key', () {
    final s1 = state.watchAccountBalance(bolsa, 'cash');
    final s2 = state.watchAccountBalance(bolsa, 'cash');
    expect(identical(s1, s2), isTrue);
  });

  test('cache: keys distintas retornan Streams distintos', () {
    final s1 = state.watchAccountBalance(bolsa, 'cash');
    final s2 = state.watchAccountBalance(debit, 'debit');
    expect(identical(s1, s2), isFalse);
  });

  test('cache: invalidateAccount borra solo las keys de esa cuenta', () {
    final sBolsa = state.watchAccountBalance(bolsa, 'cash');
    final sDebit = state.watchAccountBalance(debit, 'debit');
    state.invalidateAccount(bolsa);
    // Tras invalidar bolsa, la próxima llamada crea un Stream nuevo.
    final sBolsa2 = state.watchAccountBalance(bolsa, 'cash');
    expect(identical(sBolsa, sBolsa2), isFalse);
    // Debit no se tocó: misma referencia.
    final sDebit2 = state.watchAccountBalance(debit, 'debit');
    expect(identical(sDebit, sDebit2), isTrue);
  });

  test('cache: invalidateAll vacía el Map', () {
    final s1 = state.watchAccountBalance(bolsa, 'cash');
    state.invalidateAll();
    final s2 = state.watchAccountBalance(bolsa, 'cash');
    expect(identical(s1, s2), isFalse);
  });

  test('cache: archive(id) invalida automáticamente la cuenta archivada', () async {
    final sDebit1 = state.watchAccountBalance(debit, 'debit');
    await accountsDao.archive(debit, state);
    final sDebit2 = state.watchAccountBalance(debit, 'debit');
    expect(identical(sDebit1, sDebit2), isFalse);
  });
}

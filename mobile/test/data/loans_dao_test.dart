// Tests del LoansDao del sprint flutter-loans-v1.
//
// Cubre CRUD (create atómico + income, updateLoan campos inmutables,
// closeManual/reopen con transiciones válidas e inválidas, deleteLoan
// cascada), streams (watchActive/watchClosed), balanceOf y
// countActivePayments.

import 'package:drift/native.dart';
import 'package:fincore/data/daos/accounts_dao.dart';
import 'package:fincore/data/daos/categories_dao.dart';
import 'package:fincore/data/daos/entries_dao.dart';
import 'package:fincore/data/daos/loans_dao.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/data/seed.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sqlite_override.dart';

void main() {
  setUpAll(initSqliteOverride);

  late FincoreDatabase db;
  late AccountsDao accountsDao;
  late CategoriesDao categoriesDao;
  late LoansDao loansDao;
  late EntriesDao entriesDao;
  late String bolsaId;
  late String debitId;
  late String creditId;

  setUp(() async {
    db = FincoreDatabase(NativeDatabase.memory());
    accountsDao = AccountsDao(db);
    categoriesDao = CategoriesDao(db);
    loansDao = db.loansDao;
    entriesDao = db.entriesDao;
    await seedDefaults(
      db: db,
      accountsDao: accountsDao,
      categoriesDao: categoriesDao,
    );
    final bolsa = await accountsDao
        .listAll()
        .then((l) => l.firstWhere((a) => a.type == 'cash'));
    bolsaId = bolsa.id;
    debitId = await accountsDao.create(name: 'BBVA Débito', type: 'debit');
    creditId = await accountsDao.create(
      name: 'BBVA Oro',
      type: 'credit',
      creditLimit: 50000,
      closingDay: 15,
      paymentDay: 5,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('LoansDao.create', () {
    test('crea el préstamo + income inicial en la misma transacción',
        () async {
      final loanId = await loansDao.create(
        name: 'BBVA Personal',
        principalAmount: 37300,
        monthlyPayment: 1758,
        initialDurationMonths: 36,
        paymentDay: 5,
        contractDate: DateTime.utc(2026, 7, 15),
        destinationAccountId: bolsaId,
      );
      final loan = await loansDao.findById(loanId);
      expect(loan, isNotNull);
      expect(loan!.principalAmount, 37300);
      expect(loan.currentDurationMonths, 36);
      expect(loan.destinationAccountId, bolsaId);
      // Verificar income inicial.
      final incomeId = await loansDao.findIncomeEntryId(loanId);
      expect(incomeId, isNotNull);
      final income = await entriesDao.findById(incomeId!);
      expect(income, isNotNull);
      expect(income!.entry.kind, 'income');
      expect(income.entry.amount, 37300);
      expect(income.entry.accountDestinationId, bolsaId);
      expect(income.entry.loanId, loanId);
    });

    test('rechaza destinationAccountId tipo credit', () async {
      expect(
        () => loansDao.create(
          name: 'X',
          principalAmount: 1000,
          monthlyPayment: 100,
          initialDurationMonths: 12,
          paymentDay: 5,
          contractDate: DateTime.utc(2026, 7, 15),
          destinationAccountId: creditId,
        ),
        throwsA(isA<LoansDaoError>()
            .having((e) => e.code, 'code', 'invalid_account_type')),
      );
    });

    test('rechaza cuenta destino inexistente', () async {
      expect(
        () => loansDao.create(
          name: 'X',
          principalAmount: 1000,
          monthlyPayment: 100,
          initialDurationMonths: 12,
          paymentDay: 5,
          contractDate: DateTime.utc(2026, 7, 15),
          destinationAccountId: 'no-existe',
        ),
        throwsA(isA<LoansDaoError>()
            .having((e) => e.code, 'code', 'not_found')),
      );
    });

    test('rechaza principalAmount ≤ 0', () async {
      expect(
        () => loansDao.create(
          name: 'X',
          principalAmount: 0,
          monthlyPayment: 100,
          initialDurationMonths: 12,
          paymentDay: 5,
          contractDate: DateTime.utc(2026, 7, 15),
          destinationAccountId: bolsaId,
        ),
        throwsA(isA<LoansDaoError>()
            .having((e) => e.code, 'code', 'invalid_loan_data')),
      );
    });

    test('rechaza payment_day fuera de rango 1-28', () async {
      expect(
        () => loansDao.create(
          name: 'X',
          principalAmount: 1000,
          monthlyPayment: 100,
          initialDurationMonths: 12,
          paymentDay: 31,
          contractDate: DateTime.utc(2026, 7, 15),
          destinationAccountId: bolsaId,
        ),
        throwsA(isA<LoansDaoError>()
            .having((e) => e.code, 'code', 'invalid_payment_day')),
      );
    });

    test('rechaza name vacío', () async {
      expect(
        () => loansDao.create(
          name: '   ',
          principalAmount: 1000,
          monthlyPayment: 100,
          initialDurationMonths: 12,
          paymentDay: 5,
          contractDate: DateTime.utc(2026, 7, 15),
          destinationAccountId: bolsaId,
        ),
        throwsA(isA<LoansDaoError>()
            .having((e) => e.code, 'code', 'invalid_loan_data')),
      );
    });
  });

  group('LoansDao.updateLoan', () {
    late String loanId;
    setUp(() async {
      loanId = await loansDao.create(
        name: 'BBVA',
        principalAmount: 10000,
        monthlyPayment: 500,
        initialDurationMonths: 24,
        paymentDay: 10,
        contractDate: DateTime.utc(2026, 7, 15),
        destinationAccountId: bolsaId,
      );
    });

    test('actualiza campos editables', () async {
      await loansDao.updateLoan(
        id: loanId,
        name: 'BBVA v2',
        monthlyPayment: 600,
        currentDurationMonths: 20,
        paymentDay: 15,
      );
      final loan = await loansDao.findById(loanId);
      expect(loan!.name, 'BBVA v2');
      expect(loan.monthlyPayment, 600);
      expect(loan.currentDurationMonths, 20);
      expect(loan.paymentDay, 15);
      // Inmutables preservados.
      expect(loan.principalAmount, 10000);
      expect(loan.initialDurationMonths, 24);
      expect(loan.destinationAccountId, bolsaId);
    });

    test('rechaza payment_day fuera de rango', () async {
      expect(
        () => loansDao.updateLoan(id: loanId, paymentDay: 30),
        throwsA(isA<LoansDaoError>()
            .having((e) => e.code, 'code', 'invalid_payment_day')),
      );
    });
  });

  group('LoansDao.closeManual + reopen', () {
    late String loanId;
    setUp(() async {
      loanId = await loansDao.create(
        name: 'BBVA',
        principalAmount: 10000,
        monthlyPayment: 500,
        initialDurationMonths: 24,
        paymentDay: 10,
        contractDate: DateTime.utc(2026, 7, 15),
        destinationAccountId: bolsaId,
      );
    });

    test('closeManual setea closed_at + close_reason=manual', () async {
      await loansDao.closeManual(loanId);
      final loan = await loansDao.findById(loanId);
      expect(loan!.closedAt, isNotNull);
      expect(loan.closeReason, 'manual');
    });

    test('reopen sobre manual limpia los campos', () async {
      await loansDao.closeManual(loanId);
      await loansDao.reopen(loanId);
      final loan = await loansDao.findById(loanId);
      expect(loan!.closedAt, isNull);
      expect(loan.closeReason, isNull);
    });

    test('reopen sobre paid lanza cannot_reopen_paid', () async {
      // Simular paid manualmente en BD.
      await loansDao.closeManual(loanId);
      final loan = await loansDao.findById(loanId);
      await db.customStatement(
        'UPDATE loans SET close_reason = ? WHERE id = ?',
        ['paid', loanId],
      );
      expect(loan!.closeReason, 'manual'); // pre-check
      expect(
        () => loansDao.reopen(loanId),
        throwsA(isA<LoansDaoError>()
            .having((e) => e.code, 'code', 'cannot_reopen_paid')),
      );
    });

    test('closeManual sobre préstamo ya cerrado: no-op silencioso', () async {
      await loansDao.closeManual(loanId);
      await loansDao.closeManual(loanId); // segunda llamada
      final loan = await loansDao.findById(loanId);
      expect(loan!.closeReason, 'manual');
    });

    test('reopen sobre préstamo abierto: no-op silencioso', () async {
      await loansDao.reopen(loanId);
      final loan = await loansDao.findById(loanId);
      expect(loan!.closedAt, isNull);
    });
  });

  group('LoansDao.deleteLoan', () {
    test('cascada: income + pagos quedan con deleted_at', () async {
      final loanId = await loansDao.create(
        name: 'BBVA',
        principalAmount: 10000,
        monthlyPayment: 500,
        initialDurationMonths: 24,
        paymentDay: 10,
        contractDate: DateTime.utc(2026, 7, 15),
        destinationAccountId: bolsaId,
      );
      // Agregar 3 pagos del mes en meses distintos (regla nueva:
      // unicidad por mes).
      for (var i = 0; i < 3; i++) {
        await entriesDao.registerLoanPayment(
          loanId: loanId,
          accountOriginId: bolsaId,
          amount: 500,
          principalAmount: 400,
          interestAmount: 100,
          occurredAt: DateTime.utc(2026, 8 + i, 5),
          isMonthlyPayment: true,
        );
      }
      expect(await loansDao.countActivePayments(loanId), 3);

      await loansDao.deleteLoan(loanId);

      final loan = await loansDao.findById(loanId);
      expect(loan, isNull); // ya no se retorna (soft-deleted).
      expect(await loansDao.countActivePayments(loanId), 0);
    });
  });

  group('watchActive / watchClosed', () {
    test('watchActive excluye cerrados y eliminados', () async {
      final aId = await loansDao.create(
        name: 'A',
        principalAmount: 1000,
        monthlyPayment: 100,
        initialDurationMonths: 12,
        paymentDay: 5,
        contractDate: DateTime.utc(2026, 7, 15),
        destinationAccountId: bolsaId,
      );
      final bId = await loansDao.create(
        name: 'B',
        principalAmount: 1000,
        monthlyPayment: 100,
        initialDurationMonths: 12,
        paymentDay: 5,
        contractDate: DateTime.utc(2026, 7, 15),
        destinationAccountId: bolsaId,
      );
      await loansDao.closeManual(aId);

      final active = await loansDao.watchActive().first;
      expect(active.length, 1);
      expect(active.first.id, bId);
    });

    test('watchClosed incluye paid y manual', () async {
      final aId = await loansDao.create(
        name: 'A',
        principalAmount: 1000,
        monthlyPayment: 100,
        initialDurationMonths: 12,
        paymentDay: 5,
        contractDate: DateTime.utc(2026, 7, 15),
        destinationAccountId: bolsaId,
      );
      await loansDao.closeManual(aId);

      final closed = await loansDao.watchClosed().first;
      expect(closed.length, 1);
      expect(closed.first.id, aId);
    });
  });

  group('balanceOf', () {
    test('sin pagos retorna principal completo', () async {
      final loanId = await loansDao.create(
        name: 'X',
        principalAmount: 5000,
        monthlyPayment: 500,
        initialDurationMonths: 10,
        paymentDay: 5,
        contractDate: DateTime.utc(2026, 7, 15),
        destinationAccountId: bolsaId,
      );
      expect(await loansDao.balanceOf(loanId), 5000);
    });

    test('resta la suma de principal_amount de los pagos activos',
        () async {
      final loanId = await loansDao.create(
        name: 'X',
        principalAmount: 5000,
        monthlyPayment: 500,
        initialDurationMonths: 10,
        paymentDay: 5,
        contractDate: DateTime.utc(2026, 7, 15),
        destinationAccountId: bolsaId,
      );
      await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 500,
        principalAmount: 400,
        interestAmount: 100,
        occurredAt: DateTime.utc(2026, 8, 5),
        isMonthlyPayment: true,
      );
      expect(await loansDao.balanceOf(loanId), 4600);
    });

    test('ignora pagos cancelados', () async {
      final loanId = await loansDao.create(
        name: 'X',
        principalAmount: 5000,
        monthlyPayment: 500,
        initialDurationMonths: 10,
        paymentDay: 5,
        contractDate: DateTime.utc(2026, 7, 15),
        destinationAccountId: bolsaId,
      );
      final pId = await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 500,
        principalAmount: 400,
        interestAmount: 100,
        occurredAt: DateTime.utc(2026, 8, 5),
        isMonthlyPayment: true,
      );
      await entriesDao.deleteLoanPayment(pId);
      expect(await loansDao.balanceOf(loanId), 5000);
    });
  });

  group('countActivePayments', () {
    test('retorna 0 sin pagos', () async {
      final loanId = await loansDao.create(
        name: 'X',
        principalAmount: 1000,
        monthlyPayment: 100,
        initialDurationMonths: 10,
        paymentDay: 5,
        contractDate: DateTime.utc(2026, 7, 15),
        destinationAccountId: bolsaId,
      );
      expect(await loansDao.countActivePayments(loanId), 0);
    });

    test('cuenta N pagos activos, ignora cancelados', () async {
      final loanId = await loansDao.create(
        name: 'X',
        principalAmount: 5000,
        monthlyPayment: 500,
        initialDurationMonths: 10,
        paymentDay: 5,
        contractDate: DateTime.utc(2026, 7, 15),
        destinationAccountId: bolsaId,
      );
      for (var i = 0; i < 3; i++) {
        await entriesDao.registerLoanPayment(
          loanId: loanId,
          accountOriginId: bolsaId,
          amount: 500,
          principalAmount: 400,
          interestAmount: 100,
          occurredAt: DateTime.utc(2026, 8 + i, 5),
          isMonthlyPayment: true,
        );
      }
      expect(await loansDao.countActivePayments(loanId), 3);
    });
  });

  group('findByDestinationAccount (usado por AccountsDao.deleteAccount)', () {
    test('retorna null cuando ninguno usa la cuenta', () async {
      expect(await loansDao.findByDestinationAccount(debitId), isNull);
    });

    test('retorna el préstamo cuando usa la cuenta', () async {
      final loanId = await loansDao.create(
        name: 'X',
        principalAmount: 1000,
        monthlyPayment: 100,
        initialDurationMonths: 10,
        paymentDay: 5,
        contractDate: DateTime.utc(2026, 7, 15),
        destinationAccountId: debitId,
      );
      final found = await loansDao.findByDestinationAccount(debitId);
      expect(found, isNotNull);
      expect(found!.id, loanId);
    });

    test('excluye préstamos eliminados', () async {
      final loanId = await loansDao.create(
        name: 'X',
        principalAmount: 1000,
        monthlyPayment: 100,
        initialDurationMonths: 10,
        paymentDay: 5,
        contractDate: DateTime.utc(2026, 7, 15),
        destinationAccountId: debitId,
      );
      await loansDao.deleteLoan(loanId);
      expect(await loansDao.findByDestinationAccount(debitId), isNull);
    });
  });

  group('expectedPaymentMonths (hotfix smoke Diego v4)', () {
    test(
        'contract 20/mayo, paymentDay 5, hoy 5/jun → esperados = [junio]',
        () {
      final months = LoansDao.expectedPaymentMonths(
        contractDate: DateTime.utc(2026, 5, 20),
        today: DateTime.utc(2026, 6, 5),
        paymentDay: 5,
      );
      expect(months, ['2026-06']);
    });

    test(
        'contract 3/mayo, paymentDay 5, hoy 5/mayo → esperados = [mayo] '
        '(contract_day < payment_day → mismo mes cuenta)', () {
      final months = LoansDao.expectedPaymentMonths(
        contractDate: DateTime.utc(2026, 5, 3),
        today: DateTime.utc(2026, 5, 5),
        paymentDay: 5,
      );
      expect(months, ['2026-05']);
    });

    test('today.day < paymentDay del mes actual → excluye mes actual', () {
      final months = LoansDao.expectedPaymentMonths(
        contractDate: DateTime.utc(2026, 5, 3),
        today: DateTime.utc(2026, 7, 4),
        paymentDay: 5,
      );
      expect(months, ['2026-05', '2026-06']);
    });

    test('today.day >= paymentDay → incluye mes actual', () {
      final months = LoansDao.expectedPaymentMonths(
        contractDate: DateTime.utc(2026, 5, 3),
        today: DateTime.utc(2026, 7, 5),
        paymentDay: 5,
      );
      expect(months, ['2026-05', '2026-06', '2026-07']);
    });

    test(
        'contract 1/julio, paymentDay 1, hoy 17/julio → esperados = [julio] '
        '(hotfix v5: igualdad contract_day == payment_day cuenta el mes)',
        () {
      final months = LoansDao.expectedPaymentMonths(
        contractDate: DateTime.utc(2026, 7, 1),
        today: DateTime.utc(2026, 7, 17),
        paymentDay: 1,
      );
      expect(months, ['2026-07']);
    });

    test('contract futuro → lista vacía', () {
      final months = LoansDao.expectedPaymentMonths(
        contractDate: DateTime.utc(2026, 12, 20),
        today: DateTime.utc(2026, 7, 15),
        paymentDay: 5,
      );
      expect(months, isEmpty);
    });
  });

  group('watchMonthsOverdue (hotfix smoke Diego v4)', () {
    test('sin pagos, un mes esperado → overdue = 1', () async {
      final loanId = await loansDao.create(
        name: 'BBVA',
        principalAmount: 5000,
        monthlyPayment: 500,
        initialDurationMonths: 10,
        paymentDay: 15,
        contractDate: DateTime.utc(2026, 7, 1),
        destinationAccountId: bolsaId,
      );
      // Hoy es 17/julio (día 17 >= paymentDay 15) → mes actual cuenta.
      final overdue = await loansDao
          .watchMonthsOverdue(
            loanId: loanId,
            today: DateTime.utc(2026, 7, 17),
            contractDate: DateTime.utc(2026, 7, 1),
            paymentDay: 15,
          )
          .first;
      expect(overdue, 1);
    });

    test('pagado el mes → overdue = 0', () async {
      final loanId = await loansDao.create(
        name: 'BBVA',
        principalAmount: 5000,
        monthlyPayment: 500,
        initialDurationMonths: 10,
        paymentDay: 15,
        contractDate: DateTime.utc(2026, 7, 1),
        destinationAccountId: bolsaId,
      );
      await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 500,
        principalAmount: 400,
        interestAmount: 100,
        occurredAt: DateTime.utc(2026, 7, 15),
        isMonthlyPayment: true,
      );
      final overdue = await loansDao
          .watchMonthsOverdue(
            loanId: loanId,
            today: DateTime.utc(2026, 7, 17),
            contractDate: DateTime.utc(2026, 7, 1),
            paymentDay: 15,
          )
          .first;
      expect(overdue, 0);
    });

    test('dos meses sin pagar → overdue = 2', () async {
      final loanId = await loansDao.create(
        name: 'BBVA',
        principalAmount: 5000,
        monthlyPayment: 500,
        initialDurationMonths: 10,
        paymentDay: 5,
        contractDate: DateTime.utc(2026, 5, 1),
        destinationAccountId: bolsaId,
      );
      // Hoy es 17/julio, paymentDay=5 → esperados: mayo, junio, julio.
      // Registramos solo mayo.
      await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 500,
        principalAmount: 400,
        interestAmount: 100,
        occurredAt: DateTime.utc(2026, 5, 5),
        isMonthlyPayment: true,
      );
      final overdue = await loansDao
          .watchMonthsOverdue(
            loanId: loanId,
            today: DateTime.utc(2026, 7, 17),
            contractDate: DateTime.utc(2026, 5, 1),
            paymentDay: 5,
          )
          .first;
      expect(overdue, 2); // junio + julio.
    });
  });
}

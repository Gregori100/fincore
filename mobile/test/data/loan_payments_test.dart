// Tests del sprint flutter-loans-v1: registerLoanPayment + deleteLoanPayment
// + updateEntry gate + auto-cierre paid + reapertura auto.

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
  late String archivedDebitId;
  late String loanId;

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
    debitId = await accountsDao.create(name: 'Débito', type: 'debit');
    creditId = await accountsDao.create(
      name: 'Crédito',
      type: 'credit',
      creditLimit: 50000,
    );
    archivedDebitId = await accountsDao.create(
      name: 'Archivada',
      type: 'debit',
    );
    await accountsDao.archive(archivedDebitId);
    loanId = await loansDao.create(
      name: 'BBVA',
      principalAmount: 5000,
      monthlyPayment: 500,
      initialDurationMonths: 10,
      paymentDay: 5,
      contractDate: DateTime.utc(2026, 7, 15),
      destinationAccountId: bolsaId,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('registerLoanPayment', () {
    test('happy path: crea entry con split correcto', () async {
      final id = await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 500,
        principalAmount: 400,
        interestAmount: 100,
        occurredAt: DateTime.utc(2026, 8, 5),
        isMonthlyPayment: true,
      );
      final entry = await entriesDao.findById(id);
      expect(entry!.entry.kind, 'loan_payment');
      expect(entry.entry.loanId, loanId);
      expect(entry.entry.amount, 500);
      expect(entry.entry.principalAmount, 400);
      expect(entry.entry.interestAmount, 100);
      expect(entry.entry.accountOriginId, bolsaId);
    });

    test('rechaza principal + interest ≠ amount', () async {
      expect(
        () => entriesDao.registerLoanPayment(
          loanId: loanId,
          accountOriginId: bolsaId,
          amount: 500,
          principalAmount: 300,
          interestAmount: 100, // 300+100 != 500
          occurredAt: DateTime.utc(2026, 8, 5),
        ),
        throwsA(isA<EntriesDaoError>()
            .having((e) => e.code, 'code', 'invalid_loan_split')),
      );
    });

    test('acepta tolerancia < 0.005', () async {
      // 400.001 + 99.998 = 499.999 ≈ 500 (diff = 0.001 < 0.005).
      final id = await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 500,
        principalAmount: 400.001,
        interestAmount: 99.998,
        occurredAt: DateTime.utc(2026, 8, 5),
        isMonthlyPayment: true,
      );
      expect(id, isNotEmpty);
    });

    test('rechaza principal o interest negativos', () async {
      expect(
        () => entriesDao.registerLoanPayment(
          loanId: loanId,
          accountOriginId: bolsaId,
          amount: 500,
          principalAmount: -100,
          interestAmount: 600,
          occurredAt: DateTime.utc(2026, 8, 5),
        ),
        throwsA(isA<EntriesDaoError>()
            .having((e) => e.code, 'code', 'invalid_loan_split')),
      );
    });

    test('rechaza amount ≤ 0', () async {
      expect(
        () => entriesDao.registerLoanPayment(
          loanId: loanId,
          accountOriginId: bolsaId,
          amount: 0,
          principalAmount: 0,
          interestAmount: 0,
          occurredAt: DateTime.utc(2026, 8, 5),
        ),
        throwsA(isA<EntriesDaoError>()
            .having((e) => e.code, 'code', 'invalid_amount')),
      );
    });

    test('rechaza cuenta origen tipo credit', () async {
      expect(
        () => entriesDao.registerLoanPayment(
          loanId: loanId,
          accountOriginId: creditId,
          amount: 500,
          principalAmount: 400,
          interestAmount: 100,
          occurredAt: DateTime.utc(2026, 8, 5),
          isMonthlyPayment: true,
        ),
        throwsA(isA<EntriesDaoError>()
            .having((e) => e.code, 'code', 'invalid_account_type')),
      );
    });

    test('rechaza cuenta origen archivada', () async {
      expect(
        () => entriesDao.registerLoanPayment(
          loanId: loanId,
          accountOriginId: archivedDebitId,
          amount: 500,
          principalAmount: 400,
          interestAmount: 100,
          occurredAt: DateTime.utc(2026, 8, 5),
          isMonthlyPayment: true,
        ),
        throwsA(isA<EntriesDaoError>()
            .having((e) => e.code, 'code', 'invalid_account_type')),
      );
    });

    test('rechaza sobre préstamo cerrado', () async {
      await loansDao.closeManual(loanId);
      expect(
        () => entriesDao.registerLoanPayment(
          loanId: loanId,
          accountOriginId: bolsaId,
          amount: 500,
          principalAmount: 400,
          interestAmount: 100,
          occurredAt: DateTime.utc(2026, 8, 5),
        ),
        throwsA(isA<EntriesDaoError>()
            .having((e) => e.code, 'code', 'loan_closed')),
      );
    });

    test('rechaza sobre préstamo inexistente', () async {
      expect(
        () => entriesDao.registerLoanPayment(
          loanId: 'no-existe',
          accountOriginId: bolsaId,
          amount: 500,
          principalAmount: 400,
          interestAmount: 100,
          occurredAt: DateTime.utc(2026, 8, 5),
        ),
        throwsA(isA<EntriesDaoError>()
            .having((e) => e.code, 'code', 'not_found')),
      );
    });

    test('auto-cierre paid cuando saldo cae a ≤ 0', () async {
      // Nueva regla (hotfix smoke Diego): 1 pago del mes por mes calendario,
      // y los abonos capital requieren monthly del mismo mes primero.
      // 10 pagos "del mes" distribuidos en 10 meses distintos. Cada uno
      // aporta 500 al capital + 1 al interés (para satisfacer isMonthly
      // vía interest > 0). Principal total = 5000 → salda el préstamo.
      for (var i = 0; i < 10; i++) {
        await entriesDao.registerLoanPayment(
          loanId: loanId,
          accountOriginId: bolsaId,
          amount: 501,
          principalAmount: 500,
          interestAmount: 1,
          occurredAt: DateTime.utc(2026, 8 + i, 5),
          isMonthlyPayment: true,
        );
      }
      final loan = await loansDao.findById(loanId);
      expect(loan!.closedAt, isNotNull);
      expect(loan.closeReason, 'paid');
      expect(await loansDao.balanceOf(loanId), 0);
    });

    test('overpay ahora rechaza con overpay_loan (hotfix smoke Diego v3)',
        () async {
      expect(
        () => entriesDao.registerLoanPayment(
          loanId: loanId,
          accountOriginId: bolsaId,
          amount: 10001,
          principalAmount: 10000, // saldo pendiente es 5000
          interestAmount: 1,
          occurredAt: DateTime.utc(2026, 8, 5),
          isMonthlyPayment: true,
        ),
        throwsA(isA<EntriesDaoError>()
            .having((e) => e.code, 'code', 'overpay_loan')),
      );
    });
  });

  group('deleteLoanPayment', () {
    test('reapertura auto cuando saldo vuelve a > 0 sobre paid', () async {
      // Saldar con un solo pago del mes con interés simbólico.
      final pId = await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 5001,
        principalAmount: 5000,
        interestAmount: 1,
        occurredAt: DateTime.utc(2026, 8, 5),
        isMonthlyPayment: true,
      );
      var loan = await loansDao.findById(loanId);
      expect(loan!.closeReason, 'paid');

      // Eliminar el pago → reabre automático.
      await entriesDao.deleteLoanPayment(pId);
      loan = await loansDao.findById(loanId);
      expect(loan!.closedAt, isNull);
      expect(loan.closeReason, isNull);
      expect(await loansDao.balanceOf(loanId), 5000);
    });

    test('NO reapertura sobre cerrado manual', () async {
      final pId = await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 500,
        principalAmount: 400,
        interestAmount: 100,
        occurredAt: DateTime.utc(2026, 8, 5),
        isMonthlyPayment: true,
      );
      await loansDao.closeManual(loanId);
      // Eliminar el pago sobre un cerrado manual.
      await entriesDao.deleteLoanPayment(pId);
      final loan = await loansDao.findById(loanId);
      expect(loan!.closedAt, isNotNull);
      expect(loan.closeReason, 'manual'); // se conserva.
    });

    test('sin reapertura si el pago era 100% interés (principal=0)',
        () async {
      // Saldar con un pago del mes que combina principal + interés.
      final principalPayment = await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 5001,
        principalAmount: 5000,
        interestAmount: 1,
        occurredAt: DateTime.utc(2026, 8, 5),
        isMonthlyPayment: true,
      );
      // Simular: eliminar el pago → reabre; luego agregar un nuevo pago
      // del mes de septiembre pero con principal=0 (solo interés) →
      // sigue abierto (interés no toca capital).
      await entriesDao.deleteLoanPayment(principalPayment);
      final interestPayment = await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 100,
        principalAmount: 0,
        interestAmount: 100,
        occurredAt: DateTime.utc(2026, 9, 5),
        isMonthlyPayment: true,
      );
      expect((await loansDao.findById(loanId))!.closedAt, isNull);
      await entriesDao.deleteLoanPayment(interestPayment);
      // Sigue abierto, saldo no cambió porque interés no toca principal.
      final loan = await loansDao.findById(loanId);
      expect(loan!.closedAt, isNull);
    });
  });

  group('deleteLoanPayment cascadeCapitalInMonth (hotfix smoke Diego v4)', () {
    test('elimina monthly + todos los capital del mismo mes en una tx',
        () async {
      final monthlyId = await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 500,
        principalAmount: 400,
        interestAmount: 100,
        occurredAt: DateTime.utc(2026, 8, 5),
        isMonthlyPayment: true,
      );
      final cap1 = await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 200,
        principalAmount: 200,
        interestAmount: 0,
        occurredAt: DateTime.utc(2026, 8, 10),
        isMonthlyPayment: false,
      );
      final cap2 = await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 300,
        principalAmount: 300,
        interestAmount: 0,
        occurredAt: DateTime.utc(2026, 8, 20),
        isMonthlyPayment: false,
      );
      // Sanity: countCapitalPaymentsInSameMonth ve los dos.
      expect(await entriesDao.countCapitalPaymentsInSameMonth(monthlyId), 2);

      await entriesDao.deleteLoanPayment(
        monthlyId,
        cascadeCapitalInMonth: true,
      );

      // Los tres quedaron con deleted_at != null.
      for (final id in [monthlyId, cap1, cap2]) {
        final row = await entriesDao.findById(id);
        expect(row?.entry.deletedAt, isNotNull,
            reason: '$id debería haber quedado soft-deleted');
      }
      // Balance vuelve al principal completo (5000) porque nada quedó
      // activo.
      expect(await loansDao.balanceOf(loanId), 5000);
    });

    test('cascade sobre pago SIN abonos del mes no borra pagos de otro mes',
        () async {
      final jul = await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 500,
        principalAmount: 400,
        interestAmount: 100,
        occurredAt: DateTime.utc(2026, 7, 20),
        isMonthlyPayment: true,
      );
      final julCap = await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 100,
        principalAmount: 100,
        interestAmount: 0,
        occurredAt: DateTime.utc(2026, 7, 25),
        isMonthlyPayment: false,
      );
      final ago = await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 500,
        principalAmount: 400,
        interestAmount: 100,
        occurredAt: DateTime.utc(2026, 8, 5),
        isMonthlyPayment: true,
      );

      // Cascade sobre AGOSTO (no tiene capitales) NO debe tocar julio.
      await entriesDao.deleteLoanPayment(
        ago,
        cascadeCapitalInMonth: true,
      );
      expect((await entriesDao.findById(ago))?.entry.deletedAt, isNotNull);
      expect((await entriesDao.findById(jul))?.entry.deletedAt, isNull);
      expect((await entriesDao.findById(julCap))?.entry.deletedAt, isNull);
    });
  });

  group('updateEntry gate sobre entries con loan_id', () {
    test('rechaza edición sobre loan_payment', () async {
      final pId = await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 500,
        principalAmount: 400,
        interestAmount: 100,
        occurredAt: DateTime.utc(2026, 8, 5),
        isMonthlyPayment: true,
      );
      expect(
        () => entriesDao.updateEntry(id: pId, amount: 600),
        throwsA(isA<EntriesDaoError>()
            .having((e) => e.code, 'code', 'immutable_loan_payment')),
      );
    });

    test('rechaza edición sobre income inicial', () async {
      final incomeId = await loansDao.findIncomeEntryId(loanId);
      expect(
        () => entriesDao.updateEntry(id: incomeId!, amount: 99999),
        throwsA(isA<EntriesDaoError>()
            .having((e) => e.code, 'code', 'immutable_loan_payment')),
      );
    });

    test('permite edición sobre entry normal (sin loan_id)', () async {
      final id = await entriesDao.registerExpense(
        accountOriginId: bolsaId,
        amount: 100,
        occurredAt: DateTime.utc(2026, 8, 5),
      );
      await entriesDao.updateEntry(id: id, amount: 150);
      final entry = await entriesDao.findById(id);
      expect(entry!.entry.amount, 150);
    });
  });

  group('AccountsDao.deleteAccount con préstamo asociado', () {
    test('rechaza account_in_use_by_loan si hay préstamo activo', () async {
      // El préstamo del setUp usa bolsaId como destino. Pero la Bolsa está
      // protegida, así que probamos con un préstamo sobre debitId.
      final debitLoanId = await loansDao.create(
        name: 'Sobre débito',
        principalAmount: 1000,
        monthlyPayment: 100,
        initialDurationMonths: 12,
        paymentDay: 5,
        contractDate: DateTime.utc(2026, 7, 15),
        destinationAccountId: debitId,
      );
      expect(debitLoanId, isNotEmpty);
      expect(
        () => accountsDao.deleteAccount(debitId),
        throwsA(isA<AccountsDaoError>()
            .having((e) => e.code, 'code', 'account_in_use_by_loan')),
      );
    });

    test('permite delete si el préstamo asociado está eliminado', () async {
      final debitLoanId = await loansDao.create(
        name: 'X',
        principalAmount: 1000,
        monthlyPayment: 100,
        initialDurationMonths: 12,
        paymentDay: 5,
        contractDate: DateTime.utc(2026, 7, 15),
        destinationAccountId: debitId,
      );
      await loansDao.deleteLoan(debitLoanId);
      // Ahora sí se puede eliminar la cuenta.
      await accountsDao.deleteAccount(debitId);
      expect(await accountsDao.findById(debitId), isNotNull);
      // findById retorna incluso soft-deleted; findActiveOrArchivedById debería
      // ser null.
      expect(await accountsDao.findActiveOrArchivedById(debitId), isNull);
    });

    test('permite archivar cuenta aunque tenga préstamo asociado', () async {
      final debitLoanId = await loansDao.create(
        name: 'X',
        principalAmount: 1000,
        monthlyPayment: 100,
        initialDurationMonths: 12,
        paymentDay: 5,
        contractDate: DateTime.utc(2026, 7, 15),
        destinationAccountId: debitId,
      );
      expect(debitLoanId, isNotEmpty);
      // Archivar NO está bloqueado por RN-L09.
      await accountsDao.archive(debitId);
      final acc = await accountsDao.findActiveOrArchivedById(debitId);
      expect(acc!.archivedAt, isNotNull);
    });
  });

  // ==========================================================================
  // Hotfix smoke Diego: pago no puede ser anterior a la fecha del contrato
  // + unicidad de pago del mes por préstamo (isMonthlyPayment=true).
  // ==========================================================================
  group('registerLoanPayment — validaciones de fecha + unicidad', () {
    test('rechaza pago con occurredAt anterior a contract_date', () async {
      // El loanId del setUp tiene contract_date = 2026-07-15.
      expect(
        () => entriesDao.registerLoanPayment(
          loanId: loanId,
          accountOriginId: bolsaId,
          amount: 500,
          principalAmount: 400,
          interestAmount: 100,
          occurredAt: DateTime.utc(2026, 6, 1), // ANTES del contrato.
        ),
        throwsA(isA<EntriesDaoError>().having(
            (e) => e.code, 'code', 'payment_before_contract')),
      );
    });

    test('acepta pago con occurredAt igual al contract_date', () async {
      // El loanId del setUp tiene contract_date = 2026-07-15.
      final id = await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 500,
        principalAmount: 400,
        interestAmount: 100,
        occurredAt: DateTime.utc(2026, 7, 15),
        isMonthlyPayment: true,
      );
      expect(id, isNotEmpty);
    });

    test('acepta pago con occurredAt en el futuro', () async {
      final id = await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 500,
        principalAmount: 400,
        interestAmount: 100,
        occurredAt: DateTime.utc(2027, 12, 5), // Futuro lejano.
        isMonthlyPayment: true,
      );
      expect(id, isNotEmpty);
    });

    test(
        'isMonthlyPayment=true bloquea 2do pago con interest > 0 en el mismo mes',
        () async {
      await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 500,
        principalAmount: 400,
        interestAmount: 100,
        occurredAt: DateTime.utc(2026, 8, 5),
        isMonthlyPayment: true,
      );
      // Segundo intento del mismo mes → rechazado.
      expect(
        () => entriesDao.registerLoanPayment(
          loanId: loanId,
          accountOriginId: bolsaId,
          amount: 500,
          principalAmount: 300,
          interestAmount: 200,
          occurredAt: DateTime.utc(2026, 8, 20),
          isMonthlyPayment: true,
        ),
        throwsA(isA<EntriesDaoError>().having(
            (e) => e.code, 'code', 'duplicate_monthly_payment')),
      );
    });

    test(
        'isMonthlyPayment=true permite pago en OTRO mes tras un pago previo',
        () async {
      await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 500,
        principalAmount: 400,
        interestAmount: 100,
        occurredAt: DateTime.utc(2026, 8, 5),
        isMonthlyPayment: true,
      );
      // Septiembre — OK.
      final id = await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 500,
        principalAmount: 400,
        interestAmount: 100,
        occurredAt: DateTime.utc(2026, 9, 5),
        isMonthlyPayment: true,
      );
      expect(id, isNotEmpty);
    });

    test(
        'isMonthlyPayment=false (abono capital) requiere monthly previo en el mismo mes',
        () async {
      // Hotfix v2: primero el monthly, luego múltiples abonos capital.
      await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 500,
        principalAmount: 400,
        interestAmount: 100,
        occurredAt: DateTime.utc(2026, 8, 1),
        isMonthlyPayment: true,
      );
      // Ahora múltiples abonos capital en el mismo mes: permitidos.
      for (var i = 0; i < 3; i++) {
        final id = await entriesDao.registerLoanPayment(
          loanId: loanId,
          accountOriginId: bolsaId,
          amount: 500,
          principalAmount: 500,
          interestAmount: 0,
          occurredAt: DateTime.utc(2026, 8, 5 + i),
          isMonthlyPayment: false,
        );
        expect(id, isNotEmpty);
      }
      expect(await loansDao.countActivePayments(loanId), 4); // 1 monthly + 3 capital
    });

    test(
        'abono capital SIN monthly previo del mes: rechaza con capital_before_monthly',
        () async {
      expect(
        () => entriesDao.registerLoanPayment(
          loanId: loanId,
          accountOriginId: bolsaId,
          amount: 500,
          principalAmount: 500,
          interestAmount: 0,
          occurredAt: DateTime.utc(2026, 8, 5),
          isMonthlyPayment: false,
        ),
        throwsA(isA<EntriesDaoError>()
            .having((e) => e.code, 'code', 'capital_before_monthly')),
      );
    });
  });

  // Hotfix smoke Diego: watchHasMonthlyPaymentIn del LoansDao para el chip
  // PRÓXIMO PAGO del Dashboard.
  group('LoansDao.watchHasMonthlyPaymentIn', () {
    test('retorna false cuando no hay pago del mes en el periodo', () async {
      expect(await loansDao.hasMonthlyPaymentIn(loanId, 2026, 8), isFalse);
    });

    test('retorna true tras registrar un pago con interest > 0 en el mes',
        () async {
      await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 500,
        principalAmount: 400,
        interestAmount: 100,
        occurredAt: DateTime.utc(2026, 8, 5),
        isMonthlyPayment: true,
      );
      expect(await loansDao.hasMonthlyPaymentIn(loanId, 2026, 8), isTrue);
      // Otro mes no se afecta.
      expect(await loansDao.hasMonthlyPaymentIn(loanId, 2026, 9), isFalse);
    });

    test('un abono capital (interest=0) NO cuenta como pago del mes',
        () async {
      // Registrar monthly + abono capital + eliminar el monthly.
      // Después de eliminar, sólo queda el capital → hasMonthlyPaymentIn
      // debe retornar false porque el capital no cuenta como monthly.
      final monthlyId = await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 500,
        principalAmount: 400,
        interestAmount: 100,
        occurredAt: DateTime.utc(2026, 8, 1),
        isMonthlyPayment: true,
      );
      await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 500,
        principalAmount: 500,
        interestAmount: 0,
        occurredAt: DateTime.utc(2026, 8, 15),
        isMonthlyPayment: false,
      );
      expect(await loansDao.hasMonthlyPaymentIn(loanId, 2026, 8), isTrue);
      await entriesDao.deleteLoanPayment(monthlyId);
      expect(await loansDao.hasMonthlyPaymentIn(loanId, 2026, 8), isFalse);
    });
  });
}

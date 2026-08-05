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
      creditLimit: 5000000,
    );
    archivedDebitId = await accountsDao.create(
      name: 'Archivada',
      type: 'debit',
    );
    await accountsDao.archive(archivedDebitId);
    loanId = await loansDao.create(
      name: 'BBVA',
      principalAmount: 500000,
      monthlyPayment: 50000,
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
        amount: 50000,
        principalAmount: 40000,
        interestAmount: 10000,
        occurredAt: DateTime.utc(2026, 8, 5),
        isMonthlyPayment: true,
      );
      final entry = await entriesDao.findById(id);
      expect(entry!.entry.kind, 'loan_payment');
      expect(entry.entry.loanId, loanId);
      expect(entry.entry.amount, 50000);
      expect(entry.entry.principalAmount, 40000);
      expect(entry.entry.interestAmount, 10000);
      expect(entry.entry.accountOriginId, bolsaId);
    });

    test('rechaza principal + interest ≠ amount', () async {
      expect(
        () => entriesDao.registerLoanPayment(
          loanId: loanId,
          accountOriginId: bolsaId,
          amount: 50000,
          principalAmount: 30000,
          interestAmount: 10000, // 300+100 != 500
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
        amount: 50000,
        principalAmount: 40000,
        interestAmount: 10000,
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
          amount: 50000,
          principalAmount: -10000,
          interestAmount: 60000,
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
          amount: 50000,
          principalAmount: 40000,
          interestAmount: 10000,
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
          amount: 50000,
          principalAmount: 40000,
          interestAmount: 10000,
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
          amount: 50000,
          principalAmount: 40000,
          interestAmount: 10000,
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
          amount: 50000,
          principalAmount: 40000,
          interestAmount: 10000,
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
          amount: 50100,
          principalAmount: 50000,
          interestAmount: 100,
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
          amount: 1000100,
          principalAmount: 1000000, // saldo pendiente es 5000
          interestAmount: 100,
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
        amount: 500100,
        principalAmount: 500000,
        interestAmount: 100,
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
      expect(await loansDao.balanceOf(loanId), 500000);
    });

    test('NO reapertura sobre cerrado manual', () async {
      final pId = await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 50000,
        principalAmount: 40000,
        interestAmount: 10000,
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
        amount: 500100,
        principalAmount: 500000,
        interestAmount: 100,
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
        amount: 10000,
        principalAmount: 0,
        interestAmount: 10000,
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

  group('deleteLoanPayment sin cascada (RN-LF-04)', () {
    test(
        'UT-LF-28: borrar el pago del mes NO arrastra los abonos a capital '
        'del mismo mes', () async {
      // Antes del sprint flutter-loans-flexible-payments-v1 este borrado
      // eliminaba en cascada los abonos del mismo mes calendario, para no
      // dejarlos huérfanos frente al candado `capital_before_monthly`. Sin
      // ese candado la cascada era destrucción de datos sin justificación.
      final monthlyId = await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 50000,
        principalAmount: 40000,
        interestAmount: 10000,
        occurredAt: DateTime.utc(2026, 8, 5),
        isMonthlyPayment: true,
      );
      final cap1 = await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 20000,
        principalAmount: 20000,
        interestAmount: 0,
        occurredAt: DateTime.utc(2026, 8, 10),
        isMonthlyPayment: false,
      );
      final cap2 = await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 30000,
        principalAmount: 30000,
        interestAmount: 0,
        occurredAt: DateTime.utc(2026, 8, 20),
        isMonthlyPayment: false,
      );

      await entriesDao.deleteLoanPayment(monthlyId);

      expect((await entriesDao.findById(monthlyId))?.entry.deletedAt,
          isNotNull);
      for (final id in [cap1, cap2]) {
        expect((await entriesDao.findById(id))?.entry.deletedAt, isNull,
            reason: '$id debe sobrevivir al borrado del pago del mes');
      }
    });

    test(
        'UT-LF-29: el saldo tras el borrado refleja SÓLO el capital del pago '
        'eliminado', () async {
      final monthlyId = await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 50000,
        principalAmount: 40000,
        interestAmount: 10000,
        occurredAt: DateTime.utc(2026, 8, 5),
        isMonthlyPayment: true,
      );
      await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 20000,
        principalAmount: 20000,
        interestAmount: 0,
        occurredAt: DateTime.utc(2026, 8, 10),
        isMonthlyPayment: false,
      );
      // 500000 - 40000 - 20000.
      expect(await loansDao.balanceOf(loanId), 440000);

      await entriesDao.deleteLoanPayment(monthlyId);

      // Devuelve los 40000 del pago borrado; los 20000 del abono siguen
      // descontados porque ese pago sigue vivo.
      expect(await loansDao.balanceOf(loanId), 480000);
    });
  });

  group('updateLoanPayment (hotfix quality-review B2)', () {
    late String monthlyId;

    setUp(() async {
      monthlyId = await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 50000,
        principalAmount: 40000,
        interestAmount: 10000,
        occurredAt: DateTime.utc(2026, 8, 5),
        isMonthlyPayment: true,
      );
    });

    test('happy path: cambia monto y split', () async {
      await entriesDao.updateLoanPayment(
        entryId: monthlyId,
        amount: 60000,
        principalAmount: 50000,
        interestAmount: 10000,
        occurredAt: DateTime.utc(2026, 8, 5),
      );
      final e = await entriesDao.findById(monthlyId);
      expect(e?.entry.amount, 60000);
      expect(e?.entry.principalAmount, 50000);
      expect(e?.entry.interestAmount, 10000);
      expect(e?.entry.isMonthlyPayment, isTrue,
          reason: 'isMonthlyPayment se preserva del entry original');
      expect(await loansDao.balanceOf(loanId), 450000);
    });

    test('rechaza overpay considerando el capital previo del propio entry',
        () async {
      // saldo actual = 5000 - 400 (del monthly ya registrado) = 4600.
      // Al editar, disponible = 4600 + 400 (oldPrincipal) = 5000.
      // Nuevo principal 5001 excede.
      expect(
        () => entriesDao.updateLoanPayment(
          entryId: monthlyId,
          amount: 500200,
          principalAmount: 500100,
          interestAmount: 100,
          occurredAt: DateTime.utc(2026, 8, 5),
        ),
        throwsA(isA<EntriesDaoError>()
            .having((e) => e.code, 'code', 'overpay_loan')),
      );
      // Y aceptar exactamente 5000.
      await entriesDao.updateLoanPayment(
        entryId: monthlyId,
        amount: 500100,
        principalAmount: 500000,
        interestAmount: 100,
        occurredAt: DateTime.utc(2026, 8, 5),
      );
      expect(await loansDao.balanceOf(loanId), 0);
    });

    test(
        'auto-cierre paid cuando el nuevo split salda el préstamo',
        () async {
      await entriesDao.updateLoanPayment(
        entryId: monthlyId,
        amount: 500100,
        principalAmount: 500000,
        interestAmount: 100,
        occurredAt: DateTime.utc(2026, 8, 5),
      );
      final loan = await loansDao.findById(loanId);
      expect(loan?.closeReason, 'paid');
      expect(loan?.closedAt, isNotNull);
    });

    test('auto-reapertura paid cuando el edit reabre el saldo', () async {
      // Registrar un capital extra para llegar a paid.
      final extraCap = await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 460000,
        principalAmount: 460000,
        interestAmount: 0,
        occurredAt: DateTime.utc(2026, 8, 10),
        isMonthlyPayment: false,
      );
      expect((await loansDao.findById(loanId))?.closeReason, 'paid');
      // Editar el capital para bajarlo → reabre.
      await entriesDao.updateLoanPayment(
        entryId: extraCap,
        amount: 10000,
        principalAmount: 10000,
        interestAmount: 0,
        occurredAt: DateTime.utc(2026, 8, 10),
      );
      final loan = await loansDao.findById(loanId);
      expect(loan?.closedAt, isNull);
      expect(loan?.closeReason, isNull);
    });

    test(
        'UT-LF-27: permite mover un pago del mes a un mes que YA tiene pago '
        'del mes (RN-LF-01)', () async {
      await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 50000,
        principalAmount: 40000,
        interestAmount: 10000,
        occurredAt: DateTime.utc(2026, 9, 5),
        isMonthlyPayment: true,
      );
      // Antes esto lanzaba `duplicate_monthly_payment`. Con préstamos
      // quincenales, dos pagos con intereses en el mismo mes son lo normal.
      await entriesDao.updateLoanPayment(
        entryId: monthlyId,
        amount: 50000,
        principalAmount: 40000,
        interestAmount: 10000,
        occurredAt: DateTime.utc(2026, 9, 10),
      );
      final moved = await entriesDao.findById(monthlyId);
      expect(moved?.entry.occurredAt, DateTime.utc(2026, 9, 10));
      expect(moved?.entry.deletedAt, isNull);
      // Los dos pagos siguen descontando capital: 500000 - 40000 - 40000.
      expect(await loansDao.balanceOf(loanId), 420000);
    });

    test(
        'permite mover un abono a capital a un mes SIN pago del mes '
        '(RN-LF-02)', () async {
      final capId = await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 10000,
        principalAmount: 10000,
        interestAmount: 0,
        occurredAt: DateTime.utc(2026, 8, 15),
        isMonthlyPayment: false,
      );
      // Septiembre no tiene pago del mes: antes lanzaba
      // `capital_before_monthly`.
      await entriesDao.updateLoanPayment(
        entryId: capId,
        amount: 10000,
        principalAmount: 10000,
        interestAmount: 0,
        occurredAt: DateTime.utc(2026, 9, 15),
      );
      final moved = await entriesDao.findById(capId);
      expect(moved?.entry.occurredAt, DateTime.utc(2026, 9, 15));
      expect(moved?.entry.deletedAt, isNull);
    });

    test('rechaza payment_before_contract', () async {
      expect(
        () => entriesDao.updateLoanPayment(
          entryId: monthlyId,
          amount: 50000,
          principalAmount: 40000,
          interestAmount: 10000,
          occurredAt: DateTime.utc(2026, 7, 14), // contract es 2026-07-15
        ),
        throwsA(isA<EntriesDaoError>()
            .having((e) => e.code, 'code', 'payment_before_contract')),
      );
    });

    test('rechaza invalid_loan_split cuando principal + interest ≠ amount',
        () async {
      expect(
        () => entriesDao.updateLoanPayment(
          entryId: monthlyId,
          amount: 50000,
          principalAmount: 30000,
          interestAmount: 10000, // 300+100 = 400 ≠ 500
          occurredAt: DateTime.utc(2026, 8, 5),
        ),
        throwsA(isA<EntriesDaoError>()
            .having((e) => e.code, 'code', 'invalid_loan_split')),
      );
    });

    test('not_found sobre entry inexistente o eliminado', () async {
      expect(
        () => entriesDao.updateLoanPayment(
          entryId: 'ffffffff-ffff-7fff-8fff-ffffffffffff',
          amount: 50000,
          principalAmount: 40000,
          interestAmount: 10000,
          occurredAt: DateTime.utc(2026, 8, 5),
        ),
        throwsA(isA<EntriesDaoError>()
            .having((e) => e.code, 'code', 'not_found')),
      );
      await entriesDao.deleteLoanPayment(monthlyId);
      expect(
        () => entriesDao.updateLoanPayment(
          entryId: monthlyId,
          amount: 50000,
          principalAmount: 40000,
          interestAmount: 10000,
          occurredAt: DateTime.utc(2026, 8, 5),
        ),
        throwsA(isA<EntriesDaoError>()
            .having((e) => e.code, 'code', 'not_found')),
      );
    });
  });

  group('updateEntry gate sobre entries con loan_id', () {
    test('rechaza edición sobre loan_payment', () async {
      final pId = await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 50000,
        principalAmount: 40000,
        interestAmount: 10000,
        occurredAt: DateTime.utc(2026, 8, 5),
        isMonthlyPayment: true,
      );
      expect(
        () => entriesDao.updateEntry(id: pId, amount: 60000),
        throwsA(isA<EntriesDaoError>()
            .having((e) => e.code, 'code', 'immutable_loan_payment')),
      );
    });

    test('rechaza edición sobre income inicial', () async {
      final incomeId = await loansDao.findIncomeEntryId(loanId);
      expect(
        () => entriesDao.updateEntry(id: incomeId!, amount: 9999900),
        throwsA(isA<EntriesDaoError>()
            .having((e) => e.code, 'code', 'immutable_loan_payment')),
      );
    });

    test('permite edición sobre entry normal (sin loan_id)', () async {
      final id = await entriesDao.registerExpense(
        accountOriginId: bolsaId,
        amount: 10000,
        occurredAt: DateTime.utc(2026, 8, 5),
      );
      await entriesDao.updateEntry(id: id, amount: 15000);
      final entry = await entriesDao.findById(id);
      expect(entry!.entry.amount, 15000);
    });
  });

  group('AccountsDao.deleteAccount con préstamo asociado', () {
    test('rechaza account_in_use_by_loan si hay préstamo activo', () async {
      // El préstamo del setUp usa bolsaId como destino. Pero la Bolsa está
      // protegida, así que probamos con un préstamo sobre debitId.
      final debitLoanId = await loansDao.create(
        name: 'Sobre débito',
        principalAmount: 100000,
        monthlyPayment: 10000,
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
        principalAmount: 100000,
        monthlyPayment: 10000,
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
        principalAmount: 100000,
        monthlyPayment: 10000,
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
          amount: 50000,
          principalAmount: 40000,
          interestAmount: 10000,
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
        amount: 50000,
        principalAmount: 40000,
        interestAmount: 10000,
        occurredAt: DateTime.utc(2026, 7, 15),
        isMonthlyPayment: true,
      );
      expect(id, isNotEmpty);
    });

    test('acepta pago con occurredAt en el futuro', () async {
      final id = await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 50000,
        principalAmount: 40000,
        interestAmount: 10000,
        occurredAt: DateTime.utc(2027, 12, 5), // Futuro lejano.
        isMonthlyPayment: true,
      );
      expect(id, isNotEmpty);
    });

    test(
        'UT-LF-21: isMonthlyPayment=true PERMITE un 2do pago del mes en el '
        'mismo mes calendario (RN-LF-01)', () async {
      // El caso que originó el sprint: el préstamo de Diego es quincenal, así
      // que dos pagos con intereses en agosto son lo normal. Antes el segundo
      // moría con `duplicate_monthly_payment`.
      final primero = await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 50000,
        principalAmount: 40000,
        interestAmount: 10000,
        occurredAt: DateTime.utc(2026, 8, 5),
        isMonthlyPayment: true,
      );
      final segundo = await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 50000,
        principalAmount: 30000,
        interestAmount: 20000,
        occurredAt: DateTime.utc(2026, 8, 20),
        isMonthlyPayment: true,
      );

      // Afirma ESTADO RESULTANTE, no sólo ausencia de excepción: un test que
      // sólo comprobara "no lanza" pasaría aunque el insert no ocurriera.
      expect(primero, isNot(segundo));
      for (final id in [primero, segundo]) {
        final row = await entriesDao.findById(id);
        expect(row?.entry.deletedAt, isNull);
        expect(row?.entry.isMonthlyPayment, isTrue);
      }
      expect(await loansDao.countActivePayments(loanId), 2);
      // 500000 - 40000 - 30000.
      expect(await loansDao.balanceOf(loanId), 430000);
    });

    test(
        'UT-LF-23: tres pagos del mes en el mismo mes quedan los tres activos',
        () async {
      for (final day in [5, 15, 25]) {
        await entriesDao.registerLoanPayment(
          loanId: loanId,
          accountOriginId: bolsaId,
          amount: 20000,
          principalAmount: 10000,
          interestAmount: 10000,
          occurredAt: DateTime.utc(2026, 8, day),
          isMonthlyPayment: true,
        );
      }
      expect(await loansDao.countActivePayments(loanId), 3);
      expect(await loansDao.balanceOf(loanId), 470000);
    });

    test(
        'isMonthlyPayment=true permite pago en OTRO mes tras un pago previo',
        () async {
      await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 50000,
        principalAmount: 40000,
        interestAmount: 10000,
        occurredAt: DateTime.utc(2026, 8, 5),
        isMonthlyPayment: true,
      );
      // Septiembre — OK.
      final id = await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 50000,
        principalAmount: 40000,
        interestAmount: 10000,
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
        amount: 50000,
        principalAmount: 40000,
        interestAmount: 10000,
        occurredAt: DateTime.utc(2026, 8, 1),
        isMonthlyPayment: true,
      );
      // Ahora múltiples abonos capital en el mismo mes: permitidos.
      for (var i = 0; i < 3; i++) {
        final id = await entriesDao.registerLoanPayment(
          loanId: loanId,
          accountOriginId: bolsaId,
          amount: 50000,
          principalAmount: 50000,
          interestAmount: 0,
          occurredAt: DateTime.utc(2026, 8, 5 + i),
          isMonthlyPayment: false,
        );
        expect(id, isNotEmpty);
      }
      expect(await loansDao.countActivePayments(loanId), 4); // 1 monthly + 3 capital
    });

    test(
        'UT-LF-22: abono a capital SIN pago del mes previo se acepta '
        '(RN-LF-02)', () async {
      // Segundo caso reportado por Diego: quería abonar a capital en un mes
      // donde todavía no había capturado el pago con intereses.
      final id = await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 50000,
        principalAmount: 50000,
        interestAmount: 0,
        occurredAt: DateTime.utc(2026, 8, 5),
        isMonthlyPayment: false,
      );

      final row = await entriesDao.findById(id);
      expect(row?.entry.deletedAt, isNull);
      expect(row?.entry.isMonthlyPayment, isFalse);
      expect(await loansDao.countActivePayments(loanId), 1);
      expect(await loansDao.balanceOf(loanId), 450000);
      // Y el mes sigue sin pago del mes registrado: el abono no lo suple.
      expect(await loansDao.hasMonthlyPaymentIn(loanId, 2026, 8), isFalse);
    });

    test(
        'UT-LF-25: overpay_loan sigue vigente en un abono sin pago del mes',
        () async {
      // Quitar el candado de orden no debe debilitar la única regla contable
      // del préstamo.
      expect(
        () => entriesDao.registerLoanPayment(
          loanId: loanId,
          accountOriginId: bolsaId,
          amount: 600000,
          principalAmount: 600000,
          interestAmount: 0,
          occurredAt: DateTime.utc(2026, 8, 5),
          isMonthlyPayment: false,
        ),
        throwsA(isA<EntriesDaoError>()
            .having((e) => e.code, 'code', 'overpay_loan')),
      );
    });

    test(
        'UT-LF-24: overpay_loan vigente cuando DOS pagos del mes suman más '
        'que el saldo', () async {
      await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 300000,
        principalAmount: 300000,
        interestAmount: 0,
        occurredAt: DateTime.utc(2026, 8, 5),
        isMonthlyPayment: true,
      );
      // Saldo restante 200000: un segundo pago de 250000 debe rebotar aunque
      // ya no exista el candado de unicidad mensual.
      expect(
        () => entriesDao.registerLoanPayment(
          loanId: loanId,
          accountOriginId: bolsaId,
          amount: 250000,
          principalAmount: 250000,
          interestAmount: 0,
          occurredAt: DateTime.utc(2026, 8, 20),
          isMonthlyPayment: true,
        ),
        throwsA(isA<EntriesDaoError>()
            .having((e) => e.code, 'code', 'overpay_loan')),
      );
    });

    test(
        'UT-LF-26: el préstamo se cierra como paid cuando quien lo liquida es '
        'un abono a capital suelto', () async {
      await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 500000,
        principalAmount: 500000,
        interestAmount: 0,
        occurredAt: DateTime.utc(2026, 8, 5),
        isMonthlyPayment: false,
      );
      final loan = await loansDao.findById(loanId);
      expect(loan?.closedAt, isNotNull);
      expect(loan?.closeReason, 'paid');
      expect(await loansDao.balanceOf(loanId), 0);
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
        amount: 50000,
        principalAmount: 40000,
        interestAmount: 10000,
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
        amount: 50000,
        principalAmount: 40000,
        interestAmount: 10000,
        occurredAt: DateTime.utc(2026, 8, 1),
        isMonthlyPayment: true,
      );
      await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 50000,
        principalAmount: 50000,
        interestAmount: 0,
        occurredAt: DateTime.utc(2026, 8, 15),
        isMonthlyPayment: false,
      );
      expect(await loansDao.hasMonthlyPaymentIn(loanId, 2026, 8), isTrue);
      await entriesDao.deleteLoanPayment(monthlyId);
      expect(await loansDao.hasMonthlyPaymentIn(loanId, 2026, 8), isFalse);
    });
  });

  group('Bordes de tolerancia 0.005 (hotfix quality-review B7)', () {
    test('overpay: acepta principal = balance + 0.004, rechaza + 0.006',
        () async {
      // balance actual = 5000.
      await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 10000,
        principalAmount: 0,
        interestAmount: 10000,
        occurredAt: DateTime.utc(2026, 8, 5),
        isMonthlyPayment: true,
      );
      // Ahora balance = 5000 (solo interés no toca capital).
      // Aceptar +0.004 (dentro de tolerancia).
      await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 500000,
        principalAmount: 500000,
        interestAmount: 0,
        occurredAt: DateTime.utc(2026, 8, 6),
        isMonthlyPayment: false,
      );
      // Después de este pago el préstamo queda paid.
      // Verificar rechazo con +0.006.
      // Reset con otro préstamo para tener saldo limpio.
      final loan2 = await loansDao.create(
        name: 'X',
        principalAmount: 100000,
        monthlyPayment: 10000,
        initialDurationMonths: 10,
        paymentDay: 5,
        contractDate: DateTime.utc(2026, 7, 15),
        destinationAccountId: bolsaId,
      );
      expect(
        () => entriesDao.registerLoanPayment(
          loanId: loan2,
          accountOriginId: bolsaId,
          amount: 100001,
          principalAmount: 100001,
          interestAmount: 0,
          occurredAt: DateTime.utc(2026, 8, 5),
          isMonthlyPayment: true,
        ),
        throwsA(isA<EntriesDaoError>()
            .having((e) => e.code, 'code', 'overpay_loan')),
      );
    });

    test('invalid_loan_split: acepta diff 0.004, rechaza diff 0.006',
        () async {
      // Aceptar principal + interest fuera por 0.004 (dentro).
      await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 50000,
        principalAmount: 40000,
        interestAmount: 10000, // suma 500.004 vs amount 500 → diff 0.004
        occurredAt: DateTime.utc(2026, 8, 5),
        isMonthlyPayment: true,
      );
      // Rechazar diff 0.006.
      expect(
        () => entriesDao.registerLoanPayment(
          loanId: loanId,
          accountOriginId: bolsaId,
          amount: 10000,
          principalAmount: 5000,
          interestAmount: 5001,
          occurredAt: DateTime.utc(2026, 8, 15),
          isMonthlyPayment: false,
        ),
        throwsA(isA<EntriesDaoError>()
            .having((e) => e.code, 'code', 'invalid_loan_split')),
      );
    });
  });

  group(
      'Monthly con interest=0 (hotfix quality-review B8 — antes proxy '
      'legacy fallaba)', () {
    test(
        'registrar monthly con interest=0 persiste is_monthly_payment=true; '
        'un segundo monthly del mes ya NO se bloquea', () async {
      final id = await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 50000,
        principalAmount: 50000,
        interestAmount: 0,
        occurredAt: DateTime.utc(2026, 8, 5),
        isMonthlyPayment: true,
      );
      final e = await entriesDao.findById(id);
      expect(e?.entry.isMonthlyPayment, isTrue);
      expect(await loansDao.hasMonthlyPaymentIn(loanId, 2026, 8), isTrue);
      // Segundo monthly del mismo mes: antes rechazaba, ahora se acepta.
      final segundo = await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 30000,
        principalAmount: 30000,
        interestAmount: 0,
        occurredAt: DateTime.utc(2026, 8, 20),
        isMonthlyPayment: true,
      );
      expect((await entriesDao.findById(segundo))?.entry.deletedAt, isNull);
      // Capital posterior en el mismo mes: también acepta.
      await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 30000,
        principalAmount: 30000,
        interestAmount: 0,
        occurredAt: DateTime.utc(2026, 8, 20),
        isMonthlyPayment: false,
      );
      expect(await loansDao.countActivePayments(loanId), 3);
      // 500000 - 50000 - 30000 - 30000.
      expect(await loansDao.balanceOf(loanId), 390000);
    });

  });

  group('deleteLoanPayment default (hotfix quality-review B9)', () {
    test(
        'sin cascade preserva capitales del mes (contract: caller '
        'responsable de decidir)', () async {
      final m = await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 50000,
        principalAmount: 40000,
        interestAmount: 10000,
        occurredAt: DateTime.utc(2026, 8, 5),
        isMonthlyPayment: true,
      );
      final c = await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 10000,
        principalAmount: 10000,
        interestAmount: 0,
        occurredAt: DateTime.utc(2026, 8, 15),
        isMonthlyPayment: false,
      );
      await entriesDao.deleteLoanPayment(m); // default: sin cascade
      expect((await entriesDao.findById(m))?.entry.deletedAt, isNotNull);
      expect((await entriesDao.findById(c))?.entry.deletedAt, isNull,
          reason: 'sin cascade el capital queda ACTIVO (aunque huérfano)');
    });
  });

  group('cancel gate sobre loan_income y loan_payment '
      '(hotfix quality-review B10)', () {
    test('cancel() sobre loan_payment lanza immutable_loan_payment',
        () async {
      final id = await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 50000,
        principalAmount: 40000,
        interestAmount: 10000,
        occurredAt: DateTime.utc(2026, 8, 5),
        isMonthlyPayment: true,
      );
      expect(
        () => entriesDao.cancel(id),
        throwsA(isA<EntriesDaoError>()
            .having((e) => e.code, 'code', 'immutable_loan_payment')),
      );
    });

    test('cancel() sobre income inicial del préstamo lanza '
        'immutable_loan_payment', () async {
      final incomeId = await loansDao.findIncomeEntryId(loanId);
      expect(incomeId, isNotNull);
      expect(
        () => entriesDao.cancel(incomeId!),
        throwsA(isA<EntriesDaoError>()
            .having((e) => e.code, 'code', 'immutable_loan_payment')),
      );
    });
  });
}

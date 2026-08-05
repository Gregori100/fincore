// Tests del sprint flutter-loans-flexible-payments-v1: ajustes de saldo de
// préstamo (RN-LF-05 a RN-LF-11).
//
// Un ajuste corrige el saldo pendiente sin tocar `principal_amount`. No es un
// movimiento de dinero: no genera `journal_entry` ni altera BO/DE/CR.

import 'package:drift/native.dart';
import 'package:fincore/data/daos/accounts_dao.dart';
import 'package:fincore/data/daos/categories_dao.dart';
import 'package:fincore/data/daos/entries_dao.dart';
import 'package:fincore/data/daos/loans_dao.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/data/financial_state.dart';
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
    loanId = await loansDao.create(
      name: 'BBVA',
      principalAmount: 500000, // $5,000.00
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

  /// Deja el préstamo liquidado (saldo 0, `close_reason = 'paid'`).
  Future<void> liquidar() async {
    await entriesDao.registerLoanPayment(
      loanId: loanId,
      accountOriginId: bolsaId,
      amount: 500000,
      principalAmount: 500000,
      interestAmount: 0,
      occurredAt: DateTime.utc(2026, 8, 5),
      isMonthlyPayment: true,
    );
  }

  group('balanceOf con ajustes (RN-LF-05)', () {
    test('UT-LF-01: préstamo sin ajustes conserva la fórmula de dos términos',
        () async {
      // Blinda CB-14: `SUM` sobre conjunto vacío devuelve NULL y sin el
      // COALESCE el saldo entero se volvería null.
      expect(await loansDao.balanceOf(loanId), 500000);
      await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 100000,
        principalAmount: 80000,
        interestAmount: 20000,
        occurredAt: DateTime.utc(2026, 8, 5),
        isMonthlyPayment: true,
      );
      expect(await loansDao.balanceOf(loanId), 420000);
    });

    test('UT-LF-02: ajuste positivo sube el saldo sin tocar principal_amount',
        () async {
      await loansDao.registerAdjustment(
        loanId: loanId,
        amount: 10000,
        occurredAt: DateTime.utc(2026, 8, 5),
        reason: 'Ajuste del banco',
      );
      expect(await loansDao.balanceOf(loanId), 510000);
      final loan = await loansDao.findById(loanId);
      expect(loan!.principalAmount, 500000,
          reason: 'el monto originalmente prestado es histórico (RN-LF-06)');
    });

    test('UT-LF-03: ajuste negativo baja el saldo', () async {
      await loansDao.registerAdjustment(
        loanId: loanId,
        amount: -25000,
        occurredAt: DateTime.utc(2026, 8, 5),
      );
      expect(await loansDao.balanceOf(loanId), 475000);
    });

    test('UT-LF-04: dos ajustes de signo opuesto dan el neto', () async {
      await loansDao.registerAdjustment(
          loanId: loanId, amount: 30000, occurredAt: DateTime.utc(2026, 8, 5));
      await loansDao.registerAdjustment(
          loanId: loanId, amount: -10000, occurredAt: DateTime.utc(2026, 8, 6));
      expect(await loansDao.balanceOf(loanId), 520000);
      expect(await loansDao.watchAdjustmentsTotal(loanId).first, 20000);
    });

    test('UT-LF-05: un ajuste eliminado sale del saldo', () async {
      final id = await loansDao.registerAdjustment(
          loanId: loanId, amount: 30000, occurredAt: DateTime.utc(2026, 8, 5));
      expect(await loansDao.balanceOf(loanId), 530000);
      await loansDao.deleteAdjustment(id);
      expect(await loansDao.balanceOf(loanId), 500000);
    });

    test('UT-LF-06: watchBalance reemite al insertar, editar y borrar',
        () async {
      final emissions = <int>[];
      final sub = loansDao.watchBalance(loanId).listen(emissions.add);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final id = await loansDao.registerAdjustment(
          loanId: loanId, amount: 10000, occurredAt: DateTime.utc(2026, 8, 5));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await loansDao.updateAdjustment(
          id: id, amount: 20000, occurredAt: DateTime.utc(2026, 8, 5));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await loansDao.deleteAdjustment(id);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sub.cancel();

      expect(emissions.first, 500000);
      expect(emissions.last, 500000);
      expect(emissions, contains(510000));
      expect(emissions, contains(520000));
    });

    test(
        'el total de préstamos del Dashboard también incluye los ajustes',
        () async {
      // `FinancialStateService._buildTotalLoansSource` duplica la fórmula de
      // saldo en vez de reusar `balanceOf`; este test blinda que las dos
      // copias no diverjan.
      //
      // `watchTotalLoans` es un stream con replay-1: un segundo `.first`
      // devuelve el valor cacheado antes de que la query se recompute, así
      // que hay que escuchar y esperar la emisión nueva.
      final state = FinancialStateService(db);
      final emissions = <int>[];
      final sub = state.watchTotalLoans().listen(emissions.add);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(emissions.last, 500000);

      await loansDao.registerAdjustment(
          loanId: loanId, amount: 10000, occurredAt: DateTime.utc(2026, 8, 5));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();
      expect(emissions.last, 510000);
    });
  });

  group('validaciones (RN-LF-07)', () {
    test('UT-LF-07: monto cero se rechaza y no inserta fila', () async {
      expect(
        () => loansDao.registerAdjustment(
            loanId: loanId, amount: 0, occurredAt: DateTime.utc(2026, 8, 5)),
        throwsA(isA<LoansDaoError>()
            .having((e) => e.code, 'code', 'invalid_adjustment')),
      );
      expect(await loansDao.watchAdjustments(loanId).first, isEmpty);
      expect(await loansDao.balanceOf(loanId), 500000);
    });

    test('UT-LF-08: ajuste negativo que dejaría el saldo bajo cero se rechaza',
        () async {
      expect(
        () => loansDao.registerAdjustment(
            loanId: loanId,
            amount: -600000,
            occurredAt: DateTime.utc(2026, 8, 5)),
        throwsA(isA<LoansDaoError>()
            .having((e) => e.code, 'code', 'invalid_adjustment')),
      );
      expect(await loansDao.watchAdjustments(loanId).first, isEmpty);
    });

    test('UT-LF-09: ajuste que deja el saldo exactamente en cero se acepta',
        () async {
      await loansDao.registerAdjustment(
          loanId: loanId,
          amount: -500000,
          occurredAt: DateTime.utc(2026, 8, 5));
      expect(await loansDao.balanceOf(loanId), 0);
    });

    test('UT-LF-10: ajuste sobre préstamo inexistente lanza not_found',
        () async {
      expect(
        () => loansDao.registerAdjustment(
            loanId: 'no-existe',
            amount: 1000,
            occurredAt: DateTime.utc(2026, 8, 5)),
        throwsA(
            isA<LoansDaoError>().having((e) => e.code, 'code', 'not_found')),
      );
    });

    test('ajuste sobre préstamo archivado lanza not_found', () async {
      await loansDao.deleteLoan(loanId);
      expect(
        () => loansDao.registerAdjustment(
            loanId: loanId,
            amount: 1000,
            occurredAt: DateTime.utc(2026, 8, 5)),
        throwsA(
            isA<LoansDaoError>().having((e) => e.code, 'code', 'not_found')),
      );
    });

    test(
        'UT-LF-11: se permite ajustar un préstamo CERRADO (asimetría vs '
        'loan_closed de los pagos)', () async {
      await liquidar();
      expect((await loansDao.findById(loanId))!.closeReason, 'paid');
      // Un pago aquí rebotaría con `loan_closed`; el ajuste no.
      await loansDao.registerAdjustment(
          loanId: loanId, amount: 10000, occurredAt: DateTime.utc(2026, 9, 1));
      expect(await loansDao.balanceOf(loanId), 10000);
    });

    test(
        'UT-LF-12: se permite occurred_at anterior al contrato (asimetría vs '
        'payment_before_contract)', () async {
      final id = await loansDao.registerAdjustment(
        loanId: loanId,
        amount: 5000,
        // El contrato es del 15/07/2026.
        occurredAt: DateTime.utc(2026, 1, 1),
        reason: 'Corrección del monto original',
      );
      final adj = await loansDao.findAdjustmentById(id);
      expect(adj, isNotNull);
      expect(adj!.occurredAt, DateTime.utc(2026, 1, 1));
    });
  });

  group('updateAdjustment', () {
    test(
        'UT-LF-13: la validación excluye el propio ajuste del saldo base',
        () async {
      // Sin la auto-exclusión, editar de +400000 a +450000 compararía contra
      // un saldo que ya incluye los 400000 y el cálculo daría un resultado
      // distinto del real.
      final id = await loansDao.registerAdjustment(
          loanId: loanId, amount: 400000, occurredAt: DateTime.utc(2026, 8, 5));
      expect(await loansDao.balanceOf(loanId), 900000);
      await loansDao.updateAdjustment(
          id: id, amount: 450000, occurredAt: DateTime.utc(2026, 8, 5));
      expect(await loansDao.balanceOf(loanId), 950000);
    });

    test('editar hasta dejar el saldo en negativo se rechaza y no cambia nada',
        () async {
      final id = await loansDao.registerAdjustment(
          loanId: loanId, amount: -100000, occurredAt: DateTime.utc(2026, 8, 5));
      expect(
        () => loansDao.updateAdjustment(
            id: id, amount: -600000, occurredAt: DateTime.utc(2026, 8, 5)),
        throwsA(isA<LoansDaoError>()
            .having((e) => e.code, 'code', 'invalid_adjustment')),
      );
      expect((await loansDao.findAdjustmentById(id))!.amount, -100000);
      expect(await loansDao.balanceOf(loanId), 400000);
    });

    test('UT-LF-14: cruce de signo positivo → negativo', () async {
      final id = await loansDao.registerAdjustment(
          loanId: loanId, amount: 50000, occurredAt: DateTime.utc(2026, 8, 5));
      await loansDao.updateAdjustment(
          id: id, amount: -50000, occurredAt: DateTime.utc(2026, 8, 5));
      expect(await loansDao.balanceOf(loanId), 450000);
    });

    test('editar a monto cero se rechaza (CB-06)', () async {
      final id = await loansDao.registerAdjustment(
          loanId: loanId, amount: 50000, occurredAt: DateTime.utc(2026, 8, 5));
      expect(
        () => loansDao.updateAdjustment(
            id: id, amount: 0, occurredAt: DateTime.utc(2026, 8, 5)),
        throwsA(isA<LoansDaoError>()
            .having((e) => e.code, 'code', 'invalid_adjustment')),
      );
    });

    test('editar un ajuste inexistente lanza not_found', () async {
      expect(
        () => loansDao.updateAdjustment(
            id: 'no-existe', amount: 100, occurredAt: DateTime.utc(2026, 8, 5)),
        throwsA(
            isA<LoansDaoError>().having((e) => e.code, 'code', 'not_found')),
      );
    });
  });

  group('deleteAdjustment', () {
    test('UT-LF-15: borrado idempotente (CB-08)', () async {
      final id = await loansDao.registerAdjustment(
          loanId: loanId, amount: 10000, occurredAt: DateTime.utc(2026, 8, 5));
      await loansDao.deleteAdjustment(id);
      // Segunda vez: silencioso, sin excepción.
      await loansDao.deleteAdjustment(id);
      expect(await loansDao.balanceOf(loanId), 500000);
    });

    test('borrar un ajuste inexistente lanza not_found', () async {
      expect(
        () => loansDao.deleteAdjustment('no-existe'),
        throwsA(
            isA<LoansDaoError>().having((e) => e.code, 'code', 'not_found')),
      );
    });
  });

  group('transiciones de estado (RN-LF-09, RN-LF-10)', () {
    test('UT-LF-16: ajuste positivo reabre un préstamo cerrado como paid',
        () async {
      await liquidar();
      final antes = await loansDao.findById(loanId);
      expect(antes!.closedAt, isNotNull);
      expect(antes.closeReason, 'paid');

      await loansDao.registerAdjustment(
          loanId: loanId, amount: 10000, occurredAt: DateTime.utc(2026, 9, 1));

      final despues = await loansDao.findById(loanId);
      expect(despues!.closedAt, isNull);
      expect(despues.closeReason, isNull);
    });

    test('UT-LF-17: un préstamo cerrado MANUALMENTE no se reabre por ajuste',
        () async {
      await loansDao.closeManual(loanId);
      expect((await loansDao.findById(loanId))!.closeReason, 'manual');

      await loansDao.registerAdjustment(
          loanId: loanId, amount: 10000, occurredAt: DateTime.utc(2026, 9, 1));

      final loan = await loansDao.findById(loanId);
      expect(loan!.closedAt, isNotNull, reason: 'RN-L13: manual es terminal');
      expect(loan.closeReason, 'manual');
      // El saldo sí se recalcula aunque el estado no cambie.
      expect(await loansDao.balanceOf(loanId), 510000);
    });

    test('UT-LF-18: ajuste negativo que liquida cierra el préstamo como paid',
        () async {
      await loansDao.registerAdjustment(
          loanId: loanId,
          amount: -500000,
          occurredAt: DateTime.utc(2026, 8, 5));
      final loan = await loansDao.findById(loanId);
      expect(loan!.closedAt, isNotNull);
      expect(loan.closeReason, 'paid');
    });

    test(
        'UT-LF-19: borrar un ajuste positivo que sostenía el préstamo abierto '
        'lo cierra', () async {
      await liquidar();
      final adjId = await loansDao.registerAdjustment(
          loanId: loanId, amount: 10000, occurredAt: DateTime.utc(2026, 9, 1));
      expect((await loansDao.findById(loanId))!.closedAt, isNull);

      await loansDao.deleteAdjustment(adjId);

      final loan = await loansDao.findById(loanId);
      expect(loan!.closedAt, isNotNull);
      expect(loan.closeReason, 'paid');
      expect(await loansDao.balanceOf(loanId), 0);
    });

    test('UT-LF-20: ciclo completo cerrar por ajuste → reabrir por edición',
        () async {
      // Nota: el ciclo inverso (reabrir con un ajuste positivo y volver a
      // cerrarlo editándolo) es IMPOSIBLE por diseño — con saldo base 0
      // cualquier edición negativa dispara `invalid_adjustment` y cualquier
      // positiva lo deja abierto. Para ese caso el camino es borrar el
      // ajuste, que cubre UT-LF-19.
      final adjId = await loansDao.registerAdjustment(
          loanId: loanId,
          amount: -500000,
          occurredAt: DateTime.utc(2026, 8, 5));
      expect(await loansDao.balanceOf(loanId), 0);
      expect((await loansDao.findById(loanId))!.closeReason, 'paid');

      // Reducir la magnitud del ajuste devuelve saldo pendiente y reabre.
      await loansDao.updateAdjustment(
          id: adjId, amount: -400000, occurredAt: DateTime.utc(2026, 8, 5));
      expect(await loansDao.balanceOf(loanId), 100000);
      final loan = await loansDao.findById(loanId);
      expect(loan!.closedAt, isNull);
      expect(loan.closeReason, isNull);
    });
  });

  group('interacción con overpay_loan (CB-07 del plan)', () {
    test('un ajuste positivo amplía el capital que admite un pago', () async {
      await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 500000,
        principalAmount: 500000,
        interestAmount: 0,
        occurredAt: DateTime.utc(2026, 8, 5),
        isMonthlyPayment: true,
      );
      // Saldo 0 y préstamo cerrado: el ajuste lo reabre con saldo 30000.
      await loansDao.registerAdjustment(
          loanId: loanId, amount: 30000, occurredAt: DateTime.utc(2026, 9, 1));

      // Un pago de 40000 de capital excede el saldo → sigue rebotando.
      expect(
        () => entriesDao.registerLoanPayment(
          loanId: loanId,
          accountOriginId: bolsaId,
          amount: 40000,
          principalAmount: 40000,
          interestAmount: 0,
          occurredAt: DateTime.utc(2026, 9, 5),
          isMonthlyPayment: false,
        ),
        throwsA(isA<EntriesDaoError>()
            .having((e) => e.code, 'code', 'overpay_loan')),
      );
      // Uno de 30000 cabe exacto.
      await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 30000,
        principalAmount: 30000,
        interestAmount: 0,
        occurredAt: DateTime.utc(2026, 9, 5),
        isMonthlyPayment: false,
      );
      expect(await loansDao.balanceOf(loanId), 0);
    });
  });

  group('aislamiento del estado financiero (RN-LF-08)', () {
    test('un ajuste no genera journal_entry ni mueve el saldo de la cuenta',
        () async {
      final state = FinancialStateService(db);
      final boAntes = await state.watchBo().first;
      final entriesAntes = (await entriesDao.watchPage().first).length;

      await loansDao.registerAdjustment(
          loanId: loanId, amount: 50000, occurredAt: DateTime.utc(2026, 8, 5));

      expect(await state.watchBo().first, boAntes,
          reason: 'un ajuste no mueve dinero de ninguna cuenta');
      expect((await entriesDao.watchPage().first).length, entriesAntes,
          reason: 'un ajuste no aparece en /entries');
    });
  });

  group('cierre manual frente a ajustes (preguntas de Diego 2026-08-05)', () {
    test(
        'un ajuste que liquida un préstamo cerrado MANUALMENTE lo deja en '
        'manual, no lo convierte en paid', () async {
      await loansDao.closeManual(loanId);
      await loansDao.registerAdjustment(
          loanId: loanId,
          amount: -500000,
          occurredAt: DateTime.utc(2026, 8, 5));

      expect(await loansDao.balanceOf(loanId), 0);
      final loan = await loansDao.findById(loanId);
      expect(loan!.closeReason, 'manual',
          reason: 'RN-L13: el cierre manual es terminal frente a automatismos');
      // Consecuencia práctica: sigue siendo reabrible a mano, cosa que un
      // `paid` no permite (`cannot_reopen_paid`).
      await loansDao.reopen(loanId);
      expect((await loansDao.findById(loanId))!.closedAt, isNull);
    });

    test(
        'tras reabrir a mano un préstamo manual, la política automática '
        'vuelve a aplicar', () async {
      await loansDao.closeManual(loanId);
      await loansDao.reopen(loanId);
      expect((await loansDao.findById(loanId))!.closeReason, isNull);

      await loansDao.registerAdjustment(
          loanId: loanId,
          amount: -500000,
          occurredAt: DateTime.utc(2026, 8, 7));
      final loan = await loansDao.findById(loanId);
      expect(await loansDao.balanceOf(loanId), 0);
      expect(loan!.closeReason, 'paid');
    });

    test(
        'un ajuste reabre un préstamo paid aunque `reopen` manual lo prohíba '
        '(asimetría deliberada)', () async {
      await liquidar();
      expect(
        () => loansDao.reopen(loanId),
        throwsA(isA<LoansDaoError>()
            .having((e) => e.code, 'code', 'cannot_reopen_paid')),
        reason: 'la vía manual sigue bloqueada',
      );
      // La vía del ajuste sí lo reabre: refleja un hecho externo (el banco
      // dice que aún debes), no un capricho del usuario.
      await loansDao.registerAdjustment(
          loanId: loanId, amount: 5000, occurredAt: DateTime.utc(2026, 9, 1));
      expect((await loansDao.findById(loanId))!.closedAt, isNull);
    });

    test(
        'borrar un ajuste positivo cuyo margen ya fue consumido por pagos NO '
        'deja el saldo en negativo', () async {
      // Escenario: el ajuste amplía el saldo, el usuario paga hasta agotarlo,
      // y después borra el ajuste. Sin guarda, el saldo quedaría en -100000.
      final adjId = await loansDao.registerAdjustment(
          loanId: loanId, amount: 100000, occurredAt: DateTime.utc(2026, 8, 1));
      expect(await loansDao.balanceOf(loanId), 600000);
      await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsaId,
        amount: 600000,
        principalAmount: 600000,
        interestAmount: 0,
        occurredAt: DateTime.utc(2026, 8, 5),
        isMonthlyPayment: true,
      );
      expect(await loansDao.balanceOf(loanId), 0);

      expect(
        () => loansDao.deleteAdjustment(adjId),
        throwsA(isA<LoansDaoError>()
            .having((e) => e.code, 'code', 'invalid_adjustment')),
      );
      expect(await loansDao.balanceOf(loanId), 0,
          reason: 'el ajuste sigue vigente y el saldo no se corrompió');
    });
  });

  group('cascada al eliminar el préstamo (hallazgo B1 de la revisión)', () {
    test(
        'B1: deleteLoan cascadea a loan_adjustments', () async {
      await loansDao.registerAdjustment(
          loanId: loanId, amount: 10000, occurredAt: DateTime.utc(2026, 8, 5));
      await loansDao.registerAdjustment(
          loanId: loanId, amount: -3000, occurredAt: DateTime.utc(2026, 8, 6));

      await loansDao.deleteLoan(loanId);

      final rows = await db.select(db.loanAdjustments).get();
      expect(rows, hasLength(2), reason: 'soft delete, no borrado físico');
      for (final r in rows) {
        expect(r.deletedAt, isNotNull,
            reason: 'sin la cascada, el export emitía ajustes huérfanos y el '
                'respaldo resultante no se podía importar');
      }
      expect(await loansDao.watchAdjustments(loanId).first, isEmpty);
    });

    test('B1: `countActiveAdjustments` alimenta el diálogo destructivo',
        () async {
      expect(await loansDao.countActiveAdjustments(loanId), 0);
      await loansDao.registerAdjustment(
          loanId: loanId, amount: 10000, occurredAt: DateTime.utc(2026, 8, 5));
      await loansDao.registerAdjustment(
          loanId: loanId, amount: -3000, occurredAt: DateTime.utc(2026, 8, 6));
      expect(await loansDao.countActiveAdjustments(loanId), 2);
      await loansDao.deleteLoan(loanId);
      expect(await loansDao.countActiveAdjustments(loanId), 0);
    });
  });

  group('longitud del motivo (hallazgo M1 de la revisión)', () {
    test('un motivo de más de 200 caracteres se rechaza en el alta', () async {
      expect(
        () => loansDao.registerAdjustment(
          loanId: loanId,
          amount: 10000,
          occurredAt: DateTime.utc(2026, 8, 5),
          reason: 'x' * 201,
        ),
        throwsA(isA<LoansDaoError>()
            .having((e) => e.code, 'code', 'invalid_adjustment')),
      );
      expect(await loansDao.watchAdjustments(loanId).first, isEmpty);
    });

    test('exactamente 200 caracteres se acepta', () async {
      final id = await loansDao.registerAdjustment(
        loanId: loanId,
        amount: 10000,
        occurredAt: DateTime.utc(2026, 8, 5),
        reason: 'x' * 200,
      );
      expect((await loansDao.findAdjustmentById(id))!.reason!.length, 200);
    });

    test('la edición aplica el mismo límite', () async {
      final id = await loansDao.registerAdjustment(
          loanId: loanId, amount: 10000, occurredAt: DateTime.utc(2026, 8, 5));
      expect(
        () => loansDao.updateAdjustment(
          id: id,
          amount: 10000,
          occurredAt: DateTime.utc(2026, 8, 5),
          reason: 'x' * 201,
        ),
        throwsA(isA<LoansDaoError>()
            .having((e) => e.code, 'code', 'invalid_adjustment')),
      );
    });
  });
}

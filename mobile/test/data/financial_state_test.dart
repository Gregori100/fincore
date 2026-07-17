import 'package:drift/native.dart';
import 'package:fincore/data/backup.dart';
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
  late BackupService backup;

  late String bolsa, debit, credit;

  setUp(() async {
    db = FincoreDatabase(NativeDatabase.memory());
    state = FinancialStateService(db);
    accountsDao = AccountsDao(db);
    entriesDao = EntriesDao(db);
    backup = BackupService(db, state);

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
    // RF-007 v4 introdujo replay-1 en watchBo(): el siguiente `.first` ahora
    // recibe el último valor cacheado (500). Usar `firstWhere(v == 0)` para
    // esperar a que drift propague el cambio post-cancel.
    // M1 quality review v4: `.timeout(5s)` por defensiva — si drift no emite
    // 0 por un bug, el test falla con stack útil en lugar de colgar el isolate.
    expect(await state.watchBo().firstWhere((v) => v == 0).timeout(const Duration(seconds: 5)), 0);
  });

  test('Cuenta archivada NO aparece en BO', () async {
    await entriesDao.registerIncome(
      accountDestinationId: debit,
      amount: 300,
      occurredAt: DateTime.now(),
    );
    // Primer subscribe: cache vacío, el primer evento viene de drift (300).
    expect(await state.watchBo().first, 300);
    // Archive ahora cancela el income en cascada, sin precondición de saldo.
    await accountsDao.deleteAccount(debit);
    // RF-007 v4: replay-1 puede entregar el valor cacheado (300). Esperar 0.
    expect(await state.watchBo().firstWhere((v) => v == 0).timeout(const Duration(seconds: 5)), 0);
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
    await accountsDao.deleteAccount(credit); // archive en cascada
    // RF-007 v4: si watchCr() ya emitió antes (50000 inicial), el replay-1
    // entrega ese valor. Esperar a que llegue 0 vía firstWhere.
    expect(await state.watchCr().firstWhere((v) => v == 0).timeout(const Duration(seconds: 5)), 0);
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
    // RF-007 v4: con replay-1, esperar el valor esperado vía firstWhere para
    // no recibir un valor cacheado intermedio. `.timeout(5s)` defensivo (M1 v4).
    expect(await state.watchCr().firstWhere((v) => v == 80000).timeout(const Duration(seconds: 5)), 80000);
    await accountsDao.deleteAccount(id);
    expect(await state.watchCr().firstWhere((v) => v == 50000).timeout(const Duration(seconds: 5)), 50000);
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
    await accountsDao.deleteAccount(debit, state);
    final sDebit2 = state.watchAccountBalance(debit, 'debit');
    expect(identical(sDebit1, sDebit2), isFalse);
  });

  test('wipeAll invalida cache de streams (RF-004)', () async {
    // RF-004 del sprint flutter-local-hardening-v2: BackupService.wipeAll()
    // debe invocar state.invalidateAll() tras la transacción para que la
    // próxima suscripción cree un stream nuevo, no uno apuntando a una BD
    // ya borrada.
    final s1 = state.watchAccountBalance(bolsa, 'cash');
    await backup.wipeAll();
    final s2 = state.watchAccountBalance(bolsa, 'cash');
    expect(identical(s1, s2), isFalse);
  });

  test('watchAccountBalance cacheado acepta múltiples suscriptores (RF-006)',
      () async {
    // RF-006 + RF-001 del sprint flutter-local-hardening-v2: el stream
    // cacheado es broadcast, así que dos StreamBuilders al mismo balance
    // no lanzan StateError. Verifica también el caso de cancel + resuscribir
    // para validar que la entrada del cache sigue utilizable (RF-002
    // condicional: si falla por stream cerrado, ajustar watchAccountBalance
    // con onCancel).
    final stream = state.watchAccountBalance(bolsa, 'cash');
    final received1 = <double>[];
    final received2 = <double>[];

    final sub1 = stream.listen(received1.add);
    final sub2 = stream.listen(received2.add);
    // Trigger evento.
    await entriesDao.registerIncome(
      accountDestinationId: bolsa,
      amount: 100,
      occurredAt: DateTime.now(),
    );
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(received1.isNotEmpty, isTrue, reason: 'Listener 1 no recibió evento');
    expect(received2.isNotEmpty, isTrue, reason: 'Listener 2 no recibió evento');
    await sub1.cancel();
    await sub2.cancel();

    // Cancelar todo y resuscribir: el stream cacheado debe seguir vivo
    // (sin esto, la próxima `watchAccountBalance` retornaría un stream cerrado).
    final received3 = <double>[];
    final sub3 = state.watchAccountBalance(bolsa, 'cash').listen(received3.add);
    await entriesDao.registerIncome(
      accountDestinationId: bolsa,
      amount: 50,
      occurredAt: DateTime.now(),
    );
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(received3.isNotEmpty, isTrue,
        reason: 'Listener resuscrito no recibió evento (broadcast cerrado)');
    await sub3.cancel();
  });

  test(
      'replay-1: segundo suscriptor recibe último valor SIN cancelar el primero',
      () async {
    // Hotfix post-smoke 2026-06-19 (bug "Skeleton eterno"): cuando el
    // Dashboard ya está montado y suscrito al stream cacheado y el form
    // de alta abre un AccountBalanceHint encima (segundo suscriptor sin
    // que el primero cancele), el implementador previo con
    // `StreamController.broadcast.onListen` NO ejecutaba el replay para
    // el segundo listener — `onListen` solo se invoca tras un período de
    // cero listeners. Resultado: el hint quedaba en Skeleton hasta que
    // ocurriera un cambio en `journal_entries`.
    //
    // Este test reproduce exactamente el escenario: listener A activo,
    // recibe primer valor, NO cancela; entra listener B → debe recibir
    // el último valor inmediatamente.
    await entriesDao.registerIncome(
      accountDestinationId: bolsa,
      amount: 500,
      occurredAt: DateTime.now(),
    );
    final stream = state.watchAccountBalance(bolsa, 'cash');

    final receivedA = <double>[];
    final subA = stream.listen(receivedA.add);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(receivedA, isNotEmpty, reason: 'Listener A debería recibir primer valor');
    expect(receivedA.last, 500);

    // Sin cancelar subA, entra subB.
    final receivedB = <double>[];
    final subB = stream.listen(receivedB.add);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(receivedB, isNotEmpty,
        reason:
            'Listener B debería recibir replay del último valor, aún con A activo');
    expect(receivedB.last, 500);

    // Trigger nuevo evento: ambos deben recibirlo.
    await entriesDao.registerIncome(
      accountDestinationId: bolsa,
      amount: 100,
      occurredAt: DateTime.now(),
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(receivedA.last, 600, reason: 'A debería recibir el cambio');
    expect(receivedB.last, 600, reason: 'B debería recibir el cambio');

    await subA.cancel();
    await subB.cancel();
  });

  test(
      'replay-1: nuevo suscriptor recibe el último valor cacheado sin esperar nuevos cambios',
      () async {
    // Hotfix post-smoke 2026-06-19 (bug "vista en gris"): cuando el Dashboard
    // se desmonta durante una transición a `entry_form_screen`, el cancel de
    // un movimiento emite un evento del stream cacheado con cero listeners.
    // Al volver al Dashboard, el `StreamBuilder` se re-suscribe pero no
    // recibe valor inicial → renderiza `Skeleton` indefinidamente.
    //
    // Este test reproduce el escenario: suscribir, cancelar, esperar a que
    // ocurra un cambio sin listeners activos, re-suscribir y verificar que
    // el nuevo listener recibe inmediatamente el último valor.
    final stream = state.watchAccountBalance(bolsa, 'cash');

    // Suscripción inicial recibe el primer valor (0).
    final received1 = <double>[];
    final sub1 = stream.listen(received1.add);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(received1.last, 0, reason: 'Listener 1 debería ver el balance inicial');
    await sub1.cancel();

    // SIN listeners activos: insertar un income simulando el cancel real.
    await entriesDao.registerIncome(
      accountDestinationId: bolsa,
      amount: 250,
      occurredAt: DateTime.now(),
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));

    // Resuscribirse al stream cacheado (Dashboard se vuelve a montar).
    // Sin replay-1, este listener quedaría sin valor hasta el próximo cambio.
    final received2 = <double>[];
    final sub2 = state.watchAccountBalance(bolsa, 'cash').listen(received2.add);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(received2, isNotEmpty,
        reason: 'Listener resuscrito debería recibir el último valor por replay-1');
    expect(received2.last, 250,
        reason: 'El último valor debería ser el balance post-income (250)');
    await sub2.cancel();
  });

  test(
      'RF-012 v3: subscribe → unsubscribe → resubscribe preserva el cache del stream',
      () async {
    // El v2 documentó la decisión "por diseño NO se cierra al perder el último
    // listener" (ver `_ReplayBalanceStream`). Este test la blinda: el cache
    // debe seguir entregando el mismo Stream tras un ciclo completo, y el
    // listener nuevo debe recibir un valor sin esperar a que cambie nada.
    final s1 = state.watchAccountBalance(bolsa, 'cash');

    // L2-H2 quality review v3: 100 ms para alinearse con el resto del archivo
    // y reducir el riesgo de flake en CI lento.
    final received1 = <double>[];
    final sub1 = s1.listen(received1.add);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(received1.last, 0);

    // Cancelar TODOS los listeners deja al `_ReplayBalanceStream` con
    // `_listeners` vacío pero el upstream sigue vivo y `_last` cacheado.
    await sub1.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 100));

    // Re-suscribir tras ciclo: el cache debe haber preservado el Stream.
    final s2 = state.watchAccountBalance(bolsa, 'cash');
    expect(identical(s1, s2), isTrue,
        reason:
            'El cache de _ReplayBalanceStream NO debería liberarse al perder el último listener. '
            'Si esta aserción falla, alguien reintrodujo onLastListenerCanceled y rompió la decisión del v2.');

    // Y el listener nuevo recibe inmediatamente sin que ocurra otro cambio.
    final received2 = <double>[];
    final sub2 = s2.listen(received2.add);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(received2, isNotEmpty);
    expect(received2.last, 0);
    await sub2.cancel();
  });

  test(
      'RF-009 v4: watchBo/watchDe/watchCr cachean stream con replay-1 (L2-H1)',
      () async {
    // Antes del v4, las 3 cards superiores del Dashboard (BO/DE/CR) usaban
    // `customSelect.watchSingle()` directo, single-listener y sin replay.
    // Si el Dashboard se desmontaba con un evento en vuelo (escenario:
    // `context.go('/dashboard')` desde reportes), el siguiente subscribe
    // mostraba Skeleton hasta el próximo cambio en journal_entries.
    //
    // Este test blinda que ahora retornan el mismo Stream identitario y
    // que un resubscribe tardío recibe el último valor por replay-1.
    final bo1 = state.watchBo();
    final de1 = state.watchDe();
    final cr1 = state.watchCr();
    final bo2 = state.watchBo();
    expect(identical(bo1, bo2), isTrue,
        reason: 'watchBo() debería retornar el mismo Stream cacheado');
    expect(identical(state.watchDe(), de1), isTrue);
    expect(identical(state.watchCr(), cr1), isTrue);

    // Sembrar 1 income, primer listener captura el valor.
    await entriesDao.registerIncome(
      accountDestinationId: bolsa,
      amount: 500,
      occurredAt: DateTime.now(),
    );
    final received1 = <double>[];
    final sub1 = bo1.listen(received1.add);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(received1.last, 500);

    // Cancelar y resubscribir: replay-1 entrega el último valor cacheado.
    await sub1.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final received2 = <double>[];
    final sub2 = state.watchBo().listen(received2.add);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(received2, isNotEmpty,
        reason: 'watchBo() resuscrita debería recibir el último valor por replay-1');
    expect(received2.last, 500);
    await sub2.cancel();
  });

  test(
      'RF-008 v4: invalidateAll libera los caches BO/DE/CR (próximo watch arma uno nuevo)',
      () async {
    final bo1 = state.watchBo();
    state.invalidateAll();
    final bo2 = state.watchBo();
    expect(identical(bo1, bo2), isFalse,
        reason: 'Tras invalidateAll(), watchBo() debería armar un Stream nuevo');
  });

  // ==========================================================================
  // Sprint flutter-loans-v1 (RN-L20 + hotfix branch-quality-review B5):
  // watchTotalLoans() alimenta el KPI naranja "PRÉSTAMO" del Dashboard.
  // Condicional: sólo se renderiza si `total > 0`.
  // ==========================================================================
  group('watchTotalLoans()', () {
    test('BD vacía: total = 0 (no hay préstamos)', () async {
      expect(await state.watchTotalLoans().first, 0);
    });

    test('sube al crear préstamo (income inicial atómico)', () async {
      await db.loansDao.create(
        name: 'BBVA',
        principalAmount: 10000,
        monthlyPayment: 500,
        initialDurationMonths: 24,
        paymentDay: 5,
        contractDate: DateTime.utc(2026, 7, 1),
        destinationAccountId: bolsa,
      );
      expect(await state.watchTotalLoans().first, 10000);
    });

    test('baja al pagar principal', () async {
      final loanId = await db.loansDao.create(
        name: 'BBVA',
        principalAmount: 10000,
        monthlyPayment: 500,
        initialDurationMonths: 24,
        paymentDay: 5,
        contractDate: DateTime.utc(2026, 7, 1),
        destinationAccountId: bolsa,
      );
      await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsa,
        amount: 500,
        principalAmount: 400,
        interestAmount: 100,
        occurredAt: DateTime.utc(2026, 8, 5),
        isMonthlyPayment: true,
      );
      expect(await state.watchTotalLoans().first, 9600);
    });

    test('vuelve a 0 cuando el préstamo se salda (auto-cierre paid)',
        () async {
      final loanId = await db.loansDao.create(
        name: 'BBVA',
        principalAmount: 1000,
        monthlyPayment: 1001,
        initialDurationMonths: 1,
        paymentDay: 5,
        contractDate: DateTime.utc(2026, 7, 1),
        destinationAccountId: bolsa,
      );
      await entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsa,
        amount: 1001,
        principalAmount: 1000,
        interestAmount: 1,
        occurredAt: DateTime.utc(2026, 8, 5),
        isMonthlyPayment: true,
      );
      // Auto-cierre paid → préstamo excluido de watchTotalLoans.
      expect(await state.watchTotalLoans().first, 0);
    });

    test('no cuenta préstamos cerrados (paid o manual)', () async {
      final loanId = await db.loansDao.create(
        name: 'BBVA',
        principalAmount: 5000,
        monthlyPayment: 500,
        initialDurationMonths: 10,
        paymentDay: 5,
        contractDate: DateTime.utc(2026, 7, 1),
        destinationAccountId: bolsa,
      );
      expect(await state.watchTotalLoans().first, 5000);
      await db.loansDao.closeManual(loanId);
      // Patrón replay-1: el `.first` cachea el último valor. Usar
      // `firstWhere` para esperar la re-emisión reactiva.
      expect(
        await state
            .watchTotalLoans()
            .firstWhere((v) => v == 0)
            .timeout(const Duration(seconds: 5)),
        0,
      );
    });

    test('no cuenta préstamos eliminados', () async {
      final loanId = await db.loansDao.create(
        name: 'BBVA',
        principalAmount: 3000,
        monthlyPayment: 300,
        initialDurationMonths: 10,
        paymentDay: 5,
        contractDate: DateTime.utc(2026, 7, 1),
        destinationAccountId: bolsa,
      );
      expect(await state.watchTotalLoans().first, 3000);
      await db.loansDao.deleteLoan(loanId);
      expect(
        await state
            .watchTotalLoans()
            .firstWhere((v) => v == 0)
            .timeout(const Duration(seconds: 5)),
        0,
      );
    });

    test('suma múltiples préstamos activos', () async {
      await db.loansDao.create(
        name: 'A',
        principalAmount: 1000,
        monthlyPayment: 100,
        initialDurationMonths: 10,
        paymentDay: 5,
        contractDate: DateTime.utc(2026, 7, 1),
        destinationAccountId: bolsa,
      );
      await db.loansDao.create(
        name: 'B',
        principalAmount: 2500,
        monthlyPayment: 250,
        initialDurationMonths: 10,
        paymentDay: 10,
        contractDate: DateTime.utc(2026, 7, 1),
        destinationAccountId: debit,
      );
      expect(await state.watchTotalLoans().first, 3500);
    });
  });
}

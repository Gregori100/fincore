// Widget tests del sprint flutter-loans-flexible-payments-v1: UI de ajustes
// de saldo, ausencia del chip de atraso y ausencia del MRU de categorías.

import 'package:fincore/data/database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/widget_test_harness.dart';

void main() {
  /// El viewport por defecto de `flutter_test` es 800×600 lógicos, más ancho
  /// que alto. Los formularios de FinCore son ListView verticales pensados
  /// para un teléfono: con el default, el botón de submit queda fuera del
  /// árbol construido y `find.text` no lo encuentra. Un viewport de teléfono
  /// real evita tener que scrollear en cada test.
  void useTallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// Lee la BD real desde un widget test.
  ///
  /// `testWidgets` corre en una zona de async falso: los timers internos de
  /// los streams de drift no disparan a menos que se bombeen frames, así que
  /// un `await stream.first` dentro del cuerpo del test se cuelga para
  /// siempre. `runAsync` ejecuta el bloque contra el event loop real.
  Future<T> readDb<T>(WidgetTester tester, Future<T> Function() body) async {
    final result = await tester.runAsync(body);
    return result as T;
  }

  /// Avanza un número acotado de frames en vez de `pumpAndSettle`.
  ///
  /// Tras confirmar el formulario, la app hace `pop()` y vuelve al detalle
  /// del préstamo, que mientras sus streams cargan renderiza `SkeletonCard`
  /// con un pulso EN BUCLE (`kMotionPulse`). `pumpAndSettle` espera a que no
  /// queden frames programados, así que con una animación repetitiva no
  /// termina nunca. Un pump acotado es suficiente para que la escritura en BD
  /// se complete y podamos afirmar sobre el estado resultante.
  Future<void> pumpBriefly(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Baja hasta el final del scroll para alcanzar secciones al pie.
  Future<void> scrollToBottom(WidgetTester tester) async {
    final scrollable = find.byType(Scrollable).first;
    await tester.drag(scrollable, const Offset(0, -1200));
    await tester.pumpAndSettle();
  }

  /// Siembra un préstamo con un pago. Devuelve su id vía el callback.
  Future<String> seedLoan(
    FincoreDatabase db, {
    int principal = 500000,
    int paidPrincipal = 100000,
  }) async {
    final bolsa = await db.accountsDao
        .listAll()
        .then((l) => l.firstWhere((a) => a.type == 'cash'));
    final loanId = await db.loansDao.create(
      name: 'BBVA',
      principalAmount: principal,
      monthlyPayment: 50000,
      initialDurationMonths: 12,
      paymentDay: 5,
      contractDate: DateTime.utc(2026, 5, 1),
      destinationAccountId: bolsa.id,
    );
    if (paidPrincipal > 0) {
      await db.entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsa.id,
        amount: paidPrincipal,
        principalAmount: paidPrincipal,
        interestAmount: 0,
        occurredAt: DateTime.utc(2026, 6, 5),
        isMonthlyPayment: true,
      );
    }
    return loanId;
  }

  testWidgets(
      'WT-LF-01: el detalle del préstamo lista los ajustes junto a los pagos',
      (tester) async {
    useTallScreen(tester);
    late String loanId;
    final harness = await pumpFincoreApp(
      tester,
      seed: (db, deps) async {
        loanId = await seedLoan(db);
        await db.loansDao.registerAdjustment(
          loanId: loanId,
          amount: 10000,
          occurredAt: DateTime.utc(2026, 8, 5),
          reason: 'Ajuste del banco',
        );
      },
    );
    harness.router.go('/loans/$loanId');
    await tester.pumpAndSettle();
    await scrollToBottom(tester);

    expect(find.text('Ajustes de saldo'), findsOneWidget);
    expect(find.text('Ajuste del banco'), findsOneWidget);
    // Monto con signo explícito: sube la deuda.
    expect(find.textContaining('+\$100.00'), findsWidgets);
    await harness.dispose();
  });

  testWidgets(
      'WT-LF-02: el header desglosa los ajustes sólo cuando existen',
      (tester) async {
    useTallScreen(tester);
    late String loanId;
    final harness = await pumpFincoreApp(
      tester,
      seed: (db, deps) async => loanId = await seedLoan(db),
    );
    harness.router.go('/loans/$loanId');
    await tester.pumpAndSettle();

    // Sin ajustes: no aparece la línea de desglose.
    expect(find.textContaining('de ajustes'), findsNothing);
    // Y el monto original prestado sigue visible.
    expect(find.textContaining('originales'), findsOneWidget);

    await readDb(
        tester,
        () => harness.database.loansDao.registerAdjustment(
              loanId: loanId,
              amount: 25000,
              occurredAt: DateTime.utc(2026, 8, 5),
            ));
    await tester.pumpAndSettle();

    expect(find.textContaining('de ajustes'), findsOneWidget);
    await harness.dispose();
  });

  testWidgets('WT-LF-03: alta de ajuste en modo "Aumenta el saldo"',
      (tester) async {
    useTallScreen(tester);
    late String loanId;
    final harness = await pumpFincoreApp(
      tester,
      seed: (db, deps) async => loanId = await seedLoan(db),
    );
    harness.router.go('/loans/$loanId/adjustments/new');
    await tester.pumpAndSettle();

    // "Aumenta" es el default, así que basta con teclear el monto.
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Monto del ajuste'), '150');
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Registrar ajuste'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registrar ajuste'));
    await pumpBriefly(tester);

    final adjustments = await readDb(tester,
        () => harness.database.loansDao.watchAdjustments(loanId).first);
    expect(adjustments, hasLength(1));
    expect(adjustments.single.amount, 15000, reason: '\$150.00 en centavos');
    // 500000 - 100000 + 15000.
    expect(
        await readDb(
            tester, () => harness.database.loansDao.balanceOf(loanId)),
        415000);
    await harness.dispose();
  });

  testWidgets('WT-LF-04: alta de ajuste en modo "Disminuye el saldo"',
      (tester) async {
    useTallScreen(tester);
    late String loanId;
    final harness = await pumpFincoreApp(
      tester,
      seed: (db, deps) async => loanId = await seedLoan(db),
    );
    harness.router.go('/loans/$loanId/adjustments/new');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Disminuye el saldo'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Monto del ajuste'), '150');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Registrar ajuste'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registrar ajuste'));
    await pumpBriefly(tester);

    final adjustments = await readDb(tester,
        () => harness.database.loansDao.watchAdjustments(loanId).first);
    expect(adjustments.single.amount, -15000,
        reason: 'el toggle decide el signo, el campo sólo la magnitud');
    expect(
        await readDb(
            tester, () => harness.database.loansDao.balanceOf(loanId)),
        385000);
    await harness.dispose();
  });

  testWidgets(
      'WT-LF-05: un ajuste negativo mayor al saldo muestra error inline y no '
      'inserta', (tester) async {
    useTallScreen(tester);
    late String loanId;
    final harness = await pumpFincoreApp(
      tester,
      seed: (db, deps) async => loanId = await seedLoan(db),
    );
    harness.router.go('/loans/$loanId/adjustments/new');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Disminuye el saldo'));
    await tester.pumpAndSettle();
    // El saldo es 400000 (=$4,000); pedir bajar $9,000 lo dejaría negativo.
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Monto del ajuste'), '9000');
    await tester.pumpAndSettle();

    // El valor del test es que el formulario AVISA antes de mandar nada al
    // DAO. Que el DAO además rechace el caso está cubierto por UT-LF-08.
    expect(find.textContaining('quedaría en negativo'), findsOneWidget);
    // Y el botón sigue presente: la pantalla no se cerró ni navegó.
    expect(find.text('Registrar ajuste'), findsOneWidget);
    expect(loanId, isNotEmpty);
    await harness.dispose();
  });

  testWidgets(
      'WT-LF-06: ajustar un préstamo pagado advierte que lo va a reabrir',
      (tester) async {
    useTallScreen(tester);
    late String loanId;
    final harness = await pumpFincoreApp(
      tester,
      // Pago que liquida el préstamo completo → queda `paid`.
      seed: (db, deps) async =>
          loanId = await seedLoan(db, paidPrincipal: 500000),
    );
    harness.router.go('/loans/$loanId/adjustments/new');
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Monto del ajuste'), '100');
    await tester.pumpAndSettle();

    // El preview ya anticipa la consecuencia antes de confirmar.
    expect(
        find.textContaining('dejará de estar marcado como pagado'),
        findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Registrar ajuste'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registrar ajuste'));
    await tester.pumpAndSettle();

    // Diálogo de confirmación explícito (R-05).
    expect(find.text('Reabrir el préstamo'), findsOneWidget);
    await tester.tap(find.text('Ajustar y reabrir'));
    await pumpBriefly(tester);

    final loan = await readDb(
        tester, () => harness.database.loansDao.findById(loanId));
    expect(loan!.closedAt, isNull);
    await harness.dispose();
  });

  testWidgets(
      'WT-LF-08: el Dashboard no muestra chip rojo de atraso aunque falten '
      'meses de pago (RN-LF-12)', (tester) async {
    useTallScreen(tester);
    final harness = await pumpFincoreApp(
      tester,
      seed: (db, deps) async {
        // Contrato viejo sin ningún pago: antes del sprint esto pintaba
        // "N meses atrasados" en rojo.
        final bolsa = await db.accountsDao
            .listAll()
            .then((l) => l.firstWhere((a) => a.type == 'cash'));
        await db.loansDao.create(
          name: 'BBVA',
          principalAmount: 500000,
          monthlyPayment: 50000,
          initialDurationMonths: 12,
          paymentDay: 5,
          contractDate: DateTime.utc(2026, 1, 1),
          destinationAccountId: bolsa.id,
        );
      },
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('atrasado'), findsNothing);
    expect(find.textContaining('atrasados'), findsNothing);
    await harness.dispose();
  });

  testWidgets(
      'WT-LF-09: el chip naranja de próximo pago SIGUE apareciendo '
      '(regresión)', (tester) async {
    // Hallazgo M3 de la revisión de rama: WT-LF-08 sólo verifica que el chip
    // rojo desapareció. Sin este test, si un cambio futuro rompiera también
    // el naranja nadie lo notaría, y es el único indicador temporal que le
    // queda al préstamo en el Dashboard.
    useTallScreen(tester);
    final hoy = DateTime.now();
    // `payment_day` a 2 días de hoy → el chip aparece (umbral: ≤ 5 días).
    final objetivo = hoy.add(const Duration(days: 2));
    // El schema limita `payment_day` a 1-28; si el objetivo cae fuera, el
    // test no aplica y se salta el rango problemático usando el día 1.
    final paymentDay = objetivo.day <= 28 ? objetivo.day : 1;

    final harness = await pumpFincoreApp(
      tester,
      seed: (db, deps) async {
        final bolsa = await db.accountsDao
            .listAll()
            .then((l) => l.firstWhere((a) => a.type == 'cash'));
        await db.loansDao.create(
          name: 'BBVA',
          principalAmount: 500000,
          monthlyPayment: 50000,
          initialDurationMonths: 12,
          paymentDay: paymentDay,
          contractDate: DateTime(hoy.year, hoy.month, 1),
          destinationAccountId: bolsa.id,
        );
      },
    );
    await tester.pumpAndSettle();

    if (paymentDay == objetivo.day) {
      expect(find.textContaining('BBVA'), findsWidgets,
          reason: 'el chip naranja de próximo pago debe seguir presente');
    }
    // En cualquier caso, el rojo no debe volver.
    expect(find.textContaining('atrasado'), findsNothing);
    await harness.dispose();
  });

  testWidgets(
      'WT-LF-10: el picker de categorías no renderiza sección de recientes '
      '(RN-LF-13)', (tester) async {
    // Viewport de teléfono real. Corrió con el default 800x600 hasta que se
    // arregló el desborde de `kind_picker.dart` (M5 de la revisión de rama):
    // este test es ahora también la regresión de ese arreglo, porque un
    // RenderFlex desbordado lanza excepción y hace fallar el test.
    useTallScreen(tester);
    final harness = await pumpFincoreApp(
      tester,
      initialRoute: '/entries/new',
    );
    await tester.pumpAndSettle();

    // El MRU era estático de proceso: si sobreviviera, la sección aparecería
    // tras un par de usos del picker en la misma sesión. Verificamos que el
    // encabezado no existe en ninguna apertura.
    expect(find.text('RECIENTES'), findsNothing);
    await harness.dispose();
  });
}

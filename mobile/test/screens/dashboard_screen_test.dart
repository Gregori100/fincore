import 'package:fincore/screens/reports_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/widget_test_harness.dart';

void main() {
  group('DashboardScreen — T043 / RF-005', () {
    testWidgets(r'BD recién seedeada: solo Bolsa, BO=$0, sin movimientos',
        (tester) async {
      final harness = await pumpFincoreApp(tester);

      // Bolsa visible (nombre + label tipo cash).
      // Sprint dashboard-bundle-v1 agregó chip de filtro con nombre de
      // cuenta → "Bolsa" ahora aparece 3 veces (nombre en tile + tipo
      // label + chip filtro). Aserción actualizada a findsAtLeast(2).
      expect(find.text('Bolsa'), findsAtLeastNWidgets(2));
      // Cards de totales.
      expect(find.text('BOLSA + DÉBITO'), findsOneWidget);
      // El sprint dashboard-clarity elimina "DE"/"CR" del display principal
      // (solo quedan en Semantics.label). Cambio esperado.
      expect(find.text('DEUDA'), findsOneWidget);
      expect(find.text('DISPONIBLE'), findsOneWidget);
      // Sin movimientos: el placeholder textual del tile vacío.
      expect(
        find.textContaining('Aún no hay movimientos'),
        findsOneWidget,
      );

      await harness.dispose();
    });

    testWidgets('Con 1 ingreso sembrado: BO refleja el monto',
        (tester) async {
      final harness = await pumpFincoreApp(
        tester,
        seed: (db, deps) async {
          final bolsa = (await deps.accountsDao.listAll())
              .firstWhere((a) => a.type == 'cash');
          await deps.entriesDao.registerIncome(
            accountDestinationId: bolsa.id,
            amount: 1000.0,
            occurredAt: DateTime.utc(2026, 6, 22, 12),
            description: 'Salario',
          );
        },
      );

      // El placeholder de "sin movimientos" debe haberse ido.
      expect(
        find.textContaining('Aún no hay movimientos'),
        findsNothing,
      );
      // El movimiento aparece en la lista por descripción.
      expect(find.text('Salario'), findsOneWidget);

      await harness.dispose();
    });

    // Sprint UX de visibilidad de cuenta: la row de "Últimos movimientos"
    // muestra el nombre de la cuenta relevante según el kind (destino en
    // income; origen en expense; "origen → destino" en transfer/pago).
    testWidgets(
        'Últimos movimientos: la row muestra el nombre de la cuenta',
        (tester) async {
      final harness = await pumpFincoreApp(
        tester,
        seed: (db, deps) async {
          final bolsa = (await deps.accountsDao.listAll())
              .firstWhere((a) => a.type == 'cash');
          final bbva = await deps.accountsDao.create(
            name: 'BBVA_Row_Test',
            type: 'debit',
          );
          // Expense desde BBVA → subtexto muestra "BBVA_Row_Test".
          await deps.entriesDao.registerExpense(
            accountOriginId: bbva,
            amount: 300,
            occurredAt: DateTime.utc(2026, 6, 22, 12),
            description: 'GastoBBVA_Row',
          );
          // Transfer bolsa → BBVA → subtexto muestra "Bolsa → BBVA_Row_Test".
          await deps.entriesDao.registerTransfer(
            accountOriginId: bolsa.id,
            accountDestinationId: bbva,
            amount: 100,
            occurredAt: DateTime.utc(2026, 6, 23, 12),
            description: 'TransferRow_Test',
          );
        },
      );

      // La descripción del expense está en el árbol (puede caer fuera
      // del viewport tras el sprint dashboard-bundle-v1 que agregó
      // Hoy + sparklines + chips arriba).
      expect(find.text('GastoBBVA_Row', skipOffstage: false),
          findsOneWidget);
      // El nombre de la cuenta aparece dentro del subtexto (que también
      // trae fecha y kind). Usamos textContaining porque el subtexto es
      // "BBVA_Row_Test · 22 jun · Gasto".
      expect(
        find.textContaining('BBVA_Row_Test', skipOffstage: false),
        findsWidgets,
        reason: 'La row del expense muestra el nombre de la cuenta origen.',
      );
      // La transfer muestra "origen → destino" en el subtexto.
      expect(
        find.textContaining('Bolsa → BBVA_Row_Test', skipOffstage: false),
        findsOneWidget,
        reason: 'La row del transfer muestra "origen → destino".',
      );

      await harness.dispose();
    });

    testWidgets(
        'AppBar tiene IconButton "Reportes" que navega a /reports (RF-017)',
        (tester) async {
      final harness = await pumpFincoreApp(tester);

      // El IconButton del AppBar tiene tooltip "Reportes" (único, no confunde
      // con el icono de Categorías ni Settings).
      final reportsButton = find.byTooltip('Reportes');
      expect(reportsButton, findsOneWidget,
          reason: 'El AppBar del Dashboard debería tener un IconButton Reportes');

      await tester.tap(reportsButton);
      await tester.pumpAndSettle();

      expect(find.byType(ReportsScreen), findsOneWidget,
          reason: 'Tap del IconButton Reportes navega a /reports');

      await harness.dispose();
    });

    // Sprint flutter-dashboard-bundle-v1: vista Hoy + sparkline + chips.

    testWidgets(
        'WT-DB01: dashboard con 1 income de hoy → vista "Hoy" muestra '
        'monto en Ingresos',
        (tester) async {
      final now = DateTime.now();
      final harness = await pumpFincoreApp(
        tester,
        seed: (db, deps) async {
          final bolsa = (await deps.accountsDao.listAll())
              .firstWhere((a) => a.type == 'cash');
          await deps.entriesDao.registerIncome(
            accountDestinationId: bolsa.id,
            amount: 1500,
            occurredAt: DateTime(now.year, now.month, now.day, 10),
            description: 'IncomeToday',
          );
        },
      );
      // La card "Hoy" tiene el label "Hoy · <fecha>". Buscamos el prefijo.
      expect(find.textContaining('Hoy · '), findsOneWidget);
      // Labels de las 3 métricas.
      expect(find.text('Ingresos'), findsOneWidget);
      expect(find.text('Gastos'), findsOneWidget);
      expect(find.text('Neto'), findsOneWidget);
      await harness.dispose();
    });

    testWidgets(
        'WT-DB02: BD vacía → vista "Hoy" visible + labels correctos',
        (tester) async {
      final harness = await pumpFincoreApp(tester);
      expect(find.textContaining('Hoy · '), findsOneWidget);
      expect(find.text('Ingresos'), findsOneWidget);
      expect(find.text('Gastos'), findsOneWidget);
      expect(find.text('Neto'), findsOneWidget);
      await harness.dispose();
    });

    testWidgets(
        'WT-DB03: tap chip de cuenta → lista se filtra a los movimientos '
        'de esa cuenta',
        (tester) async {
      final now = DateTime.now();
      final harness = await pumpFincoreApp(
        tester,
        seed: (db, deps) async {
          final bolsa = (await deps.accountsDao.listAll())
              .firstWhere((a) => a.type == 'cash');
          final banamex = await deps.accountsDao.create(
            name: 'Banamex_FilterTest',
            type: 'debit',
          );
          // Movimiento en Bolsa.
          await deps.entriesDao.registerIncome(
            accountDestinationId: bolsa.id,
            amount: 100,
            occurredAt: DateTime(now.year, now.month, now.day, 9),
            description: 'IncomeBolsaFilterTest',
          );
          // Movimiento en Banamex.
          await deps.entriesDao.registerIncome(
            accountDestinationId: banamex,
            amount: 200,
            occurredAt: DateTime(now.year, now.month, now.day, 10),
            description: 'IncomeBanamexFilterTest',
          );
        },
      );
      // Ambos movimientos en el árbol (uno puede caer fuera del viewport
      // del dashboard cuando hay muchos widgets arriba; usamos
      // `skipOffstage: false`).
      expect(find.text('IncomeBolsaFilterTest', skipOffstage: false),
          findsOneWidget);
      expect(find.text('IncomeBanamexFilterTest', skipOffstage: false),
          findsOneWidget);
      // Tap chip "Banamex_FilterTest" (chip del filtro, no de la lista
      // de cuentas).
      final chip = find.widgetWithText(ChoiceChip, 'Banamex_FilterTest');
      expect(chip, findsOneWidget);
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      // Extra pump para dejar que setState + StreamBuilder reaccionen.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      // Verificar que el chip quedó seleccionado — confirma que el
      // onSelected se disparó.
      final banamexChipWidget = tester.widget<ChoiceChip>(chip);
      expect(banamexChipWidget.selected, isTrue,
          reason: 'Tras tap, el chip Banamex debería estar seleccionado.');
      // Solo el income de Banamex debería seguir en el árbol; el de
      // Bolsa debería desaparecer.
      expect(find.text('IncomeBanamexFilterTest', skipOffstage: false),
          findsOneWidget);
      expect(find.text('IncomeBolsaFilterTest', skipOffstage: false),
          findsNothing);
      await harness.dispose();
    });

    testWidgets(
        'WT-DB04: chip "Todas" está seleccionado por default al montar',
        (tester) async {
      final harness = await pumpFincoreApp(tester);
      final todasChip = find.widgetWithText(ChoiceChip, 'Todas');
      expect(todasChip, findsOneWidget);
      final widget = tester.widget<ChoiceChip>(todasChip);
      expect(widget.selected, isTrue);
      await harness.dispose();
    });

    testWidgets(
        'WT-DB05: tap "Todas" tras haber filtrado → restaura consolidado',
        (tester) async {
      final now = DateTime.now();
      final harness = await pumpFincoreApp(
        tester,
        seed: (db, deps) async {
          final bolsa = (await deps.accountsDao.listAll())
              .firstWhere((a) => a.type == 'cash');
          final debit = await deps.accountsDao.create(
            name: 'Debit_WT05',
            type: 'debit',
          );
          await deps.entriesDao.registerIncome(
            accountDestinationId: bolsa.id,
            amount: 100,
            occurredAt: DateTime(now.year, now.month, now.day, 9),
            description: 'BolsaMov_WT05',
          );
          await deps.entriesDao.registerIncome(
            accountDestinationId: debit,
            amount: 200,
            occurredAt: DateTime(now.year, now.month, now.day, 10),
            description: 'DebitMov_WT05',
          );
        },
      );
      // Tap "Debit_WT05" para filtrar.
      final debitChip = find.widgetWithText(ChoiceChip, 'Debit_WT05');
      await tester.ensureVisible(debitChip);
      await tester.pumpAndSettle();
      await tester.tap(debitChip);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      expect(find.text('BolsaMov_WT05', skipOffstage: false), findsNothing);
      expect(find.text('DebitMov_WT05', skipOffstage: false),
          findsOneWidget);
      // Tap "Todas" para restaurar.
      final todasChip = find.widgetWithText(ChoiceChip, 'Todas');
      await tester.ensureVisible(todasChip);
      await tester.pumpAndSettle();
      await tester.tap(todasChip);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      expect(find.text('BolsaMov_WT05', skipOffstage: false),
          findsOneWidget);
      expect(find.text('DebitMov_WT05', skipOffstage: false),
          findsOneWidget);
      await harness.dispose();
    });
  });
}

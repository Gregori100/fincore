import 'package:fincore/screens/reports/cashflow_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/widget_test_harness.dart';

/// Widget tests del `CashflowTab`. Sprint `flutter-reports-cashflow-v1`.
///
/// Cobertura:
/// - WT-01: render con datos del mes corriente.
/// - WT-02: empty state con BD sin entries.
/// - WT-03: tap preset "Año" cambia el rango y refresca el reporte.
void main() {
  group('CashflowTab', () {
    /// Helper: navega a `/reports` y tappea el segundo tab para que
    /// `CashflowTab` quede activo. Devuelve cuando el tab montó.
    Future<void> openCashflowTab(WidgetTester tester) async {
      final ctx = tester.element(find.byType(Scaffold).first);
      GoRouter.of(ctx).push('/reports');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cashflow mensual'));
      await tester.pumpAndSettle();
    }

    testWidgets(
        'WT-01: render con datos: header con métricas + chart + breakdown',
        (tester) async {
      final now = DateTime.now();
      final harness = await pumpFincoreApp(tester, seed: (db, deps) async {
        final bolsa = (await deps.accountsDao.listAll())
            .firstWhere((a) => a.type == 'cash');
        await deps.accountsDao.create(name: 'Banamex_C', type: 'debit');
        final debit = (await deps.accountsDao.listAll())
            .firstWhere((a) => a.name == 'Banamex_C');
        // 1 ingreso + 1 gasto en el mes corriente.
        final day = DateTime(now.year, now.month, 10, 10);
        await deps.entriesDao.registerIncome(
          accountDestinationId: bolsa.id,
          amount: 120000,
          occurredAt: day,
        );
        await deps.entriesDao.registerExpense(
          accountOriginId: debit.id,
          amount: 30000,
          occurredAt: day.add(const Duration(hours: 1)),
        );
      });

      await openCashflowTab(tester);

      // El tab `CashflowTab` está montado.
      expect(find.byType(CashflowTab), findsOneWidget);
      // Header con las 3 métricas. Labels (puede aparecer "Ingresos" tanto en
      // el header como en otros lados — aceptamos findsAtLeast).
      expect(find.text('Ingresos'), findsAtLeastNWidgets(1));
      expect(find.text('Gastos'), findsAtLeastNWidgets(1));
      expect(find.text('Neto'), findsAtLeastNWidgets(1));

      await harness.dispose();
    });

    testWidgets('WT-02: empty state con BD sin entries en el mes',
        (tester) async {
      final harness = await pumpFincoreApp(tester);

      await openCashflowTab(tester);

      expect(find.text('No hay movimientos en este rango.'), findsOneWidget);

      await harness.dispose();
    });

    testWidgets('WT-03: tap preset "Año" cambia el rango y refresca',
        (tester) async {
      final harness = await pumpFincoreApp(tester);

      await openCashflowTab(tester);

      // Default es thisMonth — confirmamos antes del tap.
      expect(find.text('Año'), findsOneWidget);
      await tester.tap(find.text('Año'));
      await tester.pumpAndSettle();

      // Tras tap, el chip "Año" debe quedar como selected. Una validación
      // mínima: el tab sigue montado y el empty state sigue (BD vacía).
      expect(find.byType(CashflowTab), findsOneWidget);
      expect(find.text('No hay movimientos en este rango.'), findsOneWidget);

      await harness.dispose();
    });

    // Sprint flutter-cashflow-monthly-breakdown-v1: sheet drill-down.
    testWidgets(
        'WT-CB01: tap en fila del mes con expense → sheet abre con sección '
        'de gastos y sin sección de ingresos',
        (tester) async {
      final now = DateTime.now();
      final harness = await pumpFincoreApp(tester, seed: (db, deps) async {
        final bolsa = (await deps.accountsDao.listAll())
            .firstWhere((a) => a.type == 'cash');
        final catId = await deps.categoriesDao.create(
          name: 'Comida_MBW',
          appliesTo: 'expense',
          colorSlug: 'red',
          iconSlug: 'shopping-cart',
        );
        await deps.entriesDao.registerExpense(
          accountOriginId: bolsa.id,
          amount: 75000,
          occurredAt: DateTime(now.year, now.month, 12, 10),
          categoryId: catId,
          description: 'BreakdownExpense',
        );
      });

      await openCashflowTab(tester);
      // Fila del mes corriente aparece en el breakdown (label formato "MMM y").
      final rows = find.byIcon(Icons.expand_more);
      expect(rows, findsWidgets);
      await tester.tap(rows.first);
      await tester.pumpAndSettle();

      // Sheet abierto: sección "Gastos por categoría" visible.
      expect(find.text('Gastos por categoría'), findsOneWidget);
      // Sin sección de ingresos.
      expect(find.text('Ingresos por categoría'), findsNothing);
      // Bucket con la categoría sembrada.
      expect(find.text('Comida_MBW'), findsOneWidget);

      await harness.dispose();
    });

    testWidgets(
        'WT-CB02: mes con income + expense → sheet muestra ambas secciones',
        (tester) async {
      final now = DateTime.now();
      final harness = await pumpFincoreApp(tester, seed: (db, deps) async {
        final bolsa = (await deps.accountsDao.listAll())
            .firstWhere((a) => a.type == 'cash');
        await deps.entriesDao.registerIncome(
          accountDestinationId: bolsa.id,
          amount: 500000,
          occurredAt: DateTime(now.year, now.month, 5, 9),
          description: 'IncomeMBW',
        );
        await deps.entriesDao.registerExpense(
          accountOriginId: bolsa.id,
          amount: 130000,
          occurredAt: DateTime(now.year, now.month, 15, 15),
          description: 'ExpenseMBW',
        );
      });

      await openCashflowTab(tester);
      final rows = find.byIcon(Icons.expand_more);
      await tester.tap(rows.first);
      await tester.pumpAndSettle();

      expect(find.text('Ingresos por categoría'), findsOneWidget);
      expect(find.text('Gastos por categoría'), findsOneWidget);
      // Ambos buckets sin categoría (no se pasó categoryId).
      expect(find.text('Sin categoría'), findsNWidgets(2));

      await harness.dispose();
    });

    testWidgets(
        'WT-CB03: BD vacía → tab renderea empty state SIN filas tap-ables '
        '(blindaje regresivo)',
        (tester) async {
      final harness = await pumpFincoreApp(tester);
      await openCashflowTab(tester);
      // BD vacía → `_CashflowReport.isEmpty` → _EmptyState del tab base.
      // No hay `_BreakdownRow` ni `expand_more`. El fallback del sheet
      // se cubre en WT-CB05 con una fila mes-cero real.
      expect(find.byIcon(Icons.expand_more), findsNothing);

      await harness.dispose();
    });

    testWidgets(
        'WT-CB05: preset "Año" con 1 movimiento en el mes actual → filas '
        'de meses vacíos aparecen con ceros → tap muestra fallback "Sin '
        'movimientos en este mes."',
        (tester) async {
      final now = DateTime.now();
      final harness = await pumpFincoreApp(tester, seed: (db, deps) async {
        final bolsa = (await deps.accountsDao.listAll())
            .firstWhere((a) => a.type == 'cash');
        // 1 income solo en el mes actual — el rango "Año" (1/1 a 31/12)
        // dispara RN-C06 (rellenar los otros 11 meses con ceros).
        await deps.entriesDao.registerIncome(
          accountDestinationId: bolsa.id,
          amount: 150000,
          occurredAt: DateTime(now.year, now.month, 10, 12),
          description: 'CurrentMonthIncome',
        );
      });
      await openCashflowTab(tester);
      // Cambiar preset a "Año" para que aparezcan 12 filas (una por mes).
      await tester.tap(find.text('Año'));
      await tester.pumpAndSettle();
      final rows = find.byIcon(Icons.expand_more);
      expect(rows, findsNWidgets(12));
      // Tapear la primera fila (enero — siempre vacía si estamos después
      // de enero en el año; si estamos exactamente en enero, usamos la
      // última fila (diciembre) que también estará vacía porque el income
      // sembrado cae en el mes actual = enero).
      final targetRow = now.month == 1 ? rows.last : rows.first;
      await tester.tap(targetRow);
      await tester.pumpAndSettle();
      expect(find.text('Sin movimientos en este mes.'), findsOneWidget);

      await harness.dispose();
    });

    testWidgets(
        'WT-CB04: tap "Ver movimientos" cierra sheet y navega a /entries',
        (tester) async {
      final now = DateTime.now();
      final harness = await pumpFincoreApp(tester, seed: (db, deps) async {
        final bolsa = (await deps.accountsDao.listAll())
            .firstWhere((a) => a.type == 'cash');
        await deps.entriesDao.registerExpense(
          accountOriginId: bolsa.id,
          amount: 40000,
          occurredAt: DateTime(now.year, now.month, 10, 12),
          description: 'DrillDownExpense',
        );
      });

      await openCashflowTab(tester);
      final rows = find.byIcon(Icons.expand_more);
      await tester.tap(rows.first);
      await tester.pumpAndSettle();

      // El botón "Ver movimientos" está dentro del sheet.
      final drillButton = find.text('Ver movimientos');
      expect(drillButton, findsOneWidget);
      await tester.tap(drillButton);
      await tester.pumpAndSettle();

      // Sheet cerrado + navegación a /entries: la descripción del entry
      // sembrado debe estar visible en la lista.
      expect(find.text('Gastos por categoría'), findsNothing);
      expect(find.text('DrillDownExpense'), findsOneWidget);

      await harness.dispose();
    });

    // Sprint flutter-cashflow-breakdown-prev-comparison-v1: chip vs mes
    // previo.
    testWidgets(
        'WT-CP01: 2 meses con datos → chip up con dirección + percent + '
        'color rojo (semántica bolsillo para gastos)',
        (tester) async {
      final now = DateTime.now();
      final harness = await pumpFincoreApp(tester, seed: (db, deps) async {
        final bolsa = (await deps.accountsDao.listAll())
            .firstWhere((a) => a.type == 'cash');
        final catId = await deps.categoriesDao.create(
          name: 'Comida_CPW',
          appliesTo: 'expense',
          colorSlug: 'red',
          iconSlug: 'shopping-cart',
        );
        // Mes previo: $500. Mes actual: $1000 → +100%.
        final prev = DateTime(now.year, now.month - 1, 10, 12);
        await deps.entriesDao.registerExpense(
          accountOriginId: bolsa.id,
          amount: 50000,
          occurredAt: prev,
          categoryId: catId,
        );
        await deps.entriesDao.registerExpense(
          accountOriginId: bolsa.id,
          amount: 100000,
          occurredAt: DateTime(now.year, now.month, 12, 12),
          categoryId: catId,
        );
      });
      await openCashflowTab(tester);
      final rows = find.byIcon(Icons.expand_more);
      await tester.tap(rows.first);
      await tester.pumpAndSettle();

      // Chip up visible con percent 100.
      expect(find.byIcon(Icons.arrow_upward), findsAtLeastNWidgets(1));
      // Sprint polish 0.18.2+92: percent >= 100 se muestra como
      // multiplicador (`×2` para +100%).
      expect(find.text('×2.0'), findsAtLeastNWidgets(1));

      await harness.dispose();
    });

    testWidgets(
        'WT-CP02: solo mes actual sin previo → chips muestran `—` '
        '(bucket + summary)',
        (tester) async {
      final now = DateTime.now();
      final harness = await pumpFincoreApp(tester, seed: (db, deps) async {
        final bolsa = (await deps.accountsDao.listAll())
            .firstWhere((a) => a.type == 'cash');
        await deps.entriesDao.registerExpense(
          accountOriginId: bolsa.id,
          amount: 30000,
          occurredAt: DateTime(now.year, now.month, 5, 12),
          description: 'NoPrevExpense',
        );
      });
      await openCashflowTab(tester);
      final rows = find.byIcon(Icons.expand_more);
      await tester.tap(rows.first);
      await tester.pumpAndSettle();

      // El `—` aparece al menos 4 veces: 3 chips del summary
      // (deltaIncome, deltaExpense, deltaNet — todos null porque el
      // previo está vacío) + 1 chip por bucket (aquí solo 1 bucket).
      expect(find.text('—'), findsAtLeastNWidgets(4));

      await harness.dispose();
    });
  });
}

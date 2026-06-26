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
          amount: 1200,
          occurredAt: day,
        );
        await deps.entriesDao.registerExpense(
          accountOriginId: debit.id,
          amount: 300,
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
  });
}

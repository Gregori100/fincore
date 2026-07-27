import 'package:fincore/screens/reports_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/widget_test_harness.dart';

/// Widget tests del `/reports` del sprint `flutter-reports-v1` (RF-016).
///
/// Patrón: el harness arranca en `/dashboard`. Cada test pushea `/reports`
/// con `context.push(...)` (igual que el test del IconButton del Dashboard
/// que pasa verde). Usar `initialRoute: '/reports'` del harness cuelga
/// `pumpAndSettle` indefinidamente — la diferencia es que `router.go(...)`
/// reemplaza el stack y la transición no asienta, mientras que `push`
/// apila y asienta normal. Convención documentada en
/// `engineering/specs/flutter-reports-v1/implementation/decisiones-implementacion.md`.
void main() {
  group('ReportsScreen — /reports (RF-016)', () {
    Future<void> pushReports(WidgetTester tester) async {
      final ctx = tester.element(find.byType(Scaffold));
      GoRouter.of(ctx).push('/reports');
      await tester.pumpAndSettle();
    }

    testWidgets(
        'BD sin gastos: la tab muestra estado vacío',
        (tester) async {
      final harness = await pumpFincoreApp(tester);
      await pushReports(tester);

      expect(find.byType(ReportsScreen), findsOneWidget);
      // AppBar con título "Reportes" y tab única "Gasto por categoría".
      expect(find.text('Reportes'), findsOneWidget);
      expect(find.text('Gasto por categoría'), findsOneWidget);
      // Estado vacío visible.
      expect(
        find.textContaining('No hay gastos en el rango'),
        findsOneWidget,
      );

      await harness.dispose();
    });

    testWidgets(
        'BD con expense en categoría: render del bucket con monto + nombre',
        (tester) async {
      final harness = await pumpFincoreApp(
        tester,
        seed: (db, deps) async {
          final debit =
              await deps.accountsDao.create(name: 'Banamex', type: 'debit');
          final catComida = await deps.categoriesDao.create(
            name: 'Comida_Test',
            appliesTo: 'expense',
            colorSlug: 'red',
            iconSlug: 'shopping-cart',
          );
          // Registrar dentro del rango default (mes corriente).
          final now = DateTime.now();
          await deps.entriesDao.registerExpense(
            accountOriginId: debit,
            categoryId: catComida,
            amount: 35000,
            occurredAt: DateTime(now.year, now.month, now.day, 10),
          );
        },
      );
      await pushReports(tester);

      // El estado vacío ya no aparece.
      expect(
        find.textContaining('No hay gastos en el rango'),
        findsNothing,
      );
      // El bucket muestra el nombre de la categoría sembrada.
      expect(find.text('Comida_Test'), findsOneWidget);
      // Card de total visible.
      expect(find.text('Total del período'), findsOneWidget);
      // 1 movimiento (texto literal en `_TotalCard`).
      expect(find.text('1 movimiento'), findsOneWidget);

      await harness.dispose();
    });

    testWidgets(
        'BD con expense sin categoría: bucket "Sin categoría" visible',
        (tester) async {
      final harness = await pumpFincoreApp(
        tester,
        seed: (db, deps) async {
          final debit =
              await deps.accountsDao.create(name: 'Banamex', type: 'debit');
          final now = DateTime.now();
          await deps.entriesDao.registerExpense(
            accountOriginId: debit,
            amount: 50000,
            occurredAt: DateTime(now.year, now.month, now.day, 10),
          );
        },
      );
      await pushReports(tester);

      expect(find.text('Sin categoría'), findsOneWidget,
          reason:
              'Bucket especial para entries con categoryId null (RN-R03/R08)');

      await harness.dispose();
    });

    testWidgets(
        'Header muestra 4 chips de presets y default "Este mes" activo',
        (tester) async {
      final harness = await pumpFincoreApp(tester);
      await pushReports(tester);

      // 4 ChoiceChip: Este mes / Mes pasado / Año / Custom.
      expect(find.byType(ChoiceChip), findsNWidgets(4));
      expect(find.text('Este mes'), findsOneWidget);
      expect(find.text('Mes pasado'), findsOneWidget);
      // Buscar el text "Año" exacto evita falso positivo de un futuro texto
      // que contenga "año".
      expect(find.text('Año'), findsOneWidget);
      expect(find.text('Custom'), findsOneWidget);
      // En default (no Custom), los date pickers no se muestran.
      expect(find.byIcon(Icons.calendar_today), findsNothing);

      await harness.dispose();
    });

    testWidgets(
        'Tap en chip "Custom" muestra dos input fields de fecha',
        (tester) async {
      final harness = await pumpFincoreApp(tester);
      await pushReports(tester);

      // Inicialmente no hay fields.
      expect(find.byIcon(Icons.calendar_today), findsNothing);

      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();

      // Tras seleccionar Custom, aparecen los dos input fields con icono.
      expect(find.byIcon(Icons.calendar_today), findsNWidgets(2));
      // Labels "Desde" y "Hasta" del InputDecorator.
      expect(find.text('Desde'), findsOneWidget);
      expect(find.text('Hasta'), findsOneWidget);

      await harness.dispose();
    });
  });
}

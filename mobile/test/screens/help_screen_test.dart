import 'package:fincore/screens/help_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/widget_test_harness.dart';

/// Widget tests del `HelpScreen`. Sprint
/// `flutter-onboarding-for-testers-v1`.
void main() {
  group('HelpScreen', () {
    Future<void> openHelp(WidgetTester tester) async {
      final ctx = tester.element(find.byType(Scaffold).first);
      GoRouter.of(ctx).push('/help');
      await tester.pumpAndSettle();
    }

    testWidgets('WT-H01: renderea 6 ExpansionTile', (tester) async {
      final harness = await pumpFincoreApp(tester);
      await openHelp(tester);
      expect(find.byType(HelpScreen), findsOneWidget);
      expect(find.byType(ExpansionTile), findsNWidgets(6));
      await harness.dispose();
    });

    testWidgets('WT-H02: tap en el primer ExpansionTile expande contenido',
        (tester) async {
      final harness = await pumpFincoreApp(tester);
      await openHelp(tester);
      // Antes del tap, el contenido del primer tile NO está visible.
      expect(find.textContaining('5 tipos de movimientos'), findsNothing);
      await tester.tap(find.text('¿Qué tipos de movimientos hay?'));
      await tester.pumpAndSettle();
      // Tras expandir, el contenido es visible.
      expect(find.textContaining('5 tipos de movimientos'), findsOneWidget);
      await harness.dispose();
    });

    testWidgets('WT-H03: tap otra vez colapsa el tile', (tester) async {
      final harness = await pumpFincoreApp(tester);
      await openHelp(tester);
      await tester.tap(find.text('¿Qué tipos de movimientos hay?'));
      await tester.pumpAndSettle();
      expect(find.textContaining('5 tipos de movimientos'), findsOneWidget);
      await tester.tap(find.text('¿Qué tipos de movimientos hay?'));
      await tester.pumpAndSettle();
      expect(find.textContaining('5 tipos de movimientos'), findsNothing);
      await harness.dispose();
    });

    testWidgets('WT-H04: títulos esperados de los 6 temas presentes',
        (tester) async {
      final harness = await pumpFincoreApp(tester);
      await openHelp(tester);
      expect(find.text('¿Qué tipos de movimientos hay?'), findsOneWidget);
      expect(find.text('¿Qué significan BO, DE y CR?'), findsOneWidget);
      expect(find.text('¿Cómo se calculan los reportes?'), findsOneWidget);
      expect(
        find.text('¿Cómo funciona la sugerencia automática de categoría?'),
        findsOneWidget,
      );
      expect(find.text('¿Qué son las vistas guardadas?'), findsOneWidget);
      expect(
        find.text('¿Cómo hacer backup y por qué importa?'),
        findsOneWidget,
      );
      await harness.dispose();
    });
  });
}

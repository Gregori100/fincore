import 'package:flutter_test/flutter_test.dart';

import 'factories.dart';
import 'widget_test_harness.dart';

void main() {
  group('pumpFincoreApp — harness', () {
    testWidgets('Sembrado por default: monta /dashboard con la Bolsa visible',
        (tester) async {
      final harness = await pumpFincoreApp(tester);

      // "Bolsa" aparece 2x en el dashboard: como nombre de la cuenta y como
      // label del tipo cash (`_typeLabel('cash')`). Ambos son intencionales.
      expect(find.text('Bolsa'), findsNWidgets(2));
      // Las cards BO / DE / CR del dashboard.
      expect(find.text('BO'), findsOneWidget);
      expect(find.text('DE'), findsOneWidget);
      expect(find.text('CR'), findsOneWidget);

      await harness.dispose();
    });

    testWidgets('Con seed extra: aparece la cuenta sembrada por el caller',
        (tester) async {
      final harness = await pumpFincoreApp(
        tester,
        seed: (db, deps) async {
          await db.into(db.accounts).insert(Factories.debit(name: 'Banamex'));
        },
      );

      expect(find.text('Banamex'), findsOneWidget);
      // Bolsa sigue presente como nombre + tipo (2x). Banamex no aparece
      // duplicado porque `_typeLabel('debit')` retorna "Débito".
      expect(find.text('Bolsa'), findsNWidgets(2));

      await harness.dispose();
    });

    testWidgets('seedBolsa=false: el router redirige a /first-run',
        (tester) async {
      final harness = await pumpFincoreApp(
        tester,
        seedBolsa: false,
        initialRoute: '/first-run',
      );

      // FirstRunScreen muestra estos dos botones.
      expect(find.textContaining('Arrancar limpio'), findsWidgets);
      expect(find.textContaining('Importar respaldo'), findsWidgets);

      await harness.dispose();
    });
  });
}

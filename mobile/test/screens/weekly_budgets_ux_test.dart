import 'package:fincore/screens/settings_screen.dart';
import 'package:fincore/screens/weekly_budgets/list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/widget_test_harness.dart';

/// Tests de la UX agregada por el sprint `flutter-weekly-budgets-v1`
/// (T033): sección "Preferencias" de Settings, entry point del Dashboard
/// y la FAQ nueva de Help. Cubre WT-SET01/02, WT-DASH01 y WT-HELP01 del
/// test-plan.
void main() {
  group('Weekly budgets UX — sprint flutter-weekly-budgets-v1', () {
    // `pumpAndSettle` NO se puede usar una vez que SettingsScreen está
    // montado: el `FutureBuilder<PackageInfo>` de "Acerca de" nunca
    // resuelve en tests (sin mock de MethodChannel) y cuelga el pump.
    // Mismo patrón que `test/screens/settings_screen_test.dart`.
    Future<void> openSettings(WidgetTester tester) async {
      final ctx = tester.element(find.byType(Scaffold).first);
      GoRouter.of(ctx).push('/settings');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // Deja que `_loadWeekStartDow` (async vía AppPreferencesDao) resuelva
      // y dispare el `setState` que reemplaza el Skeleton por el Dropdown.
      await tester.pump(const Duration(milliseconds: 100));
    }

    Future<void> scrollToWeekStartRow(WidgetTester tester) async {
      await tester.scrollUntilVisible(
        find.text('Día de inicio de la semana'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets(
        'WT-SET01: sección Preferencias muestra DropdownButton con 7 '
        'opciones + default Viernes', (tester) async {
      final harness = await pumpFincoreApp(tester);
      await openSettings(tester);
      expect(find.byType(SettingsScreen), findsOneWidget);
      await scrollToWeekStartRow(tester);

      final dropdown = find.byType(DropdownButton<int>);
      expect(dropdown, findsOneWidget,
          reason: 'La sección Preferencias debe mostrar el DropdownButton<int>');
      // Sin preferencia seteada, el default operativo es 5 = viernes.
      expect(find.text('Viernes'), findsOneWidget);

      // Abrir el menú para validar que expone las 7 opciones.
      await tester.tap(dropdown);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      for (final label in [
        'Lunes',
        'Martes',
        'Miércoles',
        'Jueves',
        'Viernes',
        'Sábado',
        'Domingo',
      ]) {
        expect(find.text(label), findsWidgets,
            reason: '"$label" debería aparecer como opción del dropdown');
      }
      // Cerrar el menú re-seleccionando el valor actual (no dispara cambio).
      await tester.tap(find.text('Viernes').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await harness.dispose();
    });

    testWidgets(
        'WT-SET02: cambiar el dropdown de Viernes a Domingo persiste y '
        'sobrevive un remount de /settings', (tester) async {
      final harness = await pumpFincoreApp(tester);
      await openSettings(tester);
      await scrollToWeekStartRow(tester);
      expect(find.text('Viernes'), findsOneWidget);

      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Domingo'), findsOneWidget,
          reason: 'Domingo debe estar entre las opciones del menú abierto');
      await tester.tap(find.text('Domingo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Persistencia verificada directamente contra el DAO.
      final dow = await harness.deps.appPreferencesDao.weekStartDow();
      expect(dow, 7, reason: 'setWeekStartDow(7) debe persistir en app_preferences');

      // Volver a montar /settings desde cero: nuevo State, nueva carga async.
      Navigator.of(tester.element(find.byType(SettingsScreen))).maybePop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await openSettings(tester);
      await scrollToWeekStartRow(tester);
      expect(find.text('Domingo'), findsOneWidget,
          reason: 'Tras remount, /settings debe reflejar la preferencia persistida');
      expect(find.text('Viernes'), findsNothing);

      await harness.dispose();
    });

    testWidgets(
        'WT-DASH01: AppBar de /dashboard tiene IconButton "Presupuestos '
        'semanales" que navega a /budgets', (tester) async {
      final harness = await pumpFincoreApp(tester);

      final button = find.byTooltip('Presupuestos semanales');
      expect(button, findsOneWidget,
          reason:
              'El AppBar del Dashboard debería tener un IconButton con tooltip '
              '"Presupuestos semanales"');

      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(find.byType(WeeklyBudgetsListScreen), findsOneWidget,
          reason: 'Tap del IconButton navega a /budgets');

      await harness.dispose();
    });

    testWidgets(
        'WT-HELP01: /help tiene la FAQ "Presupuestos" vs "Presupuestos '
        'semanales"', (tester) async {
      final harness = await pumpFincoreApp(tester);

      final ctx = tester.element(find.byType(Scaffold).first);
      GoRouter.of(ctx).push('/help');
      await tester.pumpAndSettle();

      // `skipOffstage: false`: el `ListView` no-lazy de Help mantiene todos
      // los `_FaqTile` montados aunque caigan fuera del viewport; el nuevo
      // FAQ es el último de 7 y suele quedar offstage sin scroll.
      expect(
        find.textContaining('Presupuestos semanales', skipOffstage: false),
        findsOneWidget,
        reason:
            'Debe existir una FAQ que mencione "Presupuestos semanales" en el título',
      );

      await harness.dispose();
    });
  });
}

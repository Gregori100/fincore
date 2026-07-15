import 'package:fincore/widgets/account_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/factories.dart';
import '../helpers/widget_test_harness.dart';

/// Para cada kind, validar que tras seleccionarlo en el KindPicker el form
/// muestra los labels de origin/destination según RN-011.
///
/// Labels esperados:
/// - income → solo `Cuenta destino` (cash/debit)
/// - expense → solo `Cuenta origen` (cash/debit)
/// - credit_expense → solo `Tarjeta` (credit)
/// - debt_payment → `Pago desde` + `Tarjeta a pagar`
/// - transfer → `Cuenta origen` + `Cuenta destino`
void main() {
  group('EntryFormScreen — 5 kinds (T044 / RF-006)', () {
    Future<void> pushNewEntry(WidgetTester tester) async {
      // Push real desde el dashboard para mantener el stack y permitir el back.
      final ctx = tester.element(find.byType(Scaffold));
      GoRouter.of(ctx).push('/entries/new');
      await tester.pumpAndSettle();
    }

    Future<void> selectKind(WidgetTester tester, String label) async {
      // Cada tile del KindPicker (grid post `flutter-entry-form-redesign-v1`)
      // es un InkWell con un Text de la label. Con 5 tiles en 3 filas el
      // tile puede quedar parcial/totalmente offscreen en el window 800×600.
      // Escalamos el test window a 1080×1920 (density devicePixelRatio ~2.6)
      // para que el KindPicker completo entre sin scroll, evitando el
      // problema de tap offscreen y matching post-render.
      await tester.binding.setSurfaceSize(const Size(1080, 1920));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });
      await tester.pumpAndSettle();

      final labelFinder = find.text(label);
      final card = find.ancestor(
        of: labelFinder,
        matching: find.byType(InkWell),
      );
      expect(card, findsWidgets,
          reason: 'KindPicker tile "$label" no encontrado');
      await tester.tap(card.first);
      await tester.pumpAndSettle();
    }

    Future<void> seedAccounts(dynamic db, dynamic deps) async {
      // La Bolsa ya está por seedDefaults; agregamos un debit y un credit.
      await db.into(db.accounts).insert(Factories.debit(name: 'Banamex'));
      await db.into(db.accounts).insert(Factories.credit(name: 'Visa'));
    }

    // RF-019 v4 evaluado: agregar `openDropdownAndVerify` que tap el field +
    // valida items del dropdown causa timeout. `tester.tap(find.text(label))`
    // no toca el widget tappeable del DropdownMenu (el Text del label vive
    // dentro del InputDecorator y el hit-test no llega al field). Cerrar el
    // dropdown con tap fuera también fragmentado.
    //
    // Patrón correcto requiere `find.byType(DropdownMenu<String>)` filtrado
    // por field, tap en el ícono expand específico, ESC para cerrar. Es
    // mecánico pero verboso (~30 min por kind). Se defiere a un sprint
    // dedicado de UI testing depth — el gap L1-H3 sigue documentado en
    // pendientes del v4 y v3.
    //
    // La cobertura actual valida labels textuales de los pickers, que es
    // la primera línea de defensa contra ruptura del KindPicker. La capa
    // siguiente (validar contenido del DropdownMenu) queda fuera de v4.

    testWidgets(
        'Ingreso muestra "Cuenta destino" + dropdown solo con cash/debit (RF-019 v1)',
        (tester) async {
      final harness = await pumpFincoreApp(tester, seed: seedAccounts);
      await pushNewEntry(tester);
      await selectKind(tester, 'Ingreso');

      // El AccountPicker dest tiene `label: Text('Cuenta destino')`.
      expect(find.text('Cuenta destino', skipOffstage: false), findsOneWidget);
      expect(find.text('Cuenta origen', skipOffstage: false), findsNothing);
      expect(find.text('Tarjeta', skipOffstage: false), findsNothing);
      expect(find.text('Pago desde', skipOffstage: false), findsNothing);

      // RF-019 v1: validar contenido del DropdownMenu. Ingreso solo acepta
      // dest cash/debit → Bolsa + Banamex; Visa (credit) NO debe aparecer.
      await openDropdownByLabel(tester, 'Cuenta destino');
      await verifyDropdownItems(
        tester,
        shouldShow: ['Bolsa', 'Banamex'],
        shouldNotShow: ['Visa'],
      );

      await harness.dispose();
    });

    testWidgets(
        'Gasto muestra "Cuenta origen" + dropdown solo con cash/debit (RF-019 v1)',
        (tester) async {
      final harness = await pumpFincoreApp(tester, seed: seedAccounts);
      await pushNewEntry(tester);
      await selectKind(tester, 'Gasto');

      expect(find.text('Cuenta origen', skipOffstage: false), findsOneWidget);
      expect(find.text('Cuenta destino', skipOffstage: false), findsNothing);
      expect(find.text('Tarjeta', skipOffstage: false), findsNothing);

      // RF-019 v1: origen cash/debit → Bolsa + Banamex; Visa NO.
      await openDropdownByLabel(tester, 'Cuenta origen');
      await verifyDropdownItems(
        tester,
        shouldShow: ['Bolsa', 'Banamex'],
        shouldNotShow: ['Visa'],
      );

      await harness.dispose();
    });

    testWidgets(
        'Gasto a tarjeta muestra "Tarjeta" + dropdown solo con credit (RF-019 v1)',
        (tester) async {
      final harness = await pumpFincoreApp(tester, seed: seedAccounts);
      await pushNewEntry(tester);
      await selectKind(tester, 'Gasto a tarjeta');

      expect(find.text('Tarjeta', skipOffstage: false), findsOneWidget);
      expect(find.text('Cuenta destino', skipOffstage: false), findsNothing);
      expect(find.text('Pago desde', skipOffstage: false), findsNothing);

      // RF-019 v1: origen credit → Visa; Bolsa + Banamex NO.
      await openDropdownByLabel(tester, 'Tarjeta');
      await verifyDropdownItems(
        tester,
        shouldShow: ['Visa'],
        shouldNotShow: ['Bolsa', 'Banamex'],
      );

      await harness.dispose();
    });

    testWidgets('Pago de tarjeta muestra "Pago desde" + "Tarjeta a pagar"',
        (tester) async {
      final harness = await pumpFincoreApp(tester, seed: seedAccounts);
      await pushNewEntry(tester);
      await selectKind(tester, 'Pago de tarjeta');

      expect(find.text('Pago desde', skipOffstage: false), findsOneWidget);
      expect(find.text('Tarjeta a pagar', skipOffstage: false), findsOneWidget);
      expect(find.text('Cuenta destino', skipOffstage: false), findsNothing);

      // RF-202 v2 cancelado: Material 3 DropdownMenu prerenderea los items
      // de TODOS los DropdownMenu del tree, no solo el actualmente abierto.
      // En kinds con 2 dropdowns (Pago de tarjeta + Transferencia), el
      // `find.textContaining` del helper `verifyDropdownItems` encuentra
      // items del OTRO dropdown sin importar cuál se abrió. DV-1 v1 queda
      // definitivamente diferido — la única salida sería migrar a un widget
      // custom con Keys específicos, lo cual cambia código de producción
      // solo para tests. ROI negativo.

      await harness.dispose();
    });

    testWidgets(
        'Transferencia muestra "Cuenta origen" + "Cuenta destino"',
        (tester) async {
      final harness = await pumpFincoreApp(tester, seed: seedAccounts);
      await pushNewEntry(tester);
      await selectKind(tester, 'Transferencia');

      // Tras el tap del kind el ListView del form puede tener scroll residual
      // del KindPicker (tile Transferencia estaba en la fila 3, offscreen).
      // Los AccountPickers en el nuevo layout van tras el amount hero y la
      // fecha, pueden quedar offstage en el window 800×600. Usamos
      // skipOffstage: false para validar que están en el árbol.
      expect(
        find.text('Cuenta origen', skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text('Cuenta destino', skipOffstage: false),
        findsOneWidget,
      );
      expect(find.text('Tarjeta', skipOffstage: false), findsNothing);

      await harness.dispose();
    });

    // Nota RF-019 v1: los dropdowns de Transferencia (ambos cash/debit) no
    // se verifican individualmente porque comparten el mismo problema de
    // contaminación de overlays entre tests del isolate que documentamos en
    // Pago de tarjeta. La cobertura del filtro RN-011 sobre cash/debit ya
    // queda blindada por Ingreso y Gasto.
  });
}

import 'package:drift/native.dart';
import 'package:fincore/app_dependencies.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/data/seed.dart';
import 'package:fincore/router/app_router.dart';
import 'package:fincore/theme/fincore_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Integration tests del `AccountFormScreen`.
///
/// Migración del scope DV-2 / RF-020 del sprint `flutter-local-hardening-v4`
/// (CRUD de cuentas) que quedó diferido por cuelgue de `pumpAndSettle` con
/// widget tests. Corre en runtime real (Linux desktop / Android).
///
/// Cobertura:
/// - AF-01: alta debit (default del picker) → cuenta visible en la BD.
/// - AF-02: alta con nombre vacío → validator inline "Ingresar un nombre.".
/// - AF-03: alta con nombre duplicado → snackbar con `duplicate_account_name`.
/// - AF-04: edición de Bolsa → muestra _ProtectedView (read-only).
/// - AF-05: alta credit con metadata válida → cuenta + metadata persisten.
///
/// Comandos:
///   flutter test integration_test/account_form_test.dart -d linux
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FincoreDatabase database;
  late AppDependencies deps;
  late FirstRunState firstRunState;
  late GoRouter router;

  setUp(() async {
    database = FincoreDatabase(NativeDatabase.memory());
    deps = AppDependencies.fromDatabase(database);
    await initializeDateFormatting('es_MX', null);
    await seedDefaults(
      db: database,
      accountsDao: deps.accountsDao,
      categoriesDao: deps.categoriesDao,
    );
    firstRunState = FirstRunState();
    firstRunState.value = true;
    router = buildAppRouter(deps: deps, firstRunState: firstRunState);
  });

  tearDown(() async {
    await database.close();
  });

  Widget buildApp() {
    return AppDependenciesProvider(
      deps: deps,
      child: FirstRunStateProvider(
        state: firstRunState,
        child: MaterialApp.router(
          theme: fincoreDarkTheme(),
          routerConfig: router,
        ),
      ),
    );
  }

  testWidgets('AF-01: alta debit "Banco BBVA" navega y vuelve con cuenta visible',
      (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    final ctx = tester.element(find.byType(Scaffold).first);
    GoRouter.of(ctx).push('/accounts/new');
    await tester.pumpAndSettle();

    // Nombre.
    await tester.enterText(find.byType(TextFormField).first, 'Banco BBVA');
    await tester.pumpAndSettle();

    // El tipo default del AccountTypePicker es `debit` (cash sólo la Bolsa).
    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();

    // Verificación en BD (más robusto que UI tras pop).
    final accounts = await deps.accountsDao.listAll();
    final bbva = accounts.where((a) => a.name == 'Banco BBVA').toList();
    expect(bbva, hasLength(1),
        reason: 'La cuenta "Banco BBVA" debe existir tras el submit');
    expect(bbva.first.type, 'debit',
        reason: 'El default del AccountTypePicker es debit (cash sólo Bolsa)');
  });

  testWidgets('AF-02: alta con nombre vacío bloquea con validator inline',
      (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    final ctx = tester.element(find.byType(Scaffold).first);
    GoRouter.of(ctx).push('/accounts/new');
    await tester.pumpAndSettle();

    // Sin enterText → tap "Crear cuenta" → validator dispara.
    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();

    expect(find.text('Ingresar un nombre.'), findsOneWidget,
        reason: 'El validator del field Nombre debe mostrar el mensaje');
    // Y no se creó ninguna cuenta nueva (solo la Bolsa del seed).
    final accounts = await deps.accountsDao.listAll();
    expect(accounts.length, 1,
        reason: 'No debe haberse creado ninguna cuenta nueva');
  });

  testWidgets('AF-03: alta con nombre duplicado muestra snackbar de error',
      (tester) async {
    // Seed: una cuenta debit "Repetida" además de la Bolsa.
    // (cash es singleton: sólo la Bolsa puede ser cash.)
    await deps.accountsDao.create(name: 'Repetida', type: 'debit');

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    final ctx = tester.element(find.byType(Scaffold).first);
    GoRouter.of(ctx).push('/accounts/new');
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Repetida');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();

    // Snackbar de error con texto correspondiente a `duplicate_account_name`.
    // El mapping vive en error_snackbar.dart.
    expect(find.textContaining('Ya existe una cuenta con ese nombre'),
        findsOneWidget,
        reason: 'Snackbar debe mostrar el mensaje del código duplicate_account_name');
    // Solo hay 2 cuentas (Bolsa + Repetida del seed). No se duplicó.
    final accounts = await deps.accountsDao.listAll();
    expect(accounts.where((a) => a.name == 'Repetida').length, 1);
  });

  testWidgets('AF-04: edición de Bolsa muestra _ProtectedView read-only',
      (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    final bolsa = (await deps.accountsDao.listAll())
        .firstWhere((a) => a.type == 'cash');

    final ctx = tester.element(find.byType(Scaffold).first);
    GoRouter.of(ctx).push('/accounts/${bolsa.id}/edit');
    await tester.pumpAndSettle();

    // _ProtectedView: copy explícita + sin botón "Guardar cambios".
    expect(find.text('Esta es tu Bolsa, no se puede editar ni eliminar.'),
        findsOneWidget);
    expect(find.text('Guardar cambios'), findsNothing,
        reason: 'La Bolsa no debe tener botón de submit');
    expect(find.text('Archivar cuenta'), findsNothing,
        reason: 'La Bolsa no debe tener botón de archivar');
  });

  testWidgets('AF-05: alta credit con metadata válida persiste todo',
      (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    final ctx = tester.element(find.byType(Scaffold).first);
    GoRouter.of(ctx).push('/accounts/new');
    await tester.pumpAndSettle();

    // Tap en el chip "Crédito" del AccountTypePicker (M3 chips).
    await tester.tap(find.text('Crédito'));
    await tester.pumpAndSettle();

    // Tras seleccionar Crédito aparecen los 3 fields de metadata.
    await tester.enterText(find.widgetWithText(TextFormField, 'Nombre'),
        'Visa Gold');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Límite de crédito'), '50000');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Día de corte'), '15');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Día de pago'), '5');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();

    final visa = (await deps.accountsDao.listAll())
        .firstWhere((a) => a.name == 'Visa Gold');
    expect(visa.type, 'credit');
    expect(visa.creditLimit, 50000.0);
    expect(visa.closingDay, 15);
    expect(visa.paymentDay, 5);
  });
}

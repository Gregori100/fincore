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

/// Integration tests del flujo destructivo "Reiniciar sin exportar" del
/// `SettingsScreen`.
///
/// Migración del scope DV-2 / RF-023 (settings destructivas) del sprint
/// `flutter-local-hardening-v4` diferido por cuelgue de `pumpAndSettle`.
///
/// Cobertura:
/// - SD-01: cancelar el ConfirmDialog destructivo NO ejecuta wipe.
/// - SD-02: confirmar el ConfirmDialog destructivo SÍ ejecuta wipe (BD vacía).
///
/// Comandos:
///   flutter test integration_test/settings_destructive_test.dart -d linux
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

  testWidgets('SD-01: cancelar ConfirmDialog destructivo NO ejecuta wipe',
      (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    final accountsAntes = (await deps.accountsDao.listAll()).length;
    expect(accountsAntes, greaterThan(0),
        reason: 'Pre-wipe la Bolsa del seed debe existir');

    final ctx = tester.element(find.byType(Scaffold).first);
    GoRouter.of(ctx).push('/settings');
    await tester.pumpAndSettle();

    // Tap el botón "Reiniciar sin exportar" (no requiere share previo).
    await tester.tap(find.text('Reiniciar sin exportar'));
    await tester.pumpAndSettle();

    // Aparece el ConfirmDialog con título "Reiniciar cuenta sin respaldo".
    expect(find.text('Reiniciar cuenta sin respaldo'), findsOneWidget);
    // Cancelar.
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    // La BD sigue intacta — la Bolsa no fue borrada.
    final accountsDespues = (await deps.accountsDao.listAll()).length;
    expect(accountsDespues, accountsAntes,
        reason: 'Cancelar el confirm NO debe borrar nada');
  });

  testWidgets('SD-02: confirmar ConfirmDialog destructivo SÍ ejecuta wipe',
      (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect((await deps.accountsDao.listAll()).length, greaterThan(0));

    final ctx = tester.element(find.byType(Scaffold).first);
    GoRouter.of(ctx).push('/settings');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reiniciar sin exportar'));
    await tester.pumpAndSettle();

    expect(find.text('Reiniciar cuenta sin respaldo'), findsOneWidget);
    // Confirmar con el label destructivo "Borrar todo igual".
    await tester.tap(find.text('Borrar todo igual'));
    await tester.pumpAndSettle();

    // BD vacía tras el wipe.
    final accounts = await deps.accountsDao.listAll();
    final categories = await deps.categoriesDao.listAll();
    expect(accounts, isEmpty, reason: 'wipeAll debe borrar accounts');
    expect(categories, isEmpty, reason: 'wipeAll debe borrar categories');
  });
}

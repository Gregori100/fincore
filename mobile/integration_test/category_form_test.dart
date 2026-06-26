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

/// Integration tests del `CategoryFormScreen`.
///
/// Migración del scope DV-2 / RF-022 del sprint `flutter-local-hardening-v4`
/// (CRUD de categorías + preview live del badge) diferido por cuelgue de
/// `pumpAndSettle` con widget tests.
///
/// Cobertura:
/// - CF-01: alta con nombre + defaults → categoría en BD.
/// - CF-02: alta con nombre vacío → validator inline.
/// - CF-03: alta con nombre duplicado → snackbar con `duplicate_category_name`.
/// - CF-04: edición → cambio de nombre persiste.
/// - CF-05: archive desde edit → categoría con deletedAt no null.
///
/// Comandos:
///   flutter test integration_test/category_form_test.dart -d linux
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

  testWidgets('CF-01: alta con nombre + defaults persiste en BD',
      (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    final ctx = tester.element(find.byType(Scaffold).first);
    GoRouter.of(ctx).push('/categories/new');
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre'), 'Suscripciones');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Crear categoría'));
    await tester.pumpAndSettle();

    final all = await deps.categoriesDao.listAll();
    final nuevo = all.where((c) => c.name == 'Suscripciones').toList();
    expect(nuevo, hasLength(1), reason: 'La categoría debe existir tras submit');
    expect(nuevo.first.colorSlug, isNotEmpty);
    expect(nuevo.first.iconSlug, isNotEmpty);
  });

  testWidgets('CF-02: alta con nombre vacío bloquea con validator inline',
      (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    final ctx = tester.element(find.byType(Scaffold).first);
    GoRouter.of(ctx).push('/categories/new');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Crear categoría'));
    await tester.pumpAndSettle();

    expect(find.text('Ingresá un nombre.'), findsOneWidget,
        reason: 'El validator del field Nombre debe mostrar el mensaje');
  });

  testWidgets('CF-03: alta con nombre duplicado muestra snackbar de error',
      (tester) async {
    // El seed crea 10 categorías default; "Comida" es una de ellas.
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    final ctx = tester.element(find.byType(Scaffold).first);
    GoRouter.of(ctx).push('/categories/new');
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre'), 'Comida');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Crear categoría'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Ya tenés una categoría con ese nombre'),
        findsOneWidget,
        reason: 'Snackbar debe mostrar el mensaje del duplicate_category_name');
  });

  testWidgets('CF-04: edición cambia el nombre y persiste',
      (tester) async {
    final newCat = await deps.categoriesDao.create(
      name: 'Original',
      appliesTo: 'expense',
      colorSlug: 'blue',
      iconSlug: 'shopping-cart',
    );

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    final ctx = tester.element(find.byType(Scaffold).first);
    GoRouter.of(ctx).push('/categories/$newCat/edit');
    await tester.pumpAndSettle();

    // El field "Nombre" arranca con "Original".
    expect(find.widgetWithText(TextFormField, 'Original'), findsOneWidget);

    // Limpiamos el field y escribimos "Renombrada".
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Original'), 'Renombrada');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();

    final actualizada = await deps.categoriesDao.findById(newCat);
    expect(actualizada!.name, 'Renombrada');
  });

  testWidgets('CF-05: archive seteando deletedAt no null',
      (tester) async {
    final id = await deps.categoriesDao.create(
      name: 'Archivable',
      appliesTo: 'expense',
      colorSlug: 'red',
      iconSlug: 'truck',
    );

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    final ctx = tester.element(find.byType(Scaffold).first);
    GoRouter.of(ctx).push('/categories/$id/edit');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Archivar categoría'));
    await tester.pumpAndSettle();

    // ConfirmDialog: tap "Archivar" del confirm.
    await tester.tap(find.text('Archivar').last);
    await tester.pumpAndSettle();

    // findById incluye archivadas; findActiveById no.
    final activa = await deps.categoriesDao.findActiveById(id);
    expect(activa, isNull, reason: 'La categoría archivada no debe ser activa');
    final raw = await deps.categoriesDao.findById(id);
    expect(raw, isNotNull);
    expect(raw!.deletedAt, isNotNull,
        reason: 'deletedAt debe estar seteado tras archivar');
  });
}

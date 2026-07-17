import 'package:drift/native.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/data/entries_filters.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sqlite_override.dart';

/// Test de migración 2 → 3 del sprint
/// `flutter-entries-saved-views-v1` (CM-06).
///
/// Estrategia: tomar una BD en estado v3 (todas las tablas creadas por
/// `onCreate`), simular el estado pre-migración dropeando `saved_views`,
/// ejecutar el SQL equivalente al de `m.createTable(savedViews)` y
/// verificar que la tabla queda lista para uso real.
///
/// NO valida el flujo completo "abrir BD v2 → onUpgrade dispara" porque
/// drift en memoria no permite persistir el `user_version` entre dos
/// aperturas. Esa validación queda cubierta por smoke manual SM-01
/// (instalar el APK sobre la versión anterior con datos existentes).
void main() {
  setUpAll(initSqliteOverride);

  test(
      'UT-17: CREATE TABLE saved_views deja la tabla lista para CRUD '
      '(equivalente al `m.createTable` de la migración 2 → 3)',
      () async {
    final db = FincoreDatabase(NativeDatabase.memory());
    // Forzar onCreate completo.
    await db.accountsDao.listAll();

    // Sembrar datos del usuario para validar que NO se pierden al
    // dropear/recrear `saved_views`.
    final accountId =
        await db.accountsDao.create(name: 'Banamex', type: 'debit');
    final categoryId = await db.categoriesDao.create(
      name: 'Comida',
      appliesTo: 'expense',
      colorSlug: 'red',
      iconSlug: 'shopping-cart',
    );

    // Simular estado pre-migración: dropear `saved_views`.
    await db.customStatement('DROP TABLE saved_views');
    final preRows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='saved_views'",
          readsFrom: const {},
        )
        .get();
    expect(preRows, isEmpty,
        reason: 'saved_views debería estar dropeada antes de migrar');

    // Ejecutar el SQL equivalente al de `m.createTable(savedViews)`.
    // `created_at` es TEXT (no INTEGER) porque `build.yaml` setea
    // `store_date_time_values_as_text: true` para preservar subsegundos
    // — same DateTime mapping que el codegen emite.
    await db.customStatement('''
      CREATE TABLE saved_views (
        id TEXT NOT NULL PRIMARY KEY,
        name TEXT NOT NULL,
        filters_json TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // Verificar que la tabla existe.
    final postRows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='saved_views'",
          readsFrom: const {},
        )
        .get();
    expect(postRows, hasLength(1));

    // Verificar que el DAO funciona end-to-end con la tabla recién
    // creada.
    final viewId = await db.savedViewsDao.create(
      name: 'TestView',
      filters: EntriesFilters.thisMonth(),
    );
    final list = await db.savedViewsDao.listAll();
    expect(list, hasLength(1));
    expect(list.first.id, viewId);
    expect(list.first.name, 'TestView');

    // Verificar que los datos del usuario sembrados antes de la migración
    // siguen ahí (validación crítica para RN-V01).
    final accountsAfter = await db.accountsDao.listAll();
    expect(accountsAfter.any((a) => a.id == accountId), isTrue,
        reason: 'cuenta sembrada antes de la migración debe persistir');
    final categoriesAfter = await db.categoriesDao.listAll();
    expect(categoriesAfter.any((c) => c.id == categoryId), isTrue,
        reason: 'categoría sembrada antes de la migración debe persistir');

    await db.close();
  });

  // Sprint flutter-saved-views-polish-v1 / H14 quality review: blindar
  // las ramas defensiva 1→3 y el guardrail UnimplementedError, que son el
  // primer schema bump del MVP. Sienta precedente para los próximos.

  test(
      'UT-18: rama defensiva 1→3 crea el índice + tabla saved_views '
      '(instalación que se saltó schemaVersion 2)',
      () async {
    final db = FincoreDatabase(NativeDatabase.memory());
    await db.accountsDao.listAll(); // fuerza onCreate.

    // Simular estado pre-1→3: dropear ambas estructuras.
    await db.customStatement('DROP TABLE saved_views');
    await db.customStatement('DROP INDEX idx_entries_occurred_active');

    // Llamar a onUpgrade vía `Migrator` directo, escenario from=1 to=3.
    final migrator = db.createMigrator();
    await db.migration.onUpgrade(migrator, 1, 3);

    // Verificar índice parcial creado.
    final idxRows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='index' "
          "AND name='idx_entries_occurred_active'",
          readsFrom: const {},
        )
        .get();
    expect(idxRows, hasLength(1),
        reason: 'rama 1→3 debe recrear idx_entries_occurred_active');

    // Verificar tabla saved_views creada y usable.
    final viewId = await db.savedViewsDao.create(
      name: 'Defensiva',
      filters: EntriesFilters.thisMonth(),
    );
    expect(viewId, isNotEmpty);

    await db.close();
  });

  test(
      'UT-19: guardrail UnimplementedError dispara para upgrade no '
      'implementado (RN-H02)',
      () async {
    final db = FincoreDatabase(NativeDatabase.memory());
    await db.accountsDao.listAll();
    final migrator = db.createMigrator();

    // Cualquier from/to que no esté entre las ramas explícitas debe
    // disparar el throw del guardrail.
    expect(
      () => db.migration.onUpgrade(migrator, 4, 99),
      throwsA(isA<UnimplementedError>()),
    );

    await db.close();
  });

  // ===========================================================================
  // Sprint flutter-onboarding-for-testers-v1: schema bump v3 → v4
  // ===========================================================================

  test(
      'MT-01: migración 3 → 4 crea tabla app_preferences sin tocar '
      'datos del usuario',
      () async {
    final db = FincoreDatabase(NativeDatabase.memory());
    // Forzar onCreate completo (queda en v4).
    final accountId = await db.accountsDao.create(name: 'Banamex_MT', type: 'debit');
    final categoryId = await db.categoriesDao.create(
      name: 'Comida_MT',
      appliesTo: 'expense',
      colorSlug: 'red',
      iconSlug: 'shopping-cart',
    );

    // Simular estado pre-3→4: dropear app_preferences.
    await db.customStatement('DROP TABLE app_preferences');
    final preRows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='app_preferences'",
          readsFrom: const {},
        )
        .get();
    expect(preRows, isEmpty);

    // Ejecutar onUpgrade(3, 4) vía Migrator directo.
    final migrator = db.createMigrator();
    await db.migration.onUpgrade(migrator, 3, 4);

    // Verificar tabla creada y usable.
    await db.appPreferencesDao.set('test_key', 'test_value');
    final value = await db.appPreferencesDao.get('test_key');
    expect(value, 'test_value');

    // Verificar que los datos del usuario sembrados antes de la migración
    // siguen ahí.
    final accountsAfter = await db.accountsDao.listAll();
    expect(accountsAfter.any((a) => a.id == accountId), isTrue);
    final categoriesAfter = await db.categoriesDao.listAll();
    expect(categoriesAfter.any((c) => c.id == categoryId), isTrue);

    await db.close();
  });

  test(
      'MT-02: rama defensiva 2 → 4 crea saved_views Y app_preferences',
      () async {
    final db = FincoreDatabase(NativeDatabase.memory());
    await db.accountsDao.listAll(); // fuerza onCreate

    // Simular estado v2: dropear tanto saved_views como app_preferences.
    await db.customStatement('DROP TABLE saved_views');
    await db.customStatement('DROP TABLE app_preferences');

    final migrator = db.createMigrator();
    await db.migration.onUpgrade(migrator, 2, 4);

    // Verificar ambas tablas creadas y usables.
    final viewId = await db.savedViewsDao.create(
      name: 'V2to4',
      filters: EntriesFilters.thisMonth(),
    );
    expect(viewId, isNotEmpty);
    await db.appPreferencesDao.set('mt02_key', 'mt02_value');
    expect(await db.appPreferencesDao.get('mt02_key'), 'mt02_value');

    await db.close();
  });

  test(
      'MT-03: rama defensiva 1 → 4 crea índice + saved_views + app_preferences',
      () async {
    final db = FincoreDatabase(NativeDatabase.memory());
    await db.accountsDao.listAll();

    // Simular estado v1: sin índice parcial ni saved_views ni app_preferences.
    await db.customStatement('DROP TABLE saved_views');
    await db.customStatement('DROP TABLE app_preferences');
    await db.customStatement('DROP INDEX idx_entries_occurred_active');

    final migrator = db.createMigrator();
    await db.migration.onUpgrade(migrator, 1, 4);

    // Verificar índice creado.
    final idxRows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='index' "
          "AND name='idx_entries_occurred_active'",
          readsFrom: const {},
        )
        .get();
    expect(idxRows, hasLength(1));

    // Verificar saved_views usable.
    final viewId = await db.savedViewsDao.create(
      name: 'V1to4',
      filters: EntriesFilters.thisMonth(),
    );
    expect(viewId, isNotEmpty);

    // Verificar app_preferences usable.
    await db.appPreferencesDao.set('mt03_key', 'mt03_value');
    expect(await db.appPreferencesDao.get('mt03_key'), 'mt03_value');

    await db.close();
  });

  // ===========================================================================
  // Sprint flutter-weekly-budgets-v1: schema bump v6 → v7
  // ===========================================================================
  // MG-01..MG-04 del test-plan. Mismo patrón que MT-01..03: la BD in-memory
  // abre siempre en schemaVersion actual (7) vía onCreate; para simular una
  // instalación existente en v6 dropeamos las 2 tablas del planeador semanal
  // + sus índices y llamamos a `onUpgrade` vía `Migrator` directo con
  // `from=6, to=7`.
  //
  // Refactor 2026-07-14: las tablas `budget_templates`/`budget_template_items`
  // fueron eliminadas — el rol de plantilla ahora vive como `is_template` en
  // `weekly_budgets`. MG-01..04 quedan con 2 tablas y 3 índices (sin
  // `idx_bt_items_template_sort`, reemplazado por `idx_weekly_budgets_template`).

  test(
      'MG-01: BD virgen con schemaVersion=7 (onCreate) → las 2 tablas del '
      'planeador semanal existen y son usables', () async {
    final db = FincoreDatabase(NativeDatabase.memory());
    await db.accountsDao.listAll(); // fuerza onCreate.

    for (final table in [
      'weekly_budgets',
      'weekly_budget_items',
    ]) {
      final rows = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='$table'",
            readsFrom: const {},
          )
          .get();
      expect(rows, hasLength(1), reason: 'tabla $table debería existir tras onCreate');
    }

    // Usable end-to-end vía el DAO, incluyendo el flag de plantilla.
    final budgetId = await db.weeklyBudgetsDao.createBudget(
      weekStartDate: DateTime(2026, 7, 17),
      label: 'MG-01',
    );
    expect(budgetId, isNotEmpty);
    await db.weeklyBudgetsDao.toggleTemplateFlag(budgetId);
    final row = await db.weeklyBudgetsDao.findById(budgetId);
    expect(row!.isTemplate, isTrue);

    await db.close();
  });

  test(
      'MG-02: BD "existente v6" (sin las 2 tablas nuevas) → onUpgrade(6, 7) '
      'las crea sin perder datos pre-existentes', () async {
    final db = FincoreDatabase(NativeDatabase.memory());
    await db.accountsDao.listAll(); // fuerza onCreate en v7.

    // Datos del usuario sembrados ANTES de simular la migración.
    final accountId =
        await db.accountsDao.create(name: 'Banamex_MG02', type: 'debit');
    final categoryId = await db.categoriesDao.create(
      name: 'Comida_MG02',
      appliesTo: 'expense',
      colorSlug: 'red',
      iconSlug: 'shopping-cart',
    );

    // Simular estado pre-6→7: dropear las 2 tablas nuevas + sus índices.
    await db.customStatement('DROP TABLE weekly_budget_items');
    await db.customStatement('DROP TABLE weekly_budgets');
    final preRows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' "
          "AND name IN ('weekly_budgets', 'weekly_budget_items')",
          readsFrom: const {},
        )
        .get();
    expect(preRows, isEmpty,
        reason: 'las 2 tablas deberían estar dropeadas antes de migrar');

    // Ejecutar onUpgrade(6, 7) vía Migrator directo.
    final migrator = db.createMigrator();
    await db.migration.onUpgrade(migrator, 6, 7);

    // Verificar las 2 tablas creadas y usables end-to-end.
    final budgetId = await db.weeklyBudgetsDao.createBudget(
      weekStartDate: DateTime(2026, 7, 17),
      label: 'MG-02',
    );
    await db.weeklyBudgetsDao.addItem(
      budgetId: budgetId,
      name: 'Renglón MG-02',
      amount: 100,
      kind: 'expense',
    );
    expect(await db.weeklyBudgetsDao.watchAll().first, hasLength(1));
    await db.weeklyBudgetsDao.toggleTemplateFlag(budgetId);
    expect(await db.weeklyBudgetsDao.watchTemplates().first, hasLength(1));

    // Verificar que los datos pre-existentes NO se perdieron.
    final accountsAfter = await db.accountsDao.listAll();
    expect(accountsAfter.any((a) => a.id == accountId), isTrue,
        reason: 'cuenta sembrada antes de la migración debe persistir');
    final categoriesAfter = await db.categoriesDao.listAll();
    expect(categoriesAfter.any((c) => c.id == categoryId), isTrue,
        reason: 'categoría sembrada antes de la migración debe persistir');

    await db.close();
  });

  test(
      'MG-03: migración 6 → 7 es aditiva pura — crea los 3 índices nuevos '
      'sin migración de datos', () async {
    final db = FincoreDatabase(NativeDatabase.memory());
    await db.accountsDao.listAll();

    // Simular estado pre-6→7: dropear tablas + índices.
    await db.customStatement('DROP INDEX idx_weekly_budgets_start');
    await db.customStatement('DROP INDEX idx_wb_items_budget_sort');
    await db.customStatement('DROP INDEX idx_weekly_budgets_template');
    await db.customStatement('DROP TABLE weekly_budget_items');
    await db.customStatement('DROP TABLE weekly_budgets');

    final migrator = db.createMigrator();
    await db.migration.onUpgrade(migrator, 6, 7);

    for (final index in [
      'idx_weekly_budgets_start',
      'idx_wb_items_budget_sort',
      'idx_weekly_budgets_template',
    ]) {
      final rows = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='index' AND name='$index'",
            readsFrom: const {},
          )
          .get();
      expect(rows, hasLength(1), reason: 'índice $index debe recrearse en 6→7');
    }

    await db.close();
  });

  test(
      'MG-QR-M4: 5→11, 6→11 y 7→11 crean loans + columnas + índice '
      '(hotfix quality-review — ramas defensivas)', () async {
    for (final from in [5, 6, 7]) {
      final db = FincoreDatabase(NativeDatabase.memory());
      await db.accountsDao.listAll(); // fuerza open y schema real (v11).
      final migrator = db.createMigrator();
      // No debe crashear con UnimplementedError.
      await db.migration.onUpgrade(migrator, from, 11);
      // La tabla `loans` existe.
      final loansTable = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='loans'",
            readsFrom: const {},
          )
          .get();
      expect(loansTable, hasLength(1),
          reason: 'ruta $from→11 debe crear la tabla loans');
      // La columna `is_monthly_payment` existe en journal_entries.
      final colProbe = await db
          .customSelect(
            "SELECT COUNT(*) AS c FROM pragma_table_info('journal_entries') "
            "WHERE name = 'is_monthly_payment'",
            readsFrom: const {},
          )
          .getSingle();
      expect(colProbe.read<int>('c'), 1,
          reason: 'ruta $from→11 debe agregar is_monthly_payment');
      // Índice parcial de loans en entries.
      final idxProbe = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='index' "
            "AND name='idx_entries_loan'",
            readsFrom: const {},
          )
          .get();
      expect(idxProbe, hasLength(1),
          reason: 'ruta $from→11 debe crear idx_entries_loan');
      await db.close();
    }
  });

  test(
      'MG-04: guardrail UnimplementedError sigue activo para un upgrade no '
      'implementado (from=99, to=100)', () async {
    final db = FincoreDatabase(NativeDatabase.memory());
    await db.accountsDao.listAll();
    final migrator = db.createMigrator();

    expect(
      () => db.migration.onUpgrade(migrator, 99, 100),
      throwsA(isA<UnimplementedError>()),
    );

    await db.close();
  });
}

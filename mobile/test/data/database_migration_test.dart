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

    // Cualquier from/to que no esté entre las ramas explícitas (1→2, 2→3,
    // 1→3) debe disparar el throw del guardrail.
    expect(
      () => db.migration.onUpgrade(migrator, 3, 99),
      throwsA(isA<UnimplementedError>()),
    );

    await db.close();
  });
}

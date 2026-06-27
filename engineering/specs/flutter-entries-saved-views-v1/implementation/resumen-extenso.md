# Resumen extenso — flutter-entries-saved-views-v1

## Contexto tomado de spec.md y clarificaciones

Sprint mediano (~5h reales) que sigue al F5 (saldo a fecha). **Primer
schema bump del MVP local** y primera entidad de "preferencias de UI"
en BD.

Decisiones cerradas con `preguntas.md`:

- **P-001 (formato fecha)**: respondida "híbrido". Preset semántico
  (`thisMonth`/`lastMonth`/`thisYear`) se guarda como slug rolling →
  al deserializar recalcula con `dateRangeForPreset(preset,
  DateTime.now())`. `custom` se guarda como rango fijo ISO8601.
- **P-002 (lugar UI)**: respondida "híbrido". **Guardar** dentro del
  panel (`OutlinedButton` debajo de la última sección). **Aplicar/
  Renombrar/Eliminar** desde icono `bookmark_outline` en el AppBar de
  `EntriesListScreen` que abre un sheet modal.

Reglas de negocio críticas (RN-V01..V10):

- Tabla `saved_views`: id UUID v7, name (1-50 chars, único
  case-insensitive), filters_json (string JSON), created_at.
- `name` validación trimmed + duplicate check con
  `LOWER(name) = LOWER(?)` en SQL.
- `wipeAll()` borra también las vistas (RN-V10 — coherencia con
  "arrancar limpio").
- Orden = `created_at DESC` (RN-V07).
- IDs huérfanos (cuentas/categorías archivadas) tolerados por el
  panel existente.

## Relación con plan/plan.md y plan/tasks.md

Las **33 tareas** del plan ejecutadas en orden de fases F0 → F8 con
2 desviaciones documentadas:

- **F0** (T001): baseline 279 verdes.
- **F1** (T002-T005): tabla + migración + wipeAll + registro DAO.
- **F2** (T006-T010): DAO con `@DriftAccessor` + errores tipados +
  CRUD + watchAll. 10 tests data.
- **F3** (T011-T014): serializer híbrido en `EntriesFilters`. 6 tests.
- **F4** (T015-T019): UI Panel — dialog + botón + handler + error
  mapping + AppDependencies.
- **F5** (T020-T024): UI AppBar — sheet con lista + acciones ⋮ +
  empty state + icono bookmark.
- **F6** (T025-T028): 3 widget tests.
- **F7** (T029): test de migración (UT-17).
- **F8** (T030-T033): release + APK + verify + docs.

## Cambios principales por módulo o capa

### Capa de datos (`mobile/lib/data/`)

**`database.dart`**:
- Tabla `SavedViews extends Table` con `@DataClassName('SavedViewRow')`
  para evitar conflicto con el modelo público `SavedView`.
- `schemaVersion: 2 → 3`.
- `daos: [..., SavedViewsDao]`.
- Rama en `onUpgrade(from == 2 && to == 3)`: `m.createTable(savedViews)`.
- Rama defensiva `onUpgrade(from == 1 && to == 3)` que combina ambas
  migraciones para instalaciones que se saltaron la v2.

**`daos/saved_views_dao.dart` (nuevo)**:
- `SavedView` modelo público inmutable con `EntriesFilters`
  deserializado.
- `SavedViewsDaoError` con códigos `invalid_name`, `duplicate_name`,
  `not_found`.
- `@DriftAccessor(tables: [SavedViews])` con CRUD: `create`,
  `findById`, `listAll`, `watchAll`, `rename`, `removeById`,
  `removeAll`.
- **Métodos `removeById`/`removeAll`** (no `delete`/`deleteAll`)
  porque chocaban con `DatabaseConnectionUser.delete` (statement
  builder de drift).
- Validación case-insensitive con `LOWER(name) = LOWER(?)` via
  `customSelect`.
- Serialización JSON con `dart:convert` (`jsonEncode`/`jsonDecode`).

**`entries_filters.dart`**:
- `toSavedJson()` retorna `Map<String, dynamic>` con `datePreset` slug.
  Si `custom`: incluye `from`/`to` ISO8601. Si semántico: solo el slug.
- `fromSavedJson(Map, [now])` factory tolerante. Si `custom`: parsea
  `from`/`to`. Si semántico: recalcula con `dateRangeForPreset`.
  Defaults para campos faltantes. Fallback a `thisMonth` si todo
  corrupto.
- Helpers privados `_parseSavedList` y `_tryParseDouble` tolerantes.

**`backup.dart`**:
- `_wipeTablesInternal()` agrega `await _db.delete(_db.savedViews).go()`
  al final.

### Capa de presentación

**`widgets/save_view_dialog.dart` (nuevo)**:
- `showSaveViewDialog(context, title, initialName)` retorna
  `Future<String?>`. Cancelar → null. Guardar → nombre trimmed.
- `TextFormField` con validator (1-50 chars), autofocus, submit con
  enter.

**`widgets/saved_view_picker_sheet.dart` (nuevo)**:
- `showSavedViewPickerSheet(context)` retorna
  `Future<EntriesFilters?>`. Cancelar → null. Tap en vista → filtros
  deserializados.
- `StreamBuilder<List<SavedView>>` sobre `watchAll()`.
- Cada `ListTile`: nombre + fecha creación + `PopupMenuButton` con
  Renombrar/Eliminar.
- Tap en row → `Navigator.pop(context, view.filters)`.
- Eliminar usa `showConfirmDialog` destructivo.
- Empty state: ícono + "No tenés vistas guardadas todavía." + ayuda.

**`screens/entries_filters_screen.dart`**:
- `OutlinedButton.icon` "Guardar como vista" entre la sección
  categorías y el bottom bar.
- Handler `_saveView()`: pide nombre via dialog → parsea controllers
  de monto → si min > max → snackbar warning → si OK llama
  `savedViewsDao.create(name, filters)`.

**`screens/entries_list_screen.dart`**:
- Nuevo `IconButton` con `Icons.bookmark_outline` en `actions` (a la
  izquierda del icono filtros).
- Handler `_openSavedViews()`: abre sheet. Si retorna filtros,
  `setState(() => _filters = result)`.

**`widgets/error_snackbar.dart`**:
- Helper `savedViewsDaoErrorToMessage(SavedViewsDaoError)` con switch
  por código.
- Branch nuevo en `switch (error)` antes de `Exception()`:
  `SavedViewsDaoError() => savedViewsDaoErrorToMessage(error)`.

**`app_dependencies.dart`**:
- Expone `savedViewsDao` como campo final + lo construye en
  `fromDatabase`.

### Tests

**`test/data/saved_views_dao_test.dart` (10 tests)**:
- CRUD: UT-01 create+findById, UT-02 name vacío, UT-03 name > 50,
  UT-04 duplicate case-insensitive, UT-05 rename + duplicate, UT-06
  removeById, UT-07 listAll orden, UT-08 watchAll reactivo.
- Errores: UT-09 rename not_found, UT-10 removeById not_found.

**`test/data/entries_filters_saved_test.dart` (6 tests)**:
- UT-11 round-trip custom, UT-12 thisMonth rolling, UT-13 custom fijo,
  UT-14 fallback, UT-15 campos extra, UT-16 listas.

**`test/data/database_migration_test.dart` (1 test)**:
- UT-17 valida que el CREATE TABLE equivalente al de
  `m.createTable(savedViews)` deja la tabla operativa + datos
  sembrados antes de la migración persisten.

**`test/screens/saved_views_flow_test.dart` (3 tests)**:
- WT-01 guardar desde panel + persiste en BD.
- WT-02 aplicar desde AppBar → filtros se setean.
- WT-03 empty state cuando no hay vistas.

## Desviaciones respecto al plan

**DV-1** — **Renombrar `delete`/`deleteAll` a `removeById`/`removeAll`**:
el plan los nombraba `delete` y `deleteAll`. Conflicto con
`DatabaseConnectionUser.delete<Table>(...)` que es statement builder
de drift. Renombrar elimina el conflict sin afectar funcionalidad.

**DV-2** — **`@DataClassName('SavedViewRow')`**: el plan no nombraba
esto. Drift por convención genera `SavedView` (singular del nombre
de la tabla) para la fila, lo cual chocaba con mi modelo público
`SavedView`. Annotation explícita resuelve.

**DV-3 (menor)** — **rama 1 → 3 en `onUpgrade`**: el plan solo
nombraba rama 2 → 3. Agregué la defensiva 1 → 3 para instalaciones
que pueden venir de una build muy vieja. Aditivo, sin riesgo.

**DV-4 (menor)** — **mapeo de `SavedViewsDaoError` en `showErrorSnackbar`**:
el plan asumía que el branch existente `Exception() =>
error.toString()` era suficiente. Pero ese muestra
`SavedViewsDaoError(code): message` literal — UX feo. Agregué helper
+ branch dedicado.

## Pruebas realizadas y recomendadas

**Realizadas** (automatizado):
- 0 errores en analyze, 299/299 verdes en 22s, APK validado.

**Recomendadas** (smoke manual, no del sprint):
- **SM-01 crítico**: migración real cel sobre 0.9.0+61.
- SM-02..SM-08: guardar, aplicar, renombrar, eliminar, duplicado,
  rolling, wipeAll.

## Riesgos residuales y posibles regresiones

- **R-T01 del plan** (mitigado parcialmente): test de migración cubre
  el SQL del CREATE TABLE + datos preservados. Validación end-to-end
  "onUpgrade real" requiere file-backed DB que drift in-memory no
  permite — cobertura cubierta por SM-01 manual.
- Sin regresión esperada en el resto de la suite (los 279 tests
  previos siguen verdes).

## Aplicación de engineering-code-standards

Skill no invocada explícitamente. Aplicación implícita: modelos
inmutables, errores tipados con código + mensaje, validación en
boundary del DAO (no en UI), parametrización segura SQL con
`Variable.withString`, doc-comments con folios (RN-V01..V10,
RF-001..012, etc.), helpers privados reutilizables, naming
consistente con el resto del codebase, sin deps externas.

## Aplicación de branch-quality-review

`branch-quality-review` disponible pero NO invocada (no pedida).
Recomendable para este sprint dado que es **primer schema bump**:

```bash
branch-quality-review flutter-entries-saved-views-v1
```

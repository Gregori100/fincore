# Implementation Review: flutter-entries-saved-views-v1

## Resumen de lo implementado

Sprint cerrado. **Primer schema bump del MVP local** (versión 2 → 3).
Vistas guardadas del panel de filtros de `/entries`: Diego configura
filtros, tap "Guardar como vista" → ingresa nombre custom → vista
persistida en BD. Después abre el icono bookmark del AppBar → sheet
con todas las vistas → tap aplica filtros, menú ⋮ permite renombrar/
eliminar. Serialización híbrida: preset semántico (thisMonth, etc.)
se guarda como slug rolling; custom guarda `from`/`to` exactos.
Migración aditiva 2 → 3 no destructiva.

## Archivos principales modificados

Nuevos:

- `mobile/lib/data/daos/saved_views_dao.dart` (~200 líneas: DAO con
  CRUD + errores tipados + watchAll).
- `mobile/lib/widgets/save_view_dialog.dart` (~90 líneas: dialog para
  nombre con validación).
- `mobile/lib/widgets/saved_view_picker_sheet.dart` (~230 líneas: sheet
  modal con lista + acciones ⋮).
- `mobile/test/data/saved_views_dao_test.dart` (10 tests data).
- `mobile/test/data/entries_filters_saved_test.dart` (6 tests
  serializer).
- `mobile/test/data/database_migration_test.dart` (1 test migración).
- `mobile/test/screens/saved_views_flow_test.dart` (3 widget tests).

Modificados:

- `mobile/lib/data/database.dart` (+~25 líneas: tabla `SavedViews` +
  `@DataClassName('SavedViewRow')` + `schemaVersion = 3` + migración
  2→3 + 1→3 + registro DAO).
- `mobile/lib/data/entries_filters.dart` (+~110 líneas: `toSavedJson`,
  `fromSavedJson`, helpers `_parseSavedList`, `_tryParseDouble`).
- `mobile/lib/data/backup.dart` (+1 línea: `wipeAll` borra
  `saved_views`).
- `mobile/lib/app_dependencies.dart` (+expone `SavedViewsDao`).
- `mobile/lib/widgets/error_snackbar.dart` (+branch
  `SavedViewsDaoError` + helper `savedViewsDaoErrorToMessage`).
- `mobile/lib/screens/entries_filters_screen.dart` (+botón "Guardar
  como vista" + handler `_saveView`).
- `mobile/lib/screens/entries_list_screen.dart` (+icono bookmark en
  AppBar + handler `_openSavedViews`).
- `mobile/pubspec.yaml` (versión 0.10.0+62 + nota).
- `mobile/android/app/build.gradle.kts` (versionCode 62 / versionName
  0.10.0).

## Tareas completadas

Las 33 tareas del plan cerradas con 1 desviación documentada en F2
(rename de método `delete` para no chocar con drift base).

- **F0** (T001): baseline 279 verdes confirmado.
- **F1** (T002-T005): tabla `SavedViews` + `@DataClassName` para evitar
  conflict con modelo público + `schemaVersion = 3` + migración 2→3 +
  rama defensiva 1→3 + `wipeAll` extendido.
- **F2** (T006-T010): DAO con CRUD, errores tipados, watchAll. 10
  tests data verdes. Métodos `delete`/`deleteAll` renombrados a
  `removeById`/`removeAll` para no chocar con
  `DatabaseConnectionUser.delete` (statement builder de drift).
- **F3** (T011-T014): serializer híbrido. 6 tests verdes.
- **F4** (T015-T019): UI Panel — `SaveViewDialog`, botón "Guardar
  como vista", handler `_saveView`, error_snackbar extendido,
  `AppDependencies` expone `savedViewsDao`.
- **F5** (T020-T024): UI AppBar — `SavedViewPickerSheet` con lista,
  empty state, menu ⋮ con Renombrar/Eliminar, icono bookmark en
  AppBar.
- **F6** (T025-T028): 3 widget tests del flow completo.
- **F7** (T029): test de migración (UT-17) que valida que el SQL
  CREATE TABLE es válido + datos viejos intactos.
- **F8** (T030-T033): suite verde 299/299, bump 0.10.0+62, APK +
  verify, docs.

## Tareas pendientes

Ninguna del plan. Pendiente del usuario (no del sprint):

- **Smoke SM-01 crítico**: instalar APK encima de versión anterior
  (0.9.0+61 → 0.10.0+62) → verificar que la migración no rompe la BD
  existente con datos del usuario. Es el primer schema bump real;
  validar en cel.

## Riesgos residuales

- **R-T01 del plan** (mitigado): primer schema bump. UT-17 valida el
  CREATE TABLE + datos preservados, pero la validación end-to-end
  "abrir BD v2 → onUpgrade dispara" requiere file-backed DB que el
  test in-memory de drift no permite. Cobertura cubierta por smoke
  manual SM-01.
- **R-T02 del plan** (cerrado): `serialize`/`parse` (query params) y
  `toSavedJson`/`fromSavedJson` (BD) coexisten con doc-comments
  claros.
- **R-T03 del plan** (cerrado): `LOWER(name) = LOWER(?)` valida
  duplicados case-insensitive con `customSelect`.
- **R-T04 del plan** (cerrado): `wipeAll()` extendido para borrar
  `saved_views`.
- **R-T05 del plan** (cerrado): `fromSavedJson` con try/catch +
  fallback a thisMonth.
- **Hallazgo nuevo**: `SavedView` choca con clase generada por drift
  para la fila. Resuelto con `@DataClassName('SavedViewRow')`. Sin
  impacto funcional.

## Pruebas realizadas

- `flutter analyze` → 0 errores, 4 hints `info` cosméticos
  pre-existentes (no del sprint).
- `flutter test` completo → **299/299 verdes** en 22s (279 previos +
  20 nuevos).
- `flutter test test/data/saved_views_dao_test.dart` → 10/10 verdes
  en 1s.
- `flutter test test/data/entries_filters_saved_test.dart` → 6/6
  verdes en 1s.
- `flutter test test/data/database_migration_test.dart` → 1/1 verde
  en 1s.
- `flutter test test/screens/saved_views_flow_test.dart` → 3/3 verdes
  en 4s.
- `flutter build apk --release --split-per-abi` → 3 APKs.
- `bash scripts/verify-apk.sh` → versionCode 2062 / versionName
  0.10.0 consistentes.

## Pruebas recomendadas

**SM-01 crítico — migración real en cel** con APK `0.10.0+62`:

1. Instalar el APK sobre la versión 0.9.0+61 que ya tiene datos
   (cuentas + entries).
2. Abrir la app → dashboard muestra BO/DE/CR correctos (los datos
   sobrevivieron a la migración).
3. Ir a `/entries` → ver el icono bookmark nuevo en AppBar.
4. Tap bookmark → sheet con empty state.

Otros smoke (SM-02..SM-08): documentados en `test-plan.md`. Cubren
guardar, aplicar, renombrar, eliminar, duplicado, wipeAll, import.

## Posibles regresiones

Cero detectadas en automatizado. Áreas a vigilar en smoke manual:

- **Migración real**: el escenario crítico. Si la BD existente tiene
  schema corrupto u otra anomalía, drift podría reportar error al
  abrir.
- **AppBar más cargado**: nuevo icono entre el back y filtros. Verificar
  visualmente.
- **Panel más largo**: nuevo botón al final. Posible scroll extra en cel
  chico — `scrollUntilVisible` en WT-01 sugiere que sí lo es.
- **`wipeAll` extendido**: Settings → "Reiniciar cuenta" ahora también
  borra vistas. Verificar.

## Recomendaciones para code review humano

- Verificar la migración 2 → 3: la rama `if (from == 2 && to == 3)`
  solo hace `m.createTable(savedViews)`. Aditiva, no toca tablas
  existentes. El guardrail `throw UnimplementedError(...)` sigue al
  final para impedir bumps futuros sin migración.
- Rama defensiva 1 → 3 agregada para instalaciones que se saltaron la
  v2 (improbable, pero posible si alguien viene de una build muy
  vieja).
- `@DataClassName('SavedViewRow')` evita choque entre el modelo
  `SavedView` (público, exporta `EntriesFilters` deserializado) y la
  fila generada por drift.
- `removeById`/`removeAll` (no `delete`) para no chocar con
  `DatabaseConnectionUser.delete`. Patrón coherente para futuros
  DAOs.
- Validación de `name` case-insensitive con `LOWER` en SQL — más
  robusto que comparar en Dart (drift permite parametrización segura).
- `fromSavedJson` tolerante: JSON corrupto → fallback a
  `thisMonth`. Sin lanzar.
- `branch-quality-review` disponible pero NO invocado (no pedido).
  Si Diego quiere revisión exhaustiva del schema bump:
  `branch-quality-review flutter-entries-saved-views-v1`.

# Tasks — flutter-entries-saved-views-v1

## F0 — Validación pre-sprint

- [ ] T001 Validación de calidad: confirmar baseline.
  RF: —
  Depende de: ninguna
  Paralelizable: no
  Criterio de terminado: `flutter test` → 279/279 verdes, `flutter
  analyze` → 0 errores, working tree limpio.

## F1 — Schema bump (base de datos)

- [ ] T002 Base de datos: agregar clase `SavedViews extends Table` en
  `mobile/lib/data/database.dart`.
  RF: RF-001
  Depende de: T001
  Paralelizable: no
  Criterio de terminado: tabla con columnas `id TEXT PK`, `name
  TEXT`, `filters_json TEXT`, `created_at DATETIME`. Drift codegen
  generado.

- [ ] T003 Base de datos: registrar `SavedViewsDao` en
  `@DriftDatabase(daos: [..., SavedViewsDao])` y bumpear
  `schemaVersion = 3`.
  RF: RF-001
  Depende de: T002, T006
  Paralelizable: no
  Criterio de terminado: `schemaVersion` retorna 3. El registro de
  DAO requiere T006 (clase DAO definida).

- [ ] T004 Base de datos: agregar rama de migración en `onUpgrade`
  para `from == 2 && to == 3`.
  RF: RF-002
  Depende de: T003
  Paralelizable: no
  Criterio de terminado:
  ```dart
  if (from == 2 && to == 3) {
    await m.createTable(savedViews);
    return;
  }
  ```
  El guardrail `throw UnimplementedError(...)` queda intacto al final.

- [ ] T005 Backend: extender `BackupService.wipeAll()` para truncar
  también `saved_views`.
  RF: RN-V10
  Depende de: T004
  Paralelizable: si (con F2)
  Criterio de terminado: `wipeAll()` ejecuta `delete(savedViews).go()`
  antes/después de los otros deletes.

## F2 — DAO + modelo

- [ ] T006 Backend: definir `SavedView` modelo en
  `mobile/lib/data/daos/saved_views_dao.dart` y la clase del DAO con
  `@DriftAccessor(tables: [SavedViews])`.
  RF: RF-003, RF-006
  Depende de: T002
  Paralelizable: no
  Criterio de terminado: archivo compila + drift codegen ok.
  `SavedView` inmutable con `id`, `name`, `filters` (`EntriesFilters`
  ya deserializado), `createdAt`.

- [ ] T007 Backend: implementar `SavedViewsDaoError` con códigos
  `invalid_name`, `duplicate_name`, `not_found`.
  RF: RF-004
  Depende de: T006
  Paralelizable: si (con T008-T010)
  Criterio de terminado: clase `SavedViewsDaoError implements
  Exception` con `code` y `message`. Pattern idéntico a
  `AccountsDaoError`.

- [ ] T008 Backend: implementar `create({name, filters})`,
  `findById(id)`, `listAll()`, `watchAll()` en `SavedViewsDao`.
  RF: RF-003
  Depende de: T006
  Paralelizable: si (con T007)
  Criterio de terminado:
  - `create`: valida name (trim, length 1-50, no duplicado
    case-insensitive con `LOWER(name) = LOWER(?)` via customSelect).
    Genera id v7. Serializa `filters` con `toSavedJson()` (depende
    de F3).
  - `findById`: select by id, deserializa `filters_json` →
    `EntriesFilters`. Retorna null si no existe.
  - `listAll`: SELECT ordered by `created_at DESC`.
  - `watchAll`: idem `listAll` con `.watch()`.

- [ ] T009 Backend: implementar `rename({id, name})` y
  `delete({id})`.
  RF: RF-003
  Depende de: T008
  Paralelizable: no
  Criterio de terminado:
  - `rename`: valida name; chequea que id existe (lanza `not_found`
    si no); chequea duplicado case-insensitive excluyendo el propio
    id; update.
  - `delete`: chequea que id existe; `delete(savedViews)..where`.

- [ ] T010 Pruebas: tests data del DAO en
  `mobile/test/data/saved_views_dao_test.dart`.
  RF: CM-01
  Depende de: T009
  Paralelizable: si
  Criterio de terminado: 10 tests (UT-01 a UT-10) pasan. Cubre CRUD,
  errores tipados, reactividad, orden.

## F3 — Serializer

- [ ] T011 Backend: implementar `EntriesFilters.toSavedJson()` en
  `mobile/lib/data/entries_filters.dart`.
  RF: RF-005
  Depende de: T001 (independiente de F1/F2)
  Paralelizable: si
  Criterio de terminado:
  - Retorna `Map<String, dynamic>` con `datePreset` slug y campos
    según RN-V04.
  - Si `datePreset == custom`: incluye `from` y `to` como ISO8601.
  - Si preset semántico: omite `from/to` (rolling).
  - Incluye `kinds`, `accountIds`, `categoryIds`, `minAmount`,
    `maxAmount` cuando no son defaults.

- [ ] T012 Backend: implementar `EntriesFilters.fromSavedJson(Map)`
  factory tolerante.
  RF: RF-005
  Depende de: T011
  Paralelizable: si
  Criterio de terminado:
  - Si `datePreset == custom`: usa `from`/`to` del JSON.
  - Si preset semántico: recalcula con
    `dateRangeForPreset(preset, DateTime.now())`.
  - Campos faltantes → defaults (kinds=[], accountIds=[], etc.).
  - JSON corrupto → fallback `EntriesFilters.thisMonth()`.

- [ ] T013 Backend: usar `toSavedJson()`/`fromSavedJson()` en el DAO
  (`SavedViewsDao.create` y `findById`/`listAll`).
  RF: RF-005
  Depende de: T011, T012, T008
  Paralelizable: no
  Criterio de terminado: la conversión Map ↔ String se hace con
  `jsonEncode`/`jsonDecode` de `dart:convert`.

- [ ] T014 Pruebas: tests del serializer en
  `mobile/test/data/entries_filters_saved_test.dart`.
  RF: CM-02
  Depende de: T012
  Paralelizable: si
  Criterio de terminado: 6 tests (UT-11 a UT-16) pasan. Cubre
  round-trip, rolling, custom fijo, JSON corrupto, campos extra.

## F4 — UI panel (Guardar vista)

- [ ] T015 Frontend: crear `mobile/lib/widgets/save_view_dialog.dart`
  con dialog para nombre.
  RF: RF-008
  Depende de: T001
  Paralelizable: si (con F5)
  Criterio de terminado: `Future<String?> showSaveViewDialog(
  BuildContext context)` retorna el nombre ingresado o null si
  Cancelar. `TextFormField` con `maxLength: 50` + validator no vacío.

- [ ] T016 Frontend: agregar botón "Guardar vista" en
  `mobile/lib/screens/entries_filters_screen.dart`.
  RF: RF-007
  Depende de: T015
  Paralelizable: no
  Criterio de terminado: botón debajo de la última sección antes del
  bottom bar. `OutlinedButton.icon` con `Icons.bookmark_outline`.

- [ ] T017 Frontend: implementar handler `_saveView()` que llama al
  dialog + DAO.
  RF: RF-008, RF-011
  Depende de: T016, T013
  Paralelizable: no
  Criterio de terminado: handler abre dialog → si nombre válido →
  llama `savedViewsDao.create(name, _editing)` → snackbar éxito o
  error según `SavedViewsDaoError`.

- [ ] T018 Frontend: extender `mobile/lib/widgets/error_snackbar.dart`
  con 3 cases nuevos.
  RF: RF-011
  Depende de: T007
  Paralelizable: si
  Criterio de terminado: 3 cases en el switch del error mapper:
  - `invalid_name` → "El nombre no es válido. Probá con 1-50
    caracteres."
  - `duplicate_name` → "Ya tenés una vista con ese nombre."
  - `not_found` → "Esa vista ya no existe."

- [ ] T019 Frontend: actualizar `AppDependencies` para exponer
  `SavedViewsDao`.
  RF: —
  Depende de: T009
  Paralelizable: si
  Criterio de terminado: `AppDependencies` instancia y expone
  `savedViewsDao`.

## F5 — UI AppBar (Aplicar/Renombrar/Eliminar)

- [ ] T020 Frontend: crear
  `mobile/lib/widgets/saved_view_picker_sheet.dart`.
  RF: RF-007, RF-012
  Depende de: T019
  Paralelizable: no
  Criterio de terminado: `Future<EntriesFilters?>
  showSavedViewPickerSheet(BuildContext context)` retorna los filtros
  de la vista seleccionada o null si cierra sin seleccionar.
  `showModalBottomSheet` con `StreamBuilder<List<SavedView>>` sobre
  `watchAll()`. Empty state inline si lista vacía.

- [ ] T021 Frontend: implementar item del sheet con tap (aplicar) y
  ⋮ (menú de acciones).
  RF: RF-007, RF-012
  Depende de: T020
  Paralelizable: si (con T022, T023)
  Criterio de terminado:
  - Tap en el row → resuelve el future con los filtros de la vista.
  - Tap en ⋮ → `PopupMenuButton` con "Renombrar" y "Eliminar".

- [ ] T022 Frontend: implementar handler "Renombrar" en el sheet con
  `showSaveViewDialog` pre-llenado.
  RF: RF-009
  Depende de: T021, T015
  Paralelizable: si
  Criterio de terminado: tap "Renombrar" abre dialog con `initialName`
  → si nombre válido → llama `savedViewsDao.rename(id, name)` →
  snackbar.

- [ ] T023 Frontend: implementar handler "Eliminar" con
  `showConfirmDialog` destructivo.
  RF: RF-010
  Depende de: T021
  Paralelizable: si
  Criterio de terminado: tap "Eliminar" → confirm "¿Eliminar la vista
  X?" con `destructive: true` → llama `savedViewsDao.delete(id)` →
  snackbar.

- [ ] T024 Frontend: agregar `IconButton` con `Icons.bookmark_outline`
  en `mobile/lib/screens/entries_list_screen.dart` AppBar.
  RF: RF-007
  Depende de: T020
  Paralelizable: no
  Criterio de terminado: icono visible a la izquierda del icono de
  filtros existente. Tap abre el sheet. Si retorna filtros, los aplica
  con `setState(() => _filters = result)`.

## F6 — Widget tests

- [ ] T025 Pruebas: crear `mobile/test/screens/saved_views_flow_test.dart`
  con helper de setup.
  RF: —
  Depende de: T024
  Paralelizable: no
  Criterio de terminado: archivo con `setUp` del harness + 1 test
  smoke "el icono bookmark renderea en AppBar".

- [ ] T026 Pruebas: WT-01 Guardar vista desde el panel.
  RF: CM-03
  Depende de: T025
  Paralelizable: si (con T027, T028)
  Criterio de terminado: abrir panel → tap chip "Gasto" → tap
  "Guardar vista" → enterText "Test" → tap Guardar → verificar que
  `savedViewsDao.listAll()` retorna 1 vista con name="Test".

- [ ] T027 Pruebas: WT-02 Aplicar vista desde AppBar.
  RF: CM-03
  Depende de: T025
  Paralelizable: si
  Criterio de terminado: seed con 1 vista vía DAO → tap icono
  bookmark → sheet visible → tap en la vista → sheet cerrado +
  filtros aplicados (verificar via `_ActiveFiltersBar`).

- [ ] T028 Pruebas: WT-03 Empty state cuando no hay vistas.
  RF: CM-03, RF-012
  Depende de: T025
  Paralelizable: si
  Criterio de terminado: sin vistas sembradas → tap icono → sheet
  muestra "No tenés vistas guardadas todavía.".

## F7 — Tests de migración

- [ ] T029 Pruebas: test de migración 2 → 3 en
  `mobile/test/data/database_migration_test.dart`.
  RF: CM-06
  Depende de: T004
  Paralelizable: si (con F6)
  Criterio de terminado: crear `FincoreDatabase` v2 manualmente con
  seed (Bolsa + entries) → ejecutar migración a v3 → verificar que
  tabla `saved_views` existe y datos viejos intactos.

## F8 — Release

- [ ] T030 Validación de calidad: `flutter analyze` + `flutter test`.
  RF: —
  Depende de: T010, T014, T026, T027, T028, T029
  Paralelizable: no
  Criterio de terminado: 0 errores. ~296 tests verdes (279 previos +
  17 nuevos).

- [ ] T031 Documentación: bump `pubspec.yaml` a `0.10.0+62` +
  `android/app/build.gradle.kts` (versionCode 62, versionName 0.10.0).
  Nota del cambio.
  RF: —
  Depende de: T030
  Paralelizable: si (con T032)
  Criterio de terminado: ambos archivos consistentes.

- [ ] T032 Validación de calidad: `flutter build apk --release
  --split-per-abi` + `bash scripts/verify-apk.sh`.
  RF: CM-05
  Depende de: T031
  Paralelizable: no
  Criterio de terminado: 3 APKs + verify OK con versionCode 2062 /
  versionName 0.10.0.

- [ ] T033 Documentación: crear
  `engineering/specs/flutter-entries-saved-views-v1/implementation/`
  con los 3 artefactos obligatorios.
  RF: —
  Depende de: T032
  Paralelizable: no
  Criterio de terminado: `implementation-review.md`,
  `resumen-ejecutivo.md`, `resumen-extenso.md` escritos.

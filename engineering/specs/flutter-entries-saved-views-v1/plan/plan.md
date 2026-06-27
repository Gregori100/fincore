# Plan técnico — flutter-entries-saved-views-v1

## Enfoque técnico

Sprint mediano (~5-7h). **Primer schema bump del proyecto local-first**:

1. **Base de datos**: tabla `SavedViews` nueva en drift, `schemaVersion
   2 → 3`, migración aditiva en `MigrationStrategy.onUpgrade` (no
   destructiva).
2. **DAO**: `SavedViewsDao` con CRUD + errores tipados +
   `watchAll()` reactivo.
3. **Modelo + serializer**: `SavedView` inmutable. Métodos en
   `EntriesFilters`: `toSavedJson()` (híbrido — preset semántico
   guarda slug; custom guarda ISO8601) y `fromSavedJson(Map)`
   (tolerante con defaults).
4. **UI panel**: botón "Guardar vista" dentro de
   `EntriesFiltersScreen` + dialog para nombre.
5. **UI AppBar**: icono `bookmark_outline` en
   `EntriesListScreen` + dropdown / menu sheet con lista de vistas.
6. **UI acciones**: menú ⋮ por vista con "Renombrar" / "Eliminar"
   (confirmación destructiva).
7. **Tests**: data del DAO + serializer + widget tests del flow.

Cero deps externas (drift, intl, package:fincore — todos existentes).
JSON encoding con `dart:convert` (built-in).

## Requisitos funcionales cubiertos

- **RF-001**: tabla `SavedViews` + `schemaVersion = 3` en F1.
- **RF-002**: migración 2 → 3 en `onUpgrade` (F1).
- **RF-003**: `SavedViewsDao` con CRUD + `watchAll` en F2.
- **RF-004**: errores tipados `SavedViewsDaoError` en F2.
- **RF-005**: `toSavedJson`/`fromSavedJson` en F3.
- **RF-006**: modelo `SavedView` en F2.
- **RF-007**: UI híbrida (panel + AppBar) en F4 + F5.
- **RF-008**: dialog "Guardar vista" en F4.
- **RF-009**: dialog "Renombrar vista" en F5.
- **RF-010**: confirmación destructiva al eliminar en F5.
- **RF-011**: mapeo de errores en `error_snackbar.dart` en F4.
- **RF-012**: empty state en el dropdown en F5.

## Archivos o módulos probablemente afectados

Nuevos:

- `mobile/lib/data/daos/saved_views_dao.dart` (~150 líneas).
- `mobile/lib/widgets/saved_view_picker_sheet.dart` (~200 líneas:
  sheet modal con lista + acciones).
- `mobile/lib/widgets/save_view_dialog.dart` (~80 líneas: dialog de
  nombre con validación).
- `mobile/test/data/saved_views_dao_test.dart` (~250 líneas: ~10
  tests data).
- `mobile/test/data/entries_filters_saved_test.dart` (~150 líneas:
  ~6 tests del serializer).
- `mobile/test/data/database_migration_test.dart` (~80 líneas: 1
  test de migración 2 → 3).
- `mobile/test/screens/saved_views_flow_test.dart` (~200 líneas: 3
  widget tests del flow).

Modificados:

- `mobile/lib/data/database.dart` (+~20 líneas: tabla nueva +
  migración + `daos: [...SavedViewsDao]`).
- `mobile/lib/data/entries_filters.dart` (+~80 líneas: `toSavedJson`,
  `fromSavedJson`, helper para preset rolling).
- `mobile/lib/app_dependencies.dart` (probable +1 línea: exponer
  `SavedViewsDao`).
- `mobile/lib/screens/entries_filters_screen.dart` (+~30 líneas:
  botón "Guardar vista" + handler).
- `mobile/lib/screens/entries_list_screen.dart` (+~40 líneas: icono
  bookmark en AppBar + handler que abre el sheet).
- `mobile/lib/widgets/error_snackbar.dart` (+3 cases para
  `invalid_name`, `duplicate_name`, `not_found`).
- `mobile/pubspec.yaml` (bump `0.10.0+62` + nota).
- `mobile/android/app/build.gradle.kts` (versionCode 62 / versionName
  0.10.0).

No tocados intencionalmente:

- DAOs existentes, modelos existentes (sin cambios).
- Resto de los screens (sin impacto).
- `BackupService` y `wipeAll` — la tabla nueva es preservada por
  `wipeAll` (que solo borra accounts/categories/journal_entries) o
  borrar también las vistas (decisión menor en F1).

## Entidades y estados afectados

- **`SavedView`** (nueva entidad inmutable):
  - `id`: UUID v7.
  - `name`: text (1-50 chars trimmed, único case-insensitive).
  - `filtersJson`: text (JSON serializado).
  - `createdAt`: DateTime.
- Sin transiciones de estado complejas. Sólo CRUD.
- Invariante: `name` único case-insensitive entre filas existentes.
- Efecto secundario al `wipeAll()`: las vistas también se borran
  (RN-V10).

## Compatibilidad con datos y procesos existentes

- **Schema bump 2 → 3**: primer bump del MVP local. Migración aditiva
  (CREATE TABLE) sin tocar tablas existentes. Test específico de
  migración valida que datos viejos no se pierden.
- **Backup JSON v1**: NO incluye `saved_views`. Si Diego hace
  export/import, las vistas locales se mantienen. RN-V10. Si en el
  futuro se quiere incluir, sería backup v2.
- **`wipeAll()`**: debe extenderse para borrar también
  `saved_views` (coherente con "arrancar limpio"). Verificar en T009.
- **`AppDependencies`**: exponer el nuevo DAO.

## Cambios de datos

Tabla nueva `SavedViews`:

```dart
class SavedViews extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get filtersJson => text()();
  DateTimeColumn get createdAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}
```

Sin índices adicionales (esperamos <100 filas — single-user).
Migración aditiva en `onUpgrade`:

```dart
if (from == 2 && to == 3) {
  await m.createTable(savedViews);
  return;
}
```

## Cambios de API

No aplica.

## Cambios de integraciones

- `wipeAll()` en `BackupService` debe truncar también `saved_views`.

## Cambios de UI

### `EntriesFiltersScreen`

- Nuevo botón "Guardar vista" debajo de la última sección, antes del
  bottom bar.
- Tap abre `SaveViewDialog` con `TextFormField` para nombre.
- Submit del dialog → llama `savedViewsDao.create(name, _editing)` →
  snackbar éxito/error.

### `EntriesListScreen`

- Nuevo `IconButton` con `Icons.bookmark_outline` en `AppBar.actions`,
  a la izquierda del icono de filtros existente.
- Tap abre `SavedViewPickerSheet` (modal bottom sheet con
  `showModalBottomSheet`).
- Sheet muestra lista de vistas con `StreamBuilder` sobre
  `watchAll()`.
- Cada item: nombre + fecha de creación + icono ⋮ con acciones
  Renombrar / Eliminar.
- Tap en una vista (no en ⋮) → aplica filtros + cierra sheet.
- Empty state inline si lista vacía.

## Cambios de permisos

No aplica (single-user local).

## Riesgos técnicos

- **R-T01** (medio): primer schema bump. Test de migración crítico
  para no corromper datos.
- **R-T02** (bajo): `EntriesFilters.serialize()` ya existe para
  query params; agregar `toSavedJson()` con formato diferente puede
  confundir. Mitigación: doc-comments claros + nombres distintos.
- **R-T03** (bajo): `name` único case-insensitive requiere
  `LOWER(name)` en la query de validación. Drift soporta
  `customSelect` para esto.
- **R-T04** (bajo): `BackupService.wipeAll()` debe extenderse para
  `saved_views`. Si se olvida, `wipeAll()` deja vistas huérfanas
  apuntando a cuentas/categorías borradas (pero el panel ya tolera
  IDs huérfanos — degrada graciosamente).
- **R-T05** (bajo): `fromSavedJson` debe ser tolerante a JSON
  corrupto/parcial. Mitigación: try/catch + fallback a defaults.

## Estrategia de pruebas

4 niveles:

1. **Tests de migración** (1 test): crear BD en v2, ejecutar
   migration a v3, verificar que tabla nueva existe y datos viejos
   intactos.
2. **Tests data del DAO** (10 tests): CRUD + errores tipados +
   reactividad + orden.
3. **Tests del serializer** (6 tests): round-trip, preset rolling vs
   custom fijo, tolerancia a JSON corrupto.
4. **Widget tests** (3 tests): Guardar vista, Aplicar vista, Empty
   state.

Ver `test-plan.md`.

## Estrategia de rollback

- **Si la migración falla en producción**: schema downgrade no
  soportado por drift. Mitigación: test de migración antes de release
  + APK con la migración validada en cel real (smoke).
- **Si el feature tiene bugs UX**: hot-fix puede ocultar el icono del
  AppBar + el botón del panel con un feature flag. La tabla queda en
  BD sin uso.
- **Si Diego no quiere el feature después**: revert del commit. La
  tabla queda en BD pero sin uso (drop solo si se hace otro schema
  bump destructivo, lo cual queremos evitar).

## Orden sugerido de implementación

Fases en serie:

- **F0** (T001): baseline 279 verdes.
- **F1** (T002-T005): schema bump — tabla + migración + test de
  migración + extensión de `wipeAll`.
- **F2** (T006-T010): DAO + modelo + errores tipados + tests data.
- **F3** (T011-T014): serializer `toSavedJson`/`fromSavedJson` +
  tests.
- **F4** (T015-T019): UI panel — botón "Guardar vista" + dialog +
  handler + mapeo de errores.
- **F5** (T020-T024): UI AppBar — icono bookmark + sheet + acciones
  (renombrar/eliminar) + dialogs.
- **F6** (T025-T028): widget tests del flow completo.
- **F7** (T029-T033): release — analyze + test + bump + APK + verify
  + docs.

## Casos borde que condicionan la solución

Además de los listados en spec.md (CB-1 a CB-11):

- **CB-T01**: `name` con caracteres especiales (emoji, acentos). El
  schema TEXT acepta UTF-8. Sin validación extra.
- **CB-T02**: 100 vistas guardadas (volumen alto). Sin tope, pero
  el sheet con `ListView` lazy renderea. Performance OK.
- **CB-T03**: aplicar vista cuando el panel está abierto (estado
  intermedio). Decisión: aplicar vista cierra el sheet y abre filtros
  con los nuevos valores (replace, no merge).
- **CB-T04**: aplicar vista y luego scroll de filtros: la vista NO se
  actualiza automáticamente (RN-V08 — no hay vista "activa").

## Preguntas o supuestos que siguen afectando la implementación

Sin preguntas abiertas. P-001 (híbrido preset/custom) y P-002 (UI
híbrida) respondidas e integradas a spec.md.

Supuestos del plan vale dejar trazados:

- `wipeAll()` se extiende para borrar `saved_views`. Decisión
  documentada en F1.
- Sheet modal con `showModalBottomSheet` en vez de dropdown — más
  amplio para listas largas y permite acciones ⋮ por item.
- `bookmark_outline` como icono del AppBar — semántico claro.
- Sin worktrees ni paralelización con subagentes (single-user
  brownfield local).

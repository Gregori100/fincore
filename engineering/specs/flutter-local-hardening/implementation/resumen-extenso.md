# Resumen extenso — flutter-local-hardening

## Contexto

### Origen del sprint

El sprint anterior `flutter-local-mvp` cerró con commit `44c3614` y APK `0.2.0+29` instalado en el Redmi de Diego. El `branch-quality-review` ejecutado al cierre identificó 5 bloqueantes (resueltos in-sprint en la misma sesión) + **25 hallazgos no bloqueantes M1..M25**. Estos últimos quedaron documentados como deuda técnica en `engineering/specs/flutter-local-mvp/implementation/pendientes.md` y en el reporte de quality review.

Este sprint `flutter-local-hardening` ataca 20 de esos 25 hallazgos en un esfuerzo focalizado y técnico, sin features visibles para el usuario. Los 5 restantes (M6, M11, M17, M19, M24, M25) quedan explícitamente fuera de alcance por razones documentadas (M17 es feature visible, M6 requiere clave de release real, M11/M25 sin demanda real, M19/M24 cosméticos).

### Decisiones cerradas en la spec

- **Versionado**: `0.3.0+30` aceptado como release menor aditivo (no breaking).
- **Errores tipados del import**: snake_case existente, mapeados en `domainErrorToMessage` y nuevo `backupErrorToMessage`.
- **Cache de streams**: invalidación en `wipeAll` y `archive(id)`; no en `updateEntry`/`cancel`/`register*` porque drift `readsFrom` ya re-emite.
- **`package_info_plus` fallback en tests**: `'dev'` o cadena vacía si no resuelve.
- **Migración 1→2**: incluye SOLO el índice parcial nuevo (RF-011); otros cambios de schema quedan para sprints futuros.

## Relación con el plan

El plan ejecutado cubre las tareas T001 → T025 en orden de dependencia. T023 (smoke manual) es responsabilidad de Diego y T025 (`branch-quality-review`) se invoca al cierre.

### Dependencias respetadas

- T002 (guardrail `onUpgrade`) ANTES de T010 (bump `schemaVersion` + índice + migración real).
- T005-T008 (validaciones import) ANTES de T009 (mapeo de errores).
- T012 (`findActiveById`) ANTES de T013 (uso en `updateEntry`).
- T001 (agregar `package_info_plus`) ANTES de T015 (FutureBuilder).

### Desviaciones documentadas

Detalladas en `desviaciones-plan.md`. Resumen:

1. **Test `Import con FK rota`** usaba string no-UUID `"ID-INEXISTENTE"`. Ahora rechazado por `invalid_uuid_format` antes del check de FK. Cambié el test a usar UUID válido pero inexistente.
2. **`Migrator.customStatement` no existe en drift 2.20**. Usar `customStatement` del enclosing `FincoreDatabase`.
3. **`attachedDatabase.categoriesDao` no se genera** porque `@DriftDatabase(tables: ...)` no declara `daos: [...]`. Query inline en `updateEntry` equivalente a `findActiveById`.

## Cambios principales por módulo o capa

### Capa de datos

**`lib/data/backup.dart`** — corazón del sprint en términos de superficie de seguridad:

- Constantes top-level `_validKinds`, `_validAccountTypes`, `_validAppliesToTypes`, `_kMaxNameLength` (200), `_kMaxDescriptionLength` (1000), `_uuidRegex` (UUID v4/v7).
- Helpers `_validateUuid(field, value)`, `_validateLength(field, value, max)`, `_validateDescription(field, value)`.
- Validaciones inline en `_accountFromJson` (UUID id, name length, type enum, description length), `_categoryFromJson` (UUID id, name length, applies_to enum), `_entryFromJson` (UUID id+origin+dest+category, kind enum, amount > 0, description length).
- Constructor extendido: `BackupService(this._db, [this._state])` con `FinancialStateService?` opcional.
- `wipeAll()` invoca `_state?.invalidateAll()` después de la transacción.
- `importFromJson()` invoca `_state?.invalidateAll()` después del batch insert.

**`lib/data/database.dart`** — schema y migración:

- `schemaVersion` bumpeado de 1 a 2.
- `onCreate` agrega `CREATE INDEX idx_entries_occurred_active ON journal_entries(occurred_at DESC) WHERE deleted_at IS NULL`.
- `onUpgrade` con rama `if (from == 1 && to == 2)` que ejecuta el mismo CREATE INDEX para instalaciones existentes. Guardrail `throw UnimplementedError(...)` queda después de la rama para detectar bumps accidentales.

**`lib/data/financial_state.dart`** — performance:

- Nuevo campo privado `Map<String, Stream<double>> _balanceCache = {}`.
- `watchAccountBalance(accountId, accountType)` consulta cache por key `'$accountId:$accountType'` antes de crear stream nuevo.
- Métodos públicos `invalidateAccount(String accountId)` (filtra por prefijo `'$accountId:'`) e `invalidateAll()` (limpia el Map).

**`lib/data/daos/categories_dao.dart`** — helper canónico:

- `Future<Category?> findActiveById(String id)` filtra `c.id.equals(id) & c.deletedAt.isNull()`.

**`lib/data/daos/entries_dao.dart`** — RN-H03:

- `updateEntry` separa caso "categoría heredada" vs "explícita". Si heredada y archivada, fuerza `categoryId = null` sin lanzar error (silent clear). Si explícita y archivada/incompatible, mantiene el error `invalid_category_applies_to`.
- Query inline equivalente a `findActiveById` porque `attachedDatabase.categoriesDao` no se genera.

**`lib/data/daos/accounts_dao.dart`** — integración con cache:

- `archive(id)` invoca `stateService?.invalidateAccount(id)` después de la transacción de soft-delete + cancel cascade.

### Capa de presentación

**`lib/screens/settings_screen.dart`** — el archivo con más cambios:

- `_export` envuelve `_exportInternal()` que retorna `bool` indicando si el share fue exitoso.
- `_exportThenReset()` orquesta: share → confirmación enfática → wipe.
- `_resetWithoutExport()` flujo directo con confirmación enfática.
- `_wipeAndRedirect()` extraído como helper común.
- UI: dos botones en card "Zona peligrosa". `FilledButton.icon` primario azul "Exportar respaldo y luego reiniciar" + `OutlinedButton.icon` secundario rojo "Reiniciar sin exportar".
- Card "Acerca de" usa `FutureBuilder<PackageInfo>` con skeleton mientras carga, "dev" en error, "version+build" en data.
- `kAppVersion` constante eliminada del archivo.

**`lib/widgets/error_snackbar.dart`** — UX accesible:

- Nuevo `backupErrorToMessage(BackupError error)` con switch case para los 10 códigos.
- Branch `BackupError() => backupErrorToMessage(error)` agregado ANTES del branch `Exception()` en `showErrorSnackbar`.
- `_buildFincoreSnackBar` calcula `foreground = background == FincoreColors.warning ? FincoreColors.canvas : Colors.white`.

**Otros screens** — tooltips y Semantics:

- `entries_list_screen.dart`: filter `IconButton` con `tooltip` dinámico; FAB con `tooltip: 'Nuevo movimiento'`.
- `dashboard_screen.dart`: FAB extended con `tooltip`.
- `entry_form_screen.dart`: "Cambiar tipo" envuelto en `Tooltip`.
- `first_run_screen.dart` y `settings_screen.dart`: chevrons decorativos con `Semantics(excludeSemantics: true)`.

### Infraestructura Android

- **`AndroidManifest.xml`**: en `<application>` agregados `android:allowBackup="false"`, `android:fullBackupContent="false"`, `android:dataExtractionRules="@xml/data_extraction_rules"`.
- **`res/xml/data_extraction_rules.xml`**: archivo nuevo con `<data-extraction-rules>` que excluye 5 dominios (`root`, `file`, `database`, `sharedpref`, `external`) tanto en `<cloud-backup>` como en `<device-transfer>`.
- **`build.gradle.kts`**: `versionCode = 30`, `versionName = "0.3.0"`.

### Tooling y docs

- **`pubspec.yaml`**: `package_info_plus: ^8.0.0` agregado; `version: 0.3.0+30`.
- **`CLAUDE.md` raíz**: 4 secciones nuevas:
  - "Migraciones de schema (RN-H02)" bajo Capa de datos: guardrail + regla aditiva + prohibición de DROP destructivo.
  - "Joins con categorías archivadas": helper `findActiveById` y comportamiento de RN-H03.
  - "Política de `ndkVersion` (RF-017)" bajo Convenciones del repo: hardcoded a 27.0.12077973 mientras plugins lo exijan.
  - "Política de dependencias `^` flotantes (RF-018)": no `flutter pub upgrade` sin revisar changelogs de drift/go_router/sqlite3_flutter_libs.
  - Bump de versión actualizado: de 3 lugares a 2.
- **`app_dependencies.dart`**: `BackupService(database, stateService)` para que el cache se invalide en `wipeAll` y `importFromJson`.

### Tests

- **`test/data/database_test.dart`**: +7 tests (cancel idempotente preserva balance + 6 transiciones updateEntry).
- **`test/data/backup_test.dart`**: +10 tests (validaciones import + UUID v4 borde + name vacío borde) + 1 fixture cambiado (UUID válido en FK rota).
- **`test/data/financial_state_test.dart`**: +5 tests (cache de streams + invalidación por archive).

Helper `buildPayload(...)` en `backup_test.dart` evita duplicar el JSON en 10 tests.

## Desviaciones respecto al plan

Detalladas en `desviaciones-plan.md`. Todas menores y documentadas:

- Fixture del test `Import con FK rota` cambió a UUID válido inexistente.
- `Migrator.customStatement` → `customStatement` directo del enclosing.
- `attachedDatabase.categoriesDao` no existe → query inline en `updateEntry`.
- `isNull` matcher ambiguo con drift → `equals(null)`.
- `_buildPayload` underscore → `buildPayload` por lint.

## Pruebas realizadas y recomendadas

### Realizadas

- `flutter analyze`: 0 errores, 4 hints info no bloqueantes (cosméticos pre-existentes).
- `flutter test`: **81 tests verdes**. Distribución: database 38 + financial_state 17 + backup 18 + invariants 8.
- `flutter build apk --release --split-per-abi`: 3 APKs generados.
- `aapt dump badging` y `aapt dump xmltree`: confirman versionCode, versionName, allowBackup=false, dataExtractionRules.

### Recomendadas (en T023, pendiente Diego)

1. App abre sin crash sobre BD migrada de v1 → v2.
2. Datos previos intactos.
3. "Acerca de" muestra `0.3.0+30`.
4. `adb backup` rechazado.
5. Import malicioso con `kind:'hacked'` → snackbar rojo amigable.
6. Editar entry con categoría archivada → silent clear.
7. Flujo "Exportar y luego reiniciar" end-to-end.
8. (Opcional) TalkBack narra iconos críticos.

## Riesgos residuales y posibles regresiones

### Riesgos

- Downgrade de versión no soportado tras migración.
- `schemaVersion = 2`: futuras migraciones deben agregar nueva rama en `onUpgrade`.
- Cache de streams depende de invocaciones correctas a `invalidate*`.
- `PackageInfo.fromPlatform()` puede fallar en cels muy viejos (cubierto por fallback `'dev'`).
- TalkBack no testeado automáticamente.

### Posibles regresiones

- `updateEntry` con categoría heredada archivada: cambia de error a write exitoso silencioso. Cambio intencional pero callers viejos que esperaban el error romperían silencio.
- `BackupService` constructor: nuevo parámetro opcional. Callers que crean `BackupService(database)` no rompen pero no invalidan cache.
- Snackbar warning con texto canvas: cambio visual; validable en smoke.

Riesgo de regresión cubierto por las 81 pruebas automáticas + smoke manual de Diego.

# Implementation Review: flutter-local-hardening

## Resumen de lo implementado

Sprint técnico de cleanup y hardening sobre la app FinCore Flutter Android local-first del MVP anterior. 22 RFs en 8 familias, 25 tareas T001..T025. Sin features visibles para el usuario; foco en cerrar 20 de los 25 hallazgos no bloqueantes del `branch-quality-review` del sprint anterior. **20 RFs implementados completos**; T023 (smoke manual de Diego) queda pendiente de él y T025 (branch-quality-review) se invoca al final como auditoría.

Cambios clave:

- **Import endurecido**: 6 nuevos códigos de error tipados (`invalid_kind`, `invalid_account_type`, `invalid_applies_to`, `invalid_amount`, `string_too_long`, `invalid_uuid_format`) con validaciones de enums, montos, longitudes y formato UUID v4/v7. Mapeo amigable vía nuevo `backupErrorToMessage`.
- **Privacidad Android**: `allowBackup="false"` + `fullBackupContent="false"` + `dataExtractionRules.xml` denegando todos los dominios.
- **Schema migración 1→2**: índice parcial nuevo `idx_entries_occurred_active` + guardrail `UnimplementedError` en `onUpgrade` para versiones no implementadas.
- **Cache de streams**: `Map<String, Stream<double>>` en `FinancialStateService` con invalidación en `archive` y `wipeAll`.
- **UX**: reset destructivo con dos botones (Exportar+Reiniciar / Reiniciar sin exportar); contraste WCAG AA en snackbar warning; tooltips en iconos críticos; chevrons decorativos con `Semantics(excludeSemantics: true)`.
- **Mantenibilidad**: `kAppVersion` eliminado, leído de `PackageInfo.fromPlatform()` con fallback `'dev'`; convenciones documentadas en CLAUDE.md (migraciones, joins con archivadas, ndkVersion, deps `^`).
- **Tests**: 22 nuevos verdes (de 59 → 81): cancel idempotente preserva balance, 6 transiciones de updateEntry, 10 validaciones import, 5 cache de streams.

Versión final: `0.3.0+30` (versionCode 30). APK arm64: 19.5 MB.

## Archivos principales modificados

### Capa de datos (`mobile/lib/data/`)

- `backup.dart`: constantes de validación (`_validKinds`, `_validAccountTypes`, `_validAppliesToTypes`, `_kMaxNameLength`, `_kMaxDescriptionLength`, `_uuidRegex`); helpers `_validateUuid`, `_validateLength`, `_validateDescription`; validaciones en los tres `_*FromJson`; constructor que acepta `FinancialStateService?` opcional para invalidar cache en `wipeAll` e `importFromJson`.
- `database.dart`: `schemaVersion = 2`; índice parcial `idx_entries_occurred_active` en `onCreate`; rama `if (from == 1 && to == 2)` en `onUpgrade`; guardrail `UnimplementedError` post-rama.
- `financial_state.dart`: `Map<String, Stream<double>> _balanceCache`; `watchAccountBalance` consulta cache; `invalidateAccount(String accountId)` y `invalidateAll()` públicos.
- `daos/categories_dao.dart`: helper `findActiveById(id)` que filtra archivadas.
- `daos/entries_dao.dart`: `updateEntry` aplica RN-H03 (categoría heredada archivada → silent clear via query inline; categoría explícita archivada → mantiene error).
- `daos/accounts_dao.dart`: `archive(id)` invoca `stateService?.invalidateAccount(id)` después de la transacción.

### Presentación (`mobile/lib/screens/` + `widgets/`)

- `screens/settings_screen.dart`: `_export` + `_exportInternal` + `_exportThenReset` + `_resetWithoutExport` + `_wipeAndRedirect` (refactor del flujo); UI con dos botones en "Zona peligrosa"; `FutureBuilder<PackageInfo>` en "Acerca de"; chevrons con `Semantics(excludeSemantics: true)`.
- `screens/first_run_screen.dart`: chevrons con `Semantics(excludeSemantics: true)`.
- `screens/entries_list_screen.dart`: `tooltip` en filter `IconButton` + FAB.
- `screens/dashboard_screen.dart`: `tooltip` en FAB extended.
- `screens/entry_form_screen.dart`: `Tooltip` envolviendo "Cambiar tipo".
- `widgets/error_snackbar.dart`: `backupErrorToMessage` nuevo; branch `BackupError() => backupErrorToMessage(error)` en `showErrorSnackbar`; color foreground del snackbar warning calculado a `canvas` para WCAG.

### Infraestructura Android

- `android/app/src/main/AndroidManifest.xml`: atributos `allowBackup="false"`, `fullBackupContent="false"`, `dataExtractionRules="@xml/data_extraction_rules"` en `<application>`.
- `android/app/src/main/res/xml/data_extraction_rules.xml`: archivo nuevo con `<cloud-backup>` y `<device-transfer>` excluyendo 5 dominios.
- `android/app/build.gradle.kts`: `versionCode = 30`, `versionName = "0.3.0"`.

### Tooling y docs

- `pubspec.yaml`: agregado `package_info_plus: ^8.0.0`; versión bumpeada a `0.3.0+30`.
- `CLAUDE.md` raíz: 4 secciones nuevas (Migraciones de schema, Joins con categorías archivadas, Política de ndkVersion, Política de dependencias `^` flotantes); bump de versión pasa de 3 a 2 lugares.
- `app_dependencies.dart`: `BackupService(database, stateService)` inyecta el StateService.

### Tests

- `test/data/database_test.dart`: 7 tests nuevos (1 cancel idempotente + 6 transiciones updateEntry).
- `test/data/backup_test.dart`: 10 tests nuevos (validaciones import) + 1 fixture cambiado (FK rota usa UUID válido).
- `test/data/financial_state_test.dart`: 5 tests nuevos (cache de streams).

## Tareas completadas

T001 (package_info_plus), T002 (guardrail onUpgrade), T003 (CLAUDE.md), T004 (AndroidManifest + dataExtractionRules), T005-T008 (validaciones import), T009 (backupErrorToMessage + ruteo), T010 (schemaVersion + índice + onUpgrade), T011 (cache de streams + invalidaciones), T012 (findActiveById), T013 (updateEntry con RN-H03), T014 (reset con dos botones), T015 (PackageInfo en Acerca de), T016 (snackbar warning canvas), T017 (tooltips + Semantics), T018 (cancel idempotente preserva balance), T019 (transiciones updateEntry), T020 (validaciones import + cache + UUID v4/v7 borde), T021 (bump 0.3.0+30), T022 (build APK + verificación aapt), T024 (artefactos implementation/).

## Tareas pendientes

- **T023** — smoke manual de Diego sobre el Redmi (instala APK arm64 sobre `0.2.0+29`, valida los 7 puntos). Bloqueante para cerrar el sprint en `main`.
- **T025** — `branch-quality-review` se invoca al cierre de este review.

## Riesgos residuales

- **Downgrade `0.3.0+30` → `0.2.0+29` no soportado**: la BD migrada a `schemaVersion = 2` no se puede abrir con código que espera 1; documentado en `pendientes.md`.
- **`schemaVersion` ya está en 2**: futuras migraciones deben agregar nueva rama `if (from == 2 && to == 3)` ANTES del guardrail throw. Convención documentada en CLAUDE.md.
- **Cache de streams** depende de invocaciones correctas a `invalidateAccount/All`. Cubierto por tests automáticos (5 nuevos), pero si en futuro se agregan operaciones que reemplazan la BD (ej. drop+restore selectivo), recordar invalidar.
- **Migración 1→2 con datos reales**: el `CREATE INDEX` sobre índice parcial es liviano, pero con histórico muy grande puede tardar. Cubierto en smoke manual.
- **`PackageInfo` en cels viejos**: fallback `'dev'` cubre el caso. Si Diego nota que la card "Acerca de" muestra "dev", el `package_info_plus` falló silenciosamente.
- **TalkBack no testeado automáticamente**: smoke manual de Diego (paso opcional 8 en T023) cubre la validación.

## Pruebas realizadas

- **`flutter analyze`**: 4 hints info (`prefer_const_constructors` en `skeleton.dart:75` y `entry_form_screen.dart:260/262`); 0 errores, 0 warnings.
- **`flutter test`**: **81 tests verdes** (subimos +22 desde los 59 del sprint anterior). 4 suites: database 38 + financial_state 17 + backup 18 + invariants 8.
- **`flutter build apk --release --split-per-abi`**: 3 APKs generados sin errores; arm64 = 19.5 MB.
- **`aapt dump badging`**: versionCode=2030, versionName="0.3.0", sdkVersion=24, targetSdkVersion=35, application-label="FinCore".
- **`aapt dump xmltree AndroidManifest.xml`**: `allowBackup=0x0`, `fullBackupContent=0x0`, `dataExtractionRules` apunta a resource.

## Pruebas recomendadas

Smoke manual de Diego (T023). Si después aparecen huecos:

- Widget tests para el flujo nuevo de Settings (Exportar+Reset).
- Test de carga con 50k entries para validar empíricamente que el índice parcial mantiene `watchPage` < 10 ms.
- Test de `adb backup` automatizado en CI cuando exista pipeline.

## Posibles regresiones

- **`updateEntry` con categoría heredada archivada**: el caller que esperaba `invalid_category_applies_to` ahora recibe write exitoso con `categoryId = null`. Cambio intencional (RN-H03). Si algún caller dependía del error, romperá silenciosamente. Hoy el único caller es el form de edición y no depende.
- **`BackupService` constructor**: ahora acepta `FinancialStateService?` opcional. Los tests existentes pasan `database` solo (compatible). Si en el futuro se agregan callers que crean `BackupService` sin pasar el state service, el cache no se invalidará automáticamente.
- **`schemaVersion = 2`**: instalaciones de `0.3.0+30` que se reinstalen con `0.2.0+29` van a tener BD versión 2 contra código versión 1.
- **Snackbar warning con texto canvas**: el cambio visual puede sorprender a Diego en smoke; mitigable con un override si rechaza.

## Recomendaciones para code review humano

1. **Verificar la migración 1→2 en un dispositivo real con datos**: Diego confirma en T023 que abrir el APK nuevo sobre BD vieja preserva todo. Idealmente medir tiempo de migración con su volumen real para ver si el splash es suficiente.
2. **Confirmar que el flujo "Exportar y luego reiniciar" maneja todos los estatus del share sheet**: `success`, `dismissed`, `unavailable`. El plan asume que solo `success` procede al reset; verificar visualmente.
3. **Auditar el orden de invalidación del cache**: en `BackupService.wipeAll` se invalida DESPUÉS de la transacción para que un suscriptor que llegue durante el wipe no quede con stream stale. Confirmar que sea el orden correcto.
4. **Revisar el snackbar warning con sol directo o usuarios con baja visión**: el contraste calculado pasa de 3.8:1 a ~10:1; smoke visual.
5. **Validar que `PackageInfo.fromPlatform()` no introduce delays perceptibles** al entrar a Settings; idealmente el future resuelve en <50ms.
6. **El reporte de `branch-quality-review` (T025)** se genera en `engineering/quality-review/flutter-local-hardening/YYYY-MM-DD-HHMM-branch-quality-review.md`. Cualquier bloqueante nuevo se resuelve in-sprint como hicimos en `flutter-local-mvp`.

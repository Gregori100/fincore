# Progreso — flutter-local-hardening-v2

Estado real de las tareas T001..T017 al cierre del sprint. Detalle de pruebas y desviaciones en `pruebas.md` / `desviaciones-plan.md` respectivamente.

## Fase 0 — Codegen

- [x] **T001** (RF-007) Registro de DAOs en `@DriftDatabase` + regeneración de `database.g.dart`.
  - Registrados `[AccountsDao, CategoriesDao]`. `EntriesDao` queda fuera por incompatibilidad de constructor (ver `desviaciones-plan.md`). El refactor de T002 sigue cubierto.
  - `dart run build_runner build --delete-conflicting-outputs` corrido sin warnings.

## Fase 1 — Refactors core + tests defensivos

- [x] **T002** (RF-008) `EntriesDao.updateEntry`: query inline reemplazada por `attachedDatabase.categoriesDao.findActiveById(effectiveCategoryId)`. Comportamiento idéntico (RN-H03 sin cambios).
- [x] **T003** (RF-001 + RF-002 condicional) `FinancialStateService.watchAccountBalance`: stream cacheado envuelto con `.asBroadcastStream()`. RF-002 NO necesitó implementación (T007 pasa sin `onCancel`).
- [x] **T004** (RF-003) Test `Import con name de 200 chars exactos pasa validación de longitud` agregado a `backup_test.dart`.
- [x] **T005** (RF-004) Test `wipeAll invalida cache de streams` agregado a `financial_state_test.dart`.
- [x] **T006** (RF-005) Test `watchPage no incluye badge para categorías archivadas` agregado a `database_test.dart`.
- [x] **T007** (RF-006) Test `watchAccountBalance cacheado acepta múltiples suscriptores` agregado, incluye sub-caso cancel + resuscribir.

Resultado: 87 → **91 tests verdes**.

## Fase 2 — Refactors menores

- [x] **T008** (RF-009) `_buildFincoreSnackBar`: ahora recibe `foreground` como parámetro inyectado. Los 3 helpers públicos (`showError/Success/WarningSnackbar`) pasan el color explícito según intención.
- [x] **T009** (RF-010) `Share.shareXFiles` envuelto con `.timeout(Duration(minutes: 2), onTimeout: ...)`. Resultado del timeout se trata como `ShareResultStatus.unavailable` → flujo equivalente a "cancelado".
- [x] **T010** (RF-011) `_validateUuid` y `_parseDate` en `backup.dart`: `substring` reemplazado por `value.characters.take(N).toString()` para evitar romper surrogates UTF-16 con emojis o multi-byte. Import de `package:characters/characters.dart` agregado.

## Fase 3 — Docs

- [x] **T011** (RF-012) Sección "Importar respaldos: límites y validaciones" agregada a `mobile/README.md`. Tabla con 16 códigos de error tipados + lista de límites duros + nota de truncado grapheme-safe.
- [x] **T012** (RF-013) `engineering/specs/flutter-local-hardening/implementation/desviaciones-plan.md` extendido con dos desviaciones menores no documentadas previamente (Fase 1: `isNull` → `equals(null)`, Fase 1: `_buildPayload` → `buildPayload`).

## Fase 4 — Release

- [x] **T013** Bump a `version: 0.3.1+33` en `pubspec.yaml` + `versionCode = 33` / `versionName = "0.3.1"` en `android/app/build.gradle.kts`.
- [x] **T014** `flutter build apk --release --split-per-abi` → 3 APKs generados sin warnings funcionales. Verificación `aapt2 dump badging app-arm64-v8a-release.apk`:
  - `versionCode='2033'` (2000 prefijo arm64 + 33).
  - `versionName='0.3.1'`.
  - `minSdkVersion='24'`, `targetSdkVersion='35'`.

## Fase 5 — Smoke manual

- [ ] **T015** Smoke manual a cargo de Diego. Instalar `app-arm64-v8a-release.apk` sobre `0.3.0+32` y validar puntos clave (Dashboard con datos preservados, export → share, import de respaldo viejo, snackbar warning con texto legible, reset con `_exportThenReset` y `_resetWithoutExport`). Documentar resultado en `pendientes.md` post-smoke.

## Fase 6 — Cierre

- [x] **T016** Carpeta `implementation/` con 6 archivos obligatorios (`progreso.md`, `desviaciones-plan.md`, `pendientes.md`, `implementation-review.md`, `resumen-ejecutivo.md`, `resumen-extenso.md`).
- [x] **T017** `branch-quality-review` ejecutado con slug `flutter-local-hardening-v2`. Reporte: `engineering/quality-review/flutter-local-hardening-v2/2026-06-19-1234-branch-quality-review.md`. Resultado: **0 bloqueantes**, 3 hallazgos `Media` (M1/M2/M3) accionados en sesión + 5 `Baja` diferidos.

## Post-review (2026-06-19) — Fixes adicionales sobre 3 hallazgos `Media`

El `branch-quality-review` no detectó bloqueantes pero sí 3 mejoras `Media` que se resolvieron en la misma sesión, alineado con el patrón del sprint anterior:

- **M1**: `mobile/pubspec.yaml` declara `characters: ^1.4.0` como dependencia directa. `flutter pub get` reportó "Changed 1 dependency!" (promoción de transitive a direct).
- **M2**: `mobile/lib/app_dependencies.dart` usa `database.accountsDao` y `database.categoriesDao` (instancias del codegen) en vez de `AccountsDao(database)` / `CategoriesDao(database)` manuales. `EntriesDao` sigue manual por su constructor.
- **M3**: `mobile/test/data/backup_test.dart` test "Import con name de 200 chars exactos" cambiado de `try/catch` permisivo a assert directo sobre `ImportReport.categoriesCount` + verificación del nombre persistido.

Tests siguen verdes (**91/91**). `flutter analyze` con 5 hints info (uno menos que antes). APK rebuildeado: `versionCode='2033'`, `versionName='0.3.1'`.

# Tareas — flutter-reports-drilldown-parity-v1

## Backend

- [ ] T001 Backend: identificar y leer `mobile/test/data/entries_dao_test.dart` (o archivo equivalente) para conocer el patrón de setUp (in-memory sqlite, categorías sembradas, uso de `customStatement`). Confirmar el nombre y ubicación del archivo.
  RF: —
  Depende de: ninguna
  Paralelizable: no
  Criterio de terminado: nombre exacto del archivo confirmado + patrón de setUp descrito en `implementation/desviaciones-plan.md` si difiere del asumido.

- [ ] T002 Backend: leer callers actuales de `EntriesDao.watchPage` en `mobile/lib/screens/` con `grep -n "watchPage"` para confirmar que ningún caller depende del comportamiento actual del token con `kinds=null`.
  RF: RF-004
  Depende de: T001
  Paralelizable: si
  Criterio de terminado: lista de callers en el archivo `implementation/desviaciones-plan.md` con nota de que ninguno se rompe con RN-P03.

- [ ] T003 Backend: modificar `mobile/lib/data/reports.dart` en `spendingByCategory` — agregar `AND c.applies_to != 'income'` al `ON` del LEFT JOIN. Actualizar el docstring del método explicando el filtro (paridad con `incomeByCategory`).
  RF: RF-001
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: `flutter analyze` limpio + el SQL de `spendingByCategory` incluye la cláusula en el `ON`.

- [ ] T004 Backend: refactor del bloque del token en `EntriesDao.watchPage` (`mobile/lib/data/daos/entries_dao.dart` líneas 118-137). Introducir un helper local `Expression<bool> uncategorizedCondition` que dependa del conjunto efectivo de kinds:
  - Convertir `effectiveKinds` a `Set<String>`.
  - Si el set es exactamente `{'income'}` → `categories.id.isNull() | categories.appliesTo.equals('expense')`.
  - Si el set es subconjunto no vacío de `{'expense', 'credit_expense'}` → `categories.id.isNull() | categories.appliesTo.equals('income')`.
  - Resto → `categories.id.isNull()` (comportamiento actual).
  Reemplazar las 2 ramas actuales del token para usar `uncategorizedCondition`. Actualizar el comentario del bloque explicando la nueva semántica.
  RF: RF-002, RF-003, RF-004, RF-005
  Depende de: T001
  Paralelizable: si
  Criterio de terminado: `flutter analyze` limpio + el bloque actualizado + el docstring de `watchPage` menciona la nueva convención.

## Pruebas

- [ ] T005 Pruebas: correr `flutter test` sin agregar tests nuevos aún, para confirmar que 452 tests siguen verdes tras T003 y T004.
  RF: RT-01
  Depende de: T003, T004
  Paralelizable: no
  Criterio de terminado: 452/452 verdes (o el número existente al momento del sprint).

- [ ] T006 Pruebas: agregar los 9 tests nuevos en `mobile/test/data/reports_test.dart` y `mobile/test/data/entries_dao_test.dart` (según T001):
  - UT-DP01 (paridad income con edge (3)).
  - UT-DP02 (paridad spending con edge (3) inverso).
  - UT-DP03 (`kinds:['expense','credit_expense']` expande).
  - UT-DP04 (regresión: `kinds:null` NO expande).
  - UT-DP05 (regresión: `kinds` mixto NO expande).
  - UT-DP06 (`applies_to='both'` NO cae en el bucket).
  - UT-DP07 (unión con ids reales + token).
  - UT-DP08 (`kinds:['transfer']` NO expande).
  - UT-DP09 (reactividad al cambiar `applies_to` — usa `emitsThrough`, NO `Future.delayed`).
  RF: RF-006, RF-007
  Depende de: T005
  Paralelizable: no
  Criterio de terminado: los 9 tests verdes y el conteo total sube a ≥ 461.

- [ ] T007 Pruebas: correr `flutter test` completo. Confirmar 0 regresiones en tests widget (`entries_filters_screen_test`, `income_by_category_tab_test`, `credit_cards_tab_test`, etc.).
  RF: RT-01..04
  Depende de: T006
  Paralelizable: no
  Criterio de terminado: total ≥ 461 verdes.

## Documentación

- [ ] T008 Documentación: actualizar `CLAUDE.md` en la sección "Reglas clave de los DAOs" con un párrafo explicando la nueva convención de `kUncategorizedFilterToken`. Formato sugerido: nota breve mencionando (a) los 3 casos que agrupa el token en el reporte, (b) que el DAO expande la definición cuando `kinds` es puramente income o puramente expense, (c) que en `kinds=null` o mixto se mantiene el comportamiento clásico.
  RF: RF-008
  Depende de: T004
  Paralelizable: si
  Criterio de terminado: `CLAUDE.md` actualizado con el párrafo + referencia al slug del sprint (`flutter-reports-drilldown-parity-v1`).

## Validación de calidad

- [ ] T009 Validación: bump de versión en `mobile/pubspec.yaml` (`0.15.0+78`) + `mobile/android/app/build.gradle.kts` (`versionCode = 78`, `versionName = "0.15.0"`). Correr `flutter build apk --release --split-per-abi` y `scripts/verify-apk.sh 78`.
  RF: —
  Depende de: T007, T008
  Paralelizable: no
  Criterio de terminado: APK release compilado + verify OK.

- [ ] T010 Validación: smoke manual por Diego (SM-01..04 del test-plan) en cel real.
  RF: —
  Depende de: T009
  Paralelizable: no
  Criterio de terminado: Diego confirma que los 2 escenarios (income y expense) muestran paridad reporte↔drill-down + que Dashboard y `/entries` sin filtros siguen igual.

- [ ] T011 Validación: ejecutar skill `branch-quality-review` con slug `flutter-reports-drilldown-parity-v1`. Consolidar hallazgos (si los hay) en el reporte único bajo `engineering/quality-review/flutter-reports-drilldown-parity-v1/`.
  RF: —
  Depende de: T010
  Paralelizable: no
  Criterio de terminado: reporte generado; hallazgos bloqueantes resueltos.

- [ ] T012 Validación: commit final con mensaje que resuma el sprint. NO pushear (Diego lo hace manualmente).
  RF: —
  Depende de: T011
  Paralelizable: no
  Criterio de terminado: `git status` limpio; working tree sin cambios pendientes.

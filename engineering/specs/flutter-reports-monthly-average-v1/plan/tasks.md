# Tasks — flutter-reports-monthly-average-v1

Tareas en orden de dependencia. IDs estables `T001`, `T002`, ...

## Base de datos

No aplica. Sin migración. Sin schema bump.

## Backend (data layer)

- [ ] **T001 Backend**: agregar modelo `MonthlyAverageReport` en `mobile/lib/data/reports.dart` con campos según RF-009 (`monthsRequested`, `monthsAvailable`, `windowFrom`, `windowTo`, `currentDayOfMonth`, `historicalAverage`, `currentMonthSpent`, `deltaAbsolute`, `deltaPercent`, `categoryBreakdown`, `isEmpty`).
  RF: RF-009
  Depende de: ninguna
  Paralelizable: sí
  Criterio de terminado: clase inmutable con `const` constructor, todos los campos `final`, getter `isEmpty` derivado, compila con `flutter analyze` limpio.

- [ ] **T002 Backend**: agregar modelo `CategoryAverageDelta` en `mobile/lib/data/reports.dart` según RF-010 (`categoryId` nullable, `name`, `colorSlug` nullable, `iconSlug` nullable, `historicalAverage`, `currentMonthSpent`, `deltaAbsolute`, `deltaPercent` nullable).
  RF: RF-010
  Depende de: ninguna
  Paralelizable: sí
  Criterio de terminado: clase inmutable, `const` constructor, compila limpio.

- [ ] **T003 Backend**: implementar `ReportsService.monthlyAverage({required int monthsBack, DateTime? now})` con query SQL single-shot (histórico prorrateado + mes actual) usando `customSelect(...).watch(readsFrom: {journalEntries, categories})`. La query agrega por `(month_key, category_id)` con filtro `kind IN ('expense', 'credit_expense') AND deleted_at IS NULL`.
  RF: RF-008
  Depende de: T001, T002
  Paralelizable: no
  Criterio de terminado: método público que retorna `Stream<MonthlyAverageReport>`. UT-01..UT-16 pasan.

- [ ] **T004 Backend**: helpers privados en `ReportsService`:
  - `_iterateClosedMonths(DateTime now, int monthsBack)` retorna lista de `DateTime(year, month, 1)` de los N meses cerrados.
  - `_lastDayOfMonth(int year, int month)` retorna el último día del mes (28, 29, 30 o 31).
  - `_buildMonthlyAverageReport(rows, ...)` procesa filas SQL y arma el reporte agrupando por mes/categoría, computa promedios prorrateados, deltas, ordena breakdown según RN-A12.
  RF: RF-009, RF-010, RN-A07, RN-A08, RN-A12
  Depende de: T001, T002, T003
  Paralelizable: no
  Criterio de terminado: helpers usados por `monthlyAverage`. Sin código duplicado con `cashflowByMonth`.

## Frontend

- [ ] **T005 Frontend**: crear `mobile/lib/screens/reports/monthly_average_tab.dart` con `StatefulWidget` que:
  - State: `int _monthsBack = 3`, `Stream<MonthlyAverageReport>? _reportStream`.
  - `didChangeDependencies` arma `_reportStream` una sola vez.
  - `_selectMonthsBack(n)` reasigna el stream.
  - `build()` retorna `ListView` con: chips de presets (Wrap + ChoiceChip), `StreamBuilder` con loading/empty/error/data states, body = `_GlobalCard` + subtítulo + `_CategoryBreakdown`.
  RF: RF-001, RF-002, RF-003, RF-004, RF-007, RF-011, RF-012
  Depende de: T003
  Paralelizable: sí (con T006)
  Criterio de terminado: archivo compila, render manual en `flutter run -d linux` muestra UI esperada (sin crash).

- [ ] **T006 Frontend**: widgets privados del tab dentro del mismo archivo `monthly_average_tab.dart`:
  - `_GlobalCard`: 3 columnas `_HeaderMetric` (Promedio, Mes en curso, Delta) + chip de estado.
  - `_StatusChip`: pintura del semáforo según RN-A10 con label ("Por debajo / En línea / Por encima").
  - `_CategoryBreakdown`: `Column` de filas `_CategoryRow` o reuso de `BaseCard`.
  - `_CategoryRow`: badge color+icon, nombre, promedio prorrateado, gasto actual, delta abs+%, semáforo de fila.
  - `_EmptyState`: icono + texto.
  - `_LoadingState`: placeholder simple (Skeleton no obligatorio para v1).
  - `_ErrorState`: similar a `cashflow_tab.dart` con retry.
  RF: RF-003, RF-005, RF-006, RF-007
  Depende de: T005 (mismo archivo)
  Paralelizable: no
  Criterio de terminado: widgets renderean según el reporte. Helpers de formato (`formatAmount`, `colorBySlug`, `iconBySlug`) reusados, no duplicados.

- [ ] **T007 Frontend**: modificar `mobile/lib/screens/reports_screen.dart`:
  - Import del nuevo tab.
  - `length: 4 → 5`.
  - Agregar `Tab(text: 'Promedio')` al final.
  - Agregar `MonthlyAverageTab()` al final del `TabBarView`.
  - Actualizar comentario de la clase (lista de tabs vigentes).
  RF: RF-001
  Depende de: T005
  Paralelizable: no
  Criterio de terminado: `/reports` muestra 5 tabs. Swipe al último muestra `MonthlyAverageTab`.

## Pruebas

- [ ] **T008 Pruebas**: unit tests en `mobile/test/data/reports_test.dart` — nuevo grupo `group('monthlyAverage', () {...})` con UT-01..UT-04 (BD vacía, N=1 básico, prorrateo día 15, mes en curso).
  RF: RF-008, RN-A01, RN-A05, RN-A07
  Depende de: T003
  Paralelizable: sí (con T009..T011)
  Criterio de terminado: 4 tests verdes.

- [ ] **T009 Pruebas**: unit tests UT-05..UT-08 (RN-A08 día 31, categoría archivada → "Sin categoría", soft delete, kinds excluidos).
  RF: RN-A06, RN-A08, RN-A09
  Depende de: T003, T004
  Paralelizable: sí
  Criterio de terminado: 4 tests verdes.

- [ ] **T010 Pruebas**: unit tests UT-09..UT-12 (degradación M<N, cero promedio, categoría sin gasto actual, categoría sin histórico).
  RF: RN-A04, RN-A11, RN-A13, RN-A14
  Depende de: T003, T004
  Paralelizable: sí
  Criterio de terminado: 4 tests verdes.

- [ ] **T011 Pruebas**: unit tests UT-13..UT-15 (orden breakdown, reactividad del stream, D<28).
  RF: RF-006, RN-A12
  Depende de: T003, T004
  Paralelizable: sí
  Criterio de terminado: 3 tests verdes.

- [ ] **T012 Pruebas**: crear `mobile/test/screens/monthly_average_tab_test.dart` con WT-01..WT-04 (carga inicial, cambio de preset, empty state, render breakdown). Reusar `pumpFincoreApp` del harness.
  RF: RF-001, RF-002, RF-006, RF-007
  Depende de: T005, T006, T007
  Paralelizable: no
  Criterio de terminado: 4 widget tests verdes.

## Validación de calidad

- [ ] **T013 Validación**: `flutter analyze` con 0 errores nuevos. Los 4 hints `info` preexistentes siguen tolerados.
  Depende de: T001..T012
  Paralelizable: no
  Criterio de terminado: salida limpia.

- [ ] **T014 Validación**: `flutter test` verde con la suite completa (~320 tests esperados).
  Depende de: T001..T012
  Paralelizable: no
  Criterio de terminado: "All tests passed!".

- [ ] **T015 Validación**: bump de versión en `mobile/pubspec.yaml` (`0.10.0+62 → 0.11.0+63`) y `mobile/android/app/build.gradle.kts` (`versionCode = 63`, `versionName = "0.11.0"`).
  Depende de: T013, T014
  Paralelizable: no
  Criterio de terminado: ambos archivos sincronizados. `scripts/verify-apk.sh` pasa al construir el APK.

- [ ] **T016 Validación**: invocar skill `branch-quality-review` con argumento `flutter-reports-monthly-average-v1`. Si surgen hallazgos bloqueantes, corregirlos antes del commit final.
  Depende de: T015
  Paralelizable: no
  Criterio de terminado: reporte generado en `engineering/quality-review/flutter-reports-monthly-average-v1/`. Hallazgos Altas y Críticas atendidos o documentados con criterio.

- [ ] **T017 Validación**: smoke manual SM-01..SM-05 documentados por Diego (en este sprint solo confirmar SM-01 mínimo: el tab carga sobre BD real sin crash).
  Depende de: T015
  Paralelizable: sí (con T016)
  Criterio de terminado: Diego confirma "todo OK".

## Documentación

- [ ] **T018 Documentación**: crear `engineering/specs/flutter-reports-monthly-average-v1/implementation/resumen-ejecutivo.md` (1-2 párrafos) y `resumen-extenso.md` (decisiones tomadas, casos cubiertos, pendientes) tras la implementación. Coherente con sprints anteriores.
  Depende de: T013, T014
  Paralelizable: sí
  Criterio de terminado: ambos archivos creados con contenido real (no stubs).

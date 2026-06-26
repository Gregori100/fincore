# Implementation Review: flutter-reports-cashflow-v1

## Resumen de lo implementado

Sprint cerrado. Se agregó el tab "Cashflow mensual" como segunda pestaña
de `/reports`, con bar chart pareado nativo (verde ingresos / rojo
gastos) por mes calendario, 3 métricas del período (ingresos, gastos,
neto) y breakdown numérico debajo del chart. Default `thisMonth` por
coherencia con el otro tab. Servicio nuevo `ReportsService.cashflowByMonth`
con query SQL `GROUP BY strftime('%Y-%m', occurred_at)` + filtros por
kind (`income`, `expense`, `credit_expense`) + soft delete excluido.
Modelos nuevos `CashflowReport` y `MonthCashflow`. Sin schema bump,
sin deps externas, sin cambios productivos breaking.

## Archivos principales modificados

Nuevos:

- `mobile/lib/screens/reports/cashflow_tab.dart` (501 líneas).
- `mobile/test/screens/cashflow_tab_test.dart` (88 líneas, 3 widget tests).

Modificados:

- `mobile/lib/data/reports.dart` (+~150 líneas: modelos `CashflowReport`,
  `MonthCashflow`, método `cashflowByMonth`, helper `_iterateMonthsBetween`,
  builder `_buildCashflowReport`).
- `mobile/lib/screens/reports_screen.dart` (length: 1 → 2 + 2do tab + 2do
  TabBarView entry).
- `mobile/test/data/reports_test.dart` (+~250 líneas: 13 tests data
  agrupados en 5 grupos).
- `mobile/pubspec.yaml` (versión 0.7.0+58 + nota).
- `mobile/android/app/build.gradle.kts` (versionCode 58 / versionName
  0.7.0).

## Tareas completadas

Todas las 30 tareas de `plan/tasks.md` cerradas. Detalle:

- T001 — Baseline 219 tests verdes confirmado pre-sprint.
- T002-T005 — Modelos + servicio + helper (F1).
- T006-T013 — 13 tests data nuevos (F2). UT-01 a UT-13 cubren RN-C01..C08
  + CB-T01..T13. UT-05 requirió ajuste menor: generar deuda con
  `credit_expense` antes de `debt_payment` para evitar el
  `overpay_debt` defensivo del DAO.
- T014-T020 — UI completa del `CashflowTab` con header de presets,
  StreamBuilder, 3 sub-widgets privados (`_CashflowHeader`, `_CashflowChart`,
  `_CashflowBreakdown`), estados loading/error/empty.
- T021-T023 — `ReportsScreen` con TabBar de 2 tabs.
  `reports_screen_test.dart` verde sin cambios (los tests no asumían
  length=1, T023 cerró sin modificación).
- T024-T026 — 3 widget tests del cashflow tab en 2s.
- T027-T029 — analyze + suite completa + APK + verify.
- T030 — esta documentación.

## Tareas pendientes

Ninguna del plan. Pendiente del usuario (no del sprint):

- Smoke manual en cel real (SM-01..SM-06 del test-plan). El APK
  `0.7.0+58` está construido y listo para `adb install -r`.

## Riesgos residuales

- **R-04 del spec** (mitigado): el default `thisMonth` muestra 1 sola
  columna pareada. La mitigación documentada (Diego tappea "Año" o
  "Custom") sigue válida. Si en uso real Diego prefiere un default
  más amplio, agregar preset `last6Months` en una v2.
- **R-T01 del plan** (cerrado): el helper `_iterateMonthsBetween`
  cubierto por UT-07 (cruzar año), UT-08 (mes intermedio vacío), UT-10
  (límite de mes). Sin issues con DST en local del cel.
- **R-T02 del plan** (cerrado): el bar chart pareado tiene
  `SingleChildScrollView(scrollDirection: Axis.horizontal)` por
  construcción. CB-T16 (rango > 6 meses) sigue dependiendo de smoke
  manual.
- **R-T03 del plan** (cerrado): `reports_screen_test.dart` no asumía
  length=1.

## Pruebas realizadas

- `flutter analyze` — 0 errores, 4 hints `info` cosméticos
  pre-existentes (no relacionados con este sprint).
- `flutter test` completo — **235/235 verdes** en 21s. Sin regresión.
- `flutter test test/data/reports_test.dart --name 'cashflowByMonth'`
  — **13/13 verdes** (UT-01 a UT-13).
- `flutter test test/screens/cashflow_tab_test.dart` — **3/3 verdes**
  (WT-01, WT-02, WT-03).
- `flutter test test/screens/reports_screen_test.dart` — **5/5 verdes**
  post bump a 2 tabs (validación T023).
- `flutter build apk --release --split-per-abi` — 3 APKs construidos.
- `bash scripts/verify-apk.sh` — `versionCode 2058 / versionName 0.7.0`
  consistentes.

## Pruebas recomendadas

Smoke manual en el Redmi tras `adb install -r app-arm64-v8a-release.apk`:

- SM-01: abrir app → tap "Reportes" → ver TabBar con 2 tabs.
- SM-02: tap "Cashflow mensual" → ver chips presets + métricas + chart
  + breakdown.
- SM-03: tap preset "Año" → reporte refresca con más meses; scroll
  horizontal si no caben.
- SM-04: tap "Custom" → 2 date pickers funcionan.
- SM-05: registrar income en otra pestaña, volver al tab → reporte
  refleja el nuevo dato (reactividad).
- SM-06: rango vacío → empty state visible.

## Posibles regresiones

Cero detectadas en automatizado. Áreas a vigilar en smoke manual:

- `/reports` tab 0 ("Gasto por categoría") — sin cambios productivos
  pero el bump de length puede afectar transiciones de tab.
- Dashboard BO/DE/CR — calculados por `FinancialStateService`,
  independientes del reports service. Sin riesgo.
- Deep link desde el bucket de gasto al `/entries` —
  `reports_deeplink_test.dart` cubierto.

## Recomendaciones para code review humano

- Verificar que el SQL de `cashflowByMonth` (`SUM(CASE WHEN ...)`) emite
  exactamente las columnas que `_buildCashflowReport` lee. Cambios al
  alias `income`/`expense` requieren sincronización dual.
- Verificar que `_iterateMonthsBetween` maneja correctamente el caso
  `from > to` (no debería ocurrir por validación del UI, pero la
  función no defensiva — retorna lista vacía si `cursor` ya está
  después de `end` antes del primer push).
- El bar chart pareado tiene un alto mínimo de 2px por barra (`_Bar`).
  Validación visual recomendada: un mes con income=0 y expense=1000
  no debería mostrar la barra verde "centrada" si por algún cálculo
  raro queda a 0px.
- Tab `Cashflow mensual` clona el patrón visual del spending tab. Si
  algún sprint futuro extrae un base widget compartido, sincronizar.
- El `branch-quality-review` no se invocó (skill disponible pero no
  pedido explícitamente por el usuario). Si Diego quiere revisión
  exhaustiva, ejecutar `branch-quality-review flutter-reports-cashflow-v1`
  antes de merge.

# Tasks — flutter-reports-cashflow-v1

## F0 — Validación pre-sprint

- [ ] T001 Validación de calidad: confirmar baseline antes de tocar.
  RF: —
  Depende de: ninguna
  Paralelizable: no
  Criterio de terminado: `flutter test` → 219/219 verdes,
  `flutter analyze` → 0 errores, `git status` limpio en `mobile/`.

## F1 — Modelos + servicio (data layer)

- [ ] T002 Backend: definir modelos inmutables `CashflowReport` y
  `MonthCashflow` en `mobile/lib/data/reports.dart`.
  RF: RF-002, RF-003
  Depende de: T001
  Paralelizable: no (los siguientes los usan).
  Criterio de terminado: clases `CashflowReport({from, to, totalIncome,
  totalExpense, net, months})` y `MonthCashflow({monthKey, firstDay,
  income, expense, net})` definidas con `const` constructor + campos
  `final`.

- [ ] T003 Backend: implementar helper privado
  `_iterateMonthsBetween(from, to)` que retorna lista de DateTime de
  primer-día-del-mes inclusivos.
  RF: RF-005
  Depende de: T002
  Paralelizable: si (con T004)
  Criterio de terminado: para `from=2026-01-15` y `to=2026-03-10`
  devuelve `[2026-01-01, 2026-02-01, 2026-03-01]`. Sin tocar timezone.

- [ ] T004 Backend: implementar `ReportsService.cashflowByMonth(from,
  to)` con la query SQL `strftime('%Y-%m', occurred_at)` + filtros
  por kind + soft delete.
  RF: RF-001, RF-004
  Depende de: T002
  Paralelizable: si (con T003)
  Criterio de terminado: método retorna `Stream<CashflowReport>` con
  `readsFrom: {_db.journalEntries}`. Filtros: `kind IN ('income',
  'expense', 'credit_expense')` + `deleted_at IS NULL` +
  `occurred_at BETWEEN ? AND ?`. La query agrupa por mes y suma
  `CASE WHEN kind = 'income' THEN amount ELSE 0 END` y
  `CASE WHEN kind IN ('expense','credit_expense') THEN amount ELSE 0 END`.

- [ ] T005 Backend: implementar `_buildCashflowReport(rows, from, to)`
  que combina las filas del SQL con `_iterateMonthsBetween` para
  rellenar meses vacíos con 0s, calcula totales y net del período.
  RF: RF-005, RN-C06, RN-C07
  Depende de: T003, T004
  Paralelizable: no
  Criterio de terminado: el método retorna `CashflowReport` ordenado
  cronológicamente ascendente (RN-C08). Meses sin entries aparecen
  con `income=0, expense=0, net=0`.

## F2 — Tests del DAO

- [ ] T006 Pruebas: agregar grupo `cashflowByMonth — agregación básica`
  con setUp compartido en `mobile/test/data/reports_test.dart`.
  RF: —
  Depende de: T005
  Paralelizable: no
  Criterio de terminado: estructura `group(...)` armada con seed
  reutilizado. UT-01, UT-02, UT-03 declarados aunque vacíos.

- [ ] T007 Pruebas: UT-01 BD sin entries → `totalIncome=0`,
  `totalExpense=0`, `net=0`, `months` con los meses del rango con 0s.
  RF: RF-005, RN-C06
  Depende de: T006
  Paralelizable: si (T007..T013)
  Criterio de terminado: assertion `report.months.length ==
  numMesesDelRango && report.totalIncome == 0`.

- [ ] T008 Pruebas: UT-02 único income en un mes → income > 0, expense
  = 0, net positivo.
  RF: RN-C01, RN-C07
  Depende de: T006
  Paralelizable: si
  Criterio de terminado: assertion sobre el `MonthCashflow` del mes
  sembrado y sobre los totales del reporte.

- [ ] T009 Pruebas: UT-03 expense + credit_expense del mismo mes se
  suman en `expense`.
  RF: RN-C02
  Depende de: T006
  Paralelizable: si
  Criterio de terminado: `month.expense == expense.amount +
  creditExpense.amount`.

- [ ] T010 Pruebas: agregar grupo `cashflowByMonth — filtros de kind`
  con UT-04 (`transfer` NO cuenta) + UT-05 (`debt_payment` NO cuenta).
  RF: RN-C03
  Depende de: T006
  Paralelizable: si
  Criterio de terminado: en cada test, sembrar 1 entry del kind
  correspondiente y validar que todos los `months` quedan con
  income/expense en 0.

- [ ] T011 Pruebas: agregar grupo `cashflowByMonth — soft delete` con
  UT-06 (entry con `deleted_at != NULL` no cuenta).
  RF: RN-C02 (soft delete coherente con RN-R07)
  Depende de: T006
  Paralelizable: si
  Criterio de terminado: cancel del entry vía DAO + reporte no
  incluye el monto cancelado.

- [ ] T012 Pruebas: agregar grupo `cashflowByMonth — agrupación por mes`
  con UT-07 a UT-11 (orden cronológico, mes vacío intermedio, from==to,
  rango de 1 día, rango cruza límite mes).
  RF: RN-C06, RN-C08
  Depende de: T006
  Paralelizable: si
  Criterio de terminado: cada uno de los 5 tests valida un caso borde
  específico del agrupamiento.

- [ ] T013 Pruebas: agregar grupo `cashflowByMonth — invariantes` con
  UT-12 (net = income - expense) + UT-13 (suma de meses == total).
  RF: RN-C07
  Depende de: T006
  Paralelizable: si
  Criterio de terminado: 2 tests con assertions matemáticas sobre el
  reporte.

## F3 — UI del tab nuevo

- [ ] T014 Frontend: crear esqueleto de `CashflowTab` en
  `mobile/lib/screens/reports/cashflow_tab.dart` clonando el lifecycle
  del `SpendingByCategoryTab` (initState con preset thisMonth + state
  `_from`, `_to`, `_preset`, `_reportStream`).
  RF: RF-006
  Depende de: T005
  Paralelizable: no (los siguientes lo modifican).
  Criterio de terminado: archivo compila + `flutter analyze` 0
  errores. Renderiza un Scaffold vacío con un `Text('TODO')`.

- [ ] T015 Frontend: integrar el header de presets (chips
  `DateRangePreset.values`) + el `DateFieldOutlined` cuando
  `_preset == custom`. Reusa el patrón visual del spending tab
  verbatim.
  RF: RF-006
  Depende de: T014
  Paralelizable: si (con T016)
  Criterio de terminado: tap en cada preset cambia el rango efectivo
  y refresca el stream. En "Custom", los 2 date pickers funcionan.

- [ ] T016 Frontend: implementar `_CashflowHeader` con 3 métricas
  (Ingresos verde, Gastos rojo, Neto con color según signo).
  RF: RF-007
  Depende de: T014
  Paralelizable: si (con T015)
  Criterio de terminado: widget privado `_CashflowHeader({report})`
  renderiza 3 chips/cards con label + monto formateado con
  `formatAmount`. El neto usa `FincoreColors.positive` o
  `FincoreColors.negative` según signo.

- [ ] T017 Frontend: implementar `_CashflowChart` con bar chart pareado
  nativo (1 columna por mes, 2 barras verticales por columna).
  RF: RF-008
  Depende de: T014
  Paralelizable: si (con T016, T018)
  Criterio de terminado: `Container` con `SingleChildScrollView(scrollDirection:
  Axis.horizontal)` interno, ancho mínimo ~40dp por columna, alto fijo
  ~140dp. Cada barra es un `Container` con `height` proporcional al
  `max(maxIncome, maxExpense)` del período. Labels MMM en es_MX
  bajo cada columna.

- [ ] T018 Frontend: implementar `_CashflowBreakdown` con filas
  numéricas (mes / ingreso / gasto / neto).
  RF: RF-009
  Depende de: T014
  Paralelizable: si
  Criterio de terminado: `Column` con `_CashflowBreakdownRow` por
  cada `MonthCashflow`. Cada row con 4 columnas: label MMM y y,
  monto income verde, monto expense rojo, neto con color signo.

- [ ] T019 Frontend: integrar todos los sub-widgets en el `build` de
  `CashflowTab` dentro del `StreamBuilder` con loading/error/empty
  states clonados del spending tab.
  RF: RF-010
  Depende de: T015, T016, T017, T018
  Paralelizable: no
  Criterio de terminado: `build` muestra
  presets + header de métricas + chart + breakdown cuando hay datos,
  empty state cuando `report.totalIncome + report.totalExpense == 0`,
  loading text estático mientras `!snap.hasData`.

- [ ] T020 Frontend: scroll horizontal en `_CashflowChart` cuando los
  meses superen el ancho del viewport.
  RF: RF-008, CB-T16
  Depende de: T017
  Paralelizable: no
  Criterio de terminado: con 12 meses en el reporte, el chart hace
  scroll horizontal sin overflow vertical. Validado con seed manual.

## F4 — Integración al ReportsScreen

- [ ] T021 Frontend: bumpear `DefaultTabController.length` de 1 a 2 +
  agregar `Tab(text: 'Cashflow mensual')` en `TabBar` y `CashflowTab()`
  en `TabBarView`.
  RF: RF-011, RF-012
  Depende de: T019
  Paralelizable: no
  Criterio de terminado: `mobile/lib/screens/reports_screen.dart`
  muestra los 2 tabs visibles. Arranca en el primero
  (`initialIndex` default = 0).

- [ ] T022 Frontend: validar que el navigation deep link a `/reports`
  desde `/dashboard` sigue funcionando sin cambios.
  RF: —
  Depende de: T021
  Paralelizable: si (con T023)
  Criterio de terminado: tap en wordmark dashboard → "Reportes" →
  abre `/reports` en tab 0.

- [ ] T023 Pruebas: ajustar `mobile/test/screens/reports_screen_test.dart`
  para los 2 tabs.
  RF: —
  Depende de: T021
  Paralelizable: si (con T022)
  Criterio de terminado: tests que usaban `find.byType(Tab)` con
  `findsOneWidget` cambian a `findsNWidgets(2)`. Tests que validan
  el label "Gasto por categoría" siguen sin cambios. Suite verde.

## F5 — Widget tests del tab nuevo

- [ ] T024 Pruebas: crear `mobile/test/screens/cashflow_tab_test.dart`
  con `pumpFincoreApp` + navegación a `/reports` + tap en tab
  "Cashflow mensual".
  RF: —
  Depende de: T021
  Paralelizable: no
  Criterio de terminado: archivo con setUp del harness + un test
  smoke "el tab monta sin error".

- [ ] T025 Pruebas: WT-01 — Render con datos: 3 meses sembrados con
  income + expense, validar métricas del header + presencia del chart
  + breakdown.
  RF: RF-007, RF-008, RF-009
  Depende de: T024
  Paralelizable: si (con T026)
  Criterio de terminado: assertions sobre los textos de las métricas
  (`Ingresos`, `Gastos`, `Neto`) + montos formateados.

- [ ] T026 Pruebas: WT-02 — Empty state: BD sin entries en thisMonth,
  texto "No hay movimientos en este rango." visible.
  RF: RF-010
  Depende de: T024
  Paralelizable: si
  Criterio de terminado: `find.text(...)` retorna `findsOneWidget`.

## F6 — Release

- [ ] T027 Validación de calidad: `flutter analyze` + `flutter test`
  completos.
  RF: —
  Depende de: T026, T023, T013, T020
  Paralelizable: no
  Criterio de terminado: 0 errores en analyze (hints `info`
  pre-existentes tolerados). ~232 tests verdes en `flutter test`.

- [ ] T028 Documentación: bump `pubspec.yaml` a `0.7.0+58` + bump
  `android/app/build.gradle.kts` (`versionCode = 58`, `versionName =
  "0.7.0"`). Agregar nota del cambio en el header del pubspec.
  RF: —
  Depende de: T027
  Paralelizable: si (con T029)
  Criterio de terminado: ambos archivos consistentes y la nota del
  pubspec menciona el sprint, los archivos nuevos, los 14 tests
  nuevos.

- [ ] T029 Validación de calidad: `flutter build apk --release
  --split-per-abi` + `bash scripts/verify-apk.sh`.
  RF: CM-04
  Depende de: T028
  Paralelizable: no
  Criterio de terminado: 3 APKs construidos, `verify-apk.sh` OK con
  `versionCode 2058 / versionName 0.7.0`.

- [ ] T030 Documentación: crear
  `engineering/specs/flutter-reports-cashflow-v1/implementation/resumen-extenso.md`
  con detalle del sprint cerrado (modelos nuevos, decisión P-001+P-002
  reflejadas, riesgos cerrados, regresiones validadas).
  RF: —
  Depende de: T029
  Paralelizable: no
  Criterio de terminado: archivo escrito + commit del sprint
  preparado.

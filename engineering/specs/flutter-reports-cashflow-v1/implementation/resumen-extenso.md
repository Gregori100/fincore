# Resumen extenso — flutter-reports-cashflow-v1

## Contexto tomado de spec.md, preguntas.md y clarificaciones

El sprint sale del menú post-deuda-técnica como **F4 — Cashflow
mensual** según la priorización del menú. Es el primer sprint de
features visibles después del ciclo de 3 sprints de deuda
(`flutter-integration-tests-v1`, `flutter-entries-list-refactor-v1`,
`flutter-pumpandsettle-diagnosis-v1`).

Decisiones cerradas en spec con preguntas bloqueantes (`preguntas.md`):

- **P-001 (default preset)**: respondida `thisMonth` (opción D —
  igual que el otro tab). Coherencia ganó a "ver tendencia
  inmediatamente al abrir". Permite no tocar el enum
  `DateRangePreset`.
- **P-002 (visualización)**: respondida pareado nativo (opción A).
  Sin dep externa (`fl_chart` rechazado), patrón consistente con el
  bar chart horizontal del spending tab.

Reglas de negocio críticas asentadas en spec (RN-C01..C08):

- `income` suma a "Ingresos" (RN-C01).
- `expense` + `credit_expense` suman a "Gastos" (RN-C02).
- `transfer` y `debt_payment` **excluidos** (RN-C03). Razón: son
  movimientos internos sin impacto en flujo "contra el afuera";
  incluirlos doble-contaría con el `credit_expense` original.
- Agrupación por mes calendario con clave `YYYY-MM` (RN-C04).
- Rango inclusivo en ambos extremos (RN-C05), coherente con el
  spending tab.
- Meses dentro del rango sin entries se muestran con 0s (RN-C06),
  para no abrir huecos visuales en el chart.
- `net = totalIncome - totalExpense` (RN-C07).
- Orden cronológico ascendente en el eje X (RN-C08).

## Relación con plan/plan.md y plan/tasks.md

**Las 30 tareas** del plan ejecutadas en orden de fases F0 → F6 sin
desviaciones materiales. Detalle:

- **F0** (T001): baseline 219 verdes confirmado pre-sprint.
- **F1** (T002-T005): modelos + servicio + helper + builder. Todo en
  `lib/data/reports.dart`. ~150 líneas adicionales.
- **F2** (T006-T013): 13 tests data en `test/data/reports_test.dart`
  agrupados en 5 grupos según el plan. UT-05 requirió ajuste menor
  (generar deuda con credit_expense antes del debt_payment para
  evitar `overpay_debt` del DAO defensivo).
- **F3** (T014-T020): UI completa del `CashflowTab` en
  `lib/screens/reports/cashflow_tab.dart` (~500 líneas). Reusa
  patrón visual del spending tab para chips, custom date pickers,
  estados loading/error/empty. Bar chart pareado custom-built con
  `Container` + `SizedBox(height: factor * 140)` + scroll horizontal.
- **F4** (T021-T023): `ReportsScreen` con TabBar de 2 tabs.
  `reports_screen_test.dart` verde sin cambios (T023 cerró sin
  modificación porque los tests existentes no asumían length=1).
- **F5** (T024-T026): 3 widget tests del cashflow tab en `cashflow_tab_test.dart`.
  Patrón `pumpFincoreApp` + `GoRouter.push('/reports')` + tap del
  segundo tab.
- **F6** (T027-T030): suite completa + bump 0.7.0+58 + APK + verify.

## Cambios principales por módulo o capa

### Capa de datos (`mobile/lib/data/reports.dart`)

Modelos nuevos:

- `CashflowReport({from, to, totalIncome, totalExpense, net, months})`
  con getter `isEmpty` (true si `totalIncome == 0 && totalExpense == 0`).
- `MonthCashflow({monthKey, firstDay, income, expense, net})` para
  cada mes calendario del rango.

Servicio extendido:

- `ReportsService.cashflowByMonth(from, to)` retorna
  `Stream<CashflowReport>` con `readsFrom: {_db.journalEntries}`. La
  query NO joinea `categories` (cashflow es agregado, no desglosa por
  categoría) — minimiza costo y elimina dependencia reactiva en
  cambios de categorías archivadas.

Helpers privados:

- `_iterateMonthsBetween(from, to)` retorna lista de DateTime de
  primer-día-del-mes inclusivos. Sin tocar timezone (`DateTime(year,
  month, 1)` simple, coherente con el resto de la app).
- `_buildCashflowReport(rows, from, to)` combina las filas del SQL con
  el helper iterador para rellenar meses vacíos. Calcula totales y
  net del período.

### Capa de presentación

`mobile/lib/screens/reports/cashflow_tab.dart` nuevo. Clona la
estructura del `SpendingByCategoryTab`:

- State: `_from`, `_to`, `_preset`, `_reportStream` cacheado en
  `didChangeDependencies` para que `pumpAndSettle` asiente en widget
  tests.
- 4 sub-widgets privados:
  - `_CashflowHeader` — 3 métricas (Ingresos, Gastos, Neto) con
    `_HeaderMetric` reusable.
  - `_CashflowChart` — bar chart pareado nativo en
    `SingleChildScrollView(horizontal)` con columnas de 48dp + barras
    de 14dp + alto de chart fijo en 140dp. `_ChartColumn` arma cada
    columna pareada; `_Bar` arma cada barra con altura proporcional
    a `factor * 140` (mínimo 2px para mantener alineación visual con
    income=0).
  - `_CashflowBreakdown` — filas numéricas mes/ingreso/gasto/neto con
    `_BreakdownRow`.
  - `_EmptyState`, `_LoadingState`, `_ErrorState` clonados del spending
    tab.

`mobile/lib/screens/reports_screen.dart`:

- `DefaultTabController.length: 1 → 2`.
- Segundo `Tab(text: 'Cashflow mensual')` agregado al `TabBar`.
- Segundo `CashflowTab()` agregado al `TabBarView`.

### Tests

`mobile/test/data/reports_test.dart`:

- 5 grupos nuevos con 13 tests:
  - `cashflowByMonth — agregación básica`: UT-01 (empty), UT-02 (income),
    UT-03 (expense + credit_expense).
  - `cashflowByMonth — filtros de kind (RN-C03)`: UT-04 (transfer),
    UT-05 (debt_payment).
  - `cashflowByMonth — soft delete`: UT-06.
  - `cashflowByMonth — agrupación por mes`: UT-07 (cruzar año),
    UT-08 (mes intermedio vacío), UT-09 (from==to), UT-10 (cruza
    límite de mes), UT-11 (límite inclusivo `from`).
  - `cashflowByMonth — invariantes`: UT-12 (net = income - expense
    por mes y total), UT-13 (sum de meses = total).

`mobile/test/screens/cashflow_tab_test.dart` nuevo:

- WT-01: render con datos.
- WT-02: empty state con BD sin entries.
- WT-03: tap preset "Año" cambia rango y refresca.

## Desviaciones respecto al plan

Sin desviaciones materiales. Único ajuste menor durante la ejecución:

**UT-05 (debt_payment)** inicialmente falló con `overpay_debt`
porque el DAO defensivo no permite pagar deuda que no existe.
Corrección: generar deuda primero con `registerCreditExpense(200)`,
luego `registerDebtPayment(100)`. El test pasa de "debt_payment no
debe contar" a "credit_expense de 200 cuenta, debt_payment de 100
NO". Más completo que la versión original del plan.

T023 (ajustar `reports_screen_test.dart` por bump a 2 tabs) cerró
sin modificación: los 5 tests existentes ya usaban
`find.text('Gasto por categoría')` que sigue funcionando con
length=2. Ningún test asumía `findsOneWidget` sobre `byType(Tab)`.

## Pruebas realizadas y recomendadas

**Realizadas** (automatizado):

- `flutter analyze` → 0 errores, 4 hints `info` cosméticos
  pre-existentes (no del sprint).
- `flutter test` completo → 235/235 verdes en 21s.
  - 219 previos + 13 cashflow data + 3 cashflow widget = 235.
- `flutter test test/data/reports_test.dart --name 'cashflowByMonth'`
  → 13/13 verdes en 1s.
- `flutter test test/screens/cashflow_tab_test.dart` → 3/3 verdes
  en 2s.
- `flutter test test/screens/reports_screen_test.dart` → 5/5 verdes
  sin cambios.
- `flutter build apk --release --split-per-abi` → 3 APKs construidos
  en 55s.
- `bash scripts/verify-apk.sh` → versionCode 2058 / versionName 0.7.0
  consistentes.

**Recomendadas** (smoke manual, no del sprint):

- SM-01..SM-06 documentados en `test-plan.md` y replicados en
  `implementation-review.md`. Requieren Diego en cel real con el APK
  `0.7.0+58` instalado.

## Riesgos residuales y posibles regresiones

- **R-04 del spec** (mitigado): default `thisMonth` muestra 1 sola
  columna pareada al abrir. Mitigación documentada (tappear "Año" o
  "Custom"). Si en uso real Diego prefiere default más amplio, agregar
  `last6Months` en v2.
- Reactividad: el Stream re-emite cuando cambia `journal_entries`
  (validado por construcción del `customSelect.watch` con
  `readsFrom`). Recomendado validar en SM-05.
- Sin regresión esperada en el otro tab. La `ReportsScreen` solo
  agregó la segunda entrada en el TabBar; el primero conserva su
  estructura.
- `branch-quality-review` NO se ejecutó (skill disponible pero no
  pedido por el usuario). Si Diego quiere revisión exhaustiva,
  invocar antes de merge.

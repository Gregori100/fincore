# Resumen extenso — flutter-cashflow-monthly-breakdown-v1

## Contexto

El tab "Cashflow mensual" (`/reports` tab 2) mostraba hasta este sprint
un agregado plano por mes (ingresos, gastos, neto) sin desglose por
categoría. Ese gap es lo que este sprint cierra: al tapear cualquier
fila de mes se abre un bottom sheet que enumera las categorías de
ingresos y las de gastos del mes con monto y percent, y ofrece un
drill-down a `/entries` con el rango del mes preseteado.

Decisiones tomadas antes de spec (via AskUserQuestion):
1. **UX pattern**: bottom sheet al tapear la fila del mes (patrón
   heatmap). Encabezado con métricas + secciones ingresos/gastos + link
   "Ver movimientos →".
2. **Alcance**: ambas — categorías de ingresos y de gastos. Solo se
   muestra el lado que tiene datos.

## Relación con `plan/plan.md` y `plan/tasks.md`

Se ejecutaron **T001-T015 + T017 + T018 completas** en el orden del
plan. **T016 (smokes SM-01..07)** pendiente en cel real (registrado
en memoria para batch cuando Diego pueda instalar). El commit final
`a424345` en `main` incluye los fixes A1..A7 del quality-review.

Todos los RF de la spec quedan cubiertos por código + tests:

- RF-001 a RF-010: servicio + modelos + helper.
- RF-011 a RF-013: widget del tab + sheet + drill-down.
- RF-014: `EntriesFilters.forMonth`.
- RF-015: FAQ.
- RF-016: tests.
- RF-017: bump.

Todas las 12 reglas de negocio (RN-CB01..CB12) están implementadas y
verificadas con UT + WT.

## Cambios principales por módulo o capa

### Data (`mobile/lib/data/reports.dart`)

- Nuevo método `ReportsService.cashflowMonthBreakdown({DateTime
  monthAnchor})` que retorna `Stream<MonthBreakdown>`.
- SQL con `strftime('%Y-%m', occurred_at, 'localtime') = ?` filtrando
  `kind IN ('income','expense','credit_expense')` +
  `deleted_at IS NULL` en journal_entries + `LEFT JOIN categories`
  filtrando `c.deleted_at IS NULL`.
- `readsFrom: {journalEntries, categories}` para reactividad completa
  (rename/archive de categoría dispara re-emit).
- Helper `_buildMonthBreakdown` que:
  - Colapsa a "Sin categoría" cuando el LEFT JOIN devuelve `applies_to
    == null` (categoría archivada o FK huérfana — RN-CB11 + CB-P02).
  - Aplica simetría RN-CB03/CB04: `applies_to='expense'` cae al bucket
    "Sin categoría" del lado ingresos y viceversa.
  - Filtra buckets con `amount <= 0` (CB-P03/CB-P04).
  - Calcula percent con guard `total > 0`.
  - Ordena descendente por amount.
- Nuevos modelos `MonthBreakdown` y `CategoryFlow` const-inmutables +
  clase privada `_BreakdownAccumulator` para acumular montos por
  category_id.

### Filtros (`mobile/lib/data/entries_filters.dart`)

- Nuevo factory `EntriesFilters.forMonth({required DateTime firstDay})`
  que arma `[firstDay 00:00, lastDayOfMonth 23:59:59.999]` usando
  `DateTime(y, m+1, 0, 23, 59, 59, 999)`. Respeta bisiestos (validado
  en UT-CB15).

### UI (`mobile/lib/screens/reports/cashflow_tab.dart`)

- Imports añadidos: `category_catalog.dart`, `entries_filters.dart`,
  `go_router`.
- `_BreakdownRow` envuelto con `Material(color: Colors.transparent) +
  InkWell + Padding + Row`. Splash queda dentro del row sin invadir
  el Divider externo (R7 del plan). Se agrega ícono `chevron_right`
  como affordance visual.
- Nueva clase `_MonthBreakdownSheet` (StatefulWidget) que:
  - Cachea el Stream una sola vez en `didChangeDependencies` (patrón
    cashflow tab).
  - Renderea SafeArea > SingleChildScrollView con
    `ClampingScrollPhysics` (patrón sheet heatmap).
  - Header con título del mes (`DateFormat('MMMM y', 'es_MX')`
    capitalizado) + botón cerrar.
  - StreamBuilder con estados loading / error / empty / data.
  - Data: `_BreakdownSummary` (BaseCard con 3 columnas
    ingresos/gastos/neto) + secciones condicionales por lado +
    `TextButton.icon` con `Icons.arrow_forward` para el drill-down.
- Subwidgets internos: `_BreakdownSummary`, `_SectionHeader`,
  `_CategoryFlowRow`, `_MonthBreakdownLoading`, `_MonthBreakdownEmpty`,
  `_MonthBreakdownError`.
- `_CategoryFlowRow` usa `colorBySlug`/`iconBySlug` directamente
  (evita construir `Category` sintético, R8 del plan). Fallback "Sin
  categoría" con `Icons.label_off_outlined` + `FincoreColors.textSubtle`.
- Drill-down implementado con captura de `navigator` y `router` antes
  del `await maybePop()` + chequeo `mounted` post-await (R3 del plan).

### Docs

- `help_screen.dart`: bullet del cashflow extendido con
  "Al tapear una fila de mes se abre el desglose por categoría
  (ingresos y gastos) con acceso directo a los movimientos del mes."

## Desviaciones respecto al plan

- **D1 — Fix del helper para categorías archivadas**: durante T011
  el UT-CB06 falló porque el `LEFT JOIN categories ... AND c.deleted_at
  IS NULL` devuelve `c.*` en null pero `j.category_id` sigue con el ID
  original de la categoría archivada. El helper original agrupaba por
  `j.category_id` sin detectar el JOIN vacío. Fix: colapsar a
  "Sin categoría" cuando `applies_to == null` (LEFT JOIN vacío). El
  cambio también cubre CB-P02 (FK huérfana). Documentado en el
  implementation-review.
- **D2 — Tests UT-CB07/CB08 con `updateCategory` post-facto**: el DAO
  rechaza registrar income con categoría `applies_to='expense'` y
  simétrico. Para simular el edge legacy los tests crean la categoría
  como `applies_to='both'`, registran el movimiento válido, y después
  editan `applies_to` para dejar la incompatibilidad post-facto (real
  path del edge legacy que la spec cubre).
- **D3 — Slugs de iconos válidos**: durante T011 el test UT-CB09 usó
  `iconSlug: 'ellipsis'` que no existe. Cambiado a `'gift'` (slug real
  del catálogo).
- **D4 — Test UT-CB11 requiere cargo previo**: para probar
  `debt_payment` excluido se necesita registrar un `credit_expense`
  primero (invariante `overpay_debt` del DAO). Añadido al setup del
  test.
- **D5 — Widget test WT-CB03 no puede tapear fila vacía**: cuando el
  tab base tiene BD vacía renderea empty state sin breakdown → no hay
  fila para tapear. El test se ajustó para blindar que NO existe el
  icono cuando la BD está vacía. El fallback del sheet
  "Sin movimientos en este mes." queda cubierto por WT-CB05 (agregado
  en A5 post-QR) que fuerza el escenario con preset "Año" + 1 solo
  movimiento en el mes actual.
- **D6 — Fixes post branch-quality-review (A1..A7)**: el review de la
  rama detectó 1 bloqueante + 2 Media + 2 Baja + 1 Alta + 1 Media
  aplicados como A1..A7. El más crítico (**A1**) fue el drill-down:
  el patrón original usaba `router.push('/entries', extra: filter)`
  pero `EntriesListScreen` NO lee `state.extra` — solo query params.
  Feature principal del sprint estaba rota y WT-CB04 pasaba solo por
  casualidad porque `monthAnchor == mes actual == thisMonth() default`.
  Cambiado a `router.push(filter.toDeepLink())`. Ver
  `implementation-review.md` y
  `engineering/quality-review/flutter-cashflow-monthly-breakdown-v1/`
  para el detalle completo de A2..A7.

## Pruebas realizadas y recomendadas

### Realizadas

- `flutter analyze` limpio (solo hints info pre-existentes en
  skeleton/entry_form tolerados).
- `flutter test` 560/560 verdes:
  - UT-CB01..13 + UT-CB16 servicio (14 tests: todos los edge cases +
    reactividad + FK huérfana).
  - UT-CB14..15 filtro `forMonth` (mes normal + bisiesto).
  - WT-CB01..05 widget (5 tests: sheet abre, ambas secciones, empty
    sin fila, drill-down navega, mes vacío con fallback).
- APK release + `verify-apk.sh` OK (versionCode 2088 / versionName
  0.17.0).

### Recomendadas

- SM-01..07 con Diego en cel real.
- Especialmente **SM-05** (renombrar categoría con sheet abierto →
  reactividad UI real).
- Si aparece regresión visual del `_BreakdownRow` (spacing, splash,
  divider), ampliar a widget test específico.

## Riesgos residuales y posibles regresiones

- **R6 — Divergencia timezone entre cashflow base y breakdown**: base
  agrupa por UTC (`strftime('%Y-%m', occurred_at)`), breakdown usa
  `'localtime'`. Aceptado por consistencia con calendar/heatmap.
  Alternativa futura: uniformar el base.
- **Cambio visual en _BreakdownRow**: agrega `chevron_right`. Diego
  lo notará al abrir el tab la primera vez.
- **Reactividad por rename de categoría**: `readsFrom: {journalEntries,
  categories}` provoca re-emit por cualquier cambio en categorías,
  incluidos los que no están en el mes visible. Overhead negligible en
  single-user.
- Cero regresión en cashflow base (query separada), otros reportes,
  `/entries` con otros factories, backup, forms, dashboard, tab base
  ni layout del breakdown numérico (excepto el chevron_right).

Sprint completo excepto smoke + quality-review + commit final.

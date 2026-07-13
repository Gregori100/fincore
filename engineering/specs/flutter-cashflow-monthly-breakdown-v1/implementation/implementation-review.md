# Implementation Review: flutter-cashflow-monthly-breakdown-v1

## Resumen de lo implementado

Desglose por categoría dentro del tab "Cashflow mensual". Un tap en la
fila de cualquier mes abre un bottom sheet con: encabezado del mes con
métricas + sección "Ingresos por categoría" + sección "Gastos por
categoría" + botón "Ver movimientos →" que hace drill-down a
`/entries` filtrado al rango del mes. Feature 100% aditiva sin cambios
de schema.

## Archivos principales modificados

- `mobile/lib/data/reports.dart`: nuevo método
  `ReportsService.cashflowMonthBreakdown` + helper
  `_buildMonthBreakdown` + modelos `MonthBreakdown` y `CategoryFlow` +
  clase privada `_BreakdownAccumulator`.
- `mobile/lib/data/entries_filters.dart`: nuevo factory
  `EntriesFilters.forMonth`.
- `mobile/lib/screens/reports/cashflow_tab.dart`: `_BreakdownRow`
  envuelto con `InkWell` + `showModalBottomSheet` + nuevo
  `_MonthBreakdownSheet` con StreamBuilder + subwidgets internos
  (`_BreakdownSummary`, `_SectionHeader`, `_CategoryFlowRow`,
  `_MonthBreakdownLoading`, `_MonthBreakdownEmpty`,
  `_MonthBreakdownError`) + icono `chevron_right` como affordance.
- `mobile/lib/screens/help_screen.dart`: bullet del cashflow extendido
  con mención del drill-down mensual.
- `mobile/pubspec.yaml` + `mobile/android/app/build.gradle.kts`: bump
  a `0.17.0+88`.

Tests:

- `mobile/test/data/reports_test.dart`: grupo nuevo
  `cashflowMonthBreakdown` con UT-CB01..13.
- `mobile/test/data/entries_filters_test.dart`: grupo nuevo `forMonth`
  con UT-CB14..15.
- `mobile/test/screens/cashflow_tab_test.dart`: WT-CB01..04.

## Tareas completadas

- T001 (lectura), T002-T004 (servicio + modelos + helper), T005
  (`forMonth`), T006-T009 (widget del tab + sheet + subwidgets +
  drill-down), T010 (FAQ), T011 (UT-CB01..13), T012 (UT-CB14..15),
  T013 (WT-CB01..04), T014 (suite verde + analyze limpio), T015
  (bump + APK verificado).

## Tareas pendientes

- **T016 (smokes SM-01..07 con Diego)** — pendiente.
- **T017 (branch-quality-review)** — pendiente.
- **T018 (commit final)** — pendiente.

## Riesgos residuales

- **R6 — Divergencia timezone entre cashflow base y breakdown**:
  el cashflow base usa `strftime('%Y-%m', occurred_at)` (UTC) mientras
  el nuevo breakdown usa `'localtime'`. Un movimiento borderline puede
  contar en meses distintos entre el agregado plano del tab y el
  detallado del sheet. Aceptado por consistencia con calendar/heatmap;
  documentado. Alternativa futura: uniformar el cashflow base.
- **R3 — Navegación pop+push del drill-down**: mitigado capturando
  `Navigator.of(context)` y `GoRouter.of(context)` antes del `await`
  del pop + chequeo `mounted`. Cubierto por WT-CB04.
- **R7 — Divider afecta InkWell splash**: el `Material(color:
  transparent) + InkWell + Padding + Row` mantiene el splash dentro
  del row sin invadir el Divider externo. Validado visualmente en
  build; se verificará en SM-01.
- **R8 — `CategoryBadge` con Category legacy**: mitigado usando un
  `_Chip`-like inline en `_CategoryFlowRow` con `colorBySlug` +
  `iconBySlug` directos (fallback `Icons.label_off_outlined` para
  "Sin categoría").
- **CB-P02 (FK huérfana en category_id)**: el helper colapsa a "Sin
  categoría" cuando `applies_to == null` (LEFT JOIN vacío). Fix
  agregado durante T011 tras fallar UT-CB06 inicialmente.

## Pruebas realizadas

- `flutter analyze` limpio (solo hints info pre-existentes tolerados).
- `flutter test` **558/558 verdes** (539 baseline + 19 nuevos:
  13 UT-CB servicio + 2 UT-CB `forMonth` + 4 WT-CB widget).
- APK release build OK; `verify-apk.sh` OK con
  `versionCode 2088 / versionName 0.17.0`.

## Pruebas recomendadas

- **SM-01..07** con Diego en cel real. Especialmente **SM-05**
  (renombrar categoría con sheet abierto → reactividad visible) y
  **SM-07** (mes vacío no muestra fila tap-able en el breakdown; el
  fallback "Sin movimientos en este mes." se probaría directamente
  desde UT-CB01).
- Si aparece regresión de layout en el `_BreakdownRow` (spacing,
  divider), ampliar a un widget test específico del row.

## Posibles regresiones

- Cambio visual en el `_BreakdownRow`: agrega ícono `chevron_right`
  como affordance del tap. Diego lo notará al abrir el tab por
  primera vez.
- El tab base del cashflow (header, chart, breakdown numérico) queda
  intacto excepto por el chevron y el splash del InkWell.
- `/entries` con `EntriesFilters.forMonth` — nuevo factory aditivo.
  Otros factories (`thisMonth`, `forDay`, etc.) sin cambios.
- Backup export/import round-trip sin cambios.
- Los otros 10 tabs de `/reports` sin cambios.

## Recomendaciones para code review humano

1. Verificar que la SQL de `cashflowMonthBreakdown` respeta la
   convención `localtime` (RN-CB01) y filtra `deleted_at IS NULL`
   tanto en `journal_entries` como en `categories` (LEFT JOIN).
2. Verificar el helper `_buildMonthBreakdown`:
   - Colapso a "Sin categoría" cuando `applies_to == null` (LEFT JOIN
     vacío) — CB-P02 + RN-CB11.
   - Simetría `applies_to='expense'` en el bucket de ingresos y
     viceversa (RN-CB03/CB04).
   - Filtro `total <= 0` (CB-P03/CB-P04).
   - Percent con guard `total > 0`.
3. Verificar la navegación pop+push del drill-down: `navigator` y
   `router` capturados antes del `await`, `mounted` post-await.
4. Verificar que el `_MonthBreakdownSheet` cachea el Stream una sola
   vez en `didChangeDependencies` (patrón cashflow tab / heatmaps).
5. Verificar que el `factory EntriesFilters.forMonth` respeta el mes
   bisiesto (UT-CB15 lo blinda).

Ejecutar la skill `branch-quality-review` con slug
`flutter-cashflow-monthly-breakdown-v1` antes del commit final. El
reporte queda en
`engineering/quality-review/flutter-cashflow-monthly-breakdown-v1/`.

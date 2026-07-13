# Tareas — flutter-cashflow-breakdown-prev-comparison-v1

## Backend

- [ ] T001 Backend: leer código actual detallado —
  `mobile/lib/data/reports.dart` bloques `cashflowMonthBreakdown`
  (~467-500), `_buildMonthBreakdown` (~500-575), `MonthBreakdown` +
  `CategoryFlow` (~1792-1840);
  `mobile/lib/screens/reports/cashflow_tab.dart` bloques
  `_CategoryFlowRow` (~904-960) y `_BreakdownSummary` (~785-870).
  Confirmar patrón de spacing interno del row y del summary.
  RF: —
  Depende de: ninguna
  Paralelizable: no
  Criterio de terminado: identificados los puntos de inserción exactos
  del `_DeltaChip` en el row y en las 3 columnas del summary.

- [ ] T002 Backend: en `reports.dart`, extender
  `ReportsService.cashflowMonthBreakdown({monthAnchor})` para computar
  `previousAnchor = DateTime(monthAnchor.year, monthAnchor.month - 1, 1)`,
  formatear ambos como `YYYY-MM`, y cambiar el SQL a:
  ```sql
  SELECT j.kind, j.category_id, c.name, c.color_slug, c.icon_slug,
         c.applies_to, SUM(j.amount) AS total,
         strftime('%Y-%m', j.occurred_at, 'localtime') AS month_key
  FROM journal_entries j
  LEFT JOIN categories c ON c.id = j.category_id AND c.deleted_at IS NULL
  WHERE j.deleted_at IS NULL
    AND j.kind IN ('income', 'expense', 'credit_expense')
    AND strftime('%Y-%m', j.occurred_at, 'localtime') IN (?, ?)
  GROUP BY j.kind, j.category_id, c.name, c.color_slug, c.icon_slug,
           c.applies_to, month_key
  ```
  Pasar `Variable.withString(currentKey)` y `Variable.withString(previousKey)`.
  RF: RF-001, RF-002
  Depende de: T001
  Paralelizable: no
  Criterio de terminado: método compila; query ejecutable con 2 meses.

- [ ] T003 Backend: extender `_buildMonthBreakdown` en `reports.dart`:
  - Aceptar el `previousKey` como parámetro (o computarlo desde
    `firstDay`).
  - Iterar rows separando por `month_key` en 4 acumuladores locales:
    `currentIncome`, `currentExpense`, `previousIncome`, `previousExpense`.
  - Al final construir los `CategoryFlow` del actual iterando
    `currentIncome/currentExpense`, y para cada bucket buscar el
    correspondiente en `previousIncome/previousExpense` por `categoryId`
    (null match null para "Sin categoría"). Aplicar guard RN-CP09:
    `previousAmount > 0` para calcular delta; sino `delta = null`.
  - Calcular `deltaIncome`, `deltaExpense`, `deltaNet` sobre totales
    (RN-CP08).
  - Extraer helper `_computeDelta(current, previous)` que retorna
    `DeltaPercent?` con las reglas RN-CP03/CP04/CP09.
  RF: RF-003
  Depende de: T002
  Paralelizable: no
  Criterio de terminado: helper compila; UT-CP01..09 pueden ejecutarse.

- [ ] T004 Backend: agregar en `reports.dart`:
  - `enum DeltaDirection { up, down, flat }` justo antes de
    `MonthBreakdown`.
  - `class DeltaPercent { final double percent; final DeltaDirection
    direction; const DeltaPercent({required this.percent, required
    this.direction}); }` const-inmutable.
  - Extender `CategoryFlow` con `final DeltaPercent? delta` en el
    constructor (nullable, opcional para no romper callers).
  - Extender `MonthBreakdown` con `final DeltaPercent? deltaIncome`,
    `deltaExpense`, `deltaNet`.
  RF: RF-004, RF-005
  Depende de: T001
  Paralelizable: si (con T002/T003 si se coordinan las signaturas)
  Criterio de terminado: `flutter analyze` limpio; modelos usables
  desde el helper y el widget.

## Frontend

- [ ] T005 Frontend: en
  `mobile/lib/screens/reports/cashflow_tab.dart`, agregar helper puro
  `Color _deltaColor(DeltaDirection direction, {required bool
  isExpenseSide})` con la matriz RN-CP07:
  - `flat → FincoreColors.textMuted`.
  - `up + !isExpenseSide → positive`.
  - `down + !isExpenseSide → negative`.
  - `up + isExpenseSide → negative`.
  - `down + isExpenseSide → positive`.
  RF: RF-008
  Depende de: T004
  Paralelizable: no
  Criterio de terminado: helper compila y testeable inline.

- [ ] T006 Frontend: agregar widget interno `_DeltaChip` en
  `cashflow_tab.dart`:
  - Constructor con `DeltaPercent? delta`, `bool isExpenseSide`.
  - Si `delta == null` → `Text('—', style: TextStyle(color:
    FincoreColors.textMuted, fontSize: 11))` sin ícono.
  - Si `delta != null`:
    - Ícono según `direction`: `arrow_upward` (up), `arrow_downward`
      (down), `remove` (flat) size 12.
    - Color = `_deltaColor(direction, isExpenseSide)`.
    - Texto: `'${percent.toStringAsFixed(1)}%'` con el mismo color.
    - Row con Icon + SizedBox(width: 2) + Text.
  RF: RF-006
  Depende de: T005
  Paralelizable: no
  Criterio de terminado: chip renderea correctamente los 4 estados
  (null, up, down, flat).

- [ ] T007 Frontend: extender `_CategoryFlowRow` en
  `cashflow_tab.dart`:
  - Agregar `bool isExpenseSide` como parámetro (mandatory).
  - Al final de la Row (después del percent SizedBox(width: 44))
    agregar `SizedBox(width: 8) + _DeltaChip(delta: flow.delta,
    isExpenseSide: isExpenseSide)`.
  - Actualizar el ancho del `SizedBox` del percent si el delta chip
    causa overflow. Alternativa: envolver el chip en `SizedBox(width:
    56)` con `alignment: right`.
  - En el StreamBuilder del sheet, pasar `isExpenseSide: false` para
    los buckets de ingresos y `true` para los de gastos.
  RF: RF-006
  Depende de: T006
  Paralelizable: no
  Criterio de terminado: fila renderea con chip; sin overflow visible
  en pantalla normal.

- [ ] T008 Frontend: extender `_BreakdownSummary` en `cashflow_tab.dart`:
  - Debajo de cada `Text(formatAmount(...))` agregar
    `SizedBox(height: 2) + _DeltaChip(...)`.
  - Chip ingresos: `_DeltaChip(delta: breakdown.deltaIncome,
    isExpenseSide: false)`.
  - Chip gastos: `_DeltaChip(delta: breakdown.deltaExpense,
    isExpenseSide: true)`.
  - Chip neto: `_DeltaChip(delta: breakdown.deltaNet,
    isExpenseSide: false)` (neto sube = mejor, coincide con lado
    ingresos).
  RF: RF-007
  Depende de: T006
  Paralelizable: si (con T007)
  Criterio de terminado: los 3 chips aparecen bajo los montos del
  header.

## Documentación

- [ ] T009 Documentación: en `mobile/lib/screens/help_screen.dart`,
  extender el bullet del cashflow con "El sheet compara cada
  categoría contra el mes anterior con un chip: sube (▲) o baja (▼)
  según si el cambio es mejor o peor para tu bolsillo."
  RF: RF-009
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: texto actualizado en el FAQ.

## Pruebas

- [ ] T010 Pruebas: agregar grupo `cashflowMonthBreakdown —
  comparación vs mes previo` en
  `mobile/test/data/reports_test.dart` con UT-CP01..09 según
  `test-plan.md`. UT-CP08 usa `emitsThrough` con
  `predicate<MonthBreakdown>`. Reusar el fixture del grupo del sprint
  padre (`bolsa`, `debit`, `credit`, `catComida`, `catTransporte`,
  `catSalud`).
  RF: RF-010
  Depende de: T003, T004
  Paralelizable: si (con T011)
  Criterio de terminado: 9 tests verdes.

- [ ] T011 Pruebas: agregar WT-CP01..02 en
  `mobile/test/screens/cashflow_tab_test.dart`. WT-CP01 con 2 meses
  de datos, verifica `find.byIcon(Icons.arrow_upward)` +
  `find.text('+100.0%')` (o el percent que corresponda). WT-CP02
  solo mes actual, verifica `find.text('—')` para el chip null.
  RF: RF-010
  Depende de: T007
  Paralelizable: si (con T010)
  Criterio de terminado: 2 widget tests verdes.

- [ ] T012 Pruebas: correr `flutter analyze` + `flutter test`
  completo. Suite ≥ 571 verdes (560 baseline + 11 nuevos).
  RF: RF-010
  Depende de: T010, T011
  Paralelizable: no
  Criterio de terminado: suite completa verde + analyze limpio.

## Validación de calidad

- [ ] T013 Validación: bump de versión en `mobile/pubspec.yaml`
  (`0.18.0+90`) + `mobile/android/app/build.gradle.kts` (`versionCode
  = 90`, `versionName = "0.18.0"`). Correr `flutter build apk
  --release --split-per-abi` + `scripts/verify-apk.sh`.
  RF: RF-011
  Depende de: T012
  Paralelizable: no
  Criterio de terminado: APK release compilado + `verify-apk.sh` OK
  con versionCode 2090.

- [ ] T014 Validación: **NO INSTALAR NI SMOKE AHORA** — Diego lo hace
  después en batch con los 12 smokes pendientes (documentados en
  memoria `pending-smokes-cashflow-breakdown`). Agregar SM-01..05 de
  este sprint al inventario acumulado.
  RF: —
  Depende de: T013
  Paralelizable: si
  Criterio de terminado: memoria actualizada con los 5 smokes nuevos.

- [ ] T015 Validación: ejecutar `branch-quality-review` con slug
  `flutter-cashflow-breakdown-prev-comparison-v1`. Consolidar
  hallazgos en
  `engineering/quality-review/flutter-cashflow-breakdown-prev-comparison-v1/`.
  Aplicar los bloqueantes antes del commit.
  RF: —
  Depende de: T013
  Paralelizable: no
  Criterio de terminado: reporte generado; hallazgos bloqueantes
  resueltos.

- [ ] T016 Validación: commit final. NO pushear (Diego lo hará en
  batch cuando pueda instalar).
  RF: —
  Depende de: T015
  Paralelizable: no
  Criterio de terminado: `git status` limpio; main + 4 commits ahead
  de origin.

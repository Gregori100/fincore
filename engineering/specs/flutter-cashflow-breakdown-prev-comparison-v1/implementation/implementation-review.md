# Implementation Review: flutter-cashflow-breakdown-prev-comparison-v1

## Resumen de lo implementado

Extensión aditiva del sprint `flutter-cashflow-monthly-breakdown-v1`.
El sheet del cashflow ahora incluye un chip de delta % vs el mes
calendario inmediato anterior en cada `_CategoryFlowRow` y en los 3
totales (Ingresos/Gastos/Neto) del `_BreakdownSummary`. El chip
respeta la semántica "impacto en bolsillo" (verde = mejor para vos,
rojo = peor). Sin data previa → `—` en `textMuted`. Query única
extendida (`strftime IN (?, ?)`) con un solo `customSelect.watch()`.

## Archivos principales modificados

- `mobile/lib/data/reports.dart`:
  - `enum DeltaDirection { up, down, flat }` + `class DeltaPercent`
    const-inmutable.
  - `CategoryFlow` gana `delta` opcional.
  - `MonthBreakdown` gana `deltaIncome`, `deltaExpense`, `deltaNet`
    opcionales.
  - `cashflowMonthBreakdown` extendida: SQL con `IN (?, ?)` +
    `month_key` en SELECT/GROUP BY.
  - `_buildMonthBreakdown` con 4 acumuladores (2 lados × 2 meses) +
    match por `categoryId` (incluye `null` para "Sin categoría").
  - Helper `_computeDelta(current, previous)` con RN-CP03/CP04/CP09.
- `mobile/lib/screens/reports/cashflow_tab.dart`:
  - `_CategoryFlowRow` recibe `isExpenseSide` (mandatory) y agrega
    un `_DeltaChip` al final (ancho fijo 62 px).
  - `_BreakdownSummary` gana 3 `_DeltaChip` debajo de cada monto.
  - Nuevo widget `_DeltaChip` con ícono + percent o `—`.
  - Helper puro `_deltaColor(direction, isExpenseSide)` con matriz
    RN-CP07.
  - Ajustes de spacing en `_CategoryFlowRow`: percent 44→38 px,
    spacing 8→6 y luego 4, para blindar contra overflow con el chip
    de 62 px.
  - `Flexible` en el Text del chip para blindar contra overflow con
    percents largos (ej. `1234.5%` en edge legacy).
- `mobile/lib/screens/help_screen.dart`: bullet del cashflow
  extendido con "cada categoría muestra un chip vs el mes anterior:
  ▲ sube o ▼ baja según si el cambio es mejor o peor para tu
  bolsillo".
- `mobile/pubspec.yaml` + `mobile/android/app/build.gradle.kts`:
  bump a `0.18.0+90`.

Tests:

- `mobile/test/data/reports_test.dart`: grupo nuevo
  `cashflowMonthBreakdown — comparación vs mes previo` con
  UT-CP01..09.
- `mobile/test/screens/cashflow_tab_test.dart`: WT-CP01..02.

## Tareas completadas

- T001 (lectura), T002 (query extendida), T003 (helper con 4
  acumuladores + `_computeDelta`), T004 (modelos), T005
  (`_deltaColor`), T006 (`_DeltaChip`), T007 (`_CategoryFlowRow`
  extendido con `isExpenseSide`), T008 (`_BreakdownSummary` con 3
  chips), T009 (FAQ), T010 (UT-CP01..09), T011 (WT-CP01..02), T012
  (suite verde + analyze limpio), T013 (bump + APK verificado).

## Tareas pendientes

- **T014 (smokes SM-01..05)** — pendiente en cel real; **NO
  INSTALAR AHORA** por decisión de Diego. Batch acumulado con los
  ~12 smokes pendientes de sprints anteriores (memoria
  `pending-smokes-cashflow-breakdown`).
- **T015 (branch-quality-review)** — pendiente.
- **T016 (commit final)** — pendiente.

## Riesgos residuales

- **R2 — Signo del neto que salta**: cubierto con UT-CP09.
  Decisión: si `previo <= 0`, `delta = null` (incluye neto negativo
  del previo). Esto evita el edge "de +100 a -50 = -150%" que
  confundiría al usuario. Alternativa futura: mostrar el neto
  previo/actual en tooltip.
- **R4 — Layout en cel angosto**: mitigado con reducción de widths
  del percent + spacing + `Flexible` en el Text del chip. Los
  widget tests corren en viewport típico (~400px) y pasan. Verificar
  en cel real (SM-01).
- **R6 — Divergencia timezone R6 del sprint padre**: sigue vigente
  para el tab base. Dentro del sheet (actual vs previo) ambos meses
  usan `localtime`, coherente internamente.
- **CB-P02**: movimiento cambiado de fecha entre meses con sheet
  abierto → 2 re-emits del stream (uno por cada watch trigger) →
  estado final correcto. No cubierto por UT pero garantizado por
  `readsFrom: {journalEntries}` estándar.

## Pruebas realizadas

- `flutter analyze` limpio (solo hint info pre-existente).
- `flutter test` **571/571 verdes** (560 baseline + 11 nuevos:
  9 UT-CP servicio + 2 WT-CP widget).
- APK release build OK; `verify-apk.sh` OK con
  `versionCode 2090 / versionName 0.18.0`.

## Pruebas recomendadas

- SM-01..05 con Diego en cel real (batch con los pendientes
  acumulados).
- Especialmente **SM-01** (visual: los chips caben sin overflow en
  la pantalla real con montos típicos), **SM-03** (verificar
  semántica de color en cel — rojo/verde reales), **SM-04**
  (reactividad al registrar en mes previo con sheet abierto).

## Posibles regresiones

- `_CategoryFlowRow` cambia signature: nuevo parámetro requerido
  `isExpenseSide`. Los tests widget del sprint padre (WT-CB01..05)
  no lo usaban explícitamente — verificar que siguen verdes tras
  extender. **Resultado**: verdes (validado en la suite completa).
- El `_BreakdownSummary` gana altura vertical por los 3 chips
  debajo de los montos. El sheet crece ~30-40 px pero sigue
  cabiendo con `SingleChildScrollView`.
- Sin cambios en cashflow base, otros reportes, dashboard, backup,
  forms.

## Recomendaciones para code review humano

1. Verificar la SQL de `cashflowMonthBreakdown`:
   - `strftime IN (?, ?)` con `currentKey` y `previousKey`.
   - `month_key` en SELECT + GROUP BY.
   - `readsFrom` intacto.
2. Verificar el helper `_buildMonthBreakdown`:
   - 4 acumuladores segregados correctamente por `month_key`.
   - Match por `categoryId` con `null` para "Sin categoría".
   - Delta calculado con `_computeDelta` en el flujo del actual
     (no del previo).
   - Cálculo del `deltaNet` sobre magnitudes (RN-CP08).
3. Verificar el helper `_computeDelta`:
   - `previous <= 0` → `null`.
   - `abs(diff) < 0.01` → `flat`.
   - `direction` según signo del `diff`.
4. Verificar la matriz `_deltaColor`:
   - Ingresos: `up→positive`, `down→negative`.
   - Gastos: `up→negative`, `down→positive`.
   - `flat` → `textMuted` en ambos casos.
5. Verificar el layout del `_CategoryFlowRow`: chip 62 px + percent
   38 px + spacing 4+4+4 encaja en el ancho disponible sin
   overflow.

Ejecutar `branch-quality-review` con slug
`flutter-cashflow-breakdown-prev-comparison-v1` antes del commit
final. Reporte en `engineering/quality-review/<slug>/`.

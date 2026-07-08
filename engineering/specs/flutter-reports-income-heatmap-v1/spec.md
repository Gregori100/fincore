# Heatmap anual de ingresos

## Resumen

Nuevo 11º tab en `/reports` llamado "Heatmap ingresos". Simétrico al 10º tab "Heatmap" (gastos, sprint `flutter-reports-spending-heatmap-v1`) pero para `kind='income'` y con paleta verde (`FincoreColors.positive`). Muestra el año completo como grid 3×4 de mini-heatmaps mensuales. Tap en un mini abre el mismo bottom sheet expandido con celdas grandes por día; tap en un día abre `/entries` con filtro custom `from=to=día` + `kinds=['income']`.

Sprint aditivo puro. Sin schema bump, sin dependencia externa, sin cambios en otros tabs.

## Problema a resolver

Hoy `/reports` tiene el heatmap de gastos que responde "¿cuándo gasto más?" a nivel anual. Falta el simétrico para ingresos: "¿cuándo cobré?", "¿los ingresos se agrupan a fin de mes o son irregulares?", "¿el año pasado tuve más días con ingresos que este?".

El reporte de "Ingreso por categoría" (8º tab) responde "¿de dónde vienen los ingresos?" pero no da la vista temporal densa. El calendario (9º tab) muestra el mes pero pierde la perspectiva anual. Este 11º tab completa la simetría analítica: gastos y ingresos con la misma vista año → mes → día.

## Objetivo

Entregar un tab que:

- Renderiza los 12 meses del año en foco como grid 3×4 de mini-heatmaps.
- Cada celda coloreada con 1 de 5 niveles de verde según cuartiles relativos del año (misma escala relativa que el heatmap de gastos).
- Selector de año prev/next con chevrons.
- Tap en un mini abre bottom sheet con el mes agrandado; tap en un día abre `/entries` filtrado a ese día + solo ingresos.
- Es reactivo ante cambios en `journal_entries`.
- Onboarding + FAQ actualizados a "11 reportes / 11 pestañas".

## Alcance

- Nuevo modelo `IncomeHeatmap` en `mobile/lib/data/reports.dart` — estructura idéntica a `SpendingHeatmap` (`Map<DateTime, double> daySpending`... esperar, va como `dayIncome`, pero también podría dejarse el nombre genérico; ver supuesto en Supuestos), `total`, `daysWithIncome`, `p25/p50/p75`, método `intensityFor(day)`.
- Nuevo método `ReportsService.incomeHeatmap({required int year})`:
  ```sql
  SELECT strftime('%Y-%m-%d', occurred_at, 'localtime') AS day,
         SUM(amount) AS total
  FROM journal_entries
  WHERE kind = 'income'
    AND deleted_at IS NULL
    AND occurred_at >= ?
    AND occurred_at <= ?
  GROUP BY day
  ```
  `readsFrom: {journalEntries}`. Post-fetch reusa la lógica de construcción del `SpendingHeatmap` (mismo cálculo de cuartiles con el helper existente `_computeQuartiles`).
- Nuevo archivo `mobile/lib/screens/reports/income_heatmap_tab.dart` con `IncomeHeatmapTab` — copia idiomática de `SpendingHeatmapTab` con:
  - Color base `FincoreColors.positive` en los 5 niveles del gradient.
  - Textos: "Ingreso del mes" (en lugar de "Gasto del mes"), "Sin ingresos registrados en este año" (en el empty banner), "días con ingreso" (en el subtexto de la leyenda).
  - Drill-down con `kinds: ['income']`.
  - Locale del `DateFormat` = `'es_MX'`.
  - Todo el patrón visual del sheet expandido con `_MonthDetailSheet` (afordance de tap con `Icons.open_in_full`, celdas grandes con `_DayCell`, etc.).
- Integración: `mobile/lib/screens/reports_screen.dart` sube de 10 → 11 tabs. Label "Heatmap ingresos" al final.
- Onboarding slide 3: 11ª fila con `Icons.grid_view` + `FincoreColors.positive` + "Heatmap ingresos". Párrafo actualizado a "11 reportes".
- Help FAQ: prefacio "11 pestañas" + bullet nuevo describiendo el heatmap de ingresos.
- Tests: unitarios del servicio + widget tests del tab + ajuste regresión en el test que cuenta tabs (10→11).
- Sin dependencia externa nueva. El widget se implementa reutilizando el pattern con `CustomPaint` del heatmap de gastos.

## Fuera de alcance

- **Refactor común** entre heatmap gastos e ingresos (extraer widget compartido `HeatmapView` genérico). Mismo patrón que `spending_by_category` / `income_by_category` que también conviven duplicados. Registrado como TD.
- **Comparación año vs año** (Diego lo descartó explícitamente en esta sesión).
- **Heatmap combinado gastos+ingresos** (una sola vista con delta neto): fuera de alcance v1.
- **Filtros por cuenta o categoría** dentro del tab: mismo criterio que el heatmap gastos.
- **Toggle de kind** (chip para cambiar entre expense/income sobre el mismo grid): sería el reemplazo natural del refactor común; fuera de alcance.
- **Localización más allá de `es_MX`**: heredado del proyecto.
- **Meses individuales navegables**: el sheet expandido cumple esa función.

## Reglas de negocio

- **RN-IHM01 (kinds contados)**: solo `income`. Excluye `expense`, `credit_expense`, `transfer`, `debt_payment`. Consistente con `incomeByCategory` (8º tab).
- **RN-IHM02 (agrupación por día)**: SQL usa `strftime('%Y-%m-%d', occurred_at, 'localtime')`. Respeta timezone local (patrón del sprint calendar).
- **RN-IHM03 (soft delete)**: `deleted_at IS NULL`. Ingresos cancelados no cuentan.
- **RN-IHM04 (cuartiles sobre días con ingreso)**: p25/p50/p75 se calculan solo sobre los días con `total > 0`. Los días sin ingreso NO se incluyen en el cálculo.
- **RN-IHM05 (fallback con pocos datos)**: si `daysWithIncome < 4`, `p25 = p50 = p75 = 0`. Con eso, todos los días con ingreso caen en `IntensityLevel.veryHigh` (visualmente uniforme). Idéntico al fallback del heatmap gastos.
- **RN-IHM06 (niveles de intensidad)**: función `intensityFor(day)`:
  - `total(day) == 0` (clave ausente) → `IntensityLevel.none`.
  - `0 < total ≤ p25` → `IntensityLevel.low`.
  - `p25 < total ≤ p50` → `IntensityLevel.medium`.
  - `p50 < total ≤ p75` → `IntensityLevel.high`.
  - `total > p75` → `IntensityLevel.veryHigh`.
- **RN-IHM07 (paleta de colores)**:
  - `none`: `FincoreColors.surfaceElevated`.
  - `low`: `FincoreColors.positive` con alpha 0.25.
  - `medium`: alpha 0.45.
  - `high`: alpha 0.7.
  - `veryHigh`: alpha 1.0.
- **RN-IHM08 (rango del año)**: `firstDay = DateTime(year, 1, 1, 0, 0, 0)`, `lastDay = DateTime(year, 12, 31, 23, 59, 59, 999)`.
- **RN-IHM09 (drill-down)**: tap en día del sheet → `EntriesFilters(datePreset: custom, from: día 00:00, to: día 23:59:59.999, kinds: ['income'])`.
- **RN-IHM10 (navegación de año)**: chevrons prev/next en el header.
- **RN-IHM11 (default de apertura)**: `_focusedYear = DateTime.now().year`.
- **RN-IHM12 (reactividad)**: `readsFrom: {journalEntries}` — re-emit ante cualquier cambio en la tabla. La query mantiene el filtro por `kind='income'`, así que cambios en expense/transfer NO afectan el heatmap.
- **RN-IHM13 (días futuros del año en curso)**: días posteriores a hoy se muestran como `none`.
- **RN-IHM14 (leyenda)**: al pie del tab, 5 swatches "Menos" → "Más" + subtexto "Total: $X · Y días con ingreso". Idéntico patrón al heatmap gastos con texto ajustado.
- **RN-IHM15 (año sin ingresos)**: si `daysWithIncome == 0`, el grid se muestra completamente `none` y se oculta la leyenda; se muestra solo el empty banner "Sin ingresos registrados en este año." Idéntico al fix consolidado del heatmap gastos (patch 0.16.3+85).

## Requisitos funcionales

- RF-001: modelo `IncomeHeatmap` en `mobile/lib/data/reports.dart` con `Map<DateTime, double> dayIncome`, `total`, `daysWithIncome`, `p25`, `p50`, `p75` y método `intensityFor(DateTime day) → IntensityLevel`.
- RF-002: reuso del enum `IntensityLevel` existente (5 valores). Sin nuevo enum.
- RF-003: método `ReportsService.incomeHeatmap({required int year})` con SQL como en el Alcance. `readsFrom: {journalEntries}`.
- RF-004: reuso del helper privado `_computeQuartiles` (ya en `reports.dart`). El método `_buildIncomeHeatmap(rows)` es un mirror de `_buildSpendingHeatmap` con nombres ajustados.
- RF-005: nuevo archivo `mobile/lib/screens/reports/income_heatmap_tab.dart` con `IncomeHeatmapTab` (StatefulWidget). Estado + stream cacheado + `_onPrevYear`/`_onNextYear`/`_retryStream`/`_onDayTap`/`_onMonthTap` con el pattern del heatmap gastos.
- RF-006: widget con `Column`: header (chevrons + año) → `_MonthsGrid` (3×4 mini-heatmaps) → leyenda o empty banner (según `daysWithIncome`).
- RF-007: grid con `CustomPaint` responsive (idéntico al del gastos con color positive).
- RF-008: bottom sheet `_MonthDetailSheet` idéntico al del gastos con textos y colores ajustados. Tap en `_DayCell` cierra sheet + navega.
- RF-009: `_LoadingState` + `_ErrorState` con retry funcional (patrón A1).
- RF-010: `mobile/lib/screens/reports_screen.dart` cambia de `length: 10` → `length: 11`. Agrega `Tab(text: 'Heatmap ingresos')` y `IncomeHeatmapTab()` al final.
- RF-011: `mobile/lib/screens/onboarding_screen.dart` slide 3 agrega 11ª fila con `Icons.grid_view` + `FincoreColors.positive` + "Heatmap ingresos". Párrafo pasa de "10 reportes" a "11 reportes".
- RF-012: `mobile/lib/screens/help_screen.dart` prefacio pasa a "11 pestañas" + bullet nuevo describiendo el heatmap ingresos (mismo formato que el bullet del heatmap gastos).
- RF-013: tests unitarios del servicio `incomeHeatmap` cubriendo: año vacío, 1 income (fallback), 4+ incomes (cuartiles calculados), kinds excluidos (expense/transfer/debt_payment NO cuentan), soft delete, día con múltiples ingresos, bordes de año, cruce de años, reactividad con `emitsThrough`.
- RF-014: widget tests del tab: render inicial (año vacío → banner), con 1 income seed → leyenda visible, tap en flecha cambia año, tap en mini abre sheet + tap en día → drill-down con `kinds=['income']` (blindaje).
- RF-015: regresión en `credit_cards_tab_test.dart` (o el archivo con el conteo actual): actualizar `findsNWidgets(10)` a `findsNWidgets(11)`.
- RF-016: `flutter analyze` limpio y `flutter test` verde con al menos 15 tests nuevos (11 UT servicio + 4 widget aprox; ajustar en planeación).

## Casos principales

1. Diego abre `/reports` → tab "Heatmap ingresos" → ve el año actual con celdas verdes en los días donde tuvo ingresos (sueldo, freelance, etc.).
2. Diego tapea un mes (ej: junio) → sheet expandido muestra el mes completo con celdas grandes; el día 5 (sueldo) se ve en verde intenso.
3. Diego tapea el día 5 → `/entries` filtrado a ese día muestra solo ingresos (sueldo) — los gastos del mismo día NO aparecen.
4. Diego navega al año anterior con la flecha izquierda → grid re-carga con los ingresos históricos.
5. Diego registra un nuevo income desde el FAB → vuelve al tab → celda del día correspondiente aparece o intensifica sin refresh.
6. Diego abre el tab en un año sin ingresos → grid vacío + banner "Sin ingresos registrados en este año".

## Casos borde

- Año sin ingresos: `dayIncome` vacío, cuartiles = 0, empty banner visible. RN-IHM15.
- Año con 1-3 ingresos: fallback RN-IHM05, todos veryHigh.
- Ingreso en el borde `firstDayOfYear 00:00:00`: cae en día 1 (blindaje `localtime`).
- Ingreso en el borde `lastDayOfYear 23:59:59.999`: cae en 31/12.
- Año bisiesto: grid acomoda 366 días (mismos meses, algunos con 29 en febrero).
- Ingreso cancelado (soft delete): no cuenta.
- Día con múltiples ingresos (2 sueldos + 1 freelance): 1 entrada en `dayIncome` con `total = SUM`.
- Cambio muy rápido de año: drift cachea, sin race.
- BD con muchos años sin ingresos en algunos: query devuelve `Map` vacío para esos años → empty banner.
- Categorías archivadas: irrelevantes (query no joinea `categories`).
- Cambio de horario / DST: `'localtime'` respeta.
- Tap en celda de spillover del sheet: `heatmapDayForMonthPosition` retorna `null` → `SizedBox.shrink()` sin `InkWell` — ignorado.
- Widget desmontado antes del primer emit: `StreamBuilder.hasData` check estándar.
- Cambio de kind en categoría (income → expense) tras haber ingresos: no afecta al heatmap (query no joinea categories; el kind del entry es fijo desde el registro).

## Criterios de aceptacion

- `flutter test` verde con al menos 15 tests nuevos + suite completa ≥ 534 tests.
- `flutter analyze` sin errores nuevos (4 hints info pre-existentes tolerados).
- APK release compilado con `0.16.4+86` (o el bump que corresponda) y validado con `scripts/verify-apk.sh`.
- Smoke SM-01: 11 tabs visibles en `/reports`; TabBar scrollea sin overflow.
- Smoke SM-02: entrar al tab → mini-heatmaps del año actual con celdas verdes en los días donde Diego registró ingresos reales.
- Smoke SM-03: tapear un mini → sheet expandido con nombre del mes en español + celdas grandes con números.
- Smoke SM-04: tapear un día con ingreso → `/entries` abre filtrado a ese día + solo ingresos (gastos y transfers del mismo día NO deben aparecer).
- Smoke SM-05: cambiar al año anterior con la flecha izquierda → grid recarga.
- Smoke SM-06: registrar un income nuevo desde el FAB → volver al tab → celda del día aparece o intensifica.
- Smoke SM-07: onboarding slide 3 muestra 11 filas legibles; la 11ª es "Heatmap ingresos" en verde.
- Smoke SM-08: FAQ del Help menciona "11 pestañas" + bullet del heatmap ingresos.
- Regresión: los otros 10 tabs de `/reports` siguen funcionando.

## Criterios medibles de exito

- 11º tab visible con label "Heatmap ingresos".
- Delta `día X reporta $Y en heatmap ingresos → drill-down suma exactamente $Y en /entries` en 0 casos observados.
- Reactividad: al registrar un income, la celda del día se colorea en < 1 segundo.
- `flutter test` total ≥ 534 tests verdes.
- APK release build < 1 MB adicional (sin dep externa).
- Onboarding slide 3 acomoda las 11 filas sin overflow.

## Riesgos

- **R1 — Overflow del TabBar con 11 tabs en cel chico**: `isScrollable: true`. Label "Heatmap ingresos" (16 chars) es más largo que "Heatmap" (7 chars). Validar en SM-01.
- **R2 — Renderizado del grid en cel de 360 px**: ya blindado con el diseño 3×4 del heatmap de gastos. Idéntico aquí.
- **R3 — Cálculo de cuartiles con distribuciones raras**: sesgo si Diego tiene 1-2 días de ingresos muy altos (sueldo) vs pocos días con ingresos chicos (regalos, cashback). Aceptable — la escala relativa hace su trabajo.
- **R4 — Onboarding con 11 filas**: el patrón `SingleChildScrollView` acomoda scroll interno. Validar SM-07.
- **R5 — Confusión visual con heatmap de gastos**: los 2 heatmaps son adyacentes en el TabBar (10º y 11º). Mitigado por color (rojo vs verde) y label distinto ("Heatmap" vs "Heatmap ingresos"). Diego se acostumbrará rápido.
- **R6 — Reactividad en años sin datos**: query devuelve `Map` vacío → banner visible. Sin bug esperado.
- **R7 — Duplicación de código con heatmap gastos**: intencional (mismo TD que spending/income by category). Cambios visuales futuros deben aplicarse en ambos archivos.

## Supuestos

- Diego prefiere el mismo layout que el heatmap de gastos (3×4 + sheet expandido). Confirmado en sesión.
- Color base `FincoreColors.positive` (verde) es la elección semántica correcta para "ingresos".
- Label del tab "Heatmap ingresos" es preferible a "Ingresos anual" o "Heatmap ing." (consistencia con "Ingreso por categoría").
- Ícono del onboarding: `Icons.grid_view` con color positive (mismo ícono que heatmap gastos, diferenciado por color). Coherencia visual del par de heatmaps.
- Nombre del campo del modelo: `dayIncome` (no `daySpending` reusado). Aumenta legibilidad del código semántica del modelo aunque introduzca duplicación mínima.
- Bump `0.16.4+86`: patch minor por feature nueva sin dep externa (mismo criterio del heatmap gastos).
- El sprint sigue el pattern de duplicación con reuso mínimo: se reutilizan `_computeQuartiles` y `heatmapDayForMonthPosition` (top-level públicos) + `IntensityLevel` enum. Se duplican el modelo, el widget, el painter y los sub-widgets (`_Legend`, `_EmptyBanner`, `_DayCell`, `_MonthDetailSheet`, etc.) porque cambian textos/colores. Refactor común queda como TD.

## Impacto esperado

- Cierre de la simetría analítica en `/reports`: gastos y ingresos con la misma vista año → mes → día.
- Diego responde "¿cuándo cobré este año?" con un solo tab.
- Feedback visual sobre la regularidad de ingresos (sueldo mensual = 12 celdas verdes; freelance irregular = celdas dispersas).
- Cero fricción con el resto del app: aditivo puro.
- Ligero aumento del APK (< 1 MB) por código nuevo del tab.
- Prepara terreno para un refactor futuro común (`HeatmapView<T>` genérico) si Diego lo pide después.

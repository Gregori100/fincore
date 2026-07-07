# Heatmap anual de gastos

## Resumen

Nuevo 10mo tab en `/reports` llamado "Heatmap". Muestra un año completo de gastos como grilla de 7 filas × ~53 columnas (365 celdas cuadradas, estilo GitHub contributions). La intensidad de color por día refleja el gasto agregado del día, con 5 niveles calculados por cuartiles relativos al propio período. Tap en un día abre `/entries` con filtro pre-cargado (`from = to = día`, `kinds = ['expense', 'credit_expense']`). Selector de año con chevrons prev/next.

Sprint aditivo puro. Sin schema bump, sin dependencia externa, sin cambios en otros tabs.

## Problema a resolver

Los reportes actuales muestran gasto por categoría, cashflow por mes y top movimientos — todos cortes analíticos que responden "en qué se gasta". Ninguno responde bien "cuándo se gasta": ¿los viernes son los peores?, ¿enero fue un mes denso vs julio?, ¿hay semanas de picos vs semanas tranquilas?

El calendario del sprint anterior cubre "qué pasó el día X" a nivel mes. El heatmap agrega la vista anual: identifica patrones estacionales, semanales y bursts de gasto de un vistazo. Es visualmente denso y complementa (no reemplaza) al calendario.

## Objetivo

Entregar un tab que:

- Renderiza los 365 días del año en foco como una grilla compacta y densa (columna = semana, fila = día de la semana).
- Colorea cada celda con 1 de 5 niveles según cuartiles relativos del año.
- Permite navegar prev/next año con chevrons en el header.
- Tap en un día → drill-down a `/entries` con `from = to = día` y `kinds = ['expense', 'credit_expense']`.
- Es reactivo: registrar/cancelar/editar un gasto re-emite el stream y actualiza la celda del día correspondiente.
- Renderiza en cel Android normal (ancho 360-410 px) sin overflow horizontal.

## Alcance

- Nuevo archivo `mobile/lib/screens/reports/spending_heatmap_tab.dart` con `SpendingHeatmapTab`.
- Nuevo modelo `SpendingHeatmap` en `mobile/lib/data/reports.dart` con:
  - `Map<DateTime, double>` día → `total` del día (solo días con gasto > 0).
  - `total` (double) del año.
  - `daysWithSpending` (int) para el subtexto.
  - `p25`, `p50`, `p75` (double) cuartiles precalculados.
  - Método `IntensityLevel intensityFor(DateTime day)` con enum `IntensityLevel { none, low, medium, high, veryHigh }`.
- Nuevo método `ReportsService.spendingHeatmap({required int year})` con SQL agrupando por `strftime('%Y-%m-%d', 'localtime')` para respetar timezone (patrón del sprint anterior).
- Integración en `mobile/lib/screens/reports_screen.dart`: 9 → 10 tabs.
- Onboarding slide 3: 10ª fila.
- Help FAQ: prefacio "10 pestañas" + bullet describiendo el heatmap.
- Reuso de `EntriesFilters` con `datePreset: custom + from + to + kinds` inline (sin nueva factory; el uso es específico del heatmap).
- Tests unitarios del servicio + widget tests del tab + ajuste regresión conteo de tabs 9→10.
- Sin dependencias externas nuevas. El widget se implementa con `CustomPaint` (o `Wrap` + `Container`) para las 365 celdas.

## Fuera de alcance

- **Heatmap de ingresos** (simétrico): sprint futuro. `spendingHeatmap` no se puede reusar directamente; requeriría abstraer.
- **Vista mes/semana/día de la semana** como ejes de patrones: sprint futuro.
- **Comparación año vs año**: sprint futuro.
- **Tooltip on-hover** con monto exacto: aplica a desktop, no a Android touch. En cel, tap → drill-down cumple la función informativa.
- **Long-press o tap-and-hold**: v1 solo usa tap simple.
- **Exportar el heatmap** como imagen: sprint futuro.
- **Filtro por categoría** dentro del tab: v1 muestra todos los gastos agregados. Si Diego lo pide, patch futuro.
- **Filtro por cuenta**: mismo criterio.
- **Localización de meses/días** más allá del `es_MX` ya en el proyecto.
- **Toggle escala relativa vs fija**: v1 es solo relativa (decisión con Diego).

## Reglas de negocio

- **RN-HM01 (kinds contados)**: solo `expense` y `credit_expense`. `income`, `transfer`, `debt_payment` NO cuentan. Consistente con `spendingByCategory` y `cashflowByMonth`.
- **RN-HM02 (agrupación por día)**: SQL usa `strftime('%Y-%m-%d', occurred_at, 'localtime')` (patrón del sprint calendar). Respeta la timezone del dispositivo.
- **RN-HM03 (soft delete)**: `deleted_at IS NULL`. Movimientos cancelados no cuentan.
- **RN-HM04 (cuartiles sobre días con gasto)**: p25/p50/p75 se calculan solo sobre los días con `total > 0`. Los días sin gasto NO se incluyen en el cálculo estadístico (rompería la distribución).
- **RN-HM05 (fallback con pocos datos)**: si `daysWithSpending < 4`, los cuartiles pueden estar mal definidos. Fallback: `p25 = p50 = p75 = max(totals)` para que todos los días con gasto se pinten como `veryHigh`. Aceptable UX cuando el año tiene <4 días con actividad.
- **RN-HM06 (niveles de intensidad)**: función `intensityFor(day)`:
  - `total(day) == 0` (o clave ausente) → `IntensityLevel.none`.
  - `0 < total ≤ p25` → `IntensityLevel.low`.
  - `p25 < total ≤ p50` → `IntensityLevel.medium`.
  - `p50 < total ≤ p75` → `IntensityLevel.high`.
  - `total > p75` → `IntensityLevel.veryHigh`.
- **RN-HM07 (paleta de colores)**:
  - `none`: `FincoreColors.surfaceElevated` (fondo neutro sutil).
  - `low`: `FincoreColors.negative` con alpha 0.25.
  - `medium`: alpha 0.45.
  - `high`: alpha 0.7.
  - `veryHigh`: alpha 1.0.
- **RN-HM08 (rango del año)**: `firstDay = DateTime(year, 1, 1, 0, 0, 0)`, `lastDay = DateTime(year, 12, 31, 23, 59, 59, 999)`. Query WHERE `occurred_at >= from AND occurred_at <= to`.
- **RN-HM09 (drill-down)**: tap en día → `EntriesFilters(datePreset: custom, from = day 00:00, to = day 23:59:59.999, kinds: ['expense', 'credit_expense'])`. Consistente con la semántica del heatmap ("solo gastos").
- **RN-HM10 (navegación de año)**: chevrons prev/next en el header cambian `_focusedYear`. Re-consulta el stream con el nuevo año. Sin límite práctico de rango (el usuario puede navegar a años sin datos y ver todo `none`).
- **RN-HM11 (default de apertura)**: al abrir el tab, `_focusedYear = DateTime.now().year`.
- **RN-HM12 (reactividad)**: `readsFrom: {journalEntries}` — re-emit ante registro/cancelación/edit de cualquier entry en la BD. La query mantiene el filtro de `kind`, así que cambios en income/transfer NO afectan el heatmap.
- **RN-HM13 (días futuros del año en curso)**: si el año en foco es el actual, los días posteriores a hoy se muestran como `none` (sin gasto). Semánticamente correcto y no requiere lógica especial.
- **RN-HM14 (leyenda)**: pie de la pantalla muestra 5 cuadrados de la paleta con labels "Menos" y "Más" en los extremos. Al centro, el subtexto "Total: $X · Y días con gasto" (o similar).
- **RN-HM15 (año sin gastos)**: si `daysWithSpending == 0`, el grid se muestra completamente `none` + banner sutil "Sin gastos registrados en este año".

## Requisitos funcionales

- RF-001: modelo `SpendingHeatmap` en `mobile/lib/data/reports.dart` con `Map<DateTime, double>` día→total, `total`, `daysWithSpending`, `p25`, `p50`, `p75` y método `intensityFor(DateTime day) → IntensityLevel`.
- RF-002: enum `IntensityLevel` con 5 valores (`none`, `low`, `medium`, `high`, `veryHigh`).
- RF-003: método `ReportsService.spendingHeatmap({required int year})` con SQL:
  ```sql
  SELECT strftime('%Y-%m-%d', occurred_at, 'localtime') AS day,
         SUM(amount) AS total
  FROM journal_entries
  WHERE kind IN ('expense', 'credit_expense')
    AND deleted_at IS NULL
    AND occurred_at >= ?
    AND occurred_at <= ?
  GROUP BY day
  ```
  `readsFrom: {journalEntries}`. Post-fetch en Dart: construir `Map<DateTime, double>`, calcular cuartiles vía `_computeQuartiles` sobre valores ordenados.
- RF-004: helper `_computeQuartiles(List<double> sortedValues) → (p25, p50, p75)` con interpolación estándar. Fallback si `sortedValues.length < 4` según RN-HM05.
- RF-005: nuevo archivo `mobile/lib/screens/reports/spending_heatmap_tab.dart` con `SpendingHeatmapTab` StatefulWidget:
  - `int _focusedYear` (init = año actual).
  - `Stream<SpendingHeatmap>? _stream` cacheado (patrón M5 de otros tabs).
  - `_buildStream()` llama `reportsService.spendingHeatmap(year: _focusedYear)`.
  - Método `_onPrevYear` / `_onNextYear` → setState + re-build stream.
  - Método `_onDayTap(DateTime day)` → context.push con EntriesFilters inline.
- RF-006: widget principal: `Column` con (a) header con chevrons prev/next + label "2026" centrado; (b) grid del heatmap; (c) leyenda con 5 cuadrados + subtexto.
- RF-007: grid renderizado con `CustomPaint` (o `LayoutBuilder` + `Wrap` si `CustomPaint` es excesivo). Debe:
  - Calcular el tamaño de celda dinámicamente en base al ancho disponible (viewport - padding).
  - 53 columnas máx (algunas semanas del año). 7 filas (Lun-Dom).
  - Gap horizontal y vertical de 2 px entre celdas.
  - Etiquetas de mes arriba, alineadas a la primera columna del mes (aproximado).
  - Etiquetas de día de semana a la izquierda (Lun/Mié/Vie visibles; Mar/Jue/Sáb/Dom se pueden omitir por espacio).
- RF-008: `onTap` en cada celda dispara `_onDayTap` con el `DateTime` correspondiente al día que representa.
- RF-009: `_LoadingState` estático + `_ErrorState` funcional con `onRetry` callback (patrón A1 del quality review del calendar).
- RF-010: integración: `mobile/lib/screens/reports_screen.dart` sube de 9 a 10 tabs. Label "Heatmap" al final.
- RF-011: `mobile/lib/screens/onboarding_screen.dart` slide 3 agrega 10ª fila con `Icons.grid_view` (o `Icons.calendar_view_month`) + accent color + "Heatmap".
- RF-012: `mobile/lib/screens/help_screen.dart` FAQ tile actualiza el prefacio a "10 pestañas" + bullet nuevo describiendo el heatmap.
- RF-013: tests unitarios del servicio `spendingHeatmap` cubriendo: año vacío, 1 día con gasto (cuartiles fallback), varios días con distintos totales (cuartiles correctos), cancelación reactiva, kinds excluidos (income/transfer/debt_payment NO cuentan), soft delete, cruce de años.
- RF-014: widget tests del tab: render inicial, seed con 1 gasto → celda visible, tap → drill-down.
- RF-015: regresión en `credit_cards_tab_test.dart` (o el archivo con el conteo actual): actualizar `findsNWidgets(9)` a `findsNWidgets(10)`.
- RF-016: `flutter analyze` limpio (0 errores nuevos) y `flutter test` verde con al menos 8 tests nuevos (7 UT servicio + 3 widget test o similar; ajustar en planeación).

## Casos principales

1. Diego abre `/reports` → tab "Heatmap" → ve el año actual con celdas coloreadas donde tuvo gastos.
2. Diego identifica que "los viernes de mayo se ven muy oscuros" → tapea uno para ver los movimientos exactos → `/entries` lo lleva.
3. Diego cambia al año anterior con la flecha izquierda → grid se re-renderiza con los gastos del 2025.
4. Diego registra un gasto nuevo desde el FAB → vuelve al tab → la celda del día correspondiente se colorea (o intensifica) sin refresh manual.
5. Diego abre el tab en un año sin gastos (ej: 2029) → ve el grid completamente vacío + banner "Sin gastos registrados en este año".

## Casos borde

- **Año sin ningún gasto** (`daysWithSpending == 0`): grid `none` + banner. RN-HM15.
- **Año con 1 solo gasto** (`daysWithSpending == 1`): fallback RN-HM05: p25=p50=p75 = ese monto, el día se pinta `veryHigh` (alpha 1.0).
- **Año con 2-3 gastos**: fallback RN-HM05: todos como `veryHigh` (los cuartiles con <4 puntos son inestables).
- **Año con 4+ gastos**: cuartiles calculados normalmente (RN-HM06).
- **Día en el borde (`23:59:59.999`)**: `'localtime'` en strftime lo mantiene en el día correcto (mismo blindaje que sprint calendar).
- **Año bisiesto (366 días)**: la grilla acomoda 1 columna extra. El cálculo del inicio de columna considera el día de la semana del 1 de enero.
- **1 de enero cae en jueves**: la primera columna solo tiene 4 celdas de enero (Jue/Vie/Sáb/Dom); Lun/Mar/Mié de esa columna corresponden a la semana anterior (fuera del año). Renderizar como `none` invisibles (o omitir).
- **DST**: `'localtime'` en strftime respeta el huso horario; los días DST caen en el día calendario esperado.
- **Categoría archivada asociada a un gasto**: irrelevante (query no joinea `categories`).
- **Gasto con `amount = 0`**: legalmente inválido según el DAO pero puede llegar por backup. `SUM(amount)` lo cuenta como 0 → no aparece en el `Map` (día queda como `none`).
- **Cambio muy rápido de año con las flechas**: drift cachea la query si aún no completó; sin race conditions observables.
- **Widget desmontado antes del primer emit**: `StreamBuilder.hasData` check estándar.
- **Datos con muchos años de historia**: la query es por año, sub-10ms con datasets típicos (<3000 gastos/año). Sin impacto de performance.

## Criterios de aceptacion

- `flutter test` verde con al menos 8 tests nuevos (7 UT servicio + 3-4 widget; ajustar en planeación) y suite completa ≥ 500 tests.
- `flutter analyze` sin errores nuevos.
- APK release compilado con `0.16.1+83` (o el bump que corresponda) y validado con `scripts/verify-apk.sh`.
- Smoke SM-01: 10 tabs visibles en `/reports`; el TabBar scrollea sin overflow horizontal.
- Smoke SM-02: navegar al 10mo tab → ver el año actual con celdas coloreadas según los gastos reales de Diego.
- Smoke SM-03: tapear una celda con gasto → `/entries` abre filtrado a ese día + solo gastos (income y transfers del mismo día NO deben aparecer).
- Smoke SM-04: cambiar al año anterior con la flecha izquierda → grid se recarga con los gastos históricos.
- Smoke SM-05: registrar un gasto nuevo desde el FAB → volver al tab → celda del día nuevo aparece o intensifica sin recargar.
- Smoke SM-06: onboarding slide 3 muestra 10 filas sin overflow.
- Smoke SM-07: FAQ del Help menciona "10 pestañas" + bullet del heatmap.
- Regresión: los otros 9 tabs de `/reports` siguen funcionando.

## Criterios medibles de exito

- 10mo tab visible con label "Heatmap".
- Grid renderiza en cel ancho 360 px sin scroll horizontal.
- Delta `día X reporta $Y en el heatmap → drill-down suma exactamente $Y en /entries` en 0 casos observados en la BD real de Diego.
- Reactividad: al registrar un gasto, la celda del día se colorea en < 1 segundo.
- `flutter test` total ≥ 500 tests verdes.
- APK release build < 1 MB adicional (sin dep externa, solo código nuevo).
- Onboarding slide 3 acomoda las 10 filas sin overflow (validar en cel chico).

## Riesgos

- **R1 — Overflow del TabBar con 10 tabs en cel chico**: `isScrollable: true` desde varios sprints. 10 tabs con label "Heatmap" (7 chars, corto) debería estar OK. Validar smoke.
- **R2 — Renderizado del grid en cel de 360 px**: 53 columnas × ~7 px cada + gap = ~470 px. Excede el ancho útil. Mitigación: reducir tamaño de celda a ~5-6 px, o hacer scroll horizontal dentro del grid (menos ideal). Prioridad de planeación: calcular tamaño de celda en base a viewport disponible con `LayoutBuilder`.
- **R3 — Legibilidad de celdas de 5-6 px**: extremos pero funcional para vista de patrón. GitHub usa ~11 px en desktop y ~9 px en móvil; nuestro caso es más apretado.
- **R4 — Cálculo de cuartiles con distribución rara**: sesgo si Diego tiene 1-2 días con gastos muy altos vs muchos con gastos bajos. Los cuartiles absorben esto correctamente, pero el resultado visual puede ser "todo se ve claro salvo 2 días muy oscuros".
- **R5 — Onboarding slide 3 con 10 filas**: desde el sprint budgets el slide usa `SingleChildScrollView + ConstrainedBox + IntrinsicHeight`, así que la 10ª fila debería entrar. Validar smoke.
- **R6 — Reactividad con muchos años de historia**: la query se acota al año en foco, sub-10ms.
- **R7 — Etiquetas de mes desalineadas**: en meses cortos (28 días) o largos (31), la primera columna del mes puede no caer perfectamente. Aceptable "aproximación visual"; no requiere pixel-perfect.
- **R8 — Confusión con el calendario**: el 9no tab (calendario) y el 10mo (heatmap) muestran distinto detalle. Mitigar con FAQ del Help que aclara "el calendario detalla el mes por tipo de movimiento; el heatmap muestra el año por intensidad de gasto".
- **R9 — Interpretación de escala relativa**: 2 usuarios distintos podrían tener escalas incomparables. Aceptable: la app es single-user; la escala relativa es óptima para autoanálisis del propio dueño de la BD.

## Supuestos

- Diego prefiere heatmap del año completo estilo GitHub sobre alternativas mensuales o trimestrales.
- La escala relativa por cuartiles es más útil que umbrales fijos (Diego lo confirmó via AskUserQuestion).
- Solo gastos (`expense` + `credit_expense`) cuentan; income/transfers/pagos no.
- El drill-down reusa `/entries?filter=...` con `datePreset: custom` inline, sin nueva factory.
- El widget custom con `CustomPaint` o `Wrap`/`Container` es viable sin dependencia externa.
- El selector de año es solo chevrons prev/next (patrón de otros tabs con selector temporal).
- Etiquetas de mes se muestran todas 12 arriba del grid; si el ancho no alcanza, `TextOverflow.clip` deja las que quepan.
- Días futuros del año actual se muestran como `none` (sin marker especial de "hoy"; el foco es el pasado).
- El bump de versión es minor (`0.16.1+83`) por feature nueva sin dep externa.

## Impacto esperado

- Nueva vista analítica que responde "cuándo se gasta" a nivel anual.
- Complementa el calendario (mes detallado) con perspectiva macro (año completo).
- Detecta patrones estacionales y semanales que las vistas por categoría no capturan.
- Cero fricción con el resto del app: aditivo puro.
- Sin dependencia externa → cero riesgo de romper el build.
- Ligero aumento del APK (< 1 MB) por código nuevo.
- Prepara terreno conceptual para features futuras: heatmap de ingresos simétrico, patrones por día-de-semana, comparación año vs año.

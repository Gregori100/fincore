# Resumen extenso — flutter-reports-spending-heatmap-v1

## Contexto tomado de spec.md, preguntas.md y clarificaciones

`spec.md` define el sprint como el 10mo tab en `/reports` con vista año completo estilo GitHub contributions. Sin `preguntas.md` ni `clarificaciones.md`: las 3 decisiones críticas se cerraron con Diego antes de spec-definir (vía AskUserQuestion) — alcance temporal (año completo), kinds contados (`expense` + `credit_expense`), escala (cuartiles relativos).

15 reglas de negocio (RN-HM01..HM15) cubriendo agregación por día, cuartiles, colores, drill-down, reactividad, fallback con pocos datos, empty state.

## Relación con plan/plan.md y plan/tasks.md

Orden de tasks seguido tal cual (T001..T020):

1. **T001** (referencia): reuso del patrón de `movements_calendar_tab.dart` (State + Stream cache + `_LoadingState`/`_ErrorState`).
2. **T002-T003** (modelo + helper): `SpendingHeatmap` + `IntensityLevel` + `_computeQuartiles` con fallback. **Cambio semántico durante implementación**: fallback originalmente `(max, max, max)` en el plan, corregido a `(0, 0, 0)` para cumplir con RN-HM05 (todos los días con gasto en `veryHigh`). Ver `desviaciones-plan.md` D1.
3. **T004** (servicio): `spendingHeatmap({year})` con SQL usando `strftime('%Y-%m-%d', 'localtime')` (timezone-safe, patrón del sprint anterior).
4. **T005-T007+T011** (widget): `SpendingHeatmapTab` con header + grid (`CustomPaint` + `LayoutBuilder`) + leyenda + empty banner. Hit-testing manual por coordenadas.
5. **T008** (integración): 10mo tab.
6. **T009-T010** (docs UI): onboarding + FAQ.
7. **T012-T014** (tests): 20 nuevos.
8. **T015** (regresión): WT-15 conteo 9 → 10.
9. **T016** (validación suite): 512/512 verdes.
10. **T017** (bump + APK): 0.16.1+83 verificado.
11. **T018-T020**: pendientes (smokes + quality review + commit).

## Cambios principales por módulo o capa

### Capa de datos

**`mobile/lib/data/reports.dart`**:

- Enum `IntensityLevel` con 5 valores (`none`, `low`, `medium`, `high`, `veryHigh`).
- Modelo `SpendingHeatmap` inmutable con `Map<DateTime, double> daySpending`, `total`, `daysWithSpending`, `p25`, `p50`, `p75`. Método `intensityFor(day)` según RN-HM06 (clave ausente / total 0 → `none`).
- Helper privado `_computeQuartiles(sortedValues) → (p25, p50, p75)`:
  - Vacío → `(0, 0, 0)`.
  - `< 4` valores → `(0, 0, 0)` (fallback RN-HM05, cambio durante implementación).
  - `≥ 4` → interpolación estándar lineal (formula rank = (n-1) * p).
- Método `ReportsService.spendingHeatmap({required int year})`:
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
  - Rango: `DateTime(year, 1, 1)` a `DateTime(year, 12, 31, 23, 59, 59, 999)`.
  - `readsFrom: {journalEntries}` para reactividad.
  - Helper interno `_buildSpendingHeatmap` construye el modelo post-fetch.
  - Filtra días con `dayTotal <= 0` (edge legacy con `amount=0`).

### Capa UI

**`mobile/lib/screens/reports/spending_heatmap_tab.dart`** (nuevo, ~450 líneas):

- `SpendingHeatmapTab` StatefulWidget:
  - `int _focusedYear` init = año actual.
  - `Stream<SpendingHeatmap>? _stream` cacheado.
  - `_onPrevYear` / `_onNextYear` cambian año + recrean stream.
  - `_retryStream` para el `onRetry` del `_ErrorState`.
  - `_onDayTap(day)`: verifica `day.year == _focusedYear` (spillover ignorado, RN-HM09), construye `EntriesFilters(datePreset: custom, from, to, kinds: ['expense', 'credit_expense'])` inline y hace `context.push`.
- `_YearHeader`: chevrons con tooltips + año centrado.
- `_HeatmapGrid`: `LayoutBuilder` calcula `cellSize = (availableWidth - labelColumnWidth - gapsTotal) / 53`. `GestureDetector.onTapDown` con hit-testing por coordenadas (`column = (dx - labelsWidth) / (cellSize + gap)`, `row = (dy - monthRowHeight) / (cellSize + gap)`) → `_dayForPosition(column, row, year)` (function libre).
- `_HeatmapPainter extends CustomPainter`:
  - Recibe `SpendingHeatmap`, `cellSize`, `gap`, `labelColumnWidth`, `monthRowHeight`.
  - Pinta etiquetas de mes arriba (`DateFormat('MMM', 'es_MX')`).
  - Pinta etiquetas de día de semana a la izquierda (solo Lun/Mié/Vie).
  - Pinta las celdas: para cada día del año, calcula `(column, row)` y pinta un `RRect` con el color según `heatmap.intensityFor(day)`.
  - `shouldRepaint`: compara year, heatmap, cellSize.
- `_Legend`: 5 swatches horizontales + labels "Menos"/"Más" + subtexto centrado con total y días con gasto.
- `_EmptyBanner`: `Icons.info_outline` + texto "Sin gastos registrados en este año.".
- `_LoadingState` + `_ErrorState` con retry (patrón A1 del quality review del calendar).
- Import `dart:ui as ui` para `TextDirection.ltr` en `TextPainter` (conflicto con `flutter/material.dart`).

**`mobile/lib/screens/reports_screen.dart`**: `length: 9 → 10` + `Tab(text: 'Heatmap')` + `SpendingHeatmapTab()`.

**`mobile/lib/screens/onboarding_screen.dart`**: párrafo "10 reportes" + 10ª fila con `Icons.grid_view + FincoreColors.negative + 'Heatmap anual'`.

**`mobile/lib/screens/help_screen.dart`**: "10 pestañas" + bullet describiendo el heatmap con la aclaración vs calendario.

### Version bump

- `pubspec.yaml`: `0.16.0+82 → 0.16.1+83` (patch minor por feature nueva sin dep externa).
- `build.gradle.kts`: `versionCode = 83`, `versionName = "0.16.1"`.

### Tests

- **`reports_test.dart`**: grupo `spendingHeatmap (sprint spending-heatmap)` con UT-HM01..11 (BD vacía, fallback con 1-3 gastos, cuartiles con 4+ gastos, `credit_expense` cuenta, otros kinds NO cuentan, soft delete, día con múltiples gastos, borde `23:59:59.999`, otros años NO cuentan, reactividad con `emitsThrough`).
- **`reports_test.dart`**: grupo `SpendingHeatmap.intensityFor (unit tests del modelo)` con UT-HM12..16 (día ausente, total 0 defensivo, los 4 niveles no-none, fallback con cuartiles 0).
- **`spending_heatmap_tab_test.dart`** (nuevo): WT-HM01 (render + leyenda), WT-HM02 (con datos, verifica subtexto "1 día con gasto"), WT-HM03 (cambio de año con flecha), WT-HM04 (año sin gastos → banner).
- **`credit_cards_tab_test.dart`**: WT-15 conteo 9 → 10.

## Desviaciones respecto al plan

Ver `desviaciones-plan.md` para detalle. Resumen:

- **D1** — Fallback de `_computeQuartiles` cambió de `(max, max, max)` (plan original) a `(0, 0, 0)` (implementación). Razón: cumplir RN-HM05 ("todos los días con gasto se ven como `veryHigh`"). Con `(max, max, max)` todos caían en `low` porque `value ≤ p25=max` es siempre true. Con `(0, 0, 0)` cualquier valor > 0 cae en `veryHigh`.
- **D2** — Import `dart:ui as ui` requerido para `TextDirection.ltr` en `TextPainter` (conflicto de nombres con `flutter/material.dart`).
- **D3** — UT-HM03 usa named record `(day: 5, amount: 100.0)` en vez de `.indexed` tuple destructuring (más claro y evita shadowing del parámetro `amount`).

Sin desviaciones bloqueantes.

## Pruebas realizadas y recomendadas

**Realizadas**:

- `flutter analyze` limpio.
- `flutter test` → **512/512 verdes** (492 baseline + 20 nuevos).
- Build APK release + verify-apk.sh OK (versionCode 2083 / versionName 0.16.1).

**Recomendadas**:

- SM-01..07 en cel real por Diego (visibilidad, rendering en 360 px, drill-down con solo gastos, año prev/next, reactividad, onboarding, FAQ).
- `branch-quality-review` con slug `flutter-reports-spending-heatmap-v1`.

## Riesgos residuales y posibles regresiones

- **R2 (rendering en cel 360 px)**: no medido; validar SM-02.
- **R3 (hit-testing manual)**: fragilidad conocida del `CustomPaint` con tap. Cubierto lógicamente por RN-HM09 (spillover ignorado); validar SM-03.
- **R7 (onboarding 10 filas)**: patrón acomoda scroll. Validar SM-06.
- **R8 (confusión calendar vs heatmap)**: FAQ mitiga.
- **R11 (días futuros)**: se ven `none`, intencional.
- **Regresión en calendar** (sprint anterior): cero cambios; sigue funcionando.
- **Regresión en otros 8 tabs**: cero cambios.

# Resumen extenso — flutter-reports-income-heatmap-v1

## Contexto tomado de spec.md, preguntas.md y clarificaciones

`spec.md` define el sprint como el 11º tab en `/reports` simétrico al heatmap de gastos (10º) pero para `kind='income'` con paleta verde. Sin `preguntas.md` — las 3 decisiones críticas (alcance año completo, kinds solo income, cuartiles relativos) fueron heredadas del heatmap gastos y confirmadas antes de spec-definir. Las 2 decisiones UX menores (label del tab, ícono del onboarding) se resolvieron como supuestos razonables.

15 reglas de negocio (RN-IHM01..IHM15) simétricas a las del heatmap gastos.

## Relación con plan/plan.md y plan/tasks.md

Orden de tasks seguido tal cual (T001..T020):

1. **T001** (referencia): duplicación literal de `spending_heatmap_tab.dart` vía `cp` + reemplazos globales de nombres/colores/textos.
2. **T002-T003** (modelo + helper): `IncomeHeatmap` con `dayIncome` (nombre semántico distinto a `daySpending`) + `_buildIncomeHeatmap` mirror.
3. **T004** (servicio): `incomeHeatmap({year})` con SQL `kind = 'income'` singular (no IN).
4. **T005-T008 + T011** (widget + integración): reutilización del layout completo del gastos con cambios de color/texto/kind.
5. **T009-T010** (docs): onboarding + FAQ.
6. **T012-T014** (tests): 21 nuevos.
7. **T015** (regresión): WT-15 conteo 10 → 11.
8. **T016** (validación suite): 540/540 verdes.
9. **T017** (bump + APK): 0.16.4+86 verificado.
10. **T018-T020**: pendientes (smokes + quality review + commit).

## Cambios principales por módulo o capa

### Capa de datos

**`mobile/lib/data/reports.dart`**:

- Modelo `IncomeHeatmap` inmutable con `Map<DateTime, double> dayIncome`, `total`, `daysWithIncome`, `p25/p50/p75`. Método `intensityFor(day)` idéntico al de `SpendingHeatmap` (misma lógica de niveles).
- Método `ReportsService.incomeHeatmap({required int year})`:
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
  - Rango: `DateTime(year, 1, 1)` a `DateTime(year, 12, 31, 23, 59, 59, 999)`.
  - `readsFrom: {journalEntries}` para reactividad.
  - Helper `_buildIncomeHeatmap` mirror de `_buildSpendingHeatmap`.
- Reuso del enum `IntensityLevel` y del helper privado `_computeQuartiles` (ambos ya en el archivo).

### Capa UI

**`mobile/lib/screens/reports/income_heatmap_tab.dart`** (nuevo, ~770 líneas):

- Copia literal de `spending_heatmap_tab.dart` con reemplazos:
  - `SpendingHeatmapTab` → `IncomeHeatmapTab`.
  - `SpendingHeatmap` → `IncomeHeatmap`.
  - `spendingHeatmap` → `incomeHeatmap`.
  - `daysWithSpending` → `daysWithIncome`.
  - `daySpending` → `dayIncome`.
  - `FincoreColors.negative` → `FincoreColors.positive` en el painter y celdas (`_ErrorState.Icon` restaurado a `negative` por semántica de error).
  - `kinds: ['expense', 'credit_expense']` → `kinds: ['income']`.
  - Textos "gasto"/"Gasto" → "ingreso"/"Ingreso".
  - Docstring actualizado con referencia al sprint income y RN-IHM01/09.
- Import cruzado: `import 'package:fincore/screens/reports/spending_heatmap_tab.dart' show heatmapDayForMonthPosition;` — evita duplicar el top-level público (chocaría con el del spending si ambos existieran).
- La versión local del `_colorForIntensity` (privado al archivo) usa `positive` en lugar de `negative`.

**`mobile/lib/screens/reports_screen.dart`**: `length: 10 → 11` + `Tab(text: 'Heatmap ingresos')` + `IncomeHeatmapTab()`.

**`mobile/lib/screens/onboarding_screen.dart`**: párrafo "11 reportes" + 11ª fila con `Icons.grid_view + FincoreColors.positive + 'Heatmap ingresos'`.

**`mobile/lib/screens/help_screen.dart`**: "11 pestañas" + bullet nuevo con simetría explícita.

### Version bump

- `pubspec.yaml`: `0.16.3+85 → 0.16.4+86` (patch minor por feature aditiva sin dep externa).
- `build.gradle.kts`: `versionCode = 86`, `versionName = "0.16.4"`.

### Tests

- **`reports_test.dart`**: grupo `incomeHeatmap (sprint income-heatmap)` con UT-IHM01..12 (año vacío, fallback con 1 income, 4 incomes con cuartiles, `expense`/`credit_expense`/`transfer`/`debt_payment` NO cuentan, soft delete, día con 3 incomes, borde `23:59:59.999`, otros años NO cuentan, reactividad con `emitsThrough`).
- **`reports_test.dart`**: grupo `IncomeHeatmap.intensityFor (unit tests del modelo)` con UT-IHM13..17.
- **`income_heatmap_tab_test.dart`** (nuevo): WT-IHM01 (año vacío → banner), WT-IHM02 (con datos → leyenda), WT-IHM03 (cambio de año), WT-IHM04 (drill-down blindando `kinds=['income']` con seed de income + expense el mismo día).
- **`credit_cards_tab_test.dart`**: WT-15 conteo 10 → 11.

## Desviaciones respecto al plan

- **D1** — Import cruzado `income_heatmap_tab.dart → spending_heatmap_tab.dart`: no estaba en el plan explícito, pero fue necesario para reusar `heatmapDayForMonthPosition` (top-level público). La alternativa habría sido duplicar la función con dos nombres distintos (feo) o extraer un archivo común (fuera de alcance como TD). Aceptable v1.
- **D2** — Restauración del color del `_ErrorState.Icon` a `negative`: el reemplazo global `FincoreColors.negative → FincoreColors.positive` afectó también al ícono `Icons.error_outline` del error state, que semánticamente debe ser rojo (indicador de error). Restaurado manualmente durante implementación.

Sin desviaciones bloqueantes.

## Pruebas realizadas y recomendadas

**Realizadas**:

- `flutter analyze` limpio.
- `flutter test` → **540/540 verdes** (baseline 519 + 21 nuevos).
- Build APK release + verify-apk.sh OK (versionCode 2086 / versionName 0.16.4).

**Recomendadas**:

- SM-01..08 en cel real por Diego (visibilidad, rendering, drill-down validando solo ingresos, año prev/next, reactividad, onboarding, FAQ).
- `branch-quality-review` con slug `flutter-reports-income-heatmap-v1`.

## Riesgos residuales y posibles regresiones

- **R1 (label largo)**: `TabBar isScrollable` acomoda; validar SM-01.
- **R2 (confusión heatmap gastos vs ingresos)**: mitigado por color; FAQ aclara.
- **R3 (duplicación)**: TD intencional. Cambios visuales futuros aplicar en 2 archivos.
- **R4 (acoplamiento income → spending)**: TD futuro si se refactoriza a archivo común.
- **Regresión en heatmap gastos**: cero. Solo comparte helper top-level público (`heatmapDayForMonthPosition`) e `IntensityLevel` enum, sin cambios.
- **Regresión en otros 9 tabs**: cero cambios.
- **Timezone**: query timezone-safe con `'localtime'`, mismo blindaje que sprints previos.

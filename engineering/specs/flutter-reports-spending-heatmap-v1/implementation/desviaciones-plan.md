# Desviaciones respecto al plan

## D1 — Fallback de `_computeQuartiles` cambió de `(max, max, max)` a `(0, 0, 0)`

- **Plan original**: `sortedValues.length < 4 → (max, max, max)`. Intención declarada: "todos los días con gasto se pintan como `veryHigh`" (RN-HM05).
- **Realidad**: con `p25=p50=p75=max`, cualquier valor `v ≤ max` (es decir, todos) satisface la primera condición `v ≤ p25` y cae en `IntensityLevel.low`. Contradicción semántica: la spec dice "veryHigh" pero el código pintaría "low".
- **Solución**: cambiar el fallback a `(0, 0, 0)`. Con cuartiles=0, cualquier valor > 0 salta las 3 primeras condiciones (`v ≤ 0` falso) y cae en `IntensityLevel.veryHigh`. Cumple RN-HM05 literalmente.
- **Impacto**: cero funcional respecto a la intención. Los tests UT-HM02, UT-HM03, UT-HM16 se ajustaron a esperar cuartiles=0 en el fallback y `veryHigh` como resultado.

## D2 — UT-HM03 usa named record en lugar de `.indexed` tuple

- **Plan original**: no especificaba forma de iteración; asumía tuple genérico.
- **Realidad**: el patrón `for (final (i, amount) in [(5, 100.0), ...].indexed)` shadoweaba el parámetro `amount` del `registerExpense` (destructuring del `(int, (int, double))` tuple del `.indexed`). Compilación falla.
- **Solución**: usar named record `const [(day: 5, amount: 100.0), ...]` con acceso por nombre (`entry.day`, `entry.amount`). Más legible y sin shadowing.
- **Impacto**: cero funcional. Estilo idiomático mejorado.

## D3 — Rediseño del layout post-smoke: 12 mini-heatmaps mensuales en grid 3×4

- **Plan original**: grid año completo estilo GitHub Contributions (7 filas × ~53 columnas). Riesgo R2 declarado: "grid en cel de 360 px con celdas de ~5-6 px".
- **Realidad post-smoke** (Diego probó el APK y reportó "muy pequeño"): las celdas de ~5 px son legibles para "vista de patrón" pero no permiten distinguir días individuales ni tapearlos con precisión.
- **Solución**: rediseño a **12 mini-heatmaps mensuales** en `Wrap` con 3 columnas × 4 filas.
  - Cada mini es 7 columnas (Lun-Dom) × 6 filas (semanas del mes).
  - Celdas de ~12 px en cel de 360 px (vs ~5 px del original).
  - Título del mes centrado sobre cada mini (`Ene`, `Feb`, ...).
  - Hit-testing localizado por mini (más simple que hit-testing global).
  - Preserva la vista "año completo de un vistazo" al mostrar los 12 meses juntos.
- **Impacto**:
  - **Modelo, servicio y cuartiles NO cambiaron**: sigue siendo `SpendingHeatmap` con la misma agregación diaria; el rediseño es puramente visual.
  - **Tests intactos**: los WT-HM01..04 verifican `SpendingHeatmapTab`, subtexto de la leyenda y año del header — todo se preserva. UT-HM01..16 no fueron tocados.
  - **Widget rewrite**: `_HeatmapGrid` + `_HeatmapPainter` reemplazados por `_MonthsGrid` + 12 × `_MonthMini` + `_MonthMiniPainter`. La función libre `_dayForPosition` (year+column+row → DateTime) fue reemplazada por `_dayForMonthPosition` (year+month+column+row → DateTime).
  - **Documentación local del widget**: docstring de `SpendingHeatmapTab` actualizado explicando el rediseño post-smoke.
  - **Sin cambios en la spec/plan/RN**: la funcionalidad es la misma (heatmap anual de gastos con cuartiles relativos), solo el layout visual difiere.

Sin desviaciones bloqueantes.

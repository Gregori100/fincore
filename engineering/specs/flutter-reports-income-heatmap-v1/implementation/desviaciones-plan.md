# Desviaciones respecto al plan

## D1 — Import cruzado income → spending para reusar `heatmapDayForMonthPosition`

- **Plan original**: mencionaba "reuso del helper top-level `heatmapDayForMonthPosition`" sin especificar cómo.
- **Realidad**: al copiar literalmente `spending_heatmap_tab.dart` como base, el archivo `income_heatmap_tab.dart` quedaba con su propia copia del top-level `heatmapDayForMonthPosition` — conflicto de compilación garantizado (dos top-level públicos con el mismo nombre en la misma app).
- **Solución**: eliminar la copia en `income_heatmap_tab.dart` y agregar `import 'package:fincore/screens/reports/spending_heatmap_tab.dart' show heatmapDayForMonthPosition;`. Introduce acoplamiento aceptable (solo una función pura utility).
- **Impacto**: cero funcional. Documentado como TD (refactor futuro a archivo común `lib/screens/reports/_heatmap_common.dart` si Diego lo pide).

## D2 — Restauración del color del `_ErrorState.Icon` a `negative`

- **Plan original**: cambio genérico de paleta `negative → positive` para el heatmap ingresos.
- **Realidad**: el reemplazo global `FincoreColors.negative → FincoreColors.positive` afectó también al `Icons.error_outline` del `_ErrorState`, que semánticamente debe ser rojo (indicador visual de error, no de "ingreso").
- **Solución**: restaurar `color: FincoreColors.negative` en el ícono del `_ErrorState`.
- **Impacto**: cero funcional. Consistencia visual con otros `_ErrorState` de la app.

Sin desviaciones bloqueantes.

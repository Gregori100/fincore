# Implementation Review: flutter-reports-spending-heatmap-v1

## Resumen de lo implementado

Nuevo 10mo tab "Heatmap" en `/reports` con vista año completo estilo GitHub contributions. Grid de 7 filas × ~53 columnas con intensidad de color por día calculada por cuartiles relativos al año (kinds contados: `expense` + `credit_expense`). Selector de año con chevrons prev/next. Tap en día → drill-down a `/entries` con filtro custom + `kinds=['expense','credit_expense']`. Sprint aditivo puro. Sin schema bump, sin dependencia externa.

## Archivos principales modificados

- `mobile/lib/data/reports.dart` — nuevo modelo `SpendingHeatmap` + enum `IntensityLevel` + método `ReportsService.spendingHeatmap({year})` + helper privado `_computeQuartiles` + helper `_buildSpendingHeatmap`.
- `mobile/lib/screens/reports/spending_heatmap_tab.dart` (nuevo, ~450 líneas) — widget del tab con `CustomPaint` + `LayoutBuilder` responsive + hit-testing manual + `_ErrorState` con retry funcional (patrón A1 del quality review del calendar) + leyenda + empty banner.
- `mobile/lib/screens/reports_screen.dart` — 9 → 10 tabs.
- `mobile/lib/screens/onboarding_screen.dart` — 10ª fila slide 3 con `Icons.grid_view` + `FincoreColors.negative` + label "Heatmap anual". Párrafo actualizado a "10 reportes".
- `mobile/lib/screens/help_screen.dart` — FAQ "10 pestañas" + bullet nuevo aclarando la diferencia entre calendario y heatmap.
- `mobile/pubspec.yaml` + `mobile/android/app/build.gradle.kts` — bump `0.16.1+83`.

Tests nuevos:

- `mobile/test/data/reports_test.dart` — grupo `spendingHeatmap (sprint spending-heatmap)` con UT-HM01..11 + grupo `SpendingHeatmap.intensityFor (unit tests del modelo)` con UT-HM12..16.
- `mobile/test/screens/reports/spending_heatmap_tab_test.dart` (nuevo) — WT-HM01..04.

Ajuste de regresión:

- `mobile/test/screens/reports/credit_cards_tab_test.dart` — WT-15 conteo `findsNWidgets(9) → findsNWidgets(10)`.

## Tareas completadas

- **T001** (referencia): patrón del `movements_calendar_tab.dart` reusado (State + Stream cache + `_LoadingState`/`_ErrorState` con retry).
- **T002-T003** (modelo + helper): `SpendingHeatmap`, `IntensityLevel`, `_computeQuartiles` con fallback RN-HM05.
- **T004** (servicio): `spendingHeatmap({year})` con SQL usando `strftime('%Y-%m-%d', 'localtime')` (timezone-safe, patrón del sprint calendar). `readsFrom: {journalEntries}`.
- **T005-T007** (widget base + grid + tap): `SpendingHeatmapTab` con estado, `_HeatmapGrid` + `_HeatmapPainter` (`CustomPainter`), `GestureDetector.onTapDown` con hit-testing por coordenadas.
- **T008** (integración): 10mo tab en `ReportsScreen`.
- **T009-T010** (docs UI): onboarding + FAQ.
- **T011** (leyenda): 5 swatches + labels + subtexto total + empty banner cuando `daysWithSpending == 0`.
- **T012-T014** (tests): 20 nuevos verdes tras 2 iteraciones (fix del fallback de cuartiles + fix de destructuración de tuple en UT-HM03).
- **T015** (regresión): WT-15 actualizado a 10 tabs.
- **T016** (suite): 512/512 verdes.
- **T017** (bump + APK): 0.16.1+83 verificado con versionCode 2083.

## Tareas pendientes

- **T018** (smokes SM-01..07 con Diego): pendiente en cel real.
- **T019** (`branch-quality-review`): pendiente antes del commit final.
- **T020** (commit final): pendiente.

## Riesgos residuales

- **R2 (grid en cel 360 px)**: sin medir directamente en test; validar SM-02.
- **R3 (hit-testing manual)**: cubierto lógicamente por RN-HM09 (spillover ignorado); validar SM-03 (tap → drill-down navega al día correcto).
- **R7 (onboarding con 10 filas)**: patrón `SingleChildScrollView` acomoda scroll interno; validar SM-06.
- **R8 (confusión calendario vs heatmap)**: mitigado con bullet del FAQ que aclara la diferencia.
- **R11 (días futuros del año en curso)**: comportamiento intencional (se ven como `none`).

## Pruebas realizadas

- `flutter analyze` limpio (4 hints info pre-existentes tolerados).
- `flutter test test/data/reports_test.dart --plain-name 'spending-heatmap'` → 11/11 verdes.
- `flutter test test/data/reports_test.dart --plain-name 'intensityFor'` → 5/5 verdes.
- `flutter test test/screens/reports/spending_heatmap_tab_test.dart` → 4/4 verdes.
- `flutter test` completo → **512/512 verdes** (492 baseline + 20 nuevos).
- Build APK release `--split-per-abi` OK.
- `verify-apk.sh` OK con versionCode 2083 / versionName 0.16.1.

## Pruebas recomendadas

- **SM-01..07** en cel real por Diego. Especialmente:
  - SM-02 (rendering del grid en cel de 360 px).
  - SM-03 (tap en día con gasto → `/entries` con solo `expense` + `credit_expense`).
  - SM-05 (reactividad al registrar gasto nuevo).
  - SM-08 opcional (cel chico).

## Posibles regresiones

- **Otros 9 tabs de `/reports`**: intactos. Tests widget existentes verdes.
- **`/entries`**: cero cambios. El drill-down reusa el parser existente `EntriesFilters.parse`.
- **Dashboard**: cero cambios.
- **Onboarding**: 10ª fila cabe en el `SingleChildScrollView` del slide 3. Tests existentes no verifican conteo.
- **Help**: bullet nuevo. Tests existentes no verifican texto completo.
- **`movementsByDay`** (sprint calendar): cero cambios; sigue funcionando.

## Recomendaciones para code review humano

1. Revisar que `_computeQuartiles` con `n<4` retorna `(0, 0, 0)` (no `(max, max, max)` como decía el plan inicial). Cambio semántico durante implementación: garantiza que todos los días con gasto caen en `veryHigh` (visualmente uniforme), que era la intención declarada en RN-HM05. Documentado en `desviaciones-plan.md` D1.
2. Confirmar que el SQL usa `'localtime'` en `strftime` (mismo blindaje que sprint calendar).
3. Revisar el `_HeatmapPainter` — hit-testing manual por coordenadas es la parte más frágil. Cubierto por RN-HM09 (spillover ignorado); validar SM-03 en smoke.
4. Ejecutar `branch-quality-review` con slug `flutter-reports-spending-heatmap-v1` antes del commit final.

Referencia al reporte de quality review (cuando exista): `engineering/quality-review/flutter-reports-spending-heatmap-v1/`.

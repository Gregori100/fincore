# Implementation Review: flutter-reports-income-heatmap-v1

## Resumen de lo implementado

11º tab "Heatmap ingresos" en `/reports`. Simétrico al 10º tab "Heatmap" (gastos) pero para `kind='income'` con paleta verde (`FincoreColors.positive`). Grid 3×4 de mini-heatmaps mensuales + bottom sheet expandido al tapear un mes. Sprint aditivo puro. Sin schema bump. Sin dep externa. Reusa `heatmapDayForMonthPosition` importándolo de `spending_heatmap_tab.dart` (evita conflicto de top-level público duplicado).

## Archivos principales modificados

- `mobile/lib/data/reports.dart` — nuevo modelo `IncomeHeatmap` + método `ReportsService.incomeHeatmap({year})` + helper `_buildIncomeHeatmap`. Reusa `_computeQuartiles` (privado ya existente) y enum `IntensityLevel`.
- `mobile/lib/screens/reports/income_heatmap_tab.dart` (nuevo, ~770 líneas) — widget del tab. Copia idiomática de `spending_heatmap_tab.dart` con:
  - Modelo `IncomeHeatmap` en lugar de `SpendingHeatmap`.
  - Método `reportsService.incomeHeatmap(...)`.
  - `FincoreColors.positive` en `_colorForIntensity` (salvo el ícono de `_ErrorState` que sigue en `negative`).
  - Textos "Ingreso del mes", "Sin ingresos registrados en este año", "días con ingreso".
  - Drill-down con `kinds: ['income']`.
  - Import de `heatmapDayForMonthPosition` desde `spending_heatmap_tab.dart`.
- `mobile/lib/screens/reports_screen.dart` — 10 → 11 tabs; label "Heatmap ingresos" al final.
- `mobile/lib/screens/onboarding_screen.dart` — 11ª fila slide 3 con `Icons.grid_view + FincoreColors.positive + "Heatmap ingresos"`. Párrafo actualizado a "11 reportes".
- `mobile/lib/screens/help_screen.dart` — FAQ "11 pestañas" + bullet nuevo describiendo la simetría con el heatmap gastos.
- `mobile/pubspec.yaml` + `mobile/android/app/build.gradle.kts` — bump `0.16.4+86`.

Tests nuevos:

- `mobile/test/data/reports_test.dart` — grupo `incomeHeatmap (sprint income-heatmap)` con UT-IHM01..12 + grupo `IncomeHeatmap.intensityFor (unit tests del modelo)` con UT-IHM13..17.
- `mobile/test/screens/reports/income_heatmap_tab_test.dart` (nuevo) — WT-IHM01..04.

Ajuste de regresión:

- `mobile/test/screens/reports/credit_cards_tab_test.dart` — WT-15 conteo `findsNWidgets(10) → findsNWidgets(11)`.

## Tareas completadas

- **T001** (referencia): patrón del `spending_heatmap_tab.dart` reusado literalmente vía `cp` + reemplazos.
- **T002-T003** (modelo + helper): `IncomeHeatmap` + `_buildIncomeHeatmap` mirror.
- **T004** (servicio): `incomeHeatmap({year})` con SQL `kind = 'income'` + `readsFrom: {journalEntries}` + `strftime('%Y-%m-%d', 'localtime')`.
- **T005-T008 + T011** (widget + integración): tab completo con estado + stream + sheet + leyenda + banner. 11º tab en `ReportsScreen`.
- **T009-T010** (docs): onboarding + FAQ.
- **T012-T014** (tests): 21 nuevos verdes.
- **T015** (regresión): WT-15 actualizado.
- **T016** (suite): 540/540 verdes.
- **T017** (bump + APK): 0.16.4+86 verificado con versionCode 2086.

## Tareas pendientes

- **T018** (smokes SM-01..08 con Diego): pendiente en cel real.
- **T019** (`branch-quality-review`): pendiente antes del commit final.
- **T020** (commit final): pendiente.

## Riesgos residuales

- **R1 (label largo "Heatmap ingresos" 16 chars vs "Heatmap" 7 chars)**: `TabBar isScrollable: true` acomoda; validar en SM-01.
- **R2 (confusión visual entre heatmap gastos y ingresos)**: mitigado por color (rojo vs verde) + label distinto. Adyacentes en el TabBar.
- **R3 (duplicación de código con heatmap gastos)**: intencional. TD conocido (mismo patrón que spending/income by category).
- **R4 (import cruzado income → spending)**: introduce acoplamiento `income_heatmap_tab.dart` depende de `spending_heatmap_tab.dart` (solo por `heatmapDayForMonthPosition`). Si en el futuro se refactoriza a un archivo común (`lib/screens/reports/_heatmap_common.dart`), este acoplamiento desaparece. Aceptable v1.

## Pruebas realizadas

- `flutter analyze` limpio (4 hints info pre-existentes tolerados).
- `flutter test test/data/reports_test.dart --plain-name 'income-heatmap'` → 12/12 verdes.
- `flutter test test/data/reports_test.dart --plain-name 'IncomeHeatmap.intensityFor'` → 5/5 verdes.
- `flutter test test/screens/reports/income_heatmap_tab_test.dart` → 4/4 verdes.
- `flutter test` completo → **540/540 verdes** (519 baseline + 21 nuevos).
- Build APK release + `verify-apk.sh` OK con versionCode 2086 / versionName 0.16.4.

## Pruebas recomendadas

- **SM-01..08** en cel real por Diego. Especialmente:
  - SM-01 (11 tabs sin overflow en cel chico).
  - SM-04 (drill-down con solo ingresos, expenses del mismo día NO aparecen).
  - SM-06 (reactividad al registrar income nuevo).

## Posibles regresiones

- **Otros 10 tabs de `/reports`**: intactos. Tests widget existentes verdes.
- **`/entries`**: cero cambios; el drill-down usa el parser existente `EntriesFilters.parse`.
- **Dashboard**: cero cambios.
- **Heatmap gastos (10º tab)**: sigue funcionando; solo comparte `heatmapDayForMonthPosition` (top-level público) e `IntensityLevel` (enum). Ningún cambio en su código.
- **Onboarding**: 11ª fila cabe en el `SingleChildScrollView`. Tests existentes no cuentan filas.
- **Help**: bullet nuevo. Tests existentes no verifican texto completo.

## Recomendaciones para code review humano

1. Revisar que `_ErrorState.Icon` mantiene `FincoreColors.negative` (rojo semántico de error) y no fue barrida al `positive` por el reemplazo masivo `negative → positive`. Verificado y corregido durante implementación.
2. Confirmar que el import cruzado `import '.../spending_heatmap_tab.dart' show heatmapDayForMonthPosition` es aceptable como TD documentado. Alternativa futura: extraer helper a un archivo común.
3. Revisar textos: "Ingreso del mes", "Sin ingresos registrados", "días con ingreso" — coherentes con el registro del resto del app.
4. Verificar que el drill-down `kinds: ['income']` está aislado del filter del heatmap gastos (`kinds: ['expense', 'credit_expense']`). Cubierto por WT-IHM04.
5. Ejecutar `branch-quality-review` con slug `flutter-reports-income-heatmap-v1` antes del commit final.

Referencia al reporte de quality review (cuando exista): `engineering/quality-review/flutter-reports-income-heatmap-v1/`.

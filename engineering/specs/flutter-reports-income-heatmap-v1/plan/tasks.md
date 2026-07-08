# Tareas — flutter-reports-income-heatmap-v1

## Backend

- [ ] T001 Backend: leer `mobile/lib/screens/reports/spending_heatmap_tab.dart` completo como referencia estructural del sprint. Confirmar reuso de `heatmapDayForMonthPosition` (top-level público) e `IntensityLevel` (enum) para no duplicar. Registrar la decisión de duplicación de sub-widgets en `implementation/decisiones-implementacion.md` si difiere del plan.
  RF: —
  Depende de: ninguna
  Paralelizable: no
  Criterio de terminado: patrón identificado.

- [ ] T002 Backend: agregar el modelo `IncomeHeatmap` en `mobile/lib/data/reports.dart` (cerca de `SpendingHeatmap`). Constructor const con `Map<DateTime, double> dayIncome`, `total`, `daysWithIncome`, `p25`, `p50`, `p75`. Método `IntensityLevel intensityFor(DateTime day)` según RN-IHM06 (clave ausente / total 0 → `none`). Docstring documenta relación con RN-IHM01..HM07 y la simetría con `SpendingHeatmap`.
  RF: RF-001, RF-002
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: clase definida + `flutter analyze` limpio.

- [ ] T003 Backend: agregar el helper `_buildIncomeHeatmap(List<QueryRow> rows)` en `reports.dart` (mirror de `_buildSpendingHeatmap`). Reusa `_computeQuartiles` privado ya existente. Filtra `dayTotal <= 0` para casos de `amount=0` legacy.
  RF: RF-004
  Depende de: T002
  Paralelizable: si
  Criterio de terminado: helper presente + `flutter analyze` limpio.

- [ ] T004 Backend: agregar el método `ReportsService.incomeHeatmap({required int year})` en `reports.dart`. SQL:
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
  Rango: `DateTime(year, 1, 1)` a `DateTime(year, 12, 31, 23, 59, 59, 999)`. `readsFrom: {journalEntries}`. Documentar RN-IHM01/HM02/HM03/HM08/HM12.
  RF: RF-003
  Depende de: T003
  Paralelizable: no
  Criterio de terminado: método presente + docstring completo + `flutter analyze` limpio.

## Frontend

- [ ] T005 Frontend: crear `mobile/lib/screens/reports/income_heatmap_tab.dart` con `IncomeHeatmapTab` (StatefulWidget). Estado base copiado de `SpendingHeatmapTab`:
  - `int _focusedYear` init = `DateTime.now().year`.
  - `Stream<IncomeHeatmap>? _stream` cacheado en `didChangeDependencies`.
  - `_buildStream()` llama `reportsService.incomeHeatmap(year: _focusedYear)`.
  - `_onPrevYear` / `_onNextYear` / `_retryStream` / `_lastHeatmap` (patrón A2 heredado).
  - `_onDayTap(day)`: `EntriesFilters(datePreset: custom, from: día 00:00, to: día 23:59:59.999, kinds: const ['income'])` inline + `context.push`.
  - `_onMonthTap(month)`: abre `showModalBottomSheet` con `_MonthDetailSheet` (renombrado para no chocar con el del gastos, quedará local al archivo income).
  - Widget principal: `Column` con `_YearHeader` + `_MonthsGrid` + leyenda condicional (heredado del patch consolidación) + `_EmptyBanner` cuando `daysWithIncome == 0`.
  RF: RF-005, RF-006, RF-009
  Depende de: T004
  Paralelizable: no
  Criterio de terminado: widget monta sin excepciones + `flutter analyze` limpio.

- [ ] T006 Frontend: implementar `_MonthsGrid` + `_MonthMini` + `_MonthMiniPainter` dentro de `income_heatmap_tab.dart`. Idéntico al del gastos con dos cambios:
  - `_colorForIntensity` (privado al archivo income) usa `FincoreColors.positive` en lugar de `FincoreColors.negative`.
  - `_MonthLabel` mantiene el `Icons.open_in_full` heredado del patch 0.16.3+85.
  Reusa `heatmapDayForMonthPosition` importándolo desde `spending_heatmap_tab.dart`.
  RF: RF-006, RF-007
  Depende de: T005
  Paralelizable: no
  Criterio de terminado: grid renderiza en desktop y en cel de 360 px sin overflow.

- [ ] T007 Frontend: implementar `_MonthDetailSheet` + `_DayCell` + `_WeekdayHeader` en `income_heatmap_tab.dart`. Idéntico al del gastos con cambios de textos:
  - "Ingreso del mes" en el subtexto al pie del sheet.
  - `_DayCell` con `_colorForIntensity` positive.
  - `SingleChildScrollView` envuelto (heredado del A1 del gastos).
  RF: RF-008
  Depende de: T005
  Paralelizable: no
  Criterio de terminado: sheet renderiza + tap en día ejecuta drill-down.

- [ ] T008 Frontend: integrar `IncomeHeatmapTab` en `mobile/lib/screens/reports_screen.dart`. Cambiar `length: 10` → `length: 11`. Agregar `Tab(text: 'Heatmap ingresos')` al final del `TabBar` y `IncomeHeatmapTab()` al final del `TabBarView`.
  RF: RF-010
  Depende de: T005
  Paralelizable: si (con T009, T010)
  Criterio de terminado: `/reports` muestra 11 tabs; el 11º monta el nuevo widget.

- [ ] T011 Frontend: agregar leyenda + empty banner con textos ajustados:
  - Leyenda: subtexto "Total: $X · Y días con ingreso" (singular/plural).
  - Empty banner: "Sin ingresos registrados en este año."
  - Consolidación: si `daysWithIncome == 0`, se oculta leyenda y se muestra solo banner (heredado del patch 0.16.3+85 del gastos).
  RF: RF-006 (leyenda parte del layout)
  Depende de: T005
  Paralelizable: si (con T006, T007)
  Criterio de terminado: leyenda + banner renderiza correctamente en ambos estados.

## Documentación

- [ ] T009 Documentación: agregar 11ª fila al slide 3 del `mobile/lib/screens/onboarding_screen.dart` con `Icons.grid_view` + `FincoreColors.positive` + label "Heatmap ingresos". Actualizar el párrafo del slide de "10 reportes" a "11 reportes" con descripción breve del heatmap ingresos.
  RF: RF-011
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: onboarding slide 3 renderiza 11 filas sin overflow.

- [ ] T010 Documentación: actualizar `mobile/lib/screens/help_screen.dart` — prefijo del tile de reportes de "10 pestañas" a "11 pestañas" + bullet nuevo describiendo el heatmap ingresos. Aclarar simetría con el heatmap gastos ("ambos usan intensidad de color por día; el de gastos en rojo, el de ingresos en verde").
  RF: RF-012
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: FAQ menciona 11 pestañas + bullet visible.

## Pruebas

- [ ] T012 Pruebas: agregar grupo `incomeHeatmap (sprint income-heatmap)` en `mobile/test/data/reports_test.dart` con UT-IHM01..12 según `test-plan.md`. UT-IHM12 (reactividad) usa `emitsThrough`, NO `Future.delayed`.
  RF: RF-013
  Depende de: T004
  Paralelizable: si (con T013, T014)
  Criterio de terminado: 12 tests verdes.

- [ ] T013 Pruebas: agregar grupo `IncomeHeatmap.intensityFor (unit tests del modelo)` en `mobile/test/data/reports_test.dart` con UT-IHM13..17. Tests puros (sin BD).
  RF: RF-013
  Depende de: T002
  Paralelizable: si (con T012, T014)
  Criterio de terminado: 5 tests verdes.

- [ ] T014 Pruebas: crear `mobile/test/screens/reports/income_heatmap_tab_test.dart` con WT-IHM01..04 según `test-plan.md`. WT-IHM04 valida drill-down con `kinds=['income']` sembrando 1 income + 1 expense el mismo día + verificando que solo income aparece en `/entries`.
  RF: RF-014
  Depende de: T005, T007
  Paralelizable: si (con T012, T013)
  Criterio de terminado: 4 widget tests verdes.

- [ ] T015 Pruebas: ajustar `mobile/test/screens/reports/credit_cards_tab_test.dart` (WT-15) cambiando `findsNWidgets(10)` a `findsNWidgets(11)`.
  RF: RF-015
  Depende de: T008
  Paralelizable: si (con T012, T013, T014)
  Criterio de terminado: WT-15 pasa con el nuevo conteo.

- [ ] T016 Pruebas: correr `flutter analyze` (0 errores nuevos) + `flutter test` completo. Suite ≥ 534 verdes (519 baseline + ~17 nuevos; ajustar según distribución final).
  RF: RF-016
  Depende de: T012, T013, T014, T015
  Paralelizable: no
  Criterio de terminado: suite completa verde + analyze limpio.

## Validación de calidad

- [ ] T017 Validación: bump de versión en `mobile/pubspec.yaml` (`0.16.4+86`) + `mobile/android/app/build.gradle.kts` (`versionCode = 86`, `versionName = "0.16.4"`). Correr `flutter build apk --release --split-per-abi` + `scripts/verify-apk.sh`.
  RF: —
  Depende de: T016
  Paralelizable: no
  Criterio de terminado: APK release compilado + `verify-apk.sh` OK con versionCode 2086.

- [ ] T018 Validación: smoke manual con Diego en cel real. Ejecutar SM-01..08 del `test-plan.md`. Documentar hallazgos en `implementation/pendientes.md` si aparecen; corregir antes del commit si son bloqueantes.
  RF: —
  Depende de: T017
  Paralelizable: no
  Criterio de terminado: Diego confirma los 8 smokes.

- [ ] T019 Validación: ejecutar la skill `branch-quality-review` con slug `flutter-reports-income-heatmap-v1`. Consolidar hallazgos en `engineering/quality-review/flutter-reports-income-heatmap-v1/`. Aplicar los bloqueantes antes del commit.
  RF: —
  Depende de: T018
  Paralelizable: no
  Criterio de terminado: reporte generado; hallazgos bloqueantes resueltos.

- [ ] T020 Validación: commit final con mensaje que resuma el sprint. NO pushear (Diego lo hace manualmente).
  RF: —
  Depende de: T019
  Paralelizable: no
  Criterio de terminado: `git status` limpio; working tree sin cambios pendientes.

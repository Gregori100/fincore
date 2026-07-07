# Tareas — flutter-reports-spending-heatmap-v1

## Backend

- [ ] T001 Backend: leer `mobile/lib/screens/reports/movements_calendar_tab.dart` como referencia estructural del sprint anterior (patrón State + Stream + `_LoadingState`/`_ErrorState` con retry funcional, patrón A1 del quality review previo). Confirmar los patrones a reusar.
  RF: —
  Depende de: ninguna
  Paralelizable: no
  Criterio de terminado: patrones identificados; decisión sobre reuso registrada en `implementation/decisiones-implementacion.md` si difiere del plan.

- [ ] T002 Backend: agregar el enum `IntensityLevel` (`none`, `low`, `medium`, `high`, `veryHigh`) + modelo `SpendingHeatmap` en `mobile/lib/data/reports.dart` (cerca de los otros modelos del servicio). Constructor const con `Map<DateTime, double> daySpending`, `total`, `daysWithSpending`, `p25`, `p50`, `p75`. Método `IntensityLevel intensityFor(DateTime day)` según RN-HM06 (clave ausente / total 0 → `none`). Documentar en el docstring la relación con RN-HM01..HM07.
  RF: RF-001, RF-002
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: clase definida + `flutter analyze` limpio.

- [ ] T003 Backend: agregar el helper privado `_computeQuartiles(List<double> sortedValues) → (double p25, double p50, double p75)` en `reports.dart`. Interpolación estándar (linear). Fallback RN-HM05: si `sortedValues.length < 4`, retornar `(max, max, max)`. Función pura.
  RF: RF-004
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: helper presente + `flutter analyze` limpio.

- [ ] T004 Backend: agregar el método `ReportsService.spendingHeatmap({required int year})` en `reports.dart`. SQL:
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
  Rango: `DateTime(year, 1, 1)` a `DateTime(year, 12, 31, 23, 59, 59, 999)`. `readsFrom: {journalEntries}`. Post-fetch en Dart: parsear el `Map`, calcular cuartiles con `_computeQuartiles`, construir `SpendingHeatmap`. Documentar en docstring RN-HM01/HM02/HM03/HM08/HM12.
  RF: RF-003
  Depende de: T002, T003
  Paralelizable: no
  Criterio de terminado: método presente + docstring completo + `flutter analyze` limpio.

## Frontend

- [ ] T005 Frontend: crear `mobile/lib/screens/reports/spending_heatmap_tab.dart` con `SpendingHeatmapTab` (StatefulWidget). Estado base:
  - `int _focusedYear` init = `DateTime.now().year`.
  - `Stream<SpendingHeatmap>? _stream` cacheado en `didChangeDependencies`.
  - `_buildStream()` llama `reportsService.spendingHeatmap(year: _focusedYear)`.
  - `_onPrevYear` / `_onNextYear` cambian `_focusedYear` + `setState + _stream = _buildStream()`.
  - `_retryStream()` para el `onRetry` del `_ErrorState` (patrón A1 del quality review del calendar).
  - Layout base: `Column` con header (chevrons + año centrado) + placeholder para el grid + `_LoadingState` + `_ErrorState`.
  RF: RF-005, RF-009
  Depende de: T004
  Paralelizable: no
  Criterio de terminado: widget monta sin excepciones + `flutter analyze` limpio.

- [ ] T006 Frontend: implementar el grid del heatmap dentro de `SpendingHeatmapTab`. Usar `LayoutBuilder` para calcular `cellSize` en base a `constraints.maxWidth - labelsWidth - gapsTotal`. Fijar 53 columnas + 7 filas. Dibujar con `_HeatmapPainter extends CustomPainter` que recibe `SpendingHeatmap` + `cellSize` + `gap` + `firstDayOfYearWeekday`. Cada celda pintada con el color del `IntensityLevel` según `heatmap.intensityFor(day)`. Etiquetas de mes arriba (`DateFormat('MMM', 'es_MX')`), etiquetas de día de semana a la izquierda (Lun/Mié/Vie visibles).
  RF: RF-006, RF-007
  Depende de: T005
  Paralelizable: no
  Criterio de terminado: grid renderiza en desktop (viewport 400+ px) y en móvil (360 px) sin overflow horizontal.

- [ ] T007 Frontend: `GestureDetector` alrededor del `CustomPaint`. `onTapDown` con hit-testing por coordenadas: `column = dx / (cellSize + gap)`, `row = dy / (cellSize + gap)`. Derivar el `DateTime` con `_dayForPosition(column, row)`. Si `day.year != _focusedYear` (spillover), ignorar el tap. Sino, `_onDayTap(day)` construye `EntriesFilters(datePreset: custom, from: day 00:00, to: day 23:59:59.999, kinds: ['expense', 'credit_expense'])` y hace `context.push(filter.toDeepLink())`.
  RF: RF-008, RN-HM09
  Depende de: T006
  Paralelizable: no
  Criterio de terminado: tap en día con gasto navega correctamente; tap en spillover ignorado.

- [ ] T008 Frontend: integrar `SpendingHeatmapTab` en `mobile/lib/screens/reports_screen.dart`. Cambiar `length: 9` → `length: 10`. Agregar `Tab(text: 'Heatmap')` al final del `TabBar` y `SpendingHeatmapTab()` al final del `TabBarView`. Actualizar doc-comment.
  RF: RF-010
  Depende de: T005
  Paralelizable: si (con T009, T010, T011)
  Criterio de terminado: `/reports` muestra 10 tabs; el 10mo monta el nuevo widget.

- [ ] T011 Frontend: implementar la leyenda al pie del tab. `Row` con 5 cuadraditos (16x16) de los colores `IntensityLevel.low..veryHigh` + labels "Menos" y "Más" en los extremos. Subtexto centrado: "Total: $X · Y días con gasto" (formateado con `formatAmount`). Cuando `heatmap.daysWithSpending == 0`, mostrar banner sutil "Sin gastos registrados en este año" (RN-HM15).
  RF: RF-006 (leyenda parte del layout)
  Depende de: T005
  Paralelizable: si (con T006, T007)
  Criterio de terminado: leyenda renderiza + banner visible en año vacío.

## Documentación

- [ ] T009 Documentación: agregar 10ª fila al slide 3 del `mobile/lib/screens/onboarding_screen.dart` con `Icons.grid_view` (o `Icons.calendar_view_month`) + `FincoreColors.accent` + label "Heatmap". Actualizar el párrafo del slide de "9 reportes" a "10 reportes" con descripción breve del heatmap.
  RF: RF-011
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: onboarding slide 3 renderiza 10 filas sin overflow (validar en cel chico).

- [ ] T010 Documentación: actualizar `mobile/lib/screens/help_screen.dart` — prefijo del tile de reportes de "9 pestañas" a "10 pestañas" + bullet nuevo describiendo el heatmap. Aclarar la diferencia con el calendario ("el calendario detalla el mes por tipo de movimiento; el heatmap muestra el año por intensidad de gasto") para mitigar R8.
  RF: RF-012
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: FAQ menciona 10 pestañas + bullet visible.

## Pruebas

- [ ] T012 Pruebas: agregar grupo `spendingHeatmap (sprint spending-heatmap)` en `mobile/test/data/reports_test.dart` con UT-HM01..11 según `test-plan.md`. UT-HM11 (reactividad) usa `emitsThrough`, NO `Future.delayed`.
  RF: RF-013
  Depende de: T004
  Paralelizable: si (con T013, T014)
  Criterio de terminado: 11 tests verdes.

- [ ] T013 Pruebas: agregar grupo `SpendingHeatmap.intensityFor (unit tests del modelo)` en `mobile/test/data/reports_test.dart` con UT-HM12..16 según `test-plan.md`. Tests puros (sin BD).
  RF: RF-013
  Depende de: T002
  Paralelizable: si (con T012, T014)
  Criterio de terminado: 5 tests verdes.

- [ ] T014 Pruebas: crear `mobile/test/screens/reports/spending_heatmap_tab_test.dart` con WT-HM01..04 según `test-plan.md`. Usar `pumpFincoreApp` del harness. `find.byWidgetPredicate((w) => w is CustomPaint)` para verificar el grid. WT-HM04 verifica drill-down por presencia del `find.text('DescripciónSembrada')` en `/entries`.
  RF: RF-014
  Depende de: T005, T007
  Paralelizable: si (con T012, T013)
  Criterio de terminado: 4 widget tests verdes.

- [ ] T015 Pruebas: ajustar `mobile/test/screens/reports/credit_cards_tab_test.dart` (WT-15) cambiando `findsNWidgets(9)` a `findsNWidgets(10)` en el test que verifica el conteo de tabs.
  RF: RF-015
  Depende de: T008
  Paralelizable: si (con T012, T013, T014)
  Criterio de terminado: WT-15 pasa con el nuevo conteo.

- [ ] T016 Pruebas: correr `flutter analyze` (0 errores nuevos) + `flutter test` completo. Confirmar suite ≥ 512 tests verdes (492 baseline + 20 nuevos aprox; ajustar según distribución final).
  RF: RF-016
  Depende de: T012, T013, T014, T015
  Paralelizable: no
  Criterio de terminado: suite completa verde + analyze limpio.

## Validación de calidad

- [ ] T017 Validación: bump de versión en `mobile/pubspec.yaml` (`0.16.1+83`) + `mobile/android/app/build.gradle.kts` (`versionCode = 83`, `versionName = "0.16.1"`). Correr `flutter build apk --release --split-per-abi` + `scripts/verify-apk.sh`.
  RF: —
  Depende de: T016
  Paralelizable: no
  Criterio de terminado: APK release compilado + `verify-apk.sh` OK con versionCode 2083.

- [ ] T018 Validación: smoke manual con Diego en cel real. Ejecutar SM-01..07 (y SM-08 opcional en cel chico si aplica). Documentar hallazgos en `implementation/pendientes.md` si aparecen; corregir antes del commit si son bloqueantes.
  RF: —
  Depende de: T017
  Paralelizable: no
  Criterio de terminado: Diego confirma los 7 smokes obligatorios.

- [ ] T019 Validación: ejecutar la skill `branch-quality-review` con slug `flutter-reports-spending-heatmap-v1`. Consolidar hallazgos en `engineering/quality-review/flutter-reports-spending-heatmap-v1/`. Aplicar los bloqueantes antes del commit.
  RF: —
  Depende de: T018
  Paralelizable: no
  Criterio de terminado: reporte generado; hallazgos bloqueantes resueltos.

- [ ] T020 Validación: commit final con mensaje que resuma el sprint (ver ejemplos de commits recientes del proyecto). NO pushear (Diego lo hace manualmente cuando confirma).
  RF: —
  Depende de: T019
  Paralelizable: no
  Criterio de terminado: `git status` limpio; working tree sin cambios pendientes.

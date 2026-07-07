# Tareas — flutter-reports-movements-calendar-v1

## Backend

- [ ] T001 Backend: agregar `table_calendar` con versión exacta al `mobile/pubspec.yaml`. Antes de fijar, revisar el changelog reciente y confirmar compatibilidad con Flutter 3.29 / Dart ≥3.7.2. Correr `flutter pub get`. Si aparece warning de deprecación crítico, escalar como desviación en `implementation/desviaciones-plan.md` y evaluar downgrade o alternativa custom.
  RF: RF-010
  Depende de: ninguna
  Paralelizable: no
  Criterio de terminado: `flutter pub get` OK + `flutter analyze` sin nuevos warnings de la dep.

- [ ] T002 Backend: agregar el modelo `DayActivity` en `mobile/lib/data/reports.dart` (cerca de los otros modelos del servicio). Constructor con 3 bools (`hasIncome`, `hasSpending`, `hasInternal`) + `totalCount`. Helper `hasAny` para el `markerBuilder`. Getter `dominantColor` opcional si aporta claridad; sino omitir.
  RF: RF-001
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: clase definida + `flutter analyze` limpio.

- [ ] T003 Backend: agregar el método `ReportsService.movementsByDay({required DateTime monthAnchor})` en `mobile/lib/data/reports.dart`. SQL:
  ```sql
  SELECT date(occurred_at) AS day, kind, COUNT(*) AS count
  FROM journal_entries
  WHERE deleted_at IS NULL AND occurred_at >= ? AND occurred_at <= ?
  GROUP BY day, kind
  ```
  Rango: `firstDayOfMonth(monthAnchor) 00:00:00` a `lastDayOfMonth(monthAnchor) 23:59:59.999`. `readsFrom: {journalEntries}` para reactividad. Construir `Map<DateTime, DayActivity>` en Dart post-fetch. Documentar en el docstring las 3 categorías de kind (RN-CAL01) y que los soft-deleted quedan fuera (RN-CAL02).
  RF: RF-001, RF-002
  Depende de: T002
  Paralelizable: no
  Criterio de terminado: método presente + docstring completo + `flutter analyze` limpio.

- [ ] T004 Backend: agregar el factory `EntriesFilters.forDay({required DateTime day})` en `mobile/lib/data/entries_filters.dart`. Setea `datePreset: custom`, `from = DateTime(y, m, d, 0, 0, 0)`, `to = DateTime(y, m, d, 23, 59, 59, 999)`. Sin restricciones adicionales. Documentar con referencia al sprint.
  RF: RF-006
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: factory presente + `flutter analyze` limpio.

## Frontend

- [ ] T005 Frontend: crear `mobile/lib/screens/reports/movements_calendar_tab.dart` con `MovementsCalendarTab` (StatefulWidget). Contenido:
  - `_focusedMonth` (init = primer día del mes actual) + `_selectedDay` (init = hoy si cae en el mes, sino null).
  - `Stream<Map<DateTime, DayActivity>>` recreado al cambiar `_focusedMonth`.
  - `StreamBuilder` con 4 estados (loading, error, data, empty).
  - `TableCalendar` con `locale: 'es_MX'`, `firstDay` = un año antes, `lastDay` = un año después, `focusedDay: _focusedMonth`, `selectedDayPredicate` con `_selectedDay`.
  - `calendarBuilders.markerBuilder`: hasta 3 puntos de 5 px (verde/rojo/azul) en `Row` alineados al fondo.
  - `onDaySelected: (selected, focused) => setState + context.push(EntriesFilters.forDay(day: selected).toDeepLink())`.
  - `onPageChanged: (focused) => setState(_focusedMonth = firstDayOf(focused))`.
  - `_LoadingState` estático (patrón M5 del quality review v1 de reports).
  - `_ErrorState` con retry.
  RF: RF-003, RF-004, RF-005, RF-006
  Depende de: T003, T004
  Paralelizable: no
  Criterio de terminado: widget monta sin excepciones + `flutter analyze` limpio.

- [ ] T006 Frontend: integrar `MovementsCalendarTab` en `mobile/lib/screens/reports_screen.dart`. Cambiar `length: 8` → `length: 9`. Agregar `Tab(text: 'Calendario')` al final del `TabBar` y `MovementsCalendarTab()` al final del `TabBarView`. Actualizar doc-comment del archivo con el nuevo conteo.
  RF: RF-007
  Depende de: T005
  Paralelizable: no
  Criterio de terminado: `/reports` muestra 9 tabs; el 9no monta el nuevo widget.

## Documentación

- [ ] T007 Documentación: agregar 9ª fila al slide 3 del `mobile/lib/screens/onboarding_screen.dart` con `Icons.calendar_month` (o `Icons.event`) en color neutral y label "Calendario". Actualizar el párrafo del slide de "8 reportes" a "9 reportes" con descripción breve del nuevo tab.
  RF: RF-008
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: onboarding slide 3 renderiza 9 filas sin overflow (validar visualmente en cel chico).

- [ ] T008 Documentación: actualizar `mobile/lib/screens/help_screen.dart` — prefijo del tile de reportes de "8 pestañas" a "9 pestañas" + bullet nuevo: "Calendario: vista mensual con marcadores por día según el tipo de movimiento (verde ingreso, rojo gasto, azul movimiento interno). Tap en un día abre la lista de movimientos exactos."
  RF: RF-009
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: FAQ menciona 9 pestañas + bullet visible en el tile expandido.

## Pruebas

- [ ] T009 Pruebas: agregar grupo `movementsByDay (sprint movements-calendar)` en `mobile/test/data/reports_test.dart` con UT-CAL01..12 según `test-plan.md`. UT-CAL12 (reactividad) usa `emitsThrough`, NO `Future.delayed`.
  RF: RF-011
  Depende de: T003
  Paralelizable: si (con T010, T011)
  Criterio de terminado: 12 tests verdes en el grupo.

- [ ] T010 Pruebas: agregar grupo `forDay (sprint movements-calendar)` en `mobile/test/data/entries_filters_test.dart` con UT-CAL13 (constructor) y UT-CAL14 (roundtrip deep link).
  RF: RF-011
  Depende de: T004
  Paralelizable: si (con T009, T011)
  Criterio de terminado: 2 tests verdes.

- [ ] T011 Pruebas: crear `mobile/test/screens/reports/movements_calendar_tab_test.dart` con WT-CAL01..04 según `test-plan.md`. Usar `pumpFincoreApp` del harness. WT-CAL03 verifica que el `context.push` navega a `/entries` con el `EntriesFilters` correcto.
  RF: RF-012
  Depende de: T005
  Paralelizable: si (con T009, T010)
  Criterio de terminado: 4 widget tests verdes.

- [ ] T012 Pruebas: ajustar `mobile/test/screens/reports/credit_cards_tab_test.dart` (WT-15) cambiando `findsNWidgets(8)` a `findsNWidgets(9)` en el test que verifica el conteo de tabs.
  RF: RF-013
  Depende de: T006
  Paralelizable: si (con T009, T010, T011)
  Criterio de terminado: WT-15 pasa con el nuevo conteo.

- [ ] T013 Pruebas: correr `flutter analyze` (0 errores nuevos) + `flutter test` completo. Confirmar que la suite queda en al menos 488 tests verdes (474 baseline + 14 nuevos aprox; ajustar el número final según distribución real).
  RF: RF-014
  Depende de: T009, T010, T011, T012
  Paralelizable: no
  Criterio de terminado: suite completa verde + analyze limpio.

## Validación de calidad

- [ ] T014 Validación: bump de versión en `mobile/pubspec.yaml` (`0.16.0+82`) + `mobile/android/app/build.gradle.kts` (`versionCode = 82`, `versionName = "0.16.0"`). Correr `flutter build apk --release --split-per-abi` + `scripts/verify-apk.sh`.
  RF: —
  Depende de: T013
  Paralelizable: no
  Criterio de terminado: APK release compilado + `verify-apk.sh` OK con versionCode 2082.

- [ ] T015 Validación: smoke manual con Diego en cel real. Ejecutar SM-01..07 del `test-plan.md`. Documentar hallazgos en `implementation/pendientes.md` si aparecen; corregir antes del commit si son bloqueantes.
  RF: —
  Depende de: T014
  Paralelizable: no
  Criterio de terminado: Diego confirma los 7 smokes.

- [ ] T016 Validación: ejecutar la skill `branch-quality-review` con slug `flutter-reports-movements-calendar-v1`. Consolidar hallazgos (si los hay) en el reporte único bajo `engineering/quality-review/flutter-reports-movements-calendar-v1/`. Aplicar los que sean bloqueantes antes del commit.
  RF: —
  Depende de: T015
  Paralelizable: no
  Criterio de terminado: reporte generado; hallazgos bloqueantes resueltos.

- [ ] T017 Validación: commit final con mensaje que resuma el sprint (ver ejemplos de commits recientes del proyecto). NO pushear (Diego lo hace manualmente cuando confirma).
  RF: —
  Depende de: T016
  Paralelizable: no
  Criterio de terminado: `git status` limpio; working tree sin cambios pendientes.

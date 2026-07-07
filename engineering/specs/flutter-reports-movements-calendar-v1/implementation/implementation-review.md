# Implementation Review: flutter-reports-movements-calendar-v1

## Resumen de lo implementado

Nuevo 9no tab "Calendario" en `/reports` con `table_calendar 3.1.2` (pinned). Muestra el mes en foco con hasta 3 marcadores por día según los tipos de movimiento presentes (verde ingreso, rojo gasto, azul movimiento interno). Tap en un día abre `/entries` con filtro custom `from=to=día`. Sprint aditivo puro. Sin schema bump.

## Archivos principales modificados

- `mobile/pubspec.yaml` — agrega `table_calendar: 3.1.2` (pinned) + bump `0.16.0+82`.
- `mobile/lib/data/reports.dart` — nuevo modelo `DayActivity` + método `ReportsService.movementsByDay({monthAnchor})` con SQL usando `strftime('%Y-%m-%d', occurred_at, 'localtime')` para respetar la timezone del dispositivo.
- `mobile/lib/data/entries_filters.dart` — nuevo factory `EntriesFilters.forDay({day})` que arma rango custom de 1 día sin restricciones de kind/cuenta/categoría.
- `mobile/lib/screens/reports/movements_calendar_tab.dart` (nuevo) — widget del tab con `TableCalendar`, `markerBuilder`, `onDaySelected`, `onPageChanged`, locale `'es_MX'`.
- `mobile/lib/screens/reports_screen.dart` — 8 → 9 tabs.
- `mobile/lib/screens/onboarding_screen.dart` — 9ª fila slide 3 + "9 reportes".
- `mobile/lib/screens/help_screen.dart` — FAQ "9 pestañas" + bullet nuevo.
- `mobile/android/app/build.gradle.kts` — `versionCode = 82`, `versionName = "0.16.0"`.

Tests nuevos:

- `mobile/test/data/reports_test.dart` — grupo `movementsByDay (sprint movements-calendar)` con UT-CAL01..12.
- `mobile/test/data/entries_filters_test.dart` — grupo `forDay (sprint movements-calendar)` con UT-CAL13..14.
- `mobile/test/screens/reports/movements_calendar_tab_test.dart` (nuevo) — WT-CAL01..04.

Ajuste de regresión:

- `mobile/test/screens/reports/credit_cards_tab_test.dart` — WT-15 conteo `findsNWidgets(8)` → `findsNWidgets(9)`.

## Tareas completadas

- **T001** (dep externa): `table_calendar 3.1.2` agregado con pin exacto. `flutter pub get` OK. `flutter analyze` sin nuevos warnings.
- **T002** (modelo): `DayActivity` con 3 bools + `totalCount` + getter `hasAny`.
- **T003** (servicio): `movementsByDay` con SQL `strftime('%Y-%m-%d', 'localtime')` para timezone-safe grouping. `readsFrom: {journalEntries}`.
- **T004** (factory): `EntriesFilters.forDay` con rango `00:00:00` → `23:59:59.999`.
- **T005** (widget): tab completo con `TableCalendar` + estilos consistentes al tema + `markerBuilder` con hasta 3 puntos + drill-down.
- **T006** (integración): 9no tab en `ReportsScreen`.
- **T007** (onboarding): 9ª fila con `Icons.calendar_month`.
- **T008** (FAQ): prefacio "9 pestañas" + bullet nuevo.
- **T009-T011** (tests): 18 nuevos verdes tras 2 iteraciones (fix timezone + fix genéricos de finder).
- **T012** (regresión): WT-15 actualizado a 9 tabs.
- **T013** (suite): 492/492 verdes.
- **T014** (bump + APK): 0.16.0+82 verificado.

## Tareas pendientes

- **T015** (smokes SM-01..07 con Diego): pendiente. Diego confirma tras probar el APK.
- **T016** (`branch-quality-review`): pendiente antes del commit final.
- **T017** (commit final): pendiente.

## Riesgos residuales

- **R1 (dep externa `table_calendar`)** — mitigado: pinned a `3.1.2`, `flutter analyze` limpio, no introduce warnings. Cambio a versiones futuras requiere revisar changelog.
- **R2 (locale es_MX)** — mitigado: `'es_MX'` hardcoded en el widget + `initializeDateFormatting('es_MX', null)` ya se hace en `main.dart`. Validar en smoke que días/meses aparecen en español.
- **R3 (TabBar con 9 tabs en cel chico)** — no medido en tests; Diego valida en SM-01.
- **R4 (performance del stream con muchos años)** — no medido; datasets típicos ya cubiertos por UT-CAL08.
- **R5 (marcadores con 3 kinds en 1 día)** — cubierto por UT-CAL07 lógicamente; el rendering visual (¿saturado?) se valida en smoke.
- **R7 (confusión con heatmap futuro)** — mitigado con bullet del FAQ que aclara "los marcadores indican qué tipos de movimiento hubo, no el monto".
- **R9 (bug conocido `selectedDay`/`focusedDay` divergentes)** — mitigado con `_onPageChanged` que setea `_selectedDay = null` al cambiar de mes (previene divergencia).
- **Nuevo riesgo detectado** — el `Widget?` del `markerBuilder` requiere que `_dot` respete `markersMaxCount: 3`; en implementación se agregó `if (activity.hasIncome)` / etc para limitar a 3. Sin riesgo si un día tiene los 3.

## Pruebas realizadas

- `flutter analyze` limpio (4 hints info pre-existentes tolerados).
- `flutter test test/data/reports_test.dart` — 12 nuevos verdes en el grupo movements-calendar.
- `flutter test test/data/entries_filters_test.dart` — 2 nuevos verdes en el grupo forDay.
- `flutter test test/screens/reports/movements_calendar_tab_test.dart` — 4 widget tests verdes.
- `flutter test` completo → **492/492 verdes** (474 baseline + 18 nuevos).
- Build APK release `--split-per-abi` OK.
- `verify-apk.sh` OK con versionCode 2082 / versionName 0.16.0.

## Pruebas recomendadas

- **SM-01..07** en cel real por Diego. Especialmente:
  - SM-02 (nombres de mes/días en español neutro).
  - SM-03 (drill-down con la BD real de Diego).
  - SM-04 (reactividad al agregar nuevo movimiento).
  - SM-05 (navegación de mes).
- **Validación visual del `markerBuilder`** en cel real: los 3 puntos de 5 px debajo del número del día son legibles y no se ven saturados.

## Posibles regresiones

- **Otros 8 tabs de `/reports`**: intactos. Tests widget existentes de cada uno siguen verdes.
- **`/entries`**: cero cambios. El drill-down usa el parser existente `EntriesFilters.parse`.
- **Dashboard**: cero cambios.
- **Onboarding**: la 9ª fila del slide 3 acomoda dentro del `SingleChildScrollView + LayoutBuilder` desde budgets. Los tests WT-O01..O06 siguen verdes (no verifican conteo exacto).
- **Help**: el tile de reportes ahora tiene un bullet más (9 total). Los tests WT-H01..H04 siguen verdes.

## Recomendaciones para code review humano

1. Revisar que el SQL de `movementsByDay` usa `'localtime'` en `strftime`. Sin esto, los días cerca de medianoche caen en el día equivocado por el UTC storage de drift. Cubierto por UT-CAL07/UT-CAL11.
2. Confirmar que `table_calendar 3.1.2` no introduce warnings de deprecación en `flutter analyze`. Actualmente 0.
3. Revisar el `markerBuilder` — el `Padding` + `Row` renderiza 3 puntos de 5 px con margen horizontal de 1 px. Cambio visual sutil que impacta la lectura del calendario en cel chico.
4. Ejecutar `branch-quality-review` con slug `flutter-reports-movements-calendar-v1` antes del commit final.

Referencia al reporte de quality review (cuando exista): `engineering/quality-review/flutter-reports-movements-calendar-v1/`.

# Resumen extenso — flutter-reports-movements-calendar-v1

## Contexto tomado de spec.md, preguntas.md y clarificaciones

`spec.md` define el sprint como el 9no tab en `/reports`: vista mensual de movimientos con marcadores de color por día según los tipos presentes. Sin `preguntas.md` ni `clarificaciones.md` — todas las decisiones de UX se documentaron como supuestos:

- Marcadores por kind (no intensidad por monto — eso viene con heatmap).
- Sin filtros de kind/cuenta en v1.
- Drill-down reusa `/entries?filter=...`.
- Selector de mes = header nativo del `TableCalendar`.
- Locale `'es_MX'` hardcoded.
- Día inicial = hoy si cae en el mes en foco.

Dependencia externa nueva: `table_calendar`.

## Relación con plan/plan.md y plan/tasks.md

Orden de tasks seguido tal cual (T001..T017):

1. **T001** (dep externa): agregar `table_calendar 3.1.2` pinned al `pubspec.yaml`. `flutter pub get` + `flutter analyze` limpios.
2. **T002-T003** (backend): modelo `DayActivity` + método `movementsByDay` con SQL agrupando por día + reactividad `readsFrom: {journalEntries}`. Fix aplicado in-line: usar `strftime('%Y-%m-%d', 'localtime')` en vez de `date()` para respetar timezone del dispositivo.
3. **T004** (factory): `EntriesFilters.forDay({day})` con rango custom del día.
4. **T005** (widget): `MovementsCalendarTab` con `TableCalendar`, `markerBuilder`, `onDaySelected`, `onPageChanged`, tema custom.
5. **T006** (integración): 9no tab en `ReportsScreen`.
6. **T007-T008** (docs UI): onboarding + FAQ actualizados.
7. **T009-T011** (tests): 18 nuevos.
8. **T012** (regresión): WT-15 conteo 8 → 9.
9. **T013** (validación suite): 492/492 verdes.
10. **T014** (bump + APK): `0.16.0+82` verificado.
11. **T015-T017**: pendientes (smokes + quality review + commit).

## Cambios principales por módulo o capa

### Dependencia externa

`pubspec.yaml`:

```yaml
table_calendar: 3.1.2
```

Comentario in-place explicando el pin y la relación con RF-018.

### Capa de datos

**`mobile/lib/data/reports.dart`**:

- Modelo `DayActivity`:
  - `hasIncome`, `hasSpending`, `hasInternal` (bool).
  - `totalCount` (int).
  - Getter `hasAny` = `hasIncome || hasSpending || hasInternal`.
  - Documenta la agrupación por kind según RN-CAL01.

- Método `ReportsService.movementsByDay({required DateTime monthAnchor})`:
  ```sql
  SELECT strftime('%Y-%m-%d', occurred_at, 'localtime') AS day,
         kind,
         COUNT(*) AS count
  FROM journal_entries
  WHERE deleted_at IS NULL
    AND occurred_at >= ?
    AND occurred_at <= ?
  GROUP BY day, kind
  ```
  - Rango: `firstDayOfMonth(monthAnchor)` a `lastDayOfMonth(monthAnchor) 23:59:59.999`.
  - `readsFrom: {journalEntries}` para reactividad.
  - Helper interno `_buildDayActivityMap` construye el `Map` en Dart post-fetch.
  - Clase interna `_DayBucket` (mutable, uso interno del helper).

**`mobile/lib/data/entries_filters.dart`**:

- Factory `EntriesFilters.forDay({required DateTime day})`:
  - `datePreset: DateRangePreset.custom`.
  - `from = DateTime(y, m, d, 0, 0, 0)`.
  - `to = DateTime(y, m, d, 23, 59, 59, 999)`.
  - Sin `kinds`, `accountIds`, `categoryIds`, `minAmount`, `maxAmount`.

### Capa UI

**`mobile/lib/screens/reports/movements_calendar_tab.dart`** (nuevo, ~280 líneas):

- `MovementsCalendarTab` StatefulWidget.
- Estado: `_focusedMonth` (día 1 del mes), `_selectedDay` (nullable, hoy si cae en el mes en foco al init), `_stream` cacheado.
- `_buildStream`: llama `reportsService.movementsByDay(monthAnchor: _focusedMonth)`.
- `_onPageChanged`: normaliza a día 1 + recreación de stream + limpia `_selectedDay` (previene R9).
- `_onDaySelected`: setea `_selectedDay` + `context.push(EntriesFilters.forDay(day: normalizedDay).toDeepLink())`.
- Build: `StreamBuilder` + `SingleChildScrollView` + `BaseCard` + `TableCalendar`:
  - `locale: 'es_MX'`.
  - `firstDay` / `lastDay`: ±10 años del mes actual.
  - `headerStyle` con chevrons de accent color, título centrado sin format button.
  - `calendarStyle` con `todayDecoration`, `selectedDecoration`, colores del proyecto.
  - `markersMaxCount: 3` + `markersAlignment: bottomCenter`.
  - `calendarBuilders.markerBuilder`: Row con hasta 3 `_dot(5x5)` según `DayActivity`.
- `_LoadingState` estático (patrón M5).
- `_ErrorState` con retry cosmético.

**`mobile/lib/screens/reports_screen.dart`**: 9no tab agregado.

### Documentación

- `onboarding_screen.dart`: 9ª fila con `Icons.calendar_month + accent`.
- `help_screen.dart`: "9 pestañas" + bullet nuevo.

### Version bump

- `pubspec.yaml`: `0.15.4+81` → `0.16.0+82` (minor por feature nueva + dep externa).
- `build.gradle.kts`: `versionCode = 82`, `versionName = "0.16.0"`.

### Tests

- **`reports_test.dart`**: grupo nuevo con UT-CAL01..12 (BD vacía, 5 kinds individuales, día con 3 kinds mezclados, entries fuera de mes, cancelación reactiva, bordes de mes, reactividad con `emitsThrough`).
- **`entries_filters_test.dart`**: grupo nuevo con UT-CAL13 (constructor) y UT-CAL14 (roundtrip deep link con `EntriesFilters.parse`).
- **`movements_calendar_tab_test.dart`** (nuevo): WT-CAL01 (render), WT-CAL02 (con datos), WT-CAL03 (drill-down verifica la descripción del entry en `/entries`), WT-CAL04 (navegación mes).
- **`credit_cards_tab_test.dart`**: WT-15 conteo 8 → 9.

## Desviaciones respecto al plan

Ver `desviaciones-plan.md` para detalle. Resumen:

- **D1** — SQL con `strftime` en lugar de `date()`: el plan mencionaba `date(occurred_at)`. En implementación se cambió a `strftime('%Y-%m-%d', occurred_at, 'localtime')` porque drift almacena UTC y el `date()` sin `'localtime'` cae en el día equivocado para entries cerca de medianoche. Cubierto por UT-CAL07 y UT-CAL11.
- **D2** — WT-CAL03 verifica el drill-down por presencia del `Text('IncomeCAL')` en lugar de inspeccionar `EntriesFilters` en el estado del screen. Más simple y verifica el resultado observable (que el usuario ve el entry correcto). Sin cambio de intención del test.
- **D3** — Finder `find.byType(TableCalendar<dynamic>)` no matchea widgets con generic distinto. Cambiado a `find.byWidgetPredicate((w) => w is TableCalendar)`. Idiomático en Flutter.

Sin desviaciones bloqueantes.

## Pruebas realizadas y recomendadas

**Realizadas**:

- `flutter analyze` limpio (0 errores nuevos).
- `flutter test` → **492/492 verdes** (baseline 474 + 18 nuevos).
- Build APK release `--split-per-abi` OK; `verify-apk.sh` OK con versionCode 2082 / versionName 0.16.0.

**Recomendadas**:

- SM-01..07 en cel real por Diego (visibilidad del 9no tab, español neutro en header, drill-down con BD real, reactividad, navegación mes, onboarding, FAQ).
- `branch-quality-review` con slug `flutter-reports-movements-calendar-v1`.

## Riesgos residuales y posibles regresiones

- **Sin refactor de tabs por selector de mes** (R8 del plan): TD intencional. Cada tab con selector de mes tiene su propia implementación.
- **`table_calendar` 3.1.2 pinned**: cualquier bump requiere revisar changelog + rerun de tests. Documentado con RF-018.
- **`markerBuilder` con 3 puntos**: probado por RN-CAL07 lógicamente; visual se valida en smoke.
- **Regresión potencial en otros 8 tabs**: cero — código intacto, tests widget existentes verdes.
- **Regresión potencial en drill-down desde otros tabs por categoría**: cero — el factory `forCategoryBucket` / `forIncomeBucket` no fue tocado; `forDay` es aditivo puro.
- **Timezone**: la query es timezone-safe con `'localtime'`. Diego puede viajar y los entries no se corren. Comportamiento consistente con lo que un usuario espera.

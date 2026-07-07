# Plan técnico — flutter-reports-spending-heatmap-v1

## Enfoque tecnico

Sprint aditivo puro sin dependencias externas. Cinco cambios ortogonales:

1. **Modelo `SpendingHeatmap`** + enum `IntensityLevel` en `mobile/lib/data/reports.dart`. Inmutable, con `Map<DateTime, double> daySpending` (solo días con gasto > 0), agregados (`total`, `daysWithSpending`), cuartiles precalculados (`p25`, `p50`, `p75`) y método `IntensityLevel intensityFor(DateTime day)`. `daySpending` NO contiene claves con valor 0 — el helper de intensidad devuelve `none` cuando la clave está ausente.

2. **`ReportsService.spendingHeatmap({required int year})`** con SQL:
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
   Rango: `DateTime(year, 1, 1)` → `DateTime(year, 12, 31, 23, 59, 59, 999)`. `readsFrom: {journalEntries}` — no toca `categories`, sin re-emit por archivos de categorías. Post-fetch en Dart: parsear el `Map`, calcular cuartiles ordenados vía helper `_computeQuartiles`.

3. **Helper `_computeQuartiles(List<double> sortedValues)`** (privado en `reports.dart`):
   - Si `sortedValues.length < 4` → devuelve `(max, max, max)` (RN-HM05).
   - Sino, interpolación estándar: `p25 = value at index (n-1) * 0.25` con interpolación lineal entre el `floor` y `ceil` si no es entero. Idem `p50` y `p75`.
   - Función pura, sin dependencias del `ReportsService`.

4. **Widget `SpendingHeatmapTab`** en `mobile/lib/screens/reports/spending_heatmap_tab.dart` (~350 líneas estimadas):
   - `int _focusedYear` inicializado en `DateTime.now().year`.
   - `Stream<SpendingHeatmap>? _stream` cacheado (patrón M5).
   - `_onPrevYear` / `_onNextYear` cambian `_focusedYear` y recrean el stream.
   - `_retryStream` para el `onRetry` del `_ErrorState` (patrón A1 del quality review del calendar).
   - Layout: `Column` con (a) header con chevrons + año; (b) `LayoutBuilder` con el grid; (c) leyenda.
   - Grid: `CustomPaint` con `_HeatmapPainter` que dibuja las 365-366 celdas. El painter recibe `SpendingHeatmap` + `cellSize` calculado por el `LayoutBuilder`.
   - Tap: `GestureDetector.onTapDown` calcula `column = dx / (cellSize + gap)`, `row = dy / (cellSize + gap)`, deriva el `DateTime` correspondiente y llama `_onDayTap`.
   - `_onDayTap(day)` construye `EntriesFilters(datePreset: custom, from: day 00:00, to: day 23:59:59.999, kinds: ['expense', 'credit_expense'])` inline y hace `context.push(filter.toDeepLink())`.

5. **Integración**: `mobile/lib/screens/reports_screen.dart` sube de 9 a 10 tabs (label "Heatmap" al final). Onboarding slide 3 agrega 10ª fila con `Icons.grid_view + accent + 'Heatmap'`. Help FAQ actualiza el prefacio a "10 pestañas" + bullet describiendo el heatmap.

Sin dependencia externa nueva. Bump `0.16.0+82` → `0.16.1+83` (patch minor por feature aditiva pura sin dep).

## Requisitos funcionales cubiertos

- **RF-001** (modelo `SpendingHeatmap`): T002.
- **RF-002** (enum `IntensityLevel`): T002.
- **RF-003** (método `spendingHeatmap` con SQL + `readsFrom`): T004.
- **RF-004** (helper `_computeQuartiles` con fallback): T003.
- **RF-005** (widget `SpendingHeatmapTab` estado + stream cache): T005.
- **RF-006** (Column con header + grid + leyenda): T005.
- **RF-007** (grid con `CustomPaint` + `LayoutBuilder` responsive): T006 (sub-tarea del widget).
- **RF-008** (`onTap` en cada celda dispara `_onDayTap`): T007 (sub-tarea).
- **RF-009** (`_LoadingState` + `_ErrorState` con retry): T005 (base).
- **RF-010** (10mo tab en `ReportsScreen`): T008.
- **RF-011** (onboarding slide 3 10ª fila): T009.
- **RF-012** (FAQ Help "10 pestañas" + bullet): T010.
- **RF-013** (UT servicio): T012 (según test-plan).
- **RF-014** (widget tests del tab): T014.
- **RF-015** (regresión conteo tabs 9→10): T015.
- **RF-016** (`flutter analyze` limpio + suite verde): T016.

## Archivos o modulos probablemente afectados

Confirmados por inspección previa:

- `mobile/lib/data/reports.dart` — modelo `SpendingHeatmap` + enum + método + helper `_computeQuartiles`.
- `mobile/lib/screens/reports/spending_heatmap_tab.dart` (nuevo) — widget del tab.
- `mobile/lib/screens/reports_screen.dart` — 9 → 10 tabs.
- `mobile/lib/screens/onboarding_screen.dart` — 10ª fila slide 3 + "10 reportes".
- `mobile/lib/screens/help_screen.dart` — "10 pestañas" + bullet.
- `mobile/pubspec.yaml` — bump `0.16.1+83`.
- `mobile/android/app/build.gradle.kts` — `versionCode = 83`, `versionName = "0.16.1"`.
- `mobile/test/data/reports_test.dart` — grupo nuevo `spendingHeatmap`.
- `mobile/test/screens/reports/spending_heatmap_tab_test.dart` (nuevo).
- `mobile/test/screens/reports/credit_cards_tab_test.dart` — WT-15 conteo 9→10 (por confirmar durante T015).

Sin cambios en:

- Schema o migraciones (`database.dart`).
- DAOs (`entries_dao.dart`, `categories_dao.dart`).
- `EntriesFilters` (no requiere factory nueva; el uso es inline).
- CLAUDE.md (sin nueva convención transversal).

## Entidades y estados afectados

- **JournalEntry**: solo lectura. Se consultan `kind`, `occurred_at`, `amount`, `deleted_at`.
- **`SpendingHeatmap`** (nuevo, en memoria): inmutable, vive dentro del stream. Ninguna persistencia.
- **`IntensityLevel`** (nuevo, enum): 5 valores discretos.
- **Estado de UI del tab**:
  - `_focusedYear` (int; invariante: año calendario válido).
  - `_stream` (recreado al cambiar `_focusedYear`).
- **Sin invariantes nuevos sobre el dominio**: el heatmap es una vista derivada.

## Compatibilidad con datos y procesos existentes

- **Datos históricos**: cualquier BD existente funciona; la query no requiere columnas nuevas.
- **Reportes vecinos**: `spendingByCategory`, `cashflowByMonth`, `movementsByDay`, etc. no se tocan.
- **Drill-down a `/entries`**: reusa el parser existente `EntriesFilters.parse`. Sin cambios en el screen del drill-down.
- **Import de backup JSON v1**: cero impacto (heatmap es lectura pura).
- **Onboarding + Help**: cambios de texto puros. Tests widget existentes no verifican conteo exacto ni texto completo — siguen verdes.
- **`EntriesFilters` sin factory nueva**: el drill-down construye el filtro inline en `_onDayTap`. Consistente con el patrón de RN-CAL05 del sprint calendar cuando se necesitaba control adicional sobre `kinds`.

## Cambios de datos si aplica

No aplica.

## Cambios de API si aplica

No aplica.

## Cambios de integraciones si aplica

No aplica. Sin dependencia externa nueva.

## Cambios de UI si aplica

- Nuevo tab "Heatmap" al final del TabBar de `/reports`.
- Onboarding slide 3: 10ª fila con `Icons.grid_view` (o alternativa `Icons.calendar_view_month`).
- Help FAQ: "10 pestañas" + bullet.
- Sin cambios en Dashboard, `/entries`, `/settings`, forms.

## Cambios de permisos si aplica

No aplica. Single-user.

## Riesgos tecnicos

- **R1 — Overflow del TabBar con 10 tabs en cel chico**: `isScrollable: true` desde varios sprints. 10 tabs con label "Heatmap" (7 chars) debería estar OK. Validar en SM-01.
- **R2 — Grid en cel de 360 px**: 53 columnas + gaps consumen ~470 px si celdas son 7 px. Mitigación: `LayoutBuilder` calcula `cellSize = (availableWidth - labelsWidth - gapsWidth) / 53`. En 360 px → celdas de ~5 px. Legible para vista de patrón; validar smoke.
- **R3 — Hit-testing manual dentro del `CustomPaint`**: `GestureDetector.onTapDown` con cálculo `column = dx / (cellSize + gap)` puede tener bugs off-by-one en celdas de borde. Cubrir con widget test que tapea coordenadas específicas.
- **R4 — Cuartiles con distribuciones raras**: dataset con 1 gasto muy alto vs muchos bajos → p25/p50/p75 quedan cerca de los bajos. Aceptable; el fallback RN-HM05 solo aplica a `n < 4`.
- **R5 — Año bisiesto**: 366 días. La grilla acomoda una columna extra (fila 7 columna 53). Calcular `weeksInYear = (daysInYear + firstWeekOffset) / 7`.
- **R6 — Rendering de 365 celdas con `CustomPaint`**: eficiente por naturaleza (una sola pasada de paint). Sin lag esperado.
- **R7 — Onboarding slide 3 con 10 filas**: patrón `SingleChildScrollView + LayoutBuilder + ConstrainedBox + IntrinsicHeight` acomoda scroll interno si falta. Validar smoke.
- **R8 — Locale del selector de año**: labels de meses del heatmap (Ene/Feb/...) requieren `DateFormat('MMM', 'es_MX')`. Ya inicializado en `main.dart`.
- **R9 — Widget tests limitados con `CustomPaint`**: no se puede `find.byType(HeatmapCell)`. Los detalles del rendering se validan por smoke; los widget tests cubren montaje + tap + navegación.
- **R10 — Interpretación de escala relativa**: 2 años del mismo usuario con distintos niveles de gasto se ven "iguales" porque los cuartiles son relativos. Aceptable — la escala relativa es óptima para autoanálisis (Diego lo decidió).
- **R11 — Días futuros del año en curso**: se ven como `none` (sin gasto). Comportamiento intencional según RN-HM13. Sin marker especial de "hoy".

## Estrategia de pruebas

Ver `test-plan.md`. Foco:

- **UT servicio** (10 tests): agregación, kinds excluidos, soft delete, cuartiles con distintas distribuciones, fallback `n < 4`, cruce de año, reactividad con `emitsThrough`.
- **UT modelo** (5 tests): `intensityFor` con cada `IntensityLevel` + clave ausente.
- **Widget tests** (3-4 tests): render inicial, cambio de año, drill-down verifica descripción del gasto sembrado. `find.byType(SpendingHeatmapTab)` + `find.byType(CustomPaint)`.
- **Regresión conteo tabs** en `credit_cards_tab_test.dart`.
- **Smoke con Diego**: 7 escenarios en cel real (visibilidad, rendering en 360 px, drill-down, año prev/next, reactividad, onboarding, FAQ).

## Estrategia de rollback

- Revert del commit es limpio: 5 archivos productivos + 3 test files ortogonales al resto.
- Sin dependencia externa → sin lock a resolver.
- Sin cambio de datos → BD queda intacta.
- APK 0.16.1+83 → reinstalar 0.16.0+82 tras `adb uninstall` (Android no permite downgrade).

## Orden sugerido de implementacion

1. **T001**: leer `movements_calendar_tab.dart` como referencia estructural del tab.
2. **T002**: modelo `SpendingHeatmap` + enum `IntensityLevel` + método `intensityFor`.
3. **T003**: helper `_computeQuartiles` con fallback (RN-HM05).
4. **T004**: método `ReportsService.spendingHeatmap({year})` con SQL + readsFrom.
5. **T005**: widget base `SpendingHeatmapTab` con header + `LayoutBuilder` + `_LoadingState` + `_ErrorState` funcional.
6. **T006**: pintar el grid con `_HeatmapPainter` (`CustomPainter`). Calcula posición de cada día en base al día de la semana del 1 de enero.
7. **T007**: `GestureDetector.onTapDown` con hit-testing por coordenadas → `_onDayTap` → deep link con `kinds: ['expense', 'credit_expense']`.
8. **T008**: 10mo tab en `ReportsScreen`.
9. **T009-T010**: onboarding + FAQ.
10. **T011**: leyenda al pie con 5 cuadrados + labels + subtexto total.
11. **T012**: UT servicio (10 tests).
12. **T013**: UT modelo `intensityFor` (5 tests).
13. **T014**: widget tests (3-4 tests).
14. **T015**: regresión conteo tabs.
15. **T016**: `flutter analyze` + `flutter test` completo → ≥ 500 verdes.
16. **T017**: bump versión + APK release + verify.
17. **T018**: smokes SM-01..07 con Diego.
18. **T019**: `branch-quality-review`.
19. **T020**: commit final.

## Casos borde que condicionan la solucion

- **Año sin gastos**: `daySpending` vacío, `total = 0`, `daysWithSpending = 0`, cuartiles = 0. `intensityFor` devuelve `none` para todo día. Banner "Sin gastos registrados en este año".
- **Año con 1-3 gastos**: fallback RN-HM05 activa; todos los días con gasto se pintan `veryHigh`.
- **Año con `daysWithSpending == 365`**: cuartiles calculados con distribución uniforme. Sin problemas de índice.
- **1 de enero en jueves** (o cualquier día de semana): la primera columna del grid solo tiene 4 celdas visibles (Jue/Vie/Sáb/Dom). Las celdas Lun/Mar/Mié de esa columna corresponden a la semana anterior del año previo. Renderizar como `none` invisibles (transparent) o omitirlas.
- **Año bisiesto**: 366 días. `daysInYear = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0) ? 366 : 365`.
- **Cambio muy rápido de año** con las flechas: drift cachea; sin race.
- **BD con muchos años y `year = 2010`** (sin datos): query devuelve 0 filas; `SpendingHeatmap` vacío.
- **Gasto con `amount = 0`**: `SUM(amount)` puede quedar en 0 si es el único día. Ese día NO entra al `Map` (RN-HM04 excluye `total = 0` del cálculo de cuartiles).
- **Cambio de horario / DST**: `'localtime'` en strftime maneja el desfase.
- **Tap en celda de "spillover"** (celda transparente fuera del año): ignorar en `onTapDown` verificando que `day.year == _focusedYear`.

## Preguntas o supuestos que siguen afectando la implementacion

Ninguna pregunta bloqueante.

Supuestos que se mantienen desde la spec:

- Ancho de celda calculado con `LayoutBuilder` (aproximado 5-6 px en cel de 360 px).
- Etiquetas de mes con `DateFormat('MMM', 'es_MX')`.
- Etiquetas de día de semana: solo Lun/Mié/Vie visibles (Mar/Jue/Sáb/Dom vacíos por espacio).
- Días de spillover (fuera del año en el grid) se dibujan `transparent` / omitidos.
- Sin marker especial de "hoy" (evita confusión visual con la escala relativa).
- Bump `0.16.1+83`: patch minor por feature aditiva sin dep externa.

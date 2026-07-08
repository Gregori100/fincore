# Plan técnico — flutter-reports-income-heatmap-v1

## Enfoque tecnico

Sprint aditivo puro sin dependencias externas. Mismo patrón que
`flutter-reports-spending-heatmap-v1` con duplicación intencional (mismo
criterio que `spending_by_category` / `income_by_category`). Cuatro cambios
ortogonales:

1. **Modelo `IncomeHeatmap`** en `mobile/lib/data/reports.dart`: mirror
   estructural de `SpendingHeatmap` con `Map<DateTime, double> dayIncome`,
   `total`, `daysWithIncome` (int), `p25`/`p50`/`p75` y método
   `intensityFor(day) → IntensityLevel`. Reusa el enum `IntensityLevel`
   existente. La duplicación es intencional (nombre semántico del campo
   y el modelo aumenta legibilidad).

2. **`ReportsService.incomeHeatmap({required int year})`** en
   `reports.dart`. SQL con `kind = 'income'` (singular, no `IN` porque
   solo hay 1 kind). Reusa el helper privado `_computeQuartiles` (ya
   accesible desde el mismo archivo). Helper interno `_buildIncomeHeatmap`
   mirror de `_buildSpendingHeatmap`.

3. **Widget `IncomeHeatmapTab`** en
   `mobile/lib/screens/reports/income_heatmap_tab.dart` (~500 líneas).
   Copia idiomática de `SpendingHeatmapTab` con cambios:
   - Color base `FincoreColors.positive` (verde) en los 5 niveles.
   - Textos: "Ingreso del mes", "Sin ingresos registrados en este año",
     "días con ingreso".
   - Drill-down con `kinds: ['income']`.
   - Ícono `Icons.open_in_full` sutil en `_MonthLabel` (heredado del
     patch 0.16.3+85 del gastos).
   - Consolidar en año vacío: leyenda oculta cuando
     `daysWithIncome == 0` (heredado del mismo patch).
   Se reusan helpers top-level ya existentes: `heatmapDayForMonthPosition`
   y `IntensityLevel`. Todo lo demás se duplica en el nuevo archivo
   (widget, painter, sheet, labels, banner, etc.) porque son privados al
   archivo del spending.

4. **Integración**: `mobile/lib/screens/reports_screen.dart` sube de 10
   a 11 tabs (label "Heatmap ingresos" al final). Onboarding slide 3
   agrega 11ª fila con `Icons.grid_view + FincoreColors.positive +
   'Heatmap ingresos'`. Help FAQ actualiza el prefacio a "11 pestañas"
   + bullet describiendo el nuevo tab.

Sin dependencia externa nueva. Sin schema bump. Bump `0.16.3+85` →
`0.16.4+86` (patch minor por feature aditiva pura).

## Requisitos funcionales cubiertos

- **RF-001** (modelo `IncomeHeatmap`): T002.
- **RF-002** (reuso del enum `IntensityLevel`): T002 (sin nuevo enum).
- **RF-003** (método `incomeHeatmap` con SQL + `readsFrom`): T004.
- **RF-004** (reuso de `_computeQuartiles` + helper `_buildIncomeHeatmap`):
  T004 (el helper vive en el mismo archivo, junto al de spending).
- **RF-005** (widget `IncomeHeatmapTab` con estado + stream cache): T005.
- **RF-006** (Column con header + grid + leyenda/empty banner): T005 y
  T006.
- **RF-007** (grid con `CustomPaint` responsive): T006.
- **RF-008** (bottom sheet expandido con `_MonthDetailSheet`): T007.
- **RF-009** (`_LoadingState` + `_ErrorState` con retry): T005 (base).
- **RF-010** (11º tab en `ReportsScreen`): T008.
- **RF-011** (onboarding slide 3 con 11ª fila): T009.
- **RF-012** (Help FAQ "11 pestañas" + bullet): T010.
- **RF-013** (UT servicio): T011 (según test-plan).
- **RF-014** (widget tests del tab): T012.
- **RF-015** (regresión conteo tabs 10→11): T013.
- **RF-016** (`flutter analyze` limpio + suite verde): T014.

## Archivos o modulos probablemente afectados

Confirmados por lectura previa:

- `mobile/lib/data/reports.dart` — modelo `IncomeHeatmap` + método
  `incomeHeatmap` + helper `_buildIncomeHeatmap`.
- `mobile/lib/screens/reports/income_heatmap_tab.dart` (nuevo) — widget
  del tab.
- `mobile/lib/screens/reports_screen.dart` — 10 → 11 tabs.
- `mobile/lib/screens/onboarding_screen.dart` — 11ª fila slide 3.
- `mobile/lib/screens/help_screen.dart` — "11 pestañas" + bullet.
- `mobile/pubspec.yaml` — bump `0.16.4+86` + comentario del sprint.
- `mobile/android/app/build.gradle.kts` — `versionCode = 86`,
  `versionName = "0.16.4"`.
- `mobile/test/data/reports_test.dart` — grupo nuevo `incomeHeatmap`
  + grupo `IncomeHeatmap.intensityFor`.
- `mobile/test/screens/reports/income_heatmap_tab_test.dart` (nuevo).
- `mobile/test/screens/reports/credit_cards_tab_test.dart` — WT-15
  conteo 10 → 11 (por confirmar durante T013).

Sin cambios en:

- Schema o migraciones (`database.dart`).
- DAOs (`entries_dao.dart`, `categories_dao.dart`).
- `EntriesFilters` (drill-down inline con `kinds: ['income']`).
- CLAUDE.md.

## Entidades y estados afectados

- **JournalEntry**: solo lectura. Se consultan `kind`, `occurred_at`,
  `amount`, `deleted_at`.
- **`IncomeHeatmap`** (nuevo, en memoria): inmutable, vive dentro del
  stream. Sin persistencia.
- **`IntensityLevel`** (enum reusado): sin cambios.
- **Estado de UI del tab**:
  - `_focusedYear` (int; invariante: año calendario válido).
  - `_stream` (recreado al cambiar `_focusedYear`).
  - `_lastHeatmap` (`IncomeHeatmap?` cacheado, patrón A2 quality review
    del gastos).
- **Sin invariantes nuevos sobre el dominio**: vista derivada.

## Compatibilidad con datos y procesos existentes

- **Datos históricos**: cualquier BD existente funciona; la query no
  requiere columnas nuevas.
- **Reportes vecinos**: `spendingByCategory`, `incomeByCategory`,
  `cashflowByMonth`, `movementsByDay`, `spendingHeatmap`, etc. no se
  tocan.
- **Drill-down a `/entries`**: reusa el parser existente
  `EntriesFilters.parse`. Sin cambios en el screen del drill-down.
- **Import de backup JSON v1**: cero impacto.
- **Onboarding + Help**: cambios de texto puros. Tests widget
  existentes no verifican conteo exacto ni texto completo — siguen
  verdes.

## Cambios de datos si aplica

No aplica.

## Cambios de API si aplica

No aplica.

## Cambios de integraciones si aplica

No aplica.

## Cambios de UI si aplica

- Nuevo 11º tab "Heatmap ingresos" al final del TabBar de `/reports`.
- Onboarding slide 3: 11ª fila con `Icons.grid_view` (mismo ícono que
  10º "Heatmap") + `FincoreColors.positive` + label "Heatmap ingresos".
- Help FAQ: prefacio "11 pestañas" + bullet nuevo.
- Sin cambios en Dashboard, `/entries`, `/settings`, forms.

## Cambios de permisos si aplica

No aplica. Single-user.

## Riesgos tecnicos

- **R1 — Overflow del TabBar con 11 tabs en cel chico**: label "Heatmap
  ingresos" (16 chars) es más largo que "Heatmap" (7 chars). Validar en
  SM-01. Si overflowea, considerar acortar a "Ingresos ⚡" o similar en
  patch UX futuro.
- **R2 — Confusión visual entre heatmap gastos y ingresos**: adyacentes
  en el TabBar. Mitigado por color (rojo vs verde) + label distinto.
  Validar SM en cel real.
- **R3 — Duplicación de código con heatmap gastos**: intencional. Los
  archivos son casi idénticos (~500 líneas cada uno). Cambios futuros
  aplican en ambos. Registrado como TD (mismo patrón que
  `spending_by_category_tab.dart` vs `income_by_category_tab.dart`).
- **R4 — Onboarding con 11 filas**: patrón
  `SingleChildScrollView + LayoutBuilder + ConstrainedBox +
  IntrinsicHeight` acomoda scroll interno. Validar SM.
- **R5 — Cuartiles con distribuciones raras** (sueldo mensual único
  masivo vs freelance disperso): la escala relativa hace su trabajo;
  aceptable.
- **R6 — Reactividad ante cancelaciones de gastos** (no ingresos): la
  query filtra `kind='income'`, así que `readsFrom: {journalEntries}`
  re-emite pero el resultado es el mismo. Trade-off pequeño aceptable.

## Estrategia de pruebas

Ver `test-plan.md`. Foco:

- **UT servicio** (11 tests): mirror simétrico de UT-HM01..11 (año
  vacío, 1-3 ingresos → fallback, 4+ → cuartiles, kinds excluidos —
  ahora `expense`/`transfer`/`debt_payment` NO cuentan, soft delete,
  múltiples ingresos mismo día, bordes de año, cruce de años,
  reactividad con `emitsThrough`).
- **UT modelo `intensityFor`** (5 tests): reuso lógico del pattern del
  spending, ajustados con nombre del modelo `IncomeHeatmap` y campo
  `dayIncome`.
- **Widget tests** (4-5): render año vacío (con banner), con 1 income
  → leyenda visible, tap flecha cambia año, tap mini + tap día →
  drill-down con `kinds=['income']` (siembra 1 income + 1 expense el
  mismo día; verifica que solo income aparece en el drill-down).
- **Regresión conteo tabs** en `credit_cards_tab_test.dart`.
- **Smokes SM-01..08 con Diego** en cel real.

## Estrategia de rollback

- Revert del commit es limpio: 5 archivos productivos + 2 test files
  ortogonales al resto.
- Sin dependencia externa → sin lock a resolver.
- Sin cambio de datos → BD queda intacta.
- APK 0.16.4+86 → reinstalar 0.16.3+85 tras `adb uninstall`.

## Orden sugerido de implementacion

1. **T001**: leer `spending_heatmap_tab.dart` como referencia estructural
   completa.
2. **T002**: modelo `IncomeHeatmap` en `reports.dart`.
3. **T003**: docstring del nuevo método + verificación de reuso de
   `_computeQuartiles` (ya privado en el archivo).
4. **T004**: método `incomeHeatmap` con SQL + `readsFrom` + helper
   `_buildIncomeHeatmap`.
5. **T005**: widget base `IncomeHeatmapTab` con header + `LayoutBuilder`
   + `_LoadingState` + `_ErrorState` funcional.
6. **T006**: `_MonthsGrid` + `_MonthMini` + `_MonthMiniPainter` con
   color positive.
7. **T007**: `_MonthDetailSheet` + `_DayCell` con textos ajustados.
   Incluye `SingleChildScrollView` (patch A1 del gastos ya aplicado).
8. **T008**: 11º tab en `ReportsScreen`.
9. **T009-T010**: onboarding + FAQ.
10. **T011**: UT servicio (11 tests) + UT modelo `intensityFor` (5
    tests).
11. **T012**: widget tests (4-5 tests).
12. **T013**: regresión conteo tabs 10 → 11.
13. **T014**: `flutter analyze` + `flutter test` completo → ≥ 534
    verdes.
14. **T015**: bump versión + APK release + verify.
15. **T016**: smokes SM-01..08 con Diego.
16. **T017**: `branch-quality-review`.
17. **T018**: commit final.

## Casos borde que condicionan la solucion

- **Año sin ingresos**: `dayIncome` vacío, `total=0`, `daysWithIncome=0`,
  cuartiles=0. `intensityFor` devuelve `none` para todo día. Se muestra
  solo el `_EmptyBanner` (leyenda oculta por consolidación consistente
  con el gastos).
- **Año con 1-3 ingresos**: fallback RN-IHM05, todos `veryHigh`.
- **Año con `daysWithIncome == 365/366`** (ingresos diarios, edge):
  cuartiles calculados con distribución uniforme.
- **Ingreso en el borde**: `'localtime'` respeta día local.
- **Año bisiesto**: mismo comportamiento que gastos (grid del mes de
  febrero acomoda 29 días).
- **Cambio rápido de año**: drift cachea; sin race.
- **Cambio de kind en categoría con ingresos asociados**: no afecta al
  heatmap porque la query filtra por `entry.kind`, no por
  `category.applies_to`.
- **Cancelación reactiva**: query re-emite tras `entriesDao.cancel(id)`.
  Cubierto por UT-IHM11.
- **Tap en spillover del sheet**: `heatmapDayForMonthPosition` retorna
  `null` → `SizedBox.shrink()` sin `InkWell`.

## Preguntas o supuestos que siguen afectando la implementacion

Ninguna pregunta bloqueante.

Supuestos que se mantienen desde la spec:

- Color positive (verde) para todos los niveles del gradient.
- Label del tab "Heatmap ingresos" — validar overflow en cel chico.
- Ícono `Icons.grid_view` + positive en onboarding (mismo ícono que
  heatmap gastos, diferencia por color).
- Duplicación del widget y sub-widgets (patrón del proyecto).
- Bump `0.16.4+86`: patch minor por feature aditiva sin dep externa.
- Reuso de `heatmapDayForMonthPosition` (top-level público) y
  `IntensityLevel` (enum) sin duplicar.

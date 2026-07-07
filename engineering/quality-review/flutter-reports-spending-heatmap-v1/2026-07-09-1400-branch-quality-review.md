# Branch quality review — flutter-reports-spending-heatmap-v1

**Fecha:** 2026-07-09
**Slug del sprint:** `flutter-reports-spending-heatmap-v1`
**Rama:** `main` (cambios sin commit sobre HEAD `6b25988`)
**Diff bajo revisión:** `git diff HEAD` (10 archivos: 5 código/tests + 4 docs + 2 versionado)

## Alcance

Sprint aditivo puro sin dependencias externas. Nuevo 10mo tab "Heatmap" en `/reports` con:

- Modelo `SpendingHeatmap` + enum `IntensityLevel` + método `ReportsService.spendingHeatmap({year})` (SQL con `strftime('%Y-%m-%d', 'localtime')` + cuartiles calculados en Dart, con fallback `(0,0,0)` cuando hay <4 datos).
- Widget `SpendingHeatmapTab` con **grid 3×4 de mini-heatmaps mensuales** (rediseño mayor post-smoke: original año-completo estilo GitHub → mini-heatmaps → **bottom sheet expandible al tapear un mes** con drill-down por día).
- 20 tests iniciales (11 UT servicio + 5 UT modelo + 4 widget).

Se ejecutaron **3 agentes en paralelo** con asignación de modelo por criterio: 2 Haiku para verificaciones estructuradas (SQL correctness + cobertura de tests) y 1 Sonnet para el análisis con criterio (frontend + widget + sheet expandido).

## Hallazgos por severidad

### Media — Bottom sheet sin scroll wrapper: potencial overflow en landscape

**Archivo:** `mobile/lib/screens/reports/spending_heatmap_tab.dart:342-419`

**Descripción:** `_MonthDetailSheet.build` retornaba `SafeArea > Padding > Column(mainAxisSize.min)` sin envoltorio scrollable. En landscape típico (720×360 usable), el grid de un mes de 6 filas ocupa ~618 px solo el grid + ~50 px de header + weekday + total ≈ 670 px vs 360 px disponibles → `RenderFlex overflow` con rayas amarillo/negro.

**Impacto:** UX rota en landscape. Portrait no afectado (típico uso FinCore) pero AndroidManifest no bloquea rotación.

**Estado: RESUELTO (A1)** — envuelto en `SingleChildScrollView(physics: ClampingScrollPhysics())`.

---

### Alta — Sheet drill-down sin cobertura de widget test

**Archivo:** `mobile/test/screens/reports/spending_heatmap_tab_test.dart` (previo a fix)

**Descripción:** Los WT-HM01..04 fueron escritos para el diseño original (año-completo con hit-testing directo). El rediseño introdujo el flujo mini → sheet → celda → drill-down; ninguno de los 4 tests originales lo ejercitaba. Un refactor futuro podría romperlo silenciosamente.

**Estado: RESUELTO (A2 parcial)** — nuevo `WT-HM05` que abre el sheet tapeando el mini del mes actual, tapea un día con gasto, y verifica que el drill-down muestra `HeatmapDrillDownExpense` pero NO `HeatmapDrillDownIncome` (blindaje del filter `kinds`).

---

### Alta — `_dayForMonthPosition` sin UT unitario

**Archivo:** `mobile/lib/screens/reports/spending_heatmap_tab.dart:536-546`

**Descripción:** Función pura crítica que convierte celda `(column, row)` a `DateTime` en cada mini-heatmap y en el sheet expandido. Sin test unitario directo. Bugs de off-by-one afectarían todo el hit-testing.

**Estado: RESUELTO (A2)** — renombrada a `heatmapDayForMonthPosition` (top-level público) + 6 UT que cubren feb 2026 (empieza domingo), enero 2026 (empieza jueves, spillover pre-mes), spillover post-mes, año bisiesto 2028 (29 de febrero), y último día.

---

### Alta — Drill-down no validaba `kinds`

**Archivo:** `mobile/lib/screens/reports/spending_heatmap_tab.dart:73-83`

**Descripción:** El drill-down desde el sheet construye `EntriesFilters` con `kinds: ['expense', 'credit_expense']`. Si alguien cambiara ese literal a incluir `income` accidentalmente, los tests no fallarían.

**Estado: RESUELTO (T3 resuelto con T1)** — WT-HM05 siembra 1 income + 1 expense el mismo día y verifica que solo el expense aparece.

---

### Baja — Leyenda y banner "sin gastos" se muestran juntos y son redundantes

**Archivo:** `mobile/lib/screens/reports/spending_heatmap_tab.dart:145-150`

**Descripción:** Cuando `heatmap.daysWithSpending == 0`, se renderiza tanto `_Legend` (con swatches y "Total: $0.00 · 0 días con gasto") como `_EmptyBanner`.

**Estado: NO ACCIONAR** — cosmético. Puede consolidarse en un patch UX futuro.

---

### Baja — `_MonthMini` sin affordance de tap descubrible

**Archivo:** `mobile/lib/screens/reports/spending_heatmap_tab.dart:245-301`

**Descripción:** El mini es `InkWell` sin borde ni chevron. Un usuario primerizo puede no saber que es tapeable.

**Estado: NO ACCIONAR** — Diego lo descubrió naturalmente; sin fricción real observada.

---

### Baja — Reactividad del sheet stale

**Archivo:** `mobile/lib/screens/reports/spending_heatmap_tab.dart:100-109`

**Descripción:** Si el usuario registra un gasto mientras el sheet está abierto, el grid principal se actualiza pero el sheet mantiene el snapshot viejo hasta cerrar+reabrir.

**Estado: NO ACCIONAR** — edge case (usuario típico no registra desde el sheet). Documentado como limitación conocida.

---

### Notas (accionadas)

- **N1 (`_MonthLabel` hardcodea `year=2026`)**: **RESUELTO (A3)** — recibe `year` real en constructor.
- **N2 (duplicación switch `IntensityLevel → Color` en 3 lugares)**: **RESUELTO (A4)** — extraído `_colorForIntensity` top-level; `_DayCell`, `_MonthMiniPainter` y `_Legend._swatch` lo consumen.

### Notas (no accionadas)

- **N3 (`_lastHeatmap` no se resetea al cambiar año)**: defensivo opcional. Sin bug real hoy — el StreamBuilder resetea el grid a Loading antes de re-emit.
- **CB-15/16 sin UT específico**: cubierto lógicamente por la fórmula `(totalCells / 7).ceil()` y `DateTime` rollover.
- **Tests de onboarding/help sin WT nuevo**: cambios de texto puros; smoke SM-06/SM-07 suficientes.

## Fixes aplicados antes del commit

| ID | Sev | Fix | Costo |
|---|---|---|---|
| A1 | Media | `SingleChildScrollView` en `_MonthDetailSheet` | ~5 min |
| A2 | Alta | Rename helper a público + 1 WT del sheet drill-down + 6 UT de `heatmapDayForMonthPosition` | ~25 min |
| A3 | Nota | `_MonthLabel` recibe `year` real | ~1 min |
| A4 | Nota | Extraído `_colorForIntensity` top-level | ~5 min |

Total: ~36 min de trabajo, todo blindaje real.

## Riesgos residuales

- **Reactividad del sheet stale** (edge case, no accionado).
- **Rotación de pantalla**: ahora blindada por scroll wrapper, pero validar visualmente en cel real.
- **N3** (`_lastHeatmap` no reseteado): defensivo opcional futuro.

## Pruebas ejecutadas por el sprint

- `flutter analyze` limpio (4 hints info pre-existentes tolerados).
- `flutter test` → **519/519 verdes** (492 baseline pre-heatmap + 20 originales del sprint + 7 nuevos post-fix).
- Build APK release `--split-per-abi` OK; `verify-apk.sh` OK con versionCode 2083 / versionName 0.16.1.
- Smokes SM-01..07 confirmados por Diego en cel real ("Me encantó! muy bien!").

## Recomendación de merge

**APTO PARA COMMIT** tras aplicar A1-A4. Los hallazgos accionables blindaron el sprint sin cambiar la funcionalidad. Los diferidos (Baja, N3) son cosméticos o TDs sin impacto observable.

## Pendientes sugeridos para sprints futuros

- **UX polish opcional**: hint discreto en `_MonthMini` que sugiera "tap para expandir" (H5 diferido).
- **Reactividad del sheet**: convertir `_MonthDetailSheet` en `StatefulWidget` con su propio `StreamBuilder` si Diego reporta datos stale al usar (H2 diferido).
- **Consolidar leyenda + empty banner**: unificar cuando `daysWithSpending == 0` (H4 diferido).
- **Sprint de A11Y global** (arrastrado del calendar): agregar `flutter_localizations` + delegates.

# Branch quality review — flutter-cashflow-monthly-breakdown-v1

**Fecha:** 2026-07-13
**Slug del sprint:** `flutter-cashflow-monthly-breakdown-v1`
**Rama:** `main` (cambios sin commit sobre HEAD `96ef6b0`)

## Alcance

Feature aditiva: nuevo bottom sheet en el tab "Cashflow mensual" con
desglose por categoría + drill-down a `/entries` filtrado al mes.

3 agentes en paralelo (2 Sonnet + 1 Haiku).

## Hallazgos por severidad

### BLOQUEANTE — Drill-down `router.push('/entries', extra:...)` no aplica el filtro

**Archivo:** `mobile/lib/screens/reports/cashflow_tab.dart:678-683`

**Descripción:** `EntriesListScreen` NO lee `state.extra` — solo parsea
`GoRouterState.of(context).uri.queryParameters` con
`EntriesFilters.parse(params)`. El drill-down abría `/entries` con
`EntriesFilters.thisMonth()` default en lugar del rango del mes tapeado.
WT-CB04 no lo detectó porque el mes anclado coincide con el mes actual
(cae en el mismo default).

**Estado: RESUELTO (A1)** — cambiado a
`router.push(EntriesFilters.forMonth(...).toDeepLink())` (patrón oficial
del proyecto, heredado del calendar y heatmap tabs).

---

### Alta — WT-CB03 no valida el escenario del test-plan

**Archivo:** `mobile/test/screens/cashflow_tab_test.dart:168-182`

**Descripción:** El test-plan pedía "fila con ceros del mes vacío → sheet
con fallback". El test original verificaba lo opuesto (BD vacía → NO hay
filas). La UI del fallback del sheet quedaba sin cobertura de widget.

**Estado: RESUELTO (A5)** — WT-CB03 renombrado como blindaje regresivo
del empty state del tab; agregado WT-CB05 nuevo que fuerza el escenario
con preset "Año" + 1 movimiento en el mes actual, tapea una fila del
mes vacío y verifica el fallback "Sin movimientos en este mes."

---

### Media — `_BreakdownSummary` sin ellipsis en montos largos

**Archivo:** `mobile/lib/screens/reports/cashflow_tab.dart:794-861`

**Descripción:** Los 3 `Text` de monto (`totalIncome`, `totalExpense`,
`net`) con `fontSize: 15, fontWeight: w700` en `Expanded > Column`
pueden desbordar sin ellipsis en cels angostos con montos de 7+ dígitos.

**Estado: RESUELTO (A2)** — agregado `maxLines: 1, overflow:
TextOverflow.ellipsis` a los 3.

---

### Media — Semántica del `Icons.chevron_right`

**Archivo:** `mobile/lib/screens/reports/cashflow_tab.dart:520-524`

**Descripción:** `chevron_right` en el proyecto y en Material design
señala "push a nueva pantalla". El tap real abre un `showModalBottomSheet`.
Fricción cognitiva menor.

**Estado: RESUELTO (A3)** — cambiado a `Icons.expand_more` que
semánticamente indica "expandir/mostrar más" (bottom sheet). WT-CB01/02
/04 actualizados de `find.byIcon(Icons.chevron_right)` a `expand_more`.

---

### Media — Gap CB-P02 (FK huérfana) sin UT explícito

**Archivo:** `mobile/test/data/reports_test.dart`

**Descripción:** El sentinel `applies_to == null` en el helper cubre
categorías archivadas (UT-CB06) Y FK huérfanas (backup legacy con
`category_id` colgante). Solo el primero estaba blindado.

**Estado: RESUELTO (A6)** — UT-CB16 nuevo simula backup legacy con FK
huérfana: usa `PRAGMA foreign_keys = OFF` temporal para hacer
`UPDATE journal_entries SET category_id = <ghost_uuid>` y verifica que el
bucket colapsa a "Sin categoría".

---

### Baja — `showModalBottomSheet` sin `useSafeArea: true`

**Archivo:** `mobile/lib/screens/reports/cashflow_tab.dart:443-453`

**Descripción:** Sin `useSafeArea: true`, en cels con notch el título
del sheet puede quedar tapado cuando el sheet crece a full screen.

**Estado: RESUELTO (A4)** — flag agregado.

---

### Baja — Alineación del "Neto" desplazada 22px por el nuevo ícono

**Archivo:** `mobile/lib/screens/reports/cashflow_tab.dart:499-525`

**Descripción:** El `SizedBox(width: 6) + Icon(size: 16)` empuja la
alineación derecha del texto del `Neto` respecto del chart de arriba.

**Estado: NO ACCIONAR** — cosmético menor; el ícono es affordance
necesaria del tap.

---

### Notas informacionales (Data + SQL — Sonnet)

- **Divergencia timezone** entre `cashflowByMonth` (UTC) y
  `cashflowMonthBreakdown` (localtime): aceptada por R6 del plan.
- **Índice no aprovechado** por `strftime(...) = ?` sobre columna
  indexada: aceptable single-user. Alternativa futura documentada
  (`occurred_at BETWEEN ? AND ?` calculado en Dart).
- **`applies_to == null` como sentinela** depende de schema NOT NULL:
  documentado con comentario explicativo en el helper (A7).
- **`_BreakdownAccumulator` colapso** preserva metadata del primer
  insert: documentado con comentario explicativo (A7).

### Nota Frontend

- **`didUpdateWidget` pendiente**: sheet es one-shot; si en el futuro
  se agrega swipe intermes hay que reasignar el stream. Documentado en
  el resumen-extenso.

### Notas Tests

- Gaps CB-14 (timezone borderline), CB-15 (30+ categorías), CB-16
  (subsegundo), CB-17 (rango-change), CB-P03/P04 (amount ≤ 0):
  cubiertos lógicamente o smoke.

## Fixes aplicados antes del commit

| ID | Sev | Fix | Costo |
|---|---|---|---|
| A1 | BLOQUEANTE | drill-down `.toDeepLink()` | 2 min |
| A2 | Media | ellipsis en 3 montos summary | 3 min |
| A3 | Media | `Icons.expand_more` | 1 min |
| A4 | Baja | `useSafeArea: true` | 1 min |
| A5 | Alta | renombrar WT-CB03 + WT-CB05 nuevo | 8 min |
| A6 | Media | UT-CB16 FK huérfana | 5 min |
| A7 | Nota | 2 comentarios doc | 1 min |

Total: ~21 min. Todos con impacto real de correctness (A1), robustez
UI (A2/A4), semántica UX (A3), o cobertura (A5/A6).

## Pruebas ejecutadas post-fix

- `flutter analyze` limpio (solo hint info pre-existente en skeleton).
- `flutter test` → **560/560 verdes** (539 baseline + 21 nuevos:
  14 UT servicio + 2 UT filtro + 5 widget).
- Build APK release `--split-per-abi` OK.

## Recomendación de merge

**APTO PARA COMMIT** tras aplicar A1-A7. El bloqueante A1 rompía la
feature principal del sprint (drill-down al mes real); el fix pone al
patrón oficial del proyecto.

## Pendientes sugeridos para sprints futuros

- **Uniformar timezone** entre `cashflowByMonth` y
  `cashflowMonthBreakdown` (ambos a `localtime`) para eliminar
  divergencia visible en movimientos borderline.
- **Índice compuesto sobre `occurred_at`** para acelerar el filtro
  strftime si el dataset crece a 10k+ entries.
- **`didUpdateWidget` en `_MonthBreakdownSheet`** si en el futuro se
  agrega swipe intermes.

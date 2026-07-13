# Branch quality review — flutter-cashflow-breakdown-prev-comparison-v1

**Fecha:** 2026-07-13
**Slug:** `flutter-cashflow-breakdown-prev-comparison-v1`
**Rama:** `main` (sin commit sobre HEAD `2f18042`, 3 commits ahead de origin)

## Alcance

Extensión aditiva del sprint padre. Chip vs mes anterior en cada
`_CategoryFlowRow` + 3 chips en el `_BreakdownSummary` con semántica
"impacto en bolsillo".

3 agentes en paralelo (2 Sonnet + 1 Haiku). Sin bloqueantes ni altas.

## Hallazgos por severidad

### Media — `flat` visualmente indistinguible de `null`

**Archivo:** `mobile/lib/screens/reports/cashflow_tab.dart:1013-1073`

**Descripción:** El caso `null` (bucket sin data previa) muestra
`Text('—')` en `textMuted`. El caso `flat` (monto idéntico) muestra
`Icons.remove` (línea horizontal 12px) + `Text('0.0%')` también en
`textMuted`. Visualmente muy similares en primera lectura — se pierde
el mensaje semánticamente importante de "gasté/ingresé exactamente
igual que el mes previo".

**Estado: RESUELTO (A2)** — cambiado `Icons.remove` → `Icons.drag_handle`
(dos líneas apiladas). Distintivo visual claro del em-dash textual.

---

### Media — Label ellipsizea antes por chip nuevo

**Archivo:** `mobile/lib/screens/reports/cashflow_tab.dart:944-1004`

**Descripción:** El chip agrega ~66 px de widgets fijos en el
`_CategoryFlowRow`. En viewport de ~400 px (cel angosto tras 40 px
padding), el `Expanded(label)` cae de ~172 px a ~114 px, ellipsizando
5-8 chars antes que en el sprint padre.

**Estado: RESUELTO (A3)** — chip reducido de 62 → 58 px. Ahorro
combinado con reducciones previas de spacing y `Flexible` interno
del chip.

---

### Media — Gap CB-14 (categoría archivada entre meses) sin UT

**Archivo:** `mobile/test/data/reports_test.dart`

**Descripción:** El plan documenta 18 casos borde; los 11 tests
nuevos cubrían 15 explícitamente. Gap crítico: CB-14 (categoría
activa en el previo, archivada durante el mes actual). Puede colapsar
el bucket actual a "Sin categoría" mientras el bucket previo mantiene
la categoría real → matching debería fallar sin fix.

**Estado: RESUELTO (A6)** — UT-CP10 nuevo. Sembra categoría dedicada,
registra en previo y actual, después la archiva. Verifica que:
1. Ambos meses colapsan a "Sin categoría" (categoryId=null).
2. Ambos buckets matchean por null.
3. Delta calculado correctamente (75% up para 700 vs 400).

Confirma que la implementación es correcta — el sentinel
`applies_to == null` del LEFT JOIN cubre ambos meses simétricamente.

---

### Baja — `TextOverflow.clip` corta % extremos silenciosamente

**Archivo:** `mobile/lib/screens/reports/cashflow_tab.dart:1062-1070`

**Descripción:** Con `clip`, escenarios de deuda-a-cero (previo $10 →
actual $10k = +99900%) cortan el texto sin señal visual. El usuario
lee un número mutilado.

**Estado: RESUELTO (A4)** — cap visual `>999%` + `TextOverflow.ellipsis`
como red de seguridad. La dirección ya la comunica el ícono;
magnitud sobre 999% no aporta valor accionable.

---

### Baja — 3 `Align(centerLeft)` redundantes en el summary

**Archivo:** `mobile/lib/screens/reports/cashflow_tab.dart:824-830, 857-863, 890-898`

**Descripción:** `Column(crossAxis: start) + Row(mainSize: min)` ya
alinea el chip a la izquierda. Los `Align` no cambian el resultado
visual; ruido en el árbol.

**Estado: RESUELTO (A5)** — 3 Align eliminados, `_DeltaChip` queda
directo como child del Column.

---

### Nota — Guard `previous <= 0` amplía RN-CP09

**Archivo:** `mobile/lib/data/reports.dart:658-668`

**Descripción:** RN-CP09 solo exige `null` cuando `previo == 0`. El
guard implementado extiende a `previous <= 0` (incluye negativos —
decisión conservadora). Documentado en el docstring del helper pero
sin trazabilidad formal.

**Estado: RESUELTO (A1)** — documentado en `desviaciones-plan.md` D4
con análisis del edge de neto negativo y follow-up sugerido para
sprint futuro.

---

### Notas informacionales adicionales

- **`_computeDelta(0, 0) → null`** en vez de `flat`. Cosmético en
  edge muy raro (mes previo y actual con income==expense idénticos).
  Aceptable.
- **Tolerancia absoluta 0.01** puede confundir buckets sub-peso.
  Diego no maneja centavos. Aceptable.
- **`strftime` recomputado 2×** por row (SELECT + WHERE). Negligible
  en single-user < 1k mov/mes.
- **`continue` defensivo del helper** es dead code por WHERE. Blindaje
  aceptable ante refactors futuros.
- **Divergencia timezone R6** del sprint padre sigue vigente y
  documentada; coherente dentro del sheet.
- **WT-CP01 con `now.month - 1`** puede dar mes 0 en enero — Dart
  normaliza, test pasa. UT-CP07 blinda el rollover explícitamente.
- **Matriz `_deltaColor` verificada correcta** contra RN-CP07 con
  switch exhaustivo. Bloqueo compile-time si se agrega valor al enum.

## Fixes aplicados antes del commit

| ID | Sev | Fix | Costo |
|---|---|---|---|
| A1 | Nota | Doc guard `previous <= 0` en desviaciones-plan.md | 3 min |
| A2 | Media | `flat`: `Icons.remove` → `Icons.drag_handle` | 1 min |
| A3 | Media | Chip 62 → 58 px | 1 min |
| A4 | Baja | Cap `>999%` visual + ellipsis en Text del chip | 3 min |
| A5 | Baja | Quitar 3 `Align(centerLeft)` del summary | 2 min |
| A6 | Media | UT-CP10 nuevo blinda CB-14 (categoría archivada entre meses) | 5 min |

Total: ~15 min.

## Pruebas ejecutadas post-fix

- `flutter analyze` limpio (solo hint info pre-existente en skeleton).
- `flutter test` → **572/572 verdes** (571 previos + UT-CP10 nuevo).
- Build APK release `--split-per-abi` OK.

## Recomendación de merge

**APTO PARA COMMIT** tras aplicar A1-A6. Sin bloqueantes; las 3 Media
resueltas son mejoras de UX real (distinción `flat`/`null`, ancho de
label, cobertura de CB-14). Las 2 Baja son polish visual + robustez de
edge cases.

## Pendientes sugeridos para sprints futuros

- **Reevaluar guard `previous < 0`** si Diego observa que el deltaNet
  se apaga con déficit consistente en meses previos.
- **Follow-up UX del `flat`**: si en smoke real (SM-01) Diego confunde
  `drag_handle` con `—`, considerar cambiar el color de `flat` a
  `textSubtle` o agregar signo `=` explícito en el text.
- **Cobertura de CB-P01..P03** (`applies_to='both'` cambiado de lado,
  movimiento con fecha cambiada, rango cambiado con sheet abierto)
  puede sumarse como UT si aparece regresión — hoy cubierto por smoke.

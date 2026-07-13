# Desviaciones respecto al plan

## D1 — Ajuste de spacing por overflow (widget tests)

**Plan**: chip de 62 px, percent 44 px, spacing 8 px.

**Ejecución**: los widget tests descubrieron overflow de 22-28 px en el
`_CategoryFlowRow`. Ajuste iterativo hasta encontrar el balance final
(post-quality-review):

- Chip: 62 → 58 px (A3 del quality-review).
- Percent width: 44 → 38 px.
- Spacing entre elementos: 8 → 6 → 4 en varios puntos.
- `Flexible` interno en el Text del chip con `ellipsis` + cap `>999%`
  para blindar percents extremos.

**Motivo**: el chip agrega ancho fijo real de ~58 px. Sin ajustes de
spacing complementarios el label de categoría se ellipsizea muy
temprano.

**Riesgo residual**: labels de categoría largos (20+ chars) siguen
ellipsizando en cel angosto. Aceptable; el smoke SM-01 lo validará.

## D2 — `Flexible` + `overflow: ellipsis` en el Text del chip

**Plan**: no lo especificaba.

**Ejecución**: agregado durante T007 (fix inicial post-widget-test) y
consolidado en A4 del quality-review con cap `>999%`. Sin `Flexible`
el Row del chip overflow por 2-4 px con percents de 3-4 dígitos.

**Motivo**: `SizedBox(width: 58)` restringe el ancho del chip, pero el
`Row(mainAxisSize: min)` interno intenta ocupar solo lo necesario. Un
percent con 5+ chars ("100.0%") + ícono + spacing puede exceder los
58 px. `Flexible` + `ellipsis` + cap `>999%` cubre todos los casos.

## D3 — Escape de `$` en títulos de test

**Plan**: no lo especificaba.

**Ejecución**: los strings de test con `$2000`, `$1000` etc. rompían
la compilación por interpolación Dart. Cambiado a `\$` (escape). Solo
cosmético.

## D4 — Guard `_computeDelta(current, previous)` con `previous <= 0`

**Plan y spec (RN-CP09)**: dicen `null` cuando `previo == 0` (evita
`+∞%` / `+100%` engañoso).

**Ejecución**: el guard implementa `previous <= 0 → null`,
extendiendo a `previous < 0` también. Detectado en el branch-quality-review
como decisión no documentada.

**Motivo**: cuando el neto previo es negativo (déficit del mes previo),
calcular `delta = (net_actual - net_previo) / |net_previo|` produce
resultados semánticamente confusos. Ej: previo `-300`, actual `+100`
→ `diff = +400, magnitud = 400/300 = 133% up`. Pero para el usuario,
"mejoré mi neto" es una lectura correcta y **positiva** — mostrar `up`
con color positivo desde `deltaColor(direction=up, isExpenseSide=false)`
= verde funciona. Sin embargo, el caso opuesto (previo `-300`, actual
`-500` → `diff = -200, magnitud = 200/300 = 66% down`) también daría
verde para el lado neto (down + isExpenseSide=false = negative =
rojo), pero semánticamente el usuario "gastó más" — el color rojo es
correcto.

**Ambos casos anteriores** funcionan bien con la magnitud como está.
La decisión conservadora `previous <= 0 → null` fue por simplicidad
inicial, evitando debatir el edge complejo.

**Riesgo residual**: usuario con déficit consistente (gasta más de lo
que ingresa) no ve delta del neto — la feature se apaga silenciosamente
para él. Es un edge minoritario en el uso típico single-user.

**Follow-up sugerido**: sprint futuro puede revisar y decidir si:
- (a) mantener el guard actual (conservador),
- (b) permitir `previous < 0` con la fórmula estándar,
- (c) permitir `previous < 0` pero con lógica invertida en `direction`
  para reflejar "más déficit = peor".

Documentado como pendiente en el implementation-review para reevaluar
si Diego observa el edge en uso real.

## D5 — Test WT-CP01 con `now.month - 1`

**Plan y test-plan**: los widget tests usan `now.month - 1` para
seed previo.

**Ejecución**: si el test corre en enero, `DateTime(now.year, 0, 10, 12)`
tiene mes 0 pero Dart lo normaliza automáticamente a diciembre año
anterior. El test pasa en cualquier mes.

**Motivo**: patrón implícitamente robusto por diseño de Dart. UT-CP07
explícitamente cubre el rollover con `DateTime(2026, 1, 15)` →
`DateTime(2025, 12, 15)`.

**Aceptado**: no requiere fix.

## D6 — Fixes post branch-quality-review (A1..A6)

El quality-review detectó **0 bloqueantes**, **2 Media Frontend** +
**1 Media Tests** + **2 Baja Frontend** + notas menores. Todos
aplicados:

- **A1 (D4 arriba)**: doc guard `previous <= 0`.
- **A2 (Media F1)**: `Icons.remove` → `Icons.drag_handle` para `flat`,
  visualmente más distinto del em-dash `—` de `null`.
- **A3 (Media F2)**: chip 62 → 58 px para reducir presión sobre el
  label de categoría en cel angosto.
- **A4 (Baja F3)**: cap `>999%` visual + `TextOverflow.ellipsis` en
  el Text del chip. Blindaje contra percents extremos que no cabían.
- **A5 (Baja F4)**: quitar los 3 `Align(centerLeft)` redundantes del
  summary. `Column(crossAxis: start) + Row(mainSize: min)` ya alinea.
- **A6 (Media Tests)**: UT-CP10 nuevo blinda CB-14. Categoría
  archivada durante el mes actual → ambos meses colapsan a "Sin
  categoría" (categoryId=null) → matchean correctamente por null,
  delta calculado.

Reporte completo en
`engineering/quality-review/flutter-cashflow-breakdown-prev-comparison-v1/2026-07-13-branch-quality-review.md`.

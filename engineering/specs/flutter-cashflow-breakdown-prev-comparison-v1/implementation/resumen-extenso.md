# Resumen extenso — flutter-cashflow-breakdown-prev-comparison-v1

## Contexto

Extensión del sprint `flutter-cashflow-monthly-breakdown-v1` (commit
`a424345`). El sheet actual del breakdown mensual muestra el
desglose por categoría del mes, pero no compara contra el mes previo.
Este sprint agrega la comparación bucket-por-bucket con un chip
pequeño de delta %, aprovechando la misma query reactiva (extendida)
y sin cambios de schema.

Decisiones tomadas antes de spec (via AskUserQuestion):

1. **UX**: chip pequeño al lado del percent en la misma fila
   `_CategoryFlowRow` + 3 chips en el summary. No línea aparte ni
   solo header.
2. **Semántica de color**: "impacto en bolsillo" — colores según si
   el cambio beneficia o perjudica al usuario (verde/rojo no
   coinciden 1:1 con el signo numérico).
3. **Sin data previa**: mostrar `—` sin color (categoría nueva o
   previo con total 0 → RN-CP09).
4. **Query única**: extender el SQL con `IN (?, ?)` y `month_key` —
   un solo `customSelect.watch()`, un solo re-emit.

## Relación con `plan/plan.md` y `plan/tasks.md`

Se ejecutaron **T001-T013 completas** en el orden del plan.
**T014 (smokes) explícitamente diferida** por decisión de Diego (no
puede instalar ahora; batch acumulado con los pendientes anteriores).
**T015 (branch-quality-review) + T016 (commit)** pendientes.

RF cubiertos:

- RF-001..003: query extendida + helper con 4 acumuladores.
- RF-004..005: modelos nuevos + extensión aditiva.
- RF-006..008: UI (chip, summary, helper `_deltaColor`).
- RF-009: FAQ.
- RF-010: tests.
- RF-011: bump.

RN-CP01..CP12 implementadas y verificadas con UT + WT.

## Cambios principales por módulo o capa

### Data (`mobile/lib/data/reports.dart`)

- Nuevos modelos:
  - `enum DeltaDirection { up, down, flat }`.
  - `class DeltaPercent { final double percent; final DeltaDirection
    direction; }` const-inmutable. `percent` es magnitud (siempre ≥
    0); signo via `direction`.
- Extensión aditiva de existentes:
  - `CategoryFlow.delta` (opcional).
  - `MonthBreakdown.deltaIncome`, `deltaExpense`, `deltaNet`
    (opcionales). Callers existentes siguen funcionando (los
    campos son opcionales en el constructor).
- SQL de `cashflowMonthBreakdown`:
  - Filtro cambió de `strftime = ?` a `strftime IN (?, ?)`.
  - Agrega `strftime('%Y-%m', j.occurred_at, 'localtime') AS
    month_key` al SELECT + GROUP BY.
  - `Variable.withString(currentKey)` y
    `Variable.withString(previousKey)` en el binding.
  - `readsFrom: {journalEntries, categories}` intacto.
  - Cálculo del `previousKey`: `DateTime(monthAnchor.year,
    monthAnchor.month - 1, 1)` con normalización estándar de Dart
    (enero → diciembre año anterior).
- Helper `_buildMonthBreakdown` extendido:
  - 4 acumuladores (`currentIncome`, `currentExpense`,
    `previousIncome`, `previousExpense`) segregados por `month_key`.
  - Iteración de rows: cada fila cae al acumulador correspondiente
    según `(month_key, isIncomeSide)`.
  - `flowsFrom(current, previous, total)` construye los
    `CategoryFlow` del actual con el delta calculado buscando el
    mismo `categoryId` en el previo (incluye `null` para "Sin
    categoría").
  - `deltaIncome/deltaExpense/deltaNet` calculados sobre los totales
    finales.
- Helper nuevo `_computeDelta(current, previous)`:
  - `previous <= 0` → `null` (RN-CP09).
  - `abs(diff) < 0.01` → `flat` con `percent = 0` (RN-CP04 blindaje
    floating-point).
  - `direction` según signo del `diff`.
  - `percent = |diff| / |previous| * 100`.

### UI (`mobile/lib/screens/reports/cashflow_tab.dart`)

- Widget nuevo `_DeltaChip`:
  - Constructor con `DeltaPercent? delta`, `bool isExpenseSide`.
  - `null` → `Text('—')` en `textMuted` sin ícono (RN-CP05).
  - `up` → `Icons.arrow_upward`. `down` → `Icons.arrow_downward`.
    `flat` → `Icons.remove`.
  - Color via `_deltaColor(direction, isExpenseSide)`.
  - `Flexible` alrededor del `Text` con `maxLines: 1` + `clip` para
    blindar overflow cuando el percent tiene 4+ dígitos.
- Helper puro `_deltaColor(direction, {isExpenseSide})`:
  - `flat` → `textMuted`.
  - `up + !isExpenseSide` (ingreso/neto) → `positive`.
  - `down + !isExpenseSide` → `negative`.
  - `up + isExpenseSide` (gasto) → `negative`.
  - `down + isExpenseSide` → `positive`.
- `_CategoryFlowRow`:
  - Constructor gana `bool isExpenseSide` mandatory.
  - Row extendida con `SizedBox(width: 4) + SizedBox(width: 62, child:
    _DeltaChip)` al final.
  - Ajuste de spacing: percent width 44→38, spacing 8→6→4 en varios
    puntos, para blindar overflow con el chip nuevo.
- `_BreakdownSummary`:
  - 3 chips debajo de cada monto (Ingresos, Gastos, Neto) usando
    `Align(alignment: centerLeft, child: _DeltaChip(...))`.
  - Chip neto usa `isExpenseSide: false` porque neto sube = mejor
    (coincide con lado ingresos, RN-CP08).

### Docs

- `help_screen.dart`: bullet cashflow extendido con "cada categoría
  muestra un chip vs el mes anterior: ▲ sube o ▼ baja según si el
  cambio es mejor o peor para tu bolsillo".

## Desviaciones respecto al plan

- **D1 — Ajuste de spacing por overflow**: los widget tests
  descubrieron overflow de 22 y luego 28 px en el `_CategoryFlowRow`
  con la anchura de chip original (60 px + `SizedBox(width: 8)` de
  spacing). Ajuste iterativo hasta encontrar el balance: chip 62 px
  + percent 38 px + spacings 4-4-6 = 122 px de widgets fijos
  después del label. Total del row cabe en pantalla test típica sin
  overflow, y el `Flexible` interno del chip protege contra percents
  con muchos dígitos.
- **D2 — `Flexible` en el Text del chip**: agregado para blindar
  contra overflow del texto interno cuando el percent es ≥ 100.0%
  (renderea con 5-6 caracteres + espacio del ícono). Sin `Flexible`
  el Row del chip overflow por 2-4 px en algunos escenarios.
- **D3 — Escape de `$` en títulos de test**: los strings de test con
  `$2000`, `$1000` etc. rompían la compilación por interpolación
  Dart. Cambiado a `\$` (escape). Solo cosmético.
- **D4 — Alineación del chip del summary**: el plan no
  especificaba la alineación del chip debajo del monto. Se usó
  `Align(alignment: centerLeft)` para coincidir con la alineación
  del monto (`crossAxisAlignment: CrossAxisAlignment.start` en la
  Column padre).

## Pruebas realizadas y recomendadas

### Realizadas

- `flutter analyze` limpio (solo hint info pre-existente en
  skeleton).
- `flutter test` 571/571 verdes:
  - UT-CP01..09: matemática del delta, dirección, flat, previo=0
    null, "Sin categoría" matcheado por null, bucket solo en previo
    no aparece, rollover enero→diciembre, reactividad
    (`emitsThrough`), neto que salta signo.
  - WT-CP01: 2 meses con datos → chip up con `arrow_upward` +
    `100.0%` visible en el sheet.
  - WT-CP02: solo mes actual sin previo → `—` visible al menos 4
    veces (3 chips summary + 1 chip bucket).
- APK release + `verify-apk.sh` OK (versionCode 2090 / versionName
  0.18.0).

### Recomendadas

- SM-01..05 con Diego en cel real. Batch acumulado con los ~12
  pendientes de sprints anteriores (memoria
  `pending-smokes-cashflow-breakdown`).
- Especialmente **SM-01** (visual en cel real con montos de 7-8
  dígitos + categorías largas — verificar que el chip no rompe el
  layout), **SM-03** (semántica de color con rojo/verde reales),
  **SM-04** (reactividad al registrar movimiento en mes previo con
  sheet abierto).

## Riesgos residuales y posibles regresiones

- **R2 — Signo del neto que salta**: `previous <= 0` → `null` es la
  decisión conservadora. Tests blindan el edge (UT-CP09 con neto
  previo positivo y actual negativo → `direction=down, percent=160`).
- **R6 — Divergencia timezone R6 del sprint padre**: sigue vigente
  para el tab base vs sheet. Dentro del sheet coherente (localtime
  para ambos meses).
- Cambio en el layout del `_CategoryFlowRow`: agrega ~66 px al ancho
  fijo del row. Con montos y categorías típicas caben; con extremos
  (categoría de 20+ chars + monto de 8+ dígitos + percent con 5
  dígitos + chip con 4+ dígitos) el label se ellipsizea. Aceptable.
- Cero regresión en cashflow base, otros reportes, `/entries`, forms,
  dashboard, backup.

Sprint completo excepto smoke + quality-review + commit final.

# Comparación vs mes anterior en el sheet del cashflow breakdown

## Resumen

Extensión del sprint `flutter-cashflow-monthly-breakdown-v1`. Agrega un chip pequeño de delta % al lado del percent de cada `_CategoryFlowRow` dentro del bottom sheet del cashflow. El chip compara el monto del bucket contra el mismo bucket (misma `categoryId`) del mes calendario inmediato anterior. Los 3 totales del `_BreakdownSummary` (ingresos, gastos, neto) también reciben chip delta con la misma semántica. Cero cambios de schema; extensión aditiva de la query única existente.

## Problema a resolver

El sheet del cashflow monthly-breakdown responde "¿en qué gasté este mes?" mostrando el desglose por categoría con monto y percent. Pero NO responde la pregunta natural siguiente: "¿por qué gasté más este mes que en el anterior?".

Diego hoy tiene que:
1. Cerrar el sheet.
2. Tapear la fila del mes anterior.
3. Anotar mentalmente los números de cada categoría.
4. Cerrar ese sheet, abrir el del mes actual.
5. Comparar bucket-por-bucket a ojo.

Todos los datos existen; la comparación existe conceptualmente. Solo falta que la UI la muestre lado a lado.

## Objetivo

Entregar la comparación mes vs mes anterior dentro del mismo sheet:

- Un chip pequeño al lado del percent en cada fila que compara el bucket contra el mismo bucket del mes anterior.
- 3 chips en el `_BreakdownSummary` para ingresos, gastos y neto totales.
- Semántica visual "impacto en bolsillo": color según si el cambio te beneficia o perjudica, no según signo numérico puro.
- Sin fricción de config: siempre visible cuando hay datos; `—` (guion) cuando no.
- Sin regresión de performance: query única extendida con 2 meses.

## Alcance

- **Servicio** (`mobile/lib/data/reports.dart`):
  - `ReportsService.cashflowMonthBreakdown` extendido: el SQL filtra por `strftime('%Y-%m', occurred_at, 'localtime') IN (?, ?)` con `monthKey` actual y `monthKey` previo. Agrega `strftime(...)` como columna `month_key` al SELECT + al GROUP BY.
  - Helper `_buildMonthBreakdown` separa filas por `month_key` en 2 sets: bucket del mes actual + bucket del mes previo. Match por `categoryId` (o `null` para "Sin categoría").
  - Cada `CategoryFlow` del mes actual recibe un `delta: DeltaPercent?` con la comparación. `null` cuando no hay bucket previo con esa `categoryId`.
  - `MonthBreakdown` recibe `previousTotalIncome`, `previousTotalExpense`, `previousNet` como fields opcionales para calcular el delta de los 3 totales.
  - Query `readsFrom: {journalEntries, categories}` sin cambios.

- **Modelos nuevos** (`mobile/lib/data/reports.dart`):
  - `enum DeltaDirection { up, down, flat }`.
  - `class DeltaPercent { double percent; DeltaDirection direction }` const-inmutable. El `percent` es siempre `>= 0` (magnitud); el signo se representa por `direction`.

- **Modelo extendido**:
  - `CategoryFlow` gana `final DeltaPercent? delta` (nullable).
  - `MonthBreakdown` gana `final DeltaPercent? deltaIncome`, `deltaExpense`, `deltaNet`.

- **Widget** (`mobile/lib/screens/reports/cashflow_tab.dart`):
  - `_CategoryFlowRow` renderea un chip nuevo `_DeltaChip` al final si `flow.delta != null`. Si es null, chip `—` en `textMuted`. Ícono según direction: `arrow_upward` (up), `arrow_downward` (down), `remove` (flat). Texto: percent con 1 decimal + `%`.
  - Helper `_deltaColor({required DeltaDirection direction, required bool isExpenseSide})`:
    - `up + income → positive`
    - `down + income → negative`
    - `up + expense → negative`
    - `down + expense → positive`
    - `flat → textMuted`
  - `_BreakdownSummary` gana 3 chips debajo de cada monto (ingresos, gastos, neto):
    - Chip ingresos: `_deltaColor(direction, isExpenseSide=false)`.
    - Chip gastos: `_deltaColor(direction, isExpenseSide=true)`.
    - Chip neto: `_deltaColor(direction, isExpenseSide=false)` (más neto = mejor, coincide con lado ingresos).

- **Documentación** (`mobile/lib/screens/help_screen.dart`): bullet del cashflow extendido con "El sheet compara cada categoría contra el mes anterior con un chip que sube/baja según si es mejor o peor para tu bolsillo."

- **Tests**:
  - UT servicio: match bucket-por-bucket con `categoryId` explícito.
  - UT: bucket "Sin categoría" (null) matcheado en ambos meses.
  - UT: bucket presente solo en el actual → delta null.
  - UT: bucket presente solo en el previo → NO aparece en la lista (solo mostramos buckets del actual).
  - UT: bucket idéntico → `direction = flat, percent = 0`.
  - UT: dirección correcta (`up` si actual > previo, `down` si actual < previo).
  - UT: percent con `closeTo(±0.01)` para casos redondeables.
  - UT: reactividad — cambiar movimiento del mes previo re-emite con delta actualizado (`emitsThrough`).
  - Widget tests: chip visible en filas con delta; chip `—` en filas sin previo.

- **Bump**: `0.17.1+89` → `0.18.0+90`.

## Fuera de alcance

- Comparación con mes anterior "con datos" (skip meses vacíos). Solo comparamos el mes calendario inmediato anterior.
- Comparación año vs año en el sheet.
- Detalle "en criollo" del delta (ej. "$412 más gastados"). Solo `%`.
- Chip clickeable que abre el mes previo. Sprint futuro.
- Delta en la fila del tab base (`_BreakdownRow`). La comparación queda solo dentro del sheet.
- Tooltip / long-press que muestre el monto absoluto del mes previo. Sprint futuro.
- Configuración de "vs qué mes comparar" (rolling 3 meses, promedio, etc.). Solo mes previo calendario.
- Cambio del `_MonthBreakdownRow` del tab base para mostrar delta agregado. Fuera de alcance.

## Reglas de negocio

- **RN-CP01 (mes previo canónico)**: el mes previo es el mes calendario inmediato anterior a `monthAnchor`. Ejemplo: si `monthAnchor = DateTime(2026, 3, 1)`, el mes previo es `DateTime(2026, 2, 1)`.
- **RN-CP02 (match por categoryId)**: el bucket del mes actual matchea con el del previo por `categoryId` (incluyendo `null` para "Sin categoría"). No hay match por nombre — categorías renombradas siguen siendo la misma entidad.
- **RN-CP03 (delta magnitud)**: `percent = ((actual - previo) / previo) × 100`, en valor absoluto para la magnitud. Signo se representa por `direction`.
- **RN-CP04 (direction)**:
  - `up` si `actual > previo`.
  - `down` si `actual < previo`.
  - `flat` si `actual == previo` (usar `closeTo` con tolerancia de 0.01 para floating-point).
- **RN-CP05 (delta null)**: cuando no hay bucket previo con esa `categoryId` (categoría nueva o mes previo vacío), `delta = null`. La UI muestra `—` en `textMuted`.
- **RN-CP06 (bucket solo en previo)**: NO aparece en la lista del mes actual. El sprint muestra buckets del mes actual con contexto histórico, no lista del mes previo.
- **RN-CP07 (semántica de color impacto bolsillo)**:
  - Ingresos: `up → positive` (verde), `down → negative` (rojo).
  - Gastos: `up → negative` (rojo), `down → positive` (verde).
  - Neto: `up → positive`, `down → negative` (neto sube = mejor).
  - `flat → textMuted` en todos los casos.
- **RN-CP08 (delta de totales)**: los 3 chips del summary usan los totales de cada lado (`totalIncome`, `totalExpense`, `net`). Neto puede saltar signo (positivo a negativo) — el delta se calcula sobre magnitudes por consistencia; verificar edge en test.
- **RN-CP09 (previo con total 0)**: si `previo == 0` y `actual > 0`, `delta = null` (no hay base de comparación → no mostramos `+∞%` ni `+100%` engañoso). Coincide con RN-CP05.
- **RN-CP10 (query única)**: la query filtra `strftime IN (?, ?)` con ambos meses en un solo `customSelect.watch()`. Un solo re-emit reactivo cuando cambia cualquier movimiento de cualquiera de los 2 meses.
- **RN-CP11 (timezone)**: el `strftime('%Y-%m', occurred_at, 'localtime')` sigue vigente. Divergencia con `cashflowByMonth` base (UTC) sigue documentada (R6 del sprint padre).
- **RN-CP12 (excluye `transfer`/`debt_payment`)**: sigue igual que en el sprint padre.

## Requisitos funcionales

- RF-001: extender `ReportsService.cashflowMonthBreakdown({monthAnchor})` para computar el mes previo con `DateTime(monthAnchor.year, monthAnchor.month - 1, 1)` (Dart normaliza el rollover de mes 0 → mes 12 del año anterior).
- RF-002: el SQL agrega `strftime('%Y-%m', occurred_at, 'localtime') AS month_key` al SELECT + GROUP BY, y filtra por `IN (?, ?)`.
- RF-003: helper `_buildMonthBreakdown` separa filas por `month_key`, construye buckets del actual + los buckets del previo, y calcula `delta` por match de `categoryId`.
- RF-004: nuevos modelos `DeltaPercent` (con `enum DeltaDirection { up, down, flat }`) const-inmutables.
- RF-005: `CategoryFlow.delta` opcional. `MonthBreakdown` recibe `deltaIncome`, `deltaExpense`, `deltaNet` opcionales.
- RF-006: `_CategoryFlowRow` renderea `_DeltaChip` al final. Chip con ícono según direction + percent con 1 decimal + `%`. Bucket con delta null → chip `—` en `textMuted`.
- RF-007: `_BreakdownSummary` renderea 3 chips debajo de cada monto (Ingresos/Gastos/Neto) con la semántica RN-CP07.
- RF-008: helper `_deltaColor({direction, isExpenseSide})` aplica la semántica RN-CP07.
- RF-009: FAQ del Help extendido con bullet mencionando el chip vs mes anterior.
- RF-010: 10-12 tests nuevos (8-10 UT servicio + 2-3 widget). `flutter test` completo verde.
- RF-011: bump a `0.18.0+90`.

## Casos principales

1. Diego abre Reportes → Cashflow mensual → tapea la fila de junio 2026 → sheet abre con desglose. En cada fila de categoría ve un chip pequeño al lado del percent: "Comida $3,500 41% ▲+12%" (rojo, gasté más), "Renta $2,500 29% ▼-4%" (verde, gasté menos). En el header ve el neto con "▲+8%" si su neto mejoró.
2. Diego tapea la fila de un mes donde recién apareció una nueva categoría "Salud". El chip de "Salud" muestra `—` porque no había en el mes previo.
3. Diego tapea la fila de un mes donde reciclaba una categoría que había estado 3 meses sin uso. El bucket aparece con `—` porque el mes previo no la tuvo.
4. Diego renombra "Comida" → "Alimentación" con el sheet abierto → el delta se recalcula usando el `categoryId` (no el nombre), sin perder la comparación histórica.
5. Registra un gasto nuevo en el mes previo (retrolo un ticket) → sheet re-emite con delta actualizado.

## Casos borde

- **CB-01**: Mes previo vacío (BD nueva o primer mes del usuario). Todos los buckets del actual muestran `—`. Los 3 chips del summary muestran `—`.
- **CB-02**: Bucket del actual con `categoryId` que NO existe en el previo. Delta null → chip `—`.
- **CB-03**: Bucket del previo con `categoryId` que NO existe en el actual. NO aparece en la lista (solo mostramos actual, RN-CP06).
- **CB-04**: Bucket "Sin categoría" en ambos meses. Match por `categoryId=null`. Delta calculado normal.
- **CB-05**: Bucket idéntico entre actual y previo (mismo monto). `direction=flat, percent=0`. UI: chip con ícono `remove` + `0.0%` en `textMuted`.
- **CB-06**: Actual = 100, previo = 50 → `direction=up, percent=100`. Chip `▲+100.0%`.
- **CB-07**: Actual = 50, previo = 100 → `direction=down, percent=50`. Chip `▼-50.0%`.
- **CB-08**: Previo = 0 y actual > 0 (RN-CP09). Delta null → chip `—`.
- **CB-09**: Neto salta signo (previo positivo, actual negativo). Ver test para dirección esperada. Voto: `direction = down` (neto empeoró) con percent absoluto sobre magnitudes. Documentado en RN-CP08.
- **CB-10**: `monthAnchor = enero`. Mes previo = diciembre del año anterior. Rollover verificado en UT.
- **CB-11**: Timezone borderline (mismo edge que sprint padre R6). Documentado.
- **CB-12**: Reactividad — registrar movimiento en mes previo con sheet abierto → re-emit con delta actualizado.
- **CB-13**: Reactividad — cancelar movimiento del mes previo → si el bucket previo queda en 0, el delta del bucket actual pasa de un número a `—`.
- **CB-14**: Categoría archivada en el mes actual pero activa en el previo → LEFT JOIN vacío colapsa a "Sin categoría"; matchea con el bucket "Sin categoría" del previo si existe, sino → `—`.
- **CB-15**: Muchos buckets (20+ categorías). El chip agrega ~50px de ancho a cada fila; validar en cel angosto que el layout no rompe (`overflow.ellipsis` en el label si aplica).

## Criterios de aceptacion

- `flutter test` verde con al menos 10 tests nuevos.
- `flutter analyze` sin errores nuevos.
- APK release compilado con `0.18.0+90`; `verify-apk.sh` OK.
- **SM-01**: seed 2 meses de datos con overlap de categorías → tap fila mes actual → chips visibles con dirección + percent correcto.
- **SM-02**: seed solo mes actual → chips todos en `—`. Header también `—`.
- **SM-03**: cambiar `interestRate` u otra config sin efecto en el sheet → chips no cambian.
- **SM-04**: registrar movimiento en el mes previo con sheet abierto → chip se recalcula (reactividad).
- **SM-05**: renombrar categoría del mes visible → chip no se rompe (match por `categoryId`, no nombre).
- Sin regresión en los 21 tests del sprint padre (UT-CB01..16, WT-CB01..05).

## Criterios medibles de exito

- `flutter test` total ≥ 570 verdes (560 baseline + ~10 nuevos).
- Query única extendida se ejecuta en < 30 ms para datasets típicos single-user (< 500 movimientos por mes).
- APK release build < 500 KB adicional.
- 0 regresión en tests existentes.

## Riesgos

- **R1 — Ruido visual con muchos chips**: 20+ filas con chips + 3 en el summary = mucha información densa. Mitigación: chip pequeño (fontSize 10, padding mínimo), color mesurado (no full saturation). Verificar en SM-01 en cel real.
- **R2 — División por cero en RN-CP09**: previo=0 y actual>0. Retornar delta null es la decisión tomada, evita `+∞%` o `+100%` engañoso. Cubierto en UT.
- **R3 — Signo del neto**: `net = income - expense` puede cambiar signo entre meses (mes con superávit vs déficit). El delta sobre magnitudes puede confundir. Mitigación: documentado en RN-CP08; test explícito de neto que salta signo.
- **R4 — Layout en cel angosto**: chip agrega ~40-50px al ancho de la fila. Con categorías de nombres largos + label ellipsized puede quedar sin espacio. Mitigación: verificar en SM-01. Alternativa: chip solo si hay espacio (Flex tail dropdown).
- **R5 — Ambigüedad del `—`**: el usuario puede confundir "sin data previa" con "cero cambio". Mitigación: `flat` usa ícono `remove` + `0.0%`; `—` es solo texto sin ícono. Suficientemente distinto.
- **R6 — Divergencia timezone**: el sprint padre R6 sigue vigente. Un movimiento borderline en UTC 23:30 del último día del mes puede caer en un mes distinto entre el cashflow base y este sheet. Aceptado; no aplica al delta interno del sheet (el sheet es 100% localtime tanto para actual como previo).
- **R7 — Rendimiento de la query extendida**: el `strftime IN (?, ?)` escanea el mismo range que la query original (2 meses vs 1). Con < 500 movimientos/mes negligible. Verificar con dataset típico en SM.

## Supuestos

- El `DateTime(monthAnchor.year, monthAnchor.month - 1, 1)` normaliza correctamente el rollover a diciembre año anterior cuando `monthAnchor.month == 1` (patrón Dart estándar).
- El chip visual (ícono + percent) cabe en el ancho disponible incluso en cels angostos con categorías de nombres típicos (< 15 chars). Si aparece regresión, se ajusta con `Flexible` o ellipsis.
- Diego prefiere ver `—` explícito antes que ocultar el chip cuando no hay data previa (mejor UX: indica que la comparación existe pero no aplica).
- El `flat` con `percent = 0.0%` es visualmente distinto de `—` porque el primero tiene ícono de guion (`Icons.remove`) mientras el segundo solo texto.
- La reactividad de rename se mantiene por match de `categoryId` (no nombre), preservando la comparación histórica sin lógica adicional.

## Impacto esperado

- Diego responde "¿por qué gasté más este mes?" bucket-por-bucket en el mismo tap donde ya abrió el desglose. Cero fricción adicional.
- El sheet se convierte de "snapshot del mes" a "snapshot + tendencia inmediata" — 2x el valor por segundo de uso.
- Los 3 chips del summary dan lectura rápida del "cómo voy" en 5 segundos: verde en neto = plata te sobró más que el mes previo.
- Base para features futuros: comparación 3 meses (media móvil), delta año vs año, alertas ("gastaste 40% más en Comida este mes").
- Cero cambios de schema, cero migración, cero regresión de otros reportes/tabs/backup.
- Feature 100% reversible con `git revert` del commit final.

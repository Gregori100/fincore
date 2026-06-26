# Cashflow mensual — segundo tab del `/reports`

## Resumen

Agregar el tab "Cashflow mensual" a la pantalla `/reports`, junto al
existente "Gasto por categoría". Muestra **ingresos vs gastos por mes
calendario** dentro de un rango configurable, con bar chart pareado
(verde para ingresos, rojo para gastos) más métricas agregadas del
período (total ingresos, total gastos, neto). Reusa la infraestructura
de presets de fecha del tab existente (`DateRangePreset` +
`dateRangeForPreset`).

## Problema a resolver

Hoy `/reports` responde **"dónde gasté"** (gasto por categoría) pero NO
responde **"cómo cambia mes a mes"**. Diego no tiene una vista de
tendencias: si los ingresos están cayendo, si los gastos suben
gradualmente, si un mes fue atípico. Es la dimensión analítica
faltante más visible.

## Objetivo

Que Diego pueda abrir `/reports`, tappear "Cashflow mensual" y ver de
un vistazo:

- Si los **ingresos** del período están subiendo, bajando o estables.
- Si los **gastos** del período están subiendo, bajando o estables.
- Si el **neto mensual** es positivo o negativo.
- Cuál fue el mes mejor y el peor.

Sin abrir Excel, sin recordar cifras, sin filtros complejos.

## Alcance

- Nuevo tab "Cashflow mensual" en `/reports` (TabBar pasa de 1 a 2 tabs).
- Nuevo widget `CashflowTab` en `lib/screens/reports/cashflow_tab.dart`.
- Nuevo método `ReportsService.cashflowByMonth(from, to)` en
  `lib/data/reports.dart`.
- Nuevos modelos `CashflowReport` + `MonthCashflow` (inmutables).
- Bar chart pareado (verde ingresos / rojo gastos) por mes.
- Métricas del header: total ingresos, total gastos, neto del período.
- Presets de fecha reutilizando `DateRangePreset` actual (sin tocar
  el enum). Default `thisMonth` para coherencia con el tab existente
  (decisión P-001).
- Reactividad via `customSelect.watch()` (mismo patrón que
  `spendingByCategory`).
- Tests del data layer + smoke manual.

## Fuera de alcance

- Línea de neto superpuesta al bar chart (puede sumarse en v2 si se pide).
- Desglose por categoría dentro del bar mensual (ya hay un tab para eso).
- Comparativo año-contra-año.
- Forecast / proyección de cashflow.
- Filtros por cuenta o categoría dentro del cashflow.
- Export a CSV/PDF del reporte (sprint `F9` separado).
- Drill-down al journal de un mes específico (no es navegable v1).

## Reglas de negocio

- **RN-C01**: contabilidad del bar **ingresos**: suma de
  `journal_entries.amount` donde `kind = 'income'` y
  `deleted_at IS NULL`.
- **RN-C02**: contabilidad del bar **gastos**: suma de
  `journal_entries.amount` donde `kind IN ('expense', 'credit_expense')`
  y `deleted_at IS NULL`. Coherente con `RN-R01/R02` del tab existente.
- **RN-C03**: `transfer` y `debt_payment` quedan **excluidos** del
  cashflow. Son movimientos internos (mover plata entre cuentas, pagar
  deuda ya registrada) que no representan flujo neto contra el "afuera".
  Incluirlos doble-contaría: el `credit_expense` original ya está en
  gastos; sumar el `debt_payment` lo contaría dos veces.
- **RN-C04**: agrupación por **mes calendario** del `occurred_at`.
  Clave canónica `YYYY-MM` (string). Conversión a Date para el axis:
  primer día del mes.
- **RN-C05**: rango del reporte inclusivo en ambos extremos (`[from, to]`),
  igual que el spending tab (RN-R05).
- **RN-C06**: meses dentro del rango **sin entries** se muestran con
  barras vacías (0/0). Mantiene continuidad visual del eje X. Sin
  esto, un mes vacío crearía un "hueco" engañoso.
- **RN-C07**: el **neto del período** = total ingresos − total gastos.
  Puede ser negativo (rojo) o positivo (verde) según el signo.
- **RN-C08**: orden del eje X = **cronológico ascendente** (más viejo a
  la izquierda, más reciente a la derecha). Convención universal para
  series de tiempo.

## Requisitos funcionales

- **RF-001**: `ReportsService` expone `cashflowByMonth({DateTime from,
  DateTime to})` que retorna `Stream<CashflowReport>` reactivo a
  cambios en `journal_entries`.
- **RF-002**: `CashflowReport` contiene: `from`, `to`, `totalIncome`,
  `totalExpense`, `net`, `List<MonthCashflow> months`.
- **RF-003**: `MonthCashflow` contiene: `monthKey` (`YYYY-MM`),
  `firstDay` (DateTime del 1° del mes), `income`, `expense`,
  `net` (income − expense).
- **RF-004**: la query SQL agrupa con `strftime('%Y-%m', occurred_at)`
  y filtra `kind IN ('income', 'expense', 'credit_expense')` +
  `deleted_at IS NULL`.
- **RF-005**: para cada mes calendario en `[from, to]` (incluyendo
  meses sin entries por RN-C06), el reporte produce una entrada de
  `MonthCashflow`. La función rellena ceros para meses ausentes en la
  query.
- **RF-006**: `CashflowTab` widget con la misma estructura visual del
  tab existente: header con chips de presets de fecha + body con
  métricas + bar chart + breakdown numérico debajo.
- **RF-007**: `CashflowTab` muestra 3 métricas en el header: "Ingresos"
  (verde, monto), "Gastos" (rojo, monto), "Neto" (color según signo,
  monto con signo).
- **RF-008**: bar chart **pareado nativo** (decisión P-002). 2 barras
  verticales por mes (verde ingresos a la izquierda, rojo gastos a la
  derecha), altura proporcional al máximo del período. Sin deps
  externas. Patrón consistente con el horizontal bar chart del
  spending tab. Eje X con label `MMM` (3 letras del mes en es_MX, ej.
  "ene", "feb", "mar"). Eje Y implícito (sin labels) — los montos
  reales viven en el breakdown numérico debajo (RF-009).
- **RF-009**: breakdown numérico debajo del chart: filas con mes,
  ingreso, gasto, neto. Visible sin tener que interactuar con el chart.
- **RF-010**: empty state cuando no hay ingresos NI gastos en el rango:
  "No hay movimientos en este rango." con icono neutro.
- **RF-011**: `ReportsScreen` actualizado para usar `TabBar` con 2
  tabs ("Gasto por categoría", "Cashflow mensual"). `DefaultTabController`
  con `length: 2`.
- **RF-012**: `ReportsScreen` arranca en el primer tab (gasto por
  categoría) para no romper hábito.

## Casos principales

- **CP-1 — Rango con datos en todos los meses**: 6 meses con entries.
  Bar chart muestra 6 columnas pareadas. Header agregados correctos.
- **CP-2 — Rango con un mes vacío**: mes intermedio sin entries.
  Columna del mes vacío aparece con barras en 0 (no hueco).
- **CP-3 — Solo ingresos**: rango con income pero sin gastos. Barras
  verdes presentes, barras rojas en 0. Neto = totalIncome.
- **CP-4 — Solo gastos**: opuesto. Neto = -totalExpense (rojo).
- **CP-5 — Cambio de preset**: tap "Mes pasado" → reporte refresca.
- **CP-6 — Custom range**: tap "Custom" → 2 date pickers → reporte refresca.

## Casos borde

- **CB-1 — Rango de 1 día**: from == to dentro del mismo mes. 1
  columna con los datos de ese día agregados.
- **CB-2 — Rango que cruza año** (ej. dic-2025 a feb-2026): meses
  ordenados cronológicamente, no agrupados por año.
- **CB-3 — Rango con 0 entries totales**: empty state (RF-010).
- **CB-4 — Entry justo en límite `from` (00:00:00)**: incluido
  (RN-C05, inclusivo). Coherente con CB-T05 del spending tab.
- **CB-5 — Entry justo en límite `to` (23:59:59)**: incluido.
- **CB-6 — Soft-deleted entry**: NO cuenta (RN-C02).
- **CB-7 — Categoría archivada con expense**: el expense SÍ cuenta
  (cashflow es agregado, no desglosa por categoría).
- **CB-8 — `transfer` en el rango**: NO cuenta (RN-C03).
- **CB-9 — `debt_payment` en el rango**: NO cuenta (RN-C03).
- **CB-10 — Rango muy grande (24+ meses)**: el bar chart debe ser
  scrollable horizontal si las columnas no caben en pantalla. Mínimo
  ancho por columna para legibilidad (~32px).
- **CB-11 — Cambio de zona horaria del dispositivo durante el período**:
  no aplicable hoy (subsegundos preservados, BD almacena texto ISO).
  Decisión: usar el local del cel sin conversión.

## Criterios de aceptacion

- Tap "Reportes" desde dashboard muestra TabBar con 2 tabs visibles.
- Tab "Cashflow mensual" cargado por primera vez muestra header con
  chips, métricas agregadas, bar chart pareado y breakdown numérico.
- Crear un entry nuevo desde otra pantalla y volver al tab: el reporte
  refresca con el nuevo dato (reactividad via `customSelect.watch()`).
- Tap preset "Mes pasado" cambia el rango y refresca el reporte.
- Tap preset "Custom" abre 2 date pickers; al confirmar refresca.
- Empty state con copy "No hay movimientos en este rango." aparece
  cuando suma de ingresos + gastos = 0 en el período.
- `flutter test` sigue verde tras los tests data nuevos del
  `cashflowByMonth`.

## Criterios medibles de exito

- **CM-01**: 10+ tests data del DAO en `reports_test.dart`:
  - 1 test empty (BD sin entries).
  - 2 tests rango con income / expense puros.
  - 2 tests neto positivo / negativo.
  - 1 test rango cruzando año.
  - 1 test transfers/debt_payments excluidos (RN-C03).
  - 1 test soft-delete excluido (RN-C02 / CB-6).
  - 1 test rellenar meses vacíos (RN-C06 / CP-2).
  - 1 test orden cronológico (RN-C08 / CB-2).
- **CM-02**: ≥2 widget tests del `CashflowTab`: render con datos +
  empty state.
- **CM-03**: 0 errores en `flutter analyze` post-implementación.
- **CM-04**: APK release `0.7.0+58` (bump menor por feature nuevo)
  validado por `verify-apk.sh`.

## Riesgos

- **R-01** (medio): bar chart pareado nativo + scroll horizontal +
  meses vacíos = más complejidad que el bar chart horizontal del
  spending tab. Si crece, considerar dep externa (`fl_chart` o
  similar). Decisión: empezar nativo, refactor si pasa los 200
  líneas del widget.
- **R-02** (bajo): cambio de `DefaultTabController.length` de 1 a 2
  podría romper algún test del `ReportsScreen` que asuma 1 tab.
  Hay 4-5 tests en `reports_screen_test.dart`. Validar antes de
  commit.
- **R-03** (bajo): rellenar meses vacíos en Dart (RF-005) requiere
  iterar mes a mes desde `from` hasta `to`. Cuidado con cambios de
  DST y librería `intl`. Usar `DateTime(year, month, 1)` simple,
  sin tocar timezone.
- **R-04** (bajo): el default `thisMonth` muestra 1 sola columna
  pareada al abrir el tab, lo cual sub-utiliza el potencial analítico
  del cashflow. Mitigación: el usuario tappea "Año" o "Custom" para
  ver más meses. Si el feedback post-smoke indica que es engorroso,
  agregar un preset `last6Months` en una v2 (decisión P-001).

## Supuestos

- Default range del tab: `thisMonth` (decisión P-001 — coherencia con
  el tab existente).
- Visualización: bar chart pareado nativo lado a lado (decisión P-002 —
  sin deps externas, patrón consistente con el spending tab).
- `transfer` y `debt_payment` se excluyen del cashflow (RN-C03). Razón:
  son movimientos internos sin impacto en flujo "contra el afuera";
  incluirlos doble-contaría con el `credit_expense` original.
- Eje X usa label `MMM` en es_MX (3 letras: "ene", "feb", "mar"). Con
  rangos cruzando año, el agente lector verá el orden cronológico sin
  ambigüedad por la posición en el chart.
- Métricas del header son 3: ingresos, gastos, neto. Sin "mes pico" /
  "promedio mensual" en v1 (suma si el feature lo justifica en uso).
- Reusa `BaseCard` + estilos del tab existente. Sin nueva paleta.
- Sin animaciones en el bar chart inicial (perf v1 coherente).
- TabBar arranca en tab 0 (gasto por categoría) por compatibilidad
  con tests existentes y hábito del usuario.

## Impacto esperado

- **Producto**: cubre el hueco analítico de tendencias mes a mes.
- **Código**: `reports.dart` crece ~80 líneas (servicio + modelos).
  `reports_screen.dart` crece de 36 a ~45 líneas. Nuevo
  `cashflow_tab.dart` ~250 líneas.
- **Tests**: +12 tests data + 2 widget tests. Total ≈ 233 verdes post.
- **Suite**: agrega ~1s al `flutter test`.
- **APK size**: cero impacto (sin deps nuevas).
- **Sin migración de BD**: solo lectura.

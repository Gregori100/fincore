# Filtro de monto en el panel de `/entries`

## Resumen

Agregar la dimensión **"Monto"** al panel de filtros de
`EntriesListScreen`, completando la última dimensión faltante (hoy hay
fecha, tipo, cuenta, categoría). El panel acepta 2 fields numéricos
opcionales: `mínimo` y `máximo`. El DAO traduce esos límites en
condiciones SQL `>=` y `<=` sobre `journal_entries.amount`. La
`EntriesActiveFiltersBar` muestra un chip removible con el rango activo
(análogo al chip de fechas). Sin schema bump, sin deps externas.

## Problema a resolver

El panel de filtros actual no permite acotar la lista por monto. Para
encontrar "todos los movimientos mayores a $1000 del mes pasado" Diego
tiene que scrollear visualmente, perdiendo el sentido analítico del
panel. Es la dimensión más solicitable para auditar gastos grandes,
identificar movimientos atípicos o reconciliar contra estados de cuenta.

## Objetivo

Que Diego pueda abrir el panel de filtros, escribir "1000" en
"Mínimo" y "Aplicar", y ver instantáneamente solo los entries con
`amount >= 1000` del rango activo. Que el chip "≥ $1000" aparezca en
la `EntriesActiveFiltersBar` con su "X" para removerlo sin re-abrir el
panel.

## Alcance

- Extender `EntriesFilters` con `minAmount: double?` y `maxAmount:
  double?` + `copyWith` + `clearDimension(FilterDimension.amount)` +
  `activeCount` + `parse` (query params) + `toDeepLink`.
- Extender el enum `FilterDimension` con `amount`.
- Extender `EntriesDao.watchPage` con `minAmount` y `maxAmount`
  opcionales que agregan `journalEntries.amount.isBiggerOrEqualValue` /
  `isSmallerOrEqualValue`.
- Agregar sección "Monto" en `EntriesFiltersScreen` con 2
  `TextFormField` numéricos.
- Agregar chip de monto en `EntriesActiveFiltersBar`.
- Pasar `minAmount` y `maxAmount` desde `EntriesPaginatedList` al
  `watchPage`.
- Detectar cambio de `minAmount` / `maxAmount` en
  `EntriesPaginatedList._filtersChanged` para resetear paginación.
- Tests del DAO + tests del panel + test del chip activo.

## Fuera de alcance

- Filtro por moneda múltiple (single-user single-MXN).
- Filtro por "monto exacto" como dimensión separada (cubierto por
  `minAmount == maxAmount`).
- Slider visual con histograma del rango histórico.
- Filtro por monto con signo según kind (cashflow ya cubre la lectura
  de "neto"; este filtro es por amount crudo).
- Tab nuevo de reporte por monto.
- Export filtrado por monto a CSV/PDF (sprint `F9` separado).

## Reglas de negocio

- **RN-A01**: `journal_entries.amount` se almacena **siempre positivo**.
  El signo deriva del `kind` (`expense` resta, `income` suma). El filtro
  por monto opera sobre el valor crudo positivo — coherente con lo que
  Diego ve en `_Row` (montos siempre formateados con `formatAmount`
  positivos, el signo se agrega cosméticamente).
- **RN-A02**: `minAmount` es **inclusivo** (`amount >= minAmount`).
- **RN-A03**: `maxAmount` es **inclusivo** (`amount <= maxAmount`).
  Coherente con la convención del rango de fechas y del rango del
  spending tab.
- **RN-A04**: ambos campos son **opcionales e independientes**. Si solo
  hay `minAmount`, filtra `amount >= min`. Si solo hay `maxAmount`,
  filtra `amount <= max`. Si ambos, `amount BETWEEN min AND max`.
- **RN-A05**: validación al "Aplicar": si ambos están presentes y
  `minAmount > maxAmount`, mostrar snackbar warning "El rango de monto
  no es válido. Revisá los montos." y NO aplicar. Patrón consistente
  con la validación del rango de fechas en spending/cashflow tabs.
- **RN-A06**: el filtro se aplica a **todos los kinds**. Si Diego
  quiere "solo gastos > $1000", combina filtro de kind con filtro de
  monto. Mantener el filtro por monto agnóstico del kind.
- **RN-A07**: `minAmount` y `maxAmount` deben ser **>= 0**. Negativos no
  tienen sentido para `amount` positivo. Validar en el input con
  `inputFormatters` (filtros de dígitos + un solo punto decimal).
- **RN-A08**: el filtro de monto se respeta también en deep links via
  query params (`minAmount=X` y/o `maxAmount=Y`). Coherente con el
  resto del sistema (`parse` y `toDeepLink`).

## Requisitos funcionales

- **RF-001**: `EntriesFilters` expone `minAmount: double?` y
  `maxAmount: double?` como campos finales.
- **RF-002**: `EntriesFilters.copyWith({double? minAmount, double?
  maxAmount, bool clearMinAmount, bool clearMaxAmount})` permite
  setear o limpiar cada uno independientemente. Patrón requerido
  porque `double?` con default null en copyWith no distingue "no
  cambiar" de "limpiar".
- **RF-003**: `FilterDimension` enum incluye `amount`.
- **RF-004**: `EntriesFilters.clearDimension(FilterDimension.amount)`
  limpia ambos (`minAmount = null`, `maxAmount = null`). Tap en la "X"
  del chip de monto remueve toda la dimensión, igual que las otras
  dimensiones.
- **RF-005**: `EntriesFilters.activeCount` cuenta `amount` como **1**
  dimensión si al menos uno de los 2 campos está presente. No suma 2.
- **RF-006**: `EntriesFilters.parse(queryParameters)` lee
  `minAmount=X.Y` y `maxAmount=X.Y` con `double.tryParse`. Valores no
  numéricos o negativos se ignoran (queda null).
- **RF-007**: `EntriesFilters.toDeepLink()` agrega `minAmount=X.Y` y
  `maxAmount=X.Y` cuando están presentes.
- **RF-008**: `EntriesDao.watchPage` acepta `minAmount: double?` y
  `maxAmount: double?` opcionales. Si presentes, agrega
  `journalEntries.amount.isBiggerOrEqualValue(min)` y/o
  `isSmallerOrEqualValue(max)`. Compone con los otros filtros con AND.
- **RF-009**: `EntriesFiltersScreen` agrega sección "Monto" entre las
  secciones "Cuenta" y "Categorías" (orden lógico: la dimensión
  "transaccional" cae entre las "estructurales").
- **RF-010**: la sección "Monto" muestra 2 `TextFormField` en Row:
  "Mínimo" (izq) y "Máximo" (der). Prefijo `$`. Keyboard
  `numberWithOptions(decimal: true)`. Input formatter que solo permite
  dígitos + un único punto.
- **RF-011**: al "Aplicar" con `minAmount > maxAmount`, el panel
  muestra snackbar warning + NO emite el resultado al caller (queda
  abierto). Mismo patrón que el date picker custom.
- **RF-012**: `EntriesActiveFiltersBar` agrega chip de monto cuando
  `filters.minAmount != null || filters.maxAmount != null`. Label
  según el caso:
  - Solo min: `"≥ $X"`.
  - Solo max: `"≤ $X"`.
  - Ambos: `"$X – $Y"`.
  Donde `$X` y `$Y` usan `formatAmount` para coherencia visual con la
  lista.
- **RF-013**: `EntriesPaginatedList._filtersChanged` compara también
  `minAmount` y `maxAmount` para resetear paginación cuando cambian.
- **RF-014**: `EntriesListScreen` no requiere cambios productivos —
  ya pasa `_filters` completo al `EntriesPaginatedList`.

## Casos principales

- **CP-1 — Filtro solo mínimo**: usuario abre panel, escribe "1000" en
  Mínimo, Aplica. Lista solo muestra entries con `amount >= 1000`.
- **CP-2 — Filtro solo máximo**: escribe "500" en Máximo, Aplica.
  Lista solo muestra entries con `amount <= 500`.
- **CP-3 — Filtro rango**: escribe "100" y "1000", Aplica. Lista solo
  muestra entries con `100 <= amount <= 1000`.
- **CP-4 — Combinado con otros filtros**: filtro de monto + filtro de
  kind "Gastos" + filtro de fecha "Este mes". Lista muestra gastos del
  mes en el rango de monto.
- **CP-5 — Tap "X" del chip de monto**: remueve `minAmount` y
  `maxAmount` (limpia la dimensión). Lista refresca.
- **CP-6 — Deep link manual con minAmount**: push
  `/entries?minAmount=500` pre-carga el filtro y muestra la lista
  filtrada.

## Casos borde

- **CB-1 — `minAmount == maxAmount`**: filtro exacto. Lista muestra
  solo entries con `amount == X`.
- **CB-2 — `minAmount > maxAmount` al "Aplicar"**: snackbar warning +
  panel no emite resultado.
- **CB-3 — `minAmount` o `maxAmount` con decimales**: ej. "1499.50"
  válido. Filtro respeta decimales (drift maneja DOUBLE).
- **CB-4 — `minAmount = 0`**: filtra entries con `amount >= 0`. Como
  todos los amount son >= 0, equivale a no filtrar por min.
  Comportamiento técnicamente correcto; el `activeCount` cuenta como
  dimensión activa (Diego escribió 0 intencionalmente).
- **CB-5 — Input no numérico**: el `inputFormatter` lo bloquea antes
  de llegar al state.
- **CB-6 — Limpiar el field**: borra texto del input → `null` →
  dimensión no se cuenta como activa.
- **CB-7 — Filtro de monto + paginación**: cambiar monto resetea
  paginación a `_currentLimit = _kPageSize` (RF-013 +
  `EntriesPaginatedList._resetPagination`).
- **CB-8 — Chip de monto al lado del chip de fecha custom**: el `ListView`
  horizontal de la bar acomoda ambos sin overflow (ya validado por la
  bar actual con N chips).
- **CB-9 — Deep link con `minAmount=abc`**: `double.tryParse` retorna
  `null` → ignorado.
- **CB-10 — Deep link con `minAmount=-500`**: tras parse retorna
  `-500` que es válido en double pero contradice RN-A07. Decisión:
  ignorar negativos en `parse` para no traer un estado interno
  inválido.
- **CB-11 — Cancelar entry mientras el filtro de monto está activo**:
  reactividad drift re-emite; el entry cancelado desaparece de la
  lista. Sin reset de paginación.
- **CB-12 — Render del chip con monto grande (ej. $1.000.000)**: el
  `formatAmount` lo formatea con separadores; el chip no debería
  desbordar gracias al `Flexible(child: Text(overflow: ellipsis))` ya
  presente en `_ActiveChip`.

## Criterios de aceptacion

- Tap "Filtros" en el AppBar de `/entries` abre el panel con la
  sección "Monto" visible entre "Cuenta" y "Categorías".
- Escribir "100" en Mínimo + Aplicar refresca la lista con solo
  entries `>= 100`.
- El chip "≥ $100" aparece en la `EntriesActiveFiltersBar` con su X.
- Tap en la X del chip remueve el filtro y la lista refresca con los
  entries previos.
- Push manual `/entries?minAmount=500&maxAmount=1500` carga la lista
  con los entries del rango.
- `minAmount > maxAmount` muestra snackbar warning y NO aplica.
- `flutter test` sigue verde tras los tests data nuevos + tests del
  panel + test del chip.

## Criterios medibles de exito

- **CM-01**: 6+ tests data nuevos del `watchPage` con `minAmount` y
  `maxAmount`:
  - UT-01 solo min.
  - UT-02 solo max.
  - UT-03 ambos (rango).
  - UT-04 `min == max` (igualdad).
  - UT-05 combinado con kind y fecha.
  - UT-06 sin filtro de monto (regresión).
- **CM-02**: 3+ tests del panel + chip:
  - WT-01 sección "Monto" renderea 2 fields.
  - WT-02 chip activo cuando solo min está presente.
  - WT-03 validación min > max muestra snackbar warning.
- **CM-03**: 0 errores `flutter analyze`.
- **CM-04**: APK release `0.7.1+59` validado por `verify-apk.sh`.

## Riesgos

- **R-01** (bajo): `copyWith` con `bool clear*` agrega ruido al modelo
  inmutable. Alternativa: usar un sentinel (`const _unset = double.nan`)
  o exponer `clearMinAmount()` method aparte. Decisión: optar por el
  `bool clear*` ya que es el patrón menos sorpresivo y los tests lo
  documentan.
- **R-02** (bajo): el `inputFormatter` con regex `[0-9.]` puede dejar
  pasar múltiples puntos. Mitigación: el `validator` del field rechaza
  `double.tryParse == null`, y el snackbar de submit avisa.
- **R-03** (bajo): el chip "≥ $X" / "≤ $X" agrega símbolos no-ASCII al
  rendering. Validado: la fuente del theme oscuro tiene soporte UTF-8;
  el `_ActiveChip` ya renderea acentos sin problemas.
- **R-04** (bajo): tests del `EntriesFilters` que usaban
  `EntriesFilters({datePreset, from, to, ...})` con args posicional
  pueden romper si cambia la signature. Mitigación: agregar
  `minAmount` y `maxAmount` como **opcionales** (default null) sin
  obligar al caller.
- **R-05** (bajo): el chip de monto puede empujar fuera del viewport
  el chip de fecha custom si Diego activa 4 dimensiones simultáneas.
  Mitigación: el `ListView(scrollDirection: Axis.horizontal)` ya
  permite scroll. Validar visualmente en smoke.

## Supuestos

- **Amount crudo (sin signo)**: el filtro opera sobre el valor positivo
  almacenado en BD. Diego ve "movimientos de monto en [X, Y]" sin
  importar si son gastos o ingresos. Si quiere solo gastos > X,
  combina con filtro de kind.
- **Inclusivo en ambos extremos**: coherente con rango de fechas y
  rango del spending tab.
- **Sin slider visual**: 2 fields numéricos simples. Un slider con
  histograma agrega complejidad sin valor inmediato.
- **Validación min > max al "Aplicar"** (no en tiempo real al typing):
  evita molestia mientras Diego escribe.
- **Default vacío** en ambos fields al abrir el panel.
- **Sección "Monto" entre "Cuenta" y "Categorías"** en el orden visual
  del panel.
- **Deep link `minAmount=` y `maxAmount=`** como query params, no como
  segmentos de path.
- **Sin cambio en la firma de `EntriesFilters` para callers existentes**:
  los nuevos campos son opcionales con default `null` en el
  constructor.
- **Sin impacto en el cashflow**: el cashflow agrega por mes
  independientemente del monto individual; el filtro de monto del panel
  de `/entries` no toca al servicio de reports.

## Impacto esperado

- **Producto**: cierra el panel de filtros (4 → 5 dimensiones). Diego
  puede auditar movimientos grandes / chicos sin scrollear visualmente.
- **Código**: ~30 líneas adicionales en `entries_filters.dart`,
  ~10 líneas en `entries_dao.dart`, ~40 líneas en
  `entries_filters_screen.dart` (sección nueva), ~20 líneas en
  `entries_active_filters_bar.dart` (chip + label helper),
  ~10 líneas en `entries_paginated_list.dart` (comparación en
  `_filtersChanged` + paso de `min`/`max` a `watchPage`).
- **Tests**: +6 data + +3 widget = ~234 + 9 = ~243 verdes post.
- **APK size**: cero impacto.
- **Sin migración** de schema.
- **Sin regresión** esperada en filtros existentes (los nuevos campos
  son opcionales y default null).

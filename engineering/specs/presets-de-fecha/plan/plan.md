# Plan técnico — Presets de fecha

## Enfoque tecnico

Cambio 100% frontend en 3 capas finas:

1. **Capa de cálculo (utils/dates.js)** — agregar:
   - Constante `DATE_PRESETS` con `{ key, label }` para las 7 opciones en orden fijo.
   - Función `rangeForPreset(presetKey, today = new Date())` que devuelve `{ from, to }` en ISO `YYYY-MM-DD`. Lanza `Error` con mensaje claro si la clave es inválida.
   - Función `detectPreset(from, to, today = new Date())` que recorre `DATE_PRESETS` y devuelve la primera clave cuyo rango matchea exactamente, o `'custom'` si ninguna matchea. Strings vacíos/falsy también devuelven `'custom'`.
   - Todas las operaciones internas usan `Date` local (no UTC) con `setDate(getDate() - N)` para evitar bugs DST en "Últimos N días".

2. **Capa de UI reusable (DateRangePreset.vue)** — componente nuevo:
   - Props: `modelValue: { from: string, to: string }`, `label?: string` (default `'Período'`), `disabled?: boolean`.
   - Emit único: `update:modelValue` con `{ from, to }` (objeto nuevo, no mutación in-place).
   - Estado interno: `preset` (`Ref<string>` con la clave activa o `'custom'`).
   - Watcher sobre `modelValue` con `deep: true` que recalcula `preset` via `detectPreset`.
   - Watcher sobre `preset` que cuando cambia a una clave ≠ `'custom'` emite el nuevo rango calculado.
   - Renderiza `BaseSelect` con 8 opciones (las 7 de `DATE_PRESETS` + `'Personalizado'`).
   - Renderiza condicionalmente 2 `BaseInput type=date` con `label="Desde"` / `"Hasta"` cuando `preset === 'custom'`. Cada uno emite `update:modelValue` con `{ ...modelValue, from/to: nuevoValor }`.

3. **Capa de integración (3 vistas)** — reemplazar el par de inputs por el componente:
   - `ReportsByCategoryView`: usa `filters.value.from / to`. Reemplaza el bloque que tiene los 2 `BaseInput type=date` + el botón "Este mes" (que queda obsoleto porque el preset cubre el caso).
   - `ReportsByAccountView`: usa `filters.value.from / to`. Reemplaza el bloque.
   - `EntriesTable.vue` (compartido por `/entries` y `/accounts/:uuid`): usa `filters.value.from / to` + propiedad fija `accountId` desde el padre. Reemplaza los 2 `BaseInput` sin tocar el filtro `account_id`.

**ReportsCashflowView queda fuera** — el rango es `lastNMonths(12)` fijo, no editable por el usuario hoy. Agregar el selector aquí sería **una capacidad nueva**, fuera del alcance "reemplazar filtros existentes". Documentado en sección "Compatibilidad" y como riesgo. Si se quiere unificar, se puede hacer en un sprint chico posterior agregando una opción "Últimos 12 meses" al `DATE_PRESETS` y conectando el componente.

## Requisitos funcionales cubiertos

- **RF-001**: `rangeForPreset(presetKey, today?)` en `utils/dates.js` con default `new Date()` para `today`. Devuelve ISO `YYYY-MM-DD`.
- **RF-002**: Las 7 claves declaradas en `DATE_PRESETS` (`today`, `this_week`, `this_month`, `last_month`, `last_30_days`, `last_90_days`, `this_year`). Cualquier otra clave lanza `Error('rangeForPreset: clave de preset desconocida: ...')` con la clave inválida incluida en el mensaje.
- **RF-003**: Componente `DateRangePreset.vue` con la API exacta de la spec (props/emits/comportamiento).
- **RF-004**: Watcher sobre `modelValue` invoca `detectPreset(from, to)` y actualiza `preset.value`. Al montar dispara el mismo flujo via `immediate: true`.
- **RF-005**: Cada input emite `update:modelValue` con un objeto nuevo `{ ...modelValue, [campo]: nuevoValor }`; el dropdown queda en `'custom'` porque el watcher del padre llega después del watcher local (ver "Casos borde / orden de watchers").
- **RF-006**: El watcher del `modelValue` detecta cualquier cambio externo y actualiza `preset` consistentemente.
- **RF-007**: 3 vistas modificadas (ByCategory, ByAccount, EntriesTable). Cashflow excluido con justificación.
- **RF-008 y RF-009**: cero cambios al exporter ni al drill-down — siguen leyendo `filters.value.from / to`.
- **RF-010**: Default `'this_month'` aplicado en cada vista padre (los `DEFAULT_FROM/DEFAULT_TO` actuales ya equivalen a "Este mes" en ByCategory y EntriesTable; ByAccount también arranca en mes en curso). Sin cambios en el comportamiento default visible.

## Archivos o modulos probablemente afectados

Nuevos:

- `frontend/src/components/finance/DateRangePreset.vue` — componente.
- `frontend/tests/components/DateRangePreset.spec.js` — tests del componente.
- `frontend/tests/utils/dates.spec.js` — tests del helper. Verificar al implementar si ya existe el archivo; si existe, agregar describe blocks; si no, crearlo.

Modificados:

- `frontend/src/utils/dates.js` — agrega `DATE_PRESETS`, `rangeForPreset`, `detectPreset`. Los helpers existentes (`firstDayOfMonth`, `lastDayOfMonth`, `toISODate`, etc.) se reusan internamente.
- `frontend/src/views/app/ReportsByCategoryView.vue` — reemplaza inputs from/to + botón "Este mes" por el componente.
- `frontend/src/views/app/ReportsByAccountView.vue` — reemplaza inputs from/to por el componente.
- `frontend/src/components/finance/EntriesTable.vue` — reemplaza inputs from/to por el componente.

Sin cambios:

- `ReportsCashflowView.vue` — fuera de alcance, ver "Compatibilidad".
- `EntriesView.vue`, `AccountDetailView.vue` — consumen `EntriesTable` con la misma API; no requieren cambios.
- Backend completo, rutas, modelos, migraciones — cero cambios.
- `CLAUDE.md`, `docs/api/*` — cero cambios.

## Entidades y estados afectados

No aplica. Cambio 100% frontend, sin entidades de dominio nuevas ni estados de negocio modificados.

Estado interno del componente:

- `preset: Ref<string>` — la clave activa (`'today' | 'this_week' | 'this_month' | 'last_month' | 'last_30_days' | 'last_90_days' | 'this_year' | 'custom'`).
- Invariante: `preset === 'custom'` ⇒ inputs visibles; `preset ≠ 'custom'` ⇒ inputs ocultos.
- Transición externa → interna: `modelValue` cambia → watcher recalcula `preset`.
- Transición interna → externa: `preset` cambia a clave no-custom → emite `update:modelValue` con el rango calculado.

## Compatibilidad con datos y procesos existentes

- **Backend**: cero impacto. Los endpoints siguen recibiendo strings ISO. Sin migraciones.
- **Tests existentes del frontend** (72/72 al cierre del sprint anterior): se espera regresión cero. Los specs de `ReportsByCategoryView` y similares no existen (no hay tests por vista); los que sí existen (`MonthlyCashflowChart`, `ExcelExportButton`, etc.) no tocan el rango directamente.
- **Cashflow excluido**: el comportamiento de `ReportsCashflowView` queda idéntico al actual (rango fijo 12 meses). La spec lo incluye en alcance pero como hoy NO tiene inputs editables, integrar el componente implicaría una **capacidad nueva** (cambiar el rango). Se documenta como decisión de plan; revisitable.
- **Drill-down y exports**: ambos leen `filters.value.from / to` directamente del estado de la vista padre. El componente nuevo emite los mismos campos en el mismo formato, transparente.
- **`/accounts/:uuid`**: usa `EntriesTable` con `accountId` fijo como prop. El cambio no toca esa prop ni el filtro `account_id`; sólo reemplaza los inputs from/to.

## Cambios de datos

No aplica.

## Cambios de API

No aplica. Backend intacto.

## Cambios de integraciones

No aplica.

## Cambios de UI

- Las 3 vistas pierden los 2 `BaseInput type=date` sueltos y ganan 1 `BaseSelect` (Período) que cuando es "Personalizado" muestra los 2 inputs debajo.
- `ReportsByCategoryView` pierde su botón **"Este mes"** (`<BaseButton variant="ghost" @click="thisMonth">Este mes</BaseButton>`) porque el preset cubre el caso.
- El layout de grid de filtros en ByCategory pasa de `grid-cols-... lg:grid-cols-4` a `lg:grid-cols-3` (una columna menos al eliminar el botón Este mes). Ajustar para que cuente bien.
- En "Personalizado", el componente muestra los 2 inputs en una sub-fila (no afecta el grid del padre, los inputs viven dentro del slot del componente).
- Las etiquetas son en español: "Hoy", "Esta semana", "Este mes", "Mes pasado", "Últimos 30 días", "Últimos 90 días", "Este año", "Personalizado".
- El selector usa `BaseSelect` (mismo patrón que el resto de la app).

## Cambios de permisos

No aplica.

## Riesgos tecnicos

- **DST en "Últimos N días"**: usar `setDate(getDate() - N)` (date math local), no `getTime() - N * 86400000`. La segunda forma falla cuando el cambio de horario cae en el medio del rango. Tests fijos para escenarios DST.
- **Reactividad del watcher con `deep: true`**: las 3 vistas mutan propiedades del objeto (`filters.value.from = X`), no reemplazan el objeto. El watcher local del componente necesita `deep: true` o `immediate: true` para captar esos cambios. Tests cubren el caso de mutación parcial.
- **Orden de watchers (race condición lógica)**: cuando el usuario edita un input en "Personalizado", el flujo es: input → emit `update:modelValue` → padre actualiza `filters.value.from` → watcher local del componente recalcula `detectPreset` → si los nuevos from/to por casualidad matchean un preset, el dropdown salta a ese preset y oculta los inputs. **Comportamiento esperado por RF-004 y la spec** ("Preset que coincide con un rango Personalizado por casualidad"). Si fuera molesto en la práctica se podría agregar un "modo sticky custom", pero no se prevé en este sprint.
- **EntriesTable y query params del drill-down**: `EntriesTable.vue` lee query params en mount (`year_month`, `from`, `to`) y los inyecta a `filters.value`. El componente debe detectar el preset correcto desde esos valores precargados (cubierto por `detectPreset` + watcher con `immediate: true`).
- **`firstDayOfMonth()` y `lastDayOfMonth()` ya en la base**: reusarlos en `rangeForPreset` para no duplicar lógica. Verificar que `firstDayOfMonth(new Date(2026, 5, 10))` devuelva `'2026-06-01'` y consistente.
- **EntriesTable tiene `lastDayOfMonth()` como `DEFAULT_TO`**: este default es **último día del mes**, no hoy. La spec dice que "Este mes" termina HOY. Reemplazar EntriesTable con `DateRangePreset` defaulteando a "Este mes" cambia el comportamiento sutilmente: `to` pasa de "último día" a "hoy". Verificar con el usuario o mantener "último día" como sub-preset. **Decisión de plan**: usar "Este mes" = hoy como termina (consistente con spec); el cambio es imperceptible si el usuario no está mirando el campo `to` y sólo cuando `today !== lastDayOfMonth(today)`. Documentar como desviación menor en `implementation/`.
- **`BaseSelect` con `null` vs `'custom'`**: confirmar que `BaseSelect` acepta valores string para options; las opciones existentes en el repo usan tanto strings como nulls. Test del componente lo confirma.

## Estrategia de pruebas

- **Helper `rangeForPreset` y `detectPreset`** en `frontend/tests/utils/dates.spec.js`:
  - 7 tests, uno por preset, con `today` fijo (ej. `new Date(2026, 5, 10)` = mié 10 jun 2026).
  - Casos borde: hoy es lunes, hoy es 1 del mes, hoy es 31 de marzo, año bisiesto (1 mar 2024), semana cruzando año (1 ene 2026 miércoles), últimos 30 días cruzando año, clave inválida lanza error.
  - 3 tests de `detectPreset`: matchea preset, no matchea → custom, strings vacíos → custom.
- **Componente `DateRangePreset`** en `frontend/tests/components/DateRangePreset.spec.js`:
  - Render inicial con `modelValue = { from: 'YYYY-MM-DD', to: 'YYYY-MM-DD' }` que matchea un preset → dropdown muestra ese preset, inputs ocultos.
  - Render con modelValue que no matchea → dropdown `'Personalizado'`, inputs visibles.
  - Cambio de preset en el dropdown → emite `update:modelValue` con rango correcto.
  - Cambio a `'Personalizado'` → muestra los inputs precargados con el modelValue actual.
  - Edición de input en personalizado → emite update + dropdown sigue en personalizado (porque el rango editado no matchea ningún preset).
  - Cambio externo de modelValue a un rango que matchea otro preset → dropdown se actualiza.
- **No tests de las 3 vistas modificadas** (no hay tests por vista en el repo hoy; las modificaciones son re-layout, cubiertas por inspección).

## Estrategia de rollback

Trivial. Revertir los commits del sprint deja el código en el estado anterior (3 vistas con inputs from/to + botón "Este mes" en ByCategory). El componente y los helpers nuevos no tienen dependencias externas; no quedan migraciones, sesiones ni estado persistido.

## Orden sugerido de implementacion

1. Helper `DATE_PRESETS`, `rangeForPreset`, `detectPreset` en `utils/dates.js`. Tests unit primero (TDD light).
2. Componente `DateRangePreset.vue`. Tests con `mount` + cambios de modelValue.
3. Integrar en `EntriesTable.vue` (es el más complejo: compartido, con query params, con `accountId` prop). Validar manualmente y con la suite que `/entries` y `/accounts/:uuid` siguen funcionando.
4. Integrar en `ReportsByCategoryView.vue` (también elimina el botón "Este mes").
5. Integrar en `ReportsByAccountView.vue`.
6. Suite completa frontend + smoke manual.
7. `branch-quality-review`.

## Casos borde que condicionan la solucion

Todos cubiertos por la spec:

- Hoy es lunes / 1 del mes / 31 de marzo / 29 de febrero (bisiesto).
- Semana ISO cruzando año.
- "Últimos 30 días" cruzando año.
- `modelValue` con `from` o `to` vacíos.
- `modelValue` con valores inválidos (no parseables): el helper `detectPreset` falla silencioso a `'custom'`.
- Zona horaria del navegador: cálculo siempre local, nunca UTC.
- DST: no usar aritmética de milisegundos en cálculos de rango.

## Preguntas o supuestos que siguen afectando la implementacion

- **¿Cashflow debe integrarse?** Decisión de plan: NO, por las razones de "Compatibilidad". Si el usuario lo pide después, sprint chico aparte.
- **EntriesTable `DEFAULT_TO`**: hoy es `lastDayOfMonth()` (futuro). Con `DateRangePreset` defaulteando a "Este mes", `to` pasa a ser HOY. Documentar y aceptar (consistente con la spec); el usuario rara vez nota la diferencia salvo que mire el campo `to` directamente.
- **Etiqueta del label del dropdown**: la spec sugiere "Período". Aceptable.
- **Posición vertical del bloque "Personalizado"**: los 2 inputs aparecen DEBAJO del dropdown, no al lado. Decisión visual del plan.
- **Comparativo mes vs mes (`/reports/month-comparison`)**: fuera de alcance; usa selector de `year_month`. Si en futuro se quiere un selector tipo "Este mes / Mes pasado / Otro", sprint aparte.

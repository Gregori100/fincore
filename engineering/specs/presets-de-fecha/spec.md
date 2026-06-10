# Presets de fecha en filtros de rango

## Resumen

Reemplazar los inputs `from`/`to` sueltos en las 4 vistas con filtros de rango por un selector "Período" que ofrece 7 presets prearmados + "Personalizado". Cuando hay un preset activo, los date pickers se ocultan; con "Personalizado" reaparecen para edición manual. Default global: "Este mes".

## Problema a resolver

Hoy cada vista con rango de fechas (`/reports/by-category`, `/reports/cashflow`, `/reports/by-account`, `/entries`) muestra dos inputs sueltos `from` y `to`. El usuario quiere acotar el rango más rápido sin tipear fechas — los casos típicos (mes en curso, mes pasado, últimos 30/90 días, este año) deben ser un click. Hoy cada vista resuelve esto a mano (botón "Este mes" en `ReportsByCategoryView`, default a mes en curso en `ReportsByAccountView`, etc.), inconsistente y limitado.

## Objetivo

Centralizar el flujo de selección de rango en un solo componente reutilizable que las 4 vistas adopten, con 7 presets útiles + fallback a "Personalizado", y comportamiento bidireccional (cambiar preset actualiza from/to, editar from/to en Personalizado mantiene el preset en "Personalizado").

## Alcance

- 4 vistas que hoy usan `from`/`to`:
  - `ReportsByCategoryView` (`/reports/by-category`).
  - `ReportsCashflowView` (`/reports/cashflow`).
  - `ReportsByAccountView` (`/reports/by-account`).
  - `EntriesTable` (componente usado por `EntriesView` en `/entries` y por `AccountDetailView` en `/accounts/:uuid`).
- Helpers nuevos en `frontend/src/utils/dates.js`: una función `rangeForPreset(presetKey, today)` que devuelve `{ from, to }` para los 7 presets soportados.
- Componente nuevo `DateRangePreset.vue` (componente Vue) que envuelve el dropdown y oculta/muestra los inputs `from`/`to` según el preset activo.
- Tests unitarios del helper y del componente.

## Fuera de alcance

- Comparativo mes vs mes (`/reports/month-comparison`): usa selector de `year_month`, otro modelo de datos. Se podría dar un selector análogo en otro sprint.
- Tarjetas de crédito (`/reports/credit-cards`): no acepta filtros de fecha.
- Presupuestos (`/reports/budgets`): no acepta filtros de fecha (sólo mes en curso).
- Backend: cero cambios; los endpoints siguen aceptando `from`/`to` ISO strings.
- Persistencia entre sesiones: los presets seleccionados NO se guardan en `localStorage`/store; cada vez que el usuario entra a una vista vuelve al default "Este mes".
- Internacionalización: las etiquetas se hardcodean en español de México.
- Validación cross-preset (`from > to`): los presets siempre devuelven rangos válidos por construcción; sólo "Personalizado" puede romper la regla, donde se aplica la validación existente de cada vista.
- Presets adicionales como "Semana pasada", "Ayer", "Año pasado", "Q1/Q2/Q3/Q4": se descartaron para mantener la lista corta.

## Reglas de negocio

- "Hoy" se calcula con la zona horaria local del navegador, no UTC.
- "Esta semana" comienza el lunes (semana ISO). Si hoy es lunes, `from = to = hoy`.
- "Este mes" termina hoy, no el último día del mes (consistente con cómo lo calculan hoy las vistas).
- "Mes pasado" termina el último día del mes pasado, no hoy.
- "Últimos 30 días" e "Últimos 90 días" son inclusivos del día actual: `from = hoy - (N-1)`, `to = hoy`. Total exacto N días.
- "Este año" termina hoy, no el 31 de diciembre.
- Si los `from/to` actuales del estado coinciden exactamente con los devueltos por algún preset al instante de evaluación, el dropdown muestra ese preset; si no, "Personalizado".
- Editar manualmente cualquiera de los dos inputs cuando hay un preset activo cambia el dropdown a "Personalizado" sin reverter los valores.
- El default al montar cualquier vista que use el componente sin valores previos es preset "Este mes" (mismo rango que muchas vistas usan hoy por default).

## Requisitos funcionales

- RF-001: Existe una función `rangeForPreset(presetKey: string, today?: Date): { from: string, to: string }` en `frontend/src/utils/dates.js` que devuelve fechas en formato `YYYY-MM-DD` para los 7 presets siguientes. El parámetro `today` es opcional y default `new Date()`; sirve para testear sin mockear.
- RF-002: Las claves soportadas son `today`, `this_week`, `this_month`, `last_month`, `last_30_days`, `last_90_days`, `this_year`. Cualquier otra clave lanza un error claro.
- RF-003: Existe un componente `DateRangePreset.vue` en `frontend/src/components/finance/` con la API:
  - Props: `modelValue: { from: string, to: string }`, `disabled?: boolean`, `label?: string`.
  - Emit: `update:modelValue` con `{ from, to }` cuando cambian.
  - Selector "Período" usando `BaseSelect` con las 7 opciones + "Personalizado".
  - Al seleccionar un preset (≠ "Personalizado"): oculta los inputs from/to y emite el `update:modelValue` con el rango calculado por `rangeForPreset`.
  - Al seleccionar "Personalizado": muestra dos `BaseInput type=date` para `from` y `to`. Cada `input` emite también `update:modelValue` al cambiar.
- RF-004: Al montar el componente, detecta el preset activo comparando `modelValue.from` y `modelValue.to` con `rangeForPreset(key)` para cada clave; el primero que matchea exactamente se selecciona; si ninguno matchea, selecciona "Personalizado" y muestra los inputs.
- RF-005: Editar manualmente cualquiera de los dos inputs en "Personalizado" emite `update:modelValue` con el valor nuevo; el dropdown sigue en "Personalizado".
- RF-006: Editar manualmente un input con un preset activo (no debería ser posible porque están ocultos, pero si el padre cambia `modelValue` externamente a un rango que ya no matchea ningún preset) hace que el componente caiga a "Personalizado" y muestre los inputs.
- RF-007: Las 4 vistas reemplazan su par actual de `BaseInput from/to` por el componente `DateRangePreset`, manteniendo el resto del layout.
- RF-008: El comportamiento del botón "Exportar a Excel" no cambia: usa los `from/to` del estado al click, independiente de si vinieron de un preset o de "Personalizado".
- RF-009: El comportamiento del drill-down (modal + "Ir a Movimientos") no cambia: pasa los `from/to` actuales como query params, independiente del preset.
- RF-010: Default al montar sin valores previos en cualquier vista: preset `this_month`.

## Casos principales

- Usuario abre `/reports/by-category`. Dropdown muestra "Este mes" por default. Cambia a "Mes pasado" → from/to se ajustan a primer y último día del mes anterior; los inputs no son visibles; el reporte refetchea solo.
- Usuario abre `/reports/cashflow`. Cambia a "Últimos 90 días" → from/to se ajustan a hoy-89 / hoy.
- Usuario abre `/reports/by-account`. Default "Este mes". Cambia a "Personalizado" → aparecen los inputs; tipea from=2026-03-15, to=2026-04-15; el dropdown queda en "Personalizado".
- Usuario abre `/entries`. Default "Este mes". Cambia a "Últimos 30 días" → cambia el rango y la lista refetchea.
- Usuario hace click en bucket de `ReportsByCategoryView` con "Este mes" activo → drill-down abre con `from/to` del mes en curso. Cierra modal, click en "Ir a Movimientos" → navega a `/entries?kind=expense&from=…&to=…`; en `/entries` el componente detecta que esos `from/to` matchean "Este mes" y selecciona ese preset; los inputs quedan ocultos.
- Usuario tiene `Personalizado` activo en `/entries` con from=2026-03-15 / to=2026-04-15. Hace click "Exportar a Excel" → el endpoint recibe esos from/to exactos.

## Casos borde

- **Hoy es lunes**: "Esta semana" devuelve `from = to = hoy`.
- **Hoy es 1 del mes**: "Este mes" devuelve `from = to = hoy`. "Mes pasado" devuelve el rango completo del mes anterior.
- **Hoy es 31 de marzo**: "Mes pasado" devuelve `2026-02-01` a `2026-02-28` (o 29 en bisiesto). No "2026-03-00" ni "2026-02-31".
- **Año bisiesto**: "Mes pasado" en marzo de 2024 devuelve `2024-02-01` a `2024-02-29`.
- **Semana cruzando fin de año**: "Esta semana" en el 1 de enero (miércoles) devuelve `from = lunes 30 de diciembre del año anterior`, `to = hoy`. Sin error de Y2K-style.
- **"Últimos 30 días" termina en el 1 de enero**: `from = 3 de diciembre del año anterior`, `to = 1 de enero`. Cruza año correctamente.
- **`modelValue` cambiado externamente** (query param de drill-down, navegación, edición programática): el componente detecta el nuevo preset (o cae a Personalizado) y actualiza el dropdown.
- **`modelValue` con valores inválidos** (from > to, fechas no parseables): el componente cae a "Personalizado" y muestra los inputs con esos valores; deja la validación a la vista padre.
- **Zona horaria del navegador en GMT+/-N**: `rangeForPreset` debe usar fecha local, no UTC, para que "Hoy" sea realmente hoy para el usuario.
- **Locale del `BaseInput type=date`**: el navegador renderiza el formato según locale; el modelValue siempre va en ISO `YYYY-MM-DD`.
- **DST (cambio de horario)**: el cálculo de "Últimos 30 días" debe seguir devolviendo 30 días incluso si hay DST en el medio (usar resta de días, no de milisegundos).
- **Default al montar con prop `modelValue = { from: '', to: '' }`**: el componente trata cadena vacía como "no hay valor" y aplica default "Este mes".
- **Preset que coincide con un rango "Personalizado" por casualidad**: ej. el usuario tipea from = primer día del mes, to = hoy → el componente lo detecta como "Este mes" y oculta los inputs. Comportamiento esperado por RF-004.

## Criterios de aceptacion

- `rangeForPreset(key)` devuelve fechas correctas para las 7 claves; los 9 casos borde de arriba están cubiertos por tests unitarios.
- `rangeForPreset('unsupported')` lanza un Error con un mensaje claro que cita la clave inválida.
- El componente `DateRangePreset.vue` renderiza el dropdown con las 8 opciones (7 presets + "Personalizado") y un label opcional.
- Al cambiar el dropdown a un preset, el componente emite `update:modelValue` con el rango correcto y oculta los inputs.
- Al cambiar el dropdown a "Personalizado", muestra los inputs con los valores actuales de `modelValue`.
- Al editar un input en "Personalizado", el componente emite `update:modelValue` con el nuevo valor; el dropdown sigue en "Personalizado".
- Al recibir un `modelValue` externo que matchea un preset, el dropdown se actualiza a ese preset.
- Al recibir un `modelValue` externo que no matchea ningún preset, el dropdown se actualiza a "Personalizado".
- Las 4 vistas reemplazan el par `BaseInput from/to` actual por `DateRangePreset` sin cambiar su firma a las funciones de fetch ni a los exports.
- Los tests existentes de las 4 vistas y de los exports siguen pasando sin modificación (regresión cero).
- La suite frontend (72 actuales + ~10-15 nuevos esperados) queda verde.
- El botón "Exportar a Excel" sigue funcionando con el rango actual y el drill-down sigue navegando con los `from/to` correctos.

## Criterios medibles de exito

- Cambiar de preset a otro no requiere editar inputs ni hacer click en "Actualizar"; el reporte/lista refetchea automáticamente porque el `watch` actual sobre `from/to` ya lo dispara.
- Tiempo de selección de "Mes pasado" desde "Este mes": 1 click + 1 selección de dropdown (2 acciones), vs hoy 2 ediciones de input (mínimo 6 keystrokes c/u + 2 clicks).
- Cobertura de tests del helper >= 90% y >= 10 casos (7 presets × 1 caso base + casos borde).
- Cobertura del componente: al menos 6 tests (render con preset activo, render con personalizado, switch entre opciones, switch a personalizado y back, detección desde modelValue externo, edición de input emite update).

## Riesgos

- **Inconsistencia DST entre presets**: si se usan `new Date()` + `setDate()`, JavaScript es seguro porque opera en fechas locales. Pero hay que evitar operaciones con `Date.UTC()` o `getTime()` aritmético para "Últimos N días". Mitigación: usar `setDate(getDate() - N)` o un helper específico ya probado.
- **`modelValue` ref vs reactive del padre**: si la vista padre usa un ref de objeto y muta una propiedad (`filters.value.from = …`) en lugar de reemplazar el objeto, el watcher de `modelValue` puede no dispararse. Mitigación: las 4 vistas hoy usan `ref({ from, to, … })` y mutan propiedades — el componente debe escuchar `modelValue` con `deep: true` o trabajar con props separados `from`/`to` (decisión de plan).
- **EntriesTable es compartido por dos vistas** (`/entries` y `/accounts/:uuid`): cambiar su markup afecta ambas. Cubrir con tests si existen.
- **Detección automática del preset desde query params**: cuando el drill-down navega a `/entries?from=…&to=…`, esas fechas pueden o no matchear un preset. El componente debe detectarlo correctamente. Hay riesgo de bug si la lógica de comparación es por string vs Date y zonas horarias entran al medio.
- **`BaseSelect` con 8 opciones**: si el componente existente tiene problemas con listas largas o key handling, hay que validar. Mitigación: BaseSelect ya se usa en muchas vistas con N opciones.
- **Comparativa de strings ISO funciona pero requiere paridad de formato**: `'2026-06-01'` debe ser exacto, sin `'2026-6-1'`. `toISODate` ya garantiza padding; usarlo en `rangeForPreset` también.
- **Tarjetas y Presupuestos pueden quedar inconsistentes visualmente** porque no reciben presets, pero como no aceptan filtros de fecha esto es esperado y aceptable.

## Supuestos

- El componente se posiciona en el mismo lugar donde estaban los inputs `from/to` actuales en cada vista; cada vista mantiene su layout (grid, flex) y simplemente reemplaza el bloque.
- Las etiquetas de los presets en español son: "Hoy", "Esta semana", "Este mes", "Mes pasado", "Últimos 30 días", "Últimos 90 días", "Este año", "Personalizado".
- El orden en el dropdown es: Hoy → Esta semana → Este mes → Mes pasado → Últimos 30 días → Últimos 90 días → Este año → Personalizado. Refleja granularidad creciente con Personalizado al final.
- "Esta semana" usa semana ISO (lunes = primer día), no domingo, consistente con el resto de la app.
- Los tests del componente usan `@vue/test-utils` + Vitest con jsdom, igual que el resto.
- Los tests del helper pasan un `today` fijo (ej. `new Date(2026, 5, 10)` = 10 jun 2026) para evitar depender de la hora del sistema.
- El componente NO se preocupa de validar que `from <= to` cuando el usuario tipea en "Personalizado"; deja eso a la vista padre (que ya tiene esa validación implícita o la puede aplicar después).
- No se persiste el preset elegido entre recargas; al volver a entrar a una vista, vuelve a "Este mes".
- El componente NO consulta endpoints — sólo emite `update:modelValue` y deja que la vista padre dispare el fetch via su `watch` existente.

## Impacto esperado

- 1 archivo nuevo: `frontend/src/components/finance/DateRangePreset.vue`.
- 1 archivo modificado: `frontend/src/utils/dates.js` (agrega `rangeForPreset` y constantes/labels).
- 4 vistas modificadas para usar el componente (reemplazan los 2 inputs por 1 `DateRangePreset`):
  - `frontend/src/views/app/ReportsByCategoryView.vue`
  - `frontend/src/views/app/ReportsCashflowView.vue`
  - `frontend/src/views/app/ReportsByAccountView.vue`
  - `frontend/src/components/finance/EntriesTable.vue` (compartido por `/entries` y `/accounts/:uuid`).
- 2 archivos de tests nuevos:
  - `frontend/tests/utils/dates.spec.js` (o existente si ya existe — verificar al implementar).
  - `frontend/tests/components/DateRangePreset.spec.js`.
- Sin cambios en backend, sin migraciones, sin cambios en API.
- Sin cambios en `CLAUDE.md` (no toca el contrato de la API).
- Posible nota en `docs/frontend/README.md` sobre el componente, si el documento lista componentes.

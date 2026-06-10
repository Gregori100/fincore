# Branch Quality Review — presets-de-fecha

- **Rama**: `main` (cambios en working tree, no commiteados; sumándose a 3 commits previos del sprint export-excel-reportes pendientes de push).
- **Base**: `main` (último commit `6bc3c1e docs(reports): spec, plan, implementation y quality-review de export-excel-reportes`).
- **Rango revisado**: working tree completo del sprint (4 archivos modificados, 4 nuevos).
- **Fecha**: 2026-06-10 17:35.
- **Reviewers** (paralelos, vía Explore): Helper + Componente / 3 vistas integradas.
- **Tests al momento del review**: backend 360/360 sin cambios; frontend 110/110 verde (eran 72 + 38 del sprint: 27 del helper + 11 del componente). Smoke con Playwright 4/4 OK.

## Resumen ejecutivo

Sprint en buen estado para merge. **0 bloqueantes reales** y **0 hallazgos altos**. Los hallazgos consolidados son 3 medios y 3 bajos, todos de calidad y defensa en profundidad. Notar que un hallazgo del agente fue reclasificado de "Bloqueante" a "Bajo" tras verificación contra Vue 3 (la prop `modelValue` está marcada `required: true` y Vue emite warning, no crash silencioso).

**Bloqueantes**: 0.  
**Altos**: 0.  
**Medios**: 3 (1 del sprint, 2 preexistentes).  
**Bajos**: 3.

## Hallazgos

### M1 — `ReportsByAccountView` no refetchea al cambiar el preset (preexistente, pero ahora UX inconsistente)

- **Archivo**: `frontend/src/views/app/ReportsByAccountView.vue:86`.
- **Detalle**: la vista no tiene `watch` sobre `filters`. Solo refresca con `onMounted(fetchReport)` y el botón "Actualizar". Cuando el usuario cambia el preset en el dropdown, `filters.value.from/to` se actualizan pero el reporte no refetchea automáticamente — el usuario debe presionar "Actualizar".
- **Origen**: comportamiento preexistente desde el sprint por-cuenta-drilldown; el sprint actual NO lo introduce.
- **UX**: inconsistente con `ReportsByCategoryView` y `EntriesTable`, que sí refetchean automáticamente al cambiar cualquier filtro.
- **Severidad**: Medio.
- **Acción recomendada**: agregar `watch(() => [filters.value.from, filters.value.to], fetchReport)`. Sprint chico (3 líneas).

### M2 — `EntriesTable` mantiene import muerto de `BaseInput` (nuevo)

- **Archivo**: `frontend/src/components/finance/EntriesTable.vue:7`.
- **Detalle**: `import BaseInput from '@/components/ui/BaseInput.vue'` — el componente se importa pero ya no se usa en el template (los inputs from/to fueron reemplazados por `DateRangePreset`).
- **Origen**: el sprint introdujo la inconsistencia al reemplazar los inputs sin limpiar el import.
- **Severidad**: Medio (no rompe nada pero ensucia el archivo).
- **Acción recomendada**: eliminar la línea del import.

### M3 — Flag `internalUpdate` del componente es frágil frente a casos async futuros

- **Archivo**: `frontend/src/components/finance/DateRangePreset.vue:31-56`.
- **Detalle**: el componente usa un boolean module-scoped `internalUpdate` para evitar loops `update:modelValue → watch → emit → ...`. Hoy funciona porque JS es single-threaded y el emit + actualización del padre son sincrónicos. Si en el futuro el padre introduce validación async (ej. debouncing), el watcher podría dispararse después de que el flag fue reseteado.
- **Severidad**: Medio (no es bug ahora, sino fragilidad).
- **Acción recomendada**: dejar como está y monitorear. Si aparece debouncing en algún padre, refactorizar a una ref con contador o a `watchPostEffect` con control explícito.

### B1 — Crash potencial si se pasa `modelValue = null`

- **Archivo**: `frontend/src/components/finance/DateRangePreset.vue:85` (template `:model-value="modelValue.from"`).
- **Detalle**: el watcher usa optional chaining (`val?.from`), pero el template no. Si un padre pasa `modelValue: null` por error, el template intenta acceder a `.from` en null.
- **Mitigación existente**: la prop está declarada con `required: true`, así que Vue emite un warning visible en consola si no se pasa o se pasa null/undefined. No es crash silencioso.
- **Severidad**: Bajo.
- **Acción recomendada**: opcionalmente cambiar template a `:model-value="modelValue?.from"` para defensa en profundidad. No urgente.

### B2 — Comentario en `rangeForPreset` menciona `setDate` pero el código usa constructor

- **Archivo**: `frontend/src/utils/dates.js:157-158`.
- **Detalle**: el comentario dice "setDate con valor negativo retrocede días", pero el código usa el constructor `new Date(year, month, day - (n-1))`. Ambos enfoques son correctos y DST-safe, pero el comentario es engañoso para un lector futuro.
- **Severidad**: Bajo.
- **Acción recomendada**: actualizar el comentario a "constructor `new Date(y, m, d - N)` con día negativo normaliza correctamente y respeta DST".

### B3 — Tests faltantes opcionales

- **Archivos**: `frontend/tests/components/DateRangePreset.spec.js`.
- **Casos no cubiertos** (opcionales):
  - `modelValue = null` no crashea (defensa en profundidad para B1).
  - Editar inputs en "Personalizado" hasta que matcheen un preset → componente salta al preset y oculta los inputs (RF-004 del flujo completo).
- **Severidad**: Bajo.
- **Acción recomendada**: agregar 2 tests más si se quiere cobertura exhaustiva.

## Sin hallazgos en

- **DST en cálculo de "Últimos N días"**: el constructor `new Date(year, month, day - (n-1))` con día negativo es DST-safe; JavaScript normaliza correctamente sin sufrir cambios de horario. Tests cubren cruzando año (último 30 días desde 1 ene 2026).
- **Semana ISO**: cálculo correcto para lunes (offset=0), domingo (offset=6), y miércoles (offset=2). Tests cubren cruce de año (mié 1 ene 2026 → lun 29 dic 2025).
- **Mes con 30/31 días + año bisiesto**: tests cubren `last_month` desde marzo 2026 (febrero 28), desde marzo 2024 (febrero 29 bisiesto), desde mayo (abril 30), desde enero (diciembre del año anterior).
- **`detectPreset` con valores inválidos**: devuelve `'custom'` sin lanzar para null, undefined, strings vacíos, números, strings no parseables.
- **Orden `DATE_PRESETS`**: `'today'` antes de `'this_week'` y `'this_month'` para que un rango `from==to==hoy` en lunes detecte `'today'`, no `'this_week'`. Test explícito cubre el caso.
- **`EntriesTable` cambio de `DEFAULT_TO`**: pasar de `lastDayOfMonth()` (futuro) a `toISODate()` (hoy) es consistente con la spec/plan. El watcher de `filters` capta el cambio. El drill-down y export siguen recibiendo `filters.from/to` correctamente.
- **EntriesTable compartido por `/entries` y `/accounts/:uuid`**: el prop `accountId` fijo se prioriza en `fetchEntries()` (`effectiveAccountId = props.accountId ?? filters.value.account_id`), así que el cambio del componente nuevo no rompe el caso de detalle de cuenta.
- **Query params del drill-down**: `EntriesTable` lee `from/to` de query params en mount, los asigna a `filters`, y el watcher del componente con `immediate: true` detecta el preset correcto al render inicial.
- **`ReportsByCategoryView` watcher**: refetchea automáticamente con `watch([... filters.from, filters.to ...], fetchReport)`. La eliminación del botón "Este mes" y la función `thisMonth()` está completa, sin referencias residuales.
- **`ReportsByCategoryView` layout**: el grid pasó de `lg:grid-cols-4` a `sm:grid-cols-2` para acomodar 2 elementos (Cuenta + DateRangePreset). Se ve limpio en desktop y mobile.
- **`ReportsByAccountView` layout**: pasó a `space-y-3` + `flex` para botones. Mejor para acomodar el componente cuando se expande a "Personalizado".
- **Imports limpios en las 2 vistas modificadas (excepto B2)**: `BaseInput`, `BaseButton` solo cuando se usan; `lastDayOfMonth` removido de los imports cuando ya no se usa.
- **ReportsCashflowView intacto**: no aparece en el diff. Conserva rango fijo `lastNMonths(12)` sin dropdown.
- **Suite frontend regression-free**: 110/110 (eran 72; +27 helper, +11 componente = +38). Sin regresiones.
- **Suite backend sin cambios**: 360/360. Cero impacto.

## Tareas de corrección sugeridas (en orden)

Ninguna bloquea el merge. Listadas en orden de impacto:

1. **M2**: remover import muerto de `BaseInput` en `EntriesTable.vue:7`. Una línea.
2. **M1**: agregar `watch` en `ReportsByAccountView` para refetch automático al cambiar preset. 3-4 líneas. Resuelve inconsistencia UX preexistente.
3. **B2**: actualizar comentario del helper para no mencionar `setDate`. Cosmético.
4. **B1**: opcionalmente usar `modelValue?.from/to` en el template del componente. Defensa en profundidad.
5. **B3**: opcionalmente agregar 2 tests más (modelValue null + ciclo custom→preset). Cobertura extra.
6. **M3**: dejar como está, monitorear si aparece async en algún padre futuro.

## Limitaciones y validaciones no ejecutadas

- **Smoke en navegador real**: cubierto con Playwright (4/4 escenarios). No se probó manualmente DST real (depende de la zona horaria del navegador del usuario).
- **No se probaron las 7 zonas horarias** distintas, sólo la del entorno actual (Mx). Los tests del helper usan fecha fija inyectada y son zona-agnostic, lo que cubre el modelo.
- **Tests E2E**: ninguno nuevo agregado (el sprint anterior tampoco; los E2E del repo están desactualizados según el backlog).
- **Build de producción Vite**: falla por permisos en `dist/` dentro del docker (problema preexistente documentado en backlog). El cambio del sprint NO introduce ese fallo.
- **Performance**: el componente con `watch deep + immediate` y `detectPreset` itera DATE_PRESETS (7 items). Costo O(7), negligible.

## Veredicto

**Listo para merge** tras atender M1 + M2 (5 líneas total, 5 min de trabajo). M3 y B1-B3 son mejoras o defensa en profundidad que pueden hacerse aquí o diferirse.

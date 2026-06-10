# Implementation Review: presets-de-fecha

## Resumen de lo implementado

Dropdown "Período" con 7 presets + "Personalizado" en 3 vistas (`/reports/by-category`, `/reports/by-account`, `/entries` y `/accounts/:uuid`). El componente reemplaza los inputs from/to sueltos: cuando hay un preset activo los oculta y recalcula automáticamente; en "Personalizado" reaparecen los inputs. Default global "Este mes" alineado con el comportamiento previo.

100% frontend, sin migraciones, sin cambios en backend.

## Archivos principales modificados

Frontend nuevos:

- `frontend/src/components/finance/DateRangePreset.vue`
- `frontend/tests/components/DateRangePreset.spec.js`
- `frontend/tests/utils/dates.spec.js`

Frontend modificados:

- `frontend/src/utils/dates.js` (agrega `DATE_PRESETS`, `rangeForPreset`, `detectPreset`).
- `frontend/src/components/finance/EntriesTable.vue` (reemplaza inputs + cambia `DEFAULT_TO` a hoy + computed adapter + elimina import muerto de `BaseInput`).
- `frontend/src/views/app/ReportsByCategoryView.vue` (reemplaza inputs + elimina botón "Este mes" + computed adapter).
- `frontend/src/views/app/ReportsByAccountView.vue` (reemplaza inputs + computed adapter + agrega `watch` para refetch automático).

Engineering docs:

- `engineering/specs/presets-de-fecha/spec.md`, `checklist.md`, `plan/{plan,tasks,test-plan}.md`, `implementation/*`, `engineering/quality-review/presets-de-fecha/2026-06-10-1735-branch-quality-review.md`.

## Tareas completadas

T001..T013 todas completadas. Detalle: ver `progreso.md`.

## Tareas pendientes

Ninguna. M3/B1/B2/B3 del QR son mejoras opcionales documentadas — pueden ir en este PR o diferirse.

## Riesgos residuales

- **M3 (fragilidad del flag `internalUpdate`)**: funciona porque JS es single-threaded y la actualización del padre es síncrona. Si en el futuro algún padre introduce validación async, podría romperse. Documentado, no urgente.
- **B1 (modelValue null)**: prop está `required: true`, Vue avisa con warning. Defensa en profundidad disponible.

## Pruebas realizadas

- **Helper `utils/dates.js`**: 27 tests verde (7 presets con `today` fijo + 9 casos borde + 11 de `detectPreset`).
- **Componente `DateRangePreset.vue`**: 11 tests verde (render por preset, render custom, cambio dropdown emite update, edición de inputs, watch externo a preset/custom, mutación parcial deep reactive, label custom, 8 opciones).
- **Suite frontend completa**: 110/110 (eran 72; +38 nuevos).
- **Suite backend**: 360/360 sin cambios (cero impacto al backend).
- **Smoke con Playwright**: 4/4 OK — `/reports/by-category` cambio Este mes → Últimos 90 días → Personalizado con inputs visibles; `/entries` muestra dropdown con Este mes; `/reports/by-account` igual; `/reports/cashflow` confirmado intacto sin dropdown.

## Pruebas recomendadas

- **B3 opcional**: agregar tests del componente para `modelValue = null` y para el ciclo custom→preset cuando el usuario edita inputs hasta matchear un preset (RF-004 del flujo completo).
- **E2E Playwright**: no se agregaron tests E2E nuevos. Si se quiere defensa adicional, agregar un spec en `tests-e2e/` que valide el flujo dropdown → refetch en cada vista.

## Posibles regresiones

- **Ninguna identificada**. Backend intacto, Cashflow intacto, 110 tests frontend en verde.
- **Cambio sutil documentado en EntriesTable**: `DEFAULT_TO` pasó de `lastDayOfMonth()` (futuro) a `toISODate()` (hoy). El usuario rara vez nota la diferencia porque entries del futuro no existen, pero el campo `to` ahora muestra "2026-06-10" en lugar de "2026-06-30" cuando hoy es 10/jun. Consistente con el preset `this_month`.

## Recomendaciones para code review humano

1. **Validar el patrón del computed adapter** en las 3 vistas: cada vista usa `const dateRangeModel = computed({ get, set })` para adaptar `filters.value.{from, to}` al v-model `{from, to}` del componente. ¿Preferible un wrapper más alto o así está bien?
2. **El flag `internalUpdate`**: módulo-scoped no reactivo. Funciona pero es un patrón "feo" si se quiere ser purista. M3 del QR sugiere monitorear pero no actuar.
3. **`ReportsByAccountView` ahora refetchea solo**: aplica para cambios de preset y para edición manual en "Personalizado". El botón "Actualizar" sigue siendo útil para refresco manual (sin cambiar filtros).
4. **Revisar el quality-review**: `engineering/quality-review/presets-de-fecha/2026-06-10-1735-branch-quality-review.md`. M1 y M2 atendidos durante el sprint; M3, B1, B2 y B3 son opcionales.

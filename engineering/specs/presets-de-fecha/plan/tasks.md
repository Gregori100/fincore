# Tasks — Presets de fecha

## Frontend

- [ ] T001 Frontend: agregar `DATE_PRESETS` (array de `{ key, label }` con las 7 opciones en orden), `rangeForPreset(presetKey, today?)` y `detectPreset(from, to, today?)` en `frontend/src/utils/dates.js`. Reusar `firstDayOfMonth`, `lastDayOfMonth`, `toISODate` existentes.
  RF: RF-001, RF-002
  Depende de: ninguna
  Paralelizable: no (gate del helper)
  Criterio de terminado: funciones exportadas; sin romper imports existentes (`firstDayOfMonth`, etc.).

- [ ] T002 Pruebas: tests unit de `rangeForPreset` para los 7 presets con `today` fijo + casos borde (lunes, 1 del mes, 31 marzo, bisiesto, semana cruzando año, últimos 30 cruzando año, clave inválida lanza).
  RF: RF-001, RF-002
  Depende de: T001
  Paralelizable: no
  Criterio de terminado: 13+ tests verde en `npx vitest run tests/utils/dates.spec.js`.

- [ ] T003 Pruebas: tests unit de `detectPreset` (matchea 7 presets, no matchea → custom, vacíos/null → custom, no parseable → custom sin throw, orden estable).
  RF: RF-004
  Depende de: T001
  Paralelizable: sí (con T002)
  Criterio de terminado: 10+ tests verde.

- [ ] T004 Frontend: crear `frontend/src/components/finance/DateRangePreset.vue`. Props `modelValue: { from, to }`, `label?`, `disabled?`. Emit `update:modelValue`. Watcher `deep: true` sobre modelValue + `immediate: true` que sincroniza `preset.value`. Watcher sobre `preset` que emite el nuevo rango al cambiar a clave no-custom. BaseSelect con 8 opciones. Inputs from/to condicionales cuando `preset === 'custom'`.
  RF: RF-003, RF-004, RF-005, RF-006
  Depende de: T001
  Paralelizable: no (gate del componente)
  Criterio de terminado: componente renderiza sin warnings; tests T005 pasan.

- [ ] T005 Pruebas: tests del componente `DateRangePreset` (render inicial con preset, render con personalizado, cambio de dropdown emite update, edición de input emite update con objeto nuevo, watch externo a preset/custom, props label y disabled).
  RF: RF-003, RF-004, RF-005, RF-006
  Depende de: T004
  Paralelizable: no
  Criterio de terminado: 8+ tests verde.

- [ ] T006 Frontend: integrar `DateRangePreset` en `EntriesTable.vue`. Reemplazar los 2 `BaseInput` de `filters.from` y `filters.to` por `<DateRangePreset v-model="rangeModel" />` donde `rangeModel` es un computed con getter `{ from, to }` y setter que actualiza ambos (o pasar dos refs separadas si conviene). El default actual `DEFAULT_FROM = firstDayOfMonth()` y `DEFAULT_TO = lastDayOfMonth()` pasa a `DEFAULT_TO = toISODate()` (hoy) para alinear con preset `'this_month'`. La función `clearFilters` también debe ajustarse.
  RF: RF-007
  Depende de: T004
  Paralelizable: sí (con T007, T008)
  Criterio de terminado: `/entries` y `/accounts/:uuid` funcionan; dropdown detecta preset desde mount y query params.

- [ ] T007 Frontend: integrar `DateRangePreset` en `ReportsByCategoryView.vue`. Reemplazar los 2 `BaseInput from/to` y eliminar el botón `BaseButton "Este mes"` (cubierto por preset). Ajustar grid de `lg:grid-cols-4` a `lg:grid-cols-3` o equivalente para mantener layout limpio. La función `thisMonth()` se elimina.
  RF: RF-007
  Depende de: T004
  Paralelizable: sí
  Criterio de terminado: `/reports/by-category` renderiza con dropdown; cambios de preset disparan refetch via watcher existente.

- [ ] T008 Frontend: integrar `DateRangePreset` en `ReportsByAccountView.vue`. Reemplazar los 2 `BaseInput from/to`. El botón "Actualizar" se mantiene (es un refresh manual, no compite con presets).
  RF: RF-007
  Depende de: T004
  Paralelizable: sí
  Criterio de terminado: `/reports/by-account` renderiza con dropdown.

## Validacion de calidad

- [ ] T009 Validación: ejecutar suite frontend completa.
  Depende de: T006, T007, T008
  Paralelizable: no
  Criterio de terminado: `npx vitest run` verde (72 actuales + ~20 nuevos).

- [ ] T010 Validación: ejecutar suite backend completa para descartar regresión accidental.
  Depende de: T009
  Paralelizable: no
  Criterio de terminado: `php artisan test` verde 360/360.

- [ ] T011 Validación: smoke manual en navegador (8 escenarios del test-plan).
  Depende de: T010
  Paralelizable: no
  Criterio de terminado: 8/8 escenarios OK; capturas/notas en `implementation/`.

- [ ] T012 Validación: `branch-quality-review` con `slug=presets-de-fecha`.
  Depende de: T011
  Paralelizable: no
  Criterio de terminado: reporte generado; hallazgos atendidos antes de merge.

## Documentacion

- [ ] T013 Documentación: si `docs/frontend/README.md` lista componentes, agregar `DateRangePreset`. Si no, registrar en `implementation/` que no hay sección que actualizar.
  Depende de: T008
  Paralelizable: sí (con T009)
  Criterio de terminado: docs actualizados o nota en `implementation/`.

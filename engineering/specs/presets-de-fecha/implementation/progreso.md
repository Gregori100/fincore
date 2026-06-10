# Progreso de implementación

Todas las tareas T001..T013 completadas. Sin pendientes del sprint.

## Tareas completadas

### Helper (T001-T003)

- [x] T001 — `DATE_PRESETS` + `rangeForPreset` + `detectPreset` en `frontend/src/utils/dates.js`. Reusa `firstDayOfMonth`, `toISODate` existentes.
- [x] T002 — Tests de `rangeForPreset` (7 presets + 9 casos borde + clave inválida).
- [x] T003 — Tests de `detectPreset` (los 7 presets + custom + null/undefined/vacíos + tipos no-string + no parseables + orden estable).

### Componente (T004-T005)

- [x] T004 — `DateRangePreset.vue` con v-model `{from, to}`, watcher deep+immediate, flag `internalUpdate` para evitar loops, BaseSelect con 8 opciones, inputs condicionales.
- [x] T005 — 11 tests del componente.

### Integración (T006-T008)

- [x] T006 — `EntriesTable.vue` integrado. `DEFAULT_TO` cambiado de `lastDayOfMonth()` a `toISODate()`.
- [x] T007 — `ReportsByCategoryView.vue` integrado. Botón "Este mes" y función `thisMonth()` eliminados.
- [x] T008 — `ReportsByAccountView.vue` integrado. Layout cambiado de grid a stack vertical.

### Validación (T009-T013)

- [x] T009 — Suite frontend completa: 110/110 verde.
- [x] T010 — Suite backend completa: 360/360 verde (sin cambios).
- [x] T011 — Smoke manual con Playwright: 4/4 OK (`by-category` con switch entre 3 presets, `entries` con dropdown activo, `by-account` con dropdown activo, `cashflow` confirmado intacto).
- [x] T012 — `branch-quality-review` ejecutado. Reporte en `engineering/quality-review/presets-de-fecha/2026-06-10-1735-branch-quality-review.md`. M1 y M2 atendidos durante el sprint.
- [x] T013 — `docs/frontend/README.md` no lista componentes individuales; sin sección que actualizar (verificado durante el sprint).

## Validación previa de consistencia

Sin hallazgos bloqueantes. Plan, spec y test-plan alineados. Sin preguntas `pendiente`.

## Estado de pruebas

- Frontend: 110 tests, 3.49s.
- Backend: 360 tests, 5.97s.
- Smoke Playwright: 4/4 escenarios validados.
- Quality review: 0 bloqueantes, 0 altos, 2 medios atendidos (M1, M2), 1 medio documentado para monitoreo (M3), 3 bajos opcionales (B1, B2, B3).

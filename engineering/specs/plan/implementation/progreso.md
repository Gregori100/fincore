# Progreso de implementación — Plan

Ejecución completada 2026-05-19. Slug: `plan`.

## Estado por tarea

| ID | Categoría | Estado |
|----|-----------|--------|
| T001 | Backend (helper) | completado |
| T002 | Base de datos | completado |
| T003 | Base de datos | completado |
| T004 | Backend (modelo `PlannedEvent`) | completado |
| T005 | Backend (`occurrencesBetween`) | completado |
| T006 | Backend (modelo `PlannedEventOverride`) | completado |
| T007 | Backend (exception `InvalidRecurrence`) | completado |
| T008 | Backend (exception `OverrideOnNonOccurrence`) | completado |
| T009 | Backend (`CreatePlannedEvent`) | completado |
| T010 | Backend (`UpdatePlannedEvent`) | completado |
| T011 | Backend (`DeletePlannedEvent`) | completado |
| T012 | Backend (`CreatePlannedEventOverride`) | completado |
| T013 | Backend (`UpdatePlannedEventOverride`) | completado |
| T014 | Backend (`DeletePlannedEventOverride`) | completado |
| T015 | Backend (`PlanProjectionService`) | completado |
| T016 | Backend (`PlanController`) | completado |
| T017 | Backend (rutas) | completado |
| T018 | Backend (factory) | completado |
| T019 | Frontend (api client `plan.js`) | completado |
| T020 | Frontend (store Pinia `plan.js`) | completado |
| T021 | Frontend (`PlannedEventForm.vue`) | completado |
| T022 | Frontend (`PlannedEventList.vue`) | completado |
| T023 | Frontend (`PlannedEventOverrideForm.vue`) | completado |
| T024 | Frontend (`PlanProjectionTable.vue`) | completado |
| T025 | Frontend (`PlanProjectionChart.vue`) | completado |
| T026 | Frontend (`PlanView.vue`) | completado |
| T027 | Frontend (ruta) | completado |
| T028 | Frontend (link en `AppLayout.vue`) | completado |
| T029 | Pruebas (`CreatePlannedEventTest`) | completado (12/12) |
| T030 | Pruebas (`UpdatePlannedEventTest`) | completado (8/8) |
| T031 | Pruebas (`DeletePlannedEventTest`) | completado (3/3) |
| T032 | Pruebas (`PlannedEventOverrideTest`) | completado (10/10) |
| T033 | Pruebas (`PlanProjectionServiceTest`) | completado (13/13) |
| T034 | Pruebas (`PlanApiTest`) | completado (13/13) |
| T035 | Pruebas (`plan.spec.js` store) | completado (8/8) |
| T036 | Pruebas (smoke de componentes Vue) | pendiente parcial (ver pendientes.md) |
| T037 | Pruebas (suite backend completa) | completado (265/265) |
| T038 | Pruebas (suite frontend completa) | completado (49/49) |
| T039 | Pruebas (recorrido manual UI) | pendiente (requiere el usuario) |
| T040 | Validación (`branch-quality-review`) | pendiente (sugerido antes del merge) |
| T041 | Documentación (`CLAUDE.md`) | completado |
| T042 | Documentación (memoria del proyecto) | pendiente |

## Tests verdes

- **Backend**: 265 tests, 524 assertions (línea base anterior 206; +59 nuevos del Plan).
- **Frontend**: 49 tests, todos verdes (línea base anterior 41; +8 nuevos del store).

## Migración aplicada

```
2026_05_19_120000_create_planned_events_table ... DONE
2026_05_19_120001_create_planned_event_overrides_table ... DONE
```

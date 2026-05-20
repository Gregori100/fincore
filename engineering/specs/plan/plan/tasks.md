# Tasks — Plan (proyección financiera a 6 meses)

Orden general: helper compartido → backend (entidad principal → overrides → motor) → frontend (CRUD → tabla → gráfica) → docs.

Cada tarea se cierra con el criterio explícito; las pruebas asociadas también son tarea.

## Backend

- [ ] T001 Backend: extraer `validateAccountsForKind` de `UpdateJournalEntry` a un helper compartido `backend/app/Domain/Finance/Support/JournalKindContract.php`.
  RF: RF-002
  Depende de: ninguna
  Paralelizable: no
  Criterio de terminado: el helper expone `static validateAccountsForKind(string $userId, string $kind, ?string $originId, ?string $destinationId): void`; `UpdateJournalEntry` lo invoca y todos los tests existentes (`UpdateJournalEntryTest`, 22 casos) siguen verdes sin tocarlos.

- [ ] T002 Base de datos: crear migración `2026_05_19_120000_create_planned_events_table.php` con todas las columnas, índices y FKs definidas en `plan.md → Cambios de datos`.
  RF: RF-001
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: `php artisan migrate` sube limpia; `php artisan migrate:rollback` baja limpia; el schema en Postgres coincide con la definición.

- [ ] T003 Base de datos: crear migración `2026_05_19_120001_create_planned_event_overrides_table.php` con su FK CASCADE a `planned_events` y el unique compuesto.
  RF: RF-005
  Depende de: T002
  Paralelizable: no
  Criterio de terminado: schema correcto; unique violation al insertar duplicado lanza error Postgres.

- [ ] T004 Backend: modelo `App\Models\PlannedEvent` con `HasUuids`, `$fillable` explícito, relaciones `user()`, `origin()`, `destination()`, `category()`, `overrides()`.
  RF: RF-001
  Depende de: T002
  Paralelizable: si
  Criterio de terminado: el modelo carga relaciones correctamente; `$casts` incluye `start_date` y `end_date` como `date`.

- [ ] T005 Backend: método estático `PlannedEvent::occurrencesBetween(Carbon $from, Carbon $to): Collection<Carbon>` que genera las ocurrencias de una regla en un rango. Maneja `weekly` (clamp al día de semana), `monthly` (clamp al último día del mes), `one_off`.
  RF: RF-007
  Depende de: T004
  Paralelizable: si
  Criterio de terminado: el método retorna las fechas esperadas para los 3 tipos; cobertura unitaria con casos clamp.

- [ ] T006 Backend: modelo `App\Models\PlannedEventOverride` con `HasUuids`, `$fillable`, relación `event()`.
  RF: RF-005
  Depende de: T003
  Paralelizable: si
  Criterio de terminado: el modelo está listo; `$casts` incluye `occurrence_date` como `date` e `is_skipped` como `bool`.

- [ ] T007 Backend: exception `App\Domain\Finance\Plan\Exceptions\InvalidRecurrence` extiende `DomainException` con código `invalid_recurrence` 422.
  RF: RF-001
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: hereda render JSON estándar del proyecto.

- [ ] T008 Backend: exception `App\Domain\Finance\Plan\Exceptions\OverrideOnNonOccurrence` extiende `DomainException` con código `override_on_non_occurrence` 422.
  RF: RF-005
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: hereda render JSON estándar.

- [ ] T009 Backend: Action `App\Domain\Finance\Plan\Actions\CreatePlannedEvent` que valida invariantes (amount > 0, fechas, recurrence_day según type), invoca `JournalKindContract::validateAccountsForKind`, valida categoría con `appliesToKind` y persiste.
  RF: RF-001, RF-002
  Depende de: T001, T004, T007
  Paralelizable: no
  Criterio de terminado: cubre los 12 casos del `CreatePlannedEventTest`.

- [ ] T010 Backend: Action `UpdatePlannedEvent` con `EDITABLE_FIELDS` (todo salvo `kind`), valida invariantes, recalcula validación tipo↔kind si cuentas cambian, borra overrides huérfanos cuando la recurrencia cambia, devuelve `['event' => $event, 'removed_overrides' => $n]`.
  RF: RF-004
  Depende de: T009
  Paralelizable: no
  Criterio de terminado: cubre los 8 casos del `UpdatePlannedEventTest`.

- [ ] T011 Backend: Action `DeletePlannedEvent` hard delete + cascada por FK.
  RF: RF-004
  Depende de: T009
  Paralelizable: si
  Criterio de terminado: cubre los 3 casos del `DeletePlannedEventTest`.

- [ ] T012 Backend: Action `CreatePlannedEventOverride` valida que `occurrence_date` corresponde a una ocurrencia real (`PlannedEvent::occurrencesBetween` la incluye); valida que el evento no es `one_off`; persiste.
  RF: RF-005
  Depende de: T005, T006, T008
  Paralelizable: no
  Criterio de terminado: cubre los 10 casos del `PlannedEventOverrideTest`.

- [ ] T013 Backend: Action `UpdatePlannedEventOverride` permite cambiar `amount` y `is_skipped` únicamente; rechaza cambios sobre la `occurrence_date`.
  RF: RF-006
  Depende de: T012
  Paralelizable: si
  Criterio de terminado: tests de edición pasan; intento de cambiar `occurrence_date` rechaza.

- [ ] T014 Backend: Action `DeletePlannedEventOverride` hard delete.
  RF: RF-006
  Depende de: T012
  Paralelizable: si
  Criterio de terminado: test pasa; la ocurrencia vuelve a usar el monto del evento base en la proyección.

- [ ] T015 Backend: Service `App\Domain\Finance\Plan\Services\PlanProjectionService` con `project(string $userId, int $horizonMonths = 6): array` que combina snapshot de `FinancialStateService` + ocurrencias + overrides y produce `{ horizon, accounts, series, events }`.
  RF: RF-007, RF-012
  Depende de: T005, T006, T012
  Paralelizable: no
  Criterio de terminado: cubre los 18 casos de `PlanProjectionServiceTest`.

- [ ] T016 Backend: controller `App\Http\Controllers\PlanController` con 7 endpoints (list/create/update/delete events, create/update/delete overrides, projection) y validación de payload Laravel.
  RF: RF-001, RF-003, RF-004, RF-005, RF-006, RF-007
  Depende de: T009, T010, T011, T012, T013, T014, T015
  Paralelizable: no
  Criterio de terminado: cubre el flujo HTTP completo; reusa `JournalKindContract` para la validación de cuenta-kind.

- [ ] T017 Backend: agregar 7 rutas en `backend/routes/api.php` dentro del grupo `['auth:sanctum', 'verified']` prefijado por `/finance`.
  RF: RF-001..RF-007
  Depende de: T016
  Paralelizable: no
  Criterio de terminado: `php artisan route:list --path=finance/plan` lista exactamente las 7 rutas.

- [ ] T018 Backend: factory `database/factories/PlannedEventFactory.php` con `weekly()`, `monthly()`, `oneOff()` states. Sin seeder default.
  RF: RF-001
  Depende de: T004
  Paralelizable: si
  Criterio de terminado: la factory crea instancias válidas y se usa en los tests siguientes.

## Frontend

- [ ] T019 Frontend: cliente axios `frontend/src/api/plan.js` con funciones `listEvents`, `createEvent`, `updateEvent`, `deleteEvent`, `createOverride`, `updateOverride`, `deleteOverride`, `projection`. Reutilizar el cliente base `frontend/src/api/client.js`.
  RF: RF-001..RF-007
  Depende de: T016
  Paralelizable: si
  Criterio de terminado: módulo exporta las 8 funciones tipadas con JSDoc mínimo.

- [ ] T020 Frontend: store Pinia `frontend/src/stores/plan.js` con state `events: []`, `projection: null`, `loading: false`, `error: null`. Actions: `fetchEvents`, `createEvent`, `updateEvent`, `deleteEvent`, `createOverride`, `updateOverride`, `deleteOverride`, `fetchProjection`. Cada mutación invalida y refetchea la proyección.
  RF: RF-009
  Depende de: T019
  Paralelizable: no
  Criterio de terminado: pasa `tests/stores/plan.spec.js` (8 casos).

- [ ] T021 Frontend: componente `PlannedEventForm.vue` con campos según `kind` (cuentas condicionales), `recurrence_type` (radio o segmented control) que muestra/oculta `recurrence_day` (day-of-week para weekly, número 1..31 para monthly), `start_date`, `end_date`, `amount`, `description`, `category_id`. Reusar `BaseInput`, `BaseSelect`, `BaseModal`.
  RF: RF-001, RF-002
  Depende de: T020
  Paralelizable: si
  Criterio de terminado: form crea y edita eventos sin error; validación cliente bloquea submits inválidos.

- [ ] T022 Frontend: componente `PlannedEventList.vue` con lista de eventos agrupados por tipo o filtrables, botón "Nuevo evento" que abre `PlannedEventForm` en modal, acciones inline "Editar" y "Eliminar" (con `BaseConfirm`). Badge "cuenta archivada" cuando aplica.
  RF: RF-003, RF-004, RF-012
  Depende de: T021
  Paralelizable: si
  Criterio de terminado: la lista refleja los eventos del store; CRUD completo funciona desde la UI.

- [ ] T023 Frontend: componente `PlannedEventOverrideForm.vue` en modal: dos controles (input `amount` opcional, checkbox `is_skipped`), botón "Eliminar override" si ya existe.
  RF: RF-005, RF-006
  Depende de: T020
  Paralelizable: si
  Criterio de terminado: crea y edita override; refresca proyección al cerrar.

- [ ] T024 Frontend: componente `PlanProjectionTable.vue` con fila por ocurrencia. Columnas: fecha, kind (con badge color), monto, cuentas, descripción, indicadores `override` / `saltada`. Click en fila abre `PlannedEventOverrideForm` con la `(planned_event_id, occurrence_date)` correspondiente.
  RF: RF-011
  Depende de: T020, T023
  Paralelizable: si
  Criterio de terminado: pasa `PlanProjectionTable.spec.js` y refleja correctamente todas las variantes de ocurrencia.

- [ ] T025 Frontend: componente `PlanProjectionChart.vue` instancia Chart.js (mismo patrón que `MonthlyCashflowChart.vue`). Una línea por cuenta no archivada; usa colores de la paleta CSS variables; leyenda clickable para toggle de series.
  RF: RF-010
  Depende de: T020
  Paralelizable: si
  Criterio de terminado: la gráfica renderiza con datos reales; smoke test monta el componente sin errores.

- [ ] T026 Frontend: vista `PlanView.vue` que orquesta hero con tiles (BO/DE proyectados, primera deuda en 0), `PlannedEventList`, `PlanProjectionChart` y `PlanProjectionTable`. Llama `fetchEvents` y `fetchProjection` en `onMounted`.
  RF: RF-008
  Depende de: T022, T024, T025
  Paralelizable: no
  Criterio de terminado: vista carga limpia con stack docker arriba; navegación desde dashboard fluida.

- [ ] T027 Frontend: ruta `/plan` en `frontend/src/router/index.js` con `meta: { requiresAuth: true }` y lazy import.
  RF: RF-008
  Depende de: T026
  Paralelizable: no
  Criterio de terminado: navegar a `/plan` carga la vista.

- [ ] T028 Frontend: agregar link "Plan" en `frontend/src/components/layout/AppLayout.vue` (topbar desktop + drawer mobile), entre "Movimientos" y "Reportes".
  RF: RF-008
  Depende de: T027
  Paralelizable: no
  Criterio de terminado: el link aparece en ambos breakpoints y navega a `/plan`.

## Pruebas

- [ ] T029 Pruebas: `backend/tests/Feature/Plan/CreatePlannedEventTest.php` con los 12 casos listados en `test-plan.md → Pruebas unitarias`.
  RF: RF-001, RF-002
  Depende de: T009, T018
  Paralelizable: si
  Criterio de terminado: 12/12 verdes.

- [ ] T030 Pruebas: `backend/tests/Feature/Plan/UpdatePlannedEventTest.php` con los 8 casos.
  RF: RF-004
  Depende de: T010, T018
  Paralelizable: si
  Criterio de terminado: 8/8 verdes.

- [ ] T031 Pruebas: `backend/tests/Feature/Plan/DeletePlannedEventTest.php` con los 3 casos.
  RF: RF-004
  Depende de: T011, T018
  Paralelizable: si
  Criterio de terminado: 3/3 verdes.

- [ ] T032 Pruebas: `backend/tests/Feature/Plan/PlannedEventOverrideTest.php` con los 10 casos.
  RF: RF-005, RF-006
  Depende de: T012, T013, T014, T018
  Paralelizable: si
  Criterio de terminado: 10/10 verdes.

- [ ] T033 Pruebas: `backend/tests/Feature/Plan/PlanProjectionServiceTest.php` con los 18 casos.
  RF: RF-007, RF-012
  Depende de: T015, T018
  Paralelizable: si
  Criterio de terminado: 18/18 verdes; cobertura ≥ 90% de `PlanProjectionService`.

- [ ] T034 Pruebas: `backend/tests/Feature/Http/PlanApiTest.php` con los 15 casos (incluye uno marcado `@group performance`).
  RF: RF-001..RF-007, RF-013
  Depende de: T017
  Paralelizable: si
  Criterio de terminado: 15/15 verdes.

- [ ] T035 Pruebas: `frontend/tests/stores/plan.spec.js` con los 8 casos del store.
  RF: RF-009
  Depende de: T020
  Paralelizable: si
  Criterio de terminado: 8/8 verdes en vitest.

- [ ] T036 Pruebas: componentes smoke `PlannedEventForm.spec.js`, `PlanProjectionTable.spec.js`, `PlanProjectionChart.spec.js`.
  RF: RF-001, RF-010, RF-011
  Depende de: T021, T024, T025
  Paralelizable: si
  Criterio de terminado: cada smoke test verde.

- [ ] T037 Pruebas: ejecutar la suite backend completa y verificar que no hay regresión (≥ 250 tests verdes, antes 206 + ~44 nuevos).
  RF: todos
  Depende de: T029..T034
  Paralelizable: no
  Criterio de terminado: `docker compose exec -T api php artisan test` retorna exit 0.

- [ ] T038 Pruebas: ejecutar la suite frontend completa (≥ 48 tests verdes).
  RF: todos
  Depende de: T035, T036
  Paralelizable: no
  Criterio de terminado: `cd frontend && npm run test` retorna exit 0.

- [ ] T039 Pruebas: recorrido manual de 10 pasos descrito en `test-plan.md → Pruebas manuales`.
  RF: todos
  Depende de: T028, T037, T038
  Paralelizable: no
  Criterio de terminado: los 10 pasos pasan sin errores en `localhost:5173`.

## Validacion de calidad

- [ ] T040 Validación: invocar `/branch-quality-review` con `slug=plan` para revisión exhaustiva de la rama (seguridad, autorización, SQL, concurrencia, performance, DDD, frontend, UX, validaciones, regresiones).
  RF: todos
  Depende de: T039
  Paralelizable: no
  Criterio de terminado: el reporte en `engineering/quality-review/plan/` no contiene hallazgos bloqueantes sin resolver.

## Documentación

- [ ] T041 Documentación: actualizar `CLAUDE.md` con sección "Plan / proyección financiera" en el lugar lógico (cerca de Reportes), tabla con los 7 endpoints, y nota sobre el helper `JournalKindContract`.
  RF: todos
  Depende de: T017
  Paralelizable: si
  Criterio de terminado: la sección es consistente con el resto del documento.

- [ ] T042 Documentación: actualizar memoria del proyecto (`MEMORY.md` + `project_backlog.md`) marcando el feature como cerrado y agregando lecciones aprendidas si surgen.
  RF: todos
  Depende de: T041
  Paralelizable: si
  Criterio de terminado: las memorias reflejan el estado actual sin contradicciones.

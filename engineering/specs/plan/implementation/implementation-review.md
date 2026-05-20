# Implementation Review: plan

## Resumen de lo implementado

Subdominio nuevo y autocontenido `backend/app/Domain/Finance/Plan/` que entrega proyección financiera a 6 meses sin tocar `journal_entries`. Incluye dos entidades (`PlannedEvent`, `PlannedEventOverride`), seis Actions de CRUD, un motor (`PlanProjectionService`), controller con 8 endpoints REST y dos exceptions de dominio. Refactor mínimo en `UpdateJournalEntry` para reutilizar el helper compartido `JournalKindContract`. Frontend con vista `/plan` dedicada, store Pinia, 5 componentes Vue y link en topbar/drawer. Suite backend en 265/265 verde (línea base 206, +59 del Plan); frontend 49/49 verde (+8 nuevos en store).

## Archivos principales modificados

### Nuevos (backend)

- `backend/app/Domain/Finance/Support/JournalKindContract.php`
- `backend/database/migrations/2026_05_19_120000_create_planned_events_table.php`
- `backend/database/migrations/2026_05_19_120001_create_planned_event_overrides_table.php`
- `backend/app/Models/PlannedEvent.php` (incluye `occurrencesBetween` y `occursOn`)
- `backend/app/Models/PlannedEventOverride.php`
- `backend/app/Domain/Finance/Plan/Exceptions/InvalidRecurrence.php`
- `backend/app/Domain/Finance/Plan/Exceptions/OverrideOnNonOccurrence.php`
- `backend/app/Domain/Finance/Plan/Actions/{CreatePlannedEvent,UpdatePlannedEvent,DeletePlannedEvent,CreatePlannedEventOverride,UpdatePlannedEventOverride,DeletePlannedEventOverride}.php`
- `backend/app/Domain/Finance/Plan/Services/PlanProjectionService.php`
- `backend/app/Http/Controllers/PlanController.php`
- `backend/database/factories/PlannedEventFactory.php`

### Nuevos (frontend)

- `frontend/src/api/plan.js`
- `frontend/src/stores/plan.js`
- `frontend/src/views/app/PlanView.vue`
- `frontend/src/components/finance/PlannedEventForm.vue`
- `frontend/src/components/finance/PlannedEventList.vue`
- `frontend/src/components/finance/PlannedEventOverrideForm.vue`
- `frontend/src/components/finance/PlanProjectionTable.vue`
- `frontend/src/components/finance/PlanProjectionChart.vue`

### Modificados

- `backend/app/Domain/Finance/Actions/UpdateJournalEntry.php` (delega al helper)
- `backend/routes/api.php` (8 rutas nuevas + import del controller)
- `frontend/src/router/index.js` (ruta `/plan`)
- `frontend/src/components/layout/AppLayout.vue` (link "Plan")
- `CLAUDE.md` (sección dedicada al Plan + tabla de endpoints)

### Nuevos (tests)

- `backend/tests/Feature/Plan/CreatePlannedEventTest.php` (12)
- `backend/tests/Feature/Plan/UpdatePlannedEventTest.php` (8)
- `backend/tests/Feature/Plan/DeletePlannedEventTest.php` (3)
- `backend/tests/Feature/Plan/PlannedEventOverrideTest.php` (10)
- `backend/tests/Feature/Plan/PlanProjectionServiceTest.php` (13)
- `backend/tests/Feature/Http/PlanApiTest.php` (13)
- `frontend/tests/stores/plan.spec.js` (8)

## Tareas completadas

T001..T035 + T037..T038 + T041. Detalle por ID en `progreso.md`.

## Tareas pendientes

- T036: smokes de componentes Vue diferidos (justificado en `pendientes.md`).
- T039: recorrido manual de 10 pasos. Requiere el usuario.
- T040: `branch-quality-review` sugerido antes del merge.
- T042: actualizar memoria del proyecto.

## Riesgos residuales

- **Drift entre carriles**: la proyección no se reconcilia con los `journal_entries` reales. Si el usuario abandona el plan en la vida real, la proyección queda desactualizada. Documentado en spec como aceptable v1.
- **Zona horaria del server**: el horizonte usa `Carbon::today()` del server. Pendiente decidir si se setea `APP_TIMEZONE=America/Mexico_City` en producción (Fly.io) o se introduce TZ por usuario en v2.
- **Performance**: probada empíricamente solo con casos pequeños en tests; no se ejecutó la prueba de 50 eventos. El motor es O(eventos × ocurrencias) sin sorpresas, pero conviene medir en producción.
- **Build de producción Vite**: el comando `npm run build` falla por permisos sobre `dist/` (artefacto del montaje docker). El runtime dev de Vite funciona normal con HMR; el build prod habría que correrlo en una imagen separada o limpiar permisos. No es un blocker del feature; lo es del deploy.
- **Soft delete de Account vs FK RESTRICT**: las FKs en `planned_events` están en `RESTRICT`, pero `Account` usa soft delete (`deleted_at`), por lo que el RESTRICT solo dispara en hard delete. Los soft deletes siguen funcionando y el motor de proyección detecta cuentas archivadas y marca las ocurrencias como `archived_account`. Consistente con la filosofía libreta libre.

## Pruebas realizadas

- 265/265 suite backend completa (`php artisan test`).
- 59/59 tests específicos del subdominio Plan.
- 49/49 suite frontend (`npm run test`).
- Migración aplicada en stack docker (`./scripts/fincore migrate`) y schema verificado por `php artisan route:list --path=finance/plan` (8 rutas).
- Suite backend post-refactor de `UpdateJournalEntry`: 25/25 verdes sin tocar tests existentes (regresión cero).

## Pruebas recomendadas

- Recorrido manual completo (T039) en `localhost:5173`. Especialmente: cambio de `recurrence_day` con overrides, archivado de cuenta usada por evento, sobrepago en simulación.
- Stress test informal: crear ~50 eventos y medir `/api/finance/plan/projection`. Si excede 500 ms, considerar caché en memoria por request.
- Verificar comportamiento de la gráfica con `prefers-color-scheme: light` por si las CSS variables resuelven a colores distintos.

## Posibles regresiones

- `UpdateJournalEntry`: refactorizado para usar el helper. Los 22 tests existentes (`UpdateJournalEntryTest`) siguen verdes sin modificación, lo que prueba ausencia de regresión funcional.
- Ninguna otra Action del dominio Finance fue tocada.
- El frontend reusa `BaseInput`, `BaseSelect`, `BaseModal`, `BaseButton`, `BaseConfirm` existentes sin modificarlos.
- E2E (`tests-e2e/specs/entries.spec.js`) ya tenía un test desactualizado por sprint previo (`/entries` dropdown removido); no se introdujo nuevo desfase. Ver `pendientes.md` global.

## Recomendaciones para code review humano

1. Verificar el `JournalKindContract` extraído: el método público estático preserva exactamente la firma y la semántica del privado anterior en `UpdateJournalEntry`.
2. Revisar `PlannedEvent::occurrencesBetween` y `occursOn` con atención: son el corazón del motor, y los tests cubren clamp mensual, weekly skewed start_date y rango inclusivo.
3. Confirmar que las dos FKs `ON DELETE RESTRICT` en la migración son lo deseado (vs. SET NULL u otro). La spec lo justifica como "no permitir borrar cuentas con eventos vivos".
4. Validar el flujo del PATCH event que elimina overrides huérfanos: testeado, pero al ser un side effect importante conviene que el reviewer humano lo recorra mentalmente.
5. Confirmar la decisión de no incluir `transfer` como tipo de evento planeado en v1 (documentado en spec).
6. El endpoint de proyección NO cachea. Para uso individual no hay riesgo, pero si en el futuro se llama con frecuencia desde Auto-refresh, valorar memoización en request.
7. Lanzar `/branch-quality-review slug=plan` antes del merge (recomendado por el plan).

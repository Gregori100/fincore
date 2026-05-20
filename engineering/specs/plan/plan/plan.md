# Plan técnico — Plan (proyección financiera a 6 meses)

## Enfoque tecnico

Se agrega un subdominio nuevo y autocontenido bajo `backend/app/Domain/Finance/Plan/`, paralelo a los ya existentes `Actions/`, `Services/`, `Reports/`. Su misión es persistir reglas y excepciones de eventos futuros (`PlannedEvent`, `PlannedEventOverride`) y producir, bajo demanda, una proyección de saldos por cuenta a 6 meses tomando como punto de partida lo que devuelve `FinancialStateService`.

La capa es estrictamente aditiva: no toca `journal_entries`, no cambia ningún Action de creación de movimientos, no toca el balance real. La simulación se calcula al vuelo cada vez que se consulta el endpoint, sin caché ni colas, porque el orden de magnitud es muy chico (5–20 eventos × ~180 días = ~3 000 operaciones aritméticas).

En el frontend se agrega una ruta `/plan` de primer nivel (no subruta de `/reports`) que contiene tres bloques: lista CRUD de eventos planeados, gráfica de líneas (reusando el patrón de Chart.js que ya usa `MonthlyCashflowChart`), y tabla cronológica de próximas ocurrencias con edición inline para crear overrides. Se agrega un store Pinia nuevo `frontend/src/stores/plan.js` para mantener limpio el `finance.js`.

La validación de tipo↔kind (que asegura que un `expense` apunte a cash/debit, un `credit_expense` a credit, etc.) hoy vive como método privado de `UpdateJournalEntry::validateAccountsForKind`. Como ahora dos lugares la necesitan (UpdateJournalEntry y las Actions de Plan), se extrae a un helper compartido `backend/app/Domain/Finance/Support/JournalKindContract.php` que ambas consumen sin duplicación.

## Requisitos funcionales cubiertos

- RF-001 (crear PlannedEvent con todos los campos): `CreatePlannedEvent` Action + `POST /api/finance/plan/events` + `PlannedEventForm.vue`.
- RF-002 (validar contrato tipo↔kind): helper compartido `JournalKindContract::validateAccountsForKind` invocado desde `CreatePlannedEvent` y `UpdatePlannedEvent`.
- RF-003 (listar eventos del user): `GET /api/finance/plan/events` con scope estricto por `user_id`.
- RF-004 (actualizar/eliminar evento): `UpdatePlannedEvent` + `DeletePlannedEvent` Actions, hard delete en cascada para overrides asociados (FK `ON DELETE CASCADE`).
- RF-005 (override de ocurrencia): `CreatePlannedEventOverride` Action que valida que `(planned_event_id, occurrence_date)` corresponda a una ocurrencia real de la regla.
- RF-006 (actualizar/eliminar override): `UpdatePlannedEventOverride` + `DeletePlannedEventOverride`.
- RF-007 (endpoint proyección): `GET /api/finance/plan/projection` retorna `{ events: [...], series: { account_id: [{ date, balance }] } }`.
- RF-008 (vista `/plan` con lista + form + gráfica + tabla): `PlanView.vue` orquesta los 4 componentes hijos.
- RF-009 (recálculo inmediato post-edición): el store de Pinia invalida la proyección tras cada mutación y la UI hace `fetchProjection` al volver al success del modal.
- RF-010 (gráfica con múltiples series ocultables): `PlanProjectionChart.vue` usa Chart.js con `legend.onClick` estándar para toggle de series.
- RF-011 (tabla cronológica con indicador de override y saltada): `PlanProjectionTable.vue` con badges visuales.
- RF-012 (cuenta archivada => skip y badge): el motor produce ocurrencias con `skipped_reason = "archived_account"`; UI muestra badge.
- RF-013 (rechazar fechas fuera de rango razonable): validación en controller con regla custom (`start_date >= today-1y && start_date <= today+5y`).

## Archivos o modulos probablemente afectados

### Backend (Laravel, todo nuevo)

- `backend/database/migrations/2026_05_19_120000_create_planned_events_table.php` (nueva).
- `backend/database/migrations/2026_05_19_120001_create_planned_event_overrides_table.php` (nueva).
- `backend/app/Models/PlannedEvent.php` (nuevo).
- `backend/app/Models/PlannedEventOverride.php` (nuevo).
- `backend/app/Domain/Finance/Plan/Actions/CreatePlannedEvent.php` (nuevo).
- `backend/app/Domain/Finance/Plan/Actions/UpdatePlannedEvent.php` (nuevo).
- `backend/app/Domain/Finance/Plan/Actions/DeletePlannedEvent.php` (nuevo).
- `backend/app/Domain/Finance/Plan/Actions/CreatePlannedEventOverride.php` (nuevo).
- `backend/app/Domain/Finance/Plan/Actions/UpdatePlannedEventOverride.php` (nuevo).
- `backend/app/Domain/Finance/Plan/Actions/DeletePlannedEventOverride.php` (nuevo).
- `backend/app/Domain/Finance/Plan/Services/PlanProjectionService.php` (nuevo).
- `backend/app/Domain/Finance/Plan/Exceptions/InvalidRecurrence.php` (nuevo, 422).
- `backend/app/Domain/Finance/Plan/Exceptions/OverrideOnNonOccurrence.php` (nuevo, 422).
- `backend/app/Domain/Finance/Support/JournalKindContract.php` (nuevo helper compartido).
- `backend/app/Domain/Finance/Actions/UpdateJournalEntry.php` (refactor menor: delegar al helper).
- `backend/app/Http/Controllers/PlanController.php` (nuevo).
- `backend/routes/api.php` (agregar 7 rutas bajo `/finance/plan/*`).

### Frontend (Vue 3, todo nuevo salvo router y nav)

- `frontend/src/api/plan.js` (nuevo, cliente axios para los 7 endpoints).
- `frontend/src/stores/plan.js` (nuevo store Pinia: state events + projection, actions fetch/create/update/delete).
- `frontend/src/views/app/PlanView.vue` (nuevo, orquesta lista + gráfica + tabla).
- `frontend/src/components/finance/PlannedEventList.vue` (nuevo).
- `frontend/src/components/finance/PlannedEventForm.vue` (nuevo, crear/editar).
- `frontend/src/components/finance/PlanProjectionChart.vue` (nuevo, Chart.js).
- `frontend/src/components/finance/PlanProjectionTable.vue` (nuevo, con botón inline "editar ocurrencia").
- `frontend/src/components/finance/PlannedEventOverrideForm.vue` (nuevo, modal para crear/editar override).
- `frontend/src/router/index.js` (agregar ruta `/plan` lazy).
- `frontend/src/components/layout/AppLayout.vue` (agregar link "Plan" en la topbar/drawer).

### Tests

- `backend/tests/Feature/Plan/CreatePlannedEventTest.php`.
- `backend/tests/Feature/Plan/UpdatePlannedEventTest.php`.
- `backend/tests/Feature/Plan/DeletePlannedEventTest.php`.
- `backend/tests/Feature/Plan/PlannedEventOverrideTest.php`.
- `backend/tests/Feature/Plan/PlanProjectionServiceTest.php`.
- `backend/tests/Feature/Http/PlanApiTest.php`.
- `frontend/tests/stores/plan.spec.js`.

### Documentación

- `CLAUDE.md` (sección nueva "Plan / proyección financiera" + tabla de endpoints).

## Entidades y estados afectados

### `PlannedEvent`

- Identidad: `id` UUID v7.
- Pertenencia: `user_id` UUID (FK a users, ON DELETE CASCADE).
- Campos: `kind` (`income` | `expense` | `credit_expense` | `debt_payment`), `amount` decimal(12,2) > 0, `account_origin_id` UUID nullable, `account_destination_id` UUID nullable (FKs nullable a accounts, ON DELETE RESTRICT — no permitir borrar cuentas con eventos vivos), `description` string nullable, `category_id` UUID nullable (FK a categories), `recurrence_type` (`one_off` | `weekly` | `monthly`), `recurrence_day` smallint nullable (0..6 para weekly, 1..31 para monthly), `start_date` date, `end_date` date nullable.
- Sin estados de máquina: el evento es válido o no existe. Hard delete cuando se borra.
- Invariantes:
  - `amount > 0`.
  - `start_date <= end_date` cuando `end_date` no es nulo.
  - `recurrence_day` rango válido según `recurrence_type` (NOT NULL para weekly/monthly, IGNORED para one_off).
  - Combinación `kind` + cuentas respeta el contrato compartido.

### `PlannedEventOverride`

- Identidad: `id` UUID v7.
- Pertenencia: `planned_event_id` UUID (FK a planned_events, ON DELETE CASCADE).
- Campos: `occurrence_date` date NOT NULL, `amount` decimal(12,2) nullable, `is_skipped` bool default false.
- Constraint único: `(planned_event_id, occurrence_date)` para que un override por ocurrencia.
- Invariantes:
  - `occurrence_date` debe ser una ocurrencia real generada por la regla del evento padre. Validado en Action.
  - `amount` y `is_skipped` son mutuamente alternativos lógicamente: si `is_skipped = true`, `amount` se ignora; si `is_skipped = false`, `amount` debe estar presente.
  - Solo aplica sobre eventos `weekly` o `monthly`. Los `one_off` no aceptan overrides.

### Estado simulado (transient, no persiste)

- Para cada cuenta no archivada, un running balance que parte del valor de `FinancialStateService::getAccountBalance(id)` y se modifica con cada ocurrencia aplicada.
- Para cada ocurrencia en la timeline: `{ date, kind, amount_effective, accounts, source: "rule" | "override", warnings: ["overpay" | "archived_account"], skipped: bool }`.

## Compatibilidad con datos y procesos existentes

- **Cero cambios al schema actual**. Las dos tablas nuevas son aditivas.
- **`UpdateJournalEntry` se refactoriza** para delegar la validación tipo↔kind al helper compartido. El comportamiento externo es exactamente el mismo; los tests existentes (22 en `UpdateJournalEntryTest`) deben seguir pasando sin tocar una línea.
- **FK `ON DELETE RESTRICT` en `planned_events.account_origin_id` y `account_destination_id`**: si el usuario intenta archivar (soft delete) o eliminar una cuenta, debe poder hacerlo (Account ya es soft delete y la FK respeta `deleted_at` en Eloquent). Si en el futuro se introduce hard delete de Account, el RESTRICT impedirá borrar cuentas con eventos vivos. La spec acepta que cuentas archivadas con eventos producen ocurrencias saltadas (no se bloquea archivado). Esto es coherente porque soft delete no dispara el constraint FK.
- **Reportes existentes (`/reports/*`)**: ningún reporte lee `planned_events`. Cero interacción.
- **CLI commands `fin:*`**: no se extienden en v1. Los eventos planeados son configurables solo vía API/UI.
- **E2E spec actual `entries.spec.js`**: no interactúa con `/plan`. Sin impacto.

## Cambios de datos

### Migración 1 — `create_planned_events_table`

```text
planned_events
  id                       uuid (HasUuids) PK
  user_id                  uuid NOT NULL, FK users.id ON DELETE CASCADE
  kind                     string(32) NOT NULL (income|expense|credit_expense|debt_payment)
  amount                   decimal(12,2) NOT NULL CHECK (amount > 0)
  account_origin_id        uuid NULL, FK accounts.id ON DELETE RESTRICT
  account_destination_id   uuid NULL, FK accounts.id ON DELETE RESTRICT
  category_id              uuid NULL, FK categories.id ON DELETE SET NULL
  description              string(200) NULL
  recurrence_type          string(16) NOT NULL (one_off|weekly|monthly)
  recurrence_day           smallint NULL
  start_date               date NOT NULL
  end_date                 date NULL
  created_at, updated_at   timestamps
  INDEX (user_id, start_date)
```

### Migración 2 — `create_planned_event_overrides_table`

```text
planned_event_overrides
  id                       uuid (HasUuids) PK
  planned_event_id         uuid NOT NULL, FK planned_events.id ON DELETE CASCADE
  occurrence_date          date NOT NULL
  amount                   decimal(12,2) NULL CHECK (amount IS NULL OR amount > 0)
  is_skipped               boolean NOT NULL DEFAULT false
  created_at, updated_at   timestamps
  UNIQUE (planned_event_id, occurrence_date)
```

Sin seeders. Sin migraciones de datos existentes.

## Cambios de API

Nuevas rutas dentro de `Route::middleware(['auth:sanctum', 'verified'])->prefix('finance')->group(...)`:

- `GET /api/finance/plan/events` → lista los eventos planeados del usuario actual.
- `POST /api/finance/plan/events` → crea un evento. Payload: `kind, amount, account_origin_id?, account_destination_id?, category_id?, description?, recurrence_type, recurrence_day?, start_date, end_date?`.
- `PATCH /api/finance/plan/events/{id}` → edita un evento existente. Mismos campos permitidos. Si cambia `recurrence_type`/`recurrence_day`/`start_date`/`end_date`, los overrides cuya `occurrence_date` deja de corresponder a una ocurrencia real quedan huérfanos y se eliminan en cascada (decisión: opción más simple y segura). Esto se documenta en la respuesta.
- `DELETE /api/finance/plan/events/{id}` → hard delete. Overrides asociados se eliminan por FK CASCADE.
- `POST /api/finance/plan/events/{id}/overrides` → crea un override. Payload: `occurrence_date`, `amount?`, `is_skipped?`.
- `PATCH /api/finance/plan/overrides/{id}` → edita un override.
- `DELETE /api/finance/plan/overrides/{id}` → elimina el override y deja la ocurrencia con el monto del evento base.
- `GET /api/finance/plan/projection` → respuesta `{ horizon: { from, to }, accounts: [{ id, name, type, initial_balance, final_balance }], series: { <account_id>: [{ date, balance }] }, events: [{ date, kind, amount, account_origin_id, account_destination_id, planned_event_id, override_id?, source, warnings, skipped }] }`.

Errores de dominio nuevos: `invalid_recurrence` (422) cuando los campos de recurrencia son inconsistentes con `recurrence_type`; `override_on_non_occurrence` (422) cuando la `occurrence_date` no coincide con ninguna ocurrencia de la regla. Errores reutilizados: `invalid_account_type` (422) del contrato existente.

## Cambios de integraciones

No aplica. Sin integraciones externas.

## Cambios de UI

- **Nueva ruta `/plan`** lazy-loaded en `router/index.js` con `meta: { requiresAuth: true }`.
- **Link "Plan"** en `AppLayout.vue` (topbar desktop + drawer mobile) entre "Movimientos" y "Reportes".
- **`PlanView.vue`** estructura:
  - Hero compacto con 3 tiles: "BO proyectado en 6 meses", "Deuda proyectada en 6 meses", "Cuándo termina la primera deuda" (calculado desde la proyección).
  - Sección "Plan declarado" con `PlannedEventList.vue` y botón "Nuevo evento" que abre `PlannedEventForm.vue` en `BaseModal`.
  - Sección "Proyección a 6 meses" con tabs internas: gráfica (`PlanProjectionChart.vue`) y tabla (`PlanProjectionTable.vue`).
- **`PlannedEventForm.vue`** reutiliza patrones de los forms existentes: `BaseSelect` para `kind`, cuentas, categoría; `BaseInput` para monto, fecha, descripción; selector custom para `recurrence_type` que muestra/oculta el control de `recurrence_day` (day-of-week buttons para weekly, número 1..31 para monthly, nada para one_off).
- **`PlanProjectionChart.vue`** instancia Chart.js (igual import que `MonthlyCashflowChart`): líneas multicolor, X = fecha (semanal/quincenal según densidad), Y = MXN, leyenda clickable para ocultar series.
- **`PlanProjectionTable.vue`** muestra fila por ocurrencia con: fecha, badge de kind (color según el catálogo actual), monto, cuentas, descripción, badges `override` y `saltada` cuando aplican. Click en una fila abre `PlannedEventOverrideForm.vue` para esa `(planned_event_id, occurrence_date)`.
- **`PlannedEventOverrideForm.vue`** en modal: tres campos visibles solo si hay variación (`monto custom`, checkbox `saltar esta ocurrencia`, botón eliminar override si ya existe).
- **Estilo**: reusar paleta CSS variable existente (`--color-positive`, `--color-warning`, `--color-negative`, `--color-accent`). Cuenta archivada en una fila se muestra con opacity 60% y badge similar al de cuentas archivadas en `AccountCard`. Saldos negativos en gráfica/tabla se pintan rojo cuando cruzan la línea 0.

## Cambios de permisos

No aplica. Toda autorización ya está cubierta por el middleware existente `['auth:sanctum', 'verified']`. Scope por `user_id` en todas las queries (igual patrón que el resto del dominio).

## Riesgos tecnicos

- **Cohesión semántica entre carriles**: el usuario puede declarar planes que difieran de la realidad y la proyección quedará desactualizada respecto a lo que realmente ocurre. v1 no concilia esto. Mitigación: la UI deja clara la separación; v2 puede agregar comparación plan vs real.
- **Cuentas archivadas con eventos activos**: si una cuenta se archiva post-creación, las ocurrencias se saltan silenciosamente. Mitigación: indicador visible y alerta en la lista de eventos. No se bloquea archivado para evitar acoplamiento con `DeleteAccount`.
- **Zona horaria server vs usuario**: el horizonte se calcula con `now()` del server (UTC en Postgres). Si el user opera en MX (-06:00), la "primera ocurrencia hoy" puede off-by-one. Mitigación: en v1 documentamos; v2 introduce TZ por usuario o se setea `APP_TIMEZONE=America/Mexico_City` (se puede hacer ahora con un secret en Fly).
- **Cambio de recurrencia con overrides existentes**: si el usuario edita la recurrencia, algunos overrides pueden quedar huérfanos. Decisión: borrar los overrides cuya `occurrence_date` deja de coincidir. Mitigación: el endpoint PATCH retorna `{ removed_overrides: n }` y la UI puede avisar antes con un confirm.
- **Performance de simulación con plan grande**: ~5k operaciones máximo en caso realista, sin riesgo. Si el número de eventos crece a centenas, valorar cache. No es problema v1.
- **Doble registro accidental**: el usuario podría planear un pago y también registrarlo manual cuando llegue el día, sin que la app se entere. La proyección seguiría asumiendo el plan; el balance real ya lo tiene. La UI debe ser explícita sobre que "plan" es declarativo y no se ejecuta. Mitigación: copy y onboarding.
- **Sobrecarga del PATCH de evento**: editar `recurrence_day` puede invalidar muchos overrides. Mitigación: confirm dialog en frontend cuando se detecte cambio que afecta overrides.

## Estrategia de pruebas

- **Backend feature tests** por Action y por endpoint (ver `test-plan.md` para detalle).
- **Service tests** para `PlanProjectionService` cubriendo todas las variantes de recurrencia, casos borde, cuentas archivadas y overrides.
- **API tests** para los 7 endpoints, validación de input, scope por usuario, códigos de error.
- **Frontend unit tests** para el store `plan.js` (mutaciones, fetch, integración con API mock).
- **No E2E en v1**: la UI tiene mucho movimiento (Chart.js, modales encadenados) y el costo de cobertura E2E es alto; se cubre en v1.1 cuando la UI esté estable. Sí se documentan los flujos manuales en `test-plan.md`.
- **Regresión**: la suite backend completa (~206 tests) debe seguir verde tras el refactor de `UpdateJournalEntry` para usar el helper compartido.

## Estrategia de rollback

- **Rollback aditivo**: si algo sale mal, basta con `php artisan migrate:rollback --step=2` para eliminar las dos tablas nuevas. Ningún `journal_entry` se modifica jamás, así que no hay riesgo de datos contaminados.
- **Feature flag**: no se considera necesario. La feature es un módulo aislado bajo una nueva ruta `/plan` y nuevos endpoints; si se decide ocultarla, basta con quitar el link de `AppLayout` y dejar la ruta sin nav. El backend puede convivir con la UI desactivada sin coste.
- **Refactor del helper compartido**: el refactor de `UpdateJournalEntry::validateAccountsForKind` para delegar al helper debe pasar los 22 tests existentes sin tocarlos. Si rompe algo, se revierte el cambio en `UpdateJournalEntry.php` (1 archivo) y se duplica la lógica temporalmente en las Actions de Plan.

## Orden sugerido de implementacion

Se prioriza ir armando vertical end-to-end por capas pequeñas, de modo que cada paso sea reviewable y reversible.

1. **Helper compartido + refactor mínimo de UpdateJournalEntry**. Garantiza que no hay regresión antes de meter algo nuevo.
2. **Migración 1 (`planned_events`) + Modelo + 3 Actions CRUD + endpoints + tests** del evento sin overrides, sin proyección todavía.
3. **Migración 2 (`planned_event_overrides`) + Modelo + 3 Actions + endpoints + tests** de override.
4. **`PlanProjectionService` + endpoint de proyección + tests del service**. Esto es el motor y el componente más subtle; vale la pena tener tests exhaustivos antes de UI.
5. **API client + store Pinia + tests del store**.
6. **`PlanView.vue` + `PlannedEventList.vue` + `PlannedEventForm.vue`** (CRUD de eventos sin gráfica todavía).
7. **`PlanProjectionTable.vue` + `PlannedEventOverrideForm.vue`** (visualización + override).
8. **`PlanProjectionChart.vue`** (gráfica final).
9. **Hero con tiles "BO proyectado / Deuda proyectada / Primera deuda en cero"**.
10. **Link en AppLayout** + ruta en router.
11. **Documentación: actualizar CLAUDE.md y agregar tabla de endpoints**.

## Casos borde que condicionan la solucion

- **Edición de `recurrence_day` que invalida overrides existentes**: el PATCH debe borrar los overrides cuyas `occurrence_date` ya no caen en la nueva regla, y devolver el conteo. La UI confirma antes.
- **`one_off` no admite override**: la Action rechaza con `invalid_recurrence` si se intenta crear override sobre un evento `one_off`.
- **Override de `is_skipped = true` con `amount` presente**: el Action ignora `amount` (no rechaza), porque el invariante semántico es "saltada gana". Documentado.
- **`start_date` futura más allá del horizonte de 6 meses**: el evento se persiste pero la proyección no incluye ocurrencias (no hay ninguna en la ventana). Aceptable; aparece en la lista de eventos pero no en la timeline.
- **`end_date` anterior a hoy**: el evento se persiste pero la proyección no genera nada. La lista lo muestra con badge "vencido". Aceptable.
- **Eventos con la misma fecha y misma cuenta destino**: se aplican en orden de creación (ORDER BY `created_at`). Determinístico.
- **Cuenta archivada después de crear el evento, con override sobre una ocurrencia futura**: la ocurrencia se salta igual; el override sigue persistido pero se marca con `archived_account` también. UI lo muestra.
- **Sobrepago acumulado en la simulación de tarjeta**: las ocurrencias se aplican y se marcan `warning = "overpay"` desde la primera que cruza balance < 0. No se bloquea (consistencia con la filosofía libreta libre en el carril simulado).
- **Carbon parse de `recurrence_day` en meses cortos**: la simulación clampa al último día del mes (ej. day=31 en febrero => 28/29). Probarlo en test-plan.
- **DST / cambios de horario**: las fechas son `date`, no `datetime`. Sin impacto de DST.
- **Eventos con monto en miles de millones**: cap por `decimal(12,2)` = hasta 9 999 999 999.99. No es un caso real esperable; el schema lo limita naturalmente.

## Preguntas o supuestos que siguen afectando la implementacion

Sin preguntas pendientes. Supuestos clave (todos heredados de `spec.md` y `clarificaciones.md`):

- Horizonte fijo 6 meses calendario desde hoy.
- Granularidad día.
- Sin caché del resultado de proyección.
- Hard delete de eventos y overrides.
- FK `ON DELETE RESTRICT` en cuentas referenciadas (impide borrar cuentas con eventos vivos, pero respeta soft delete de Account).
- No se introduce `transfer` como tipo de evento planeado.
- Convención ISO 8601 para día de la semana (0=lunes).
- TZ del server hasta que se introduzca TZ por usuario (riesgo documentado).
- Cambio de recurrencia en PATCH borra overrides ya inconsistentes y devuelve el conteo; UI confirma antes con `BaseConfirm`.

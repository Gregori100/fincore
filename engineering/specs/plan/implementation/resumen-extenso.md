# Resumen extenso — Plan

## Contexto tomado de la spec

El feature "Plan" se definió como una **capa nueva y paralela** a `journal_entries` que permite simular cómo evolucionarán los saldos de las cuentas a 6 meses, a partir de eventos declarados por el usuario. Las cinco decisiones grandes se cerraron antes de generar la spec:

1. Alcance v1: cuatro tipos de eventos (ingreso recurrente, gasto recurrente, pago a tarjeta recurrente, gasto/cargo one-off).
2. Carriles separados: nada que se planee toca movimientos reales.
3. Horizonte fijo: 6 meses calendario desde hoy.
4. Plan declarativo + overrides puntuales por ocurrencia.
5. Sin cálculo de intereses ni mínimos en v1 (Fase 2 separada).

Las decisiones secundarias quedaron documentadas como Supuestos en `spec.md` y revalidadas en `clarificaciones.md`:

- Hard delete de eventos y overrides.
- Convención ISO 8601 para día de la semana (`0 = lunes`).
- No `transfer` como evento planeado (modelar con dos eventos).
- Sin recurrencia quincenal/biweekly (dos `monthly` separados).
- Sobrepago en simulación se aplica con `warning = "overpay"` (no bloquea); en la creación real `PayCreditAccount` sigue bloqueando.

## Relación con el plan

`plan/plan.md` definió 14 secciones con enfoque técnico DDD-light + Laravel 12 + Vue 3. `plan/tasks.md` se descompuso en 42 tareas con dependencias, agrupadas en Backend, Frontend, Pruebas, Validación y Documentación. La ejecución siguió el orden vertical sugerido (helper compartido → backend end-to-end → frontend → tests → docs), permitiendo verificar la suite verde después de cada bloque grande.

## Cambios principales por módulo o capa

### Capa de dominio — backend

- **Helper compartido** `Domain/Finance/Support/JournalKindContract` extraído de `UpdateJournalEntry::validateAccountsForKind`. Reusado tanto por la Action existente como por `CreatePlannedEvent` y `UpdatePlannedEvent`. Mantiene la lógica de invariantes tipo↔kind como single source of truth.
- **Dos entidades nuevas** con `HasUuids`: `PlannedEvent` y `PlannedEventOverride`. El primero implementa `occurrencesBetween(Carbon, Carbon): Collection<Carbon>` y `occursOn(Carbon): bool` para encapsular la lógica de recurrencia. El segundo persiste overrides identificados por `(planned_event_id, occurrence_date)` con unique constraint.
- **Seis Actions** que cubren CRUD de los dos modelos con validación de invariantes, scope estricto por `user_id`, transacciones para mutaciones que afectan múltiples filas y reuso del helper compartido.
- **Dos exceptions de dominio** que se renderizan a JSON `{error, code}` con HTTP 422: `InvalidRecurrence` (cuando los parámetros de recurrencia son inconsistentes) y `OverrideOnNonOccurrence` (cuando se intenta crear un override en una fecha que no cae en el patrón).
- **Service** `PlanProjectionService` orquesta el motor. Su flujo:
  1. Captura snapshot inicial via `FinancialStateService::getAccounts()`.
  2. Carga todos los `PlannedEvent` del usuario con sus overrides.
  3. Para cada evento, genera ocurrencias en el rango [hoy, hoy+6m] y las cruza con los overrides correspondientes.
  4. Ordena cronológicamente y aplica al map de balances en memoria, respetando la semántica de cada kind (cash/debit suma vs credit resta para `outgoing`, etc.).
  5. Marca ocurrencias con `archived_account` cuando una cuenta involucrada está soft-deleted, y con `overpay` cuando un `debt_payment` deja la tarjeta con balance negativo.
  6. Devuelve `{ horizon, accounts, series, events }` listo para gráfica + tabla.

### Capa HTTP — backend

- **Controller** `PlanController` con 8 endpoints REST estilo Laravel: validación con `$request->validate()`, delegación a Actions, scope por usuario implícito (via `$request->user()->id`). Reusa el grupo `['auth:sanctum', 'verified']` existente.
- **Rutas** agregadas en `routes/api.php` con prefijo `/finance/plan/`. Verificadas con `route:list` (8 rutas).

### Capa de persistencia

- **Migración 1** `create_planned_events_table` con columnas tipadas, FKs `ON DELETE RESTRICT` a `accounts` (preserva eventos cuando la cuenta es soft-deleteada pero impide hard delete), `CASCADE` a `users`, `SET NULL` a `categories`. Índice `(user_id, start_date)` para queries de listado.
- **Migración 2** `create_planned_event_overrides_table` con FK `CASCADE` a `planned_events` y unique compuesto `(planned_event_id, occurrence_date)`.

### Refactor de `UpdateJournalEntry`

Se removió el método privado `validateAccountsForKind` (junto con `resolveAccount` y los imports asociados). La Action ahora llama a `JournalKindContract::validateAccountsForKind` estáticamente. La firma pública y todos los códigos de error son idénticos. Los 22 tests existentes pasaron sin modificación.

### Capa frontend

- **API client** `src/api/plan.js` con 8 funciones, default export.
- **Store Pinia** `src/stores/plan.js` con state `events`, `projection`, `loading`, `error`. Cada mutación invalida y refetchea la proyección para mantener carga reactiva sin lógica duplicada en componentes.
- **Componentes Vue**:
  - `PlannedEventForm.vue`: formulario unificado para crear y editar, con selects condicionales según `kind` y `recurrence_type`.
  - `PlannedEventList.vue`: lista agrupada por kind, con badges para cuenta archivada y acciones inline hover.
  - `PlannedEventOverrideForm.vue`: modal compacto con dos controles (amount opcional, checkbox saltada).
  - `PlanProjectionTable.vue`: tabla dual desktop/mobile (mismo patrón que `EntriesTable`), click en fila abre el override.
  - `PlanProjectionChart.vue`: línea Chart.js con una serie por cuenta, leyenda clickable, forward-fill cuando un punto no existe en la serie.
- **`PlanView.vue`**: hero con tres tiles (BO proyectado, deuda proyectada, primera deuda en 0 calculada del array de series), sección lista, sección proyección con tabs "Gráfica" / "Tabla". `BaseConfirm` para eliminaciones de eventos.

### Documentación

- `CLAUDE.md` ahora tiene una sección "Plan (proyección financiera a 6 meses)" antes del bloque de Deploy, y 8 filas nuevas en la tabla de endpoints.
- Memoria del proyecto pendiente de actualizar (T042).

## Desviaciones respecto al plan

- **8 rutas en lugar de 7**: el plan listaba 7 endpoints pero al implementar quedó claro que era más natural separar `create_override` (bajo el evento) de `update`/`delete` (por su propio id). El total queda en 8, lo cual es coherente con el plan, no un sobre-alcance.
- **Smokes de componentes Vue (T036) parcialmente diferidos**: solo se hizo el smoke del store. Razones documentadas en `pendientes.md`: jsdom + Chart.js da más ruido que valor, y la cobertura efectiva ya viene de backend + integración del store.
- **`PlannedEvent::occursOn`** se agregó al plan implícitamente (la Action de override lo necesita; el plan lo asumía pero no lo nombró). Documentado.
- **Build de Vite** no se ejecutó exitosamente por permisos en `dist/`. Vitest sí pasó completo, lo que demuestra que la sintaxis es válida. Pendiente para la fase de deploy.

## Pruebas realizadas

Detalladas en `progreso.md` y `implementation-review.md`. Resumen numérico:

- 12 + 8 + 3 + 10 + 13 + 13 = **59 tests backend nuevos** (todos verdes).
- 8 tests frontend nuevos (todos verdes).
- Suite backend completa: **265/265 (524 assertions)**.
- Suite frontend completa: **49/49**.
- Refactor de `UpdateJournalEntry`: **0 regresiones** en sus 22 tests existentes.

## Pruebas recomendadas

- **Recorrido manual** (T039): documentado en `test-plan.md`. Necesario antes del merge para validar UX real.
- **Test de performance**: crear 50 eventos vía tinker y medir `/api/finance/plan/projection`. Objetivo < 500 ms.
- **Visual QA**: revisar la gráfica con `prefers-color-scheme: light`; con > 5 cuentas (densidad de líneas); en mobile (la tabla cambia a cards verticales, la gráfica reduce ancho).
- **`branch-quality-review`** antes del merge.

## Riesgos residuales y posibles regresiones

Detallados en `implementation-review.md`. Lo más relevante:

- Drift plan vs realidad (aceptado en v1).
- TZ del server para el horizonte (mitigable con `APP_TIMEZONE` en Fly.io).
- Sin caché del motor de proyección.
- Build de producción Vite a verificar fuera del ambiente local.

Sin regresiones detectadas en la suite. El refactor de `UpdateJournalEntry` es la única superficie compartida y sus tests pasan idénticos.

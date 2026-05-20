# Test plan — Plan (proyección financiera a 6 meses)

## Casos borde detectados

Lista activa de escenarios que el plan debe demostrar antes de declarar la feature lista. Algunos vienen de `spec.md` casos borde; otros son inferidos del impacto sobre el dominio existente.

- Recurrencia `monthly` con `recurrence_day = 31` cae en febrero: ocurrencia el 28 (años no bisiestos) o 29 (bisiestos).
- Recurrencia `weekly` con `start_date` posterior al `recurrence_day` de esa semana: la primera ocurrencia es la próxima coincidencia, no la actual.
- Recurrencia `weekly` con `start_date` anterior al `recurrence_day` de esa semana: la primera ocurrencia es la misma semana.
- `start_date == today`: si coincide con el patrón, hay ocurrencia hoy; si no, la siguiente coincidencia.
- Evento con `end_date < start_date`: rechazar al crear.
- Evento con `end_date` anterior a hoy: se persiste sin error; proyección no contiene ocurrencias.
- Evento con `start_date` más de 6 meses en el futuro: se persiste; proyección no contiene ocurrencias.
- Evento con `recurrence_day` inválido (e.g. 7 para weekly, 32 para monthly, -1): rechazar al crear con `invalid_recurrence`.
- Evento `one_off` con `recurrence_day`/`end_date`: ambos se ignoran al persistir (o se persisten en null, decidir consistencia).
- Override con `occurrence_date` que no es ocurrencia de la regla: rechazar con `override_on_non_occurrence`.
- Override sobre evento `one_off`: rechazar con `invalid_recurrence`.
- Override con `is_skipped = true` y `amount` presente: persistir, ignorar amount en la simulación; documentar el comportamiento del Action.
- Dos overrides para la misma `(planned_event_id, occurrence_date)`: el segundo POST devuelve 422 por unique constraint; PATCH sí permite editar el existente.
- Editar `recurrence_day` borra overrides huérfanos: contar y verificar que las ocurrencias preservadas (mismo `occurrence_date` válido en la nueva regla) sobreviven.
- Cuenta archivada después de crear el evento: ocurrencias futuras se marcan `skipped_reason = "archived_account"` y no aplican al balance.
- Cuenta de otro usuario referenciada al crear evento: 404/422 sin persistir.
- Categoría incompatible con el `kind`: rechazar con `invalid_category_applies_to`.
- Categoría sobre `debt_payment` o `transfer` (transfer no existe en Plan, pero por consistencia con la spec verificar que `debt_payment` rechaza categoría).
- Múltiples eventos el mismo día sobre la misma cuenta: aplicados en orden determinístico (por `created_at`).
- Múltiples ocurrencias el mismo día para el mismo evento: imposible por diseño (recurrencias semanal/mensual generan a lo sumo una por día; one_off una sola).
- Proyección con cero eventos: respuesta válida con series vacías de eventos pero balance inicial = balance final = snapshot actual.
- Proyección sin Bolsa (caso teórico, Bolsa es protegida): la simulación corre normal sin esa serie.
- Saldo proyectado de cuenta cash/debit cae por debajo de 0: la serie cruza el eje X; no se bloquea; no aparece error.
- Saldo proyectado de tarjeta excede `credit_limit`: la serie sube sobre el límite; no se bloquea; no aparece error específico (la spec de tarjetas excediendo límite ya es libreta libre).
- Pago a tarjeta (`debt_payment`) deja la deuda en < 0: aplicar pero marcar la ocurrencia con `warning = "overpay"`.
- Endpoint de proyección con un usuario sin ningún evento ni movimiento: serie con balance constante en 0 (BO = 0).
- Proyección con un usuario que tiene `journal_entries` reales pero ningún `planned_event`: balance constante = balance actual.
- Proyección con un evento cuyas únicas ocurrencias caen en el día final del horizonte: incluir la ocurrencia (rango inclusivo).
- Proyección con un evento cuyas únicas ocurrencias caen un día después del horizonte: no incluir.
- Solicitud de override para una fecha pasada (anterior a hoy): permitir o rechazar (decisión técnica). Recomendado: permitir, porque el override puede crearse para una fecha "ya pasada" desde el punto de vista del calendario pero todavía dentro de una ventana de proyección retrospectiva. v1 lo permite; la simulación arranca en hoy así que esos overrides no influyen.
- Concurrencia: dos requests simultáneas creando el mismo override para `(planned_event_id, occurrence_date)`: solo uno gana, el otro recibe 422 por unique violation.
- Concurrencia: simulación corriendo mientras se crea/edita un evento: la simulación trabaja sobre la foto leída al inicio del request; commit del evento no afecta una proyección en curso.
- Performance: usuario con 50 eventos + 5 cuentas activas: respuesta del endpoint en < 500 ms localhost.
- Performance: usuario con 200 eventos (no realista pero defensivo): respuesta en < 2 s localhost.
- Edición de un evento que cambia `kind`: rechazar (kind no es editable, igual que en `UpdateJournalEntry`).
- Validación de payload: `amount` no numérico, `start_date` no fecha, `recurrence_type` inválido: 422 con errores de Laravel.

## Pruebas unitarias necesarias

Hard target: ≥ 90 % cobertura en `Domain/Finance/Plan/`. PHPUnit feature tests con `RefreshDatabase`.

- `CreatePlannedEventTest`: 12 casos. Crear con cada `kind`. Crear `weekly` valida `recurrence_day` 0..6. Crear `monthly` valida `recurrence_day` 1..31. Crear `one_off`. Rechazar `kind` inválido. Rechazar contrato tipo↔kind (e.g. expense con destino credit). Rechazar `amount <= 0`. Rechazar `start_date > end_date`. Rechazar `recurrence_day` fuera de rango. Rechazar cuenta de otro user. Rechazar categoría incompatible. Rechazar cuenta inexistente.
- `UpdatePlannedEventTest`: 8 casos. Editar `amount`. Editar `recurrence_day`. Editar fechas. Editar `description`. Editar `category_id` (null o válida). Rechazar cambio de `kind`. Editar `recurrence_day` borra overrides huérfanos. Editar cuenta a una archivada (decisión: rechazar, no permitir referenciar archivadas nuevas). Editar evento de otro user => 404.
- `DeletePlannedEventTest`: 3 casos. Eliminar borra evento + cascada overrides. Eliminar evento de otro user => 404. Eliminar evento inexistente => 404.
- `PlannedEventOverrideTest`: 10 casos. Crear override sobre ocurrencia válida. Rechazar override sobre `one_off`. Rechazar `occurrence_date` no-ocurrencia. Crear `is_skipped = true`. Crear con `amount` custom. Crear con ambos (amount ignorado pero persistido). Crear segundo override para misma `(planned_event_id, occurrence_date)` => 422 unique violation. Editar override. Eliminar override. Override de un evento de otro user => 404.
- `PlanProjectionServiceTest`: 18 casos. Sin eventos. Solo ingreso recurrente weekly. Solo pago recurrente weekly. Combinación ingreso + pago. Evento monthly clamp 31 en febrero. Evento `one_off` futuro. Evento `one_off` pasado (no aparece). Override que cambia amount. Override `is_skipped`. Sobrepago de tarjeta marca `warning`. Cuenta archivada marca `archived_account`. Cuenta archivada no afecta balance. Eventos múltiples mismo día. `end_date` corta correctamente. `start_date` después de horizonte no genera. Bolsa preservada cuando user solo tiene bolsa. Pago recurrente que lleva deuda exactamente a 0 (no warning). Pago que cruza 0 a la siguiente ocurrencia (sí warning desde esa).

## Pruebas de integracion o API necesarias

PHPUnit feature tests sobre `PlanController` con HTTP real.

- `PlanApiTest::test_listing_returns_only_user_events`: dos usuarios con eventos cruzados; el listado de A no contiene los de B.
- `PlanApiTest::test_create_planned_event_via_api`: POST con payload válido devuelve 201 + JSON shape.
- `PlanApiTest::test_create_planned_event_invalid_recurrence`: weekly con day=10 => 422 + code=`invalid_recurrence`.
- `PlanApiTest::test_create_planned_event_invalid_account_type`: expense con destino credit => 422 + code=`invalid_account_type`.
- `PlanApiTest::test_patch_planned_event`: PATCH simple devuelve 200 + cambios reflejados.
- `PlanApiTest::test_patch_recurrence_removes_orphan_overrides`: con overrides creados, cambiar `recurrence_day` borra los que ya no aplican y devuelve `removed_overrides` ≥ 1.
- `PlanApiTest::test_delete_planned_event_cascades_overrides`: DELETE evento, verificar que la tabla de overrides también pierde sus rows.
- `PlanApiTest::test_create_override_on_one_off_fails`: 422 + `invalid_recurrence`.
- `PlanApiTest::test_create_override_on_non_occurrence_fails`: 422 + `override_on_non_occurrence`.
- `PlanApiTest::test_create_duplicate_override_returns_422`: segundo POST mismo `(event, date)` => 422.
- `PlanApiTest::test_projection_returns_expected_shape`: POST evento simple, GET projection devuelve `{ horizon, accounts, series, events }` con tipos correctos.
- `PlanApiTest::test_projection_scoped_by_user`: dos usuarios; el segundo no ve eventos del primero en su proyección.
- `PlanApiTest::test_projection_runs_under_500ms_for_realistic_load`: 50 eventos + 5 cuentas, medir `microtime`. Test marcado como `@group performance` para poder excluirlo si flakea en CI.
- `PlanApiTest::test_endpoints_require_sanctum_verified`: cada endpoint sin auth o sin verificación => 401/403.
- `PlanApiTest::test_validation_rejects_invalid_dates`: payload con `start_date` fuera del rango [today-1y, today+5y] => 422.

## Pruebas de UI o flujo necesarias

vitest + @vue/test-utils, en lo posible sin browser.

- `tests/stores/plan.spec.js`: 8 casos. Estado inicial (events vacío, projection null). `fetchEvents` setea estado. `createEvent` exitoso agrega al estado y dispara `fetchProjection`. `createEvent` con error 422 conserva estado. `updateEvent` reemplaza la entrada. `deleteEvent` la quita y limpia overrides locales. `createOverride` actualiza la entrada anidada. `fetchProjection` setea `projection`.
- Componentes (smoke):
  - `PlannedEventForm.spec.js`: renderiza, muestra/oculta `recurrence_day` según `recurrence_type`, valida amount > 0, valida cuenta requerida según kind.
  - `PlanProjectionTable.spec.js`: renderiza filas correctamente, badge `override` cuando `source = "override"`, badge `saltada` cuando `skipped`, click en fila dispara emit `editOverride`.
  - `PlanProjectionChart.spec.js`: smoke test que monte el componente con datos mínimos sin error (no se prueba Chart.js internamente).

## Pruebas de permisos y seguridad

- Scope por `user_id` en todas las queries Eloquent: verificado en tests de Action (`test_create_planned_event_rejects_account_of_other_user`, etc.) y en API (`test_listing_returns_only_user_events`).
- Middleware `auth:sanctum` + `verified` en las 7 rutas: cubierto por `test_endpoints_require_sanctum_verified`.
- Rate limit: no se aplica throttle a `/plan/*` en v1 (consistencia con resto de `/finance/*`).
- SQL injection / mass-assignment: usar `$fillable` explícito en los modelos. No exponer `user_id` en `fillable`; setear vía relación `for($user)` o asignación explícita en Action.

## Pruebas de datos, migracion o compatibilidad

- Levantar migraciones desde cero (`migrate:fresh --seed`) y verificar que las dos tablas nuevas se crean correctamente. Verificar índices y FKs en Postgres (no SQLite, porque las pruebas locales corren contra Postgres dockerizado vía `./scripts/fincore migrate`).
- Probar rollback (`migrate:rollback --step=2`) y volver a aplicar.
- Asegurar que `journal_entries` y `accounts` no fueron tocadas por las nuevas migraciones (diff de schema).
- Constraint unique `(planned_event_id, occurrence_date)`: tests Postgres-native que verifiquen el error si se intenta insertar duplicado.

## Pruebas de regresion sobre flujos existentes

- Suite backend completa antes y después: 206 tests verdes (línea base 2026-05-19), debe permanecer en mínimo ese número (más nuevos).
- Específicamente:
  - `UpdateJournalEntryTest` (22 tests): debe pasar sin cambios tras el refactor del helper compartido.
  - `RegisterExpenseTest`, `RegisterCreditExpenseTest`, `RegisterTransferTest`, `PayCreditAccountTest`, `RegisterIncomeTest`: no se tocan; deben pasar sin cambios.
  - `FinanceApiTest`: no se toca.
- Suite frontend: 41 tests verdes hoy. Debe seguir en ese mínimo (más nuevos).
- E2E `entries.spec.js`: no interactúa con Plan; debe permanecer verde.

## Pruebas manuales o smoke tests necesarios

Recorrido manual antes de cerrar la feature, ejecutado en `localhost:5173` con stack docker arriba:

1. Login y dashboard cargan normal.
2. Click "Plan" en topbar abre `/plan` con lista vacía.
3. "Nuevo evento" → crear ingreso recurrente "Sueldo $5,700 cada viernes, sin fecha fin". Verificar que aparece en la lista.
4. La gráfica muestra la serie de Bolsa subiendo cada viernes. La tabla cronológica enumera las próximas ocurrencias.
5. Crear pago recurrente "Pago Visa $3k cada viernes". Verificar que la serie de deuda baja, y eventualmente cruza 0 con marcador `overpay` si la deuda original es menor a 3k × 26.
6. Editar la ocurrencia del próximo viernes en la tabla → cambiar a $5k. Verificar que ese punto en la gráfica baja más y los demás siguen igual.
7. Cambiar el `recurrence_day` del pago de Visa de viernes a sábado. Confirmar diálogo de "se borrarán N overrides". Verificar que la lista cronológica se reordena.
8. Archivar la cuenta del pago de Visa en `/accounts`. Volver a `/plan` y verificar que las ocurrencias futuras del pago aparecen con badge "cuenta archivada" y la serie de la tarjeta deja de bajar.
9. Eliminar el evento de Sueldo. Verificar que la gráfica de Bolsa deja de subir.
10. Probar en mobile (Chrome devtools o celular): la gráfica debe ser scrolleable; la tabla debe responder a tap.

## Datos de prueba recomendados

- Usuario base con Bolsa + 1 cuenta débito + 2 tarjetas de crédito (1k y 2k de deuda inicial).
- Conjunto de 5 eventos: 1 ingreso semanal, 2 pagos semanales a tarjeta, 1 gasto mensual (renta), 1 gasto puntual one_off.
- 2 overrides: uno con `amount` custom, otro `is_skipped`.

Estos datos pueden incluirse en una factory `PlannedEventFactory` y un seeder opcional `PlanDemoSeeder` (no se ejecuta por default; útil para tests E2E futuros).

## Comandos o validaciones locales sugeridas

```bash
# Backend
docker compose exec -T api php artisan test
docker compose exec -T api php artisan test --filter Plan
docker compose exec -T api ./vendor/bin/pint --test

# Frontend
cd frontend && npm run test
cd frontend && npm run test -- plan

# Migraciones
./scripts/fincore migrate            # aplicar
./scripts/fincore migrate -- --rollback --step=2   # revertir las 2 nuevas
./scripts/fincore migrate -- --fresh --seed        # rebuild from scratch
```

Manual: abrir `http://localhost:5173/plan` con sesión válida.

## Criterios minimos para aprobar la implementacion

1. Las dos migraciones suben y bajan limpias.
2. Las 7 rutas responden con los códigos y shapes esperados.
3. `PlanProjectionServiceTest` con ≥ 18 casos, todos verdes.
4. `PlanApiTest` con ≥ 15 casos, todos verdes.
5. La suite total backend ≥ 250 tests, todos verdes.
6. La suite total frontend ≥ 48 tests, todos verdes.
7. Refactor del helper compartido no rompe ningún test existente.
8. Recorrido manual completo (10 pasos) sin errores.
9. CLAUDE.md actualizado con sección y tabla de endpoints.
10. Performance del endpoint de proyección bajo 500 ms para 50 eventos.

## Validacion final recomendada

Una vez implementada la feature en una rama y antes de mergear, invocar `/branch-quality-review` con `slug=plan` para revisión exhaustiva (seguridad, autorización, SQL, concurrencia, performance, DDD, frontend, UX, validaciones, regresiones). El reporte se genera en `engineering/quality-review/plan/` y no se duplica en `implementation/`.

Si por alguna razón `branch-quality-review` no está disponible, la checklist equivalente mínima incluye:

- `git diff main` revisado a ojo por archivos nuevos vs modificados.
- Confirmar que `UpdateJournalEntry.php` cambia mínimo (solo delega al helper, no cambia comportamiento).
- Buscar `dd(`, `dump(`, `console.log` en el diff (deben ser cero).
- `php artisan route:list --path=plan` muestra exactamente las 7 rutas esperadas.
- Test de carga manual con script `tinker` que crea 50 eventos y mide proyección.
- Revisar el JSON de la proyección manualmente con un usuario realista y comparar con cálculo a papel.

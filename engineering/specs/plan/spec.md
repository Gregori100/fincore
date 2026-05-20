# Plan — Proyección financiera a 6 meses

## Resumen

Capa nueva de FinCore que permite al usuario declarar eventos financieros futuros (recurrentes y puntuales) y ver una simulación, día a día, de cómo evolucionan sus saldos durante los próximos seis meses. La proyección vive en paralelo al sistema actual: no toca `journal_entries` ni el snapshot real, sólo lo usa como punto de partida. El motor combina el estado calculado por `FinancialStateService` con los eventos planeados y produce una línea de tiempo de saldos por cuenta y eventos cronológicos, suficiente para responder "cuánto me queda libre cada viernes", "cuándo termino de pagar cada tarjeta" y "qué pasa si cambio un pago puntual".

## Problema a resolver

Hoy FinCore es 100 % retrospectivo: sirve para registrar lo que ya pasó. Cuando el usuario tiene deudas en varias tarjetas, un ingreso recurrente y necesita decidir cómo distribuir pagos, no puede ver en la app cómo se va a mover su dinero a futuro ni comparar mentalmente "si pago 3k vs 5k". El usuario hoy hace esa proyección a mano o en hojas de cálculo aparte. El feature elimina esa fricción y permite tomar decisiones de pago con visibilidad real del impacto.

## Objetivo

Entregar una vista `/plan` que, sin afectar nada del flujo actual, permita:

1. Declarar reglas recurrentes y eventos puntuales que representan el comportamiento esperado del usuario para los próximos seis meses.
2. Editar una ocurrencia específica de una regla recurrente con un monto distinto sin alterar las demás ocurrencias.
3. Visualizar la evolución de los saldos (BO, deuda por tarjeta) a lo largo del horizonte, con gráfica y tabla cronológica.
4. Mantener carriles separados: ningún evento planeado se convierte en `journal_entry` por sí solo; el usuario sigue registrando movimientos reales como hoy.

## Alcance

- Nueva agregación de dominio: `PlannedEvent` (regla recurrente o evento puntual) y `PlannedEventOverride` (override de una ocurrencia específica de una regla recurrente).
- CRUD completo de `PlannedEvent` y de overrides, scoped por usuario.
- Servicio de simulación que toma el snapshot actual + los eventos planeados + un horizonte y produce una proyección.
- Endpoint para devolver la proyección lista para visualizar (timeline de eventos + serie temporal de saldos).
- UI nueva en `/plan` con: lista de eventos planeados, formulario para crear/editar, vista de proyección con gráfica de línea y tabla.
- Soporte para los cuatro tipos de evento que mapean a kinds existentes de `JournalEntry`: `income`, `expense`, `credit_expense`, `debt_payment`. (Las transferencias entre cuentas propias no se incluyen en v1; ver Fuera de alcance).
- Soporte para dos patrones de recurrencia: `weekly` (un día específico de la semana, 0–6) y `monthly` (un día específico del mes, 1–31). Más patrones (quincenal, biweekly, anual) quedan fuera.
- Soporte para eventos `one_off` (puntuales en una fecha futura).

## Fuera de alcance

- Cálculo de intereses por no pagar el mínimo de la tarjeta, uso de `closing_day`/`payment_day`/`interest_rate`/`minimum_payment_pct`. Fase 2 separada que se construirá encima de este plan.
- Recurrencias avanzadas: biweekly, quincenal (días 1 y 15 del mismo mes en un solo evento), anual, cron-like.
- Plan recurrente del tipo "transferencia entre dos cuentas propias" (`transfer`). El caso "muevo de Bolsa a banco cada quincena" se puede modelar v1 con dos eventos (un `expense` desde Bolsa y un `income` al banco), aunque rompe la simetría; queda como limitación documentada.
- What-if exploratorio con sliders no persistentes. La v1 trabaja sobre el plan persistido: para comparar escenarios el usuario edita el plan y la proyección se recalcula.
- Asistente que detecta automáticamente patrones recurrentes en el histórico real y sugiere eventos planeados.
- Auto-match entre eventos planeados y `journal_entries` reales (botón "marcar como ejecutado" o vínculo bidireccional). En v1 los carriles permanecen totalmente independientes.
- Cálculo o despliegue de proyecciones probabilísticas (rangos, intervalos de confianza).
- Notificaciones, alertas o envíos por correo asociados a eventos próximos.

## Reglas de negocio

- Cada `PlannedEvent` pertenece a un `user_id` y todas las operaciones se filtran por ese scope (igual patrón que `JournalEntry`).
- El `kind` de un `PlannedEvent` define cuáles cuentas son válidas, reutilizando el mismo contrato tipo↔kind que `UpdateJournalEntry::validateAccountsForKind`:
  - `income`: `account_destination_id` debe ser cash/débito; `account_origin_id` es null.
  - `expense`: `account_origin_id` debe ser cash/débito; `account_destination_id` es null.
  - `credit_expense`: `account_origin_id` debe ser crédito; `account_destination_id` es null.
  - `debt_payment`: `account_origin_id` cash/débito; `account_destination_id` crédito.
- `amount` siempre debe ser mayor a 0. Igual que en `JournalEntry`, no se permite amount = 0 ni negativo.
- Si una cuenta referenciada por un `PlannedEvent` se archiva (`Account` soft-delete), el evento permanece pero la simulación marca cada ocurrencia futura con un flag `skipped_reason = "archived_account"` y no la aplica al saldo. El evento es editable para reasignarlo a otra cuenta o se puede archivar también.
- Categorización: `PlannedEvent` puede tener `category_id` opcional con las mismas reglas de `appliesToKind` (income / expense; transfer y debt_payment no se categorizan). Como `debt_payment` no se categoriza, se ignora si llega un `category_id` para ese kind.
- Recurrencia `weekly`:
  - Campo `recurrence_day` = 0..6 (0 = lunes, 6 = domingo; misma convención que ISO 8601).
  - `start_date` es la primera ocurrencia. Si `start_date` no cae en el `recurrence_day` declarado, se ignora `start_date` para fijar el día de semana y se usa la primera coincidencia desde esa fecha en adelante. La spec recomienda que la UI fuerce `start_date` a coincidir con el día, pero el motor es robusto a discrepancias.
- Recurrencia `monthly`:
  - Campo `recurrence_day` = 1..31.
  - Si el mes no tiene ese día (ej. 31 en febrero), la ocurrencia se aplica el último día del mes.
- Recurrencia `one_off`: una sola ocurrencia en `start_date`. `recurrence_day` y `end_date` se ignoran.
- `end_date` (opcional): si está presente, la regla deja de generar ocurrencias después de esa fecha. Si está ausente, la regla genera ocurrencias hasta el final del horizonte de simulación (HOY + 6 meses).
- Override de una ocurrencia (`PlannedEventOverride`):
  - Identifica unívocamente la ocurrencia por `(planned_event_id, occurrence_date)`. Restricción unique en BD.
  - Puede modificar `amount` o marcar la ocurrencia como saltada (`is_skipped = true`).
  - No puede cambiar la cuenta ni el kind: si se quiere mover a otra cuenta o cambiar la naturaleza, se edita el evento base.
  - Aplica únicamente a la fecha exacta de la ocurrencia regular generada por la regla. Crear un override sobre una fecha que no corresponde a una ocurrencia de la regla queda rechazado por el dominio.
- Eventos `one_off` no admiten overrides; se editan o eliminan directamente.
- Simulación:
  - El horizonte siempre es HOY (la fecha del servidor en zona horaria del usuario) hasta HOY + 6 meses calendario.
  - El estado inicial es lo que devuelve `FinancialStateService` (balances por cuenta no archivada).
  - Las ocurrencias se procesan en orden cronológico. Múltiples eventos el mismo día se aplican en cualquier orden estable; el saldo final del día es determinista.
  - Filosofía libreta libre: la proyección puede mostrar saldos negativos y deudas que sobrepasen el límite. No se bloquea. La UI los marca visualmente.
  - Excepción: pagos a tarjeta (`debt_payment`) que dejarían la tarjeta con deuda < 0 (sobrepago) se aplican igual en la simulación, pero se marcan con un flag `warning = "overpay"` por congruencia con la única validación dura que sí existe en la creación real (`OverpayDebt` en `PayCreditAccount`). La simulación no falla; solo informa.

## Requisitos funcionales

- RF-001: El sistema debe permitir crear un `PlannedEvent` con `kind`, `amount`, `account_origin_id` y/o `account_destination_id` según corresponda al kind, `description` opcional, `category_id` opcional cuando aplica, `recurrence_type` (`weekly` | `monthly` | `one_off`), `recurrence_day` cuando aplica, `start_date` y `end_date` opcional.
- RF-002: El sistema debe validar el contrato tipo↔kind reutilizando la misma lógica que `UpdateJournalEntry::validateAccountsForKind` antes de persistir o actualizar un `PlannedEvent`.
- RF-003: El sistema debe permitir listar los `PlannedEvent` del usuario actual, scope estricto por `user_id`.
- RF-004: El sistema debe permitir actualizar y eliminar un `PlannedEvent`. La eliminación es hard delete o soft delete; la spec lo deja a criterio de implementación siempre que la UI lo refleje (ver Riesgos).
- RF-005: El sistema debe permitir registrar un `PlannedEventOverride` que aplique a una ocurrencia específica identificada por `(planned_event_id, occurrence_date)`, modificando `amount` o marcando `is_skipped = true`.
- RF-006: El sistema debe permitir actualizar o eliminar un override. Eliminar el override deja la ocurrencia con el valor original del evento base.
- RF-007: El sistema debe exponer un endpoint `GET /api/finance/plan/projection` que devuelva, para los próximos 6 meses, la serie temporal de saldos por cuenta y la lista cronológica de eventos efectivos (con sus overrides aplicados). El endpoint acepta sin parámetros y usa HOY del servidor como inicio.
- RF-008: La UI debe ofrecer una vista `/plan` con: (a) lista de eventos planeados, agrupados o filtrables por tipo, (b) formulario de creación/edición, (c) gráfica de evolución de saldos a 6 meses, (d) tabla cronológica de las próximas ocurrencias con la posibilidad de editar una ocurrencia individual (crea override).
- RF-009: La proyección debe recalcularse en cliente o en servidor inmediatamente después de cualquier alta, baja o edición de evento u override. No se requiere persistir la proyección.
- RF-010: La gráfica debe mostrar al menos: una línea por la cuenta Bolsa, una línea por cada cuenta de débito no archivada, una línea por cada cuenta de crédito no archivada (deuda). El usuario puede ocultar/mostrar series.
- RF-011: La tabla cronológica debe mostrar fecha, tipo, monto, cuenta(s) involucradas, descripción opcional y un indicador visual cuando la fila es resultado de un override o cuando la ocurrencia se saltó.
- RF-012: Si un `PlannedEvent` referencia una cuenta archivada, la UI debe mostrarlo con un badge "cuenta archivada" y el endpoint de proyección debe marcar sus ocurrencias futuras como saltadas sin aplicarlas al saldo.
- RF-013: El sistema debe rechazar la creación de eventos cuya `start_date` o `end_date` caigan fuera del horizonte futuro razonable (definido como HOY − 1 año a HOY + 5 años) para evitar errores de input. Dentro de ese rango la simulación se limita igual al horizonte de 6 meses.

## Casos principales

- Crear un ingreso recurrente: el usuario declara "Sueldo: $5,700 a Bolsa, cada viernes, empezando este viernes, sin fecha fin". La proyección a 6 meses muestra 26 ocurrencias y la línea de Bolsa sube en escalones cada viernes.
- Crear un pago recurrente a tarjeta: el usuario declara "Pago a Visa: $3,000 desde Bolsa, cada viernes". La línea de deuda de Visa baja cada viernes hasta llegar a 0 cuando se cubre la deuda actual; las ocurrencias posteriores se aplican igual y la deuda quedaría negativa, marcada con `warning = "overpay"`.
- Override puntual: el usuario edita la ocurrencia del próximo viernes y pone $5,000 en lugar de $3,000. La proyección se recalcula: ese viernes la deuda baja 5k, los siguientes viernes siguen bajando 3k según la regla.
- Crear un gasto puntual: el usuario declara "Vuelo Cancún: $4,200 desde Bolsa, el 14 de junio, one_off". La proyección refleja una caída de Bolsa ese día.
- Crear un gasto recurrente fijo: "Renta: $8,000 desde Banamex, día 1 de cada mes". Genera 6 ocurrencias en el horizonte.

## Casos borde

- Recurrencia `monthly` con `recurrence_day = 31` cayendo en febrero: la ocurrencia se aplica el 28 o 29 según el año.
- Evento cuya `start_date` es hoy: la primera ocurrencia es hoy (si coincide con el patrón) o la siguiente coincidencia.
- Evento con `end_date` anterior a `start_date`: rechazar al crear.
- Override sobre una `occurrence_date` que no corresponde a ninguna ocurrencia de la regla (ej. martes para una regla weekly con day=friday): rechazar al crear.
- Múltiples overrides para el mismo evento en fechas distintas: válido, cada uno aplica a su fecha.
- Cuenta referenciada por un evento fue archivada después de crear el evento: la simulación salta esas ocurrencias y la UI muestra alerta para que el usuario reasigne o archive el evento.
- Eventos del mismo día (ej. sueldo y dos pagos el mismo viernes): se aplican todos al saldo del día, en orden estable; la tabla cronológica los muestra agrupados o secuenciales.
- Recurrencia `weekly` cuya `start_date` es un día anterior al `recurrence_day` de esa misma semana: la primera ocurrencia es la primera fecha desde `start_date` (inclusive) que cae en el día declarado.
- Evento que sobreviene a un saldo de cuenta archivada porque la cuenta se reasignó en un override: rechazar el override que cambie cuenta (no permitido) y forzar editar el evento base.
- Pago recurrente que llevaría la deuda a negativo durante varias ocurrencias seguidas: las ocurrencias se aplican y todas se marcan con `warning = "overpay"`.
- Horizonte de 6 meses cae en un día que no es viernes: la simulación corre hasta esa fecha inclusive y termina ahí; no se completa la "última semana" si parcial.

## Criterios de aceptacion

- Al crear un `PlannedEvent` válido se persiste y queda visible en `GET /api/finance/plan/events` con todos sus campos, scope por usuario.
- Al crear un evento que viola el contrato tipo↔kind se devuelve 422 con un código de dominio (`invalid_account_type` o el equivalente reutilizado de las Actions actuales).
- Al consultar `GET /api/finance/plan/projection` con eventos creados, la respuesta contiene una lista de eventos efectivos ordenados cronológicamente y la serie temporal por cuenta, todo dentro del rango HOY a HOY + 6 meses.
- Al crear un override válido, la siguiente consulta a la proyección refleja el monto modificado únicamente en la fecha del override, sin alterar las otras ocurrencias.
- Al marcar `is_skipped = true` en un override, la ocurrencia desaparece del aporte al saldo pero se sigue mostrando en la tabla con un indicador "saltada".
- En la UI `/plan`, después de crear o editar un evento, la gráfica y la tabla cronológica reflejan el cambio sin necesidad de recargar la página.
- Crear un evento que referencia una cuenta archivada o de otro usuario devuelve 422 / 404 sin persistir.
- La proyección nunca modifica `journal_entries` ni el estado real: tras correr la proyección, `FinancialStateService::getBO()` devuelve exactamente el mismo valor que antes.
- Los saldos negativos y la deuda en sobrepago (`overpay`) se muestran en la UI con un estilo distintivo (rojo / warning), reusando la misma paleta que el dashboard actual.

## Criterios medibles de exito

- Tiempo de respuesta del endpoint de proyección menor a 500 ms para un usuario con hasta 50 eventos planeados y 5 cuentas activas.
- Cero regresiones: la suite backend completa (actualmente 206 tests) sigue verde tras integrar el feature.
- Al menos 90 % de cobertura de tests unitarios sobre la nueva clase de simulación, incluyendo todos los casos borde listados arriba.
- La proyección de un escenario realista (1 ingreso semanal + 2 pagos semanales a tarjeta + 2 gastos mensuales fijos + 3 one-off) produce un resultado verificable a mano que coincide con la salida del endpoint.
- La UI `/plan` se carga en menos de 2 segundos en localhost con 50 eventos.

## Riesgos

- **Drift entre carriles**: el usuario puede registrar movimientos reales que no coincidan con su plan declarado. La v1 no concilia los dos carriles, así que la proyección puede "mentir" si el usuario abandona su plan en la realidad. Mitigación: la spec lo asume; futuras versiones pueden agregar comparación plan vs real.
- **Cuentas archivadas con eventos vivos**: si el usuario archiva una cuenta sin antes editar los eventos que la usan, la proyección "salta" silenciosamente. Mitigación: alerta visual en la lista de eventos y en la tabla cronológica; eventualmente bloquear archivado de cuenta si hay eventos activos referenciándola (queda para fase posterior, no v1).
- **Soft delete vs hard delete de eventos**: si se opta por soft delete habría que decidir el alcance de overrides huérfanos. La spec recomienda hard delete simple en v1 (los eventos planeados no tienen valor histórico equivalente a un `JournalEntry`).
- **Costo de simulación**: si en el futuro alguien declara cientos de eventos diarios el motor podría volverse lento. El supuesto razonable es que un usuario típico tiene 5–20 eventos. Si se cruza ese umbral, se evalúa optimización.
- **Cálculo de fechas en zonas horarias**: el snapshot real y la simulación usan la fecha del servidor. Si el usuario opera desde otra zona horaria, la "primera ocurrencia hoy" puede no coincidir con su percepción. Mitigación v1: documentar; v2: TZ por usuario.
- **Recurrencias quincenales**: el usuario podría querer "días 1 y 15 del mes" como un solo evento. v1 lo fuerza a crear dos eventos monthly separados. Documentado en Fuera de alcance.

## Supuestos

- El usuario tiene al menos una cuenta cash (Bolsa) y un horizonte continuo de uso. La simulación sin estado inicial no aporta valor.
- La granularidad de la proyección es **día**. No se proyectan saldos intraday.
- La proyección se calcula bajo demanda (cada vez que se consulta el endpoint). No se cachea ni se precalcula. Esto simplifica el ciclo plan ↔ override ↔ recálculo.
- Las cuentas archivadas no aportan a la proyección desde el momento del archivado (el snapshot inicial las excluye via `FinancialStateService`).
- La UI usará Chart.js (ya disponible en el proyecto por el reporte de cashflow) para la gráfica de líneas.
- El feature vive bajo `/plan` como ruta de primer nivel del SPA, no como subruta de `/reports`. Conceptualmente "plan" es una herramienta de decisión, no un reporte sobre el pasado.
- La tabla `planned_events` y `planned_event_overrides` usan UUID v7 (igual que el resto del dominio) y `user_id` UUID. Schema análogo a `journal_entries`.
- El motor de simulación vive en `backend/app/Domain/Finance/Plan/` (carpeta nueva paralela a `Reports/`) con al menos: el modelo `PlannedEvent`, el modelo `PlannedEventOverride`, un service `PlanProjectionService` y Actions para CRUD.
- Endpoints REST viven bajo `/api/finance/plan/*`, scoped por sanctum + verified igual que el resto de `/api/finance/*`.
- Hard delete para `PlannedEvent` y `PlannedEventOverride` en v1. Los eventos planeados no necesitan archivo histórico.

## Impacto esperado

- **Backend**: dos nuevas tablas, modelos, Actions, service de proyección y endpoints. Sin cambios destructivos en el dominio actual: el feature es aditivo.
- **Frontend**: una nueva vista `/plan`, dos o tres componentes nuevos (lista de eventos, formulario, gráfica + tabla), reusa Chart.js, BaseModal, BaseSelect, BaseInput.
- **DX**: el patrón de "Actions + Service + Reports + Exceptions" se extiende a un nuevo subdominio `Plan/`. Mantiene la convención DDD-light del proyecto.
- **Performance**: el endpoint de proyección agrega carga proporcional al número de eventos × días del horizonte (en orden ~5000 operaciones para casos realistas). Sin riesgo material.
- **Usuario**: gana visibilidad sobre el futuro inmediato. Es la primera herramienta prospectiva de FinCore.
- **Migración / dato existente**: ninguna. Las tablas nuevas arrancan vacías por usuario.

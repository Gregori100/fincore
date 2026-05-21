# Clarificaciones

## 2026-05-19

Revisión final de los supuestos sensibles antes de planear. El usuario confirmó las 5 decisiones tal cual estaban en `spec.md`:

- Decisión: Sobrepago en simulación se aplica y se marca `warning = "overpay"`, pero el `OverpayDebt` real al crear el movimiento sigue bloqueando. La simulación responde "qué pasaría si"; el registro real conserva la única validación dura del dominio.
  Impacto en spec: confirma Reglas de negocio (Simulación) y Casos borde (sobrepago en simulación).

- Decisión: `recurrence_day` semanal usa la convención ISO 8601 (`0 = lunes`, `6 = domingo`).
  Impacto en spec: confirma Reglas de negocio (Recurrencia `weekly`).

- Decisión: `PlannedEvent` y `PlannedEventOverride` usan hard delete en v1. No hay historial de planes archivados.
  Impacto en spec: confirma Supuestos y RF-004.

- Decisión: `transfer` no entra como tipo de evento planeado en v1. Para modelar movimientos entre cuentas propias el usuario debe crear dos eventos (un `expense` y un `income`).
  Impacto en spec: confirma Fuera de alcance.

- Decisión: No se agregan patrones de recurrencia quincenal/biweekly. Casos como "días 1 y 15" se modelan con dos eventos `monthly`.
  Impacto en spec: confirma Fuera de alcance y Riesgos.

Estado de la spec al cierre: **Lista para planear**. Sin preguntas pendientes ni bloqueos.

## 2026-05-20

Cambio retroactivo al motor de proyección a pedido del usuario tras probar la v1:

- Decisión: `debt_payment` planeado se **auto-ajusta** en la simulación para nunca dejar la tarjeta en negativo. Si el monto programado excede la deuda actual al momento de la ocurrencia, se recorta al monto exacto adeudado (`warning = "auto_adjusted"`). Si la deuda ya está en 0, la ocurrencia se salta entera (`warning = "debt_already_zero"`).
  Impacto en spec: deroga el comportamiento anterior de aplicar el pago igual y marcar `warning = "overpay"`. Reglas de negocio (Simulación) y Casos borde actualizados. La filosofía libreta libre se preserva para cash/débito (saldos pueden ir negativos) y para cargos a tarjeta (pueden exceder credit_limit), pero NO para pagos planeados de tarjeta — porque sobrepagar es un caso sin uso real (motivo por el cual `OverpayDebt` también bloquea en la creación de movimientos reales).
  Decisión técnica: el ajuste vive en `PlanProjectionService::project()` antes de aplicar el saldo, no en una flag por evento. Si en el futuro alguien quiere "sí pagar más para acumular saldo a favor" se agrega un flag opt-in.

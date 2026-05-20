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

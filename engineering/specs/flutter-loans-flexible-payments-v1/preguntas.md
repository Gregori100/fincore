# Preguntas abiertas

Las tres preguntas de esta spec se resolvieron con Diego el 2026-08-05, antes de escribir `spec.md`. Sus respuestas ya están integradas en las reglas de negocio y los requisitos funcionales. Se conservan aquí para trazabilidad de por qué el alcance quedó así.

## Alcance

- ID: P-001
  Estado: respondida
  Pregunta: ¿Se elimina también el candado `duplicate_monthly_payment` (un solo pago con intereses por mes calendario), o únicamente `capital_before_monthly`?
  Por que importa: el reporte original de Diego mezcla los dos síntomas. Quitar solo el segundo dejaría sin resolver el caso que originó el sprint — su préstamo es quincenal y necesita dos pagos con intereses en el mismo mes.
  Impacto si cambia: si se conservara `duplicate_monthly_payment`, RF-001 desaparece, RN-LF-01 se invierte y el caso principal 1 deja de ser soportado.
  Respuesta o decision: **quitar los dos candados**. Integrado en RN-LF-01, RN-LF-02, RF-001 y RF-002.

## UX

- ID: P-002
  Estado: respondida
  Pregunta: El chip del préstamo en el Dashboard tiene dos estados — "N meses atrasados" (rojo) y "Próximo pago en N días" (naranja). ¿Cuál se elimina?
  Por que importa: el rojo se alimenta de un conteo por mes calendario que carece de sentido en un préstamo quincenal, pero el naranja depende solo de `payment_day` y sigue siendo útil como recordatorio.
  Impacto si cambia: eliminar ambos dejaría el préstamo sin ninguna señal en el Dashboard; conservar ambos mantendría la alerta falsa.
  Respuesta o decision: **eliminar solo el chip rojo de atrasos**. El naranja conserva su lógica actual, incluido el ocultarse cuando ya hay pago del mes registrado. Integrado en RN-LF-12, RF-004 y CA-05.

## Datos

- ID: P-003
  Estado: respondida
  Pregunta: Para reflejar el ajuste de saldo del banco, ¿se modela una tabla de ajustes con historial o un único campo acumulado editable en el préstamo?
  Por que importa: define si el sprint agrega una tabla, una migración de schema y un bump de backup, o solo una columna. Determina también si es posible auditar ajustes sucesivos.
  Impacto si cambia: con un campo único desaparecen la tabla `loan_adjustments`, RF-005, RF-007 parcialmente, el bump de backup a v4 y con él el riesgo R-01; pero se pierde el rastro de cuándo y por qué cambió el saldo cada vez.
  Respuesta o decision: **tabla de ajustes con historial**, con monto firmado, motivo y fecha. Diego no sabe por qué el banco hizo el ajuste, así que dejar rastro tiene valor si vuelve a ocurrir. Integrado en RF-005 a RF-009 y en RN-LF-05 a RN-LF-11.

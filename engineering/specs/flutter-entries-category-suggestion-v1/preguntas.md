# Preguntas abiertas

## UX

- ID: P-001
  Estado: respondida
  Pregunta: ¿El sello visual "Sugerida" (chip pequeño con icono ✨ debajo del picker) está bien, o preferís algo más sobrio como solo cambiar el color del label del `CategoryPicker` a accent cuando es sugerencia?
  Por qué importa: el sello visual define la sensación de "asistencia activa" vs "selección silenciosa". Un chip explícito le dice a Diego "esto lo eligió la app, podés cambiarlo"; cambiar el color del label es más sutil pero más fácil de pasar por alto.
  Impacto si cambia: una clase nueva (`_SuggestionChip`) vs un cambio de estilo del label existente. Trivial cualquiera, pero define el patrón visual del sprint.
  Respuesta o decisión: **Chip "✨ Sugerida"** debajo del `CategoryPicker`. Pequeño, color accent suave, icono sparkle al inicio + texto "Sugerida". Desaparece cuando el usuario cambia la selección. Integrada en RF-005 y RN-S07.

## Alcance

- ID: P-002
  Estado: respondida
  Pregunta: ¿La sugerencia aplica también a `income` o solo a `expense` + `credit_expense` (gastos)?
  Por qué importa: los kinds donde la categoría tiene mayor utilidad son los gastos (presupuesto, análisis de consumo). Income típicamente tiene pocas fuentes (salario, freelance, regalos). Si la incluimos en v1, el servicio debe contemplar `income` con su cuenta destino en lugar de origen.
  Impacto si cambia: pequeño — agregar `'income'` al filtro de kinds y manejar `account_destination_id` en lugar de `account_origin_id` para esa rama. ~30 min adicionales.
  Respuesta o decisión: **`expense` + `credit_expense` + `income`** (revisión en 2026-06-29). Diego pidió incluir income también en v1. Para income, la "cuenta relevante" del algoritmo es `account_destination_id` (a dónde llega el dinero); para expense/credit_expense es `account_origin_id` (de dónde sale). El servicio recibe un único `accountId` y el caller (form) decide cuál pasar según el kind actual. Integrada en RN-S01, RN-S03, RF-001, RF-003, CP-07, CB-T13, AC-05 y S-04.

## Casos borde

- ID: P-003
  Estado: respondida
  Pregunta: ¿El match de descripción es **exacto** (case-insensitive trimmed) o también **substring** (e.g., "Café Starbucks Monterrey" matchea con descripción histórica "Café Starbucks")?
  Por qué importa: substring matching es más útil cuando Diego escribe descripciones largas con detalles variables, pero también puede dar falsos positivos ("Pagué luz" matchearía con "Pagué luz y agua" → categoría incorrecta). Exact match es más predecible y simple.
  Impacto si cambia: SQL diferente (`LIKE '%' || ? || '%'`) + potencial degradación de performance sin índice FTS. Tests adicionales para casos parciales.
  Respuesta o decisión: **Match exacto** (case-insensitive, trimmed). Sin substring. Razón: predecible, sin falsos positivos. La cascada cubre el resto — si no matchea exacto, igual cae a "monto+cuenta" o "más usada reciente". Integrada en RN-S03 paso 1.

## Casos borde (resoluble con supuesto razonable)

- ID: P-004
  Estado: respondida
  Pregunta: ¿La ventana de "monto+cuenta reciente" de 90 días y "más usado" de 30 días son adecuadas?
  Por qué importa: ventanas muy cortas (e.g. 7 días) hacen que sugerencias dejen de funcionar después de una semana sin uso; muy largas (e.g. 365 días) traen sugerencias obsoletas. 30/90 es estándar.
  Impacto si cambia: trivial — un literal en el código.
  Respuesta o decisión: **30 días para "más usado", 90 días para "monto+cuenta"** confirmado. Estándar de la industria, balance entre relevancia y suficiente histórico. Integrada en RN-S03 pasos 2 y 3.

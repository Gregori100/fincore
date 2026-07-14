# Preguntas abiertas

Todas cerradas. Se dejan registradas para trazabilidad.

## Integraciones

- ID: P-001
  Estado: respondida
  Pregunta: ¿El backup JSON incluye los presupuestos semanales y sube
  a versión 2, o quedan fuera del backup por ahora (v1 se mantiene)?
  Respuesta o decision: **NO al backup**. Los presupuestos no se
  exportan ni importan. El backup queda en v1. Los presupuestos y
  plantillas se pierden en cada restore — trade-off aceptado. FAQ
  del HelpScreen debe explicar el detalle.
  Integrado en spec: `Fuera de alcance` + `RN-B13` + `CP-13` + `CB-09`.

## Terminología

- ID: P-002
  Estado: respondida
  Pregunta: ¿Cómo se llama en la UI para no confundir con el reporte
  mensual "Presupuestos"?
  Respuesta o decision: **"Presupuestos semanales"** en la UI del
  módulo nuevo. El reporte mensual sigue como "Presupuestos" en
  `/reports`. Ruta top-level `/budgets`.
  Integrado en spec: `Resumen`, `Objetivo`, `Alcance`.

## Datos

- ID: P-003
  Estado: respondida
  Pregunta: ¿La compatibilidad `kind`/`applies_to` de la categoría
  se enforcea?
  Respuesta o decision: **Laxo (A)**. La UI sugiere pero el DAO
  acepta cualquier categoría activa. Es planeación libre, no ledger
  real.
  Integrado en spec: `RN-B07` + `CB-11` + `CB-12`.

- ID: P-004
  Estado: respondida
  Pregunta: ¿Se permite tener más de un presupuesto ACTIVO por la
  misma `week_start_date`?
  Respuesta o decision: **SÍ (opción B)**. Se permiten múltiples
  presupuestos con la misma fecha. Cada uno con su `label`
  obligatorio distinto. Sirven como escenarios comparativos
  ("Conservador", "Optimista").
  Integrado en spec: `RN-B04` + `RN-B14` + `CP-06`.

## UX

- ID: P-005
  Estado: respondida
  Pregunta: ¿Advertencia al cambiar `week_start_dow` con
  presupuestos futuros existentes?
  Respuesta o decision: **No hace falta** — al final Diego optó
  porque cambiar el `week_start_dow` NO afecta a los presupuestos
  existentes. Cada uno conserva su `week_start_date` original y su
  rango calculado desde esa fecha. Solo cambia el default sugerido
  del picker para el siguiente create. Sin dialog destructivo.
  Integrado en spec: `RN-B10` + `CP-04` + `CB-05`.

- ID: P-006
  Estado: respondida
  Pregunta: ¿Card del presupuesto de "esta semana" en el Dashboard?
  Respuesta o decision: **NO**. Entrada al módulo solo por
  IconButton en el AppBar del Dashboard.
  Integrado en spec: `Fuera de alcance`.

- ID: P-007
  Estado: respondida (con pivot terminológico y de gesto)
  Pregunta: ¿Cómo se reordenan los renglones dentro de una sección?
  Respuesta o decision: **Drag & drop con handle visual** (icono
  ⋮⋮ tipo `Icons.drag_indicator`). El row completo NO inicia el
  gesto — solo el handle. Widget: `ReorderableListView` con
  `buildDefaultDragHandles: false` + `ReorderableDragStartListener`
  envolviendo el handle.
  Terminología: se cambia "línea" → **"renglón"** en todo el módulo.
  Integrado en spec: `RN-B11` + `RF-007` + `CP-03` + `CB-20`.

## Alcance

- ID: P-008
  Estado: respondida (con pivot mayor: plantillas en vez de
  duplicar)
  Pregunta: ¿Método `duplicateBudget(id)` que copie a la próxima
  semana?
  Respuesta o decision: **Pivot mayor**. En vez de una acción
  "duplicar", se implementan **plantillas de presupuesto** como
  entidad nueva. Se crean derivadas de un presupuesto existente
  ("Crear plantilla desde este presupuesto"). Al armar un
  presupuesto nuevo se ofrece "Desde plantilla" (con preview).
  Monto obligatorio en los renglones de la plantilla. Snapshot
  copiado (no comparte referencia). También se agregan CRUD +
  hard delete de plantillas y presupuestos.
  Integrado en spec: `Objetivo #5`, `Alcance` (tablas
  `budget_templates` y `budget_template_items`, `BudgetTemplatesDao`,
  `BudgetTemplatesScreen`), `RN-B15/B16/B17/B18`, `RF-014..RF-019`,
  `CP-09..CP-12`, `CB-15..CB-19`.

- ID: P-009
  Estado: respondida
  Pregunta: ¿La fecha del presupuesto solo puede caer en el día del
  `week_start_dow`?
  Respuesta o decision: **Sugerido, no forzado**. El picker por
  default apunta al próximo día que coincide con `week_start_dow`
  (viernes), pero el usuario puede moverlo a cualquier día. El
  rango del presupuesto se calcula como 7 días desde la fecha
  elegida (RN-B03). Al editar el presupuesto, la fecha es
  immutable (RN-B09) porque afectaría el rango de los renglones ya
  agregados.
  Integrado en spec: `RN-B02` + `RN-B03` + `RN-B09` + `Fuera de
  alcance` (restricción dura descartada).

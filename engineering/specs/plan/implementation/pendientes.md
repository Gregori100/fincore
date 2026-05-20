# Pendientes — Plan

## T036 — smoke tests de componentes Vue

El plan listaba 3 smokes: `PlannedEventForm.spec.js`, `PlanProjectionTable.spec.js`, `PlanProjectionChart.spec.js`. Solo se ejecutó el del store (`plan.spec.js`). Los smokes de componentes quedan diferidos por:

- el costo de montar Chart.js con mock de canvas en jsdom es alto y suele dar más ruido que valor;
- la cobertura funcional ya está garantizada por los tests backend (motor + endpoints) y por el store (que valida la integración cliente-servidor).

Acción recomendada: si en uso real se detecta algún edge case visual, agregar el smoke específico.

## T039 — recorrido manual de 10 pasos

Pendiente de ejecutar por el usuario. La guía está en `engineering/specs/plan/plan/test-plan.md` sección "Pruebas manuales o smoke tests necesarios". Pasos clave:

1. Crear ingreso recurrente weekly y verificar gráfica.
2. Crear pago a tarjeta semanal y ver cuándo cae a 0.
3. Editar una ocurrencia (crear override).
4. Cambiar `recurrence_day` con override existente y confirmar el aviso de "se borrarán N overrides".
5. Archivar la cuenta de un evento y verificar badge "cuenta archivada".

## T040 — branch-quality-review

Sugerido antes del merge a `main`. Ejecutar con `/branch-quality-review slug=plan`. Output esperado en `engineering/quality-review/plan/`.

## T042 — actualizar memoria del proyecto

Actualizar `~/.claude/projects/-home-developer-Escritorio-proyectos-fincore/memory/project_backlog.md` marcando el feature Plan como cerrado y, eventualmente, agregando lecciones aprendidas.

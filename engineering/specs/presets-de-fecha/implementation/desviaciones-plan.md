# Desviaciones del plan

Cambios respecto a `plan/plan.md` y `plan/tasks.md`. Ninguno altera el alcance ni los criterios de aceptación.

## D-001: prop `disabled` removida del componente

El plan inicial declaraba `disabled?: boolean` como prop opcional del `DateRangePreset`. Al implementar se confirmó que `BaseSelect` y `BaseInput` (los componentes hijo) **no soportan `disabled`** en su API actual. La prop quedaba sin efecto visual. Se eligió removerla en lugar de exponer una API ilusoria. Si en el futuro los Base* soportan `disabled`, se reintroduce.

## D-002: ReportsByAccountView gana `watch` automático

Aunque no estaba en las tareas del plan, durante la implementación del QR se detectó que `ReportsByAccountView` no tenía `watch` sobre `filters` (comportamiento preexistente desde antes del sprint). Con el dropdown de presets activo, la inconsistencia UX se volvió visible: `ByCategory` y `EntriesTable` refrescan automáticamente, `ByAccount` no.

Se aplicó el `watch` durante el cierre del sprint (no como tarea separada del plan), porque atender el hallazgo del QR (M1) tenía baja complejidad (3 líneas) y resolvía una inconsistencia visible.

## D-003: import muerto en EntriesTable corregido durante el QR

`BaseInput` quedó como import residual tras reemplazar los inputs from/to por `DateRangePreset`. Detectado por el QR como M2, removido durante el cierre del sprint.

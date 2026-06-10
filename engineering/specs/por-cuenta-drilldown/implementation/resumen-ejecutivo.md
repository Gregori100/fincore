# Resumen ejecutivo — por-cuenta-drilldown

## Qué se implementó

1. **Reporte "por cuenta"**: sexto reporte en `/reports/by-account` que muestra Ingresos, Gastos y Neto para cada cuenta activa en un rango configurable (default mes en curso). En tarjetas de crédito, "Ingresos" son pagos recibidos a la deuda y "Gastos" son cargos.
2. **Drill-down transversal en TODOS los reportes**: cada bucket clickeable (categoría, mes, tarjeta, presupuesto, cuenta) abre un modal compacto con la tabla de movimientos exactos del bucket. Botón "Ir a Movimientos" navega a `/entries` con los filtros precargados para editar/cancelar/paginar.

## Impacto esperado

- **Auditabilidad**: cada número en cualquier reporte se vuelve verificable en un click. El usuario deja de tener que ir manualmente a `/entries` y aplicar filtros para entender un total.
- **Visibilidad por cuenta**: cierra la pregunta "¿qué cuenta uso más para gastar?" sin necesidad de inferirlo de otros reportes.
- **Patrón reusable**: el modal `EntriesDrilldownModal` queda como pieza canónica. Reportes futuros heredan el drill-down emitiendo un evento con filtros estandarizados.

## Riesgos o pendientes relevantes

- Recorrido manual de los 10 puntos del smoke pendiente del usuario.
- `/branch-quality-review` recomendado antes del merge.
- Sin migraciones; cambios aditivos; rollback es revertir el commit.

## Estado de pruebas

- Backend: **322 verde / 0 fallidos** (línea base 300, +22 nuevos).
- Frontend: **53 verde / 0 fallidos** (línea base 49, +4 nuevos del modal).
- Gate de regresión (`test_entries_endpoint_paginates_and_filters`): verde tras el refactor del helper compartido.
- Anti-N+1: tests con ≤10 queries para 20 entries con eager loading.

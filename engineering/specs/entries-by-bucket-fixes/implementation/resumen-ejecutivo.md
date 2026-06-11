# Resumen ejecutivo — entries-by-bucket-fixes

## Qué se implementó

Dos fixes al endpoint del drill-down de reportes para que el contenido del modal cuadre exactamente con el bucket clickeado:

- **P1**: bucket "Sin categorizar" ahora muestra solo entries sin categoría (antes mostraba todas las categorías mezcladas).
- **P2**: bucket de gastos con `kind=expense` ahora incluye también cargos a tarjeta (`credit_expense`), alineando con la semántica que ya usan los reportes agregados (Por categoría, Presupuestos, Proyección).

Durante el smoke se descubrió un **bug preexistente del helper compartido** (`applyEntryFilters` filtraba `to` sin hora, excluyendo el último día del rango). Corregido como fix emergente porque sin esto P2 no se demostraba funcionar en navegador real.

## Impacto esperado

- **Para el usuario**: los buckets de los 7 reportes y su drill-down ahora cuadran. La confianza en el módulo de reportes mejora.
- **Para `/entries`**: el filtro "Tipo = Gasto" hereda la mejora (incluye cargos a tarjeta), y el filtro de fecha incluye el último día completo. Documentado como cambios deseables en la spec.

Cambio aditivo de comportamiento. Sin cambios en el contrato JSON. Sin migraciones.

## Riesgos o pendientes relevantes

- **M1 (preexistente)**: el flujo "Ir a Movimientos" desde el bucket "Sin categorizar" sigue roto — la navegación a `/entries?category_id=` no aplica el filtro porque `listEntries` y `EntriesTable` usan truthy checks. Documentado para sprint chico futuro. Requiere también una opción "Sin categorizar" en el BaseSelect de filtros.
- **M2 (preexistente)**: bucket sintético "Otras" en `ReportsByCategoryView` (cuando hay 7+ categorías) navega con `category_id='__others__'` que falla validación. Documentado para backlog.
- **Fix emergente del `to`**: aplica también a `listEntries` (helper compartido). Mejora consistencia, sin regresiones detectadas.

## Estado de pruebas

- **Backend**: 394/394 verde (eran 386; +8 nuevos).
- **Frontend**: 119/119 verde (eran 116; +3 nuevos).
- **Pint**: limpio.
- **Smoke con Playwright real**: P1 ✓, P2 ✓, fix `to` ✓ (los buckets cuadran exactamente con el modal del drill-down).
- **Quality review**: 0 bloqueantes, 0 altos del sprint, 2 medios preexistentes (M1, M2) documentados, 3 bajos opcionales.

Listo para merge.

# Resumen ejecutivo — flutter-reports-monthly-average-v1

## Qué se implementó

Un 5° tab "Promedio mensual" en `/reports` que responde la pregunta: *"¿estoy gastando más o menos que de costumbre?"*. Compara el gasto promedio mensual prorrateado al mismo día del mes (configurable a 1, 3, 6, 12 o 24 meses cerrados; default 3) contra el gasto del mes en curso. Resultado: delta absoluto, porcentual y semáforo (verde si gastás ≤95% del promedio, amarillo 95-110%, rojo >110%). Debajo, el desglose por categoría aplica la misma comparación, ordenado por mayor desviación al alza primero.

## Impacto esperado

- Diego puede medir su gasto contra su propio patrón histórico sin tener que cruzar a ojo los datos del tab Cashflow.
- El desglose por categoría permite identificar **en qué** se desvió el gasto (e.g. "Comida fuera está 40% arriba aunque el global está en línea").
- Sienta la base de datos confiables para el **módulo Presupuestos futuro**: el método `monthlyAverage` es directamente reutilizable y comparte reglas de inclusión por kind y definición de "mes en curso".

## Riesgos o pendientes relevantes

- **Smoke manual pendiente** sobre la BD real de Diego (especialmente migración no requerida pero estabilidad sobre datos preexistentes).
- **Categorías con histórico pero sin movimiento del mes actual** aparecen en el breakdown con delta negativo. Documentado en RN-A14; revisar en uso si confunde.
- Performance con journals grandes (>10k entries) no medida. Aceptable para tamaño single-user típico.

## Estado de pruebas

- `flutter test`: **321 tests verdes** (antes 302). 15 unit tests nuevos del DAO + 4 widget tests del tab.
- `flutter analyze`: 0 errores nuevos.
- Smoke manual: pendiente Diego.

## Versión

`0.10.0+62` → `0.11.0+63`. Minor bump por feature visible nuevo, sin breaking en BD ni en API pública.

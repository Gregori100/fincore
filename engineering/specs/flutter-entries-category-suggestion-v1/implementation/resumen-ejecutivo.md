# Resumen ejecutivo — flutter-entries-category-suggestion-v1

## Qué se implementó

Sugerencia automática de categoría al capturar un nuevo movimiento en `/entries/new`. Al elegir kind (`expense`, `credit_expense`, `income`) y escribir descripción, monto o cuenta, el `CategoryPicker` se pre-selecciona con la categoría más probable según el histórico de Diego. Un chip "✨ Sugerida" debajo del picker comunica que la categoría fue propuesta por la app. Diego puede confirmar dejándola tal cual o cambiarla manualmente; tras un cambio manual, la sugerencia no se recalcula más en ese form.

El algoritmo es una cascada de 3 criterios:

1. **Descripción idéntica** (case-insensitive trimmed): entry más reciente con la misma descripción y categoría activa.
2. **Monto + cuenta + kind** dentro de los últimos 90 días.
3. **Categoría más usada** en los últimos 30 días para ese kind + cuenta.

Si ningún paso matchea, el picker queda vacío como hoy.

## Impacto esperado

- **Menos fricción** en la captura diaria de gastos. Diego registra más entries con categoría correcta sin pensar.
- **Mejor calidad del dataset** que alimenta los reportes (Gasto por categoría, Promedio mensual recién instalado, Presupuestos futuro).
- **Sienta precedente** del patrón "servicio que consulta el journal con cascada de heurísticas". Reutilizable para futuras sugerencias (cuenta, monto recurrente, detección de duplicados).

## Riesgos o pendientes relevantes

- **SQLite `LOWER` es ASCII-only**: descripciones históricas con acentos en MAYÚSCULA no matchean con tipeo en minúscula. Bajo en uso real (Diego escribe en minúscula).
- **Sin smoke manual confirmado**: el chip puede sentirse intrusivo en el primer uso o muy útil; depende del feedback real.
- **`branch-quality-review` no se invocó** automáticamente — Diego decide si lo lanza antes del commit.

## Estado de pruebas

- `flutter test`: **343 tests verdes** (antes 321; +22 nuevos).
  - 18 unit tests del servicio cubriendo cascada completa, edge cases, `now` inyectable, soft delete, applies_to compatible/incompatible.
  - 4 widget tests del form cubriendo sugerencia visible, manual override, edit no dispara, BD vacía sin chip.
- `flutter analyze`: 0 errores nuevos.
- Smoke manual: pendiente Diego.

## Versión

`0.11.1+64` → `0.11.2+65`. Patch bump por feature pequeño no-breaking, sin schema bump.

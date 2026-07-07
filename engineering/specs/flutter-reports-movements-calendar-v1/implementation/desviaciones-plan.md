# Desviaciones respecto al plan

## D1 — SQL usa `strftime('%Y-%m-%d', 'localtime')` en lugar de `date()`

- **Plan original**: `SELECT date(occurred_at) AS day, kind, COUNT(*) AS count`.
- **Realidad**: drift almacena `DateTime` como TEXT UTC con sufijo `Z` (por `store_date_time_values_as_text: true` en `build.yaml`). Sin `'localtime'`, `date()` extrae `YYYY-MM-DD` del UTC — un entry a las 23:00 local del día 30 (que en UTC son las 05:00 del 31) cae en el día 31. UT-CAL11 lo detectó al primer run.
- **Solución**: `strftime('%Y-%m-%d', occurred_at, 'localtime')` respeta el huso horario del dispositivo. Comportamiento consistente con lo que el usuario espera ver.
- **Impacto**: cero, es el fix correcto. Cubierto por UT-CAL07 (día con 3 kinds en horas distintas) y UT-CAL11 (borde `23:59:59.999`).

## D2 — WT-CAL03 verifica el drill-down por resultado observable

- **Plan original**: verificar que el `EntriesFilters` pasado al drill-down tiene `from = to = ese día`.
- **Realidad**: inspeccionar el estado de `EntriesListScreen` (o su widget interno) requiere hookearse al State privado o al parseo de `EntriesFilters` desde la URL — complejo y frágil.
- **Solución**: verificar que la descripción del entry sembrado (`'IncomeCAL'`) aparece en la lista tras el tap. Verifica end-to-end el resultado observable: el usuario ve el entry correcto en su drill-down.
- **Impacto**: sin cambio de intención. Test más robusto contra refactors del parseo del deep link.

## D3 — Finder `find.byType(TableCalendar<dynamic>)` cambiado a `byWidgetPredicate`

- **Plan original**: `find.byType(TableCalendar<dynamic>)` para localizar el widget del calendario en tests.
- **Realidad**: Flutter no matchea `find.byType(TableCalendar<dynamic>)` contra `TableCalendar<DayActivity>` (el generic real usado en el widget). Los 4 WT-CAL fallaron por "Found 0 widgets" al primer run.
- **Solución**: `find.byWidgetPredicate((w) => w is TableCalendar)` sin genérico. Idiomático en Flutter para widgets genéricos.
- **Impacto**: sin cambio de intención. Cero riesgo de falso positivo (solo hay 1 `TableCalendar` en el tab).

Sin desviaciones bloqueantes.

# Pendientes — flutter-reports-v1

## Pendientes del sprint (diferidos con justificación)

### P-01: Widget tests del DatePicker (T027 + T028)

**Estado**: diferido al cierre del sprint.

**Contenido**: validar via widget test el flujo de:
- Abrir `showDatePicker` con tap en `OutlinedButton "Desde"`.
- Seleccionar una fecha distinta.
- Validar que el rango se actualizó y la query re-emitió.
- Para rango inválido (`from > to`): validar `SnackBar` warning visible + rango previo preservado.

**Por qué se difirió**:
- Material 3 `showDatePicker` tiene animaciones internas (apertura del modal, transición de meses, cierre) que cuelgan `pumpAndSettle` consistentemente. Mismo patrón documentado en DV-1 v1/v2 con `DropdownMenu`.
- La lógica del filtro de fecha y del rango inválido están cubiertas por los UT-11 a UT-17 del `reports_test.dart`.
- El SnackBar warning queda cubierto por el smoke manual SM-04.

**Cuando atacar**:
- Si se identifica un patrón confiable para test de DatePicker (mockear `showDatePicker`, golden-test snapshot, etc.).
- Si la regresión del flujo de filtros se vuelve real (Diego reporta que el cambio de fecha no actualiza la vista).

## Pendientes técnicos a futuro

### P-02: Loading state con UX rica

**Hoy**: `SizedBox(height: 1)` durante el primer frame del `StreamBuilder` (~10-50ms en BD in-memory, imperceptible en el cel real con miles de entries).

**Mejora**: agregar un `BaseCard` estático con texto "Cargando…" o un placeholder no animado. Mejor UX visual sin colgar tests.

**Cuando**: si Diego nota que la pantalla se ve vacía en el primer milisegundo. O si en el cel real con journal de 5000+ entries la query tarda > 200ms y el placeholder vacío es feo.

### P-03: Click en bucket → drill-down a entries del rango

Hoy el reporte es solo lectura agregada. Un tap en un bucket podría abrir `EntriesListScreen` filtrada por:
- Categoría del bucket (o "Sin categoría").
- Rango temporal del reporte.

**Cuando**: si Diego pide la funcionalidad. Requiere extender `EntriesListScreen` para aceptar filtros via query params del router. Estimado: 4-6h.

### P-04: Persistir último rango entre sesiones

Hoy cada apertura de `/reports` resetea al mes corriente. Diego podría querer que recuerde el último rango elegido durante esa sesión (o cross-session con SharedPreferences).

**Cuando**: si el caso de uso recurrente (revisar mes anterior repetidamente) molesta. Estimado: 1-2h con SharedPreferences.

### P-05: Exportar reporte a CSV/PDF

Hoy el reporte vive solo en la app. Diego podría querer compartirlo (WhatsApp, mail) o imprimirlo.

**Cuando**: depende de necesidad real. Estimado: 3-5h (PDF requiere dep nueva como `pdf` o `printing`).

### P-06: Siguientes reportes en `/reports`

El TabBar tiene 1 tab pero la estructura es extensible. Reportes pendientes del backlog del spec:
- **Cashflow mensual**: ingresos vs gastos por mes (últimos N meses).
- **Saldo a fecha**: BO/DE/CR a una fecha pasada arbitraria.
- **Top movimientos**: los N gastos/ingresos más grandes del rango.

**Cuando**: sprints separados. Cada uno reusa `ReportsService` y la estructura de tabs.

### P-07: Bar chart con `fl_chart` si se decide chart visual rico

Hoy: barras horizontales simples con `Container`. Si se quiere agregar pie chart o donut chart, evaluar `fl_chart`.

**Cuando**: si Diego pide otro tipo de visualización (pie, donut, line). No hoy.

## No-pendientes

Items que el spec/plan listaban como riesgos pero NO se materializaron:

- **R-02 (query lenta sin índice)**: la query corre en <10ms con BD in-memory + datos sintéticos. No se observó degradación. Re-evaluar con journal real de 5000+ entries en el cel.
- **R-04 (división por cero al calcular percent)**: cubierto por el guard `total > 0 ? r.total / total : 0` + test UT-01.
- **R-05 (decimales monto)**: `bucket.total / report.total` ya devuelve `double` por construcción. Sin pérdida de precisión observada.
- **RT-02 (LEFT JOIN lento con journal grande)**: idem R-02, sin observación.
- **CB-extra-04 (locale es_MX)**: `initializeDateFormatting('es_MX')` ya cargado en `main.dart` y en el harness. `DateFormat('d MMM y', 'es_MX')` funciona correctamente.

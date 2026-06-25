# Pendientes — flutter-movements-filters-v1

## Pendientes del sprint (diferidos con justificación)

### P-01: Widget test del deep link `/entries?...` puro

**Estado**: diferido (Desviación-2).

**Razón técnica**: el árbol con `_ActiveFiltersBar` (2 StreamBuilders anidados de cuentas y categorías) + `StreamBuilder` principal del DAO + `SkeletonCard` durante el primer frame cuelga `pumpAndSettle` en tests cuando hay entries que satisfacen el filtro.

**Cobertura compensatoria**:
- `reports_deeplink_test.dart` cubre el flujo end-to-end equivalente.
- `entries_list_screen_test.dart` cubre el estado vacío con filtros activos via deep link (que no cuelga porque la lista está vacía).
- UTs del DAO y de `EntriesFilters` cubren toda la lógica.

**Cuando atacar**: cuando el problema sistémico de StreamBuilders anidados se resuelva (probablemente con un refactor de `_ActiveFiltersBar` para que no use stream watchers internos sino que reciba los datos ya hidratados del padre).

## Pendientes técnicos a futuro

### P-02: Paginación (`offset` + scroll infinito)

**Hoy**: `watchPage(limit: 200)` fijo. Funciona para journal < 500 entries.

**Mejora**: agregar `offset` al DAO + scroll infinito en la lista. Diseñado para que el cambio sea aditivo (la firma de `watchPage` ya acepta `offset` desde antes).

**Cuando**: cuando la lista degrade visiblemente. Diego ya anticipó esto en la conversación pre-spec.

### P-03: Filtros por monto (rango $X a $Y)

**Hoy**: no hay.

**Mejora**: agregar sección "Monto" en el panel con dos campos numéricos. DAO acepta `minAmount`/`maxAmount`. Sin refactor de la pantalla, solo extensión.

**Cuando**: si Diego pide la funcionalidad.

### P-04: Filtros por descripción (búsqueda textual)

**Hoy**: no hay.

**Mejora**: SQLite FTS5 sobre `journal_entries.description`. Schema bump + índice virtual + UI con TextField en el panel.

**Cuando**: futuro sprint dedicado.

### P-05: Guardar filtros como "vistas guardadas"

**Hoy**: filtros se pierden al navegar fuera de `/entries`.

**Mejora**: tabla `saved_views` + UI para nombrar/recordar combinaciones de filtros. Navegación rápida.

**Cuando**: si el uso recurrente de filtros idénticos se vuelve molesto.

### P-06: Multi-account

**Hoy**: filtro de cuenta es single-select.

**Mejora**: chips multi-select para cuenta, igual que categorías. DAO acepta `accountIds: List<String>?`.

**Cuando**: si surge necesidad.

### P-07: Exportar movimientos filtrados (CSV/PDF)

**Hoy**: no hay.

**Mejora**: botón en el AppBar del `/entries` que exporta el resultado del filtro actual a CSV. Sin filtros = todo el histórico.

**Cuando**: futuro sprint.

### P-08: Eliminar el parámetro `kind: String?` deprecado del DAO

**Hoy**: `watchPage(kind: String?, kinds: List<String>?, ...)` con `kind` deprecado.

**Cuando**: cuando ningún caller use `kind`. Hoy todos están migrados; en el próximo sprint que toque el DAO se puede eliminar la firma deprecada y dejar solo `kinds`.

### P-09: Refactor de `_ActiveFiltersBar` para no usar StreamBuilders internos

**Hoy**: el bar usa 2 streams adicionales (cuentas + categorías) para resolver los nombres de los chips activos. Esto causa el cuelgue del P-01.

**Mejora**: el padre `EntriesListScreen` ya tiene esos streams. Que pase las listas resueltas como argumento, no como streams.

**Cuando**: probablemente cuando se resuelva P-01 (juntos en un sprint corto).

## No-pendientes (cubiertos en este sprint)

- ✅ Performance del modal: resuelto al reemplazar bottom sheet + DropdownButtonFormField por panel full-screen con chips inline.
- ✅ Filtros de fecha: chips de presets reutilizando el helper del reporte.
- ✅ Filtros de categorías multi-select: implementado.
- ✅ Deep link desde reporte: implementado y testeado.
- ✅ Chips de filtros activos con "X": implementado.
- ✅ Badge numérico en AppBar: implementado.
- ✅ Estado vacío específico cuando hay filtros: implementado.

## Smoke manual pendiente (SM-01 a SM-09)

A ejecutar por Diego tras instalar el APK `0.5.0+47`:

- **SM-01**: Settings → "Acerca de" muestra `0.5.0+47`.
- **SM-02**: `/entries` por defecto muestra "Este mes". Sin badge ni chips activos (default thisMonth no cuenta).
- **SM-03**: Tap en icono `tune` abre el panel **rápido** (< 200ms subjetivo, sin lag).
- **SM-04**: En el panel, "Mes pasado" + "Gastos" + "Comida" + tap "Aplicar" → lista se filtra al instante.
- **SM-05**: Aparecen 3 chips arriba de la lista (Mes pasado, Gastos, Comida) + badge "3" en AppBar.
- **SM-06**: Tap en "X" del chip "Mes pasado" → el chip desaparece + badge baja a "2" + lista se actualiza al rango thisMonth.
- **SM-07**: En `/reports`, tap en un bucket de categoría → navega a `/entries` con filtros pre-cargados (fecha del reporte + Gastos + categoría del bucket).
- **SM-08**: En `/reports`, tap en bucket "Sin categoría" → `/entries` con `kinds=expense,credit_expense` + categoría "Sin categoría".
- **SM-09**: Tap "Limpiar todo" en el panel → vuelve a `Este mes` + todo en blanco. Aplicar → la lista vuelve al default.

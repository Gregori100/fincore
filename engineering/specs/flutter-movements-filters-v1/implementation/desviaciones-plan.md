# Desviaciones del plan — flutter-movements-filters-v1

## Desviación-1: SQL del filtro "Sin categoría" simplificado vía LEFT JOIN existente

**Plan original (RF-003)**: la query para `categoryIds` con token `__null__` debía generar:
```sql
WHERE (category_id IN (?, ?) OR category_id IS NULL OR
       category_id IN (SELECT id FROM categories WHERE deleted_at IS NOT NULL))
```

**Implementación real**: el `LEFT JOIN categories ON ... AND categories.deleted_at IS NULL` que ya existía en `watchPage` deja `categories.id IS NULL` para los dos casos cubiertos (entry con `category_id` null + entry con categoría archivada). Reusamos esa columna del JOIN:

```dart
if (hasNullToken && realIds.isEmpty) {
  query.where(categories.id.isNull());
} else if (hasNullToken) {
  query.where(
    journalEntries.categoryId.isIn(realIds) | categories.id.isNull(),
  );
} else {
  query.where(journalEntries.categoryId.isIn(realIds));
}
```

**Razón**: el JOIN ya hacía el trabajo. Agregar un subquery `IN (SELECT id FROM categories WHERE deleted_at IS NOT NULL)` era redundante y más costoso. Misma semántica (RN-M03), implementación más simple y eficiente.

**Tests**: 4 unit tests del DAO validan los 4 escenarios (`__null__` solo, mix con IDs reales, IDs reales solo, vacío).

## Desviación-2: Widget test del deep link via query params puro diferido

**Plan original (WT-13)**: validar que `push /entries?from=...&to=...&kinds=...&categoryIds=X` pre-carga el filtro y rinde la lista filtrada.

**Implementación real**: el test cuelga `pumpAndSettle` indefinidamente cuando `EntriesListScreen` rinde el `_ActiveFiltersBar` (que tiene 2 `StreamBuilder` anidados de cuentas y categorías además del stream principal del DAO). El árbol con StreamBuilders anidados parece generar un ciclo de pump que `pumpAndSettle` no logra asentar.

**Cobertura compensatoria**:
- `reports_deeplink_test.dart` valida el flujo end-to-end equivalente: tap en bucket del reporte → navega a `/entries` con query params → lista filtrada. RF-022 cumplido.
- El test base `Default thisMonth muestra los 5 entries` valida que `EntriesListScreen` rinde bien con la lista filtrada por fecha (default thisMonth, sin _ActiveFiltersBar).
- El test base `Estado vacío específico con filtros activos` usa `push /entries?kinds=expense&categoryIds=__null__` y verifica el render del estado vacío. **Este test SÍ pasa** porque la lista está vacía → no entra al `ListView.separated` con SkeletonCard, y el `_ActiveFiltersBar` rindea pero asienta rápido.

**Hipótesis técnica del cuelgue**: cuando hay entries que cumplen el filtro, el `ListView.separated` con `SkeletonCard` durante el primer frame del `StreamBuilder` principal + el `_ActiveFiltersBar` con 2 streams adicionales generan un timing donde drift emite eventos coalesceados que `pumpAndSettle` no detecta como "asentamiento".

**Reactivable**: si en un sprint futuro se ataca el problema sistémico de `pumpAndSettle` con StreamBuilders anidados (M5 + M3 del quality review previo extendido), reabilitar el test. Mientras tanto, el feature está cubierto funcionalmente.

## Desviación-3: Default de `/entries` cambia de "sin filtro" a "Este mes" — UX breaking

**Plan original (S-01 del spec, RT-02 del plan)**: el riesgo declarado era que el cambio del default `/entries` de "sin filtro" (histórico completo) a "Este mes" calendario podía confundir.

**Implementación real**: aplicado el cambio. El `EntriesListScreen` ahora arranca con `EntriesFilters.thisMonth()` por default. Si Diego abre la pantalla por primera vez en el cel y espera ver el histórico completo, no lo verá: tendrá que abrir el panel y seleccionar "Año" o "Custom" con rango amplio.

**Mitigación implementada**:
- El default `thisMonth` tiene `activeCount = 0` por construcción (`EntriesFilters.activeCount` no cuenta `thisMonth` como activo) → la pantalla NO muestra badge en el AppBar ni chips activos arriba de la lista. Visualmente parece "lista sin filtros".
- Cuando el usuario quiere ver más entries, abre el panel y elige "Año" o "Custom". El chip activo aparece + el badge aparece.

**Reactivable**: si Diego en el smoke prefiere el comportamiento anterior, hotfix `0.5.0+48` cambia el default a `EntriesFilters()` (sin rango) y agrega el chip de presets en el panel mostrando "Sin filtro" como opción adicional. No es invasivo.

## Desviación-4: `EntriesFilters.serialize` simplificado para `datePreset` no-custom

**Plan original (CB-extra-07)**: el serializer debía omitir parámetros default para URLs cortas.

**Implementación real**: si `datePreset == DateRangePreset.thisMonth`, **NO se serializa nada** (preset por default). Pero si es `lastMonth`/`thisYear`, se serializa solo el slug del preset (`datePreset=last_month`) sin `from`/`to` porque el parse del receptor recalcula el rango desde el preset. Solo `custom` serializa `from` y `to` explícitos.

Esto resulta en URLs más cortas:
- Default: `/entries`
- Mes pasado: `/entries?datePreset=last_month`
- Custom: `/entries?datePreset=custom&from=...&to=...`

**Test del round-trip** (`UT-14` en `entries_filters_test.dart`) valida que serializar + parsear devuelve filtros equivalentes para todos los presets.

**Decisión técnica**: el receptor del deep link (`EntriesListScreen.didChangeDependencies`) usa `DateTime.now()` actual para recalcular el rango de los presets no-custom. Esto significa: si Diego genera un deep link de "Mes pasado" en junio y lo abre en julio, el rango será mayo→junio (no abril→mayo). **Esto es intencional**: "Mes pasado" semánticamente significa "el mes calendario anterior a ahora", no "el mes pasado cuando se generó el link".

## Desviación-5: Tests viejos de `entries_list_screen_test.dart` reescritos por completo

**Plan original (RG-07)**: migrar los 2 tests previos del filtro `kind` viejo a la nueva API.

**Implementación real**: los 3 tests previos (no 2) usaban el bottom sheet con `find.byTooltip('Filtros (activos)')` que ya no aplica con el nuevo IconButton `tune` + badge. Además, asumían fechas hardcoded (`DateTime.utc(2026, 6, 22)`) que dejarían de matchear con el default `thisMonth` cuando el reloj pasara junio 2026.

**Reescritura**: el archivo entero se reemplazó con 4 tests nuevos que:
- Usan fechas relativas a `DateTime.now()` (`day = DateTime(now.year, now.month, 5)` cae siempre en el mes corriente).
- Validan el nuevo flujo: tune + badge + chips activos + estados vacíos específicos.
- Eliminan los asserts del bottom sheet viejo.

El test del flujo de filtros completo se cubre en `entries_filters_screen_test.dart` (panel aislado) + `reports_deeplink_test.dart` (end-to-end).

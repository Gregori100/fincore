# Resumen extenso — flutter-entries-list-refactor-v1

## Contexto

Sprint 2 del ciclo de **deuda técnica** post-pivote-local. Sigue al
`flutter-integration-tests-v1` (Sprint 1) que amplió cobertura del
`EntriesListScreen` con 7 integration tests nuevos (3 paginación + 2
filters panel + 2 settings + cobertura indirecta).

Disparador concreto: `mobile/lib/screens/entries_list_screen.dart` cargaba
**672 líneas** con 7 widgets privados embebidos, mezclando:

- Shell del Scaffold (AppBar + FAB).
- State de filtros + parsing de deep link.
- Subscripciones a accounts/categories (perf v1).
- State de paginación (`_currentLimit`, `_reachedEnd`, etc.) +
  ScrollController + listeners.
- Stream del DAO + StreamBuilder + reconciliación postFrameCallback.
- Lista + footer paginado + row de cada entry.
- Barra de filtros activos + chips removibles.
- Empty state con botón "Limpiar filtros".

Antes de cualquier feature nueva sobre `/entries` (filtros por monto,
búsqueda FTS5, vistas guardadas), refactorizar reduce el costo cognitivo
de cada cambio.

## Partición resultante

| Archivo | Líneas antes | Líneas después | Responsabilidad |
|---|---|---|---|
| `lib/screens/entries_list_screen.dart` | 672 | **170** | Shell: AppBar, FAB, state de filtros, subs accounts/categories, flow handlers (`_openFilters`, `_removeDimension`, `_clearAllFilters`). |
| `lib/widgets/entries_paginated_list.dart` | 0 | **340** | Stream + ScrollController + state de paginación + lista + footer + row + constantes (`_kPageSize`, `_kMaxLimit`, `_kScrollLoadMoreThreshold`). |
| `lib/widgets/entries_active_filters_bar.dart` | 0 | **155** | Bar horizontal + `_ActiveChip` + labels por dimensión (con fallback "(archivada)"). |
| `lib/widgets/entries_empty_state.dart` | 0 | **50** | Empty state con copy condicional + botón "Limpiar filtros". |

**Total**: 672 → 715 líneas distribuidas en 4 archivos (vs 1 mono-archivo).
El overhead de 43 líneas viene de imports + headers + docstrings extra.

## Decisión clave de diseño

**El state de paginación se mueve al `EntriesPaginatedList`** (no se queda
en el screen). Esto evita que el padre tenga que conocer la mecánica de
scroll/limit/loadMore. El contrato es:

- Props: `filters: EntriesFilters` + `onClearFilters: VoidCallback`.
- `didUpdateWidget` compara los filtros campo por campo (`from`, `to`,
  `datePreset`, `kinds`, `accountIds`, `categoryIds`). Si cambiaron,
  `_resetPagination()` + rebuild del stream.
- `didChangeDependencies` construye el stream inicial (necesita
  `AppDependencies.of(context)`).

`EntriesFilters` no tiene `==` custom (es inmutable pero usa la identidad
por default). Se evaluó agregárselo durante el refactor — desestimado por
ser ortogonal al objetivo. La comparación campo-a-campo en
`_filtersChanged` es 6 líneas, autocontenida.

## Validación

- `flutter analyze`: 0 errores, 4 hints `info` pre-existentes
  (cosméticos del entry_form_screen + skeleton).
- `flutter test`: **217/217 unit/widget verdes** (sin regresión).
- `flutter test integration_test/<each>.dart -d linux`:
  - `movements_pagination_test.dart`: **3/3 verdes** (16s).
  - `entries_filters_panel_test.dart`: **2/2 verdes** (16s).
  - `account_form_test.dart`: **5/5 verdes** (19s).
  - `category_form_test.dart`: **5/5 verdes** (20s).
  - `settings_destructive_test.dart`: **2/2 verdes** (16s).
  - Total: **17/17 integration verdes**.
- APK `0.6.4+56` construido + `verify-apk.sh` OK.

**Nota sobre el runner**: correr `flutter test integration_test/ -d linux`
(toda la suite) tira "Error waiting for a debug connection" tras 2-3
archivos seguidos. Causa probable: log reader de Flutter acumula state
entre runs sucesivos. Workaround: correr archivos individualmente. Es un
issue del runner, NO del código.

## Riesgos residuales

- **RR-01** (bajo): `didChangeDependencies` corre múltiples veces durante
  el ciclo de vida del widget — el guard `_stream ??= _buildStream()`
  garantiza que solo el primer pass construye. Si en el futuro hace falta
  rebuild forzado, podemos exponer un `key` o usar `didUpdateWidget`.
- **RR-02** (bajo): el `_filtersChanged` compara listas por posición.
  Si en algún momento se cambia el orden interno de `_filters.kinds` sin
  intención semántica, el widget va a resetear paginación innecesariamente.
  Hoy `EntriesFilters` mantiene orden estable via `List.unmodifiable`.
- **RR-03** (nulo): el integration test `FP-02` con BBVA filtrado +
  GastoBolsa fuera **falló inicialmente** durante el refactor por un bug
  en el `didUpdateWidget` (cuando se pasó la primera versión con stream
  reconstruido en cada rebuild). Fix: construir el stream sólo en
  `didChangeDependencies` o tras detectar cambio de filtros. Confirmado
  con tests verdes.

## Próximos sprints habilitados

Con el refactor en su lugar, son baratos:

- **Filtros por monto** en `/entries`: agregar campos al panel + al
  modelo + al DAO. Sin tocar la paginación.
- **Búsqueda FTS5**: agregar field de búsqueda en el AppBar del screen y
  pasar el texto al `EntriesPaginatedList` como prop extra del filter.
- **Vistas guardadas**: state nuevo en el screen, panel para
  cargar/guardar. La paginación no se entera.

## Compatibilidad

Cero cambios de comportamiento observable. Los widgets nuevos exponen el
mismo render que los privados originales con los mismos parámetros (chips
con label igual, footer con copy igual, empty state con copy igual).

## Archivos productivos tocados

```
mobile/lib/screens/entries_list_screen.dart           (rewrite)
mobile/lib/widgets/entries_paginated_list.dart        (new)
mobile/lib/widgets/entries_active_filters_bar.dart    (new)
mobile/lib/widgets/entries_empty_state.dart           (new)
mobile/pubspec.yaml                                    (bump)
mobile/android/app/build.gradle.kts                    (bump)
```

Tests: ninguno modificado, ninguno agregado.

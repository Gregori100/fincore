# Plan técnico — flutter-movements-pagination-v1

## Enfoque técnico

Sprint chico. División en 6 fases:

- **F0 — Limpieza pre-sprint (ya aplicada)**: `EntriesDao.watchPage` ya no acepta los singulares `kind: String?` ni `accountId: String?`. Test de compatibilidad eliminado. Suite en 214 verdes. Esta fase está hecha; solo se valida en el plan.
- **F1 — State + ScrollController**: agregar `_currentLimit`, `_reachedEnd`, `_loadingMore`, `_scrollController` al state de `EntriesListScreen`. Wirearlos al `ListView.separated`. Dispose correcto.
- **F2 — Lógica de paginación**: `_loadMore`, `_resetPagination`, detección de fin via `WidgetsBinding.addPostFrameCallback`. Hook a los puntos donde el filtro cambia (`_openFilters` con resultado, `_removeDimension`, `_clearAllFilters`).
- **F3 — UI del footer**: nuevo `_PaginationFooter` con 2 estados (loading / end). Eliminar el viejo `_TruncatedFooter` y la constante `_kEntriesLimit = 200`.
- **F4 — Tests data**: 3 tests nuevos del DAO con `offset`/`limit` distintos. Validar Dashboard sigue funcionando con `watchPage(limit: 10)`.
- **F5 — Release**: bump `0.6.0+52`, build APK, verify.

Toda la complejidad es UI-only. El DAO ya soporta `offset` + `limit` desde el v1.

El enfoque de paginación es **acumulativo con offset=0**: el `_currentLimit` crece (100 → 200 → 300...) y el Stream del DAO se rearma con el nuevo limit. Drift emite la lista completa actualizada. Esto:
- Mantiene reactividad gratis (cualquier cambio en `journal_entries` re-emite la lista correcta).
- Evita riesgo de duplicados o entries faltantes cuando alguien agrega/borra mientras paginás.
- Memoria controlada porque Diego raramente pasa de 5-10 páginas en uso típico (S-01).

## Requisitos funcionales cubiertos

- **RF-001 a RF-006** (state + ScrollController + paginación): F1 + F2.
- **RF-007** (detección de fin via postFrameCallback): F2.
- **RF-008 a RF-010** (UI del footer + cleanup): F3.
- **RF-011** (uso de `_currentLimit` en `_buildStream`): F1.
- **RF-012** (attach del ScrollController): F1.
- **RF-013** (tests data): F4.
- **RF-014** (release): F5.

## Archivos o módulos probablemente afectados

Nuevos: ninguno.

Modificados:

- `mobile/lib/screens/entries_list_screen.dart`: state + paginación + `_PaginationFooter`. Eliminación del `_TruncatedFooter` viejo y `_kEntriesLimit = 200`. ~80 líneas netas (suma + resta).
- `mobile/test/data/entries_dao_filters_test.dart`: +3 tests de offset/limit.
- `mobile/pubspec.yaml`: bump versión.
- `mobile/android/app/build.gradle.kts`: bump versionCode + versionName.

Probablemente no afectados (validar):

- `mobile/lib/data/daos/entries_dao.dart`: F0 ya lo limpió. Sin cambios adicionales.
- `mobile/lib/screens/dashboard_screen.dart`: usa `watchPage(limit: 10)` sin paginación. Validar que no rompe.
- `mobile/lib/data/entries_filters.dart`: sin cambios.
- `mobile/lib/screens/entries_filters_screen.dart`: sin cambios.
- `mobile/lib/screens/reports/spending_by_category_tab.dart`: sin cambios.

## Entidades y estados afectados

Sin cambios en entidades de dominio ni schema.

Nuevos campos de presentación en `_EntriesListScreenState`:

- `int _currentLimit = 100` (state mutable, default 100).
- `bool _reachedEnd = false` (latch que se activa al detectar fin del rango).
- `bool _loadingMore = false` (gate para evitar trigger duplicado).
- `ScrollController _scrollController = ScrollController()` (con dispose en `dispose()`).

Invariantes:

- `_currentLimit` siempre múltiplo de 100, mínimo 100.
- Si `_reachedEnd == true`, ningún `_loadMore` se dispara.
- `_loadingMore == true` solo entre `_loadMore()` y el siguiente emit del Stream.
- Reset de filtros (cambio en `_filters`) implica reset de los 3 flags + nuevo Stream.

Transiciones:

- Default → `_currentLimit = 100, _reachedEnd = false, _loadingMore = false`.
- Scroll trigger → `_currentLimit += 100, _loadingMore = true`.
- Stream emit con `entries.length < _currentLimit` → `_reachedEnd = true, _loadingMore = false`.
- Stream emit con `entries.length >= _currentLimit` y `_loadingMore == true` → `_loadingMore = false` (sigue habiendo más).
- Cambio de filtro → reset a default.

## Compatibilidad con datos y procesos existentes

- **Backup JSON v1**: sin cambios.
- **Datos históricos**: el `watchPage` con limit creciente sigue rindiendo sobre journal histórico igual. Sin migraciones.
- **Dashboard**: sigue usando `watchPage(limit: 10)` sin paginación. No afectado.
- **`/reports`**: usa `ReportsService.spendingByCategory` con su propio Stream agregado. Sin relación con paginación de entries.
- **`MigrationStrategy`**: no se toca. `schemaVersion = 2` queda igual.
- **Tests existentes de `EntriesListScreen`**: 4 tests previos. El footer cambia, así que los asserts del `_TruncatedFooter` (si los hay) o del `_EmptyState` con filtros deberían revisarse.

## Cambios de datos

No aplica. Sin schema bump, sin migraciones.

## Cambios de API

No aplica. App local-first.

## Cambios de integraciones

- `customSelect.watch()` de drift: ya en uso, sin cambios. El comportamiento de cancelar el upstream cuando se reemplaza la referencia del Stream se valida en F2.

## Cambios de UI

- **EntriesListScreen**:
  - `ListView.separated` recibe `controller: _scrollController`.
  - `itemCount` suma 1 cuando `_loadingMore || _reachedEnd`.
  - `itemBuilder` retorna `_PaginationFooter` para el último índice si aplica.
- **`_PaginationFooter`** (nuevo widget privado):
  - Si `loadingMore`: `Padding(vertical: 16, child: Center(child: Text('Cargando…', sutil)))`.
  - Si `reachedEnd`: `Padding(vertical: 16, child: Center(child: Text('Fin de los movimientos del rango.', sutil)))`.
- **`_TruncatedFooter`** y `_kEntriesLimit = 200`: eliminados.
- **`_EmptyState`**: sin cambios.
- Theme: sin cambios.

## Cambios de permisos

No aplica.

## Riesgos técnicos

- **RT-01**: `_currentLimit` crece sin tope. Tras 50 paginaciones, query carga 5000 entries en memoria. Mitigación: documentado como S-01 + RT-01 del spec. Si Diego nota lag, sprint dedicado de paginación con offset real (2 streams + merge).
- **RT-02**: scroll listener puede dispararse mid-frame y trigger `_loadMore` varias veces. Mitigación: `_loadingMore` y `_reachedEnd` guards en el listener.
- **RT-03**: `setState` desde `WidgetsBinding.addPostFrameCallback` lanza si el widget se desmontó entre tanto. Mitigación: `if (!mounted) return;` dentro del callback.
- **RT-04**: el `ScrollController.dispose()` debe llamarse antes de `super.dispose()`. Sin esto, leak.
- **RT-05**: el reemplazo del Stream cuando `_currentLimit` cambia puede generar un flash si la nueva emisión tarda. Mitigación: el `StreamBuilder` mantiene `snap.data` viejo hasta el nuevo emit (comportamiento por default de Flutter).
- **RT-06**: tests del `entries_list_screen_test.dart` previos pueden romperse por el cambio de footer y el ScrollController. Mitigación: actualizar los 4 tests existentes según necesite.
- **RT-07**: cuelgue de `pumpAndSettle` en widget tests del scroll (sistémico desde sprints anteriores). Mitigación: solo data tests; widget tests del scroll quedan diferidos.
- **RT-08**: si el `Dashboard` o el `BackupService` invocan `watchPage(kind: ...)` o `watchPage(accountId: ...)` que ya fueron eliminados, el compilador lanzaría. F0 ya validó esto (suite verde tras eliminación).

## Estrategia de pruebas

Tests data en F4 (gate antes de release). Widget tests del scroll infinito **diferidos** por el cuelgue sistémico de `pumpAndSettle` con ScrollController + StreamBuilder.

- **Tests unitarios del DAO**: 3 tests cubriendo `limit < total`, `limit > total`, `offset + limit` distintos. Smoke de que la firma sin deprecados sigue funcionando.
- **Tests previos del DAO**: 30+ tests existentes deben seguir verdes. F0 ya confirmó.
- **Tests del `EntriesListScreen`**: los 4 actuales validan default thisMonth, AppBar tune, estados vacíos. El footer cambió pero el assert principal no toca el footer directo. Revisar y ajustar lo mínimo.
- **Smoke manual** del scroll infinito en el Redmi con journal real (Diego registra suficientes entries para que se vea la transición de páginas).

`flutter analyze` debe quedar en 0 errores / 0 warnings.

## Estrategia de rollback

El sprint es aditivo en UI, breaking en DAO (eliminación de deprecated).

- **Opción A — revert completo**: `git revert <hash>` del commit del sprint. La eliminación de deprecated se revierte también. Sin pérdida de datos.
- **Opción B — patch parcial**: si solo falla el scroll infinito, hotfix `0.6.0+53` vuelve a `_currentLimit = 200` fijo + restaurar `_TruncatedFooter`. La limpieza de deprecated queda aplicada.
- **APK ya instalado**: el usuario puede reinstalar el `0.5.4+51` previo si guardó el APK; los datos sobreviven (sin schema bump).

## Orden sugerido de implementación

1. **F0 — Validar limpieza pre-sprint**:
   1.1. `grep -rn "watchPage(kind:\|watchPage(accountId:" mobile/` → 0 matches confirmado.
   1.2. `flutter test` → 214 verdes confirmado.
2. **F1 — State + ScrollController**:
   2.1. Agregar `_currentLimit`, `_reachedEnd`, `_loadingMore`, `_scrollController` al `_EntriesListScreenState`.
   2.2. `_scrollController.addListener(_onScroll)` en `initState`.
   2.3. `_scrollController.dispose()` antes de `super.dispose()`.
   2.4. Modificar `_buildStream` para usar `_currentLimit`.
   2.5. Pasar `controller: _scrollController` al `ListView.separated`.
3. **F2 — Lógica de paginación**:
   3.1. Implementar `_onScroll()`: si `position.pixels >= maxScrollExtent - 300 && !_reachedEnd && !_loadingMore`, llamar `_loadMore()`.
   3.2. Implementar `_loadMore()`: `setState(() { _currentLimit += 100; _loadingMore = true; _buildStream(); })`.
   3.3. Implementar `_resetPagination()`: `_currentLimit = 100; _reachedEnd = false; _loadingMore = false;`. Llamarla desde `_openFilters` (cuando hay resultado), `_removeDimension`, `_clearAllFilters`.
   3.4. Implementar detección de fin: en el `builder` del `StreamBuilder`, si `entries.length < _currentLimit && !_reachedEnd`, agendar `setState` post-frame para activar `_reachedEnd`. Si `entries.length >= _currentLimit && _loadingMore`, agendar `setState` post-frame para desactivar `_loadingMore`.
   3.5. Validación con `flutter run -d linux`.
4. **F3 — UI del footer**:
   4.1. Crear `_PaginationFooter` privado con 2 estados.
   4.2. Modificar `_EntriesList` para sumar 1 al `itemCount` si `loadingMore || reachedEnd`, y retornar `_PaginationFooter` en el último índice.
   4.3. Eliminar `_TruncatedFooter` y `_kEntriesLimit = 200`.
   4.4. Iteración visual con `flutter run -d linux`.
5. **F4 — Tests data**:
   5.1. Agregar 3 tests al `entries_dao_filters_test.dart` cubriendo offset/limit.
   5.2. Correr `flutter test` → debe quedar en 217+ verdes.
   5.3. Revisar y actualizar los 4 tests previos de `entries_list_screen_test.dart` si rompen.
6. **F5 — Release**:
   6.1. Bump `pubspec.yaml` a `0.6.0+52`.
   6.2. Bump `android/app/build.gradle.kts` a `versionCode=52, versionName="0.6.0"`.
   6.3. `flutter analyze` limpio.
   6.4. `flutter build apk --release --split-per-abi`.
   6.5. `scripts/verify-apk.sh` → exit 0 con versionCode 2052.
7. **Validación de calidad** (opcional para sprint chico): invocar `/branch-quality-review flutter-movements-pagination-v1` si Diego lo pide. Para sprints chicos puede omitirse y revisar el diff manualmente.
8. **Commit + push**: Diego ejecuta el push manual.

## Casos borde que condicionan la solución

Más allá de los CB-01 a CB-10 del spec:

- **CB-extra-01**: el `ScrollController` se attach al `ListView` que está dentro de un `StreamBuilder`. Cuando el StreamBuilder rebuild (cada emit), el ListView se reconstruye. ¿El `controller` se mantiene? Sí, porque el `_scrollController` está en el state padre y se pasa como prop. La identidad referencial se mantiene.
- **CB-extra-02**: el `WidgetsBinding.addPostFrameCallback` se invoca DESDE el builder del StreamBuilder. Si el callback dispara setState mid-build, puede haber assertion. Mitigación: postFrameCallback se ejecuta DESPUÉS del build actual, no en él. Seguro.
- **CB-extra-03**: el `_resetPagination` se llama ANTES de `_buildStream` para que el nuevo Stream se arme con `_currentLimit = 100`. Si se invoca en orden inverso, el Stream queda con el limit viejo.
- **CB-extra-04**: tests del `entries_list_screen` que validan footer "Mostrando los 200 más recientes" rompen. Los actualizamos o eliminamos.
- **CB-extra-05**: el `_loadMore` invoca `_buildStream` que reasigna `_stream`. Pero el `StreamBuilder` actual está suscrito al stream viejo. Al rebuild con el nuevo `_stream`, el StreamBuilder cancela el listener viejo y se suscribe al nuevo. Drift cancela la suscripción upstream. OK.

## Preguntas o supuestos que siguen afectando la implementación

Sin preguntas bloqueantes abiertas. Los supuestos S-01 a S-07 del spec se respetan.

Decisiones técnicas tomadas durante el plan:

- **DT-P-01**: `_PaginationFooter` es widget privado de `entries_list_screen.dart`. No se extrae a `lib/widgets/` porque es muy específico de este flujo.
- **DT-P-02**: el `_scrollController` se instancia inline en el field (`= ScrollController()`), no en initState. Equivalente y más conciso.
- **DT-P-03**: `_resetPagination` es void; no devuelve un nuevo `EntriesFilters`. Solo muta state local.
- **DT-P-04**: el threshold de scroll trigger es 300px del final. Si Diego siente que carga tarde/temprano, ajustable.
- **DT-P-05**: el footer de fin dice "Fin de los movimientos del rango." (con punto final). Texto definido.
- **DT-P-06**: el footer de loading dice "Cargando…" (con tres puntos suspensivos en un solo carácter `…`). Sin animación.
- **DT-P-07**: el cleanup del `_TruncatedFooter` y `_kEntriesLimit = 200` se hace en F3 junto con el footer nuevo, no en F1.

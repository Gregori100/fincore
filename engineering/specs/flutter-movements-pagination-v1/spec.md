# flutter-movements-pagination-v1 — Scroll infinito en /entries

## Resumen

Reemplazar el `limit: 200` fijo de `EntriesListScreen` por un modelo de paginación con **scroll infinito**: la lista arranca cargando 100 entries y carga 100 más automáticamente cuando el usuario se acerca al final del scroll. Cuando se llega al último entry del rango filtrado, footer informativo "Fin de los movimientos". Sin cambios al DAO (ya acepta `offset` + `limit`); sin schema bump.

Aprovecha el sprint para hacer **limpieza de deprecated**: `EntriesDao.watchPage` ya no acepta los singulares `kind: String?` ni `accountId: String?` (P-08 del sprint `flutter-movements-filters-v1`, aplicado pre-sprint).

## Problema a resolver

Tras el sprint `flutter-movements-filters-v1`, `/entries` carga hasta 200 entries con un `_TruncatedFooter` que dice *"Mostrando los 200 más recientes. Ajustá filtros para acotar."*. Esto es UX debt:

- Si Diego abre el reporte de un año completo o no aplica filtros de fecha, **silenciosamente se ven solo 200 de N**.
- El footer es informativo pero no accionable: tener que ajustar filtros para ver más entries históricos es fricción.
- Diego ya anticipó esto en `flutter-movements-filters-v1`: *"en algún punto se ocupará paginación para que no se trabe"*. El feature creció a un volumen donde vale invertir.

Adicionalmente quedan 2 deprecated del DAO (`kind: String?` y `accountId: String?`) sin callers vivos; conservarlos es deuda permanente.

## Objetivo

Que Diego pueda **scrollear sin tope** en la lista de movimientos del rango filtrado, con carga automática transparente. Cuando llega al fin, ver feedback claro de que no hay más entries en el rango actual.

Eliminar los 2 parámetros deprecated del DAO.

## Alcance

- **DAO**: `EntriesDao.watchPage` ya soporta `offset` y `limit`. Eliminación de los singulares `kind`/`accountId` deprecados.
- **`EntriesListScreen`**:
  - State nuevo: `_currentLimit: int` (default 100) y `_reachedEnd: bool` (default false).
  - `ScrollController` adjunto al `ListView.separated`. Listener: si `pixels >= maxScrollExtent - 300` y `!_reachedEnd && !_loadingMore`, dispara `_loadMore`.
  - `_loadMore` aumenta `_currentLimit += 100` y reconstruye el Stream del DAO con el nuevo limit. Marca `_loadingMore = true` hasta que llegue el siguiente snapshot del Stream.
  - Detección de fin: cuando `entries.length < _currentLimit` tras un emit del Stream, marcar `_reachedEnd = true` y `_loadingMore = false`.
  - Reset al cambiar filtros (panel "Aplicar" o tap "X" de chip activo): `_currentLimit = 100, _reachedEnd = false, _loadingMore = false`.
- **UI**:
  - Eliminación del `_TruncatedFooter` ("Mostrando los 200 más recientes...") — reemplazado por footer condicional.
  - Footer condicional como último item del ListView:
    - `_loadingMore == true` → indicador estático ("Cargando…" centrado, sin animación).
    - `_reachedEnd == true && entries.isNotEmpty` → "Fin de los movimientos del rango."
    - Otro caso → nada (no agregar item extra).
- **Sin cambios** en `EntriesFilters`, en el panel de filtros, en el reporte ni en el Dashboard.
- Tests data del DAO con `offset` cubriendo el flujo de paginación.
- Release `0.6.0+52` (minor por cambio de UX significativo + breaking en DAO).

## Fuera de alcance

- **Botón "Cargar más" explícito**: Diego eligió scroll infinito. Sin botón manual.
- **Paginación reverse** (cargar entries más viejos hacia abajo): el orden sigue siendo `occurred_at DESC` desde la primera página.
- **Estado "página actual" persistido**: si Diego cambia de pantalla y vuelve, la paginación se resetea a 100. No mantenemos posición de scroll.
- **Indicador "página X de Y"**: el scroll infinito no expone páginas discretas al usuario.
- **Paginación reactiva con offset cambiante**: aprovechamos que `customSelect.watch()` con un limit creciente y `offset = 0` fijo es reactivo gratis. No usamos `offset > 0` en el caller productivo.
- **Performance audit con journal de 50k+ entries**: documentado como riesgo pero no validado en este sprint.
- **Mejora del `setState` en perf v1**: el patrón de StreamSubscription se mantiene tal cual.
- **Reactivar tests diferidos** del sprint anterior (M3/M10/M13): se mantienen diferidos.
- **Cambios en `/reports`** o cualquier otra pantalla.

## Reglas de negocio

- **RN-P01**: paginación es UI-only. El DAO sigue exponiendo `offset` y `limit`, pero el caller productivo siempre usa `offset: 0` con `limit` creciente.
- **RN-P02**: cargar más NO duplica entries. Como `offset` siempre es 0 y `limit` solo crece, el Stream re-emite la lista completa actualizada con cada cambio.
- **RN-P03**: cambio de filtro (`_filters` reasignado) resetea el estado de paginación a `_currentLimit = 100, _reachedEnd = false, _loadingMore = false`.
- **RN-P04**: si un entry nuevo se agrega/modifica/elimina desde otra pantalla mientras `/entries` está abierta, el Stream re-emite la lista actualizada al `_currentLimit` actual. El entry nuevo puede entrar o salir según matchee los filtros y el rango del limit.
- **RN-P05**: el scroll listener trigger `_loadMore` solo cuando `!_reachedEnd && !_loadingMore`. Re-trigger se ignora durante la carga.
- **RN-P06**: detección de fin: si el Stream emite `entries.length < _currentLimit`, significa que el rango filtrado tiene menos entries que el limit pedido → `_reachedEnd = true`.
- **RN-P07**: el orden sigue siendo `occurred_at DESC, created_at DESC` (sin cambio respecto al DAO actual).
- **RN-P08**: la lista visible es exactamente lo que emite el Stream. No mantenemos cache local de entries.

## Requisitos funcionales

- **RF-001**: extraer la constante `_kEntriesLimit = 200` y reemplazar por estado mutable `_currentLimit: int = 100` en `_EntriesListScreenState`.
- **RF-002**: agregar campos al state: `bool _reachedEnd = false`, `bool _loadingMore = false`, `ScrollController _scrollController = ScrollController()`.
- **RF-003**: instalar listener en `_scrollController` en `initState` que invoque `_loadMore()` cuando `_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300` y `!_reachedEnd && !_loadingMore`.
- **RF-004**: liberar `_scrollController.dispose()` en `dispose()`.
- **RF-005**: implementar `_loadMore()`: `setState(() { _currentLimit += 100; _loadingMore = true; _buildStream(); })`.
- **RF-006**: implementar `_resetPagination()`: `_currentLimit = 100; _reachedEnd = false; _loadingMore = false;`. Invocar como prefijo de `_buildStream()` cada vez que el filtro cambia (`_openFilters` con `result != null`, `_removeDimension`, `_clearAllFilters`).
- **RF-007**: en el `StreamBuilder` de `EntriesListScreen`, cuando snap recibe `entries`, dentro del builder hacer:
  ```dart
  if (entries.length < _currentLimit && !_reachedEnd) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _reachedEnd = true;
        _loadingMore = false;
      });
    });
  } else if (entries.length >= _currentLimit && _loadingMore) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    });
  }
  ```
- **RF-008**: `_EntriesList` (widget existente) cambia a recibir `entries`, `loadingMore`, `reachedEnd` como props. El `itemCount` suma 1 cuando hay footer condicional (loading o fin). El `itemBuilder` retorna `_PaginationFooter` para ese índice.
- **RF-009**: `_PaginationFooter`:
  - Si `loadingMore == true` → `Padding(vertical: 16, child: Center(child: Text('Cargando…')))`. Sin animación.
  - Si `reachedEnd == true` → `Padding(vertical: 16, child: Center(child: Text('Fin de los movimientos del rango.', color: textSubtle, fontSize: 12)))`.
  - No deben mostrarse ambos a la vez (mutuamente excluyentes).
- **RF-010**: eliminar `_TruncatedFooter` y la constante `_kEntriesLimit = 200`.
- **RF-011**: `_buildStream` usa `_currentLimit` en lugar de la constante:
  ```dart
  _stream = deps.entriesDao.watchPage(
    kinds: _filters.kinds.isEmpty ? null : _filters.kinds,
    accountIds: _filters.accountIds.isEmpty ? null : _filters.accountIds,
    categoryIds: _filters.categoryIds.isEmpty ? null : _filters.categoryIds,
    from: _filters.from,
    to: _filters.to,
    limit: _currentLimit,
  );
  ```
- **RF-012**: el `attach` del `_scrollController` al `ListView.separated` se hace via parámetro `controller:` del ListView.
- **RF-013**: nuevos tests data del DAO con `offset` y `limit` distintos cubriendo:
  - `watchPage(limit: 100)` con 150 entries → 100 entries.
  - `watchPage(limit: 200)` con 150 entries → 150 entries.
  - `watchPage(offset: 0, limit: 100)` y `watchPage(offset: 100, limit: 100)` retornan páginas distintas.
- **RF-014**: bump versión a `0.6.0+52`. Build APK + verify-apk.sh.

## Casos principales

- **C-01**: Diego abre `/entries` con 350 entries del mes → ve los primeros 100. Scroll al final → cargan 100 más (200). Sigue scrolleando → cargan 100 más (300). Sigue → cargan 50 más (350) y el footer dice "Fin de los movimientos del rango".
- **C-02**: Diego abre `/entries` con 50 entries del mes → ve los 50, footer dice "Fin de los movimientos del rango" desde el primer render.
- **C-03**: Diego scrollea al final mientras está cargando → el listener trigger se ignora (`_loadingMore == true`).
- **C-04**: Diego cambia un filtro estando en la página 3 (300 entries) → la lista se resetea a 100 entries del nuevo filtro. `_reachedEnd` y `_loadingMore` vuelven a false.
- **C-05**: Diego registra un entry nuevo desde `/entries/new` → al volver, el Stream re-emite con `_currentLimit` actual (100 si no scrolleó, +X si scrolleó) incluyendo el entry nuevo si matchea filtros + rango.
- **C-06**: Diego abre `/entries` desde un deep link del reporte (filtros pre-cargados) → ve los primeros 100 entries que matchean. Si hay menos de 100, footer "Fin" desde el primer render.

## Casos borde

- **CB-01**: BD vacía → 0 entries → `entries.length < _currentLimit` desde el primer emit → `_reachedEnd = true`. El `_EmptyState` ya cubre (sin filtros: "No hay movimientos"; con filtros: "Probá ajustarlos"). Sin footer extra.
- **CB-02**: filtro con 0 resultados pero con entries en la BD → mismo que CB-01.
- **CB-03**: filtro que matchea exactamente 100 entries → `entries.length == _currentLimit (100)`. NO marcamos `_reachedEnd` todavía (puede haber 1+ más). Si Diego scrollea, `_loadMore` aumenta a 200, el Stream re-emite con 100 entries (no hay más) → ahora `entries.length < _currentLimit` → `_reachedEnd = true`.
- **CB-04**: scroll muy rápido a través de 5 páginas en 1 segundo → el listener trigger una sola vez (gate por `_loadingMore`). Cuando termina la primera carga, si Diego sigue en el fondo, se dispara la siguiente.
- **CB-05**: `_currentLimit` muy grande (ej. 5000 tras 50 paginaciones) → el Stream sigue funcionando pero la query carga 5000 entries. Documentado como riesgo (RT-01).
- **CB-06**: Diego cambia de filtro mid-carga (`_loadingMore == true`) → `_resetPagination` resetea todo + nuevo Stream. La emisión vieja se descarta (StreamBuilder cancela el listener al cambiar `_stream`).
- **CB-07**: Diego archiva una categoría desde otra pantalla mientras tiene esa categoría como filtro activo → Stream re-emite con menos entries (la categoría ya no matchea). Si `entries.length < _currentLimit`, `_reachedEnd = true` se setea.
- **CB-08**: Diego importa un respaldo JSON mientras `/entries` está abierta → BD se reemplaza totalmente, Stream re-emite con la lista nueva al `_currentLimit` actual. El estado de paginación NO se resetea automáticamente (UX rara pero coherente). Aceptable: caso raro.
- **CB-09**: `ScrollController` adjunto pero el ListView nunca llega a estar scrolleable (lista vacía o muy corta) → el listener no se dispara. Sin bug.
- **CB-10**: rotación de pantalla / cambio de tamaño → el `ScrollController` mantiene posición. Sin reset.

## Criterios de aceptación

- **CA-01**: al abrir `/entries` el `_currentLimit` arranca en 100. Si hay ≥100 entries en el rango, se ven los primeros 100.
- **CA-02**: scroll a 300px del final → `_loadMore` se invoca → `_currentLimit = 200`. Stream re-emite con los siguientes 100 (acumulado 200).
- **CA-03**: cuando `entries.length < _currentLimit`, footer dice "Fin de los movimientos del rango." y el scroll listener queda dormido.
- **CA-04**: cambio de filtro (cualquier vía: panel o tap "X" de chip activo) resetea `_currentLimit` a 100 y desactiva `_reachedEnd`/`_loadingMore`.
- **CA-05**: el footer viejo "Mostrando los 200 más recientes" ya no aparece (eliminado).
- **CA-06**: `EntriesDao.watchPage` ya no acepta los parámetros `kind: String?` ni `accountId: String?`.
- **CA-07**: `flutter test` queda verde (214 + tests nuevos).
- **CA-08**: `flutter analyze` queda en 0 errores, 0 warnings.
- **CA-09**: `scripts/verify-apk.sh` exit 0 con `versionCode=2052`.

## Criterios medibles de éxito

- **CME-01**: cobertura nueva: ≥3 tests data del DAO con `offset`/`limit` distintos.
- **CME-02**: suite total post-sprint ≥ 217 tests verdes (214 actual + 3 nuevos mínimo).
- **CME-03**: tiempo de carga inicial del primer `_currentLimit = 100` con 1000 entries en BD ≤ 200ms en debug build (Stopwatch ad-hoc, no test recurrente).
- **CME-04**: Diego confirma en smoke que el scroll es fluido y la auto-carga no se siente con lag al final del scroll.
- **CME-05**: Diego ya no ve el footer "Mostrando los 200 más recientes" en ningún caso.

## Riesgos

- **RT-01**: con `_currentLimit` creciente sin tope, después de muchas páginas (ej. 50 = 5000 entries) la query carga toda la lista en memoria. Mitigación: documentado como S-01. Si Diego nota lag, sprint dedicado de offset real (2 streams concurrentes con merge) — fuera de scope.
- **RT-02**: scroll trigger puede dispararse múltiples veces durante un scroll rápido. Mitigación: `_loadingMore` guard + `_reachedEnd` guard.
- **RT-03**: el cuelgue de `pumpAndSettle` de los sprints anteriores puede afectar widget tests del scroll infinito (no se prueban con widget test, solo data tests + smoke manual).
- **RT-04**: el `ScrollController.dispose()` debe llamarse en el `dispose()` del state. Sin esto, leak.
- **RT-05**: si el `WidgetsBinding.instance.addPostFrameCallback` se invoca después de `dispose()` (muy rara race), el `setState` lanza. Mitigación: `if (!mounted) return;` dentro del callback.
- **RT-06**: el reemplazo del Stream en `_buildStream` cuando cambia `_currentLimit` puede generar un flash visual si la nueva lista emite tarde. Mitigación: `_loadingMore = true` mantiene la lista vieja hasta el nuevo emit.
- **RT-07**: tests de `entries_list_screen_test.dart` previos pueden romperse por el cambio de footer. Mitigación: validar y actualizar.

## Supuestos

- **S-01**: Diego rara vez scrollea más de 5-10 páginas (500-1000 entries). Si el caso se vuelve común, sprint de optimización.
- **S-02**: el `customSelect.watch()` reactivo de drift maneja sin issues un Stream que se reemplaza cada cambio de limit. Si surge bug de cancelación, fix puntual.
- **S-03**: el scroll trigger a 300px del final es razonable. Si Diego nota que carga muy tarde o muy temprano, ajustable.
- **S-04**: el footer es un único `_PaginationFooter` con 2 estados (loading/end), no dos widgets distintos. Si en el futuro suma "error" como tercer estado, refactor menor.
- **S-05**: la paginación se resetea al cambiar filtros sin preservar `_currentLimit`. Si Diego quería ver entries más viejos del nuevo filtro, scrollea de nuevo. Aceptable.
- **S-06**: el `Dashboard` sigue usando `watchPage(limit: 10)` sin paginación. La sección "Últimos movimientos" solo necesita 10. Sin cambios.
- **S-07**: la limpieza de deprecated (`kind` y `accountId`) se hace en el mismo sprint porque tocamos `entries_dao.dart`. Cambio aditivo + 1 test eliminado.

## Impacto esperado

- **Producto**: Diego puede ver TODO el histórico de movimientos sin necesidad de ajustar filtros. El footer "Mostrando los 200 más recientes" desaparece — UX más limpia y predecible. Scroll infinito es patrón conocido y esperado.
- **Código**:
  - Modificado: `mobile/lib/screens/entries_list_screen.dart` (~50 líneas: state + ScrollController + _loadMore + _resetPagination + _PaginationFooter).
  - Modificado: `mobile/lib/data/daos/entries_dao.dart` (eliminación de los 2 deprecados, ~6 líneas).
  - Modificado: `mobile/test/data/entries_dao_filters_test.dart` (eliminación del test de compatibilidad + 3 tests nuevos de offset/limit).
  - Bump versión + verify APK.
- **Compatibilidad**: cambio breaking en el DAO (eliminación de deprecated). Ningún caller productivo afectado (verificado pre-sprint). Backup JSON v1 intacto. Schema sin cambios.
- **Sucesor**: cuando Diego note degradación con 5000+ entries (raro), sprint de paginación con offset real.

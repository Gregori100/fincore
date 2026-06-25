# Test plan — flutter-movements-pagination-v1

## Casos borde detectados

Más allá de los CB-01 a CB-10 del spec:

- **CB-T01**: BD con exactamente 100 entries → primer emit `entries.length == 100`. NO marcar `_reachedEnd` (puede haber más). Scroll trigger dispara `_loadMore` → `_currentLimit = 200`. Stream re-emite con 100 entries (no hay más). Ahora `entries.length < _currentLimit` → `_reachedEnd = true`.
- **CB-T02**: BD con exactamente 99 entries → primer emit `entries.length == 99 < _currentLimit (100)` → `_reachedEnd = true` desde el inicio. Scroll listener ignora trigger.
- **CB-T03**: BD vacía → primer emit `entries.length == 0 < _currentLimit (100)` → `_reachedEnd = true`. `_EmptyState` se renderiza (sin footer porque la lista está vacía y no se renderiza `_EntriesList` ni su footer).
- **CB-T04**: scroll trigger durante `_loadingMore == true` → ignorado por el guard.
- **CB-T05**: scroll trigger tras `_reachedEnd == true` → ignorado por el guard.
- **CB-T06**: cambio de filtro mid-paginación (cuando ya hay 300 entries cargados, Diego cambia "Este mes" → "Mes pasado"): `_resetPagination` setea `_currentLimit = 100`, `_reachedEnd = false`, `_loadingMore = false`. `_buildStream` arma nuevo Stream con limit 100 + filtros nuevos. Lista se reemplaza al primer emit.
- **CB-T07**: tap "X" del chip de filtro activo → `_removeDimension` → `_resetPagination` → nuevo Stream.
- **CB-T08**: tap "Limpiar filtros" del estado vacío → `_clearAllFilters` → `_resetPagination` → nuevo Stream.
- **CB-T09**: rotación de pantalla / cambio de tamaño del Scaffold → `_scrollController` mantiene `position.pixels` (Flutter standard). Sin reset.
- **CB-T10**: el ListView nunca llega a estar scrolleable porque la lista cabe en pantalla (ej. 5 entries) → el listener no se dispara. `_reachedEnd` ya está en true por CB-T03 lógica equivalente.
- **CB-T11**: dos `_loadMore` consecutivos muy rápidos (race teórica): el primero hace `setState(_loadingMore = true; _currentLimit = 200; ...)`. El listener antes de que llegue el primer emit, vuelve a triggerar. Pero `_loadingMore == true` lo bloquea. OK.
- **CB-T12**: registrar entry nuevo desde `/entries/new` con filtro actual matchea: vuelve a `/entries` → Stream emite la lista actualizada al `_currentLimit` actual. El entry nuevo entra si su posición en el orden lo coloca dentro del limit.
- **CB-T13**: archivar categoría con filtro activo de esa categoría: Stream re-emite con menos entries. `_reachedEnd` puede activarse si los entries son menos que `_currentLimit`.
- **CB-T14**: importar respaldo JSON v1 mientras `/entries` está abierta: BD se reemplaza dentro de transacción. Stream re-emite tras commit con la lista nueva al `_currentLimit` actual. El estado de paginación NO se resetea automáticamente (caso raro).
- **CB-T15**: la `Dashboard` sigue invocando `watchPage(limit: 10)` sin paginación. Verificar que no rompe por la eliminación de deprecated (F0 confirmó esto).
- **CB-T16**: `entries.length == _currentLimit` exacto: NO marcar `_reachedEnd` (puede haber más). Esperar a próximo `_loadMore` para confirmar.
- **CB-T17**: `_currentLimit` muy grande (10 páginas = 1000 entries) con journal de 5000 totales: query carga 1000 entries de una. Lag visible si supera 200ms en debug build.

## Pruebas unitarias necesarias

Archivo: `mobile/test/data/entries_dao_filters_test.dart` (extensión).

- **UT-01**: BD con 150 entries, `watchPage(limit: 100)` → retorna exactamente 100 entries.
- **UT-02**: BD con 50 entries, `watchPage(limit: 100)` → retorna 50 entries.
- **UT-03**: BD con 150 entries, `watchPage(offset: 0, limit: 100)` y `watchPage(offset: 100, limit: 100)` retornan páginas distintas que no se solapan y concatenadas dan los 150 originales.

No agregamos tests del modelo `EntriesFilters` (no cambia).

## Pruebas de integración o API necesarias

App local-first sin API. Sin integración nueva.

- **IT-01** (opcional): test que valida que registrar un entry vía `EntriesDao.registerExpense` mientras un Stream con `watchPage(limit: 100)` está suscrito → el Stream re-emite con el entry nuevo. Validación de reactividad básica. Probablemente ya cubierto por otros tests del DAO.

## Pruebas de UI o flujo necesarias

**Widget tests del scroll infinito**: diferidos por cuelgue sistémico de `pumpAndSettle` con ScrollController + StreamBuilder.

- **WT-01** (intentar, diferir si cuelga): mount `EntriesListScreen` con 150 entries sembrados. Validar que aparecen los primeros 100. Scroll programático al final → validar que la lista crece a 200 entries (todos los 150 + footer "Fin").
- **WT-02** (intentar, diferir si cuelga): cambio de filtro resetea a 100.
- **WT-03** (probablemente diferido): footer "Cargando…" durante el loading.

Si los 3 cuelgan, documentar como diferidos en `pendientes.md` con justificación. Cobertura compensatoria: smoke manual.

## Pruebas de permisos y seguridad

No aplica. Single-user, sin auth.

## Pruebas de datos, migración o compatibilidad

- **MG-01**: BD con `schemaVersion = 2` → sin migración disparada. Verificable manualmente (la app abre sin re-trigger de `onUpgrade`).
- **MG-02**: importar respaldo JSON v1 anterior al sprint → la lista paginada rinde correcto sobre los datos importados.

## Pruebas de regresión sobre flujos existentes

- **RG-01**: Dashboard sigue mostrando últimos 10 movimientos sin filtros. Test `dashboard_screen_test.dart` debe seguir verde.
- **RG-02**: panel de filtros y deep link desde reporte siguen funcionando.
- **RG-03**: tests existentes de `entries_list_screen_test.dart` (4 tests):
  - "Default thisMonth muestra los 5 entries del mes actual": sigue verde (lista chica, sin scroll).
  - "AppBar tiene IconButton tune": sigue verde.
  - "Estado vacío específico cuando lista vacía + filtros activos": probable que rompa por el cambio de `_EmptyState` con `onClearFilters` (ya cubierto en sprint anterior).
  - "Estado vacío genérico cuando BD vacía sin filtros": sigue verde.
  - **Validar y actualizar lo mínimo**.
- **RG-04**: tests de `entries_filters_screen_test.dart` (8 tests): sin cambios esperados.
- **RG-05**: tests de `reports_deeplink_test.dart` (2 tests): sin cambios esperados.
- **RG-06**: tests del DAO existentes (30+): sin cambios esperados, todos verdes tras F0.

Suite total post-sprint: ≥ 217 verdes (214 actual + 3 nuevos).

## Pruebas manuales o smoke tests necesarios

Tras instalar `0.6.0+52` en el Redmi:

- **SM-01**: Settings → "Acerca de" muestra `0.6.0+52`.
- **SM-02**: Abrir `/entries`. Sin filtros activos (default thisMonth). Si tenés <100 entries del mes, el footer dice "Fin de los movimientos del rango." al final del scroll.
- **SM-03**: Cambiar filtro a "Año" (más entries probablemente). Si hay >100 entries del año:
  - Ver los primeros 100.
  - Scrollear al final → debe aparecer "Cargando…" brevemente → cargar siguientes 100.
  - Repetir hasta llegar al fin → footer dice "Fin de los movimientos del rango."
- **SM-04**: Estando en página 3 (300 entries cargados), cambiar filtro a "Mes pasado" → la lista vuelve al inicio con los primeros 100 del nuevo rango.
- **SM-05**: Tap "X" del chip de filtro activo → equivalente a SM-04 (reseteo).
- **SM-06**: El footer "Mostrando los 200 más recientes" no aparece en ningún caso (eliminado).
- **SM-07**: Registrar entry nuevo desde `/entries/new` → vuelve a `/entries` y el entry nuevo aparece en la lista si matchea filtros y rango.
- **SM-08**: Deep link desde reporte sigue funcionando. Bucket con muchos entries (>100) → ver los primeros 100 + scroll infinito.

## Datos de prueba recomendados

Para los unitarios del DAO:

- BD in-memory + seedDefaults.
- Loop registrando 150 expenses con `Factories.debit` o equivalente, fechas consecutivas, montos arbitrarios.

Para smoke manual:

- Diego puede tener su journal real si supera 100 entries del mes/año. Si no, registrar 110-120 entries manuales (fastidioso pero único camino sin importar respaldo).

## Comandos o validaciones locales sugeridas

```bash
cd mobile

# F0 verificación:
grep -rn "watchPage(kind:\|watchPage(accountId:" lib/ test/ | grep -v "@Deprecated"
# Debe retornar 0 matches.

# Tras F2 + F3 (lógica + UI):
flutter run -d linux  # iteración visual

# Tras F4 (tests):
flutter test test/data/entries_dao_filters_test.dart
flutter test  # 217+ verdes

# Tras F5 (release):
flutter analyze
flutter build apk --release --split-per-abi
scripts/verify-apk.sh build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

## Criterios mínimos para aprobar la implementación

- ≥3 tests unitarios del DAO con offset/limit verdes.
- Suite total ≥217 verdes.
- `flutter analyze`: 0 errores, 0 warnings (hints info preexistentes tolerados).
- `scripts/verify-apk.sh` retorna exit 0 con versionCode 2052.
- APK release instalable en el Redmi sin downgrade error.
- Smoke manual SM-01 a SM-08 pasados (Diego confirma).
- Sin regresión en la suite existente (RG-01 a RG-06).

## Validación final recomendada

Para sprints chicos, `branch-quality-review` es opcional pero recomendado si:
- Diego nota algún hallazgo durante el smoke.
- El reset de paginación tras cambio de filtro siente buggy.
- El threshold de 300px se siente mal calibrado.

Si todo el smoke pasa limpio, commit + push directo sin review formal puede ser razonable.

El reporte del quality review (si se ejecuta) viviría en `engineering/quality-review/flutter-movements-pagination-v1/`.

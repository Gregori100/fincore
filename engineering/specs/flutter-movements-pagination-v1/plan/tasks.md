# Tasks — flutter-movements-pagination-v1

Sprint chico (~3-4h efectivas). Tareas pequeñas con criterio de terminado verificable.

## F0 — Validación pre-sprint (limpieza ya aplicada)

- [ ] T001 Validación: confirmar que `grep -rn "watchPage(kind:\|watchPage(accountId:" mobile/` retorna 0 matches.
  RF: ninguna (gate)
  Depende de: ninguna
  Paralelizable: no
  Criterio de terminado: 0 matches en grep + `flutter test` con 214 verdes.

## F1 — State + ScrollController

- [ ] T002 Frontend: agregar al `_EntriesListScreenState` los campos `int _currentLimit = 100`, `bool _reachedEnd = false`, `bool _loadingMore = false`, `final ScrollController _scrollController = ScrollController()`.
  RF: RF-001, RF-002
  Depende de: T001
  Paralelizable: no
  Criterio de terminado: compila sin warnings.

- [ ] T003 Frontend: agregar `_scrollController.addListener(_onScroll)` en `initState`. Implementar `_onScroll()` (vacío por ahora, lógica en T006).
  RF: RF-003
  Depende de: T002
  Paralelizable: no
  Criterio de terminado: listener instalado, callback definido.

- [ ] T004 Frontend: agregar `_scrollController.dispose()` antes del `super.dispose()` en el método dispose existente.
  RF: RF-004
  Depende de: T002
  Paralelizable: sí (con T003)
  Criterio de terminado: leak prevention verificado por inspección.

- [ ] T005 Frontend: en `_buildStream`, reemplazar `limit: _kEntriesLimit` por `limit: _currentLimit`. Pasar `controller: _scrollController` al `ListView.separated` dentro de `_EntriesList`.
  RF: RF-011, RF-012
  Depende de: T002
  Paralelizable: no
  Criterio de terminado: lista usa el controller; query usa el limit dinámico.

## F2 — Lógica de paginación

- [ ] T006 Frontend: implementar `_onScroll()` con la lógica: si `_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300 && !_reachedEnd && !_loadingMore`, llamar `_loadMore()`.
  RF: RF-003
  Depende de: T003
  Paralelizable: no
  Criterio de terminado: callback dispara `_loadMore` correctamente bajo los guards.

- [ ] T007 Frontend: implementar `_loadMore()`: `setState(() { _currentLimit += 100; _loadingMore = true; _buildStream(); })`.
  RF: RF-005
  Depende de: T005
  Paralelizable: no
  Criterio de terminado: invocar manualmente desde `flutter run -d linux` y validar visualmente que el limit crece.

- [ ] T008 Frontend: implementar `_resetPagination()`: `_currentLimit = 100; _reachedEnd = false; _loadingMore = false;`. NO llama setState (lo harán los callers junto con `_buildStream`).
  RF: RF-006
  Depende de: T002
  Paralelizable: sí (con T006, T007)
  Criterio de terminado: método definido.

- [ ] T009 Frontend: hookar `_resetPagination()` en los puntos de cambio de filtro:
  - `_openFilters` (justo después de `if (result == null) return;`).
  - `_removeDimension` (al inicio del switch o antes del `setState`).
  - `_clearAllFilters` (al inicio).
  Combinar con el `setState` existente para que `_resetPagination` se aplique antes de `_buildStream`.
  RF: RF-006
  Depende de: T008
  Paralelizable: no
  Criterio de terminado: cambio de filtro vuelve a `_currentLimit = 100` confirmado por `flutter run -d linux`.

- [ ] T010 Frontend: detección de fin en el `builder` del `StreamBuilder`. Si `entries.length < _currentLimit && !_reachedEnd`, agendar `WidgetsBinding.instance.addPostFrameCallback` que haga `setState(() { _reachedEnd = true; _loadingMore = false; })`. Si `entries.length >= _currentLimit && _loadingMore`, agendar `setState(() => _loadingMore = false)`. Ambos con guard `if (!mounted) return;` dentro del callback.
  RF: RF-007
  Depende de: T007
  Paralelizable: no
  Criterio de terminado: footer "Fin" aparece cuando se llega al final del rango.

## F3 — UI del footer

- [ ] T011 Frontend: crear `_PaginationFooter` privado en `entries_list_screen.dart`. Recibe `loadingMore: bool` y `reachedEnd: bool`. Si `loadingMore`: muestra "Cargando…" centrado con padding vertical 16. Si `reachedEnd`: muestra "Fin de los movimientos del rango." sutil.
  RF: RF-009
  Depende de: T002
  Paralelizable: sí (con tasks F2)
  Criterio de terminado: widget compila y renderiza los 2 estados.

- [ ] T012 Frontend: modificar `_EntriesList` para recibir `loadingMore` y `reachedEnd`. `itemCount` suma 1 si `loadingMore || reachedEnd`. `itemBuilder` retorna `_PaginationFooter` cuando `i == entries.length` y hay footer.
  RF: RF-008
  Depende de: T011
  Paralelizable: no
  Criterio de terminado: footer aparece como último item bajo las condiciones esperadas.

- [ ] T013 Frontend: eliminar `_TruncatedFooter` y la constante `_kEntriesLimit = 200`.
  RF: RF-010
  Depende de: T012
  Paralelizable: no
  Criterio de terminado: `grep -n "_TruncatedFooter\|_kEntriesLimit" mobile/lib/screens/entries_list_screen.dart` retorna 0 matches.

- [ ] T014 Frontend: pasar `loadingMore: _loadingMore` y `reachedEnd: _reachedEnd` al `_EntriesList` cuando se invoca en el builder del `StreamBuilder`.
  RF: RF-008
  Depende de: T012
  Paralelizable: no
  Criterio de terminado: visual con `flutter run -d linux` muestra el footer correcto en cada estado.

## F4 — Tests data

- [ ] T015 Pruebas: agregar UT-01 a `entries_dao_filters_test.dart`: registrar 150 entries del mismo kind, `watchPage(limit: 100)` retorna 100.
  RF: RF-013
  Depende de: T001
  Paralelizable: sí (con T016, T017)
  Criterio de terminado: 1 test verde.

- [ ] T016 Pruebas: agregar UT-02 (50 entries, limit 100, retorna 50).
  RF: RF-013
  Depende de: T001
  Paralelizable: sí (con T015, T017)
  Criterio de terminado: 1 test verde.

- [ ] T017 Pruebas: agregar UT-03 (150 entries, offset/limit distintos, páginas no se solapan).
  RF: RF-013
  Depende de: T001
  Paralelizable: sí (con T015, T016)
  Criterio de terminado: 1 test verde.

- [ ] T018 Pruebas: correr `flutter test test/data/entries_dao_filters_test.dart` completo + suite full. Validar 217+ verdes.
  RF: ninguna (gate)
  Depende de: T015, T016, T017
  Paralelizable: no
  Criterio de terminado: suite completa verde.

- [ ] T019 Pruebas: revisar y actualizar los 4 tests previos de `entries_list_screen_test.dart` si rompen por cambio de footer. Lo más probable: solo el test "Estado vacío específico" puede necesitar ajuste por el botón "Limpiar filtros" (ya cubierto). Validar.
  RF: ninguna (gate)
  Depende de: T014
  Paralelizable: no
  Criterio de terminado: 4 tests previos siguen verdes.

## F5 — Validación de calidad

- [ ] T020 Validación: `flutter analyze` debe quedar en 0 errores, 0 warnings.
  RF: CA-08
  Depende de: T018, T019
  Paralelizable: no
  Criterio de terminado: output limpio salvo hints info preexistentes.

- [ ] T021 Validación (opcional para sprint chico): invocar `/branch-quality-review flutter-movements-pagination-v1`. Para sprints chicos puede omitirse si todo el smoke pasa limpio.
  RF: ninguna (gate)
  Depende de: T020
  Paralelizable: no
  Criterio de terminado: si se ejecuta, reporte en `engineering/quality-review/flutter-movements-pagination-v1/`. Hallazgos críticos resueltos.

## Documentación

- [ ] T022 Documentación: crear `engineering/specs/flutter-movements-pagination-v1/implementation/cierre.md` con resumen del sprint + decisiones tomadas durante implementación. Si surgió pendiente, agregar `pendientes.md`.
  RF: ninguna (gate)
  Depende de: T020
  Paralelizable: sí (con T023)
  Criterio de terminado: archivo creado.

## Release

- [ ] T023 Release: bump `mobile/pubspec.yaml` a `version: 0.6.0+52`.
  RF: RF-014
  Depende de: T020
  Paralelizable: sí (con T024)
  Criterio de terminado: línea actualizada.

- [ ] T024 Release: bump `mobile/android/app/build.gradle.kts` a `versionCode = 52`, `versionName = "0.6.0"`.
  RF: RF-014
  Depende de: T020
  Paralelizable: sí (con T023)
  Criterio de terminado: ambas líneas actualizadas.

- [ ] T025 Release: ejecutar `flutter build apk --release --split-per-abi`.
  RF: RF-014
  Depende de: T023, T024
  Paralelizable: no
  Criterio de terminado: 3 APKs generados.

- [ ] T026 Release: ejecutar `scripts/verify-apk.sh build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.
  RF: RF-014, CA-09
  Depende de: T025
  Paralelizable: no
  Criterio de terminado: exit 0 con versionCode=2052, versionName=0.6.0.

- [ ] T027 Release: comunicar comando `adb install -r` a Diego al final del sprint.
  RF: ninguna (gate)
  Depende de: T026
  Paralelizable: no
  Criterio de terminado: comando comunicado.

- [ ] T028 Release: smoke manual SM-01 a SM-08 por Diego tras instalar. Confirmación verbal de:
  - Scroll infinito funciona (cargar más a 300px del final).
  - Footer "Fin de los movimientos del rango" aparece al llegar al final.
  - Footer "Cargando…" aparece durante la carga.
  - Cambio de filtro resetea a 100.
  - El footer viejo "Mostrando los 200 más recientes" ya no aparece.
  RF: CME-04, CME-05
  Depende de: T027
  Paralelizable: no
  Criterio de terminado: Diego confirma cada item.

## Resumen de paralelización

- T015, T016, T017 paralelizables entre sí.
- T023, T024 paralelizables entre sí.
- T011 paralelizable con tareas de F2 (T006-T010) si se ejecuta el código en paralelo.

Total tareas: **28**. Estimado de horas: **F0=5min, F1=30min, F2=1h, F3=45min, F4=45min, F5=30min ≈ 3.5h efectivas**. Sprint chico.

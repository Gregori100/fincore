# Tasks — Fixes al endpoint entries-by-bucket

## Backend

- [ ] T001 Backend: cambiar validación de `category_id` en `entriesByBucket` (FinanceController.php:470) de `['sometimes', 'uuid', 'exists:...']` a `['sometimes', 'nullable', 'uuid', 'exists:categories,id,user_id,'.$userId]`. Sin más cambios al método.
  RF: RF-001
  Depende de: ninguna
  Paralelizable: no (gate)
  Criterio de terminado: validador acepta `category_id=null` sin 422; resto del comportamiento sin cambios.

- [ ] T002 Backend: modificar helper `applyEntryFilters` (FinanceController.php:253) para detectar `category_id` con `array_key_exists`. Si presente y null → `whereNull('category_id')`. Si presente y no null → `where('category_id', $id)`. Cambio aislado a la rama `category_id`; otros filtros (`account_id`, `kind`, `from`, `to`) siguen con `isset`.
  RF: RF-002, RF-005
  Depende de: T001
  Paralelizable: no
  Criterio de terminado: cuando llega `category_id=null`, la query filtra `WHERE category_id IS NULL`. Tests T006 verifican.

- [ ] T003 Backend: modificar helper `applyEntryFilters` (rama `kind`) para tratar `kind=expense` como `whereIn(['expense','credit_expense'])`. Cualquier otro `kind` mantiene `where('kind', $value)` literal.
  RF: RF-003, RF-004
  Depende de: T001
  Paralelizable: sí (con T002)
  Criterio de terminado: `kind=expense` devuelve entries `expense` Y `credit_expense`; otros kinds literal.

- [ ] T004 Backend: modificar helper `buildBucketLabel` (FinanceController.php:518) para detectar `category_id` con `array_key_exists`. Si presente y null → agregar "sin categorizar" al label (ej. "Gastos sin categorizar del X al Y"). Si presente y UUID → mantener "de NombreCategoria". Si ausente → no mencionar categoría.
  RF: RF-008
  Depende de: T001
  Paralelizable: sí (con T002, T003)
  Criterio de terminado: label correcto en los 3 escenarios. Test T010 verifica.

- [ ] T005 Backend: confirmar que `if (empty($data))` en `entriesByBucket` (FinanceController.php:477) sigue funcionando con `category_id=null`. PHP `empty(['category_id' => null])` devuelve false, así que el chequeo pasa. Sin cambios al código.
  RF: RF-007
  Depende de: T001
  Paralelizable: sí
  Criterio de terminado: test verifica que `?category_id=null` único pasa `missing_filters` (200), pero `?` sin filtros sigue dando 422.

## Pruebas (backend)

- [ ] T006 Pruebas: agregar `test_category_id_null_filters_uncategorized_entries` a `EntriesByBucketTest`. Crear 2 entries (uno con categoría, uno sin). GET `?category_id=&kind=expense`. Esperar 1 entry (sin categoría).
  RF: RF-002, RF-006
  Depende de: T002, T003
  Paralelizable: sí (con T007..T010)
  Criterio de terminado: test verde.

- [ ] T007 Pruebas: agregar `test_kind_expense_includes_credit_expense` a `EntriesByBucketTest`. Crear 1 expense + 1 credit_expense del mismo user en el mismo rango. GET `?kind=expense`. Esperar 2 entries en respuesta.
  RF: RF-003
  Depende de: T003
  Paralelizable: sí
  Criterio de terminado: test verde.

- [ ] T008 Pruebas: agregar `test_kind_credit_expense_literal` a `EntriesByBucketTest`. Mismos 2 entries. GET `?kind=credit_expense`. Esperar solo 1 (credit_expense, no expense puro).
  RF: RF-004
  Depende de: T003
  Paralelizable: sí
  Criterio de terminado: test verde.

- [ ] T009 Pruebas: agregar `test_kind_income_literal` y `test_kind_transfer_literal` a `EntriesByBucketTest`. Validar que filtros literales no se ven afectados por el cambio.
  RF: RF-004
  Depende de: T003
  Paralelizable: sí
  Criterio de terminado: 2 tests verde.

- [ ] T010 Pruebas: agregar `test_bucket_label_includes_sin_categorizar_when_category_id_is_null` a `EntriesByBucketTest`. GET con `category_id=null + kind=expense`. Validar que `bucket_label` contiene "sin categorizar".
  RF: RF-008
  Depende de: T004
  Paralelizable: sí
  Criterio de terminado: test verde.

- [ ] T011 Pruebas: validar que los 14 tests existentes de `EntriesByBucketTest` siguen verde sin modificación. Si alguno necesita ajuste por la nueva semántica, documentar.
  RF: RF-001..RF-008
  Depende de: T002, T003, T004
  Paralelizable: sí
  Criterio de terminado: 14 tests existentes verdes; ajustes (si hay) documentados.

- [ ] T012 Pruebas: verificar `test_entries_endpoint_paginates_and_filters` en `FinanceApiTest.php`. Si usa `kind=expense` con expectativa literal, ajustar test para reflejar la nueva semántica. Si no usa `kind=expense`, dejar tal cual.
  RF: regresión `/entries`
  Depende de: T003
  Paralelizable: sí
  Criterio de terminado: test gate verde.

## Frontend

- [ ] T013 Frontend: modificar `pruneFilters` en `frontend/src/components/finance/EntriesDrilldownModal.vue`. Caso especial: si `Object.prototype.hasOwnProperty.call(f, 'category_id') && f.category_id === null`, preservar en el output. Resto del loop sin cambios.
  RF: RF-006
  Depende de: ninguna (paralelo a backend)
  Paralelizable: sí
  Criterio de terminado: función exporta el nuevo comportamiento; tests T014 verifican.

- [ ] T014 Pruebas: agregar 3 tests a `frontend/tests/components/EntriesDrilldownModal.spec.js`:
  - `pruneFilters preserva category_id: null cuando la key existe`.
  - `pruneFilters omite category_id cuando la key no está en filters`.
  - `pruneFilters descarta otros filtros con null (regresión account_id)`.
  RF: RF-006
  Depende de: T013
  Paralelizable: no
  Criterio de terminado: 3 tests verde.

## Validacion de calidad

- [ ] T015 Validación: suite backend completa verde (sin regresión en los 386 actuales + nuevos).
  RF: criterios mínimos
  Depende de: T006..T012
  Paralelizable: no
  Criterio de terminado: `php artisan test` verde.

- [ ] T016 Validación: suite frontend completa verde (sin regresión en los 116 actuales + nuevos).
  RF: criterios mínimos
  Depende de: T014
  Paralelizable: sí (con T015)
  Criterio de terminado: `npx vitest run` verde.

- [ ] T017 Validación: Pint sobre el controller modificado.
  Depende de: T002, T003, T004
  Paralelizable: sí
  Criterio de terminado: `./vendor/bin/pint app/Http/Controllers/FinanceController.php` sin diffs.

- [ ] T018 Validación: smoke en navegador con Playwright. Seedear dataset (1 expense con cat, 1 credit_expense con cat, 1 expense sin cat) y validar 7 escenarios del test-plan.
  Depende de: T015, T016
  Paralelizable: no
  Criterio de terminado: 7/7 OK.

- [ ] T019 Validación: ejecutar `branch-quality-review` con `slug=entries-by-bucket-fixes`. Atender hallazgos críticos antes del merge.
  Depende de: T018
  Paralelizable: no
  Criterio de terminado: reporte generado; sin bloqueantes.

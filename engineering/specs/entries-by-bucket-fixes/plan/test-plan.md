# Test plan — Fixes al endpoint entries-by-bucket

## Casos borde detectados

- **`category_id=null` válido sin otros filtros**: pasa `missing_filters` porque hay un filtro. Devuelve entries `category_id IS NULL` de toda la historia con cap 100.
- **`category_id=null` + `kind=expense`**: combinación válida; devuelve entries sin categoría de tipo expense + credit_expense.
- **`category_id=null` con dataset que no tiene entries sin categoría**: devuelve `categories: []`, `total_count: 0`. Sin error.
- **Día 1 del mes con `kind=expense`**: incluye credit_expense del día 1. Sin error en cálculo de rangos.
- **`kind=expense` + categoría con sólo credit_expense**: devuelve esos entries. Antes devolvía vacío (porque sólo había credit_expense, no expense puro).
- **`kind=credit_expense` literal**: NO incluye expense puro. Usado en `/reports/credit-cards`.
- **`kind=income` literal**: sin cambios.
- **`kind=transfer`, `debt_payment`, `adjustment`**: sin cambios.
- **`category_id` con UUID válido**: ya cubierto por tests previos. Sin cambios.
- **`category_id` con UUID de otro usuario**: 422 por `exists`. Sin cambios.
- **`category_id` como cadena vacía `''`**: tratado como `null` o descartado por Laravel `nullable`. Test confirmar.
- **`category_id` archivada con histórico**: tests existentes cubren. Sin cambios.
- **Cancelados (`deleted_at != null`)**: scope global los excluye. Sin cambios.
- **Frontend `pruneFilters` con `category_id: null` presente**: preserva null.
- **Frontend `pruneFilters` con `category_id: ''`**: descarta (regla "vacíos se descartan").
- **Frontend `pruneFilters` con `category_id: undefined`**: descarta.
- **Frontend `pruneFilters` sin la key `category_id`**: no inserta nada.
- **`bucket_label` con `category_id=null` + `kind=expense`**: contiene "Gastos" y "sin categorizar" en el label.
- **`bucket_label` con `category_id` UUID válido**: igual que antes, "de Comida" etc.
- **`bucket_label` sin `category_id`**: igual que antes (no menciona categoría).
- **Performance con `whereNull('category_id')`**: sin índice específico, scan parcial. Aceptable.
- **Regresión en `/entries`**: el filtro "Tipo = Gasto" ahora incluye `credit_expense`. Cambio deseable, verificar tests existentes.
- **Regresión en otros endpoints/reportes**: cero (no se tocan).

## Pruebas unitarias necesarias

No aplica. Los helpers `applyEntryFilters` y `buildBucketLabel` son privados al controller; se ejercitan a través de tests HTTP.

## Pruebas de integracion o API necesarias

En `backend/tests/Feature/Http/EntriesByBucketTest.php` (agregar a los 14 existentes):

- **`test_category_id_null_filters_uncategorized_entries`**: crear 2 entries (uno con categoría, uno sin). GET con `category_id` explícitamente null + `kind=expense`. Esperar 1 entry (el sin categoría).
- **`test_category_id_null_combined_with_kind_expense`**: combinación. Validar que solo trae expense/credit_expense sin categoría.
- **`test_kind_expense_includes_credit_expense`**: crear 1 expense + 1 credit_expense (mismo user, mismo rango). GET con `kind=expense`. Esperar 2 entries.
- **`test_kind_credit_expense_does_not_mix_with_expense`**: mismos 2 entries del test anterior. GET con `kind=credit_expense`. Esperar solo el credit_expense.
- **`test_kind_income_literal`**: crear income + expense. GET con `kind=income`. Solo income.
- **`test_kind_transfer_literal`**: similar para transfer.
- **`test_bucket_label_uncategorized_includes_sin_categorizar`**: GET con `category_id=null` + `kind=expense`. `bucket_label` contiene "sin categorizar".
- **`test_bucket_label_with_category_id_unchanged`**: sanity check. Bucket con categoría sigue diciendo "de NombreCategoria".
- **`test_category_id_empty_string_treated_as_null`** (opcional): GET con `category_id=`. Comportamiento equivalente a `category_id=null`.
- **`test_missing_filters_still_returns_422_when_only_category_id_null_absent`**: sin ningún filtro, sigue dando `missing_filters`. Pero con `category_id=null` único, pasa.

En `backend/tests/Feature/Http/FinanceApiTest.php` (validación de no-regresión):

- **`test_entries_endpoint_paginates_and_filters` (existente)**: leer el test. Si usa `kind=expense` con expectativa de filtrar literal (sin credit_expense), ajustar el test para reflejar la nueva semántica. Si no lo usa, dejar tal cual.
- Otros tests de `/entries` con `kind`: verificar.

## Pruebas de UI o flujo necesarias si aplica

En `frontend/tests/components/EntriesDrilldownModal.spec.js` (agregar a los existentes):

- **`pruneFilters preserva category_id: null cuando la key existe explícitamente`**: input `{ category_id: null, kind: 'expense' }` → output `{ category_id: null, kind: 'expense' }`.
- **`pruneFilters omite category_id cuando la key no está en filters`**: input `{ kind: 'expense' }` → output `{ kind: 'expense' }`. Sin agregar key.
- **`pruneFilters descarta category_id cuando el valor es '' o undefined`**: validar.
- **`pruneFilters descarta otros filtros con null` (regresión)**: input `{ account_id: null, kind: 'expense' }` → output `{ kind: 'expense' }`. La regla null-preserve es solo para `category_id`.

Los smoke tests pre-existentes del modal (`fetch + render`, `truncado`, `Ir a Movimientos`) deben seguir verde.

## Pruebas de permisos y seguridad si aplica

- Tests pre-existentes cubren auth/verified/scope. No se modifican.
- Confirmar que la validación `exists:categories,id,user_id,$userId` con `nullable` sigue cortando UUIDs de otros users (debería; `nullable` solo afecta el caso `null`).

## Pruebas de datos, migracion o compatibilidad si aplica

No aplica. Sin migraciones.

## Pruebas de regresion sobre flujos existentes

- **EntriesByBucketTest (14 tests pre-existentes)**: deben seguir verde sin modificación. Si alguno usa `kind=expense` con expectativa de "solo expense puro", ajustar para reflejar la nueva semántica (whereIn).
- **EntriesDrilldownModal.spec.js (existentes)**: deben seguir verde. Los 5 tests previos no validan la rama `null` en `pruneFilters`.
- **Suite backend completa**: 386 actuales + ~5-7 nuevos.
- **Suite frontend completa**: 116 actuales + ~3 nuevos.
- **Tests E2E** (`tests-e2e/`): `entries.spec.js` está desactualizado, no bloquea. Otros specs no afectados.
- **Smoke manual de las 7 vistas de reportes**: validar que el drill-down sigue funcionando en todas (no debería romper ninguno).

## Pruebas manuales o smoke tests necesarios

Levantar stack:

```bash
./scripts/fincore start
```

Setup de datos en navegador o tinker:
1. Login con user verificado.
2. Crear 1 entry expense con categoría "Comida" en el mes actual.
3. Crear 1 entry credit_expense con categoría "Comida" en el mes actual (usar una tarjeta).
4. Crear 1 entry expense sin categoría en el mes actual.

Smoke en navegador:
1. `/reports/by-category` → bucket "Comida" muestra $X (expense + credit_expense). Click → modal con 2 entries (no 1). Suma del modal = $X.
2. `/reports/by-category` → bucket "Sin categorizar" muestra el entry sin categoría. Click → modal con 1 entry. No mezcla con otras.
3. `/reports/forecast` → equivalente al punto 1 si Comida tiene historial en los 3 meses previos.
4. `/reports/forecast` → equivalente al punto 2 si "Sin categorizar" tiene historial.
5. `/entries` con filtro Tipo = "Gasto" → muestra expense + credit_expense (verificar que aparecen ambos en la lista).
6. `/entries` con filtro Tipo = "Cargo crédito" (credit_expense literal) → solo muestra credit_expense.
7. `/reports/credit-cards` → click en un cargo → modal con solo credit_expense (literal).

## Datos de prueba recomendados

- 1 user con email verificado.
- 2 cuentas (1 débito + 1 crédito con `credit_limit`).
- 3 categorías de gasto incluyendo una con `monthly_limit` para no romper budgets.
- Entries del mes actual: 1 expense con categoría, 1 credit_expense con la misma categoría, 1 expense sin categoría.
- Para forecast: replicar entries en marzo, abril, mayo del mismo año.

## Comandos o validaciones locales sugeridas

```bash
# Backend
docker compose exec -T -w /var/www/html api php artisan test --filter='EntriesByBucket|FinanceApi'
docker compose exec -T -w /var/www/html api php artisan test
docker compose exec -T -w /var/www/html api ./vendor/bin/pint --test app/Http/Controllers/FinanceController.php

# Frontend
cd frontend
npx vitest run tests/components/EntriesDrilldownModal.spec.js
npx vitest run

# Smoke manual: levantar stack y navegar
./scripts/fincore start
# http://localhost:5173/reports/by-category, /reports/forecast, /entries
```

## Criterios minimos para aprobar la implementacion

- Suite backend: 386 actuales + nuevos = ~393 verde.
- Suite frontend: 116 actuales + nuevos = ~119 verde.
- Pint sin diffs.
- Smoke manual: 7/7 escenarios validados en navegador.
- `entriesByBucket` ya no devuelve entries de todas las categorías cuando se filtra `category_id=null`.
- `kind=expense` en drill-down incluye credit_expense.
- `kind=credit_expense` mantiene literal.
- `bucket_label` con `category_id=null` contiene "sin categorizar".
- Cero regresiones en los 7 reportes existentes y sus exports.
- Cero regresiones en `/entries` y `/accounts/:uuid`.

## Validacion final recomendada

Ejecutar `branch-quality-review` con `slug=entries-by-bucket-fixes`. Reporte en `engineering/quality-review/entries-by-bucket-fixes/`. Foco recomendado:

1. **Semántica del cambio en `applyEntryFilters`**: validar que `kind=expense` whereIn no afecta otros endpoints.
2. **`array_key_exists` vs `isset`**: en `applyEntryFilters` y `buildBucketLabel` solo para `category_id`.
3. **Tests cubren `kind=credit_expense` literal** (no debe mezclarse con expense).
4. **`pruneFilters` aislado a `category_id`**: otros campos siguen con la regla original.
5. **No regresión en `/entries`**: tests del paginado siguen verde con la nueva semántica.
6. **Smoke real**: bucket "Sin categorizar" y bucket con credit_expense.

# Plan técnico — Fixes al endpoint entries-by-bucket

## Enfoque tecnico

Cambio quirúrgico localizado en 3 puntos:

1. **Validación de `entriesByBucket`**: aceptar `category_id=null` explícito. Validador pasa de `['sometimes', 'uuid', 'exists:...']` a `['sometimes', 'nullable', 'uuid', 'exists:...']`. Sin nuevos parámetros, sin nuevos campos, sin migraciones.

2. **Helper `applyEntryFilters`**: dos cambios independientes:
   - **`category_id`**: usar `array_key_exists` (no `isset`) para detectar presencia, ya que `isset($arr['x'])` devuelve `false` cuando el valor es `null`. Si la key existe y el valor es `null`, aplicar `whereNull('category_id')`. Si existe y es UUID, mantener `where('category_id', $id)`.
   - **`kind`**: cuando el valor es exactamente `'expense'`, aplicar `whereIn('kind', ['expense', 'credit_expense'])`. Cualquier otro `kind` (`income`, `credit_expense`, `transfer`, `debt_payment`, `adjustment`) mantiene `where('kind', $value)` literal. Esta semántica se alinea con la que ya usan los Report Services (`CategoryBreakdownReport`, `BudgetsReport`, `SpendingForecastReport`).

3. **Helper `buildBucketLabel`**: cuando `category_id` está presente y su valor es `null`, devolver "Sin categorizar" en el label (ej. `"Gastos sin categorizar del 2026-06-01 al 2026-06-11"`). Hoy `isset` falla con null, así que el bucket nunca se reconoce como "Sin categorizar" y el label queda genérico. Usar `array_key_exists` aquí también.

4. **Frontend `pruneFilters`**: tratar `category_id` como caso especial. Si la key `category_id` existe en `props.filters` y el valor es `null`, preservarla en el output (mandar `null` al backend). Para el resto de las keys, mantener el comportamiento actual (descarte de `null`/`undefined`/`''`). Implementación: `Object.prototype.hasOwnProperty.call(f, 'category_id') && f.category_id === null` → preservar.

### Por qué este enfoque

- **Cero superficie nueva**: el contrato JSON del endpoint no cambia. El cliente sigue mandando los mismos campos. Solo cambia la *semántica* de dos valores (`category_id=null` y `kind=expense`).
- **Coherencia con los Services**: hoy los Report Services suman `expense + credit_expense`; el endpoint queda alineado.
- **Bonus en `/entries`**: `listEntries` reusa `applyEntryFilters`. El cambio mejora la consistencia del filtro "Tipo = Gasto" en `/entries` (incluye cargos a tarjeta), comportamiento documentado como deseable en la spec.

## Requisitos funcionales cubiertos

- **RF-001**: validación pasa a `'sometimes', 'nullable', 'uuid', 'exists:...'`. Laravel acepta `null` y omite la regla `exists` cuando el valor es `null`.
- **RF-002**: `applyEntryFilters` aplica `whereNull('journal_entries.category_id')` cuando la key existe y el valor es `null`.
- **RF-003**: `applyEntryFilters` aplica `whereIn('journal_entries.kind', ['expense', 'credit_expense'])` cuando recibe `kind=expense`.
- **RF-004**: cualquier otro `kind` mantiene `where('journal_entries.kind', $value)` literal (no se modifica esa rama).
- **RF-005**: `array_key_exists` reemplaza a `isset` solo en la rama de `category_id` dentro de `applyEntryFilters` y dentro de `buildBucketLabel`. Las otras keys (`account_id`, `kind`, `from`, `to`) siguen usando `isset` porque no admiten valor `null` semánticamente.
- **RF-006**: `pruneFilters` en `EntriesDrilldownModal.vue` preserva `category_id: null` explícito.
- **RF-007**: el chequeo `if (empty($data))` para `missing_filters` sigue funcionando: PHP `empty(['category_id' => null])` devuelve `false` (el array no está vacío).
- **RF-008**: `buildBucketLabel` agrega "sin categorizar" al label cuando `category_id` presente y `null`. La parte literal del cambio: condición `if (array_key_exists('category_id', $filters))` con sub-rama para `null`.
- **RF-009**: el contrato JSON (`entries`, `truncated`, `total_count`, `bucket_label`) no se toca.

## Archivos o modulos probablemente afectados

Backend (modificados):

- `backend/app/Http/Controllers/FinanceController.php`:
  - Método `entriesByBucket` (validación de `category_id`).
  - Método `applyEntryFilters` (helper privado).
  - Método `buildBucketLabel` (helper privado).
  - Sin tocar `listEntries`, `reportByCategory`, ni ningún otro método.

Backend (tests ampliados):

- `backend/tests/Feature/Http/EntriesByBucketTest.php`: +5 tests.
- `backend/tests/Feature/Http/FinanceApiTest.php`: verificar que `test_entries_endpoint_paginates_and_filters` no rompa (probablemente no se modifica, pero confirmar al implementar).

Frontend (modificados):

- `frontend/src/components/finance/EntriesDrilldownModal.vue`: función `pruneFilters`.

Frontend (tests ampliados):

- `frontend/tests/components/EntriesDrilldownModal.spec.js`: +2 tests.

Sin cambios:

- Report Services en `app/Domain/Finance/Reports/*` (siguen sumando `expense + credit_expense`).
- Las 7 vistas que abren `EntriesDrilldownModal` (siguen pasando los mismos filtros).
- `EntriesTable.vue` (no usa pruneFilters).
- Migraciones, modelos, listEntries, otros endpoints.
- `CLAUDE.md` (contrato no cambia; semántica nueva se documenta en `docs/api/reports.md`).

## Entidades y estados afectados

Ninguna entidad de dominio cambia. Los estados, soft delete y scopes existentes siguen aplicando:

- `JournalEntry::SoftDeletes` excluye cancelados.
- `Account::SoftDeletes` no afecta el filtro `account_id` del endpoint (validación con `exists` tolerante al estado).
- `Category::SoftDeletes` no aplica al filtro del endpoint (mismo patrón).

Invariantes:

- Scope por `user_id` se mantiene en todas las queries.
- `category_id` validado con `exists:categories,id,user_id,$userId` cuando es UUID; cuando es `null`, la regla `exists` se omite por Laravel (consecuencia de `nullable`).
- `kind=expense` ya no es estrictamente un valor del enum, sino un *grupo*. La semántica del enum literal sigue viva para los otros valores.

## Compatibilidad con datos y procesos existentes

- **Datos existentes**: cero cambios. No hay migración. Los entries siguen con sus `category_id` y `kind` actuales.
- **Endpoints existentes**:
  - `entriesByBucket`: cambio de semántica documentado.
  - `listEntries`: hereda automáticamente el cambio de `kind=expense` (deseable; ahora "Tipo = Gasto" en `/entries` incluye tarjeta).
  - Otros endpoints: sin cambios.
- **Report Services**: no cambian. Su semántica de "gastos = expense + credit_expense" ya era así. El endpoint queda alineado.
- **Frontend `/entries`**: el filtro de "Tipo" ya muestra `Gasto` como una opción. El cambio mejora su comportamiento. Sin cambio adicional en UI.
- **Tests previos**: 386 backend / 116 frontend. El test gate `test_entries_endpoint_paginates_and_filters` en `FinanceApiTest.php` probablemente NO usa `kind=expense` con expectativa de filtrar literal. Verificar al implementar.
- **E2E**: el spec `entries.spec.js` está marcado como desactualizado en el backlog. No bloquea este sprint.

## Cambios de datos

No aplica. Cambio puramente de comportamiento de queries de lectura.

## Cambios de API

Aditivos y de semántica. El contrato JSON no cambia:

- `GET /api/finance/reports/entries-by-bucket`:
  - `category_id=null` ahora se acepta y filtra entries sin categoría.
  - `kind=expense` ahora incluye `expense + credit_expense`.
  - Otros params y comportamientos sin cambios.

- `GET /api/finance/entries` (`listEntries`):
  - `kind=expense` ahora incluye `credit_expense` (hereda del helper). Sin cambios en otros filtros.

Sin nuevos endpoints, sin nuevos campos en la respuesta.

## Cambios de integraciones

No aplica.

## Cambios de UI

- `EntriesDrilldownModal.vue`: cambio interno en `pruneFilters`. Sin cambios visuales.
- Las 7 vistas (ByCategory, Cashflow, MonthComparison, CreditCards, Budgets, ByAccount, Forecast) siguen pasando los mismos filtros.
- `/entries`: el filtro "Tipo = Gasto" cambia su comportamiento (más entries devueltas), pero la UI no se ve distinta.

## Cambios de permisos

No aplica. El scope por `user_id` se mantiene en todas las queries.

## Riesgos tecnicos

- **`array_key_exists` vs `isset`** (riesgo mecánico): aplicar mal este cambio reintroduce el bug. Mitigación: tests específicos.
- **`exists:` con `nullable` y `null`**: en Laravel, `exists` se aplica sólo cuando el valor no es `null`. Verificar comportamiento empíricamente con un test que mande `category_id=null` válido (debe pasar validación).
- **`category_id` como string vacío `''` en query string**: la query string `?category_id=` puede llegar como `''` o como `null` dependiendo del request middleware. La validación `nullable` cubre ambos, pero el helper debe normalizar. Decisión de plan: si el valor es `''`, tratarlo igual que `null` (whereNull). El `pruneFilters` del frontend ya descarta `''` por convención, así que el caso ocurriría sólo en clientes externos. Documentar en tests.
- **Test gate `test_entries_endpoint_paginates_and_filters`**: si este test usa `kind=expense` y verifica que sólo trae `expense` puro (sin `credit_expense`), va a romper. Probablemente no — el test fue diseñado para validar paginación y filtros básicos. Confirmar al implementar.
- **Cambio en `/entries`**: usuarios que dependían del comportamiento "Tipo = Gasto sólo expense puro" verán entries adicionales. Probabilidad baja (FinCore es libreta personal, no hay clientes externos). Beneficio claro: consistencia con los reportes.
- **`buildBucketLabel`**: agregar "Sin categorizar" requiere cuidar el orden de las partes del label. Hoy el orden es `kind + categoria + cuenta + rango`. La nueva rama añade "Sin categorizar" en el lugar de "de Comida".
- **Frontend `pruneFilters`**: cambiar la lógica de poda puede afectar otros filtros si no se aísla bien al caso `category_id`. Mitigación: tests específicos cubren los otros campos.
- **Performance del `whereNull`**: PG sin índice específico hace scan parcial. Aceptable para FinCore.

## Estrategia de pruebas

- **Backend tests HTTP** en `EntriesByBucketTest.php`:
  - Drill-down con `category_id=null` filtra entries `category_id IS NULL`.
  - Drill-down con `kind=expense` incluye entries `credit_expense`.
  - Drill-down con `kind=credit_expense` literal (no mezcla con expense).
  - Drill-down con `kind=income` literal.
  - `bucket_label` con `category_id=null` contiene "sin categorizar" o equivalente.
  - Combinación `category_id=null + kind=expense` filtra correctamente.
- **Backend tests de regresión**: correr la suite completa para garantizar que `EntriesByBucketTest` actuales (14 tests) y `FinanceApiTest::test_entries_endpoint_paginates_and_filters` no rompan.
- **Frontend tests** en `EntriesDrilldownModal.spec.js`:
  - `pruneFilters({ category_id: null, kind: 'expense' })` preserva `category_id: null`.
  - `pruneFilters({ kind: 'expense' })` (sin key) no inserta la key.
  - `pruneFilters({ category_id: '', kind: 'expense' })` descarta `category_id` (consistente con regla "vacíos se descartan").
- **Smoke con Playwright**:
  - Login + seed con entries sin categoría + categoría con credit_expense.
  - `/reports/by-category` → click "Sin categorizar" → modal con entries correctas.
  - `/reports/forecast` → click bucket con credit_expense → modal incluye entries credit_expense.
  - `/entries` con filtro "Tipo = Gasto" → ahora muestra también credit_expense (verificable).

## Estrategia de rollback

Revertir los commits. Cero estado persistido. Cero migraciones. Cero impacto en datos.

## Orden sugerido de implementacion

1. Backend: cambiar validación en `entriesByBucket`. Test inicial: `category_id=null` no devuelve 422.
2. Backend: cambiar `applyEntryFilters` para `category_id` (array_key_exists + whereNull). Test: filtro correcto.
3. Backend: cambiar `applyEntryFilters` para `kind=expense` (whereIn). Test: incluye credit_expense.
4. Backend: cambiar `buildBucketLabel` para "Sin categorizar". Test: label correcto.
5. Backend: correr suite completa, asegurar 386+ tests verde.
6. Frontend: cambiar `pruneFilters` en el modal. Test: preserva null explícito.
7. Frontend: correr suite completa, asegurar 116+ tests verde.
8. Smoke con Playwright real con dataset seedeado.
9. Pint sobre archivos modificados.
10. QR con `branch-quality-review`.

## Casos borde que condicionan la solucion

- Día 1 del mes con `category_id=null`: combinación válida; entries sin categoría del día 1.
- `kind=expense` + `category_id=null` + sin rango: trae todas las entries de expense/credit_expense sin categoría de toda la historia (con cap 100).
- `kind=expense` + categoría archivada: trae entries de la categoría incluyendo credit_expense.
- `kind=credit_expense` literal: NO se mezcla. Importante para `/reports/credit-cards`.
- `pruneFilters` con tipo inesperado en `category_id` (ej. número): preserva si no es null/undefined/'', se descarta si lo es. Documentar.
- Cliente externo manda `category_id=null` directo al endpoint: ahora funciona; antes daba comportamiento incorrecto silencioso (devolvía toda la base).
- `listEntries` (paginado de `/entries`) recibe `kind=expense`: hereda whereIn. Sin cambios de contrato.

## Preguntas o supuestos que siguen afectando la implementacion

- **Comportamiento de Laravel con `exists:` + `nullable` + `null`**: asumido que Laravel salta la regla `exists` cuando el valor es `null` (es el comportamiento estándar). Verificar al implementar con un test directo.
- **`buildBucketLabel` con cambio de orden**: si el formato actual es `"Gastos del 2026-06-01 al 2026-06-11"` para un kind sin category_id, la nueva versión con `category_id=null` será `"Gastos sin categorizar del 2026-06-01 al 2026-06-11"`. Mantener orden.
- **Frontend `pruneFilters` y otros filtros con `null`**: la regla queda específica para `category_id`. Los demás filtros (account_id, kind, from, to) siguen descartando `null`. Si en el futuro otro filtro necesita la misma semántica, se extiende.
- **`/entries` con filtro "Tipo = Gasto"**: este sprint mejora el filtro. Verificar smoke que no rompa nada visual.
- **El test gate `test_entries_endpoint_paginates_and_filters`**: confirmar al implementar; si usa `kind=expense` con expectativa literal, ajustarlo.

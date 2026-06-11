# Progreso de implementación

Todas las tareas T001..T019 completadas. Sin pendientes del sprint.

## Tareas completadas

### Backend (T001-T012)

- [x] T001 — Validación de `category_id` con `'nullable'`.
- [x] T002 — `applyEntryFilters`: rama `category_id` con `array_key_exists` + `whereNull`/`where`.
- [x] T003 — `applyEntryFilters`: rama `kind=expense` con `whereIn`.
- [x] T004 — `buildBucketLabel`: rama `category_id` con `array_key_exists` + "sin categorizar".
- [x] T005 — Confirmado: `empty($data)` con `category_id: null` sigue funcionando (PHP `empty(['category_id'=>null])` = false).
- [x] T006 — `test_category_id_null_filters_uncategorized_entries`.
- [x] T007 — `test_kind_expense_includes_credit_expense`.
- [x] T008 — `test_kind_credit_expense_literal_does_not_mix_with_expense`.
- [x] T009 — `test_kind_income_literal` y `test_kind_transfer_literal`.
- [x] T010 — `test_bucket_label_includes_sin_categorizar_when_category_id_is_null`.
- [x] T011 — 14 tests existentes de EntriesByBucketTest siguen verde sin ajuste.
- [x] T012 — `test_entries_endpoint_paginates_and_filters` de `FinanceApiTest` sigue verde sin ajuste.

### Backend extra (no en plan original)

- [x] D-001 — Fix emergente del rango `to`: aplicar `<= $to.' 23:59:59'`. Descubierto durante smoke porque el bucket "Comida" y su drill-down no cuadraban. Documentado en `desviaciones-plan.md`.

### Frontend (T013-T014)

- [x] T013 — `pruneFilters`: caso especial para `category_id: null` → `''` (workaround axios, documentado en `desviaciones-plan.md` D-002).
- [x] T014 — 5 → 8 tests del modal (2 ajustados, 3 nuevos).

### Validación (T015-T019)

- [x] T015 — Suite backend completa: 394/394 verde.
- [x] T016 — Suite frontend completa: 119/119 verde.
- [x] T017 — Pint sin diffs en archivos del sprint.
- [x] T018 — Smoke real con Playwright: P1 (bucket "Sin categorizar" filtra correctamente, title "Gastos sin categorizar del X al Y") ✓; P2 (bucket "Comida" muestra expense + credit_expense, total cuadra exactamente) ✓.
- [x] T019 — `branch-quality-review` ejecutado. Reporte en `engineering/quality-review/entries-by-bucket-fixes/2026-06-11-1748-branch-quality-review.md`. 0 bloqueantes del sprint; 2 medios preexistentes documentados (M1 "Ir a Movimientos" desde "Sin categorizar", M2 bucket "Otras").

## Validación previa de consistencia

Sin hallazgos bloqueantes. Plan, spec y test-plan alineados.

## Estado de pruebas

- Backend: 394 tests, 942 assertions, ~5.6s.
- Frontend: 119 tests, ~3.3s.
- Smoke Playwright real: 2/2 escenarios principales validados (P1, P2).
- Pint: limpio.
- Quality review: 0 bloqueantes, 0 altos del sprint, 2 medios preexistentes documentados, 3 bajos opcionales.

## Decisión durante el QR

Se intentó incluir el fix completo del flujo "Ir a Movimientos" desde el bucket "Sin categorizar" (validación listEntries + EntriesTable + UI BaseSelect). Se descartó por exceder alcance: requiere una opción "Sin categorizar" en el BaseSelect de filtros + sentinel value para distinguir "filtrar = sin categoría" de "no filtrar". Revertido y documentado para sprint chico futuro. Detalles en `desviaciones-plan.md` D-003.

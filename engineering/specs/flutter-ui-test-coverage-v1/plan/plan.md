# Plan — flutter-ui-test-coverage-v1

## Estrategia

5 fases secuenciales en orden de **valor descendente** (acordado con Diego):

1. RF-019 — gap RN-011 (mayor riesgo bug latente).
2. RF-023 — settings destructivas (warm-up barato).
3. RF-021 — entries_list bottom sheet filtros.
4. RF-022 — category_form preview live.
5. RF-020 — accounts CRUD (el más laborioso por debug pendiente del v4).
6. Release 0.3.9+41 + cierre.

Cada fase termina con `flutter test` verde antes de la siguiente. Si una fase se cuelga >30 min sin progreso, se difiere y se documenta como desviación.

## Fases

### Fase 1 — RF-019 (validar patrón de DropdownMenu)

- Test piloto con Ingreso (validar que `find.ancestor(text → DropdownMenu)` + tap funciona).
- Si el piloto pasa, aplicar a los 4 kinds restantes.
- Helpers `openDropdownByLabel` y `verifyDropdownItems` en `widget_test_harness.dart`.

### Fase 2 — RF-023

- 2 tests: reset destructivo + tap categorías.
- Sin `pumpAndSettle` en Settings porque PackageInfo.fromPlatform() nunca resuelve.

### Fase 3 — RF-021

- 3 tests: render de 5 entries + filtro income + limpiar filtro.
- `pumpAndSettle` después del bottom sheet sí funciona (el bottom sheet completa su animación).

### Fase 4 — RF-022

- 3 tests: preview placeholder + preview live + submit persiste.
- `scrollUntilVisible` para botón "Crear categoría" que está fuera del viewport.

### Fase 5 — RF-020

- 3 tests: monta form + alta de debit + edición persiste.
- El cuelgue del v4 era falta de `scrollUntilVisible` para el botón submit. Resuelto con el patrón identificado en Fase 4.

### Fase 6 — Release y cierre

- Bump 0.3.9+41.
- Build APK + verify-apk.sh.
- Docs implementation/ + quality review v4 → branch-quality-review.
- Commits + push.

## Mapeo RF → tests resultantes

| RF | Tests nuevos | Total |
|----|--------------|-------|
| RF-019 (modifica 3 existentes) | 0 nuevos, 3 ampliados | — |
| RF-023 | 2 | 2 |
| RF-021 | 3 | 5 |
| RF-022 | 3 | 8 |
| RF-020 | 3 | 11 |

**Suite final estimada:** 112 → 123 verdes.

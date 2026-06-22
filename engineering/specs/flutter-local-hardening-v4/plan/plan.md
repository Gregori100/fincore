# Plan — flutter-local-hardening-v4

## Estrategia

25 RFs en 6 fases secuenciales. La Fase 1 es la más sensible (refactor que toca el constructor de `EntriesDao`); se ataca primero para validar el plan técnico. Después escala en complejidad decreciente.

## Fases

### Fase 1 — Refactor EntriesDao + @DriftDatabase (RF-001 a RF-006)

Orden:
1. Extraer `accountBalanceAtomic` función pura.
2. `FinancialStateService.accountBalanceNow` wrapper.
3. `EntriesDao` quita `_state`, usa función pura.
4. Registrar en `@DriftDatabase(daos:)`.
5. `dart run build_runner build --delete-conflicting-outputs`.
6. `AppDependencies.fromDatabase` → `database.entriesDao`.
7. Suite verde después de cada paso.

**Criterio de salida:** suite original (110) sigue verde + analyze limpio + `database.entriesDao` accesible.

### Fase 2 — Replay-1 BO/DE/CR (RF-007, RF-008, RF-009)

- 3 fields lazy en `FinancialStateService`.
- `invalidateAll()` actualizado.
- Test defensivo de identity + replay-1.

**Criterio de salida:** suite ≥ 111.

### Fase 3 — Cluster de Baja (RF-010 a RF-018)

9 fixes pequeños. Orden por archivo para minimizar re-lectura:
- `widget_test_harness.dart`: RF-010, RF-011, RF-013.
- `entry_form_screen_test.dart`: RF-012.
- `financial_state.dart`: RF-014, RF-015.
- `verify-apk.sh`: RF-016, RF-017, RF-018.

**Criterio de salida:** suite ≥ 111 (los cambios no agregan tests, solo mejoran robustez).

### Fase 4 — Gap RN-011 (RF-019)

Ampliar `entry_form_kinds_test.dart`. Los 5 tests ahora abren el dropdown.

**Criterio de salida:** suite ≥ 111 (los tests existentes ahora cubren más, no se agregan nuevos archivos).

### Fase 5 — Widget tests profundos del CRUD (RF-020 a RF-023)

4 archivos nuevos:
- `account_form_screen_test.dart`: ~4 tests.
- `entries_list_screen_test.dart`: ~3 tests.
- `category_form_screen_test.dart`: ~3 tests.
- `settings_screen_test.dart`: ~2 tests.

**Total estimado:** ~12 tests nuevos.

**Criterio de salida:** suite ≥ 123. Si llegamos a 130+ mejor.

### Fase 6 — Release (RF-024, RF-025)

- Bump 0.3.8+40.
- Build APK + verify.

### Fase 7 — Cierre

- Docs `implementation/`.
- `branch-quality-review` v4.
- Commits + push.

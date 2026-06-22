# Branch quality review — flutter-local-hardening-v4

**Fecha:** 2026-06-22 17:00
**Rama:** main (working tree con cambios uncommitted del sprint v4)
**Base de comparación:** HEAD = `52d55c3` (commit final del v3)
**Slug:** flutter-local-hardening-v4
**Revisores:** 2 subagentes en paralelo
- Lane 1 (código: refactor + replay-1 + DV-5) — Sonnet
- Lane 2 (docs y trazabilidad) — Haiku

## Resumen ejecutivo

- **Hallazgos totales:** 6 (0 bloqueantes, 1 Media, 5 Baja/crítica menor).
- **EntriesDao @DriftDatabase** validado correcto.
- **Replay-1 en BO/DE/CR** validado correcto.
- **DV-5 (NO invalidateAll en cleanup)** validado correcto y consistente en todos los docs.
- **Aplicados in-sprint:** 4 (M1, B1, L4-H1, L4-H3).
- **Diferidos:** 2 (L1-B2 import notación, sugerencias opcionales de docs).

Sin bloqueantes para commit + push del v4.

## Hallazgos por lane

### Lane 1 — Código

| ID | Sev | Path:línea | Descripción |
|----|-----|-----------|-------------|
| L1-M1 | Media | `test/data/financial_state_test.dart:128,142,165,180,182` | 6 invocaciones de `await stream.firstWhere(...)` sin `.timeout()`. Si drift no emite el valor esperado, el test cuelga el isolate. **Fix:** `.timeout(Duration(seconds: 5))` en cada llamada. |
| L1-B1 | Baja | `lib/data/financial_state.dart:214` | `SELECT type FROM accounts WHERE id = ?` sin `AND deleted_at IS NULL`. En producción no hay riesgo (EntriesDao valida tipo antes), pero blindar contra futuras integraciones. **Fix:** agregar el filtro. |
| L1-B2 | Baja | `lib/data/daos/entries_dao.dart` | Import de `financial_state.dart` necesario para `accountBalanceAtomic` da impresión de acoplamiento. Sin impacto funcional, queda como nota de legibilidad. |

**Validaciones positivas:**
- `EntriesDao(super.db)` con `attachedDatabase` en `transaction()` mantiene atomicidad del OverpayDebt check + insert.
- Replay-1 con `_boCache ??= _ReplayBalanceStream(...)` preserva identidad referencial, `invalidateAll()` libera los 3 caches.
- DV-5 aplicado consistente en 4 suites de datos + harness.
- `assert(!(seedBolsa && initialRoute == '/first-run'))` convierte error silencioso del v3 en explícito.
- 3 fixes de `verify-apk.sh` (RF-016/017/018) correctos.

### Lane 2 — Docs

| ID | Sev | Archivo:sección | Descripción |
|----|-----|-----------------|-------------|
| L4-H1 | Crítica menor | `CLAUDE.md:40` | "# 110 tests" obsoleto. Hoy son 112. |
| L4-H2 | Baja | `resumen-ejecutivo.md:51` | "suite pasa de >40 min a 6-12 segundos" no clarifica que >40 min era con el falso fix. Lector sin contexto puede confundirse. |
| L4-H3 | Baja | `pendientes.md:68-69` | Sección decía "Patrón `state.invalidateAll() + db.close()`" — contradice DV-5. Debería ser contraconvención. |

**Validaciones positivas:**
- DV-5 narrado consistentemente en `progreso.md`, `desviaciones-plan.md`, `resumen-ejecutivo.md`, `resumen-extenso.md`. 4 versiones del mismo hallazgo sin contradecirse.
- 19/25 RFs entregados con trazabilidad clara spec → plan → progreso.
- DV-1 y DV-2 (Fases 4 y 5 diferidas) tienen detalle suficiente para sprint dedicado.
- CLAUDE.md ya incluye la contraconvención DV-5 correcta.

**Sugerencias opcionales (no aplicadas):**
- DV-3 título podría ser "RF-010 revertido a booleano simple" en lugar de "simplificación".
- Tabla de diferidos v4 vs heredados v3 en pendientes.md ayudaría al lector rápido.
- T020 (smoke) podría aparecer en tabla de progreso.md, no solo en pendientes.

## Decisión: qué se aplica in-sprint vs qué se difiere

### Aplicados in-sprint

| # | Hallazgo | Cambio |
|---|----------|--------|
| F1 | L1-M1 | `.timeout(Duration(seconds: 5))` en las 5 invocaciones de `firstWhere` (líneas 128, 142, 165, 180, 182) |
| F2 | L1-B1 | `AND deleted_at IS NULL` en SQL de `accountBalanceAtomic` |
| F3 | L4-H1 | "# 112 tests" en CLAUDE.md línea 40 |
| F4 | L4-H3 | `pendientes.md` corregida con la contraconvención DV-5 |

### Diferidos

| # | Hallazgo | Razón |
|---|----------|-------|
| D1 | L1-B2 | Import necesario, sin impacto funcional. Solo notación. |
| D2 | L4-H2 | Aclaración semántica menor en resumen ejecutivo. Lector con contexto ya lo entiende. |
| D3 | Sugerencias opcionales de docs | Polishing aditivo, no afecta correctness. |

## Validación final post-fixes

```
flutter test     → 112/112 verdes
flutter analyze  → 0 errores, 0 warnings, 4 hints info preexistentes
scripts/verify-apk.sh app-arm64-v8a-release.apk → exit 0 (versionCode=2040)
```

## Limitaciones de esta revisión

- Las 2 lanes no ejecutaron tests; verificación final pre-commit.
- No se construyó APK nuevo después de los fixes M1+B1 (los cambios son tests + 1 línea SQL, no afectan runtime de producción salvo el filtro `deleted_at`).
- Lane 2 no examinó cada línea de los 6 docs del v4; solo verificó consistencia macro de DV-5 y trazabilidad RF.
- No se invocó `git log` para detectar regresiones cross-sprint.

# Branch Quality Review: flutter-local-hardening-v4

## Metadata

- Fecha: 2026-06-22
- Rama revisada: main (working tree uncommitted)
- Rama base: HEAD (`52d55c3` — sprint flutter-local-hardening-v3)
- Rango: working tree vs HEAD
- Commit HEAD: 52d55c3
- Autor de revision: branch-quality-review skill
- Carpeta de reporte: `engineering/quality-review/flutter-local-hardening-v4/`

---

## Resumen ejecutivo

- **19 de 25 RFs entregados.** Las 6 diferidas (RF-019, RF-020–RF-023, RF-014 parcial) tienen documentación de bloqueo suficiente para un sprint dedicado.
- **El refactor principal (RF-001–RF-005) está bien ejecutado:** `EntriesDao` sin `FinancialStateService`, `accountBalanceAtomic` como función pura top-level, y los 3 DAOs ahora vía codegen. Sin dobles instancias.
- **Replay-1 en BO/DE/CR (RF-007/008):** correcto. Los 3 campos lazy liberan en `invalidateAll()`. Identidad referencial probada por test. Los `firstWhere` en los tests de stream afectados no tienen `.timeout()` — riesgo de cuelgue si el valor esperado nunca llega (hallazgo Media).
- **DV-5 (NO invalidateAll en tearDown) correctamente aplicado** en todos los tearDowns y en el `dispose()` del harness. La justificación técnica es sólida.
- **RF-014 descartado correctamente:** la causa técnica del timeout (`hasListener` falso durante init del `MultiStreamController`) está documentada y verificable.
- **Rama entregable** con un ajuste Baja recomendado (`firstWhere` + timeout de seguridad) y dos notas de seguimiento.

---

## Alcance revisado

- **Commits:** working tree vs HEAD (sprint completo uncommitted)
- **Archivos principales:** 16 archivos modificados (+263 / −74)
  - `mobile/lib/data/financial_state.dart`
  - `mobile/lib/data/daos/entries_dao.dart`
  - `mobile/lib/data/database.dart`
  - `mobile/lib/app_dependencies.dart`
  - `mobile/lib/data/database.g.dart`
  - `mobile/test/helpers/widget_test_harness.dart`
  - `mobile/test/screens/entry_form_screen_test.dart`
  - `mobile/test/screens/entry_form_kinds_test.dart`
  - `mobile/test/data/{database,backup,financial_state,invariants}_test.dart`
  - `scripts/verify-apk.sh`
  - `mobile/pubspec.yaml`, `mobile/android/app/build.gradle.kts`, `CLAUDE.md`
- **Areas:** arquitectura/datos, pruebas, tooling de release
- **Comandos usados:** `git diff --stat HEAD`, `git diff HEAD -- <file>`, `grep`, lectura directa de archivos fuente

---

## Hallazgos bloqueantes

_Ninguno._

---

## Hallazgos no bloqueantes

### M1. `firstWhere` sin `.timeout()` — riesgo de cuelgue en tests de stream

- **Severidad:** Media
- **Area:** Pruebas / `financial_state_test.dart`
- **Evidencia:**
  ```dart
  // líneas 128, 142, 165, 180, 182
  expect(await state.watchBo().firstWhere((v) => v == 0), 0);
  expect(await state.watchCr().firstWhere((v) => v == 0), 0);
  ```
  Ninguna de las 6 invocaciones tiene `.timeout(Duration(...))`. Si drift no emite el valor esperado (por bug en el SQL, race en in-memory SQLite o cancelación prematura de la suscripción), el test bloquea el isolate indefinidamente hasta que el runner lo mate por timeout global.
- **Impacto:** Suite se cuelga silenciosamente en CI si el valor esperado nunca llega; el error no aparece con evidencia concreta del test fallido.
- **Recomendacion:**
  ```dart
  expect(
    await state.watchBo().firstWhere((v) => v == 0)
        .timeout(const Duration(seconds: 5)),
    0,
  );
  ```
  El timeout de 5 s es suficiente para in-memory SQLite; hace el fallo rápido y con mensaje claro.
- **Depende de:** ninguno.

### B1 (bajado a Baja). `accountBalanceAtomic` — `SELECT type FROM accounts` sin filtro `deleted_at`

- **Severidad:** Baja
- **Area:** Arquitectura / `financial_state.dart:214`
- **Evidencia:**
  ```sql
  SELECT type FROM accounts WHERE id = ? LIMIT 1
  ```
  No filtra `deleted_at IS NULL`. Para `registerDebtPayment` (el único caller del DAO), esto no es un riesgo real: `_validateAccountTypes` (línea 418) ya lanza `invalid_account_type` si la cuenta destino tiene `deletedAt != null`, y esa validación ocurre **antes** de entrar a la transacción que llama `accountBalanceAtomic`. La cuenta archivada nunca llega al `accountBalanceAtomic` del DAO en producción.
  
  El riesgo existe si en el futuro se agrega un caller que omita la validación previa.
- **Impacto:** ninguno en el código actual. Deuda técnica latente si se añaden nuevos callers.
- **Recomendacion:**
  ```sql
  SELECT type FROM accounts WHERE id = ? AND deleted_at IS NULL LIMIT 1
  ```
  Cero costo, elimina la deuda preventivamente.
- **Depende de:** ninguno.

### B2 (Baja). `FinancialStateService` todavía importado en `entries_dao.dart` aunque solo queda el import

- **Severidad:** Baja
- **Area:** Limpieza / `mobile/lib/data/daos/entries_dao.dart:3`
- **Evidencia:**
  ```dart
  import 'package:fincore/data/financial_state.dart';
  ```
  El import es necesario para `accountBalanceAtomic` (función pura top-level en ese archivo). No es un import muerto — es correcto. Sin embargo, el nombre del import da la impresión de que el DAO sigue acoplado al *service*; el comentario del constructor (líneas 38–42) aclara, pero alguien haciendo un grep de "FinancialStateService" en el DAO podría confundirse.
- **Impacto:** ninguno funcional. Potencial confusión de lectura.
- **Recomendacion:** sin cambio obligatorio. Si se quiere máxima claridad, mover `accountBalanceAtomic` a su propio archivo `account_balance_atomic.dart` en `data/` — pero es un cambio de organización, no un fix. Documentar en `pendientes.md` si aplica.
- **Depende de:** ninguno.

---

## Validaciones positivas

- **`EntriesDao(super.db)` sin `_state`:** correcto. `attachedDatabase` expone el mismo executor que `db`, así que `accountBalanceAtomic(attachedDatabase, ...)` dentro de `transaction(...)` usa la misma conexión y garantiza atomicidad con el insert. No hay riesgo de dead-lock de second connection.

- **Replay-1 en BO/DE/CR con `_boCache ??=`:** pattern correcto. Lazy init, identidad referencial preservada, `invalidateAll()` libera los 3 caches correctamente con `?.dispose(); = null`. El test RF-009 valida `identical(bo1, bo2)` y el replay tras cancel/resubscribe.

- **DV-5 aplicado consistentemente:** `dispose()` del harness llama solo `database.close()`. Todos los tearDowns de las 4 suites de datos hacen `db.close()` sin `invalidateAll()`. El razonamiento (cerrar `MultiStreamController` con listeners activos genera microtasks pendientes que cuelgan `pumpAndSettle`) está documentado en `CLAUDE.md` y en `desviaciones-plan.md`.

- **`assert` en `pumpFincoreApp` (RF-011):** el guard `!(seedBolsa && initialRoute == '/first-run')` convierte una inconsistencia silenciosa en un error explícito en modo debug. La rama condicional previa que forzaba la navegación aunque fuera ambigua fue eliminada limpiamente.

- **`verify-apk.sh` fixes (RF-016/017/018):** `find -maxdepth 2` cubre el path `build-tools/<version>/aapt2` correctamente (profundidad 2 relativa al directorio `build-tools`). `tr -d "'\""`es idempotente si no hay comillas. El charset `['\"]` en sed maneja ambos estilos de salida de aapt2 sin romper el caso mayoritario (comillas simples).

---

## Plan de corrección ordenado

1. **(Baja, opcional-preventivo)** Agregar `AND deleted_at IS NULL` al `SELECT type FROM accounts` en `accountBalanceAtomic` — `mobile/lib/data/financial_state.dart:214`.
2. **(Media, recomendado)** Agregar `.timeout(const Duration(seconds: 5))` a los 6 `firstWhere(...)` en `mobile/test/data/financial_state_test.dart` (líneas 128, 142, 165, 180, 182).
3. **(Baja, diferida)** Evaluar mover `accountBalanceAtomic` a archivo propio para separar concern del import de `financial_state.dart` en `entries_dao.dart`. Agregar a `pendientes.md` si se decide no hacer ahora.
4. **(Diferidos confirmados)** RF-019 (tests DropdownMenu), RF-020–RF-023 (widget tests CRUD) — sprint `flutter-test-coverage-v1`.
5. Smoke manual `0.3.8+40` en Redmi (T020 de `pendientes.md`).

---

## Validaciones recomendadas

```bash
cd mobile
flutter analyze                          # debe dar 0 errores
flutter test                             # debe dar 112 tests verdes
bash scripts/verify-apk.sh build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

---

## Limitaciones

- No se ejecutaron `flutter test` ni `flutter analyze` — verificación estática solo.
- No se construyó el APK de release para validar el script `verify-apk.sh` contra un binario real.
- La condición de `firstWhere` sin timeout no se probó en CI; el riesgo es teórico pero accionable.
- No se revisaron `mobile/lib/screens/` ni widgets de UI — los cambios del v4 son exclusivamente de capa de datos, harness y tooling.

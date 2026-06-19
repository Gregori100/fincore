# Resumen extenso — flutter-local-hardening-v2

## Contexto

Sprint técnico de cleanup. Continuación del sprint `flutter-local-hardening` cerrado en commit `ecb9893` con APK `0.3.0+32`. Aquel sprint resolvió 20+3 bloqueantes detectados en el quality review previo y dejó 9 hallazgos no bloqueantes documentados en su `pendientes.md`. Este sprint cierra esos 9 ítems + 1 test de regresión descubierto durante el smoke (categorías archivadas con badge fantasma en `watchPage`).

Sin features visibles. Objetivo: dejar el codebase listo para el próximo sprint de funcionalidades sin deuda residual del MVP ni del hardening.

## Relación con `plan/plan.md` y `plan/tasks.md`

- `spec.md` definió 13 RFs en 6 familias: Robustez de streams (RF-001/002), Tests adicionales (RF-003..006), Codegen drift (RF-007/008), UX (RF-009/010), Backup robustez (RF-011), Documentación (RF-012/013).
- `plan/plan.md` agrupó los 13 RFs en 17 tareas T001..T017, ordenadas en 6 fases (codegen → refactors core + tests → refactors menores → docs → release → cierre).
- `plan/test-plan.md` definió 4 tests defensivos nuevos (RF-003..006) y la matriz de regresión.
- Implementación cubrió todas las tareas excepto T015 (smoke manual de Diego) y T017 (branch-quality-review). 16 de 17 cerradas en sesión.

## Cambios principales por módulo o capa

### `lib/data/`

- `database.dart`: `@DriftDatabase(tables: [...])` extendido a `daos: [AccountsDao, CategoriesDao]`. `EntriesDao` queda fuera por incompatibilidad de constructor con codegen — documentado en comentario inline + en `desviaciones-plan.md` del sprint.
- `database.g.dart`: regenerado con `dart run build_runner build --delete-conflicting-outputs`.
- `daos/entries_dao.dart`: en `updateEntry`, query inline `(select(categories)..where((c) => c.id.equals(...) & c.deletedAt.isNull())).getSingleOrNull()` reemplazada por `attachedDatabase.categoriesDao.findActiveById(effectiveCategoryId)`. RN-H03 conservado.
- `financial_state.dart`: `_balanceCache` ahora cachea `Stream<double>` envueltos con `.asBroadcastStream()`. Comentario explica el motivo (`StateError: Stream has already been listened to` cuando dos widgets se suscriben al mismo balance).
- `backup.dart`: import de `package:characters/characters.dart`. `_validateUuid` y `_parseDate` ahora truncan previews con `value.characters.take(N).toString()` en lugar de `substring(0, N)`. Esto previene partir surrogates UTF-16 cuando el valor inválido contiene emojis o caracteres multi-byte.

### `lib/widgets/`

- `error_snackbar.dart`: `_buildFincoreSnackBar` ahora recibe `foreground` como parámetro requerido. Los 3 helpers públicos (`showError/Success/WarningSnackbar`) calculan el color según intención y lo pasan explícitamente. Antes se infería con `background == FincoreColors.warning`, lo que rompía si un caller pasaba una variante con `withValues(alpha: ...)`.

### `lib/screens/`

- `settings_screen.dart`: `Share.shareXFiles(...)` envuelto en `.timeout(Duration(minutes: 2), onTimeout: () => const ShareResult('timeout', ShareResultStatus.unavailable))`. Si el share sheet del sistema no resuelve en 2 minutos, el flujo trata el timeout como cancelación: `_working = false` y mensaje de warning al usuario.

### `test/`

- `backup_test.dart`: nuevo test "Import con name de 200 chars exactos pasa validación de longitud" (RF-003). Defensa del límite inclusivo. Junto con los tests existentes de 0 y 201 chars cubre el caso borde.
- `financial_state_test.dart`: dos nuevos tests. (a) "wipeAll invalida cache de streams" (RF-004): tras `backup.wipeAll()`, la próxima `watchAccountBalance` retorna un Stream distinto al anterior. (b) "watchAccountBalance cacheado acepta múltiples suscriptores" (RF-006): dos listeners suscritos en paralelo reciben eventos; subcaso de cancel + resuscribir valida que la entrada del cache sigue viable.
- `database_test.dart`: nuevo test "watchPage no incluye badge para categorías archivadas" (RF-005). Defensa contra la regresión del smoke previo. Verifica que tras `categoriesDao.archive(id)`, el entry sigue teniendo `categoryId` pero el join devuelve `category: null`.
- `financial_state_test.dart`: `setUp` extendido con `late BackupService backup;` para soportar el test del cache + wipeAll.

### Documentación

- `mobile/README.md`: sección nueva "Importar respaldos: límites y validaciones" antes de "Filosofía". Tabla de 16 códigos de error tipados + lista de límites duros (`name ≤ 200`, `description ≤ 1000`, `amount > 0`, UUID v4/v7, ranges de credit metadata).
- `engineering/specs/flutter-local-hardening/implementation/desviaciones-plan.md`: 2 desviaciones menores agregadas (Fase 1: `isNull` ambiguo → `equals(null)`; Fase 1: `_buildPayload` → `buildPayload`).

### Tooling

- `pubspec.yaml`: `version: 0.3.1+33`.
- `android/app/build.gradle.kts`: `versionCode = 33`, `versionName = "0.3.1"`.

## Desviaciones respecto al plan

Documentadas en `implementation/desviaciones-plan.md`:

1. **Fase 0 — Registro parcial de DAOs**. Plan original esperaba registrar los 3 DAOs en `@DriftDatabase(daos: [...])`. Real: solo 2 (`AccountsDao`, `CategoriesDao`). `EntriesDao` tiene constructor `EntriesDao(super.db, this._state)` con 2 args y drift codegen genera solo `(db)`. Mitigación: el RF-008 (delegación al helper canónico) sigue cubierto porque solo necesita `attachedDatabase.categoriesDao`. `EntriesDao` continúa accesible vía `AppDependencies` sin cambio. Comentario inline en `database.dart` explica el motivo.

Resto del plan ejecutado tal cual.

## Pruebas realizadas y recomendadas

Realizadas:

- `flutter test`: 91/91 verdes. 4 tests nuevos del sprint pasan.
- `flutter analyze`: 0 errores (6 hints info preexistentes).
- `flutter build apk --release --split-per-abi`: build exitoso.
- Verificación con `aapt2 dump badging app-arm64-v8a-release.apk`: `versionCode='2033'`, `versionName='0.3.1'`, `minSdk=24`, `targetSdk=35`.

Recomendadas (pendientes):

- T015 — smoke manual en Redmi (Diego). Detalle en `pendientes.md`.
- T017 — `branch-quality-review` con slug `flutter-local-hardening-v2`. Si aparecen bloqueantes, resolver en sesión antes del commit final.
- Sprint futuro: widget test de bootstrap del `entry_form_screen` que cubra los 5 kinds.

## Riesgos residuales y posibles regresiones

- **`EntriesDao` no registrado en `@DriftDatabase`**: pequeña inconsistencia conceptual sin impacto funcional. Si en el futuro se decide invertir la dependencia (database expone `state`), se podría completar el registro. No urgente.
- **Broadcast stream sin `onCancel`**: T007 pasa, pero queda como riesgo si un caller cancela y resuscribe muy rápido. Plan: si en el futuro reaparece el `Bad state`, agregar `onCancel: (_) => invalidateAccount(accountId)` en `watchAccountBalance` y un test que valide el escenario.
- **Timeout de `Share.shareXFiles`**: 2 minutos es holgado pero finito. En el caso patológico el flujo trata el timeout como cancelación; el archivo temporal del export puede quedar en disco hasta que el SO limpie `getTemporaryDirectory()`.
- **`attachedDatabase.categoriesDao` vs query inline**: el comportamiento esperado de `findActiveById` (filtra por `c.id.equals(id) & c.deletedAt.isNull()`) coincide con la query inline previa. RN-H03 sigue cumpliéndose por completo.
- **Bump de versionCode con `--split-per-abi`**: Flutter prepende un código de arquitectura, así que arm64 termina en `2033`. Si Diego accidentalmente intenta instalar un APK con `versionCode` menor a `2033`, el sistema rechaza con `INSTALL_FAILED_VERSION_DOWNGRADE`. La sección de README.md sobre build release ya explica este patrón.

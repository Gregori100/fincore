# Branch Quality Review: flutter-local-hardening-v2

## Metadata

- Fecha: 2026-06-19 12:34
- Rama revisada: `main` (working tree, sin commit todavía)
- Rama base: `ecb9893` (cierre sprint `flutter-local-hardening`)
- Rango: working tree (14 archivos modificados + `engineering/specs/flutter-local-hardening-v2/` untracked)
- Commit HEAD: `ecb9893` (los cambios del sprint v2 aún no están commiteados)
- Autor de revisión: Claude Code (Opus 4.7 main loop + 4 subagentes Sonnet/Haiku)
- Carpeta de reporte: `engineering/quality-review/flutter-local-hardening-v2/`

## Resumen ejecutivo

- Sprint técnico cerrado. 13/13 RFs cubiertos en 16/17 tareas (T015 smoke manual pendiente para Diego).
- **No hay hallazgos bloqueantes.** Los dos candidatos a bloqueante de los subagentes (broadcast stream sin `onCancel` y duplicación de instancias de DAOs) fueron verificados manualmente y degradados.
- 91/91 tests verdes. 4 nuevos defensivos cubren los huecos detectados en el smoke previo. `flutter analyze` sin errores.
- APK release `0.3.1+33` verificado con `aapt2 dump badging` (`versionCode='2033'`, `versionName='0.3.1'`).
- 3 mejoras `Media` para considerar antes/después del commit: declarar `characters` como dependencia directa en `pubspec.yaml`, alinear `AppDependencies` con las instancias del codegen y endurecer el test de "200 chars exactos" para no aceptar verde por excepción ajena.
- Rama **entregable**. Recomiendo commit + smoke manual de Diego (T015) + decidir si se aplican las 3 mejoras `Media` ahora o se difieren a un follow-up.

## Alcance revisado

- Commits: ninguno aún (changes en working tree).
- Archivos principales:
  - `mobile/lib/data/database.dart`, `database.g.dart` (regenerado), `daos/entries_dao.dart`, `financial_state.dart`, `backup.dart`
  - `mobile/lib/widgets/error_snackbar.dart`, `lib/screens/settings_screen.dart`
  - `mobile/test/data/{backup,database,financial_state}_test.dart`
  - `mobile/{pubspec.yaml,android/app/build.gradle.kts,README.md}`
  - `engineering/specs/flutter-local-hardening/implementation/desviaciones-plan.md`
  - `engineering/specs/flutter-local-hardening-v2/` (nuevo: spec, plan, implementation)
- Áreas: drift codegen, broadcast streams, validación de backup, UX snackbar, share_plus timeout, docs, release versioning, tests defensivos.
- Comandos usados:
  - `git status --short`, `git diff --stat HEAD`, `git diff HEAD -- <paths>`
  - `flutter test` (91 verdes), `flutter analyze` (0 errores, 6 hints info preexistentes)
  - `flutter build apk --release --split-per-abi`
  - `aapt2 dump badging app-arm64-v8a-release.apk`
  - Test directo en Dart 3.7.2 para validar semántica de `asBroadcastStream()` sin `onCancel`.
  - `grep` sobre `mobile/lib/app_dependencies.dart` y `mobile/pubspec.lock` para verificar duplicación e import indirecto.

## Hallazgos bloqueantes

Ninguno. Los candidatos identificados por los subagentes se descartan o degradan tras verificación manual (ver nota en B*-descartado abajo).

### Candidatos descartados tras verificación

**Broadcast stream sin `onCancel` reportado como Alta**. Verificado con un test directo en Dart 3.7.2: `Stream.asBroadcastStream()` sin `onCancel` **mantiene viva** la suscripción upstream cuando todos los listeners cancelan y se resuscribe. La nueva subscripción recibe los siguientes eventos correctamente. El test T007 (`watchAccountBalance cacheado acepta múltiples suscriptores`) ya cubre el escenario cancel + resuscribir y pasa en verde. Sin riesgo funcional. Decisión coherente con la documentación del plan: RF-002 quedó como condicional y T007 lo desmiente.

**Duplicación de instancias `AccountsDao`/`CategoriesDao` reportada como Alta**. Confirmado que `app_dependencies.dart:36-38` instancia los DAOs manualmente (`CategoriesDao(database)`) y al mismo tiempo el codegen genera `attachedDatabase.categoriesDao` por el registro `daos: [...]`. Sin embargo: los DAOs en este proyecto son stateless (solo wrappers de queries sobre el mismo `DatabaseConnectionUser`), así que las dos instancias son funcionalmente intercambiables. Sin riesgo de divergencia hoy. Degradado a M2 abajo como inconsistencia arquitectónica que conviene resolver para evitar confusión a futuro.

## Hallazgos no bloqueantes

### M1. Paquete `characters` importado como dependencia transitiva

- Severidad: Media
- Área: Tooling / mantenibilidad
- Evidencia:
  - `mobile/pubspec.yaml` no declara `characters`.
  - `mobile/pubspec.lock` muestra `characters: dependency: transitive` (viene del Flutter SDK).
  - `mobile/lib/data/backup.dart:3` hace `import 'package:characters/characters.dart';`.
- Impacto: hoy funciona porque Flutter SDK lo provee. Si el lint `depend_on_referenced_packages` se activa en `analysis_options.yaml`, este import se marca como warning. Si en una versión futura de Flutter SDK `characters` cambia de nombre o pasa a opcional, el build podría romperse. Bajo en probabilidad, pero estilo recomendado por Dart.
- Recomendación: agregar `characters: ^1.4.0` en `dependencies:` de `mobile/pubspec.yaml`. Diff trivial, sin impacto en lock.
- Depende de: ninguna.

### M2. `AppDependencies` instancia DAOs en paralelo a las instancias del codegen

- Severidad: Media
- Área: Arquitectura
- Evidencia:
  - `mobile/lib/app_dependencies.dart:36-38` crea `AccountsDao(database)` y `CategoriesDao(database)` manualmente.
  - `mobile/lib/data/database.g.dart` (codegen) genera `late final accountsDao = AccountsDao(...)` y `late final categoriesDao = CategoriesDao(...)` por el nuevo `daos: [AccountsDao, CategoriesDao]`.
  - Resultado: cada DAO existe dos veces en runtime — el de `AppDependencies` lo usan los screens; el de `attachedDatabase` lo usa `EntriesDao.updateEntry` para resolver `findActiveById`.
- Impacto: hoy ninguno (DAOs stateless). Pero si un sprint futuro agrega cache o estado en `CategoriesDao` o `AccountsDao`, ese estado se va a duplicar silenciosamente entre las dos instancias y el bug va a ser difícil de diagnosticar.
- Recomendación: en `AppDependencies.fromDatabase` reemplazar las construcciones manuales por `database.accountsDao` y `database.categoriesDao`. `EntriesDao` queda con la construcción manual porque su constructor requiere `FinancialStateService` (ver desviación documentada).
- Depende de: ninguna. Cambio en un solo archivo.

### M3. Test "200 chars exactos" acepta verde por excepción ajena

- Severidad: Media
- Área: Tests / cobertura RF-003
- Evidencia: `mobile/test/data/backup_test.dart` test `Import con name de 200 chars exactos pasa validación de longitud`. Patrón:
  ```dart
  try {
    await backup.importFromJson(buildPayload(categoryName: boundary));
  } catch (e) {
    expect(e, isA<BackupError>());
    expect((e as BackupError).code, isNot('string_too_long'));
  }
  ```
  Si el import lanza una excepción distinta (ej. `invalid_reference` por algún detalle del helper `buildPayload`), el `catch` la captura, valida que NO es `string_too_long` y el test pasa verde. El happy path "el import completa sin excepción" queda sin verificar.
- Impacto: una futura regresión en la validación de longitud que elevara el límite a `190` (más permisivo) o lo bajara a `199` (más estricto) podría pasar desapercibida si `buildPayload(...)` ya falla por otro motivo. Bajo en probabilidad, pero el test pierde su valor defensivo.
- Recomendación: cambiar el patrón a `expect(() => backup.importFromJson(buildPayload(categoryName: boundary)), returnsNormally);` o ejecutar el import directamente y verificar que `ImportReport.categoriesCount == 1`.
- Depende de: ninguna.

### M4. `watchAccountBalance` no incluye `_db.accounts` en `readsFrom`

- Severidad: Baja
- Área: Drift reactividad
- Evidencia: `mobile/lib/data/financial_state.dart:57` usa `readsFrom: {_db.journalEntries}`. El closure captura `isCredit = accountType == 'credit'` y genera la fórmula SQL específica. Si el `type` de la cuenta cambia tras la creación del stream (cash↔debit o debit↔credit), el stream cacheado sigue usando la fórmula anterior.
- Impacto: hoy nulo. La Bolsa es `is_protected=true` y no puede cambiar de type. No hay UI ni DAO que permita cambiar el `type` de otras cuentas. El campo es de facto inmutable post-creación.
- Recomendación: dejar como está y agregar un comentario en `watchAccountBalance` señalando que `accountType` se asume inmutable. Alternativa: agregar `_db.accounts` a `readsFrom` por defensa pura, costo trivial.
- Depende de: ninguna.

### M5. Comentario defensivo sugerido en `@DriftDatabase(daos: [...])`

- Severidad: Baja
- Área: Mantenibilidad
- Evidencia: `mobile/lib/data/database.dart` registra solo `[AccountsDao, CategoriesDao]` con un comentario explicando el motivo del registro parcial. Si un mantenedor futuro agrega `EntriesDao` al array, el codegen genera `EntriesDao(this as FincoreDatabase)` que falla en tiempo de construcción de la BD porque al constructor real le falta `FinancialStateService`.
- Impacto: el comentario actual ya advierte el riesgo; un PR review casual podría no detectarlo.
- Recomendación: reforzar el comentario con un marcador como `// NUNCA agregar EntriesDao aquí — su constructor requiere FinancialStateService.` para que sea inconfundible en revisión. Cambio cosmético.
- Depende de: ninguna.

### M6. Contrastes WCAG de los snackbars `success` y `error` quedan en el límite o por debajo de AA

- Severidad: Baja (fuera del scope de este sprint)
- Área: Accesibilidad / UX
- Evidencia (estimación del subagente Haiku):
  - `showSuccessSnackbar`: `Colors.white` sobre `FincoreColors.positive` (#50CC8E). Contraste ~2.0:1.
  - `showErrorSnackbar`: `Colors.white` sobre `FincoreColors.negative` (#E05959). Contraste ~4.2:1.
  - `showWarningSnackbar`: `FincoreColors.canvas` sobre `FincoreColors.warning` (#EBBD52). Contraste ~10.5:1 (AA cumple holgado).
- Impacto: success queda claramente bajo AA (4.5:1) y error queda al filo. Pre-existente al sprint v2 (el sprint solo refactorizó la inyección del color, no cambió las paletas).
- Recomendación: NO bloquea este sprint. Levantar como tarea separada para el próximo sprint de UX. Si se atacara aquí, cambiar `foreground` en `showSuccessSnackbar` (y opcionalmente en `showErrorSnackbar`) a `FincoreColors.canvas` para alcanzar ≥4.5:1.
- Depende de: ninguna. Decisión de scope.

### M7. Timeout de 2 minutos en `Share.shareXFiles` puede ser ajustado al alza

- Severidad: Baja
- Área: UX export
- Evidencia: `mobile/lib/screens/settings_screen.dart:56` envuelve el share con `.timeout(Duration(minutes: 2), onTimeout: () => const ShareResult('timeout', ShareResultStatus.unavailable))`. Si el usuario abre Gmail y tarda más de 2 minutos en redactar y enviar, el flujo trata el share como cancelado.
- Impacto: en el caso "abrir share → app pesada → tomar tiempo en seleccionar destino → terminar > 2 min" el flujo `_exportThenReset` muestra "Exportación cancelada" cuando en realidad sí se completó. El archivo temporal queda en disco hasta limpieza del SO.
- Recomendación: dejar 2 min para v0.3.1 (es el patrón documentado en `pendientes.md`). Si Diego reporta el falso negativo durante el smoke, subir a 5 min.
- Depende de: T015 (smoke manual).

### M8. Validación de campos credit-only en cuentas no-credit no se verifica

- Severidad: Baja (fuera de scope)
- Área: Backup / integridad
- Evidencia: `_accountFromJson` valida que `closing_day/payment_day/credit_limit` cumplen rangos solo si `type == 'credit'`. Para `cash`/`debit` esos campos pueden llegar con cualquier valor (incluido `999`) y se persisten en la BD.
- Impacto: la UI no usa esos campos para cash/debit, así que no hay crash. Pero la BD queda con datos sucios si el JSON viene corrupto desde un sistema externo.
- Recomendación: si se considera relevante, agregar validación de "estos campos deben ser `null` cuando `type != 'credit'`". Documentar en `pendientes.md` del sprint v2 si se decide diferir.
- Depende de: ninguna. Decisión de scope.

## Plan de corrección ordenado

Las 3 mejoras `Media` pueden aplicarse antes del commit del sprint v2. El resto puede diferirse a follow-up. Orden por dependencia (ninguna depende de otra):

1. **M1** — `mobile/pubspec.yaml`: agregar `characters: ^1.4.0` en `dependencies:`. Verificar con `flutter pub get` (no debe cambiar `pubspec.lock`).
2. **M2** — `mobile/lib/app_dependencies.dart:36-37`: reemplazar `AccountsDao(database)` por `database.accountsDao` y `CategoriesDao(database)` por `database.categoriesDao`. Mantener `EntriesDao(database, stateService)` manual.
3. **M3** — `mobile/test/data/backup_test.dart`: cambiar el patrón `try/catch` del test de 200 chars por `expect(() => ..., returnsNormally)` o un assert sobre el `ImportReport` resultante.
4. **T015** — Smoke manual a cargo de Diego sobre Redmi (instalar APK arm64 release sobre `0.3.0+32`, validar los puntos de `pendientes.md` del sprint v2).
5. **Commit + push** del sprint v2 si T015 pasa verde. Mensaje siguiendo el patrón `feat(mobile): sprint flutter-local-hardening-v2`.
6. **Follow-up futuro** (no urgente): documentar M4 con comentario, reforzar M5, evaluar M6/M7/M8 en un sprint dedicado a UX.

## Validaciones recomendadas

- `cd mobile && flutter analyze`
- `cd mobile && flutter test`
- `cd mobile && flutter pub get` (tras aplicar M1)
- `~/Android/Sdk/build-tools/36.0.0/aapt2 dump badging build/app/outputs/flutter-apk/app-arm64-v8a-release.apk | head -3` (verificar `versionCode='2033'` post-rebuild si M1 obliga a regenerar APK).
- Smoke checklist en Redmi: instalar `app-arm64-v8a-release.apk` sobre `0.3.0+32`, validar datos preservados, snackbars con texto legible, flujo `_exportThenReset`, flujo `_resetWithoutExport`, importar JSON corrupto y verificar mensajes amigables del importador.

## Limitaciones

- **Sin commit todavía**: el review se hizo sobre el working tree, no sobre un commit/PR. Cualquier verificación post-commit con `git log --oneline ecb9893..HEAD` queda pendiente.
- **No se ejecutó la app en el cel** (T015 es responsabilidad de Diego). El review verifica build + tests + análisis estático; no valida UX real en Android.
- **No se midieron los contrastes WCAG con herramienta**: las estimaciones del subagente Haiku son aproximaciones de fórmula sRGB. Si M6 se ataca, recalcular con `accessible-colors` o similar.
- **No se verificó el comportamiento de `Share.shareXFiles` con timeout disparado** en Android real. El flujo se diseñó por especificación de `share_plus` ^10.0.0; un edge-case patológico solo aparece en smoke.
- **Diff de `database.g.dart`** no se auditó línea por línea (es codegen). Se confió en `flutter test` (91 verdes) como verificación de que el codegen quedó coherente.

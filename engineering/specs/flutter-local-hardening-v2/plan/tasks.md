# Tareas — flutter-local-hardening-v2

17 tareas T001..T017 organizadas por categoría. Dependencias declaradas, paralelización marcada.

## Base de datos — Codegen

- [ ] T001 Base de datos: modificar la anotación `@DriftDatabase` en `mobile/lib/data/database.dart:89` de `@DriftDatabase(tables: [Accounts, Categories, JournalEntries])` a `@DriftDatabase(tables: [Accounts, Categories, JournalEntries], daos: [AccountsDao, CategoriesDao, EntriesDao])`. Agregar `import 'package:fincore/data/daos/accounts_dao.dart';`, `import 'package:fincore/data/daos/categories_dao.dart';`, `import 'package:fincore/data/daos/entries_dao.dart';` si no están presentes. Ejecutar `cd mobile && dart run build_runner build --delete-conflicting-outputs`.
  RF: RF-007
  Depende de: ninguna
  Paralelizable: no (bloquea T002)
  Criterio de terminado: codegen completa sin errores, `database.g.dart` queda regenerado, `flutter analyze` y `flutter test` siguen verdes con los 87 tests previos.

## Base de datos — Refactors

- [ ] T002 Base de datos: en `mobile/lib/data/daos/entries_dao.dart`, dentro de `updateEntry`, reemplazar la query inline:
  ```dart
  final active = await (select(categories)
        ..where((c) => c.id.equals(effectiveCategoryId) & c.deletedAt.isNull()))
      .getSingleOrNull();
  ```
  por delegación al helper canónico:
  ```dart
  final active = await attachedDatabase.categoriesDao.findActiveById(effectiveCategoryId);
  ```
  Mantener la lógica de `forceClearCategory` y el resto de RN-H03 intacta.
  RF: RF-008
  Depende de: T001
  Paralelizable: si (con T003..T010)
  Criterio de terminado: query inline eliminada (6-10 líneas), test `'updateEntry sobre entry con categoría heredada archivada limpia silenciosamente'` sigue verde, comportamiento RN-H03 preservado.

- [ ] T003 Base de datos: en `mobile/lib/data/financial_state.dart:31-53`, modificar `watchAccountBalance` para retornar un stream broadcast cacheado. Aplicar `.asBroadcastStream()` al stream creado por `customSelect(...).watchSingle()` antes de guardarlo en `_balanceCache`. Si T007 detecta que el cache queda con stream cerrado tras cancelar el último listener, ajustar a `.asBroadcastStream(onCancel: (_) => invalidateAccount(accountId))` o equivalente que limpie la key del Map. Si el broadcast simple pasa, queda como está.
  RF: RF-001, RF-002 (condicional)
  Depende de: ninguna
  Paralelizable: si (con T002, T004..T010)
  Criterio de terminado: dos `Stream.listen(...)` simultáneos al mismo `(accountId, accountType)` no lanzan `StateError`. Tests del cache existentes (5 del sprint anterior) siguen verdes.

## Pruebas

- [ ] T004 Pruebas: agregar al final de `mobile/test/data/backup_test.dart` el test `'Import con name de 200 chars exactos pasa validación de longitud'`. Usar el helper `buildPayload(categoryName: 'A' * 200)` y verificar con un patrón similar al test `'Import con name vacío pasa la validación de longitud'`: si lanza `BackupError`, su código NO debe ser `string_too_long`.
  RF: RF-003
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: nuevo test en verde; tests existentes siguen verdes.

- [ ] T005 Pruebas: agregar en `mobile/test/data/financial_state_test.dart` el test `'wipeAll invalida cache de streams'`. Requiere construir `BackupService(database, state)` en el setUp si todavía no se hace. Flujo: sembrar Bolsa, suscribirse a `state.watchAccountBalance(bolsa, 'cash')` y capturar referencia (`s1`), ejecutar `await backup.wipeAll()`, llamar de nuevo `state.watchAccountBalance(bolsa, 'cash')` (`s2`), verificar `identical(s1, s2) == false`.
  RF: RF-004
  Depende de: ninguna (si T003 cambia el comportamiento del cache, ajustar al final)
  Paralelizable: si
  Criterio de terminado: nuevo test en verde.

- [ ] T006 Pruebas: agregar en `mobile/test/data/database_test.dart`, idealmente dentro o cerca del grupo `EntriesDao — los 5 kinds`, el test `'watchPage no incluye badge para categorías archivadas'`. Crear un income con `categoryId = catSueldo`, archivar `catSueldo` con `categoriesDao.archive(catSueldo)`, leer `entriesDao.watchPage().first`, verificar que `result.first.category == null` (o `equals(null)` para evitar ambigüedad con drift).
  RF: RF-005
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: nuevo test en verde. Defensa contra la regresión del join.

- [ ] T007 Pruebas: agregar en `mobile/test/data/financial_state_test.dart` el test `'watchAccountBalance cacheado acepta múltiples suscriptores simultáneos'`. Suscribir 2 `StreamSubscription` a `state.watchAccountBalance(bolsa, 'cash')`, registrar emisiones de cada uno, ejecutar un `entriesDao.registerIncome(...)` para disparar evento, esperar `Future.delayed(Duration(milliseconds: 100))` para que drift propague, cancelar ambos subscriptions, verificar que ambos recibieron al menos 1 evento. Adicionalmente: cancelar todo, esperar, suscribirse de nuevo, ejecutar otro insert, verificar que el nuevo listener también recibe evento (defiende RF-002 condicional).
  RF: RF-006, RF-001 (validación), RF-002 (validación condicional)
  Depende de: T003
  Paralelizable: si (con T002, T004, T005, T006, T008..T010 una vez T003 commiteado)
  Criterio de terminado: test verde. Si falla por stream cerrado al perder último listener, ajustar T003 con `onCancel`.

## Frontend — Refactors

- [ ] T008 Frontend: refactor de `mobile/lib/widgets/error_snackbar.dart`. Cambiar la firma de `_buildFincoreSnackBar` para recibir `required Color foreground` en lugar de inferir por `background == FincoreColors.warning`. Eliminar las líneas 103-104 (el cálculo inferido). Actualizar los 3 callers (`showSuccessSnackbar`, `showWarningSnackbar`, `showErrorSnackbar`) para pasar `foreground: Colors.white`, `foreground: FincoreColors.canvas`, `foreground: Colors.white` respectivamente.
  RF: RF-009
  Depende de: ninguna
  Paralelizable: si (con T002, T003, T004..T007, T009, T010)
  Criterio de terminado: el snackbar warning sigue mostrando texto canvas oscuro sobre amarillo en runtime. `flutter analyze` 0 errores. Comparación por igualdad de instancia eliminada.

- [ ] T009 Frontend: en `mobile/lib/screens/settings_screen.dart:53`, envolver `Share.shareXFiles(...)` con `.timeout(Duration(minutes: 2), onTimeout: () => const ShareResult(raw: '', status: ShareResultStatus.unavailable))`. Importar `package:share_plus/share_plus.dart` ya está disponible. Confirmar que el flow `_exportThenReset` ya distingue `success` del resto y trata `unavailable` como cancelación.
  RF: RF-010
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: timeout aplicado, comportamiento del fallback consistente con el flujo existente.

## Backend (capa de datos) — characters

- [ ] T010 Base de datos: en `mobile/lib/data/backup.dart`, agregar `import 'package:characters/characters.dart';` al tope del archivo. En `_validateUuid` reemplazar `value.length <= 16 ? value : '${value.substring(0, 16)}…'` por `value.characters.length <= 16 ? value : '${value.characters.take(16).string}…'`. En `_parseDate` reemplazar `raw.length <= 32 ? raw : '${raw.substring(0, 32)}…'` por `raw.characters.length <= 32 ? raw : '${raw.characters.take(32).string}…'`.
  RF: RF-011
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: tests existentes de import siguen verdes. `flutter analyze` 0 errores. Comportamiento con ASCII indistinguible; comportamiento con multi-byte preserva grapheme clusters.

## Documentación

- [ ] T011 Documentación: agregar al `mobile/README.md` una sección nueva titulada **"Importar respaldos: límites y validaciones"**. Ubicar tras la sección actual de filosofía o antes de "Cómo recuperar el cliente web legacy". Contenido:
  - Mención de que el formato es JSON v1 compatible con el backend Laravel legacy.
  - Lista de los 13+ códigos de error tipados (los 4 existentes + los 6 del sprint anterior + los 4 nuevos resueltos in-sprint en hardening: `invalid_date_format`, `invalid_credit_limit`, `invalid_credit_metadata`, `invalid_color_slug`, `invalid_icon_slug`, `protected_account`).
  - Tabla o lista con los límites: `name ≤ 200 chars`, `description ≤ 1000 chars`, `amount > 0`, UUIDs `v4` o `v7`, credit metadata (`credit_limit > 0`, `closing_day` y `payment_day` en `[1, 31]` y distintos, `interest_rate` y `minimum_payment_pct` en `[0, 1]`).
  - Mención de la invariante Bolsa singleton (`type=cash` + `is_protected=true`).
  RF: RF-012
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: sección agregada con contenido claro y trazable; markdown válido.

- [ ] T012 Documentación: completar `engineering/specs/flutter-local-hardening/implementation/desviaciones-plan.md` agregando una sección **"Desviaciones menores"** con 3 ítems:
  1. `isNull` matcher ambiguo entre drift y `flutter_test`: cambiado a `equals(null)` en `database_test.dart` (2 ocurrencias).
  2. `_buildPayload` renombrado a `buildPayload` en `backup_test.dart` por lint `no_leading_underscores_for_local_identifiers`.
  3. Query inline `findActiveById` en `EntriesDao.updateEntry` por falta de `daos: [...]` en `@DriftDatabase`. Nota que el sprint `flutter-local-hardening-v2` RH2-005 resuelve esto registrando los DAOs.
  RF: RF-013
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: archivo actualizado, sección coherente con el resto del documento.

## Validación de calidad — Release y smoke

- [ ] T013 Documentación: bumpear `mobile/pubspec.yaml` a `version: 0.3.1+33` y `mobile/android/app/build.gradle.kts` a `versionCode = 33` + `versionName = "0.3.1"`. NO actualizar `kAppVersion` (ya no existe, eliminado en sprint anterior).
  RF: criterios de aceptación del bump
  Depende de: T001..T012
  Paralelizable: no
  Criterio de terminado: los dos archivos sincronizados en `0.3.1+33`.

- [ ] T014 Validación de calidad: ejecutar `cd mobile && export PATH="$HOME/development/flutter/bin:$PATH" && flutter analyze` (0 errores), `flutter test` (≥ 91 verdes), `flutter build apk --release --split-per-abi` (3 APKs generados). Confirmar con `$HOME/Android/Sdk/build-tools/*/aapt dump badging app-arm64-v8a-release.apk` que `versionCode='2033'` y `versionName='0.3.1'`. Confirmar con `aapt dump xmltree AndroidManifest.xml` que `allowBackup=0x0` y `dataExtractionRules` siguen presentes.
  RF: criterios de aceptación
  Depende de: T013
  Paralelizable: no
  Criterio de terminado: los tres comandos pasan; APK arm64 en `mobile/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` con metadata correcta.

- [ ] T015 Validación de calidad: **smoke manual pendiente de Diego**. Instalar `app-arm64-v8a-release.apk` sobre el `0.3.0+32` existente en el Redmi vía `~/Android/Sdk/platform-tools/adb install -r ...`. Validar:
  1. App abre sin pantalla blanca; splash → dashboard con datos preservados.
  2. Settings → "Acerca de" muestra `0.3.1+33`.
  3. Tomar un entry con categoría, archivar la categoría, abrir el entry → form sin badge, listados (Dashboard + Movimientos) sin badge (regresión RF-005).
  4. Settings → "Exportar respaldo y luego reiniciar" → en el share sheet del sistema cancelar rápido → snackbar warning "Exportación cancelada. No se reinició la BD." (RF-010 cubre el fallback completo de timeout, no se puede simular share colgado manualmente).
  RF: criterios de aceptación
  Depende de: T014
  Paralelizable: no
  Criterio de terminado: Diego confirma los 4 puntos OK. Si aparece bug, regresar a T012 con desviación documentada.

## Cierre

- [ ] T016 Documentación: crear carpeta `engineering/specs/flutter-local-hardening-v2/implementation/` con los 6 archivos estándar:
  - `progreso.md` (estado de cada tarea T001..T017).
  - `desviaciones-plan.md` (cambios respecto al plan + onCancel del broadcast si se aplicó).
  - `pendientes.md` (cualquier nuevo límite descubierto + ítems diferidos a sprints futuros).
  - `implementation-review.md` (estructura estándar).
  - `resumen-ejecutivo.md`.
  - `resumen-extenso.md`.
  RF: trazabilidad obligatoria
  Depende de: T015
  Paralelizable: no
  Criterio de terminado: los 6 archivos existen, contenido coherente y refleja el estado real del sprint.

- [ ] T017 Validación de calidad: invocar skill `branch-quality-review` con slug `flutter-local-hardening-v2`. Espera reporte en `engineering/quality-review/flutter-local-hardening-v2/YYYY-MM-DD-HHMM-branch-quality-review.md` con cobertura de 6 lanes. Si aparecen bloqueantes, resolverlos en la misma sesión como hicimos en `flutter-local-mvp` y `flutter-local-hardening`.
  RF: trazabilidad obligatoria
  Depende de: T016
  Paralelizable: no
  Criterio de terminado: reporte generado; bloqueantes (si hay) resueltos o documentados explícitamente como aceptados; sprint listo para `git add + commit` con el patrón de sprints anteriores.

# Tareas — flutter-local-hardening

25 tareas organizadas por categoría. IDs consecutivos T001..T025 con dependencias declaradas. Las paralelizables pueden ejecutarse en cualquier orden dentro de la misma fase.

## Documentación y tooling base

- [ ] T001 Tooling: agregar `package_info_plus: ^8.x` a `mobile/pubspec.yaml` y ejecutar `flutter pub get`.
  RF: RF-016
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: `flutter pub get` exitoso, `pubspec.lock` actualizado, la importación `package:package_info_plus/package_info_plus.dart` resuelve sin errores en `flutter analyze`.

- [ ] T003 Documentación: actualizar `CLAUDE.md` raíz con 4 secciones nuevas: (a) convención de migraciones (RN-H02 + RF-010), (b) convención de joins con categorías archivadas / uso de `findActiveById` (RF-015 documental), (c) política de `ndkVersion` hardcoded (RF-017), (d) política de no `flutter pub upgrade` sin revisar changelogs (RF-018).
  RF: RF-010, RF-015 (documental), RF-017, RF-018
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: `CLAUDE.md` contiene las 4 secciones nuevas con bullets concretos; cada una referencia el archivo correspondiente en `mobile/` cuando aplica.

## Base de datos (preparación de schema)

- [ ] T002 Base de datos: redefinir `onUpgrade` en `mobile/lib/data/database.dart` para que, por defecto, lance `UnimplementedError('Schema upgrade $from → $to no implementado en database.dart')`. NO bumpear todavía `schemaVersion`.
  RF: RF-009
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: `onUpgrade` lanza la excepción cuando `from != to`; `flutter test` sigue verde (los tests usan in-memory que ejecuta `onCreate`, no `onUpgrade`); `flutter analyze` 0 errores.

## Capa de datos — Validaciones del import (Familia 1)

- [ ] T005 Base de datos: agregar constantes `_validKinds`, `_validAccountTypes`, `_validAppliesToTypes` en `mobile/lib/data/backup.dart` y validar enums en `_entryFromJson` (kind), `_accountFromJson` (type) y `_categoryFromJson` (applies_to). Lanzar `BackupError('invalid_kind' | 'invalid_account_type' | 'invalid_applies_to', mensaje)` si el valor no está en la lista.
  RF: RF-001, RF-002, RF-003
  Depende de: ninguna
  Paralelizable: si (independiente de T006, T007, T008 al estar en métodos distintos pero mismo archivo; coordinar si se hacen simultáneos)
  Criterio de terminado: las constantes son `const Set<String>`; las validaciones lanzan antes de construir el Companion; los tests existentes de `backup_test.dart` siguen verdes.

- [ ] T006 Base de datos: validar `amount > 0` en `_entryFromJson` de `mobile/lib/data/backup.dart`. Lanzar `BackupError('invalid_amount', 'El monto del movimiento debe ser mayor a 0.')` si `amount <= 0`.
  RF: RF-004
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: validación antes del Companion; tests existentes siguen verdes.

- [ ] T007 Base de datos: agregar constantes `_kMaxNameLength = 200`, `_kMaxDescriptionLength = 1000` en `backup.dart`. Validar `name.length <= 200` en `_accountFromJson` y `_categoryFromJson`; validar `description.length <= 1000` (cuando no es null) en `_accountFromJson` y `_entryFromJson`. Lanzar `BackupError('string_too_long', 'El campo X excede el límite de Y caracteres (longitud observada: Z).')`.
  RF: RF-005
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: validaciones aplicadas en los tres `_*FromJson`; el mensaje incluye el nombre del campo y la longitud observada; tests existentes siguen verdes. Actualizar `mobile/README.md` con los límites bajo "Filosofía" o "Cosas que NO están en este MVP".

- [ ] T008 Base de datos: definir constante `_uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[47][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$')` en `backup.dart`. Validar formato del campo `id` en los tres `_*FromJson` y de `category_id` cuando no es null en `_entryFromJson`. Lanzar `BackupError('invalid_uuid_format', 'El campo X tiene un ID inválido (esperado UUID v4 o v7, recibido: <truncado a 16 chars>).')`.
  RF: RF-006
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: regex documentada con comentario sobre v4/v7; validación aplicada; tests existentes siguen verdes.

## Presentación — Mapeo de errores

- [ ] T009 Frontend: agregar `backupErrorToMessage(BackupError error)` en `mobile/lib/widgets/error_snackbar.dart` con switch case para todos los códigos de `BackupError` (los existentes `invalid_json`, `unsupported_version`, `missing_bolsa`, `invalid_reference` y los nuevos `invalid_kind`, `invalid_account_type`, `invalid_applies_to`, `invalid_amount`, `string_too_long`, `invalid_uuid_format`). Agregar branch `BackupError() => backupErrorToMessage(error)` en el switch de `showErrorSnackbar` ANTES del branch `Exception()`.
  RF: RF-007
  Depende de: T005, T006, T007, T008
  Paralelizable: no (modifica el mismo archivo y requiere conocer todos los códigos)
  Criterio de terminado: snackbar muestra mensajes amigables en español para los 10 códigos; los mensajes ya existentes del backend legacy mantienen su redacción; `flutter analyze` 0 errores.

## Capa de datos — Schema y streams (Familia 4)

- [ ] T010 Base de datos: en `mobile/lib/data/database.dart`, bumpear `schemaVersion` de 1 a 2. Agregar en `onCreate` la sentencia `await customStatement('CREATE INDEX idx_entries_occurred_active ON journal_entries(occurred_at DESC) WHERE deleted_at IS NULL');`. Agregar en `onUpgrade` la rama `if (from == 1 && to == 2) { await m.customStatement('CREATE INDEX idx_entries_occurred_active ON journal_entries(occurred_at DESC) WHERE deleted_at IS NULL'); return; }` antes del throw del guardrail.
  RF: RF-011
  Depende de: T002
  Paralelizable: si (con T011 — archivos distintos)
  Criterio de terminado: `schemaVersion == 2`; `onCreate` ejecuta los 7 CREATE INDEX (los 6 actuales + el nuevo); `onUpgrade(1, 2)` ejecuta el CREATE INDEX y retorna sin tocar el throw; tests existentes verdes.

- [ ] T011 Base de datos: refactor de `FinancialStateService` en `mobile/lib/data/financial_state.dart`. Agregar campo privado `final Map<String, Stream<double>> _balanceCache = {};`. `watchAccountBalance(accountId, accountType)` consulta el Map por la key `'$accountId:$accountType'` y retorna el stream cacheado si existe; si no, crea uno nuevo, lo guarda y retorna. Exponer dos métodos públicos: `void invalidateAccount(String accountId)` (borra todas las keys del Map que empiezan con `'$accountId:'`) y `void invalidateAll()` (limpia el Map). Modificar `BackupService.wipeAll()` para llamar `_state.invalidateAll()` antes del `delete journalEntries/categories/accounts` (requiere agregar parámetro al constructor de `BackupService` o pasarlo desde `app_dependencies`). Modificar `AccountsDao.archive(id)` para llamar `_state.invalidateAccount(id)` después del soft-delete de la cuenta dentro de la transacción.
  RF: RF-012
  Depende de: ninguna (independiente de T010)
  Paralelizable: si (con T010, T012)
  Criterio de terminado: el Map cachea correctamente; suscripciones repetidas a la misma key reciben el mismo stream; tras `archive(id)` el Map no contiene keys de esa cuenta; tras `wipeAll()` el Map queda vacío; tests existentes verdes.

## Capa de datos — Categorías (Familia 5 datos)

- [ ] T012 Base de datos: agregar `Future<Category?> findActiveById(String id)` a `mobile/lib/data/daos/categories_dao.dart` que retorna el resultado de `(select(categories)..where((c) => c.id.equals(id) & c.deletedAt.isNull())).getSingleOrNull()`.
  RF: RF-015
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: método nuevo disponible; tests existentes verdes; documentado en `CLAUDE.md` por T003.

- [ ] T013 Base de datos: modificar `EntriesDao.updateEntry` en `mobile/lib/data/daos/entries_dao.dart`. Después de calcular `effectiveCategoryId`, si no es null, ejecutar `final cat = await _state.attachedDatabase.categoriesDao.findActiveById(effectiveCategoryId);` (o equivalente según el accessor real al CategoriesDao). Si `cat == null`, forzar `effectiveCategoryId = null` antes del write (no lanzar error). Si `cat != null`, continuar con `_validateCategoryForKind` como hoy.
  RF: RF-014
  Depende de: T012
  Paralelizable: no (mismo método que T013 toca lógica de validación)
  Criterio de terminado: cuando la categoría heredada está archivada, el write incluye `categoryId = const Value(null)`; cuando está activa pero incompatible con el kind, sigue lanzando `invalid_category_applies_to`; tests existentes verdes.

## Presentación — UX

- [ ] T014 Frontend: refactor de `_resetAccount` en `mobile/lib/screens/settings_screen.dart`. Reemplazar el botón único por dos botones apilados dentro de la card "Zona peligrosa":
  1. Botón primario (`FilledButton.icon` con `accent`): "Exportar respaldo y luego reiniciar". Lanza `_export()`; tras share sheet con status success, muestra `showConfirmDialog` con texto "El respaldo se compartió correctamente. ¿Continuar con el reseteo de tu BD local?" y, tras confirmar, ejecuta `wipeAll()` + redirect.
  2. Botón secundario (`OutlinedButton.icon` rojo): "Reiniciar sin exportar". Mantiene el flujo actual con confirmación destructiva enfática.
  Si el share sheet retorna status `dismissed` o `unavailable`, mostrar `showWarningSnackbar` con "Exportación cancelada. No se reinició la BD."
  RF: RF-013
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: los dos botones son visibles; el flujo "Exportar y luego reiniciar" requiere share sheet success + confirmación adicional; el flujo "Reiniciar sin exportar" mantiene la confirmación actual; ambos terminan en `/first-run` tras `wipeAll`.

- [ ] T015 Frontend: refactor de la card "Acerca de" en `settings_screen.dart`. Eliminar la constante `kAppVersion`. Usar `FutureBuilder<PackageInfo>` con `future: PackageInfo.fromPlatform()` y, en el `builder`, mostrar `'${info.version}+${info.buildNumber}'` cuando hay data, un `Skeleton(width: 60, height: 14)` mientras espera, y `'dev'` si `snapshot.hasError`.
  RF: RF-016
  Depende de: T001
  Paralelizable: si
  Criterio de terminado: la card no tiene strings hardcoded de versión; en runtime muestra el `versionName + versionCode` del manifest; en tests sin platform channel, el FutureBuilder maneja error sin reventar.

- [ ] T016 Frontend: modificar `_buildFincoreSnackBar` en `mobile/lib/widgets/error_snackbar.dart` para que, cuando `background == FincoreColors.warning`, el `Icon` y el `Text` usen `color: FincoreColors.canvas` en lugar de `Colors.white`. Mantener `Colors.white` para `negative` y `positive`.
  RF: RF-019
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: en runtime, el snackbar warning muestra texto e icono oscuros sobre fondo amarillo; el contraste calculado pasa ≥7:1; los snackbars success y error mantienen texto blanco.

- [ ] T017 Frontend: agregar `tooltip` o `Semantics` en iconos críticos:
  - `entries_list_screen.dart`: `IconButton` del filter recibe `tooltip: 'Filtros'`.
  - `dashboard_screen.dart`: `FloatingActionButton.extended` recibe `tooltip: 'Nuevo movimiento'`.
  - `entries_list_screen.dart`: `FloatingActionButton` recibe `tooltip: 'Nuevo movimiento'`.
  - `entry_form_screen.dart`: `TextButton.icon` "Cambiar tipo" envuelto en `Tooltip(message: 'Cambiar tipo de movimiento', child: ...)` si el `TextButton` no soporta tooltip nativo.
  - `first_run_screen.dart` y `settings_screen.dart`: chevrons (`Icon(Icons.chevron_right)`) decorativos envueltos en `Semantics(excludeSemantics: true, child: ...)`.
  RF: RF-020
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: TalkBack narra los iconos críticos con el tooltip; los chevrons no se narran; `flutter analyze` 0 errores.

## Pruebas

- [ ] T018 Pruebas: agregar test `cancel idempotente preserva balance` en `mobile/test/data/database_test.dart` (grupo "EntriesDao — los 5 kinds"). Crear income $500 sobre Bolsa; ejecutar primer cancel; capturar balance; ejecutar segundo cancel; verificar que el balance no cambia y queda en 0.
  RF: RF-021
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: nuevo test en verde; subimos de 59 a 60 tests.

- [ ] T019 Pruebas: agregar grupo `group('EntriesDao.updateEntry transiciones', () {...})` en `database_test.dart` con al menos 4 tests:
  1. Editar `amount + description + occurredAt` simultáneamente en un income — verifica los tres campos persisten.
  2. Editar `categoryId` a una categoría compatible — verifica el cambio.
  3. Editar `categoryId` a una categoría con `applies_to` incompatible — verifica `invalid_category_applies_to`.
  4. Editar `accountOriginId` en un expense a otra cuenta cash/debit activa — verifica persistencia y `_validateAccountTypes` correcto.
  5. (extra) updateEntry sobre entry con categoría que fue archivada después del insert — verifica que el write persiste con `categoryId = null` y sin error.
  RF: RF-022, RF-014 (test del nuevo comportamiento)
  Depende de: T013
  Paralelizable: si (con T020)
  Criterio de terminado: 4-5 tests nuevos verdes; subimos a 64-65 tests.

- [ ] T020 Pruebas: agregar a `mobile/test/data/backup_test.dart` los siguientes tests de validación (al menos uno por código de error tipado nuevo):
  - `Import con kind inválido rechaza con invalid_kind`.
  - `Import con type de cuenta inválido rechaza con invalid_account_type`.
  - `Import con applies_to inválido rechaza con invalid_applies_to`.
  - `Import con amount <= 0 rechaza con invalid_amount`.
  - `Import con name muy largo rechaza con string_too_long`.
  - `Import con id no UUID rechaza con invalid_uuid_format`.
  - `Import con UUID v4 y UUID v7 ambos válidos pasa`.
  - `BD existente intacta tras rechazo` (ya existe para invalid_json; ampliar a uno de los nuevos códigos).
  Adicionalmente: agregar al menos un test en `database_test.dart` o nuevo `migration_test.dart` que valide la migración 1→2 con `customStatement` programando un schema viejo y luego invocando `onUpgrade(1, 2)` manualmente o vía `NativeDatabase` con `migrationStrategy` que ejecute el upgrade.
  Y agregar en `financial_state_test.dart`: `cache de streams retorna el mismo Stream para la misma key`, `invalidateAccount limpia solo las keys de esa cuenta`, `invalidateAll vacía el Map`.
  RF: RF-001..RF-006, RF-011 (test migración), RF-012 (test cache)
  Depende de: T005, T006, T007, T008, T010, T011
  Paralelizable: si (con T019)
  Criterio de terminado: ≥10 tests nuevos verdes; suite total ≥70 verdes; `flutter analyze` 0 errores.

## Permisos Android

- [ ] T004 Frontend nativo: modificar `mobile/android/app/src/main/AndroidManifest.xml` agregando en `<application>` los atributos `android:allowBackup="false"`, `android:fullBackupContent="false"` y `android:dataExtractionRules="@xml/data_extraction_rules"`. Crear `mobile/android/app/src/main/res/xml/data_extraction_rules.xml` con `<data-extraction-rules>` que excluye `cloud-backup` y `device-transfer`.
  RF: RF-008
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: APK compilado declara `application:android:allowBackup='false'` en `aapt dump badging`; `adb backup io.github.gregori100.fincore` rechaza con "Backup not allowed".

## Validación de calidad — release y smoke

- [ ] T021 Documentación: bumpear `versionName = "0.3.0"` + `versionCode = 30` en `mobile/pubspec.yaml` y `mobile/android/app/build.gradle.kts`. NO actualizar la constante `kAppVersion` en `settings_screen.dart` porque T015 la elimina.
  RF: RF-016 (implícito)
  Depende de: T001..T020
  Paralelizable: no
  Criterio de terminado: los dos archivos sincronizados en `0.3.0+30`.

- [ ] T022 Validación de calidad: ejecutar `flutter analyze` (0 errores), `flutter test` (≥67 verdes), `flutter build apk --release --split-per-abi` (3 APKs generados). Confirmar `aapt dump badging app-arm64-v8a-release.apk` muestra `versionCode='2030'` (versionCode 30 + arch prefix arm64) y `application: ... allowBackup='false'`.
  RF: criterios de aceptación de la spec
  Depende de: T021
  Paralelizable: no
  Criterio de terminado: los tres comandos pasan; APK arm64 listo en `mobile/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.

- [ ] T023 Validación de calidad: **smoke manual pendiente de Diego**. Instalar `app-arm64-v8a-release.apk` sobre el `0.2.0+29` existente en el Redmi vía `adb install -r ...`. Validar:
  1. La app abre sin pantalla blanca; el splash muestra el logo y carga.
  2. Los datos previos (cuentas, categorías, movimientos) están intactos.
  3. Settings → "Acerca de" muestra `0.3.0+30`.
  4. Ejecutar `adb backup io.github.gregori100.fincore` desde la laptop; el cel rechaza con "Backup not allowed".
  5. Crear un JSON de respaldo válido, editarlo a mano poniendo `"kind": "hacked"` en una entry, intentar importarlo: snackbar rojo con mensaje "El kind del movimiento no es válido (esperado: income, expense, ...)." BD intacta.
  6. Editar un entry cuya categoría se archivó previamente; tocar Guardar; verificar que el badge desaparece sin error.
  7. Settings → "Exportar respaldo y luego reiniciar"; completar share sheet; confirmar segundo diálogo; llegar a `/first-run`.
  8. (Opcional) Activar TalkBack; navegar entry_form, settings, entries; iconos críticos se narran con el tooltip correcto.
  RF: criterios de aceptación de la spec
  Depende de: T022
  Paralelizable: no
  Criterio de terminado: Diego confirma los 7 puntos OK. Si aparece bug, regresar a T024 con desviación documentada.

## Cierre

- [ ] T024 Documentación: crear carpeta `engineering/specs/flutter-local-hardening/implementation/` con los siguientes archivos:
  - `progreso.md` (status de cada tarea T001..T025).
  - `desviaciones-plan.md` (cambios respecto al plan + cierre de los 20 hallazgos M atacados con referencia al fix).
  - `pendientes.md` (los 5 fuera de alcance: M6, M11, M17, M19, M24, M25 — sí, 6 contando M21 si quedó pendiente; ajustar al cerrar — más downgrade no soportado y cualquier nuevo límite descubierto en smoke).
  - `implementation-review.md` (estructura estándar).
  - `resumen-ejecutivo.md`.
  - `resumen-extenso.md`.
  RF: trazabilidad obligatoria del flujo spec-driven
  Depende de: T023
  Paralelizable: no
  Criterio de terminado: los 6 archivos existen, tienen contenido coherente y reflejan el estado real del sprint cerrado.

- [ ] T025 Validación de calidad: invocar skill `branch-quality-review` con slug `flutter-local-hardening`. Espera reporte en `engineering/quality-review/flutter-local-hardening/YYYY-MM-DD-HHMM-branch-quality-review.md` con cobertura de 6 lanes (seguridad, concurrencia, SQL/perf, UX, tests, build/docs). Si aparecen bloqueantes nuevos, resolverlos en la misma sesión como hicimos en `flutter-local-mvp` y reactualizar `progreso.md` / `desviaciones-plan.md`.
  RF: trazabilidad obligatoria
  Depende de: T024
  Paralelizable: no
  Criterio de terminado: reporte generado; bloqueantes (si hay) resueltos o documentados explícitamente como aceptados; commit final del sprint listo para `git add + commit` con el patrón del sprint anterior.

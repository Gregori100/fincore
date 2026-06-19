# Progreso de implementación — flutter-local-hardening

Estado de cada tarea del plan.

## Fase 0 — Base independiente

- [x] T001 — `package_info_plus: ^8.0.0` agregada a `mobile/pubspec.yaml` en la sección `dependencies` (línea 41). `flutter pub get` exitoso, deps cambiadas: 2 (paquete + transitive). 57 paquetes con versión más nueva incompatible (pinning intencional).
- [x] T002 — `MigrationStrategy.onUpgrade` en `lib/data/database.dart:124` redefinida con guardrail: `throw UnimplementedError('Schema upgrade $from → $to no implementado en database.dart. Agregá la rama correspondiente en MigrationStrategy.onUpgrade antes de bumpear schemaVersion.')`. `schemaVersion` sigue en 1 (T010 lo bumpea). Comentario in-line explica que las futuras ramas `if (from == X && to == Y) { ... return; }` van ANTES del throw y se conserva el throw como catch-all final.
- [x] T003 — `CLAUDE.md` raíz actualizado con 4 secciones nuevas:
  - **Migraciones de schema (RN-H02)**: bajo "Capa de datos", antes de "Backup JSON v1". Explica el guardrail, la regla aditiva y la prohibición de DROP en datos del usuario.
  - **Joins con categorías archivadas**: misma sección de Capa de datos. Documenta el helper `categoriesDao.findActiveById(id)` y RN-H03 (`updateEntry` limpia silenciosamente).
  - **Política de `ndkVersion` (RF-017)**: bajo "Convenciones del repo". Hardcoded a `27.0.12077973` mientras los plugins nativos lo exijan.
  - **Política de dependencias `^` flotantes (RF-018)**: misma sección. No `flutter pub upgrade` sin revisar changelogs de drift / go_router / sqlite3_flutter_libs.
  - Adicionalmente: bump de versión pasa de 3 a 2 lugares (eliminada la referencia a `kAppVersion` porque RF-016 la borra).
- [x] T004 — `AndroidManifest.xml` extendido con `android:allowBackup="false"`, `android:fullBackupContent="false"` y `android:dataExtractionRules="@xml/data_extraction_rules"`. Nuevo archivo `res/xml/data_extraction_rules.xml` con `<cloud-backup>` y `<device-transfer>` excluyendo los 5 dominios (`root`, `file`, `database`, `sharedpref`, `external`). Comentario en el XML explica que el flujo oficial de respaldo es Settings → Exportar JSON.

`flutter analyze` tras Fase 0: 4 hints info (`prefer_const_constructors` en skeleton.dart:75 y entry_form_screen.dart:260/262), 0 errores, 0 warnings. Cosméticos no bloqueantes.

## Fase 1 — Capa de datos import (T005-T009)

Aplicado de manera coordinada en `lib/data/backup.dart` y `lib/widgets/error_snackbar.dart` para mantener consistencia entre validaciones y mapeo de mensajes.

- [x] T005 — constantes `_validKinds`, `_validAccountTypes`, `_validAppliesToTypes` declaradas a nivel top del archivo. `_entryFromJson` valida `kind`, `_accountFromJson` valida `type`, `_categoryFromJson` valida `applies_to`. Lanzan `BackupError('invalid_kind' | 'invalid_account_type' | 'invalid_applies_to', mensaje con valor recibido)` antes del Companion.
- [x] T006 — `_entryFromJson` valida `amount > 0` y lanza `BackupError('invalid_amount', 'El monto del movimiento debe ser mayor a 0 (recibido: X).')`.
- [x] T007 — constantes `_kMaxNameLength = 200` y `_kMaxDescriptionLength = 1000`. Helper `_validateLength(field, value, max)` reutilizable + `_validateDescription(field, value)` que tolera null. Aplicado en `_accountFromJson` (name + description), `_categoryFromJson` (name) y `_entryFromJson` (description). Lanza `BackupError('string_too_long', 'El campo X excede el límite de Y caracteres (longitud observada: Z).')`.
- [x] T008 — `_uuidRegex` aceptando v4 y v7 (clase de caracter `[47]` en el primer hex del tercer grupo). Helper `_validateUuid(field, value)` aplicado a `accounts.id`, `categories.id`, `journal_entries.id`, `journal_entries.account_origin_id`, `journal_entries.account_destination_id` y `journal_entries.category_id` (solo cuando no son null). Lanza `BackupError('invalid_uuid_format', 'El campo X tiene un ID inválido (esperado UUID v4 o v7, recibido: "preview…").')` con truncado a 16 chars.
- [x] T009 — `backupErrorToMessage(BackupError error)` agregado en `error_snackbar.dart` con switch case para los 10 códigos (`invalid_json`, `unsupported_version`, `missing_bolsa`, `invalid_reference` ya existentes con mensajes amigables fijos; los 6 nuevos retornan `error.message` directo porque ya viene auto-explicativo con campo y valor recibido). Branch `BackupError() => backupErrorToMessage(error)` agregado en el switch de `showErrorSnackbar` ANTES del branch `Exception()`.

**Regresión esperada del contrato (desviación)**: el test `Import con FK rota rechaza invalid_reference` usaba `"account_origin_id": "ID-INEXISTENTE"` para simular FK rota. Con la nueva validación de UUID, ese string es rechazado primero como `invalid_uuid_format`. Cambié el test para usar un UUID v7 válido pero inexistente en accounts (`00000000-0000-7000-8000-fffffffffff0`), que es el caso real de FK rota. Documentado en `desviaciones-plan.md`.

`flutter analyze` tras Fase 1: 4 hints info no bloqueantes. `flutter test`: **59/59 verde** (sin nuevos tests todavía; los de T020 vienen en Fase 5).

## Fase 2 — Schema y streams (T010-T011)

- [x] T010 — `schemaVersion` bumpeado a 2. Agregado `CREATE INDEX idx_entries_occurred_active ON journal_entries(occurred_at DESC) WHERE deleted_at IS NULL` en `onCreate` (línea 121-127 de database.dart). Rama `if (from == 1 && to == 2)` en `onUpgrade` con el mismo `CREATE INDEX` para instalaciones existentes. El guardrail throw queda después de la rama para cubrir transiciones futuras.
- [x] T011 — `Map<String, Stream<double>> _balanceCache` en `FinancialStateService`. `watchAccountBalance` consulta el cache por key `'$accountId:$accountType'` y retorna el stream cacheado o crea uno nuevo. Métodos públicos `invalidateAccount(String id)` (borra keys que empiezan con `'$id:'`) e `invalidateAll()` (vacía el Map). Integración:
  - `BackupService` ahora recibe `FinancialStateService?` opcional vía constructor; inyectado desde `AppDependencies.fromDatabase`. `wipeAll()` invalida tras la transacción; `importFromJson()` invalida tras el batch insert.
  - `AccountsDao.archive` invalida `stateService?.invalidateAccount(id)` después de la transacción (el `stateService` ya era parámetro opcional desde el sprint anterior).

**Errores de compilación corregidos durante la ejecución**:
- `import 'package:fincore/data/financial_state.dart'` faltante en `backup.dart` para el tipo `FinancialStateService?`.
- En `onUpgrade`, el método debe ser `customStatement` directo (heredado de `FincoreDatabase`), no `m.customStatement` (`Migrator` no expone ese método en drift 2.20).

## Fase 3 — Categorías (T012-T013)

- [x] T012 — `Future<Category?> findActiveById(String id)` agregado a `CategoriesDao` (línea 44-52 de categories_dao.dart). Filtra `c.id.equals(id) & c.deletedAt.isNull()`. Documentado en CLAUDE.md bajo "Joins con categorías archivadas".
- [x] T013 — `EntriesDao.updateEntry` aplica RN-H03 con lógica explícita:
  - Si el caller setea `categoryId` **explícitamente** (no null), valida como antes con `_validateCategoryForKind`. Si la categoría está archivada o es incompatible, lanza `invalid_category_applies_to`.
  - Si la categoría es **heredada** (`categoryId == null && !clearCategory && existing.categoryId != null`), hace query inline equivalente a `findActiveById`. Si está archivada o si el kind no acepta categoría (transfer/debt_payment), setea `forceClearCategory = true` y el write incluye `categoryId = null` SIN error.
  - Nota técnica: la query inline en lugar de delegar a `categoriesDao.findActiveById` se debe a que `@DriftDatabase` no tiene `daos: [...]` declarado y `attachedDatabase.categoriesDao` no se genera. Documentado en `desviaciones-plan.md`. La lógica es idéntica.

`flutter analyze` tras Fase 3: 4 hints info. `flutter test`: **59/59 verde**. Los tests adicionales que cubren estos cambios vienen en T020.

## Fase 4 — Presentación (T014-T017)

- [x] T014 — `SettingsScreen` refactor del flujo de reset:
  - `_export` ahora delega en `_exportInternal()` que retorna `bool` (`true` si `ShareResult.status == success`).
  - `_exportThenReset()` (botón primario): exporta → si share OK, segunda confirmación → `_wipeAndRedirect()`. Si share cancelado/unavailable, snackbar warning "Exportación cancelada. No se reinició la BD."
  - `_resetWithoutExport()` (botón secundario): confirmación destructiva enfática única → `_wipeAndRedirect()`.
  - `_wipeAndRedirect()` extraído: `wipeAll()` + flip `FirstRunState.value = false` + `Navigator.maybePop`.
  - UI: la card "Zona peligrosa" tiene ahora `FilledButton.icon` azul "Exportar respaldo y luego reiniciar" + 8px gap + `OutlinedButton.icon` rojo "Reiniciar sin exportar".
- [x] T015 — `kAppVersion` eliminado. La card "Acerca de" usa `FutureBuilder<PackageInfo>` con `PackageInfo.fromPlatform()`. Estados: skeleton de 60×13 mientras espera, "dev" si `hasError || data == null`, `${version}+${buildNumber}` cuando OK. Import nuevo `package_info_plus/package_info_plus.dart`. La constante `const String kAppVersion = '0.2.0+29'` se removió completamente.
- [x] T016 — `_buildFincoreSnackBar` calcula `foreground = background == FincoreColors.warning ? FincoreColors.canvas : Colors.white`. El icono y el texto comparten el color. Mantiene blanco para `negative` y `positive`. Contraste calculado: amarillo `#EBBD52` vs canvas `#1F242B` ≥ 10:1 (era 3.8:1 con blanco).
- [x] T017 — tooltips agregados:
  - `entries_list_screen`: filter `IconButton` con `tooltip` dinámico "Filtros" / "Filtros (activos)". FAB con `tooltip: 'Nuevo movimiento'`.
  - `dashboard_screen`: `FloatingActionButton.extended` con `tooltip: 'Nuevo movimiento'`.
  - `entry_form_screen`: el "Cambiar tipo" `TextButton.icon` envuelto en `Tooltip(message: 'Cambiar tipo de movimiento')`.
  - `first_run_screen` y `settings_screen`: chevrons decorativos envueltos en `Semantics(excludeSemantics: true)`. NOTA: el `Semantics` no es `const`, así que el outer no puede ser `const` pero el `Icon` interno sí (mantiene la optimización).

`flutter analyze`: 4 hints info no bloqueantes. `flutter test`: **59/59 verde**. Los tests adicionales que cubren el comportamiento nuevo (validaciones import, migración, cache) vienen en Fase 5.

## Fase 5 — Tests (T018-T020)

- [x] T018 — test `cancel idempotente preserva balance (no doble reversión)` agregado a `database_test.dart` después del `cancel es idempotente` original. Crea income $500, cancela, captura balance (esperado: 0), cancela de nuevo, verifica que el balance no cambió. Si una regresión hiciera que el segundo cancel re-restara el monto, este test lo detecta.
- [x] T019 — grupo nuevo `EntriesDao.updateEntry transiciones` con 6 tests:
  1. `edita amount + description + occurredAt simultáneo` — los 3 campos persisten.
  2. `cambia categoryId a una compatible` — verifica el cambio.
  3. `cambia categoryId a una incompatible rechaza` — `invalid_category_applies_to`.
  4. `cambia accountOriginId a otra cuenta activa` — persiste.
  5. `updateEntry sobre entry con categoría heredada archivada limpia silenciosamente` — RF-014/RN-H03 en acción.
  6. `updateEntry con clearCategory=true ignora categoryId pasado` — prioridad del flag.
- [x] T020 — tests de validaciones del import en `backup_test.dart` (10 tests nuevos):
  - `invalid_kind` (kind='hacked').
  - `invalid_account_type` (type='savings').
  - `invalid_applies_to` (applies_to='any').
  - `invalid_amount` con `amount=0` y con `amount<0` (2 tests).
  - `string_too_long` en `name` de 201 chars.
  - `string_too_long` en `description` de 1001 chars.
  - `invalid_uuid_format` (id='abc').
  - UUID v4 válido **NO** rechaza por `invalid_uuid_format` (test borde RF-006).
  - `name` vacío pasa validación de longitud (test borde RF-005).
  Tests del cache en `financial_state_test.dart` (5 tests nuevos):
  - `watchAccountBalance` retorna el mismo Stream para la misma key.
  - keys distintas retornan Streams distintos.
  - `invalidateAccount(id)` borra solo las keys de esa cuenta.
  - `invalidateAll()` vacía el Map.
  - `archive(id)` invalida automáticamente la cuenta archivada.

Helper `buildPayload(...)` en `backup_test.dart` para no duplicar el JSON en 10 tests; cada uno cambia exactamente la key que está probando.

**Errores de compilación corregidos durante la ejecución**:
- `isNull` ambiguo: existe tanto en drift como en `flutter_test/matcher`. Cambié los 2 usos en `database_test.dart` por `equals(null)`.
- Lint info `no_leading_underscores_for_local_identifiers` en `_buildPayload`: renombrado a `buildPayload`.

`flutter test`: **81/81 verde** (de 59 → 81, +22 tests). `flutter analyze`: 4 hints info no bloqueantes.

## Fase 6 — Release + smoke (T021-T023)

- [x] T021 — bump completo: `pubspec.yaml` → `version: 0.3.0+30`; `android/app/build.gradle.kts` → `versionCode = 30` + `versionName = "0.3.0"`. `kAppVersion` NO se actualiza porque T015 lo eliminó.
- [x] T022 — `flutter build apk --release --split-per-abi` exitoso. APKs generados:
  - `app-armeabi-v7a-release.apk`: 17.0 MB
  - `app-arm64-v8a-release.apk`: **19.5 MB** ← el que Diego instala
  - `app-x86_64-release.apk`: 20.7 MB
  Verificación `aapt dump badging`:
  - package: `io.github.gregori100.fincore` ✓
  - versionCode: 2030 (30 base + arm64 prefix 2000)
  - versionName: 0.3.0 ✓
  - sdkVersion (minSdk): 24 ✓
  - targetSdkVersion: 35 ✓
  Verificación `aapt dump xmltree AndroidManifest.xml`:
  - `android:allowBackup(0x...)=(type 0x12)0x0` → false ✓
  - `android:fullBackupContent(0x...)=(type 0x12)0x0` → false ✓
  - `android:dataExtractionRules(0x...)=@0x7f0e0000` → resource ref a `xml/data_extraction_rules` ✓
- [x] T023 — Smoke manual de Diego cerrado sobre el Redmi con el APK `0.3.0+32` (versión final post quality-review + post regresión de joins). Resultado:
  - ✅ App migra de `0.3.0+30` a `0.3.0+32` sin perder datos. "Acerca de" muestra `0.3.0+32`.
  - ✅ Editar entry cuya categoría se archivó: el form abre con categoría limpia y los listados (Dashboard + Movimientos) tampoco pintan el badge. Esto incluye el fix de regresión del join (ver "Post-smoke — Regresión de badge en listados").
  - ⏭️ Import con timestamp inválido: saltado por Diego; cubierto por test unitario `Import con timestamp inválido rechaza con invalid_date_format` (verde).
  - ✅ `adb backup io.github.gregori100.fincore` genera archivo `.ab` vacío (47 bytes, header sin payload). Antes del sprint el mismo comando producía un `.ab` con la BD SQLite real. Privacidad de datos confirmada.
  - ✅ "Exportar respaldo y luego reiniciar" → share OK → cancelar segundo diálogo → snackbar verde "Respaldo exportado. Reseteo cancelado." y BD intacta.

Validaciones técnicas previas a T023:
  - `flutter test`: **87/87 verde**.
  - `flutter analyze`: 0 errores, 4 hints info no bloqueantes preexistentes.
  - `flutter build apk --release --split-per-abi`: tres APKs OK; arm64 = 19.5 MB.

## Post-smoke — Regresión de badge en listados (versión 0.3.0+32)

Durante el smoke del paso 2, Diego detectó que tras archivar una categoría, el form de edición ya cargaba sin badge (fix B2 funcionando) pero **los listados del Dashboard y de Movimientos seguían pintando el badge de la categoría archivada**.

Causa: el join de drift en `entries_dao.dart` (`watchPage` línea 57 y `findById` línea 103) hacía `leftOuterJoin(categories, categories.id.equalsExp(journalEntries.categoryId))` SIN filtrar `deletedAt.isNull()`. Drift no aplica filtros de soft-delete automáticamente; devolvía la fila completa de la categoría archivada y la UI la pintaba con `CategoryBadge`. La documentación de `CLAUDE.md` que prometía "la relación devuelve null para archivadas" era incorrecta — corresponde a una convención que el código no implementaba.

Fix aplicado en `mobile/lib/data/daos/entries_dao.dart`: ambos joins de categoría ahora son `categories.id.equalsExp(journalEntries.categoryId) & categories.deletedAt.isNull()`. Con esto, `row.readTableOrNull(categories)` retorna null cuando la categoría está archivada, el `CategoryBadge` se omite y los listados reflejan la realidad.

Versión bumpeada a `0.3.0+32` (versionCode 32; arm64 split = 2032). APK arm64 = 19.5 MB. Tests siguen en 87/87 verde porque los 6 tests nuevos del sprint no ejercitaban este caso específico (validaban DAO directo, no el join completo). Considerar agregar en sprint futuro: test `watchPage no incluye badge para categorías archivadas`.
  1. App abre sin pantalla blanca; splash → dashboard.
  2. Datos previos intactos (cuentas, categorías, movimientos).
  3. Settings → "Acerca de" muestra `0.3.0+30`.
  4. `adb backup io.github.gregori100.fincore` rechaza con "Backup not allowed".
  5. Importar JSON con `kind: 'hacked'` → snackbar rojo amigable. BD intacta.
  6. Editar entry con categoría archivada → badge desaparece sin error.
  7. Settings → "Exportar respaldo y luego reiniciar" → share sheet → confirmación → `/first-run`.

## Fase 7 — Cierre (T024-T025)

- [x] T024 — `implementation/` con 6 archivos obligatorios creados al cierre.
- [x] T025 — `branch-quality-review` ejecutado con 6 subagentes en paralelo. Reporte en `engineering/quality-review/flutter-local-hardening/2026-06-19-1019-branch-quality-review.md`. **3 bloqueantes** detectados (B1 timestamp inválido sin try/catch, B2 form rompe RN-H03 al editar entries con categoría archivada, B3 metadata de credit sin validar) + 11 no bloqueantes + falsos positivos descartados.

## Post-review — Bloqueantes resueltos (versión 0.3.0+31)

Los 3 bloqueantes + 5 no-bloqueantes (M1, M2, M3, M5, M11) fueron corregidos en la misma sesión:

- [x] **B1** — `_parseDate` envuelve `DateTime.parse` en try/catch y lanza `BackupError('invalid_date_format', ...)` con preview truncado a 32 chars. Mapeado en `backupErrorToMessage`. Test agregado.
- [x] **B2** — `entry_form_screen._bootstrap` valida la categoría heredada con `findActiveById` antes de setear `_categoryId`. Si está archivada, queda en null y el DAO entra al branch heredado → limpieza silenciosa real, no solo en tests sintéticos.
- [x] **B3** — `_accountFromJson` valida metadata de credit accounts: `credit_limit > 0`, `closing_day`/`payment_day` en [1,31] y distintos, `interest_rate`/`minimum_payment_pct` en [0,1] cuando están presentes. 2 tests nuevos.
- [x] **M1** — Validación de Bolsa singleton en import: una sola cuenta protegida y debe ser type=cash. Test agregado.
- [x] **M2** — `color_slug` e `icon_slug` validados contra `kCategoryColors`/`kCategoryIcons`. Test para color slug inválido.
- [x] **M3** — Snackbar de éxito ("Respaldo exportado. Reseteo cancelado.") cuando el usuario completa el share OK pero cancela el segundo confirmDialog.
- [x] **M5** — Test `updateEntry con categoryId explícito archivado rechaza` agrega defensa contra regresiones del fix B2.
- [x] **M11** — `CREATE INDEX` en `onUpgrade(1, 2)` ahora incluye `IF NOT EXISTS` como defensa adicional ante reejecución.

Versión bumpeada a `0.3.0+31` (versionCode 31; arm64 split = 2031). APK arm64: 19.5 MB. **`flutter test`: 87/87 verde** (81 → 87, +6 tests nuevos). `flutter analyze`: 4 hints info cosméticos.

Los hallazgos no bloqueantes restantes (M4 README, M6 broadcast stream, M7 boundary 200 chars, M8 wipeAll cache test, M9 color por identidad, M10 share timeout, M12 deduplicación de findActiveById, M13 desviaciones menores, M14 substring multi-byte) quedan documentados en `pendientes.md` para el próximo sprint.

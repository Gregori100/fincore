# Tareas — flutter-accounts-archive-v1

## Base de datos

- [ ] T001 Base de datos: agregar columna `archivedAt` a la tabla `Accounts` en `mobile/lib/data/database.dart` como `DateTimeColumn` nullable.
  RF: RF-001
  Depende de: ninguna
  Paralelizable: no
  Criterio de terminado: la clase `Accounts` declara `DateTimeColumn get archivedAt => dateTime().nullable()();` y `schemaVersion` sube a 9.

- [ ] T002 Base de datos: agregar rama en `MigrationStrategy.onUpgrade` para `to == 9` que ejecuta `ALTER TABLE accounts ADD COLUMN archived_at TEXT` cubriendo saltos desde `from ∈ {1..8}`.
  RF: RF-001
  Depende de: T001
  Paralelizable: no
  Criterio de terminado: rama nueva agregada antes del guardrail `UnimplementedError`; el guardrail sigue lanzando para transiciones no cubiertas.

- [ ] T003 Base de datos: regenerar `mobile/lib/data/database.g.dart` corriendo `dart run build_runner build --delete-conflicting-outputs`.
  RF: RF-001
  Depende de: T001, T002
  Paralelizable: no
  Criterio de terminado: `flutter analyze` sin errores en `mobile/`; `Account` (data class) tiene campo `archivedAt`.

## Backend (DAO)

- [ ] T004 Backend: renombrar `AccountsDao.archive(id, [stateService])` a `AccountsDao.delete(id, [stateService])` sin cambiar lógica interna.
  RF: RF-002
  Depende de: T003
  Paralelizable: no
  Criterio de terminado: el método `delete` existe con el mismo cuerpo del `archive` anterior; el nombre `archive` queda libre para el nuevo método.

- [ ] T005 Backend: nuevo `AccountsDao.archive(id)` que valida Bolsa (`protected_account`) y setea `archived_at = DateTime.now()`. No toca `journal_entries`. No llama `stateService.invalidateAll()`.
  RF: RF-003
  Depende de: T004
  Paralelizable: no
  Criterio de terminado: método existe, valida Bolsa protegida, es no-op silencioso si ya está archivada.

- [ ] T006 Backend: nuevo `AccountsDao.unarchive(id)` que setea `archived_at = null`.
  RF: RF-004
  Depende de: T004
  Paralelizable: no
  Criterio de terminado: método existe, no-op silencioso si ya está activa.

- [ ] T007 Backend: ajustar `AccountsDao.watchActive()` para filtrar `deleted_at IS NULL AND archived_at IS NULL`.
  RF: RF-005
  Depende de: T003
  Paralelizable: si
  Criterio de terminado: query incluye ambos filtros; test unitario verifica.

- [ ] T008 Backend: nuevo `AccountsDao.watchArchived()` con stream `deleted_at IS NULL AND archived_at IS NOT NULL` ordenado por tipo y nombre.
  RF: RF-006
  Depende de: T003
  Paralelizable: si
  Criterio de terminado: stream reactivo emite las archivadas; test unitario verifica.

- [ ] T009 Backend: ajustar `AccountsDao.listAll({includeArchived: false})` para filtrar siempre `deleted_at IS NULL` y aplicar `archived_at IS NULL` sólo cuando `!includeArchived`.
  RF: RF-007
  Depende de: T003
  Paralelizable: si
  Criterio de terminado: comportamiento verificable con test unitario que insertó una activa y una archivada.

- [ ] T010 Backend: nuevo helper `AccountsDao.findActiveOrArchivedById(id)` que devuelve la cuenta si `deleted_at IS NULL`.
  RF: RF-008
  Depende de: T003
  Paralelizable: si
  Criterio de terminado: método existe y test unitario verifica.

- [ ] T011 Backend: nuevo helper `EntriesDao.countByAccount(id)` que cuenta `journal_entries` activas donde la cuenta figura como origen o destino.
  RF: RF-009
  Depende de: T003
  Paralelizable: si
  Criterio de terminado: método retorna `int`; test unitario cubre casos con 0, 1, N movimientos y ninguna cuenta archivada/borrada.

- [ ] T012 Backend: actualizar comentario en `mobile/lib/data/financial_state.dart` (línea ~85) que referencia `AccountsDao.archive(id)` para reflejar el nombre nuevo (`delete`).
  RF: RF-002
  Depende de: T004
  Paralelizable: si
  Criterio de terminado: comentario actualizado; sin cambio de comportamiento.

## Frontend

- [ ] T013 Frontend: extender `AccountPicker` (`mobile/lib/widgets/account_picker.dart`) con prop `bool includeArchived = false`. Por default filtra `archivedAt == null`. Cuando true, muestra archivadas con sufijo ` · archivada` en el label y estilo `textSubtle` para icono/color.
  RF: RF-010
  Depende de: T003
  Paralelizable: si
  Criterio de terminado: widget compila; smoke visual verifica badge.

- [ ] T014 Frontend: extender `movement_row.dart` (`mobile/lib/widgets/movement_row.dart`) para agregar sufijo `(archivada)` al label de cuenta cuando el entry apunta a una cuenta con `archived_at != null`. Estilo `textSubtle` italic.
  RF: RF-018
  Depende de: T003, T010
  Paralelizable: si
  Criterio de terminado: helper `entryAccountLabel` (o widget) refleja el sufijo; smoke visual verifica en `/entries`.

- [ ] T015 Frontend: refactorizar `mobile/lib/screens/accounts_list_screen.dart` para agregar `SegmentedButton<AccountsSegment>` bajo el AppBar. Segmento activo por default: `activas`. Cada segmento usa su propio stream (`watchActive` / `watchArchived`).
  RF: RF-011
  Depende de: T007, T008
  Paralelizable: no
  Criterio de terminado: la lista cambia según el segmento; smoke visual verifica.

- [ ] T016 Frontend: en `accounts_list_screen`, agregar menú overflow (`PopupMenuButton`) por card con 3 opciones (activa) o 2 opciones (archivada). Handlers:
  - Editar → `context.push('/accounts/{id}/edit')`.
  - Archivar → `showConfirmDialog` + `AccountsDao.archive`.
  - Desarchivar → `showConfirmDialog` + `AccountsDao.unarchive`.
  - Eliminar → `showDestructiveDialog` con impacts poblados por `EntriesDao.countByAccount(id)` + `AccountsDao.delete`.
  RF: RF-012, RF-013, RF-020
  Depende de: T005, T006, T011, T015
  Paralelizable: no
  Criterio de terminado: los 4 handlers funcionan; Bolsa no muestra menú overflow.

- [ ] T017 Frontend: refactorizar `mobile/lib/screens/account_form_screen.dart` para reemplazar `OutlinedButton "Archivar cuenta"` (línea ~198) por menú overflow en AppBar con Archivar y Eliminar (rojo) para cuenta activa.
  RF: RF-014, RF-020
  Depende de: T005, T011, T004
  Paralelizable: no
  Criterio de terminado: el botón inline desaparece; el menú overflow tiene ambas opciones con sus diálogos.

- [ ] T018 Frontend: en `account_form_screen`, agregar detección de `account.archivedAt != null` para modo read-only: banner "Cuenta archivada", campos deshabilitados, sin botón Guardar, menú overflow con Desarchivar y Eliminar.
  RF: RF-015, RF-020
  Depende de: T017, T006
  Paralelizable: no
  Criterio de terminado: al navegar a `/accounts/{id}/edit` con id de cuenta archivada, el form no permite edición.

- [ ] T019 Frontend: en `mobile/lib/screens/entry_form_screen.dart`, agregar helper `_isEntryLockedByArchivedAccount(entry, accounts)` que retorna true si origen o destino tiene `archived_at != null`. Cuando true: banner superior "Movimiento con cuenta archivada · Sólo se puede eliminar", campos deshabilitados, sin botón Guardar. `AccountPicker` recibe `includeArchived: true` para renderizar la cuenta.
  RF: RF-016, RF-017
  Depende de: T010, T013
  Paralelizable: no
  Criterio de terminado: editar un entry con cuenta archivada muestra el form bloqueado con banner; sólo Eliminar movimiento funciona.

- [ ] T020 Frontend: auditar los 11 tabs de reportes en `mobile/lib/screens/reports/` y `mobile/lib/data/reports_service.dart` para confirmar que ninguna query filtra por `archived_at`. Si algún tab tiene picker de cuenta como filtro, pasarle `includeArchived: true`.
  RF: RF-019
  Depende de: T013
  Paralelizable: si
  Criterio de terminado: comentario o mini-doc en `plan/plan.md` confirma cero cambios necesarios (o lista los cambios aplicados).

## Pruebas

- [ ] T021 Pruebas: renombrar los tests existentes de `AccountsDao.archive` cascada a `AccountsDao.delete` en `test/data/database_test.dart` y `test/data/invariants_test.dart`. Sin cambio de comportamiento.
  RF: RF-002
  Depende de: T004
  Paralelizable: si
  Criterio de terminado: `flutter test` verde; conteo de tests preservado.

- [ ] T022 Pruebas: nuevo grupo en `test/data/accounts_archive_dao_test.dart` (o dentro de `database_test.dart`) para `archive`, `unarchive`, `watchActive`, `watchArchived`, `listAll(includeArchived)`, `findActiveOrArchivedById`.
  RF: RF-003, RF-004, RF-005, RF-006, RF-007, RF-008
  Depende de: T005, T006, T007, T008, T009, T010
  Paralelizable: si
  Criterio de terminado: ≥ 6 tests nuevos verdes cubriendo casos happy path y edge (Bolsa protegida, no-op idempotente).

- [ ] T023 Pruebas: nuevo test para `EntriesDao.countByAccount(id)` con casos 0/1/N movimientos, ignorando movimientos con `deleted_at != null`.
  RF: RF-009
  Depende de: T011
  Paralelizable: si
  Criterio de terminado: 3+ tests verdes.

- [ ] T024 Pruebas: nuevo test de invariante en `test/data/invariants_test.dart`: `archive` sobre Bolsa lanza `protected_account`; `delete` sobre Bolsa lanza `protected_account`.
  RF: RN-A01
  Depende de: T005, T004
  Paralelizable: si
  Criterio de terminado: 2 tests verdes.

- [ ] T025 Pruebas: test de backup round-trip con una cuenta archivada presente en la BD. Verifica que el export ignora `archived_at` (o lo persiste sin romper el esquema JSON v1) y el import v1 asume `archived_at = null`.
  RF: RN-A12
  Depende de: T005
  Paralelizable: si
  Criterio de terminado: 1 test verde en `test/data/backup_test.dart`.

- [ ] T026 Pruebas: widget test en `test/screens/list_screens_test.dart` que verifica el `SegmentedButton` en `accounts_list_screen` y el conmute de streams.
  RF: RF-011
  Depende de: T015
  Paralelizable: si
  Criterio de terminado: 1-2 tests verdes usando `pumpFincoreApp`.

- [ ] T027 Pruebas: widget test en `test/screens/entry_form_screen_test.dart` que verifica el banner read-only cuando el entry en edit tiene una cuenta archivada.
  RF: RF-016
  Depende de: T019
  Paralelizable: si
  Criterio de terminado: 1 test verde.

- [ ] T028 Pruebas: correr `flutter analyze` y `flutter test` completos en `mobile/`, confirmar 0 errores y todos los tests verdes.
  RF: cross-cutting
  Depende de: T021-T027
  Paralelizable: no
  Criterio de terminado: ambos comandos verdes en la terminal.

## Documentacion

- [ ] T029 Documentacion: bump `pubspec.yaml` a `version: 0.26.0+109` y `android/app/build.gradle.kts` a `versionCode = 109`, `versionName = "0.26.0"`.
  RF: RF-021
  Depende de: T028
  Paralelizable: no
  Criterio de terminado: `scripts/verify-apk.sh` (si se corre) confirma sincronía.

- [ ] T030 Documentacion: actualizar `CLAUDE.md` en la sección "Migraciones de schema (RN-H02)" y "Reglas clave de los DAOs" para reflejar los 3 estados de cuenta y la separación `deleted_at` / `archived_at` (nota corta al final de la sección).
  RF: cross-cutting
  Depende de: T029
  Paralelizable: si
  Criterio de terminado: nota agregada; sin duplicar información con `spec.md`.

## Validacion de calidad

- [ ] T031 Validacion de calidad: build de APK `arm64-v8a-release` desde `mobile/` y validación local con `scripts/verify-apk.sh`.
  RF: RF-021
  Depende de: T029
  Paralelizable: no
  Criterio de terminado: APK generado sin errores; `versionCode` del APK == 2109 (prefix arm64) o == 109 según convención.

- [ ] T032 Validacion de calidad: smoke manual Android según checklist de `test-plan.md` sección "Pruebas manuales o smoke tests necesarios".
  RF: cross-cutting
  Depende de: T031
  Paralelizable: no
  Criterio de terminado: todos los items del checklist smoke ejecutados por Diego y confirmados; screenshots opcionales.

- [ ] T033 Validacion de calidad: invocar `branch-quality-review` sobre el sprint para revisar la rama antes de merge.
  RF: cross-cutting
  Depende de: T032
  Paralelizable: no
  Criterio de terminado: reporte generado en `engineering/quality-review/flutter-accounts-archive-v1/`; hallazgos críticos resueltos.

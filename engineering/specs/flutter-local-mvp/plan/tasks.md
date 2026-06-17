# Tasks — flutter-local-mvp

Tareas en orden de dependencia, agrupadas por fase. Las tareas **T001 y T050** son responsabilidad del usuario (Diego). Las demás las ejecuta el agente.

## Fase 0 — Pre-pivote (DESCARTADA el 2026-06-17)

- [x] T001 (DESCARTADA). Diego decidió arrancar de cero sin migrar los datos del backend. El JSON del backend legacy no se exporta ni se importa al MVP. Si en el futuro quiere recuperar el histórico, queda accesible haciendo `git checkout legacy/web-and-online-flutter` y levantando el stack docker. La pantalla "Primer arranque" mantiene el botón "Importar respaldo" por resiliencia para los backups propios que Diego genere desde Settings tras empezar a usar la app.

## Fase 1 — Preservar legacy

- [ ] T002 Frontend: crear rama `legacy/web-and-online-flutter` desde el commit actual de `main`. Comando: `git checkout -b legacy/web-and-online-flutter main`. Push a origin: `git push -u origin legacy/web-and-online-flutter`.
  RF: RF-001
  Depende de: ninguna
  Paralelizable: no
  Criterio de terminado: `git branch -a` lista `remotes/origin/legacy/web-and-online-flutter` y `git log origin/legacy/web-and-online-flutter -1` muestra el commit reciente del cliente online.

- [ ] T003 Validación de calidad: verificar que la rama legacy tiene todo el código que se va a borrar. Comandos: `git log origin/legacy/web-and-online-flutter -- backend/ frontend/ mobile/lib/api/ | head -5` (debe mostrar commits reales), `git show origin/legacy/web-and-online-flutter:backend/composer.json | head -5` (debe mostrar el composer.json del backend), `git show origin/legacy/web-and-online-flutter:mobile/lib/api/auth_api.dart | head -3` (debe mostrar el archivo del cliente online).
  RF: RF-001
  Depende de: T002
  Paralelizable: no
  Criterio de terminado: los 3 comandos arriba responden correctamente, demostrando que la rama legacy preserva backend + frontend + mobile online.

## Fase 2 — Destruir legacy en main

- [ ] T004 Base de datos / Frontend: volver a main (`git checkout main`) y borrar en un solo commit todo el código legacy:
  - `git rm -rf backend/ frontend/ mobile/ db/ docker/ tests-e2e/ test-results/ node_modules/`
  - `git rm -f compose.yaml compose.tailscale.yml Dockerfile fly.toml`
  - `git rm -f scripts/install.sh scripts/fincore`
  - `git rm -rf docs/api docs/cli docs/frontend docs/scripts docs/deploy.md docs/deploy-tailscale.md`
  - `git rm -f package.json package-lock.json`
  - `git rm -f .env.example .env.tailscale 2>/dev/null || true`
  - `git commit -m "chore(pivote): borrar legacy backend, frontend, mobile online y stack docker"`
  Conservar: `engineering/`, `.git/`, `README.md`, `CLAUDE.md`, `.gitignore`. `engineering/` se mantiene completo con todas las specs históricas.
  RF: RF-002
  Depende de: T003 verificada (T001 descartada)
  Paralelizable: no
  Criterio de terminado: `ls` en raíz de main muestra solo `engineering/`, `README.md`, `CLAUDE.md`, `.gitignore`. `git log -1 --stat` muestra el commit de borrado con miles de líneas eliminadas.

- [ ] T005 Validación de calidad: confirmar antes de continuar que el código legacy sigue accesible desde la rama, no perdido. `git show legacy/web-and-online-flutter:mobile/lib/theme/fincore_colors.dart | head -10` debe mostrar el archivo. Si falla, abortar T006 y reproducir T002+T003.
  RF: RF-001
  Depende de: T004
  Paralelizable: no
  Criterio de terminado: el archivo se muestra correctamente desde la rama legacy.

## Fase 3 — Fundación Flutter local

- [ ] T006 Frontend: crear proyecto Flutter en `mobile/` desde cero. Comando ejecutado desde raíz: `flutter create --org io.github.gregori100 --project-name fincore --platforms=android,linux mobile`. Esto recrea la carpeta `mobile/` que T004 dejó borrada.
  RF: RF-003
  Depende de: T004
  Paralelizable: no
  Criterio de terminado: `mobile/pubspec.yaml` existe y `mobile/lib/main.dart` es el default de flutter create. `mobile/android/` y `mobile/linux/` existen, `mobile/ios/` `mobile/macos/` `mobile/windows/` `mobile/web/` NO existen.

- [ ] T007 Frontend: configurar `mobile/android/app/build.gradle.kts` con `applicationId = "io.github.gregori100.fincore"`, `versionCode = 2`, `versionName = "0.2.0"`, `minSdk = 24`, `targetSdk = 35`. Si share_plus exige Kotlin 2.1, ajustar también `android/settings.gradle.kts`.
  RF: RF-003, P-002
  Depende de: T006
  Paralelizable: si (con T008)
  Criterio de terminado: `grep "io.github.gregori100.fincore" mobile/android/app/build.gradle.kts && grep "versionCode = 2" mobile/android/app/build.gradle.kts && grep "versionName = \"0.2.0\"" mobile/android/app/build.gradle.kts`.

- [ ] T008 Frontend: configurar `mobile/android/app/src/main/AndroidManifest.xml` con `android:label="FinCore"`, `xmlns:tools`, declarar únicamente `<uses-permission android:name="android.permission.INTERNET"/>`. Eliminar `<queries>` de PROCESS_TEXT si flutter create lo agregó.
  RF: RN-015, RF-003
  Depende de: T006
  Paralelizable: si
  Criterio de terminado: `aapt dump permissions ...apk` después del build mostrará solo INTERNET + DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION (autogenerado por sistema).

- [ ] T009 Frontend: escribir `mobile/pubspec.yaml` con las dependencias definidas en plan.md: `flutter`, `cupertino_icons ^1.0.8`, `drift ^2.20.0`, `drift_flutter ^0.2.0`, `sqlite3 ^2.4.0`, `sqlite3_flutter_libs ^0.5.0`, `path ^1.9.0`, `path_provider ^2.1.0`, `intl ^0.19.0`, `go_router ^14.6.2`, `file_picker ^8.1.0`, `share_plus ^10.0.0`, `file_selector ^1.0.0`. DevDependencies: `flutter_test`, `flutter_lints ^5.0.0`, `mocktail ^1.0.4`, `drift_dev ^2.20.0`, `build_runner ^2.4.0`. Version del proyecto: `0.2.0+2`. Correr `flutter pub get`. Si alguna dep exige SDK > 3.7.2, anclar a versión compatible con el SDK actual.
  RF: RF-003
  Depende de: T006
  Paralelizable: si
  Criterio de terminado: `flutter pub get` completa sin error. `cat mobile/pubspec.yaml | grep "version:"` muestra `0.2.0+2`.

- [ ] T010 Frontend: crear `mobile/build.yaml` con la sección `targets > $default > builders > drift_dev` y opción `store_date_time_values_as_text: true`. Sin esto drift trunca subsegundos en DateTimeColumn (gotcha conocido de dogear). Documentar comentario en el archivo.
  RF: RF-004
  Depende de: T009
  Paralelizable: no
  Criterio de terminado: archivo existe y contiene `store_date_time_values_as_text: true`.

- [ ] T011 Frontend: configurar `mobile/analysis_options.yaml` incluyendo `package:flutter_lints/flutter.yaml` y reglas extras (`always_use_package_imports`, `prefer_const_constructors`, `prefer_final_locals`, `avoid_print`). Excluir generados: `**/*.g.dart`. Correr `flutter analyze` con main.dart default → debe ser limpio o solo warnings de prefer_const.
  RF: RF-018
  Depende de: T009
  Paralelizable: si
  Criterio de terminado: `flutter analyze` da "No issues found!" o tras un fix trivial de main.dart.

- [ ] T012 Frontend: crear `mobile/scripts/run-linux.sh` y `mobile/scripts/build-apk.sh` simplificados (sin FINCORE_API_URL; solo `flutter run -d linux` y `flutter build apk --release` respectivamente). Crear `mobile/scripts/codegen.sh` que ejecuta `dart run build_runner build --delete-conflicting-outputs`. Hacer ejecutables.
  RF: RF-019
  Depende de: T009
  Paralelizable: si
  Criterio de terminado: los 3 scripts son ejecutables y los `flutter run` / `flutter build apk` corren al menos hasta el primer error de código.

## Fase 4 — Portado desde legacy

- [ ] T013 Frontend: portar `mobile/lib/theme/fincore_colors.dart` y `mobile/lib/theme/fincore_theme.dart` desde la rama legacy. Comando: `git show legacy/web-and-online-flutter:mobile/lib/theme/fincore_colors.dart > mobile/lib/theme/fincore_colors.dart` y análogo para `fincore_theme.dart`. Verificar que `flutter analyze` sigue limpio (no debería referenciar a FincoreColors aún).
  RF: RF-014
  Depende de: T006
  Paralelizable: si
  Criterio de terminado: los 2 archivos existen en main con el contenido del legacy.

- [ ] T014 Frontend: portar `mobile/lib/constants/category_catalog.dart`, `mobile/lib/constants/kinds.dart`, `mobile/lib/constants/account_types.dart` desde la rama legacy con `git show`.
  RF: RF-013, RF-015
  Depende de: T006
  Paralelizable: si (con T013)
  Criterio de terminado: los 3 archivos existen y `flutter analyze` no marca errores de import en ellos.

- [ ] T015 Frontend: portar widgets compartidos desde legacy con `git show`: `widgets/amount_formatter.dart`, `widgets/base_card.dart`, `widgets/category_badge.dart`, `widgets/confirm_dialog.dart`, `widgets/error_snackbar.dart`, `widgets/account_type_picker.dart`, `widgets/applies_to_picker.dart`, `widgets/color_picker.dart`, `widgets/icon_picker.dart`, `widgets/kind_picker.dart`. NO portar `widgets/account_picker.dart` ni `widgets/category_picker.dart` por ahora (consumen modelos del cliente online; se rehacen en T032).
  RF: RF-014
  Depende de: T013, T014
  Paralelizable: si
  Criterio de terminado: los archivos existen y compilan tras T016 (modelos).

## Fase 5 — Capa de datos

- [ ] T016 Frontend: crear `mobile/lib/data/database.dart` con las 3 tablas drift anotadas:
  - `Accounts`: `text() id` PK, `text() name`, `text() type`, `text() description nullable`, `boolean() isProtected default false`, `real() creditLimit nullable`, `integer() closingDay nullable`, `integer() paymentDay nullable`, `real() interestRate nullable`, `real() minimumPaymentPct nullable`, `dateTime() createdAt`, `dateTime() updatedAt`, `dateTime() deletedAt nullable`.
  - `Categories`: `text() id` PK, `text() name`, `text() appliesTo`, `text() colorSlug`, `text() iconSlug`, `real() monthlyLimit nullable`, `dateTime() createdAt`, `dateTime() updatedAt`, `dateTime() deletedAt nullable`.
  - `JournalEntries`: `text() id` PK, `text() kind`, `text() accountOriginId nullable references Accounts(id)`, `text() accountDestinationId nullable references Accounts(id)`, `real() amount` con check > 0, `text() description nullable`, `dateTime() occurredAt`, `text() categoryId nullable references Categories(id)`, `dateTime() createdAt`, `dateTime() updatedAt`, `dateTime() deletedAt nullable`.
  - Clase `FincoreDatabase extends _$FincoreDatabase` con `schemaVersion = 1`, `MigrationStrategy.onUpgrade` stub, `beforeOpen` que ejecuta `PRAGMA foreign_keys = ON`, y constructor que recibe `QueryExecutor` (para inyección en tests).
  - Migración inicial que crea índices: `CREATE INDEX idx_entries_origin ON journal_entries(account_origin_id) WHERE deleted_at IS NULL`, `CREATE INDEX idx_entries_dest ON journal_entries(account_destination_id) WHERE deleted_at IS NULL`, `CREATE INDEX idx_entries_deleted ON journal_entries(deleted_at)`.
  - Helper `openDatabase()` para producción que usa `drift_flutter` con `path_provider.getApplicationDocumentsDirectory()`.
  RF: RF-004, RN-005
  Depende de: T009, T010
  Paralelizable: no
  Criterio de terminado: el archivo existe; `dart run build_runner build --delete-conflicting-outputs` genera `database.g.dart` sin error.

- [ ] T017 Frontend: correr codegen drift. Comando: `cd mobile && dart run build_runner build --delete-conflicting-outputs`. Verificar que `mobile/lib/data/database.g.dart` se generó. Sin esto los DAOs no compilan.
  RF: RF-004
  Depende de: T016
  Paralelizable: no
  Criterio de terminado: `mobile/lib/data/database.g.dart` existe; `flutter analyze` no marca errores en `database.dart`.

- [ ] T018 Frontend: crear `mobile/lib/data/daos/accounts_dao.dart` con métodos:
  - `Stream<List<AccountRow>> watchActive()` (filtra `deletedAt IS NULL`).
  - `Future<List<AccountRow>> listAll({bool includeArchived = false})`.
  - `Future<AccountRow?> findById(String id)`.
  - `Future<String> create({...})` con validaciones: rechaza si `type == 'cash'` (Bolsa singleton — RN-004), valida nombre único entre activas, valida `closing_day != payment_day` si type='credit'. Setea created_at + updated_at + uuid v7 generado.
  - `Future<void> update(String id, {...})` con validaciones: rechaza si `is_protected = true`, idem closing/payment.
  - `Future<void> archive(String id)` con validación de saldo cero (la consulta usa el StateService).
  - `Future<void> createBolsa()` interno usado por seed.dart.
  RF: RF-008, RN-004, RN-007, RN-013
  Depende de: T017
  Paralelizable: si
  Criterio de terminado: tests T039 verifican estos métodos.

- [ ] T019 Frontend: crear `mobile/lib/data/daos/categories_dao.dart` con métodos análogos: `watchActive({String? appliesTo})`, `listAll({bool includeArchived})`, `findById`, `create`, `update`, `archive`. Validaciones: nombre único entre activas, applies_to ∈ {income, expense, both}, color/icon slug del catálogo.
  RF: RF-009, RN-012
  Depende de: T017
  Paralelizable: si
  Criterio de terminado: tests T039 verifican.

- [ ] T020 Frontend: crear `mobile/lib/data/daos/entries_dao.dart` con métodos:
  - `Stream<List<EntryWithRelations>> watchPage({JournalKind? kind, String? accountId, DateTime? from, DateTime? to, int offset = 0, int limit = 50})`. Devuelve filas con joins a accounts (origen y destino) y category.
  - `Future<EntryWithRelations?> findById(String id)`.
  - `Future<String> registerIncome({...})`, `registerExpense({...})`, `registerCreditExpense({...})`, `registerDebtPayment({...})`, `registerTransfer({...})`. Cada uno valida los tipos de cuenta según RN-011 + OverpayDebt para debt_payment (consulta el StateService) + monto > 0.
  - `Future<void> updateEntry(String id, {amount?, description?, occurredAt?, categoryId?, accountOriginId?, accountDestinationId?})`. NO permite cambiar kind. Valida tipos de cuenta si se cambian.
  - `Future<void> cancel(String id)` (soft delete).
  RF: RF-010, RN-006, RN-011
  Depende de: T017, T018 (para validar saldo en debt_payment)
  Paralelizable: no
  Criterio de terminado: tests T039 y T042 verifican los 5 kinds + edit + cancel + OverpayDebt.

- [ ] T021 Frontend: crear `mobile/lib/data/financial_state.dart` con `FinancialStateService`:
  - `Stream<num> watchAccountBalance(String accountId, String type)` — query agregada según el tipo de cuenta (cash/debit suma destino menos origen; credit invertido).
  - `Stream<num> watchBo()`, `watchDe()`, `watchCr()` — agregados sobre cuentas activas.
  - `Future<num> accountBalanceNow(String accountId)` — versión sincrónica para validaciones del DAO (ej. archive).
  Implementación con `customSelect(sql, readsFrom: {accounts, journalEntries}).watchSingle()` para que drift detecte cambios. Sin estado adicional.
  RF: RF-011, RN-009, RN-010
  Depende de: T017
  Paralelizable: si
  Criterio de terminado: tests T040 verifican BO/DE/CR y saldos por cuenta para los 5 kinds.

- [ ] T022 Frontend: crear `mobile/lib/data/seed.dart` con `Future<void> seedDefaults(FincoreDatabase db)` que crea la Bolsa singleton + 10 categorías default. UUIDs v7. Idempotente: si ya hay Bolsa, no hace nada. Mismas categorías default y mismos color/icon slugs que `backend/app/Domain/Finance/Catalog/CategoryDefaults.php` y que el listener `CreateUserDefaultCategories` del backend.
  RF: RF-006, RN-004
  Depende de: T017, T018, T019
  Paralelizable: si
  Criterio de terminado: test T039 verifica que tras `seedDefaults`, la BD tiene 1 cuenta cash + 10 categorías; segundo llamado no agrega filas.

- [ ] T023 Frontend: crear `mobile/lib/data/bootstrap.dart` con `Future<bool> hasBolsa(FincoreDatabase db)` (devuelve true si existe cuenta `type = 'cash'`). Esto lo usa el router para decidir si redirige a `/first-run`.
  RF: RF-006
  Depende de: T017
  Paralelizable: si
  Criterio de terminado: test simple en `bootstrap_test.dart` verifica con BD vacía y con BD seeded.

- [ ] T024 Frontend: crear `mobile/lib/data/backup.dart`:
  - `class BackupService { Future<String> exportToJson(); Future<ImportReport> importFromJson(String jsonRaw); }`.
  - Formato JSON v1 idéntico al producido por `/api/finance/backup/export` del backend: top-level `{ "version": 1, "exported_at": "ISO8601", "accounts": [...], "categories": [...], "journal_entries": [...] }`. Sin user_id, sin plan, sin soft-deleted.
  - Export: lee solo activos (deletedAt IS NULL), serializa con formato ISO 8601 con subsegundos para todos los timestamps. Devuelve el JSON como string.
  - Import: parsea ANTES de tocar BD. Valida que `version == 1` (rechazo con error claro si > 1). Valida que existe al menos una cuenta cash (la Bolsa). Dentro de una transacción de drift: borra TODO físicamente (categories, journal_entries, accounts) y luego inserta lo importado preservando los UUIDs originales. Si falla, la transacción aborta y la BD queda intacta. Devuelve `ImportReport { accountsCount, categoriesCount, entriesCount, importedAt }`.
  - Casos de error tipados: `BackupInvalidJsonError`, `BackupUnsupportedVersionError`, `BackupMissingBolsaError`, `BackupTransactionError`.
  RF: RF-005, RN-013
  Depende de: T017
  Paralelizable: si
  Criterio de terminado: tests T041 verifican round-trip + import corrupto + versión desconocida + falta Bolsa.

- [ ] T025 Frontend: crear `mobile/lib/app_dependencies.dart` con InheritedWidget que expone `database` + `accountsDao` + `categoriesDao` + `entriesDao` + `stateService` + `backupService`. Helper `AppDependencies.of(context)`. SIN apiClient, sin tokenStorage, sin authState, sin authApi, sin *Api. Patrón similar al actual del cliente online (que se preservó).
  RF: RF-017
  Depende de: T021, T024
  Paralelizable: no
  Criterio de terminado: archivo existe; las pantallas que se porten en Fase 6 lo consumen.

## Fase 6 — Router y pantallas

- [ ] T026 Frontend: crear `mobile/lib/router/app_router.dart` con `GoRouter`. Rutas: `/first-run`, `/dashboard`, `/accounts`, `/accounts/new`, `/accounts/:id/edit`, `/categories`, `/categories/new`, `/categories/:id/edit`, `/entries`, `/entries/new`, `/entries/:id/edit`, `/settings`. Redirect global: si `hasBolsa()` devuelve false y la ruta no es `/first-run`, ir a `/first-run`. Si tiene Bolsa y la ruta es `/first-run`, ir a `/dashboard`. Sin redirects de auth.
  RF: RF-016
  Depende de: T025, T023
  Paralelizable: no
  Criterio de terminado: la app boot a `/dashboard` cuando hay Bolsa; a `/first-run` cuando no.

- [ ] T027 Frontend: escribir `mobile/lib/main.dart` con `void main() async` que: `WidgetsFlutterBinding.ensureInitialized()`, abre `openDatabase()`, construye `BackupService`, `*Dao`, `FinancialStateService`, `AppDependencies`, `buildAppRouter`, y `runApp(FincoreApp(deps, router))`. La `FincoreApp` envuelve un `AppDependenciesProvider` y `MaterialApp.router` con `fincoreDarkTheme()`. SIN FINCORE_API_URL ni asserts de env.
  RF: RF-007, RF-017
  Depende de: T026
  Paralelizable: no
  Criterio de terminado: `flutter run -d linux` arranca la app y muestra alguna pantalla (probablemente `/first-run` si BD vacía o `/dashboard` si tiene Bolsa).

- [ ] T028 Frontend: crear `mobile/lib/screens/first_run_screen.dart`. Card central con título "Bienvenido a FinCore". Dos botones grandes: "Importar respaldo" (abre `file_picker.pickFiles(type: FileType.custom, allowedExtensions: ['json'])`, lee bytes, llama `backupService.importFromJson`, navega a `/dashboard`; muestra error si rechaza) y "Arrancar limpio" (confirm dialog destructivo → llama `seedDefaults` → navega a `/dashboard`). Maneja casos de error con `showErrorSnackbar`.
  RF: RF-006
  Depende de: T024, T022, T026
  Paralelizable: si
  Criterio de terminado: test widget T043 verifica los dos caminos.

- [ ] T029 Frontend: portar `mobile/lib/screens/dashboard_screen.dart` desde el legacy. Reemplazos clave:
  - `deps.stateApi.fetch()` (Future) → 3 streams cacheados en `_State`: `_boStream`, `_deStream`, `_crStream` de `stateService`, más `_accountsStream` de `accountsDao.watchActive()`, más `_recentEntriesStream` de `entriesDao.watchPage(limit: 10)`.
  - 5 `StreamBuilder` en lugar de un `FutureBuilder` único.
  - Cachear los streams en `_State`, no recrear en `build()` (patrón dogear).
  - Pull-to-refresh ya no aplica (streams son automáticos). Reemplazar por un botón discreto "Recargar" o eliminar.
  - AppBar con botón → `/settings`, FAB → `/entries/new`. Conservar navegación a `/accounts`, `/categories`, `/entries`.
  RF: RF-007
  Depende de: T028
  Paralelizable: no
  Criterio de terminado: el dashboard muestra BO/DE/CR con valores reales tras seed o import. Test widget T044.

- [ ] T030 Frontend: portar `mobile/lib/screens/accounts_list_screen.dart` desde legacy con stream del `accountsDao.watchActive()` en lugar de `FutureBuilder` con `accountsApi.list()`. Conservar UI de barra de uso de credit, badge de protegida, etc.
  RF: RF-008
  Depende de: T029
  Paralelizable: si
  Criterio de terminado: lista renderiza con cuentas reales del seed.

- [ ] T031 Frontend: portar `mobile/lib/screens/account_form_screen.dart` desde legacy. Crear / editar / eliminar mediante `accountsDao`. Vista protegida para Bolsa. Validaciones del form se mantienen; las del DAO complementan. Mensaje específico cuando intenta archivar cuenta no vacía (RN-007).
  RF: RF-008
  Depende de: T030
  Paralelizable: no
  Criterio de terminado: crear/editar/archivar contra BD local funciona en Linux desktop.

- [ ] T032 Frontend: crear `mobile/lib/widgets/account_picker.dart` y `mobile/lib/widgets/category_picker.dart` nuevos. Reciben listas (no streams) para mantener simplicidad de los formularios y permitir filtros sincrónicos. Los formularios obtienen `accounts` y `categories` desde el `_State` que sí escucha streams (cacheados).
  RF: RF-008, RF-009, RF-010
  Depende de: T015
  Paralelizable: si
  Criterio de terminado: los pickers se importan limpios en forms.

- [ ] T033 Frontend: portar `mobile/lib/screens/categories_list_screen.dart` y `mobile/lib/screens/category_form_screen.dart` desde legacy. Reemplazar `categoriesApi.*` por `categoriesDao.*`. Conservar preview live del badge.
  RF: RF-009
  Depende de: T029, T032
  Paralelizable: si
  Criterio de terminado: CRUD contra BD local funciona.

- [ ] T034 Frontend: portar `mobile/lib/screens/entries_list_screen.dart` desde legacy. Reemplazar paginación HTTP por paginación del DAO. Conservar filtros en bottom-sheet.
  RF: RF-008, RF-010
  Depende de: T029, T032
  Paralelizable: no
  Criterio de terminado: lista renderiza con stream del DAO; scroll infinito carga más páginas.

- [ ] T035 Frontend: portar `mobile/lib/screens/entry_form_screen.dart` desde legacy. Reemplazar `entriesApi.register*` por `entriesDao.register*`. Reemplazar `entriesApi.update` y `cancel` por DAO. Conservar pickers contextuales por kind. El kind inmutable en edición se mantiene. OverpayDebt se maneja mostrando mensaje del DAO error.
  RF: RF-010, RN-006, RN-011
  Depende de: T034, T020
  Paralelizable: no
  Criterio de terminado: crear/editar/cancelar para los 5 kinds funciona contra BD local.

- [ ] T036 Frontend: crear `mobile/lib/screens/settings_screen.dart` con: sección "Respaldo" con dos botones grandes ("Exportar respaldo" → llama `backupService.exportToJson()` y abre share sheet con `share_plus`; "Importar respaldo" → file_picker + confirm destructivo + llama `importFromJson`), sección "Acerca de" con versión `0.2.0+2`, nota informativa sobre rama legacy ("El backend Laravel y la Vue web están en la rama legacy/web-and-online-flutter del repo"). SIN logout ni nada de auth.
  RF: RF-012
  Depende de: T024, T027
  Paralelizable: si
  Criterio de terminado: export produce un JSON valido descargable; import del mismo JSON deja la BD igual.

## Fase 7 — Tests

- [ ] T037 Pruebas: crear `mobile/test/helpers/sqlite_override.dart` que llama `open.overrideFor(OperatingSystem.linux, () => DynamicLibrary.open('libsqlite3.so.0'))`. Documentar comentario explicativo. Importar en `setUpAll` de todos los tests de datos.
  RF: RF-018
  Depende de: T009
  Paralelizable: si
  Criterio de terminado: el helper se importa en los tests de Fase 7 sin error.

- [ ] T038 Pruebas: crear `mobile/test/helpers/test_app.dart` que: monta `AppDependenciesProvider` + `MaterialApp.router` con tema FinCore. Recibe `FincoreDatabase database` (typically en memoria). Setup helper para crear BD en memoria con `NativeDatabase.memory()`. En `tearDown` cierra `database.close()` y bombea `pump(Duration(milliseconds: 600))` para drenar el Timer interno de drift (gotcha dogear). Crear también `mobile/test/helpers/factories.dart` con `buildAccount({...})`, `buildCategory({...})`, `buildEntry({...})` fixtures.
  RF: RF-018
  Depende de: T037, T025
  Paralelizable: si
  Criterio de terminado: un test trivial corre sin warning de "Timer is still pending".

- [ ] T039 Pruebas: `mobile/test/data/daos_test.dart` (o 3 archivos separados) cubriendo:
  - accounts: crear debit + credit, unique name entre activos (permitido con archivada del mismo nombre), rechazar create con type=cash, rechazar update/delete con is_protected, archivar con saldo cero OK, archivar con saldo no cero rechaza.
  - categories: crear, applies_to válido, unique name, color/icon del catálogo, archivar.
  - entries: registrar los 5 kinds, validación de tipos por kind, OverpayDebt para debt_payment que excede deuda, edición sin cambiar kind, cancel soft delete.
  - seed: idempotente (Bolsa + 10 categorías; segundo llamado no agrega).
  RF: RF-018, RN-004, RN-007, RN-011
  Depende de: T018, T019, T020, T022, T038
  Paralelizable: si
  Criterio de terminado: ≥ 25 tests verdes en este archivo.

- [ ] T040 Pruebas: `mobile/test/data/financial_state_test.dart` cubriendo BO/DE/CR y saldos por cuenta para escenarios:
  - BD vacía → todos los saldos en 0.
  - Solo income → cuenta destino con saldo positivo, BO sube.
  - Solo expense → cuenta origen con saldo negativo (libreta libre), BO baja.
  - credit_expense → cuenta credit con saldo (deuda) positivo, DE sube, CR baja.
  - debt_payment → cuenta credit con deuda menor, cuenta origin con saldo menor.
  - transfer → BO sin cambio (suma cero), saldos por cuenta cambian.
  - Entry cancelado no cuenta.
  - Cuenta archivada no aparece en BO/DE/CR.
  - Stream reactivo: insertar entry mientras escucha → emite nuevo valor.
  - Performance: dataset de 10,000 entries; query BO + DE + CR + saldos de 10 cuentas tarda < 50 ms.
  RF: RF-011, RN-009, RN-010
  Depende de: T021, T038
  Paralelizable: si
  Criterio de terminado: ≥ 12 tests verdes.

- [ ] T041 Pruebas: `mobile/test/data/backup_test.dart` cubriendo:
  - Round-trip básico: BD con 2 cuentas + 5 categorías + 10 entries → export → wipe → import → mismos UUIDs + mismos amounts + mismas fechas exactas (subsegundos).
  - Round-trip con archivados: solo se exportan activos; tras import, archivados no están.
  - Import de JSON corrupto (string roto, JSON malformado): rechaza con `BackupInvalidJsonError`; BD existente intacta.
  - Import de version: 2: rechaza con `BackupUnsupportedVersionError`; BD intacta.
  - Import sin Bolsa: rechaza con `BackupMissingBolsaError`.
  - Import con UUIDs duplicados entre filas: transaccion aborta; BD intacta.
  - Import de JSON sample del backend real (fixture `test/fixtures/backend_export_sample.json` — copiar un JSON de prueba del backend): completa sin error y la BD queda con los datos esperados.
  RF: RF-005, RN-013
  Depende de: T024, T038
  Paralelizable: si
  Criterio de terminado: ≥ 7 tests verdes.

- [ ] T042 Pruebas: `mobile/test/data/financial_invariants_test.dart` cubriendo invariantes de los DAOs:
  - OverpayDebt: pagar más que la deuda actual de una tarjeta → DAO lanza `OverpayDebtError`.
  - Libreta libre: gasto que deje saldo negativo en cash → DAO acepta (no lanza).
  - Crear movimiento con cuenta archivada como origen → DAO rechaza.
  - Editar movimiento cambiando a cuenta archivada → DAO rechaza.
  - transfer con origin == destination → DAO rechaza.
  - debt_payment con destino que no es credit → DAO rechaza.
  RF: RN-003, RN-011
  Depende de: T020, T038
  Paralelizable: si
  Criterio de terminado: ≥ 6 tests verdes.

- [ ] T043 Pruebas: `mobile/test/screens/first_run_screen_test.dart` cubriendo:
  - Render: muestra dos botones grandes.
  - Tap "Arrancar limpio" → confirm dialog → tras confirmar, BD tiene Bolsa + 10 categorías y navega a /dashboard.
  - Tap "Importar respaldo" con file picker mockeado devolviendo JSON válido → BD tiene contenido del JSON y navega a /dashboard.
  - Import con JSON corrupto → snackbar con mensaje de error; BD sigue vacía.
  RF: RF-006
  Depende de: T028, T038
  Paralelizable: si
  Criterio de terminado: ≥ 4 tests verdes.

- [ ] T044 Pruebas: `mobile/test/screens/dashboard_screen_test.dart` cubriendo:
  - Render con dataset: BO/DE/CR + cuentas + entries.
  - Streams reactivos: insertar entry en BD → dashboard refleja el cambio sin pull-to-refresh.
  - Tap en cuenta → navega a `/accounts/:id/edit`.
  - Tap en entry → navega a `/entries/:id/edit`.
  RF: RF-007
  Depende de: T029, T038
  Paralelizable: si
  Criterio de terminado: ≥ 4 tests verdes.

- [ ] T045 Pruebas: `mobile/test/screens/entry_form_screen_test.dart` cubriendo:
  - Crear cada uno de los 5 kinds: form contextual muestra los campos correctos, submit guarda en BD.
  - Editar entry existente: kind no editable; cambios persisten.
  - Cancelar entry: soft delete; entry desaparece de listas.
  - OverpayDebt al pagar tarjeta: snackbar con mensaje específico.
  RF: RF-010, RN-006, RN-011
  Depende de: T035, T038
  Paralelizable: si
  Criterio de terminado: ≥ 8 tests verdes.

- [ ] T046 Validación de calidad: ejecutar `flutter test` y verificar que toda la suite pasa. Mínimo ≥ 50 tests verdes (el plan suma >55).
  RF: RF-018
  Depende de: T039, T040, T041, T042, T043, T044, T045
  Paralelizable: no
  Criterio de terminado: `flutter test` reporta "All tests passed!" con ≥ 50 tests.

- [ ] T047 Validación de calidad: `flutter analyze` sin issues (incluyendo archivos generados — éstos están excluidos por `analysis_options.yaml`).
  RF: RF-018
  Depende de: cualquier fase previa de UI
  Paralelizable: si
  Criterio de terminado: "No issues found!".

## Fase 8 — Build release + smoke

- [ ] T048 Frontend: validar manifest del APK final post-build. `aapt dump permissions ...apk` muestra `INTERNET` + `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` (autogenerado por sistema) y nada más.
  RF: RN-015
  Depende de: T046, T047
  Paralelizable: no
  Criterio de terminado: la salida de aapt confirma lo arriba.

- [ ] T049 Frontend: ejecutar `mobile/scripts/build-apk.sh` → produce `mobile/build/app/outputs/flutter-apk/app-release.apk`. Verificar tamaño < 50 MB.
  RF: RF-019
  Depende de: T048
  Paralelizable: no
  Criterio de terminado: APK existe, < 50 MB, y `aapt dump badging ...apk` muestra `package: name='io.github.gregori100.fincore' versionCode='2' versionName='0.2.0'`.

- [ ] T050 Frontend / Validación de calidad (smoke manual del usuario): Diego instala el APK en el Redmi Note 13 con `adb install -r mobile/build/app/outputs/flutter-apk/app-release.apk`. Verifica que el ícono FinCore aparece en el home. Abre la app. La primera vez muestra pantalla "Primer arranque". Tap "Arrancar limpio" → confirma destructivo → Dashboard con BO/DE/CR = $0, Bolsa visible, 10 categorías default disponibles. Crea un ingreso a la Bolsa de prueba, confirma que el saldo refleja el cambio. Crea uno de cada uno de los 5 kinds (income, expense, credit_expense, debt_payment, transfer). Edita y cancela alguno.
  RF: criterios de aceptación de spec
  Depende de: T049
  Paralelizable: no
  Criterio de terminado: Diego confirma que el flujo end-to-end del lanzamiento (Arrancar limpio + CRUD de los 5 kinds + edit + cancel) funciona sin errores.

- [ ] T051 Validación de calidad (smoke manual modo avión + export/import): Diego activa modo avión en el celular y verifica que la app sigue funcionando: navegar a `/entries/new`, crear un gasto, editarlo, cancelarlo, ver dashboard. Todo offline. Adicional: Settings → Exportar respaldo (share sheet → guardar el JSON v1 a sí mismo por Drive/email/etc.). Después Settings → Importar respaldo → seleccionar el mismo JSON → confirmar destructivo → BD queda idéntica a antes del import. Verificable también con `adb shell dumpsys netstats | grep io.github.gregori100.fincore` que muestre 0 bytes RX/TX recientes durante el flujo.
  RF: criterio medible "0 requests salientes"
  Depende de: T050
  Paralelizable: no
  Criterio de terminado: Diego confirma que la app funciona completamente con red apagada.

## Fase 9 — Documentación + QR

- [ ] T052 Documentación: escribir `mobile/README.md` con: qué es la app, prerequisitos (Flutter 3.29.3, opcionalmente Android SDK 35 para builds, opcionalmente libs de Linux desktop para dev), cómo correr en Linux desktop, cómo construir APK, cómo importar el backup del backend legacy la primera vez (instrucciones de cómo regenerar el JSON si se pierde haciendo `git checkout legacy/web-and-online-flutter` y levantando el stack), workflow de codegen (`./scripts/codegen.sh` tras tocar database.dart), trampas conocidas de drift testing (override de libsqlite3, drain Timer en testApp).
  RF: RF-020
  Depende de: T051
  Paralelizable: si
  Criterio de terminado: README cubre los puntos.

- [ ] T053 Documentación: reescribir `CLAUDE.md` raíz de cero para la nueva era (Flutter local-first single-user). Secciones: "Qué es FinCore", "Arquitectura" (drift + SQLite, sin backend, sin auth), "Comandos" (con paths de mobile/scripts), "Decisiones técnicas" (soft delete, saldos derivados con streams, JSON v1, schema versioning), "Roadmap futuro" (backup Drive, reportes recuperables, sync API muy futuro), "Referencia al legacy" (cómo acceder al backend + Vue + cliente online en la rama). Sin menciones de Laravel/Vue/Tailscale/Docker en presente.
  RF: RF-020
  Depende de: T052
  Paralelizable: si
  Criterio de terminado: `CLAUDE.md` raíz refleja la nueva era; `grep -i 'laravel\|tailscale\|docker compose' CLAUDE.md` no devuelve líneas que hablen de configuración activa (solo referencias históricas a la rama legacy).

- [ ] T054 Documentación: reescribir `README.md` raíz simplificado: una página corta con qué es FinCore (app Android local-first), cómo instalar el APK, link a `mobile/README.md` para desarrollo, link a la rama legacy para el código del backend antiguo. Actualizar `.gitignore` raíz quitando entradas obsoletas (Docker, Tailscale, etc.) y conservando solo lo de Flutter + IDE.
  RF: RF-020
  Depende de: T053
  Paralelizable: si
  Criterio de terminado: README raíz claro, < 50 líneas, sin referencias activas al stack docker/laravel.

- [ ] T055 Validación de calidad: ejecutar `branch-quality-review` sobre la rama del sprint. Revisar reporte generado en `engineering/quality-review/flutter-local-mvp/`. Resolver cualquier hallazgo bloqueante antes de merge.
  RF: estrategia de pruebas
  Depende de: T046, T047, T051, T053, T054
  Paralelizable: no
  Criterio de terminado: reporte de quality-review existe, 0 hallazgos bloqueantes documentados como resueltos o aceptados con razón.

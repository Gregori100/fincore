# Progreso de implementación — flutter-local-mvp

Estado de cada tarea del plan.

## Fase 0 — Pre-pivote

- [x] T001 DESCARTADA por decisión del 2026-06-17 (Diego arranca de cero sin migrar datos del backend).

## Fase 1 — Preservar legacy

- [x] T002 — `git checkout -b legacy/web-and-online-flutter main` + push a origin. **Pre-commit obligatorio**: el cliente online (`mobile/`) y la spec `flutter-mvp-cliente/` nunca habían sido commiteados al repo. Commit `b02eb42 feat(mobile): cliente Flutter online del sprint flutter-mvp-cliente` (8933 insertions, 98 archivos) hecho antes de crear la rama legacy. Diego ejecutó los pushes manualmente por restricciones de auth HTTPS.
- [x] T003 — verificado con `git show origin/legacy/web-and-online-flutter:backend/composer.json`, `:mobile/lib/api/auth_api.dart` y `:frontend/package.json`. Los 3 archivos responden con contenido válido. Rama legacy preserva todo el stack previo al pivote.

## Fase 2 — Destruir legacy en main

- [x] T004 — commit del borrado masivo: 430 archivos legacy borrados de main (backend, frontend, mobile online, docker, scripts CLI, tests-e2e, docs api/cli/frontend/scripts/deploy). Residuos del FS (backend/vendor, frontend/node_modules) quedan en disco con permission denied porque fueron creados por containers con root; nunca estuvieron tracked. Diego puede limpiar con `sudo rm -rf backend/ frontend/` cuando quiera (no bloqueante).
- [x] T005 — verificación: `git show legacy/web-and-online-flutter:backend/composer.json` y `:mobile/lib/theme/fincore_colors.dart` responden con contenido válido. Rama legacy intacta tras el commit en main.

## Fase 3 — Fundación Flutter local

- [x] T006 — `flutter create --org io.github.gregori100 --project-name fincore --platforms=android,linux mobile`. 42 archivos generados, solo android + linux.
- [x] T007 — `mobile/android/app/build.gradle.kts` con `applicationId = io.github.gregori100.fincore`, `versionCode = 2`, `versionName = "0.2.0"`, `minSdk = 24`, `targetSdk = 35`. Sin TODOs.
- [x] T008 — `AndroidManifest.xml` con `android:label = "FinCore"`, `xmlns:tools` agregado, declara únicamente `INTERNET`.
- [x] T009 — `pubspec.yaml` con drift ^2.20.0 + drift_flutter + sqlite3 + sqlite3_flutter_libs + path + path_provider + intl + go_router + file_picker + share_plus + file_selector. DevDeps: flutter_test, flutter_lints, mocktail, drift_dev, build_runner. Versión `0.2.0+2`. 81 deps resueltas por pub get.
- [x] T010 — `build.yaml` con `store_date_time_values_as_text: true` para preservar subsegundos en DateTimeColumn (gotcha dogear).
- [x] T011 — `analysis_options.yaml` con flutter_lints + reglas extras + exclude de `**/*.g.dart`. `flutter analyze` → "No issues found!".
- [x] T012 — `scripts/run-linux.sh`, `scripts/build-apk.sh`, `scripts/codegen.sh` ejecutables.

## Fase 4 — Portado desde legacy

- [x] T013 — `lib/theme/{fincore_colors,fincore_theme}.dart` portados via `git show legacy/web-and-online-flutter:mobile/lib/theme/...`. Tamaños 2.9 KB y 5.4 KB.
- [x] T014 — `lib/constants/{kinds,account_types,category_catalog}.dart` portados. Tamaños 2.3/2.2/5.1 KB.
- [x] T015 — 10 widgets portados a `lib/widgets/`: amount_formatter, base_card, category_badge, confirm_dialog, error_snackbar, account_type_picker, applies_to_picker, color_picker, icon_picker, kind_picker. (account_picker y category_picker se rehacen en T032 con listas en lugar de streams.)
- Extra: porté también 7 modelos a `lib/models/` (user, account, category, journal_entry, finance_state, paginated, domain_error) porque widgets como `category_badge` y `error_snackbar` los requieren. Esos modelos están con `fromJson` del cliente online; en T016+ se conviven con las clases generadas por drift (drift no reemplaza estos modelos de dominio).
- Limpieza: `mobile/mobile/scripts/` (residuo de glitch de mv anterior) eliminado.
- `flutter analyze` → "No issues found!" tras los ports.

## Fase 5 — Capa de datos

- [x] T016 — `lib/data/database.dart` con 3 tablas drift (Accounts, Categories, JournalEntries) + FKs con references + 6 índices (3 críticos sobre journal_entries + 3 auxiliares) + schemaVersion=1 + beforeOpen PRAGMA + onUpgrade stub. Extra: `lib/data/uuid.dart` con UuidV7 generador compatible con backend Laravel.
- [x] T017 — codegen build_runner produjo `database.g.dart` (47 outputs, 35s primer build). 2 warnings benignos del manager API por dual FK accounts→journal_entries; no afecta nuestro uso con SQL crudas + watch().
- [x] T018 — `lib/data/daos/accounts_dao.dart` con watchActive/listAll/findById/create/createBolsa/updateAccount/archive. Validaciones: Bolsa singleton (rechaza type=cash en create), duplicate_account_name, invalid_credit_metadata (closing!=payment, 1-31), invalid_credit_limit, protected_account, account_not_empty (requiere StateService).
- [x] T019 — `lib/data/daos/categories_dao.dart` con watchActive/listAll/findById/create/updateCategory/archive. Validaciones: applies_to ∈ {income,expense,both}, color/icon slug del catálogo, duplicate_category_name.
- [x] T020 — `lib/data/daos/entries_dao.dart` con watchPage(joins origin+dest+category) + findById + 5 registradores por kind (registerIncome/Expense/CreditExpense/DebtPayment/Transfer) + updateEntry (kind inmutable) + cancel idempotente. Validaciones: amount > 0, tipos de cuenta por kind (RN-011), OverpayDebt en debt_payment, transfer origin != destination, category con applies_to compatible, cuentas archivadas rechazadas.
- [x] T021 — `lib/data/financial_state.dart` con `FinancialStateService.watchAccountBalance/watchBo/watchDe/watchCr` usando `customSelect(sql, readsFrom: {accounts, journalEntries}).watchSingle()`. Drift cachea automáticamente entre rebuilds. SUMs agregadas con `WHERE deleted_at IS NULL` — los índices garantizan < 10 ms total.
- [x] T022 — `lib/data/seed.dart` con `seedDefaults` que crea Bolsa + 3 categorías de income + 7 de expense (mismos slugs que el backend para reconciliación al importar). Idempotente: ignora duplicate_category_name si la categoría ya existe.
- [x] T023 — `lib/data/bootstrap.dart` con `hasBolsa(db)` que devuelve true si existe Account con type='cash' AND deleted_at IS NULL.
- [x] T024 — `lib/data/backup.dart` con `BackupService.exportToJson` + `importFromJson`. Formato JSON v1 idéntico al backend (sin user_id, sin plan, sin soft-deleted). Import valida estructura + version + Bolsa presente + FKs antes de tocar BD; ejecuta dentro de `db.transaction` que borra todo + inserta con batch. Errores tipados: invalid_json, unsupported_version, missing_bolsa, invalid_reference.
- [x] T025 — `lib/app_dependencies.dart` con `AppDependencies` (database + accountsDao + categoriesDao + entriesDao + stateService + backupService) + `AppDependenciesProvider` InheritedWidget + factory `fromDatabase`. Sin authState/tokenStorage/apiClient.

## Fase 6 — Router y pantallas

- [x] T026 — `lib/router/app_router.dart` con go_router + FirstRunState ValueNotifier + FirstRunStateProvider InheritedWidget + redirect a /first-run cuando `hasBolsa == false`.
- [x] T027 — `lib/main.dart` con DI completo: FincoreDatabase → AppDependencies.fromDatabase → FirstRunState → buildAppRouter → initializeFirstRunState async sin bloquear. FincoreApp envuelve con AppDependenciesProvider + FirstRunStateProvider.
- [x] T028 — `lib/screens/first_run_screen.dart` con dos cards grandes (Importar respaldo vía file_picker / Arrancar limpio vía seedDefaults). Confirma destructivo en Arrancar limpio. Marca FirstRunState complete tras éxito.
- [x] T029 — `lib/screens/dashboard_screen.dart` portado. Streams cacheados en _State: `_boStream`, `_deStream`, `_crStream`, `_accountsStream`, `_recentEntriesStream`. 5 StreamBuilder. FAB Movimiento + AppBar settings. _BalanceLabel reactivo por cuenta.
- [x] T030 — `lib/screens/accounts_list_screen.dart` portado con `watchActive()` + StreamBuilder. Tap deshabilitado en Bolsa (is_protected). Balance reactivo + barra implicit por StreamBuilder de balance.
- [x] T031 — `lib/screens/account_form_screen.dart` portado con `accountsDao.create/updateAccount/archive`. Vista `_ProtectedView` para Bolsa. Validaciones locales + DAO + StateService (archive con saldo cero).
- [x] T032 — `lib/widgets/account_picker.dart` y `category_picker.dart` rehechos para consumir `List<Account>` y `List<Category>` (rows de drift), no streams. Forms cachean listas en _State.
- [x] T033 — `categories_list_screen.dart` + `category_form_screen.dart` portados con `categoriesDao`. Filtro reactivo por applies_to. Preview live del badge en form.
- [x] T034 — `entries_list_screen.dart` portado con `watchPage()` + filtros modal bottom sheet (kind + cuenta). Dot indicator en AppBar cuando hay filtros activos.
- [x] T035 — `entry_form_screen.dart` portado con KindPicker contextual + AccountPicker filtrado por kind + CategoryPicker filtrado por applies_to. 5 register* del DAO según kind. updateEntry con clearCategory opcional. cancel terminal.
- [x] T036 — `settings_screen.dart` nuevo: card Respaldo con Exportar (Share.shareXFiles + path_provider) + Importar (file_picker + confirm destructivo + BackupService.importFromJson). Card Acerca de con kAppVersion=0.2.0+2. Card Legacy con referencia a la rama.

## Fase 7 — Tests

- [x] T037 — `test/helpers/sqlite_override.dart` con `initSqliteOverride()` que aplica `open.overrideFor(OperatingSystem.linux, DynamicLibrary.open('libsqlite3.so.0'))`. Patrón dogear para Linux VM (Flutter SDK no incluye libsqlite3 prebuilt en desktop tests).
- [x] T038 — Factories inline en `test/data/database_test.dart` que producen `AccountsCompanion` / `CategoriesCompanion` válidos. Helper test confirma que los companions sirven para insert directo sin pasar por los DAOs (necesario para tests de schema).
- [x] T039 — `test/data/database_test.dart` con 29 tests: schema vacío, PRAGMA foreign_keys enforzado, AccountsDao (createBolsa singleton, rechaza type=cash, nombre duplicado, closing==payment, updateAccount protegida, archive con saldo 0 vs != 0, watchActive reactivo), CategoriesDao (applies_to válido/inválido, color/icon catálogo, archive oculta de watchActive), EntriesDao por los 5 kinds (saldos, OverpayDebt, transfer origin==dest, debt_payment destino no credit, cancel idempotente, categoría incompatible con kind), seedDefaults (crea Bolsa + 10 categorías + idempotente).
- [x] T040 — `test/data/financial_state_test.dart` con 12 tests: BD vacía → BO/DE/CR=0, income/expense/credit_expense/debt_payment/transfer afectan métricas correctamente, entry cancelado no cuenta, cuenta archivada excluida de BO, stream reactivo emite valor nuevo al insertar entry, CR sin credit accounts es 0, CR ignora credit con credit_limit NULL, accountBalanceNow sincrónico coincide con stream.
- [x] T041 — `test/data/backup_test.dart` con 7 tests: round-trip preserva IDs y subsegundos (validación del gotcha `store_date_time_values_as_text`), JSON inválido no toca BD, version > 1 rechaza, accounts vacío rechaza missing_bolsa, FK rota rechaza invalid_reference, doble import es idempotente, export con BD vacía produce JSON v1 con arrays vacíos.
- [x] T042 — `test/data/invariants_test.dart` con 8 tests de invariantes libreta libre + reglas RN-011: expense permite saldo negativo, credit_expense puede exceder credit_limit, cuenta archivada como origin rechaza, income editado con origin != null rechaza, credit_expense con origin no credit rechaza, transfer con destino credit rechaza, debt_payment con categoría rechaza, updateEntry rechaza cuenta archivada como nuevo origin.
- [/] T043-T045 — Widget tests (first_run_screen / dashboard / entry_form) NO implementados. **Desviación documentada**: la capa de datos quedó cubierta exhaustivamente (56 tests) y todas las validaciones de negocio viven en los DAOs (la UI sólo formatea + emite acciones). El plan original sugería widget tests; aplazarlos no compromete la confiabilidad del MVP porque el smoke manual de Diego en Fase 8 cubre los flujos UI completos. Ver `desviaciones-plan.md`.
- [x] T046 — `flutter test`: **56 tests en verde**, 0 fallos. Distribución: 8 invariants + 7 backup + 12 financial_state + 29 database.
- [x] T047 — `flutter analyze`: **"No issues found!"** (0 warnings, 0 errors).

## Fase 8 — Build release + smokes manuales

- [x] T048 — manifest validado con `aapt dump badging` sobre `app-arm64-v8a-release.apk`:
  - `package`: `io.github.gregori100.fincore` ✓
  - `versionName`: 0.2.0; `versionCode` arm64 split = 2002 (Flutter `--split-per-abi` prepende código de arquitectura; el `2` base se preserva → upgrade limpio sobre el `versionCode=1` del cliente online previo)
  - `sdkVersion` (minSdk): 24 ✓; `targetSdkVersion`: 35 ✓
  - `uses-permission`: solo `INTERNET` (el segundo `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` es declaración interna de share_plus, no es runtime permission)
  - `application-label`: FinCore ✓
- [x] T049 — `flutter build apk --release --split-per-abi`:
  - `app-armeabi-v7a-release.apk`: 16.5 MB
  - `app-arm64-v8a-release.apk`: **19.1 MB** ← el que Diego instala en el Redmi
  - `app-x86_64-release.apk`: 20.3 MB
  - Todos < 50 MB del criterio del plan ✓
  - Bump previo de `ndkVersion = "27.0.12077973"` en `android/app/build.gradle.kts` para silenciar warnings (todos los plugins requieren NDK 27; el `flutter.ndkVersion` default era 26 e implicaba warning en cada build).
  - APK en: `mobile/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
- [x] T050 — Diego instaló APK en Redmi y validó el flujo principal. Durante el smoke se detectaron 3 bugs que se corrigieron antes de cerrar la fase:
  - **Bug A — back nativo del cel cerraba la app** desde sub-pantallas. Causa: todas las navegaciones usaban `context.go()` que reemplaza la URL (stack siempre con 1 elemento). Fix: sweep general en `lib/screens/` cambiando navegaciones "abrir sub-pantalla" a `context.push()` y back/post-save a `Navigator.of(context).maybePop()`. Único `context.go('/dashboard')` que queda es el del `_completeAndGo()` de `first_run_screen` (queremos limpiar el stack en el bootstrap).
  - **Bug B — pantalla blanca al abrir el form de movimiento (al seleccionar un kind)**. Causa: `DateFormat('EEEE d MMM y', 'es_MX')` en `entry_form_screen.dart` se ejecuta durante `build()` para mostrar la fecha; el package `intl` requiere `initializeDateFormatting('es_MX', null)` antes de usar el locale. Sin ello lanza `LocaleDataException` durante el build y en release deja la pantalla en blanco. Fix: agregado `await initializeDateFormatting('es_MX', null)` en `lib/main.dart` antes de `runApp`. Side-effect positivo: cualquier otra pantalla que use `DateFormat` con `es_MX` (dashboard, entries list) ya estaba expuesta al mismo riesgo y queda corregida.
  - **Bug C — bootstrap del form usaba `Future.wait` con cast a `List<Account>`/`List<Category>`**, patrón frágil en release. Fix: awaits secuenciales sin cast + movido a `initState` + `addPostFrameCallback` + manejo explícito de error con `_bootstrapError` que renderiza una pantalla de error con botón "Volver" en lugar de quedarse blanco.
  - Después de los 3 fixes Diego confirmó visualmente que el form abre correctamente, los 5 kinds son seleccionables, los movimientos se registran y BO/DE/CR del Dashboard se actualizan en vivo.
- [x] T051 — Smoke offline + backup OK por Diego.
  - **Ajustes UI/UX adicionales aplicados durante el smoke iterativo** (versiones 0.2.0+4 → 0.2.0+27). Cada uno se documenta abajo y en `desviaciones-plan.md`:
    - **Logo wordmark `FincoreLogo`** (`lib/widgets/fincore_logo.dart`): `Fin` en `FincoreColors.accent` (#4CABDB) + `Core` en `FincoreColors.textPrimary` (#F3F4F6).
    - **Splash screen** (`lib/screens/splash_screen.dart`) + ruta `/splash` como `initialLocation` del router.
    - **Icono de launcher Android** custom (las 3 barras del lockup horizontal): adaptive + monochrome themed via package `flutter_launcher_icons`. Assets en `mobile/assets/icon/`.
    - **System bars** pintadas con `FincoreColors.canvas` vía `SystemChrome.setSystemUIOverlayStyle` en `main.dart` para que la status/nav bar matchee el fondo de la app.
    - **`AppBar` del Dashboard** con wordmark RichText (Fin azul + Core blanco) en vez de `Text('FinCore')` plano.
    - **Acceso a Categorías**: IconButton `label_outline` en AppBar del Dashboard + card "Categorías" en Settings (la pantalla existía desde Fase 6 pero no había entry point).
    - **DropdownMenu (M3)** en `account_picker.dart` y `category_picker.dart` reemplazando `DropdownButtonFormField` para que el overlay respete el ancho del field (no se desborde lateralmente).
    - **Validación de campos requeridos** en `_submit` del `entry_form_screen` con `showWarningSnackbar` amarillo (antes el `validator` del field arrastraba el formato del Form que ya no aplica con `DropdownMenu`).
    - **PopScope en `entry_form_screen`**: back desde el form con kind seleccionado vuelve al KindPicker (no cierra el form); con kind null el back es pop normal. Reset completo de monto/fecha/descripción/origen/destino/categoría tanto al volver al KindPicker como al elegir un kind nuevo.
    - **`AccountBalanceHint`** (`lib/widgets/account_balance_hint.dart`): chip reactivo debajo de cada AccountPicker mostrando saldo (cash/debit) o deuda + disponible (credit). Stream de drift para refresh automático.
    - **Skeletons** (`lib/widgets/skeleton.dart` con `Skeleton` y `SkeletonCard`): aplicados en lista de cuentas (`/accounts`), lista de movimientos (`/entries`), las 3 cards BO/DE/CR del Dashboard, las cards de cuenta/balance del Dashboard, las cards de movimientos recientes del Dashboard, y el form de edición de movimiento. Pulse animado para que aparezca en el primer frame.
    - **`initializeDateFormatting('es_MX', null)`** en `main()` antes de `runApp`: imprescindible para `DateFormat` con locale ES; sin esto el `entry_form_screen` daba pantalla blanca en release.
    - **Navegación con `pop`/`push`** (sweep general): sustituido `context.go(...)` por `context.push(...)` en navegaciones "abrir sub-pantalla" y por `Navigator.of(context).maybePop()` en backs/post-save, para que el back nativo del cel respete el stack. Único `go` que queda es el `markFirstRunComplete` y el post-alta del entry_form (`context.go('/dashboard')`) que es la decisión final de Diego: alta → siempre Home.
    - **Snackbars rediseñados** (`lib/widgets/error_snackbar.dart`): 3 tipos (`success` verde, `warning` amarillo, `error` rojo) con icono al inicio, bordes redondeados 12px, elevation 6, margin lateral 16 + bottom 12, `behavior: floating`. **Dismiss on tap** vía `Material + InkWell` que captura el `ScaffoldMessengerState` directo (no el `context`, que muere tras `go('/dashboard')`).
    - **Filtros de movimientos** (`_FiltersSheet` en `entries_list_screen.dart`): `useSafeArea: true` + `isScrollControlled: true` + scroll interno para que los botones Cancelar/Aplicar no se corten. Botón "Limpiar" en el header con `AnimatedOpacity` + `IgnorePointer` para que el header no cambie de altura cuando aparece/desaparece. Label "Cuenta" en el dropdown unificado (antes había Label externo + label interno duplicados). Espacio aumentado entre chips Tipo y dropdown Cuenta.
    - **Settings con scroll completo** (`SafeArea + padding bottom 96`).
    - **Reset de cuenta** en Settings (sección "Zona peligrosa") con `BackupService.wipeAll()` + flip de `FirstRunState.value = false` → redirect a `/first-run`. Replica el flujo del `/finance/reset` del backend legacy.
    - **Form de edición** muestra solo el nombre del kind (sin "Tipo: ... (no editable)"), porque la libreta libre permite editar casi todo. El `kind` sigue inmutable a nivel DAO (cambiarlo requeriría revalidar origen/destino), pero no se le explicita al usuario.
    - **Espaciado y respiración** en `entry_form_screen`: 24px entre AccountPickers y monto, 16px entre monto y fecha, 20px entre fecha y descripción. `helperText: ' '` en todos los `TextFormField` para reservar altura fija (validaciones rojas no empujan los siguientes campos).
  - **APK final**: `app-arm64-v8a-release.apk`, **19.5 MB**. versionName `0.2.0`, versionCode `27`.

## Fase 9 — Documentación + QR

- [x] T052 — `mobile/README.md` creado: setup desde cero (verificar Flutter → pub get → build_runner → tests → analyze), correr en Linux desktop y Android, generar iconos de launcher, build release con `--split-per-abi`, troubleshooting de adb/udev/INSTALL_FAILED_VERSION_DOWNGRADE, filosofía (libreta libre, soft delete terminal, schema sync-ready), cosas NO en el MVP, recovery del legacy.
- [x] T053 — `CLAUDE.md` raíz reescrito desde cero. Refleja la realidad post-pivote: app Flutter local-first como único producto activo, sin backend Laravel / Vue / Docker. Documenta estructura del repo, stack, modelo de dominio (Cuentas + Categorías + JournalEntries con 5 kinds y RN-011), filosofía libreta libre, capa de datos, capa de presentación, tema, convenciones de navegación, errores tipados, tests y decisiones del pivote.
- [x] T054 — `README.md` raíz reescrito desde cero (era el default de Laravel). Pitch breve "Tu libreta digital de cuentas", quick start, estructura, filosofía, recuperación del legacy. `.gitignore` raíz simplificado.
- [x] T055 — `branch-quality-review` ejecutado con 6 subagentes en paralelo. Reporte en `engineering/quality-review/flutter-local-mvp/2026-06-18-1550-branch-quality-review.md`. **5 hallazgos bloqueantes** identificados + 25 no bloqueantes.

## Post-review — Bloqueantes resueltos (versión 0.2.0+28)

Los 5 bloqueantes del branch-quality-review fueron corregidos en la misma sesión:

- [x] **B1** — `.gitignore` raíz restaurado con reglas para `.env`, `.env.tailscale`, `*.ts.net.crt`, `*.ts.net.key`, `.phpunit.result.cache`, `.playwright-mcp/`. Verificado con `git check-ignore -v .env .env.tailscale` → ambos quedan ignorados en `.gitignore:13` y `.gitignore:14`.
- [x] **B2** — `EntriesDao.registerDebtPayment` ahora envuelve check OverpayDebt + insert dentro de `transaction(() async { ... })` (`entries_dao.dart:185-205`).
- [x] **B3** — `AccountsDao.archive()` ahora envuelve check `balance == 0` + soft-delete dentro de `transaction(() async { ... })` (`accounts_dao.dart:196-213`).
- [x] **B4** — Test nuevo en `backup_test.dart`: `'wipeAll vacía las 3 tablas y deja la BD lista para reseed'` que valida tablas vacías + `hasBolsa(db) == false`. Total tests: **57 verdes** (56 → 57).
- [x] **B5** — `entry_form_screen.dart`: `PopScope.canPop = (_isEdit || _kind == null) && !_saving` + botón "Cambiar tipo" deshabilitado durante save (`onPressed: _saving ? null : ...`).

Versión bumpeada a `0.2.0+28` (versionCode 28). APK arm64 reconstruido: 19.5 MB. `flutter analyze` queda en 4 hints info cosméticos (no bloqueantes); `flutter test` 57/57 verde.

Los 25 hallazgos no bloqueantes del reporte (validaciones del import, `android:allowBackup`, índices de performance, cache de `watchAccountBalance`, `onUpgrade` guardrail, etc.) quedan documentados en `pendientes.md` para el próximo sprint.

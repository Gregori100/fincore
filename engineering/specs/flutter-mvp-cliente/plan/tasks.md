# Tasks — flutter-mvp-cliente

Tareas numeradas en orden de dependencia. Categorías usadas: Frontend (Flutter), Pruebas, Validación de calidad, Documentación. No hay tareas de Backend ni Base de datos (sin cambios).

## Fase 1 — Fundación

- [ ] T001 Frontend: crear proyecto Flutter en `mobile/` con `flutter create --org io.github.gregori100 --project-name fincore --platforms=android,linux mobile` (desde la raíz del monorepo). Asegurar que el cwd sea la raíz y la carpeta `mobile/` no exista previamente.
  RF: RF-001
  Depende de: ninguna
  Paralelizable: no
  Criterio de terminado: `cd mobile && flutter run -d linux` arranca la app default ("You have pushed the button N times").

- [ ] T002 Frontend: agregar `mobile/build/`, `mobile/.dart_tool/`, `mobile/.flutter-plugins`, `mobile/.flutter-plugins-dependencies`, `mobile/ios/`, `mobile/macos/`, `mobile/windows/`, `mobile/web/` al `.gitignore` raíz (los targets no soportados los borramos en T003; los caches se ignoran).
  RF: RF-001
  Depende de: T001
  Paralelizable: no
  Criterio de terminado: `git status` desde la raíz no muestra `mobile/build/` ni caches como untracked.

- [ ] T003 Frontend: eliminar carpetas de targets fuera de alcance (`mobile/ios/`, `mobile/macos/`, `mobile/windows/`, `mobile/web/`) si fueron generadas por `flutter create`.
  RF: RF-001
  Depende de: T001
  Paralelizable: si (con T002)
  Criterio de terminado: solo quedan `mobile/android/` y `mobile/linux/` como subcarpetas de plataforma.

- [ ] T004 Frontend: configurar `mobile/android/app/build.gradle.kts` con `applicationId = "io.github.gregori100.fincore"`, `versionCode = 1`, `versionName = "0.1.0"`, `minSdkVersion = 24` (recomendado por dependencias modernas) y `targetSdkVersion = 35`.
  RF: RF-002
  Depende de: T001
  Paralelizable: si
  Criterio de terminado: `grep "io.github.gregori100.fincore" mobile/android/app/build.gradle.kts` retorna línea.

- [ ] T005 Frontend: configurar `mobile/android/app/src/main/AndroidManifest.xml` con `android:label="FinCore"` en `<application>` y declarar `<uses-permission android:name="android.permission.INTERNET"/>` (ningún otro permiso).
  RF: RF-002, RN-007
  Depende de: T001
  Paralelizable: si
  Criterio de terminado: el manifest declara solo INTERNET y la app instalada en Android muestra "FinCore" como nombre.

- [ ] T006 Frontend: configurar `mobile/pubspec.yaml`: nombre `fincore`, descripción, versión `0.1.0+1`, dependencias mínimas — `flutter`, `dio: ^5.7.0`, `flutter_secure_storage: ^9.2.2`, `go_router: ^14.6.2` (verificar compatibilidad con Flutter 3.29 — si exige SDK 3.32+, bajar a `^13.0.0`), `intl: ^0.19.0` (para formato de moneda y fechas). DevDependencies: `flutter_test`, `flutter_lints`, `mocktail: ^1.0.4`.
  RF: RF-001
  Depende de: T001
  Paralelizable: si
  Criterio de terminado: `cd mobile && flutter pub get` completa sin errores.

- [ ] T007 Frontend: estructura inicial de `lib/`: crear carpetas vacías `api/`, `models/`, `screens/`, `widgets/`, `theme/`, `constants/`, `router/`, `storage/`. Crear `lib/main.dart` mínimo que valide `FINCORE_API_URL` (`const apiUrl = String.fromEnvironment('FINCORE_API_URL'); assert(apiUrl.isNotEmpty);`) y arranca un `MaterialApp` vacío.
  RF: RF-003
  Depende de: T006
  Paralelizable: no
  Criterio de terminado: `flutter run -d linux --dart-define=FINCORE_API_URL=https://example.com` arranca sin error; sin `--dart-define` falla el assert con mensaje claro en debug.

- [ ] T008 Frontend: configurar `mobile/analysis_options.yaml` con `include: package:flutter_lints/flutter.yaml` y reglas adicionales razonables (`always_use_package_imports`, `prefer_const_constructors`, `prefer_final_locals`). Correr `flutter analyze` y verificar 0 issues.
  RF: RF-014
  Depende de: T006
  Paralelizable: si
  Criterio de terminado: `flutter analyze` retorna "No issues found!".

- [ ] T009 Frontend: crear `mobile/scripts/run-linux.sh` y `mobile/scripts/build-apk.sh` que encapsulan los comandos con `--dart-define=FINCORE_API_URL=$FINCORE_API_URL` leyendo la variable de entorno o exigiéndola. Hacer ejecutables.
  RF: RF-015
  Depende de: T007
  Paralelizable: si
  Criterio de terminado: `FINCORE_API_URL=https://example.com ./mobile/scripts/run-linux.sh` arranca la app sin errores.

## Fase 2 — Core técnico

- [ ] T010 Frontend: crear `lib/theme/fincore_colors.dart` con las 21 constantes `Color` derivadas de las CSS variables del bloque `@theme` de `frontend/src/assets/main.css`. Convertir oklch → sRGB usando Chromium DevTools o herramienta equivalente. Documentar cada conversión con comentario `// oklch(...) → #RRGGBB`.
  RF: RF-018
  Depende de: T007
  Paralelizable: si
  Criterio de terminado: el archivo tiene `static const canvas`, `surface`, `surfaceElevated`, `border`, `textPrimary`, `textMuted`, `textSubtle`, `accent`, `accentHover`, `positive`, `negative`, `warning` + las 10 de categoría (`categoryBlue`, ..., `categoryGray`). Todos valores `Color(0xFFRRGGBB)`.

- [ ] T011 Frontend: crear `lib/theme/fincore_theme.dart` con `fincoreDarkTheme()` que retorna `ThemeData(useMaterial3: true, brightness: Brightness.dark, colorScheme: ColorScheme.dark(...))`. Mapear colores a slots Material 3: `primary = accent`, `surface = surface`, `surfaceContainer = surfaceElevated`, `outline = border`, `onSurface = textPrimary`, etc. Configurar `cardTheme`, `inputDecorationTheme`, `appBarTheme`, `textTheme` para acercarse a la estética de Vue.
  RF: RF-018
  Depende de: T010
  Paralelizable: no
  Criterio de terminado: `MaterialApp(theme: fincoreDarkTheme())` en `main.dart` renderiza con paleta oscura coherente.

- [ ] T012 Frontend: crear `lib/constants/category_catalog.dart` con las 10 entradas de color (`CategoryColor(slug: 'blue', color: FincoreColors.categoryBlue, label: 'Azul')`) y ~30 íconos del catálogo Vue. Mapear los slugs de Heroicons a `IconData` equivalentes de Material Icons (o usar `flutter_iconly` / `phosphor_flutter` si calza mejor — definir en este task). Exponer `colorBySlug`, `iconBySlug` como helpers.
  RF: RF-007, RF-018
  Depende de: T010
  Paralelizable: si
  Criterio de terminado: el archivo expone `kCategoryColors` (List<CategoryColor>) y `kCategoryIcons` (List<CategoryIcon>); ambos con la misma cantidad y los mismos slugs que `frontend/src/constants/categoryCatalog.js`.

- [ ] T013 Frontend: crear `lib/constants/kinds.dart` con enum `JournalKind { income, expense, creditExpense, debtPayment, transfer }` + extensión `label()` que retorna el texto en español ("Ingreso", "Gasto", "Gasto a tarjeta", "Pago de tarjeta", "Transferencia") y `apiValue()` que retorna el string que el backend espera (`income`, `expense`, `credit_expense`, `debt_payment`, `transfer`).
  RF: RF-009
  Depende de: T007
  Paralelizable: si
  Criterio de terminado: el enum existe y los helpers funcionan; test unitario corto en T064 cubre el mapping.

- [ ] T014 Frontend: crear `lib/constants/account_types.dart` con enum `AccountType { cash, debit, credit }` + helpers `label()` ("Bolsa", "Débito", "Crédito"), `apiValue()`, `isCashLike()` (cash o debit), `canBeOrigin(JournalKind)`, `canBeDestination(JournalKind)`.
  RF: RF-006, RF-009
  Depende de: T007
  Paralelizable: si
  Criterio de terminado: helpers funcionan; mapping kind ↔ tipo válido coincide con backend (ej. `transfer` requiere ambos cash-like).

- [ ] T015 Frontend: crear `lib/api/api_client.dart` con `dio.Dio` configurado: `baseUrl: FINCORE_API_URL`, `headers: {'Accept': 'application/json'}`, timeout 15s. Agregar interceptor de Auth (inyecta `Authorization: Bearer <token>` desde `TokenStorage`) e interceptor de errores que maneja 401, 403-verified, 422, 429, 5xx/network como describe `plan.md`.
  RF: RF-013
  Depende de: T007, T017
  Paralelizable: no
  Criterio de terminado: `ApiClient()` se instancia, expone `dio` y los interceptores; tests T063 lo cubren.

- [ ] T016 Frontend: crear `lib/models/` con clases data inmutables (con `fromJson` y `toJson` manual sin codegen): `User`, `Account` (con metadata de credit), `Category`, `JournalEntry`, `FinanceState`, `Paginated<T>`, `DomainError` (representa el `{ error, code }` del backend o `errors` de validación).
  RF: RF-004..RF-011
  Depende de: T013, T014
  Paralelizable: si
  Criterio de terminado: cada modelo tiene constructor, `fromJson`, `toJson`, igualdad por valor (`==` y `hashCode`). Documentar campos que pueden ser null.

- [ ] T017 Frontend: crear `lib/storage/token_storage.dart` envolviendo `flutter_secure_storage`. Métodos: `readToken()`, `writeToken(String)`, `clearToken()`. En Linux desktop usar `LinuxOptions(useSessionKeyring: false)` para evitar dependencia de keyring del SO en dev.
  RF: RF-004, RF-010
  Depende de: T006
  Paralelizable: si
  Criterio de terminado: `TokenStorage` se instancia y permite ciclo read/write/clear sin error en Linux y Android.

- [ ] T018 Frontend: crear `lib/api/auth_api.dart` con métodos `login(email, password)`, `logout()`, `me()`, `resendVerification()`. Cada método recibe el `ApiClient`, mapea response a `User` o lanza `DioException` que el interceptor maneja.
  RF: RF-004, RF-010, RF-017
  Depende de: T015, T016
  Paralelizable: si
  Criterio de terminado: tests T064 cubren los 4 endpoints.

- [ ] T019 Frontend: crear `lib/api/{accounts_api.dart, categories_api.dart, entries_api.dart, state_api.dart}` con métodos del CRUD que la app usa. Misma firma que `auth_api.dart` (recibe `ApiClient`, retorna modelo o lanza).
  RF: RF-005, RF-006, RF-007, RF-008
  Depende de: T015, T016
  Paralelizable: si
  Criterio de terminado: tests T065, T066, T067 cubren los métodos críticos.

- [ ] T020 Frontend: crear `lib/router/app_router.dart` con `GoRouter` declarativo. Rutas: `/login`, `/verify-email`, `/dashboard`, `/accounts`, `/accounts/new`, `/accounts/:id/edit`, `/categories`, `/categories/new`, `/categories/:id/edit`, `/entries`, `/entries/new`, `/entries/:id/edit`, `/settings`. Redirect: sin token → `/login`; con token pero 403-verify → `/verify-email`; con token válido en login → `/dashboard`.
  RF: RF-013
  Depende de: T017, T018
  Paralelizable: no
  Criterio de terminado: navegación condicional probada en widget tests (T068).

## Fase 3 — Auth

- [ ] T021 Frontend: crear `lib/screens/login_screen.dart`. Form con email + password + botón "Iniciar sesión". Submit → `authApi.login()` → guardar token → `me()` → navegar a `/dashboard` o `/verify-email` según `email_verified_at`. Mostrar errores 422 y 429.
  RF: RF-004
  Depende de: T011, T018, T020
  Paralelizable: si (con otras pantallas)
  Criterio de terminado: login real contra backend funciona en Linux desktop.

- [ ] T022 Frontend: crear `lib/screens/verify_email_screen.dart`. Muestra email del user, texto explicativo, botón "Reenviar correo" con cooldown 10s tras envío exitoso, botón "Ya verifiqué" que llama `me()` y navega a `/dashboard` si pasa.
  RF: RF-017
  Depende de: T011, T018, T020
  Paralelizable: si
  Criterio de terminado: con un usuario sin verificar, la pantalla aparece tras login y el botón Reenviar genera email visible en logs del backend.

- [ ] T023 Frontend: crear `lib/widgets/error_snackbar.dart` y helpers `showErrorSnackbar(BuildContext, String)` + parser `domainErrorToMessage(DomainError)` que mapea códigos conocidos (`overpay_debt`, `invalid_credit_metadata`, `protected_account`, `account_not_empty`, `duplicate_account_name`, `duplicate_category_name`, `insufficient_funds`, etc.) a textos en español. Default: usar `error.error` directo.
  RF: RF-013
  Depende de: T016
  Paralelizable: si
  Criterio de terminado: `domainErrorToMessage(DomainError(error: 'X', code: 'overpay_debt'))` retorna "No podés pagar más de lo que debes a la tarjeta."

## Fase 4 — Dashboard

- [ ] T024 Frontend: crear `lib/widgets/amount_formatter.dart` con helper `formatAmount(num, {bool showSign = false})` que aplica `NumberFormat.currency(locale: 'es_MX', symbol: '\$')`. Permitir `showSign: true` para mostrar `+` en ingresos.
  RF: RF-005
  Depende de: T006 (intl)
  Paralelizable: si
  Criterio de terminado: `formatAmount(1234.5)` retorna `"$1,234.50"`.

- [ ] T025 Frontend: crear `lib/widgets/category_badge.dart` que recibe `Category?` y renderiza un chip con color e ícono del catálogo; si `category == null`, muestra "Sin categoría" en gris.
  RF: RF-007, RF-008
  Depende de: T012
  Paralelizable: si
  Criterio de terminado: badge se renderiza con paleta correcta.

- [ ] T026 Frontend: crear `lib/widgets/base_card.dart` (wrapper de `Card` con padding y elevación consistente) y otros wrappers de UI compartida (`section_title.dart`).
  RF: estética
  Depende de: T011
  Paralelizable: si
  Criterio de terminado: wrappers consistentes en toda la app.

- [ ] T027 Frontend: crear `lib/screens/dashboard_screen.dart`. Carga `GET /finance/state` en `initState`, muestra 3 cards (BO, DE, CR) en grid, lista de cuentas activas, lista de últimos N movimientos. Pull-to-refresh recarga. AppBar con título "FinCore" + ícono de settings.
  RF: RF-005
  Depende de: T011, T015, T019, T024, T025, T026
  Paralelizable: si
  Criterio de terminado: dashboard muestra datos reales contra backend en Linux desktop.

## Fase 5 — Cuentas

- [ ] T028 Frontend: crear `lib/screens/accounts_list_screen.dart`. Lista cuentas con `name`, `type` badge, saldo formateado. FAB para crear. Tap en cuenta → navegar a edit. La Bolsa muestra ícono de candado y al tocar va a vista solo lectura (mensaje "Es tu Bolsa, no editable").
  RF: RF-006
  Depende de: T014, T015, T019, T024
  Paralelizable: si
  Criterio de terminado: lista renderiza tras login.

- [ ] T029 Frontend: crear `lib/widgets/account_type_picker.dart` (selector entre Debit y Credit; Cash no es opción porque la Bolsa no se crea).
  RF: RF-006
  Depende de: T014
  Paralelizable: si
  Criterio de terminado: picker funciona en el form.

- [ ] T030 Frontend: crear `lib/screens/account_form_screen.dart`. Modo crear o editar (según ruta y parámetros). Campos comunes: nombre + descripción. Si type = credit, agrega: credit_limit, closing_day, payment_day, interest_rate, minimum_payment_pct. Validaciones locales mínimas; el backend valida el resto. Mutex `_saving`.
  RF: RF-006
  Depende de: T028, T029
  Paralelizable: si
  Criterio de terminado: crear y editar funcionan contra backend real.

- [ ] T031 Frontend: agregar botón "Eliminar" en `account_form_screen` (modo editar) con `ConfirmDialog`. Llama `DELETE /accounts/{id}`. Si responde 422 `account_not_empty`, mostrar el mensaje.
  RF: RF-006
  Depende de: T030
  Paralelizable: no
  Criterio de terminado: eliminar cuenta vacía exitoso; cuenta con saldo muestra el error.

## Fase 6 — Categorías

- [ ] T032 Frontend: crear `lib/screens/categories_list_screen.dart`. Lista categorías con `CategoryBadge`, filtro por `applies_to` (chips). FAB para crear. Tap → edit.
  RF: RF-007
  Depende de: T012, T025, T019
  Paralelizable: si
  Criterio de terminado: lista renderiza con badges visibles.

- [ ] T033 Frontend: crear `lib/widgets/color_picker.dart` que muestra los 10 slugs del catálogo en grid; selección guarda slug.
  RF: RF-007
  Depende de: T012
  Paralelizable: si
  Criterio de terminado: tap en color resalta selección.

- [ ] T034 Frontend: crear `lib/widgets/icon_picker.dart` análogo con los ~30 íconos del catálogo.
  RF: RF-007
  Depende de: T012
  Paralelizable: si
  Criterio de terminado: tap en ícono resalta selección.

- [ ] T035 Frontend: crear `lib/widgets/applies_to_picker.dart` con segmented button entre income / expense / both.
  RF: RF-007
  Depende de: T011
  Paralelizable: si
  Criterio de terminado: picker funciona en el form.

- [ ] T036 Frontend: crear `lib/screens/category_form_screen.dart`. Modo crear/editar. Campos: nombre, applies_to, color_picker, icon_picker. Mutex `_saving`.
  RF: RF-007
  Depende de: T032, T033, T034, T035
  Paralelizable: si
  Criterio de terminado: crear y editar funcionan contra backend.

- [ ] T037 Frontend: agregar botón "Archivar" en `category_form_screen` con `ConfirmDialog` que advierte "Los movimientos con esta categoría seguirán existiendo pero sin badge". Llama `DELETE /categories/{id}`.
  RF: RF-007
  Depende de: T036
  Paralelizable: no
  Criterio de terminado: archivar funciona; categoría desaparece de la lista activa.

## Fase 7 — Movimientos

- [ ] T038 Frontend: crear `lib/widgets/kind_picker.dart` que muestra los 5 kinds con ícono y etiqueta en español. Usado como primer paso del form de creación.
  RF: RF-009
  Depende de: T013
  Paralelizable: si
  Criterio de terminado: picker funciona y emite el kind seleccionado.

- [ ] T039 Frontend: crear `lib/widgets/account_picker.dart` que recibe `List<Account>` + `List<AccountType> allowedTypes` y muestra solo las cuentas cuyo tipo está en la lista. Usado en formularios de entry según el kind.
  RF: RF-009
  Depende de: T014
  Paralelizable: si
  Criterio de terminado: picker filtra correctamente según el kind.

- [ ] T040 Frontend: crear `lib/widgets/category_picker.dart` que filtra por `applies_to` según el kind seleccionado.
  RF: RF-009
  Depende de: T012
  Paralelizable: si
  Criterio de terminado: picker filtra correctamente.

- [ ] T041 Frontend: crear `lib/screens/entries_list_screen.dart`. Lista paginada con `GET /entries`. Filtros en AppBar/bottomsheet: kind, account, rango de fecha. FAB para crear (lleva a kind picker → form). Tap en entry → edit. Long-press o menú → cancelar.
  RF: RF-008
  Depende de: T015, T019, T024, T025
  Paralelizable: si
  Criterio de terminado: lista renderiza, scroll infinito carga páginas, filtros aplicados refrescan la lista.

- [ ] T042 Frontend: crear `lib/screens/entry_form_screen.dart` con composición dinámica según el kind:
  - **income**: account_destination (debit, cash) + amount + descripción + occurred_at + category (income/both).
  - **expense**: account_origin (debit, cash) + amount + descripción + occurred_at + category (expense/both).
  - **credit_expense**: account_origin (credit) + amount + descripción + occurred_at + category (expense/both).
  - **debt_payment**: account_origin (debit, cash) + account_destination (credit) + amount + descripción + occurred_at. Sin category.
  - **transfer**: account_origin (debit, cash) + account_destination (debit, cash) + amount + descripción + occurred_at. Sin category. Origin ≠ destination.
  Submit llama al endpoint correspondiente (`/income`, `/expense`, etc.). Mutex `_saving`.
  RF: RF-009
  Depende de: T038, T039, T040, T041
  Paralelizable: no
  Criterio de terminado: los 5 kinds se crean contra backend real.

- [ ] T043 Frontend: modo editar en `entry_form_screen`: `PATCH /entries/{id}` con campos editables (`category_id`, `description`, `occurred_at`, `account_origin_id`, `account_destination_id`, `amount`). El `kind` se muestra solo lectura en un chip.
  RF: RF-010
  Depende de: T042
  Paralelizable: no
  Criterio de terminado: editar entry existente funciona y refleja cambios en la lista.

- [ ] T044 Frontend: acción "Cancelar movimiento" en `entry_form_screen` con `ConfirmDialog`. `DELETE /entries/{id}`. Si responde 404 (race con otra sesión), tratar como éxito y mostrar mensaje "Ya estaba cancelado".
  RF: RF-011
  Depende de: T043
  Paralelizable: no
  Criterio de terminado: cancelar funciona; race condition manejada.

## Fase 8 — Settings

- [ ] T045 Frontend: crear `lib/screens/settings_screen.dart`. Muestra: nombre y email del user, URL del API actual (desde `String.fromEnvironment('FINCORE_API_URL')`), versión (desde `package_info_plus` o constante hardcoded `0.1.0+1`). Botón "Cerrar sesión" con `ConfirmDialog` → `authApi.logout()` (tolera fallo de red) → `tokenStorage.clearToken()` → navegar a `/login`.
  RF: RF-012
  Depende de: T015, T018, T020
  Paralelizable: si
  Criterio de terminado: settings renderiza y logout completa el ciclo.

## Fase 9 — Pruebas

Ver `test-plan.md` para detalle de qué cubre cada test. Aquí solo el listado de tareas.

- [ ] T046 Pruebas: crear `test/helpers/test_app.dart` que monta `MaterialApp.router` con `fincoreDarkTheme`, `ApiClient` mockeado y `TokenStorage` mockeado. Debe drenar timers internos al teardown (patrón aprendido en dogear: sin esto, `testWidgets` revienta con "Timer is still pending").
  RF: RF-014
  Depende de: T020
  Paralelizable: no
  Criterio de terminado: el helper se instancia en un test trivial sin warning.

- [ ] T047 Pruebas: `test/api/auth_api_test.dart` — cubre login éxito (200 con token), credenciales inválidas (422 con errors), throttle (429), logout (204), me (200 con user), resend (204), resend con throttle (429).
  RF: RF-014, RN-004
  Depende de: T018
  Paralelizable: si
  Criterio de terminado: 7 tests verdes.

- [ ] T048 Pruebas: `test/api/entries_api_test.dart` — cubre create income, create expense, create credit_expense, create debt_payment éxito + overpay_debt 422, create transfer, patch entry, delete entry, delete entry ya cancelado (404).
  RF: RF-014, RN-003
  Depende de: T019
  Paralelizable: si
  Criterio de terminado: 9 tests verdes.

- [ ] T049 Pruebas: `test/api/error_interceptor_test.dart` — cubre 401 → limpia token + dispara redirect; 403-verify → dispara navegación a verify; 422 con code → parsea DomainError; 429 → mensaje throttle; 5xx → mensaje genérico; DioException network → mensaje sin conexión.
  RF: RF-013
  Depende de: T015
  Paralelizable: si
  Criterio de terminado: 6 tests verdes.

- [ ] T050 Pruebas: `test/screens/login_screen_test.dart` — cubre render del form, submit con credenciales válidas (navega a dashboard), submit con 422 (muestra error), submit con 403-verify post-login (navega a verify).
  RF: RF-014, RF-004, RF-017
  Depende de: T021, T046
  Paralelizable: si
  Criterio de terminado: 3 tests verdes.

- [ ] T051 Pruebas: `test/screens/dashboard_screen_test.dart` — cubre render con state mockeado (3 totales + cuentas + entries), pull-to-refresh recarga, navegación a settings desde AppBar.
  RF: RF-014, RF-005
  Depende de: T027, T046
  Paralelizable: si
  Criterio de terminado: 3 tests verdes.

- [ ] T052 Pruebas: `test/screens/entry_form_screen_test.dart` — cubre form expense (selecciona cuenta + monto + descripción + categoría + guarda), form transfer (origen ≠ destino), form debt_payment con 422 overpay_debt (muestra mensaje), edit con kind no editable, doble tap → un solo submit.
  RF: RF-014, RF-009, RF-010, RN-010
  Depende de: T042, T046
  Paralelizable: si
  Criterio de terminado: 5 tests verdes.

- [ ] T053 Pruebas: `test/screens/verify_email_screen_test.dart` — cubre render, botón "Reenviar correo" llama endpoint, cooldown 10s deshabilita botón tras envío, botón "Ya verifiqué" con éxito navega a dashboard.
  RF: RF-014, RF-017
  Depende de: T022, T046
  Paralelizable: si
  Criterio de terminado: 4 tests verdes.

- [ ] T054 Validación de calidad: ejecutar suite completa (`flutter test`) y verificar todos verdes. Mínimo declarado en spec: ≥10 tests; con los anteriores se llega a ~37.
  RF: RF-014
  Depende de: T047..T053
  Paralelizable: no
  Criterio de terminado: `flutter test` reporta "All tests passed!" con ≥30 tests.

- [ ] T055 Validación de calidad: ejecutar `flutter analyze` y verificar 0 issues. Si hay warnings, resolver o documentar el supresor con razón.
  RF: RF-014
  Depende de: cualquier fase previa de UI
  Paralelizable: si
  Criterio de terminado: "No issues found!".

## Fase 10 — Build release + smoke real

- [ ] T056 Frontend: verificar `AndroidManifest.xml` final declara solo `android.permission.INTERNET` (sin permisos heredados de plugins). Si algún plugin añade extras, suprimir con `<uses-permission android:name="..." tools:node="remove"/>`.
  RF: RN-007
  Depende de: T005, todas las fases de UI
  Paralelizable: no
  Criterio de terminado: `grep "uses-permission" mobile/android/app/src/main/AndroidManifest.xml` solo lista INTERNET (y `tools:node="remove"` si aplica).

- [ ] T057 Frontend: ejecutar `flutter build apk --release --dart-define=FINCORE_API_URL=https://loma-latitude-3540.tail285790.ts.net`. Verificar APK generado en `mobile/build/app/outputs/flutter-apk/app-release.apk`.
  RF: RF-015
  Depende de: T056
  Paralelizable: no
  Criterio de terminado: APK existe, < 30 MB.

- [ ] T058 Frontend: instalar APK en el Android del usuario vía `adb install` (Diego ejecuta; instrucciones documentadas en README). Verificar que el ícono "FinCore" aparece en el home.
  RF: RF-015
  Depende de: T057
  Paralelizable: no
  Criterio de terminado: ícono FinCore visible en home del Redmi Note 13 del usuario.

- [ ] T059 Validación de calidad (smoke manual): completar el flujo end-to-end en el Android con Tailscale activo: login → dashboard con datos reales → crear gasto + transfer + debt_payment → editar uno → cancelar uno → logout. Documentar resultado en `implementation/progreso.md` (lo crea spec-implementar; placeholder por ahora).
  RF: criterios de aceptación de spec
  Depende de: T058
  Paralelizable: no
  Criterio de terminado: los 6 flujos pasan en celular real; el dashboard refleja los cambios.

- [ ] T060 Validación de calidad (smoke verify email): crear usuario de prueba `diego+verify@mgtransportes.mx` desde la Vue web SIN verificar (o forzar `UPDATE users SET email_verified_at = NULL WHERE email = 'diego+verify@mgtransportes.mx'` desde shell del backend) → login desde Flutter → debería ir a pantalla Verify → tocar "Reenviar correo" → verificar que llega al log del backend → marcar verificado → "Ya verifiqué" → entrar a dashboard.
  RF: RF-017
  Depende de: T058
  Paralelizable: no
  Criterio de terminado: flujo completo pasa; el usuario de prueba queda verificado en BD.

## Fase 11 — Documentación

- [ ] T061 Documentación: crear `mobile/README.md` con: descripción de la app (cliente Flutter del backend Laravel), cómo correr en Linux desktop (`./scripts/run-linux.sh` con env var), cómo construir APK release (`./scripts/build-apk.sh`), cómo instalar en Android (`adb install`), cómo crear usuario de testing para verify email, cómo regenerar APK tras cambio de URL del backend.
  RF: RF-016
  Depende de: T009, T057
  Paralelizable: si
  Criterio de terminado: README cubre los 6 puntos listados.

- [ ] T062 Documentación: agregar sección "Mobile architecture (`mobile/`)" en `CLAUDE.md` raíz en paralelo a las secciones Backend y Frontend. Cubrir: estructura de `lib/`, decisiones técnicas (dio + go_router + secure_storage), tema con paleta de Vue, comandos clave, dependencia de Tailscale para acceso al backend.
  RF: RF-016
  Depende de: T061
  Paralelizable: no
  Criterio de terminado: `CLAUDE.md` raíz contiene la nueva sección, referenciada desde el índice si existe.

- [ ] T063 Validación de calidad: ejecutar `branch-quality-review` sobre la rama del sprint. Revisar reporte generado en `engineering/quality-review/flutter-mvp-cliente/`. Resolver cualquier hallazgo bloqueante antes de merge.
  RF: estrategia de pruebas
  Depende de: T054, T055, T059, T060, T061, T062
  Paralelizable: no
  Criterio de terminado: reporte de quality-review existe, 0 hallazgos bloqueantes documentados como resueltos o aceptados con razón.

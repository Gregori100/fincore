# Plan técnico — flutter-mvp-cliente

## Enfoque técnico

App Flutter 3.29.3 en una carpeta nueva `mobile/` del monorepo. Stack: `dio` como HTTP client con interceptores, `flutter_secure_storage` para el bearer token, `go_router` para navegación declarativa, `flutter_test` + `mocktail` para tests. Sin gestor de estado externo: `StatefulWidget` + Futures cacheados en el `State` (recrear solo al cambiar filtros — patrón aprendido en dogear para evitar rebuild loops).

La app es un cliente delgado contra el API Laravel existente. NO duplica reglas de dominio; solo presenta y serializa. El backend sigue siendo la fuente única de verdad. Cero cambios en `backend/` ni `frontend/` (Vue queda congelada). Estructura del repo después del sprint: `backend/` + `frontend/` + `mobile/`, con `engineering/` gobernando el proceso. `CLAUDE.md` raíz recibe una sección Flutter en paralelo a las de Backend y Frontend.

URL del API se inyecta solo en compile time vía `--dart-define=FINCORE_API_URL=...`. Sin valor por defecto: el `main()` valida y termina con mensaje claro si falta, para evitar conectar silenciosamente a un host viejo. Documento README.md de `mobile/` registra el comando exacto.

Tema visual replica la paleta exacta de la Vue web. Las CSS variables del bloque `@theme` de `frontend/src/assets/main.css` (canvas, surface, surface-elevated, border, text-primary, text-muted, text-subtle, accent, positive, negative, warning + 10 colores de categoría — todas en formato oklch) se convierten manualmente a sRGB en tiempo de implementación y se exponen como constantes `Color` en `lib/theme/fincore_colors.dart`. El `ColorScheme.dark` custom mapea esas constantes a los slots Material 3 (primary, surface, etc.). Los 10 slugs del catálogo de categorías se exponen en `lib/constants/category_catalog.dart` paralelo al JS de la Vue.

Manejo de errores HTTP centralizado en un interceptor de `dio`:
- 401 → limpia token + redirige a Login con mensaje "Sesión expirada".
- 403 con código de no verificación (middleware `verified` de Laravel; respuesta `{"message":"Your email address is not verified."}`) → navegar a pantalla Verify, no a "Sesión expirada".
- 422 → parsear `{ error, code }` de DomainException o `errors` de Laravel validation; mostrar mensajes amigables en español mapeando códigos conocidos (`overpay_debt`, `invalid_credit_metadata`, `protected_account`, etc.).
- 429 → mensaje "Demasiados intentos, espera 1 minuto" (throttle `6,1` aplica a login, register, password forgot/reset, verification resend).
- 5xx / timeout / DioException → snackbar reintentar; el formulario conserva los datos.

## Requisitos funcionales cubiertos

- RF-001: proyecto Flutter en `mobile/` con targets Android + Linux desktop. Cubierto en fase de fundación (T001-T005).
- RF-002: `applicationId = io.github.gregori100.fincore`, `versionCode = 1`, `versionName = "0.1.0"`. T006.
- RF-003: URL del API configurable en compile time, sin default. T007.
- RF-004: pantalla Login. T020-T024.
- RF-005: pantalla Dashboard. T028-T031.
- RF-006: pantalla Cuentas (lista + crear + editar + eliminar; debit y credit). T032-T039.
- RF-007: pantalla Categorías (lista + crear + editar + archivar; color/icon picker del catálogo). T040-T045.
- RF-008: pantalla Movimientos (lista paginada + filtros). T046-T049.
- RF-009: crear movimiento por kind (income, expense, credit_expense, debt_payment, transfer). T050-T056.
- RF-010: editar movimiento. T057.
- RF-011: cancelar movimiento. T058.
- RF-012: pantalla Settings mínimo (logout + URL del API + versión). T060-T062.
- RF-013: manejo global de errores HTTP. T015 (interceptor `dio`).
- RF-014: suite de tests ≥10 verde. T063-T076 (12 tests targeted).
- RF-015: APK release con `flutter build apk --release --dart-define=...`. T077-T080.
- RF-016: README de `mobile/` + sección Flutter en `CLAUDE.md` raíz. T081-T082.
- RF-017: pantalla "Verifica tu email" + botón "Reenviar". T025-T027.
- RF-018: tema visual réplica paleta exacta de Vue. T010-T013.

## Archivos o módulos probablemente afectados

Nuevos (todos dentro de `mobile/`):

- `mobile/pubspec.yaml`, `mobile/analysis_options.yaml`, `mobile/README.md`
- `mobile/android/app/build.gradle.kts` (applicationId, versionCode, versionName)
- `mobile/android/app/src/main/AndroidManifest.xml` (permiso INTERNET, label "FinCore")
- `mobile/lib/main.dart` (DI: dio + secure storage + go_router; valida FINCORE_API_URL)
- `mobile/lib/api/`
  - `api_client.dart` (dio configurado + interceptor de Auth + interceptor de errores)
  - `auth_api.dart`, `accounts_api.dart`, `categories_api.dart`, `entries_api.dart`, `state_api.dart`
- `mobile/lib/models/`
  - `user.dart`, `account.dart`, `category.dart`, `journal_entry.dart`, `finance_state.dart`, `paginated.dart`, `domain_error.dart`
- `mobile/lib/storage/token_storage.dart` (envuelve `flutter_secure_storage`)
- `mobile/lib/theme/`
  - `fincore_colors.dart` (constantes Color desde oklch convertido)
  - `fincore_theme.dart` (`ThemeData` con `ColorScheme.dark` custom)
- `mobile/lib/constants/`
  - `category_catalog.dart` (10 slugs de color + ~30 íconos, paralelo a `frontend/src/constants/categoryCatalog.js`)
  - `kinds.dart` (enum y mapping a etiquetas en español)
  - `account_types.dart` (enum + helpers)
- `mobile/lib/router/app_router.dart` (rutas con redirect según token + verify)
- `mobile/lib/screens/`
  - `login_screen.dart`
  - `verify_email_screen.dart`
  - `dashboard_screen.dart`
  - `accounts_list_screen.dart`, `account_form_screen.dart`
  - `categories_list_screen.dart`, `category_form_screen.dart`
  - `entries_list_screen.dart`, `entry_form_screen.dart`
  - `settings_screen.dart`
- `mobile/lib/widgets/`
  - `base_card.dart`, `category_badge.dart`, `amount_formatter.dart`, `kind_picker.dart`, `account_picker.dart`, `category_picker.dart`, `color_picker.dart`, `icon_picker.dart`, `confirm_dialog.dart`, `error_snackbar.dart`
- `mobile/test/`
  - `api/auth_api_test.dart`, `entries_api_test.dart`, `error_interceptor_test.dart`
  - `screens/login_screen_test.dart`, `dashboard_screen_test.dart`, `entry_form_screen_test.dart`
  - `helpers/test_app.dart`, `helpers/api_client_mock.dart`

Modificados (mínimos, fuera de `mobile/`):

- `CLAUDE.md` (raíz): nueva sección "Mobile architecture" en paralelo a Backend y Frontend; comandos `flutter run -d linux`, `flutter test`, `flutter build apk --release`.
- `.gitignore` (raíz): excluir `mobile/build/`, `mobile/.dart_tool/`, `mobile/.flutter-plugins`, `mobile/.flutter-plugins-dependencies`, etc. — los gitignore estándar de Flutter.

Sin tocar: `backend/`, `frontend/`.

## Entidades y estados afectados

La app no agrega entidades; consume las del backend:

- **User**: `id` (UUID), `name`, `email`, `email_verified_at`.
- **Account**: `id`, `name`, `type` (`cash | debit | credit`), `description?`, `is_protected`, `deleted_at?`, metadata de credit (`credit_limit`, `closing_day`, `payment_day`, `interest_rate?`, `minimum_payment_pct?`). Saldo derivado viene del backend en `FinanceState.accounts[].balance`.
- **Category**: `id`, `name`, `applies_to` (`income | expense | both`), `color_slug`, `icon_slug`, `deleted_at?`.
- **JournalEntry**: `id`, `kind` (`income | expense | credit_expense | debt_payment | transfer`), `account_origin_id?`, `account_destination_id?`, `amount`, `description?`, `occurred_at`, `category_id?`, `deleted_at?`, relaciones `account_origin`, `account_destination`, `category` (la `category` puede ser `null` si fue archivada).
- **FinanceState**: snapshot con BO, DE, CR, lista de cuentas activas + balance, últimos N movimientos.

Estados relevantes que la UI debe respetar:
- **Bolsa** (`is_protected = true`): no editable, no eliminable.
- **Cuenta archivada** (`deleted_at != null`): aparece solo cuando se incluye `?include_archived=1`; UI no la muestra por default.
- **Categoría archivada**: aparece con `?include_archived=1`; entries con categoría archivada se muestran sin badge (`category` = null en la relación porque el backend usa scope sin `withTrashed`).
- **Movimiento cancelado** (`deleted_at != null`): no aparece en `listEntries`. Cancelar es terminal.

Invariantes que valida el backend (no la app):
- `cash` es singleton por user (no crear, no eliminar).
- `credit.closing_day != credit.payment_day`.
- `OverpayDebt` al pagar a tarjeta.
- Cuenta con saldo distinto a 0 no se puede archivar.

## Compatibilidad con datos y procesos existentes

- **Cero cambios en backend**: no se requieren endpoints nuevos, migraciones ni ajustes de validación. El plan se construye encima del API existente.
- **Vue web sigue funcional**: la app Flutter y la Vue conviven contra el mismo backend; un movimiento creado en una aparece en la otra tras refresh. No hay race conditions porque ambos clientes son Diego (en la práctica, lecturas y escrituras espaciadas en el tiempo).
- **BD compartida con dev**: la cuenta del usuario `diego.velez@mgtransportes.mx` ya está verificada y tiene datos reales. Para validar el flow del RF-017 (verify email) hay que crear OTRO usuario de prueba (`diego+verify@mgtransportes.mx` por ejemplo) o forzar temporalmente `email_verified_at = NULL` en la BD para el usuario existente. La spec lo asume y documenta en supuestos (S-009 implícito).
- **Reportes / Excel / Plan / Forecast en Vue**: no cambian; siguen disponibles cuando el usuario abre la Vue web desde laptop.

## Cambios de datos

No aplica. Sin migraciones, sin scripts ETL, sin transformaciones de datos. La app es read/write contra endpoints existentes.

## Cambios de API

No aplica. Cero endpoints nuevos. La app consume:

- POST `/api/auth/login`
- POST `/api/auth/logout`
- GET `/api/auth/me`
- POST `/api/auth/email/verification-notification` (throttle `6,1`)
- GET `/api/finance/state`
- GET `/api/finance/accounts` (con `?include_archived=1` opcional)
- POST `/api/finance/accounts`
- PATCH `/api/finance/accounts/{id}`
- DELETE `/api/finance/accounts/{id}`
- GET `/api/finance/categories` (con `?include_archived=1`, `?applies_to=...`)
- POST `/api/finance/categories`
- PATCH `/api/finance/categories/{id}`
- DELETE `/api/finance/categories/{id}` (archivar)
- GET `/api/finance/entries` (filtros: `account_id`, `category_id`, `kind`, `from`, `to`, `page`)
- PATCH `/api/finance/entries/{id}`
- DELETE `/api/finance/entries/{id}` (cancelar)
- POST `/api/finance/income`
- POST `/api/finance/expense`
- POST `/api/finance/credit-expense`
- POST `/api/finance/pay-credit`
- POST `/api/finance/transfer`

Lista no incluida en MVP (futuro): `/reports/*`, `/plan/*`, `/backup/*`, `/reset`.

## Cambios de integraciones

No aplica. La única "integración" del cliente es el API HTTP del backend, que ya está consolidado.

## Cambios de UI

Toda la UI es nueva (carpeta `mobile/`). Cero cambios en la Vue web. Ver sección "Archivos o módulos probablemente afectados" para el desglose de pantallas y widgets.

Notas de UI:
- **Tema único oscuro** con paleta réplica de Vue (oklch convertido a sRGB). Sin alternancia claro/oscuro.
- **Texto en español** en toda la app. Sin i18n por ahora (clave fija en español como las pantallas de Vue).
- **Material 3** (`useMaterial3: true`) pero con `ColorScheme.dark` custom mapeado a las CSS vars de Vue. Acepta que algunos componentes Material 3 (FAB extendido, Cards elevadas, etc.) tengan defaults que no calzan 1:1 con la estética de Vue — el `ThemeData` los ajusta donde sea posible.
- **Formularios**: campos de monto usan `TextInputType.numberWithOptions(decimal: true)`; campos de descripción son `TextField` multilinea opcional; fechas con `showDatePicker` material 3.
- **Pickers compartidos**: `account_picker` filtra por tipo según el contexto del kind. `category_picker` filtra por `applies_to`. `color_picker` y `icon_picker` muestran el catálogo curado.

## Cambios de permisos

Android: solo se declara `android.permission.INTERNET` en `AndroidManifest.xml`. Ningún otro permiso (sin storage, sin location, sin contacts, sin camera). El manifest se valida en RF-015 y T080.

No hay roles ni permisos a nivel de aplicación (la app es single-user). El backend ya valida acceso vía Sanctum bearer token.

## Riesgos técnicos

- **Flutter 3.29.3 tiene ~14 meses**: alguna dependencia moderna (`go_router` 14+, `dio` 5.x, `flutter_secure_storage` 9+) puede exigir SDK 3.32+. Mitigación: anclar versiones conservadoras en `pubspec.yaml` durante el setup; si una versión moderna lo requiere y no hay alternativa, levantar como pregunta para considerar upgrade del SDK como tarea explícita.
- **Conversión oklch → sRGB** para los 11 colores base + 10 colores de categoría: oklch es relativamente nuevo y los conversores online pueden dar variaciones de 1-2 puntos en RGB. Mitigación: usar Chromium DevTools o `culori.js` para convertir con precisión, validar visualmente en `flutter run -d linux` antes de cerrar el tema. Si Diego nota diferencia perceptible, ajustar.
- **Tailscale obligatorio en celular**: si el usuario apaga Tailscale por accidente, la app pierde conexión y muestra error. Documentado en spec; no es bloqueante de implementación.
- **Verify email flow requiere usuario sin verificar** para testing manual. Mitigación: crear una migración seeder de testing local (o documentar el comando SQL `UPDATE users SET email_verified_at = NULL WHERE email = ...` que se ejecuta una vez para validar el flow en smoke; revertir después).
- **Material 3 vs paleta Vue**: algunos defaults (elevación de cards, ripple effects, sombras) pueden ensuciar la réplica. Mitigación: ajustar `cardTheme`, `appBarTheme`, `inputDecorationTheme` en `fincore_theme.dart` lo suficiente; aceptar 95% de similitud.
- **Throttle 6,1 del verify**: si el usuario aprieta "Reenviar" más de 6 veces en 1 minuto, recibe 429. La UI debe deshabilitar el botón temporalmente tras cada envío exitoso (cooldown visible de 10s) para no llegar al límite por accidente.
- **Filtros de fecha en `entries`**: el helper compartido del backend ya aplica `to <= 23:59:59` (sprint entries-by-bucket-fixes). La app envía `from` y `to` en formato `YYYY-MM-DD`; sin manipulación de hora.
- **APK release sin firma de producción**: el build sin firma genera un APK de debug-signed (válido para sideload por adb, no para Play Store). El sprint de publicación a Play Store es spec aparte; este MVP entrega APK debug-signed instalable. Documentado en supuestos.
- **Costo de mantener tres frontends conceptualmente** (backend + Vue + Flutter): aumenta complejidad del `CLAUDE.md`. Mitigación: sección Flutter clara y separada en `CLAUDE.md`, README específico en `mobile/`.

## Estrategia de pruebas

Ver `test-plan.md` para detalle. Resumen:

- **Capa API**: tests unitarios de cada cliente HTTP usando `mocktail` para simular `dio.Response`. Verificar serialización/deserialización, headers Bearer correctos, manejo de errores HTTP por status code.
- **Capa Widget**: tests de pantallas críticas usando `flutter_test` y un harness `testApp(database: null, apiClient: mockClient)` que monta la app con un cliente mock. Verificar navegación, render condicional, manejo de submit.
- **Smoke manual**: instalar APK en Android del usuario, completar login → dashboard → CRUD básico → logout.
- **Cobertura mínima**: ≥10 tests en verde, `flutter analyze` sin errores, manifest validado.

## Estrategia de rollback

Como es un cliente nuevo independiente:
- **Rollback de código**: `git revert` del commit del sprint. Sin efectos en backend o frontend (ambos intactos).
- **Rollback de uso**: si la app Flutter resulta inestable, el usuario sigue usando la Vue web desde laptop o desde el browser del celular vía Tailscale. Cero pérdida de datos (todo vive en el backend).
- **Rollback de Play Store**: no aplica en este sprint (no se publica).

## Orden sugerido de implementación

Fases secuenciales (cada una habilita la siguiente):

1. **Fundación** (T001-T009): crear proyecto Flutter, applicationId, versionado, validación FINCORE_API_URL, dependencias en `pubspec.yaml`, lint config.
2. **Core técnico** (T010-T019): tema (colors + ThemeData), category catalog, constants (kinds, account_types), api client (dio + interceptores), token storage, modelos JSON, navegación (go_router con redirect).
3. **Auth** (T020-T027): Login, Verify Email (incluyendo botón Reenviar con cooldown).
4. **Dashboard** (T028-T031): pantalla principal con state.
5. **Cuentas** (T032-T039): lista + form (debit y credit) + delete con confirmación.
6. **Categorías** (T040-T045): lista + form (picker color/icon) + archivar.
7. **Movimientos** (T046-T059): lista paginada + filtros + form por kind + edit + cancel.
8. **Settings** (T060-T062): logout + URL + versión.
9. **Tests** (T063-T076): cobertura mínima por capa.
10. **Build release + Docs** (T077-T082): manifest validado, APK release, smoke real, README, CLAUDE.md.

Dentro de cada fase, muchas tareas son paralelizables — anotado por tarea en `tasks.md`.

## Casos borde que condicionan la solución

- **FINCORE_API_URL no definido en build**: `main()` debe abortar con `assert(apiUrl.isNotEmpty, 'FINCORE_API_URL no definido. Usa --dart-define=FINCORE_API_URL=https://...')` para evitar runs silenciosos contra localhost o nada.
- **Token expirado en pleno uso**: cualquier endpoint que devuelva 401 dispara el interceptor que limpia storage y navega a Login. El formulario en pantalla pierde su estado — aceptado en spec.
- **Cuenta no verificada**: 403 con texto del middleware verified. Interceptor distingue 403-verified (navega a Verify Email) de 403-otro (snackbar).
- **Tailscale apagado en el celular**: primera request da `DioException` con `type: connectionError`. Mostrar snackbar "No se pudo conectar al servidor — verifica tu conexión".
- **Latencia alta** (Tailscale relay 200-500 ms): cada operación de mutación deshabilita el botón "Guardar" hasta que vuelve la respuesta. Loader visible.
- **Doble tap rápido en "Guardar"**: usar un `bool _saving` en `State` que el botón consulta; cualquier tap mientras `_saving` lo ignora.
- **Cancelar entry ya cancelado** (concurrencia entre Flutter y Vue web): backend responde 404 al `DELETE` (porque `JournalEntry` usa SoftDeletes y el record con `deleted_at != null` no se encuentra por scope). La app trata 404 en cancel como "ya estaba cancelado" y refresca la lista.
- **Editar entry con cuenta archivada en el medio**: backend responde 422 `invalid_account_type` o similar. App muestra el mensaje del backend.
- **Filtro de fecha** `to`: el backend aplica `<= to 23:59:59`. La app envía solo `YYYY-MM-DD`; no se preocupa por la hora.
- **Categoría con `applies_to = income` seleccionada en form de gasto**: la app filtra el picker para no mostrarla; si por algún motivo el id viaja igual (deep link, etc.), backend rechaza con 422 `invalid_category_applies_to`.
- **Movimiento con fecha futura**: backend acepta; la app no bloquea. El usuario puede planear un cargo prospectivo si quiere.
- **Categoría color/icon slug fuera de catálogo**: si el backend en alguna versión futura agrega un slug nuevo y la app está atrasada, render del badge debe fallar elegantemente (color gris fallback + ícono genérico). Catálogo de Flutter es una constante, no descargada del backend; documentar.
- **Lista vacía** (sin cuentas / sin categorías / sin movimientos): empty state con CTA al botón crear.
- **Texto largo** (descripciones de 200+ caracteres): `Text` con `maxLines: 2 + overflow: ellipsis` en listas; expandido en detalle.
- **Emoji y caracteres UTF-8** en descripciones: serialización JSON las maneja por default; verificar render con un test que pase un emoji.
- **Token guardado pero usuario ya no existe / fue eliminado**: `GET /api/auth/me` al arrancar devolverá 401; interceptor limpia y va a Login.
- **Logout sin red**: la app limpia el token local incondicionalmente; el POST `/api/auth/logout` que falla silenciosamente no impide el logout local.

## Preguntas o supuestos que siguen afectando la implementación

Todas las preguntas de la spec (P-001..P-005) están cerradas. Los supuestos S-001..S-014 quedan vigentes. Posibles tensiones técnicas que pueden aparecer durante la implementación:

- **Si `flutter_secure_storage` no funciona en Linux desktop** (hubo issues en el pasado con backends de keystore), usar un fallback a `shared_preferences` para Linux desktop solo, manteniendo `flutter_secure_storage` en Android. Esto debería resolverse silenciosamente; documentar si aparece.
- **Si `go_router` 14+ exige SDK 3.32+**: anclar a `go_router: ^13.x` que sí soporta Flutter 3.29. Si causa fricción mayor, evaluar upgrade del SDK como tarea explícita aparte.
- **Si oklch → sRGB da diferencias perceptibles**: ajustar manualmente los 21 colores en `fincore_colors.dart` hasta que Diego confirme similitud.
- **Si el smoke real en celular falla por Tailscale**: el plan asume Tailscale activo. Si hay problemas (DNS, propagación), volver a la guía de `docs/deploy-tailscale.md`.

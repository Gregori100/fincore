# FinCore Flutter: cliente Android MVP (online-only)

## Resumen

Segundo cliente del rumbo cloud-first multi-cliente: app Flutter para Android (target principal, futuro Play Store) y Linux desktop (target secundario de desarrollo) que consume el API Laravel existente. **No es una app local-first** — la fuente única de verdad sigue siendo el backend; la app es una UI nativa que llama HTTP. La Vue web queda congelada en paridad actual y sigue accesible desde laptop para reportes/Excel/Plan/Forecast; el MVP Flutter cubre el subset básico (CRUD de cuentas, categorías y movimientos + dashboard) que el usuario opera desde el celular en el momento real del gasto. Cliente online-only: si no hay red al backend, la app muestra errores claros.

## Problema a resolver

El acceso a FinCore desde el celular vía browser (logrado en el sprint `deploy-tailscale`) resuelve la disponibilidad pero no la experiencia: barra del browser visible, sin ícono propio, gestures genéricos del SPA, foco táctil pensado para escritorio. El momento real de captura (subir al taxi, salir del supermercado) exige una app que se sienta nativa: abre con un tap, formularios pulidos para una mano, sin elementos de navegador. Por otro lado, el alcance completo de FinCore (7 reportes, Excel, Plan engine, Forecast) no es lo que se usa en ese momento — eso se mira sentado en laptop. El MVP separa los dos contextos: Flutter para captura rápida en celular; Vue web para revisión profunda en laptop.

## Objetivo

- Instalar APK release en el Android del usuario y registrar un movimiento desde la app en < 10 segundos desde el ícono del home.
- Conexión exclusiva vía API HTTP al backend Laravel; sin estado local persistente más allá del token de sesión.
- Base lista para Play Store (`applicationId` definitivo desde el día uno, versionado disciplinado, sin permisos innecesarios).
- URL del backend configurable: hoy `https://loma-latitude-3540.tail285790.ts.net` (vía Tailscale), mañana un dominio real cuando se migre a hosting.

## Alcance

Estructura del repo:

- Carpeta nueva del proyecto Flutter dentro del monorepo (nombre exacto a confirmar en P-003: `mobile/`, `app/` o `flutter/`). El `backend/` y `frontend/` continúan intactos. `engineering/` sigue gobernando el proceso. No hay rama `legacy/web` ni similar — la Vue queda viva en `main`.
- README del proyecto Flutter (qué es, comandos de desarrollo, build APK, cómo cambiar URL del API).
- `CLAUDE.md` del monorepo actualizado con sección Flutter (estructura, comandos, decisiones clave) en paralelo a las secciones Backend y Frontend existentes.

Fundación técnica:

- Proyecto Flutter inicializado con Flutter 3.29.3 (SDK instalado en `~/development/flutter`).
- `applicationId` definitivo (P-001) en `android/app/build.gradle`; nombre visible "FinCore".
- Targets: Android (release APK instalable) y Linux desktop (desarrollo). Sin iOS, sin Web, sin macOS, sin Windows.
- Resolución del warning de toolchain Android del `flutter doctor` como parte del setup, replicando lo aprendido en dogear.
- HTTP client: `dio` (interceptores limpios para inyectar `Authorization: Bearer ...` y manejar 401 globales).
- Storage seguro del token: `flutter_secure_storage`.
- Tema único oscuro Material 3 con paleta coherente con la Vue web actual.

Funcionalidad (MVP básico):

- **Auth**: pantalla Login (email + password) → `POST /api/auth/login` → token persistido y dashboard. Logout (`POST /api/auth/logout` + limpiar token + volver a Login). Auto-login si hay token válido al arrancar.
- **Email verification**: cuando el backend responde 403 por cuenta no verificada al consumir un endpoint protegido (`/api/finance/*` o `/api/auth/me`), la app muestra pantalla "Verifica tu email" con botón "Reenviar correo" que llama `POST /api/auth/email/verification-notification`. Tras verificar desde el email (deep link va a la Vue web), un botón "Ya verifiqué" reintenta y entra al dashboard.
- **Dashboard**: `GET /api/finance/state` → BO/DE/CR + lista de cuentas activas con saldo + últimos movimientos. Pull-to-refresh.
- **Cuentas**: lista con saldo derivado, crear/editar/eliminar (`debit` y `credit`; `cash` es la Bolsa singleton — solo se ve, no se crea ni elimina). Formulario de credit acepta `credit_limit`, `closing_day`, `payment_day`, `interest_rate`, `minimum_payment_pct`.
- **Categorías**: lista con badge color + ícono, crear/editar/archivar con catálogo curado (`color_slug` e `icon_slug` con los mismos slugs que el backend define en `CategoryDefaults`).
- **Movimientos**: lista paginada con filtros (`kind`, `account_id`, rango de fechas). Crear movimiento por kind (`income`, `expense`, `credit_expense`, `debt_payment`, `transfer`) con formulario contextual. Editar (`PATCH /api/finance/entries/{id}`) y cancelar (`DELETE /api/finance/entries/{id}`) con confirmación.
- **Settings mínimo**: botón Logout y mostrar la URL del API activa. Cambiar URL en runtime queda como funcionalidad futura (decisión P-002 cerrada: solo compile time en MVP).

Calidad:

- Suite de tests con `flutter_test`: data layer (clientes HTTP mockeados) y widget tests de los flujos críticos (login, registrar movimiento, editar, cancelar, manejar 401).
- `flutter analyze` sin errores.
- Smoke en Linux desktop y APK instalado en el Android del usuario (verificación manual).
- Manifest Android sin permisos extra (solo INTERNET, que sí es necesario).
- Versionado disciplinado: `versionCode` y `versionName` desde el inicio (preparación Play Store futura).

## Fuera de alcance

- 7 reportes (`by-category`, `cashflow-monthly`, `month-comparison`, `credit-cards`, `budgets`, `by-account`, `forecast`): siguen disponibles en la Vue web. Eventual paridad es spec posterior.
- Excel export de reportes: idem.
- Plan engine completo (eventos planeados, overrides, proyección 6 meses con gráfica).
- Settings con `hard reset`, `backup export/import` (existen como endpoints; UI en Flutter es funcionalidad futura).
- Registro de nuevos usuarios desde la app y forgot/reset password. Solo el usuario actual (Diego) usa la app; si necesita registrar otra cuenta o reset usa la Vue web. (El flow de verify email SÍ está dentro de alcance — decisión P-005.)
- iOS, web como target, modo oscuro/claro alternable (tema único oscuro), notificaciones push, widgets de home screen, integraciones con sistema (share sheet, etc.).
- Publicación efectiva en Play Store (firma de producción, AAB, closed testing). Spec aparte; este MVP entrega APK directo.
- Migración o sincronización de datos: la app conecta al backend existente; no hay datos a migrar.
- Modo offline o cache local: sin red al backend, se ven errores. Es decisión explícita del rumbo cloud-first.

## Reglas de negocio

- RN-001: cliente **online-only**. Sin SQLite local, sin sync engine, sin queue de mutaciones offline. Si no hay red al backend, la app muestra errores claros y ofrece reintentar.
- RN-002: la app **no duplica reglas de dominio** del backend. Las validaciones de tipo de cuenta, límites, integridad de FK, soft delete, etc. viven en Laravel. La app envía la solicitud y reacciona al resultado.
- RN-003: **"libreta libre"** — la app no bloquea gastos que dejen saldo negativo ni cargos que excedan el `credit_limit`. Solo el backend valida `OverpayDebt` al pagar a tarjeta; ese 422 con `code: overpay_debt` se muestra como mensaje al usuario.
- RN-004: **auth con bearer token** (Sanctum). Header `Authorization: Bearer <token>` en todas las requests a `/api/finance/*` y `/api/auth/me`/`logout`. Token guardado en `flutter_secure_storage`. Sin token o 401 → logout silencioso + redirect a Login.
- RN-005: el modelo de dominio que muestra la app coincide al pie de la letra con la Vue web:
  - Tipos de cuenta: `cash` (Bolsa singleton, solo lectura), `debit`, `credit`.
  - Kinds de movimiento: `income`, `expense`, `credit_expense`, `debt_payment`, `transfer` (no se expone `adjustment`, no está implementado).
  - Categorías: `applies_to` ∈ `income | expense | both`; `color_slug` e `icon_slug` del catálogo curado de `CategoryDefaults`.
- RN-006: UI y textos en **español**. Tema único oscuro coherente con la paleta de la Vue web.
- RN-007: **sin permisos de Android salvo INTERNET**. Sin acceso a contactos, ubicación, cámara, almacenamiento amplio, etc.
- RN-008: **versionado desde el día uno** con disciplina (`versionCode` incremental, `versionName` semver) preparando Play Store futura sin tener que reorganizar.
- RN-009: la app trata los IDs (cuentas, categorías, movimientos) como **strings opacos** (son UUID v7 generados por el backend). No parsea ni asume formato.
- RN-010: doble tap rápido en cualquier botón de "guardar" no debe enviar dos requests (mutex local de UI).

## Requisitos funcionales

- RF-001: proyecto Flutter creado en carpeta nueva del monorepo (nombre exacto en P-003) con targets Android + Linux habilitados; `flutter doctor` sin issues bloqueantes para esos targets.
- RF-002: `applicationId` definitivo en `android/app/build.gradle.kts` (P-001). Nombre visible "FinCore". `versionCode = 1`, `versionName = "0.1.0"`.
- RF-003: URL del API configurable vía `--dart-define=FINCORE_API_URL=https://...` en compile time. La app lee ese valor; sin él, falla el build con mensaje claro (no usar un default que apunte a localhost o un host viejo, eso oculta errores). El comando de build se documenta en README.
- RF-004: pantalla Login con email + password. Submit → `POST /api/auth/login` → guardar token + navegar a Dashboard. Errores 422 muestran el mensaje del backend (credenciales inválidas, throttle).
- RF-005: pantalla Dashboard: `GET /api/finance/state` con header bearer. Renderiza BO/DE/CR (tres totales), lista de cuentas activas con saldo, y los últimos N movimientos (mismo subset que la Vue). Pull-to-refresh recarga el state.
- RF-006: pantalla Cuentas — listado con saldo (calculado por el backend), `+` para crear, tap → editar/eliminar. Formularios:
  - **Debit**: nombre + descripción opcional.
  - **Credit**: nombre + descripción + `credit_limit` + `closing_day` (1-31) + `payment_day` (1-31, distinto al closing_day) + `interest_rate` opcional + `minimum_payment_pct` opcional.
  - **Cash (Bolsa)**: solo lectura; el formulario muestra mensaje "es tu Bolsa, no editable".
- RF-007: pantalla Categorías — listado con badge de color e ícono. `+` para crear; tap → editar/archivar. Formulario: nombre + `applies_to` (selector entre income, expense, both) + color picker (catálogo de 10 colores curados) + icon picker (catálogo ~30 íconos curados). Archivar (soft delete) con confirmación.
- RF-008: pantalla Movimientos — lista paginada (`GET /api/finance/entries`) con filtros: `kind`, `account_id`, rango de fecha (`from`/`to`). Tap → editar; long-press o menú → cancelar.
- RF-009: crear movimiento por kind. Formulario contextual:
  - **Income**: account_destination (debit o cash) + amount + descripción + occurred_at + categoría opcional (solo categorías `applies_to ∈ income | both`).
  - **Expense**: account_origin (debit o cash) + amount + descripción + occurred_at + categoría opcional (solo `expense | both`).
  - **Credit expense**: account_origin (credit) + amount + descripción + occurred_at + categoría opcional (solo `expense | both`).
  - **Debt payment**: account_origin (debit o cash) + account_destination (credit) + amount + descripción + occurred_at. Sin categoría.
  - **Transfer**: account_origin (debit o cash) + account_destination (debit o cash) + amount + descripción + occurred_at. Sin categoría.
  - Selector de cuenta filtra por tipo según el kind. Selector de categoría filtra por `applies_to`.
- RF-010: editar movimiento — `PATCH /api/finance/entries/{id}` con campos editables: `category_id`, `description`, `occurred_at`, `account_origin_id`, `account_destination_id`, `amount`. El `kind` es inmutable (lo respeta el backend; la UI lo muestra solo lectura). Cuentas nuevas respetan el tipo según el kind.
- RF-011: cancelar movimiento — `DELETE /api/finance/entries/{id}` con confirmación. Cancelar es terminal (no hay reactivación). Movimiento cancelado desaparece de la lista.
- RF-012: Settings mínimo: botón Logout (`POST /api/auth/logout` + limpiar token + volver a Login). Muestra la URL del API actual y la versión de la app (versionCode + versionName).
- RF-013: manejo global de errores HTTP:
  - **401**: limpiar token, navegar a Login, mostrar mensaje "Sesión expirada".
  - **422**: mostrar errores de validación del backend (campo + mensaje) o el `error` del DomainException si viene.
  - **5xx / network error / timeout**: snackbar "No se pudo conectar al servidor" con botón "Reintentar"; el formulario conserva los datos.
- RF-014: suite de tests Flutter con cobertura mínima:
  - Login: éxito + credenciales inválidas + throttle (429).
  - Registro de un movimiento de cada kind (income, expense, credit_expense, debt_payment, transfer).
  - Edición de un movimiento existente.
  - Cancelación de un movimiento.
  - Manejo de 401 (token expirado) → redirect a Login.
  - Manejo de 422 (validación) → mensajes visibles.
  - Total ≥ 10 tests verdes.
- RF-015: artefacto release: `flutter build apk --release --dart-define=FINCORE_API_URL=https://...` produce APK instalable. README documenta exactamente cómo ejecutarlo.
- RF-016: documentación:
  - README en la carpeta Flutter: qué es, cómo correr en Linux desktop (`flutter run -d linux --dart-define=FINCORE_API_URL=...`), cómo construir APK release, cómo instalar en Android vía adb.
  - `CLAUDE.md` raíz actualizado con sección Flutter siguiendo el formato de las secciones Backend y Frontend existentes.
- RF-017: pantalla "Verifica tu email" para flujo de cuentas no verificadas. Se activa cuando un endpoint protegido responde 403 con código de "no verificado" (middleware `verified` de Laravel). Contiene: texto explicativo, email del usuario, botón "Reenviar correo" → `POST /api/auth/email/verification-notification` (sujeto al throttle `6,1` del backend; mostrar mensaje en 429), y botón "Ya verifiqué" que reintenta `GET /api/auth/me` y entra al dashboard si pasa. El click del enlace en el email se abre con la Vue web (`GET /auth/email/verify/{id}/{hash}` ya existe y redirige a `FRONTEND_URL`), Flutter no maneja deep links de verify en este MVP.
- RF-018: tema visual replica la paleta exacta de la Vue web. Mapeo manual de las CSS variables del `@theme` block de `frontend/src/style.css` a un `ColorScheme.dark` custom de Material 3. Los colores curados del catálogo (`CategoryColors` con 10 slugs) se exponen en una constante Dart paralela a `frontend/src/constants/categoryCatalog.js` para que los badges de categoría se vean idénticos entre clientes.

## Casos principales

- Abrir app por primera vez → Login → ingresar credenciales → dashboard con BO/DE/CR + cuentas + últimos movimientos.
- Abrir app habiendo login previo (token válido) → directo a dashboard, sin re-login.
- Token expirado o revocado por logout-all desde la Vue web → primer 401 → logout silencioso → Login con mensaje "Sesión expirada".
- Captura típica del día: home → tocar ícono FinCore → dashboard → "+" → "Gasto" → seleccionar cuenta + monto + categoría + descripción → guardar → vuelve al dashboard con saldo actualizado.
- Pagar tarjeta: "+" → "Pago de tarjeta" → origen (cash o debit) + destino (credit) + monto → guardar. Si excede la deuda, backend devuelve 422 `overpay_debt` → mostrar mensaje.
- Editar un movimiento ingresado en mal momento: lista → tap → cambiar monto/descripción/fecha → guardar.
- Migración futura de hosting: el usuario rebuildea con `--dart-define=FINCORE_API_URL=https://nuevo.host.com`; la app conecta al nuevo backend sin cambios de UI ni código.

## Casos borde

- Backend caído / Tailscale desactivado en el celular → cada request termina en network error → snackbar "no se pudo conectar". El formulario no pierde los datos.
- Latencia alta del API (Tailscale relay puede agregar 200-500 ms) → loaders visibles en cada operación; botón "guardar" deshabilitado en flight.
- Doble tap en "guardar" → mutex local impide envío duplicado.
- Caracteres especiales y emoji en descripciones (UTF-8 completo, igual que la web).
- Cancelar un movimiento ya cancelado (race condition entre dos devices) → backend responde 404; la app muestra "ya estaba cancelado" y refresca la lista.
- Editar movimiento con cuenta archivada en el medio → backend responde 422; la app muestra el mensaje y refresca cuentas.
- Backend en mantenimiento (503) → mensaje "El servidor no está disponible. Reintenta en unos minutos.".
- Rotación de pantalla / proceso matado por Android a media edición → lo guardado persiste (está en el backend); lo no guardado en el formulario se pierde sin corromper datos.
- Cuenta de credit cuyo `closing_day == payment_day` → backend rechaza con 422 `invalid_credit_metadata`; la app muestra el mensaje.
- Movimiento con fecha futura → permitido por el backend; la app no lo bloquea.
- Categoría con `applies_to = income` seleccionada en un formulario de gasto → no aparece en el picker (filtro de UI).

## Criterios de aceptacion

- En un Android real con Tailscale activo: instalar el APK release, completar login → dashboard → crear gasto → editar → cancelar → logout. Cero fricción.
- `git status` de la rama del sprint no contiene cambios en `backend/` ni en `frontend/` (Vue queda intacta; el backend no necesitó endpoints nuevos).
- `flutter test` en verde con ≥10 tests; `flutter analyze` sin errores.
- `flutter build apk --release --dart-define=FINCORE_API_URL=https://...` produce APK instalable sin warnings críticos.
- Manifest de Android declara permiso `android.permission.INTERNET` y ningún otro.
- Mismo backend que la Vue web: un movimiento creado desde Flutter aparece en la Vue web tras refresh, y viceversa.
- 401 simulado (modificando el token guardado a inválido) fuerza la pantalla de Login con el mensaje "Sesión expirada".
- 422 `overpay_debt` (intentar pagar más de lo que se debe a una tarjeta) muestra el mensaje del backend al usuario.

## Criterios medibles de exito

- Arranque frío (ícono del home → dashboard interactivo) < 4 s en el dispositivo del usuario, incluyendo round-trip a `/finance/state` por Tailscale.
- 0 permisos Android más allá de INTERNET.
- ≥ 10 tests en verde (mix de data + widgets).
- APK release < 30 MB.
- 100% de los flujos del MVP (login, dashboard, CRUD cuentas, CRUD categorías, CRUD movimientos, logout) operables desde la app sin recurrir a la Vue web.
- 0 endpoints nuevos en el backend para este MVP.

## Riesgos

- **Dependencia de Tailscale en el celular** mientras no hay hosting con tarjeta. Si el usuario apaga Tailscale por accidente o se sale del tailnet, la app no funciona. Mitigado: la app muestra error claro y el README documenta la dependencia. Cuando se migre a hosting real, desaparece.
- **URL del API hardcodeada en build time**: si en algún rebuild olvidás pasar `--dart-define`, el build falla (preferimos eso a que conecte a un host viejo). Riesgo de fricción al iterar; mitigado con un script `mobile/scripts/build-release.sh` que recuerde el comando.
- **Vue y Flutter divergen** en feature set: Vue conserva reportes/Excel/Plan/Forecast, Flutter solo CRUD básico. El usuario debe recordar que para esas funciones va a la Vue (laptop). Documentado; aceptado por decisión explícita del usuario.
- **Stack Dart/Flutter nuevo para el agente y el repo** — costo de revisión humana sube al inicio. Mitigado con el conocimiento ya validado en dogear (CLAUDE.md de dogear documenta las trampas: override de `libsqlite3.so.0` no aplica acá porque no hay drift, pero el patrón de testApp + cuidados con StreamBuilder/pumpAndSettle sí).
- **Flutter 3.29.3 instalado tiene ~14 meses**: alguna dependencia moderna puede exigir upgrade del SDK. Si bloquea, se hace como tarea explícita en plan, no silenciosa.
- **Warning de toolchain Android** (`flutter doctor`): puede ocultar fricción al primer `flutter build apk`. Mitigado: replicar la resolución que ya quedó documentada en dogear; si bloquea Android, el desarrollo continúa en Linux desktop mientras se destraba.
- **`applicationId` irreversible en Play Store**: una vez publicado, no se puede cambiar. Mitigado por P-001 antes de planear.
- **Verificación final en dispositivo es manual del usuario** (instalar APK por adb). El emulador del SDK mitiga parcialmente en desarrollo.
- **Coexistencia de tres frontends** (backend + frontend Vue + nueva carpeta Flutter) en el monorepo: aumenta complejidad del CLAUDE.md y del onboarding de cualquier otro agente. Mitigado documentando el rol de cada uno.

## Supuestos

- S-001: `applicationId = io.github.gregori100.fincore`, mismo patrón que dogear. Decisión P-001 cerrada. Inmutable una vez publicado.
- S-002: URL del API se configura solo en compile time (`--dart-define=FINCORE_API_URL=...`). Decisión P-002 cerrada. Pantalla Settings runtime para cambiarla es funcionalidad futura (spec aparte).
- S-003: la carpeta del proyecto Flutter dentro del monorepo se llama `mobile/`. Decisión P-003 cerrada.
- S-004: tema único oscuro Material 3 que replica la paleta exacta de la Vue web. Decisión P-004 cerrada. Mapeo manual de CSS variables del `@theme` block de `frontend/src/style.css` a un `ColorScheme.dark` custom; los 10 slugs de color del catálogo `CategoryColors` se exponen como constantes Dart paralelas a `frontend/src/constants/categoryCatalog.js`. Acepta el costo extra (~medio día) sobre `ColorScheme.fromSeed`.
- S-005: el flow de email verification SÍ se construye en este MVP. Decisión P-005 cerrada. Cuando un endpoint protegido responde 403 por cuenta no verificada, la app muestra la pantalla del RF-017 con botón Reenviar correo. El click del enlace del email abre la Vue web (flow ya existente del backend); Flutter no maneja deep links del verify en este MVP.
- S-006: HTTP client = `dio` (mejor manejo de interceptores que `http`).
- S-007: storage seguro del token = `flutter_secure_storage`.
- S-008: navegación = `go_router` (más declarativo y soportado oficialmente que Navigator 2.0 puro).
- S-009: tests con `flutter_test` + `mocktail` para mockear el cliente HTTP.
- S-010: backend Laravel NO requiere cambios. Endpoints `/api/auth/*` y `/api/finance/*` ya existen.
- S-011: CORS no aplica al cliente nativo de Flutter (no es browser); cero ajustes en `config/cors.php`.
- S-012: el `versionCode = 1` y `versionName = "0.1.0"` inicial, con disciplina de incrementarlos en cada release. La automatización viene en spec posterior.
- S-013: backend acepta los formatos de fecha que enviará Flutter (ISO 8601 con timezone). Verificación trivial al implementar.
- S-014: el usuario instalará la app vía `adb install` (no Play Store en este MVP). El Redmi Note 13 del usuario requiere activar "Instalar vía USB" además de depuración (mismo gotcha aprendido en dogear).

## Impacto esperado

- Producto: FinCore vivirá como app con ícono propio en el Android del usuario, con experiencia táctil pulida para captura rápida. La Vue web sigue siendo la herramienta para análisis profundo.
- Repo: nueva carpeta Flutter en paralelo a `backend/` y `frontend/`. `CLAUDE.md` se actualiza con la nueva sección. `engineering/` sigue con su flujo de specs.
- Backend: sin cambios. Cero endpoints nuevos, cero migraciones, cero ajustes.
- Vue: sin cambios. Queda en su estado actual con sus 7 reportes, Excel, Plan engine, Forecast — todo funcional cuando se accede vía Tailscale desde laptop.
- Roadmap posterior natural:
  - Spec aparte: paridad de reportes en Flutter (cuando se justifique por uso real).
  - Spec aparte: Settings runtime con cambio de URL del API.
  - Spec aparte: hosting real con tarjeta (Fly.io / VPS) — sin Tailscale obligatorio.
  - Spec aparte: publicación en Play Store (firma, AAB, closed testing).
  - Eventual: backup/restore desde Flutter, plan engine, modo oscuro/claro alternable, notificaciones push.

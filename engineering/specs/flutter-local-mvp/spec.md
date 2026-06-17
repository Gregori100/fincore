# FinCore Flutter local-first: MVP single-user

## Resumen

Pivote del producto FinCore desde cliente Flutter online-only sobre backend Laravel (vía Tailscale) a app **Flutter local-first** estilo Obsidian: abre instantáneo, funciona 100% offline, sin login, sin servidor, con los datos en SQLite dentro del celular. Single-user (Diego, el único usuario). Mismo modelo que el usuario ya validó en su proyecto dogear. El MVP entrega control real sobre cuentas + Bolsa + categorías + movimientos + dashboard de saldos, más **export/import de respaldo JSON desde el día uno** para no perder datos por pérdida del dispositivo. El backend Laravel, el frontend Vue y el cliente Flutter online que existían quedan congelados en la rama `legacy/web-and-online-flutter`; `main` queda limpio con sólo el proyecto Flutter local-first en `mobile/`. **Diego decidió el 2026-06-17 que prefiere arrancar de cero** sin migrar los datos del backend legacy: la pantalla "Primer arranque" mantiene ambos botones (Importar respaldo / Arrancar limpio) por resiliencia futura, pero el flujo principal del lanzamiento es "Arrancar limpio".

## Problema a resolver

El cliente Flutter online-only construido durante junio 2026 (mismo `mobile/` actual) demostró ser inutilizable en el momento real de captura: dependía de la laptop del usuario encendida con backend Docker corriendo, Tailscale activo, cert TLS válido y propagación DNS. Cuando Diego intentó usarlo fuera de casa, los errores de conexión arruinaron la experiencia. El momento real de registrar un gasto es mientras se va caminando, en el subte, en una tienda — con el celular en la mano y a veces sin internet estable. La arquitectura cloud-first añadía fricción y costos operativos sin aportar valor para un solo usuario. La decisión explícita del usuario, tomada el 2026-06-12, es el modelo Obsidian: local puro, sin red en runtime, backup como única red de seguridad. El API y la sincronización se evalúan al final como spec separada, no en este sprint.

## Objetivo

- Abrir la app y estar capturando un movimiento en segundos, sin red, sin login, sin laptop encendida.
- Toda la funcionalidad de control diario (cuentas + Bolsa + categorías + movimientos + saldos derivados BO/DE/CR) disponible offline.
- Arrancar limpio: la app crea automáticamente la Bolsa singleton + 10 categorías default tras la confirmación del primer arranque. Diego empieza a usar la app sin pasos previos de migración.
- Datos a salvo de la pérdida del celular vía respaldo exportable/importable JSON, disponible desde el día uno. El mismo formato JSON v1 puede usarse para restaurar respaldos posteriores que Diego genere desde Settings.
- Base técnica preparada para Play Store (`applicationId` definitivo, versionado disciplinado, migraciones de schema entre versiones) y para un sync futuro de bajo costo (UUIDs v7 + timestamps + soft delete en todo el schema).

## Alcance

Estructura del repo:

- Crear rama `legacy/web-and-online-flutter` desde el `main` actual, conservando intactos `backend/`, `frontend/`, el `mobile/` online y toda la trazabilidad de `engineering/specs/` previa.
- En `main`: retirar `backend/`, `frontend/`, `compose.yaml`, `compose.tailscale.yml`, `Dockerfile`, `db/`, `docker/`, `scripts/` (CLI fincore + install.sh), `tests-e2e/`, `docs/` (api, cli, frontend, scripts, deploy), `fly.toml` y todo el `mobile/` actual online. Conservar `engineering/` con sus specs históricas (incluyendo `flutter-mvp-cliente/` que documenta el cliente online ahora desechado) y `README.md` raíz reescrito para la nueva era.
- Reconstruir `mobile/` como proyecto Flutter local-first nuevo aprovechando lo reutilizable del anterior (tema, catálogo, enums, widgets, pantallas con cambios mínimos). El proyecto vive directamente en `mobile/`, no en la raíz.
- `engineering/` continúa con el flujo de specs habitual; este sprint vive en `engineering/specs/flutter-local-mvp/`.

Fundación técnica:

- Proyecto Flutter 3.29.3 con `applicationId = io.github.gregori100.fincore` (sin cambios respecto al anterior; inmutable post-Play Store).
- Persistencia con **drift** sobre SQLite local: `schemaVersion = 1`, `MigrationStrategy.onUpgrade` para futuro, `PRAGMA foreign_keys = ON` en `beforeOpen`, fechas como TEXT ISO-8601 vía `build.yaml` (`store_date_time_values_as_text: true`) — sin esta opción drift trunca subsegundos y rompe el orden y el round-trip de backup, igual que aprendido en dogear.
- Codegen drift con `build_runner` (estándar de facto, dogear lo usa).
- Stack de runtime: streams de drift + StreamBuilder + StatefulWidget. Sin gestor de estado externo. Patrón aprendido en dogear: cachear streams en el `State`, recrear solo al cambiar filtros — no crear en `build()`.
- Navegación con `go_router` (ya estaba en el `mobile/` actual).
- Tests con `flutter_test` + `mocktail`; data layer con drift en memoria; widget tests con helper `testApp` que monta la app con BD en memoria y drena el Timer interno de drift en `tearDown` (sin esto `testWidgets` revienta con "Timer is still pending").

Modelo de dominio (schema drift v1):

- **`accounts`**: `id` (UUID v7 TEXT PK), `name` (TEXT), `type` (TEXT: `cash | debit | credit`), `description` (TEXT NULL ≤ 200), `is_protected` (BOOL), `credit_limit` (REAL NULL), `closing_day` (INTEGER NULL 1-31), `payment_day` (INTEGER NULL 1-31), `interest_rate` (REAL NULL), `minimum_payment_pct` (REAL NULL), `created_at` (TEXT ISO-8601), `updated_at` (TEXT ISO-8601), `deleted_at` (TEXT ISO-8601 NULL).
- **`categories`**: `id` (UUID v7 TEXT PK), `name` (TEXT), `applies_to` (TEXT: `income | expense | both`), `color_slug` (TEXT), `icon_slug` (TEXT), `monthly_limit` (REAL NULL — aceptado por el schema para compatibilidad con backup del backend; UI no lo expone en el MVP), `created_at`, `updated_at`, `deleted_at` (TEXT NULL).
- **`journal_entries`**: `id` (UUID v7 TEXT PK), `kind` (TEXT: `income | expense | credit_expense | debt_payment | transfer`), `account_origin_id` (TEXT NULL FK → accounts.id), `account_destination_id` (TEXT NULL FK → accounts.id), `amount` (REAL > 0), `description` (TEXT NULL), `occurred_at` (TEXT ISO-8601), `category_id` (TEXT NULL FK → categories.id), `created_at`, `updated_at`, `deleted_at` (TEXT NULL).

Funcionalidad (paridad funcional con el cliente Flutter online actual menos auth):

- **Primer arranque**: pantalla obligatoria si la BD está vacía (sin Bolsa). Dos botones grandes: "Arrancar limpio" (flujo principal — confirmación destructiva → crea Bolsa singleton + 10 categorías default) e "Importar respaldo" (file picker → valida JSON v1 → import transaccional). El mismo componente de import se reusa después desde Settings para restaurar respaldos posteriores.
- **Dashboard**: BO (Σ saldos cash + debit), DE (Σ deudas credit), CR (Σ `credit_limit − deuda`), lista de cuentas activas con saldo derivado, lista de últimos N movimientos. Pull-to-refresh recalcula vista. Sin loaders de red.
- **CRUD cuentas**: lista, crear/editar (`debit` o `credit` con metadata de credit), eliminar (sólo si `saldo derivado == 0`). Bolsa singleton (`cash`, `is_protected = true`) es read-only y no puede crearse ni eliminarse.
- **CRUD categorías**: lista con filtro por `applies_to`, crear/editar con color e ícono del catálogo curado (10 colores + 30 íconos, mismos slugs que el backend), archivar (soft delete). Las archivadas no aparecen en la UI pero conservan referencias históricas en los entries.
- **CRUD movimientos**: lista paginada con filtros (`kind`, `account_id`, rango de fecha). Crear movimiento por kind con formulario contextual (los 5 kinds: `income`, `expense`, `credit_expense`, `debt_payment`, `transfer`). Editar y cancelar (soft delete). "Libreta libre": el cliente no bloquea gastos que dejen saldo negativo ni cargos que excedan `credit_limit`; sólo bloquea `OverpayDebt` al pagar más de lo adeudado a una tarjeta.
- **Settings**: botón "Exportar respaldo" (genera JSON y abre share sheet de Android), botón "Importar respaldo" (selecciona archivo JSON, confirma reemplazo total destructivo, ejecuta import transaccional), versión visible, link a la rama legacy/web por si Diego quiere referenciar el backend antiguo.

Backup:

- **Formato JSON de backup version: 1** compatible con el producido por `/api/finance/backup/export` del backend legacy: contiene `accounts` (incluyendo la Bolsa), `categories`, `journal_entries` (sólo activos, sin soft-deleted), `exported_at`. Sin plan (no aplica en este MVP). Sin user_id (single-user).
- **Export**: serializa BD local activa a JSON v1 y abre share sheet del sistema con nombre `fincore-backup-YYYY-MM-DD.json`. La UI confirma destino antes.
- **Import**: parsea el JSON v1 completamente antes de tocar la BD; valida la versión; ejecuta dentro de una transacción que primero borra TODO (cuentas, categorías, journal_entries físicamente — single-user, no hay soft delete vs sync que respetar) y luego inserta lo importado preservando los UUIDs del export. Si algo falla a mitad, la transacción aborta y la BD queda intacta. Confirmación de UI obligatoria con texto destructivo.
- **Caso primer arranque**: la pantalla inicial detecta BD vacía y muestra los dos botones. Diego usará "Arrancar limpio" en el lanzamiento; "Importar respaldo" queda disponible para escenarios futuros (restaurar un export propio tras un wipe del celular o tras cambiar de dispositivo).

Calidad:

- Suite de tests con `flutter_test` cubriendo capa de datos (DAOs con drift en memoria), motor de saldos (`FinancialStateService` reimplementado en Dart), import/export round-trip, migración de schema v1, y widget tests de los flujos críticos (dashboard render con datos, crear movimiento por cada kind, editar, cancelar, importar backup).
- `flutter analyze` sin issues.
- APK release instalable directo en Android del usuario con `adb install`.

## Fuera de alcance

- **Cliente web Vue y backend Laravel**: quedan en rama `legacy/web-and-online-flutter` congelados, sin mantener. Si Diego necesita features que sólo están allá (reportes, Excel, Plan engine), hace checkout de la rama. No se mantiene paridad ni se mergea hacia atrás.
- **Auth, login, register, verify email, reset password**: eliminados completamente. Single-user implícito.
- **Sync API + cliente sync**: spec aparte cuando llegue el momento. Hoy diseñamos el schema y el formato de backup para que esa spec futura sea barata, pero no se construye nada.
- **7 reportes** (`by-category`, `cashflow-monthly`, `month-comparison`, `credit-cards`, `budgets`, `by-account`, `forecast`): se pierden en este sprint, inventariados en la memoria `features-lost-on-flutter-pivot` para evaluación futura.
- **Excel export**: idem.
- **Plan engine completo** (eventos planeados, overrides, proyección 6 meses, gráfica de evolución): idem.
- **Hard reset administrativo separado del import**: el import ya hace reemplazo total destructivo, suficiente como reset.
- **Settings administrativas avanzadas** (logout-all, password change, etc.): no aplican sin auth.
- **iOS, web, modo claro alternable** (queda tema único oscuro), notificaciones push, widgets de home screen, integraciones profundas con Android (share sheet sí, otros no).
- **Publicación en Play Store** (firma de producción, AAB, closed testing 12 testers, ficha de la tienda): spec aparte cuando el usuario decida publicar.
- **Auto-backup a Google Drive**: roadmap fase 2 (similar a dogear).
- **Sub-categorías, drag-and-drop de orden, múltiples bolsas**: descartados explícitamente en sprints anteriores y vigentes.

## Reglas de negocio

- RN-001: la app es **local-first puro**. Sin red en runtime para CRUD ni dashboard. Sin login ni sesión. La fuente única de verdad es la BD SQLite del dispositivo.
- RN-002: **single-user**. No hay `user_id` en ninguna tabla. La BD entera es del único usuario del dispositivo.
- RN-003: **"libreta libre"** del backend se mantiene: el cliente NO bloquea gastos que dejen saldo negativo, transferencias que dejen origen negativo, ni cargos a tarjeta que excedan `credit_limit`. ÚNICA validación bloqueante de creación: `OverpayDebt` al pagar más de la deuda actual de una tarjeta — el saldo a favor no tiene sentido para una libreta personal.
- RN-004: **Bolsa singleton**. Existe exactamente una cuenta tipo `cash` por instalación con `is_protected = true`. Se crea automáticamente al arrancar con BD limpia. No se puede crear otra, ni eliminar la existente, ni cambiar su `type`. Nombre default "Bolsa" (editable).
- RN-005: **schema con UUID v7 + timestamps + soft delete** en todo el modelo. Permite sync futuro barato. `created_at` se setea en INSERT; `updated_at` se actualiza en cada UPDATE/INSERT vía DAO; `deleted_at` reemplaza al DELETE físico para cuentas/categorías/movimientos.
- RN-006: **cancelar es terminal**. Un movimiento con `deleted_at != null` no se reactiva. La UI no muestra entries cancelados por default.
- RN-007: **archivar cuentas es terminal y exige saldo cero**. Sólo se puede archivar una cuenta si `saldo derivado == 0`. Una vez archivada (`deleted_at != null`) no se puede reactivar desde la UI ni editar. Mismo criterio que el backend.
- RN-008: **archivar categorías**: las categorías archivadas siguen referenciadas por los entries históricos (no se borra el `category_id`), pero la relación se trata como null en la UI (no muestra badge). Idem al comportamiento del backend.
- RN-009: **saldos derivados** siempre. La columna `accounts.balance` NO existe. Se calcula on-the-fly por SQL agregado: cash/debit = `Σ destination.amount − Σ origin.amount`; credit = `Σ origin.amount − Σ destination.amount` (deuda).
- RN-010: **BO/DE/CR**:
  - BO = Σ saldo(account) donde type ∈ (cash, debit).
  - DE = Σ saldo(account) donde type = credit (suma de deudas).
  - CR = Σ (credit_limit − saldo(account)) donde type = credit y credit_limit != null.
- RN-011: **kinds y combinaciones de cuentas**: idénticas al backend.
  - `income`: origin = null, destination ∈ (cash, debit). Acepta categoría con `applies_to ∈ (income, both)`.
  - `expense`: origin ∈ (cash, debit), destination = null. Acepta categoría con `applies_to ∈ (expense, both)`.
  - `credit_expense`: origin = credit, destination = null. Acepta categoría con `applies_to ∈ (expense, both)`.
  - `debt_payment`: origin ∈ (cash, debit), destination = credit. NO acepta categoría.
  - `transfer`: origin ∈ (cash, debit), destination ∈ (cash, debit), origin ≠ destination. NO acepta categoría.
- RN-012: **catálogo de colores e íconos**: 10 colores curados + ~30 íconos curados con slugs idénticos al backend (`CategoryDefaults.php`) y al cliente Flutter online actual (`category_catalog.dart`). Cambiar un slug implica actualizar el catálogo y migrar entries existentes — no se hace lightly.
- RN-013: **formato JSON de backup version: 1** idéntico al del backend legacy. Versión futura > 1 requerirá `MigrationStrategy.onUpgrade` del importador. Versión desconocida (más alta de lo que la app sabe leer) se rechaza con mensaje claro.
- RN-014: **UI y textos en español**. Tema único oscuro coherente con la paleta del cliente Flutter online actual (réplica de las CSS variables de Vue).
- RN-015: **sin permisos Android salvo `INTERNET`**, que se mantiene declarado para no romper al activar sync futuro pero no se usa en este MVP (la app funciona sin red).
- RN-016: **doble tap en cualquier botón de guardar** no envía dos veces. Mutex local en cada formulario.

## Requisitos funcionales

- RF-001: branch nueva `legacy/web-and-online-flutter` creada desde el commit actual de `main`, conservando todo el código (backend, frontend, mobile online, docker, etc.). Pusheada a `origin`.
- RF-002: `main` retira el código legacy y queda con: `mobile/` reconstruido + `engineering/` con specs históricas + `README.md` raíz nuevo + `CLAUDE.md` raíz reescrito + `.gitignore` raíz mínimo.
- RF-003: proyecto Flutter en `mobile/` con `applicationId io.github.gregori100.fincore`, nombre visible "FinCore", targets Android + Linux desktop (Linux para desarrollo; Android para uso real). `flutter doctor` sin issues bloqueantes.
- RF-004: schema drift v1 en `mobile/lib/data/database.dart`: tablas `accounts`, `categories`, `journal_entries` con las columnas listadas en Alcance. `schemaVersion = 1`. `MigrationStrategy.onUpgrade` con stub para versiones futuras. `beforeOpen` ejecuta `PRAGMA foreign_keys = ON`. `build.yaml` configura `store_date_time_values_as_text: true`. La migración inicial crea índices sobre `journal_entries(account_origin_id)`, `journal_entries(account_destination_id)` y `journal_entries(deleted_at)` para que las queries agregadas de saldos derivados corran en milisegundos (criterio < 10 ms total para BO/DE/CR + N cuentas). Generación de tipos vía `build_runner` (codegen drift estándar, ver S-005).
- RF-005: `mobile/lib/data/backup.dart`: serializador y deserializador JSON v1. Export reúne accounts/categories/journal_entries activos y produce JSON con `{ "version": 1, "exported_at": "...", "accounts": [...], "categories": [...], "journal_entries": [...] }`. Import parsea TODO antes de tocar BD, valida `version == 1`, ejecuta dentro de transacción: borra todo + inserta lo importado. Si versión > 1 o JSON inválido, rechaza con mensaje claro.
- RF-006: **pantalla "Primer arranque"** (`first_run_screen.dart`): se muestra cuando la BD no tiene Bolsa (detección al booteo en `bootstrap()`). Dos opciones grandes: "Importar respaldo" (file picker del sistema → valida JSON v1 → import transaccional) o "Arrancar limpio" (confirmación destructiva → crea Bolsa singleton + 10 categorías default). Tras cualquiera de las dos, navega a `/dashboard`. Decisión cerrada por P-001: la app NO embebe el JSON como asset; el usuario es quien envía el archivo al celular y lo selecciona desde la app la primera vez. El mismo componente de import se reusa en Settings para restaurar respaldos posteriores.
- RF-007: **Dashboard** (`dashboard_screen.dart`): muestra 3 tarjetas BO/DE/CR calculadas vía SQL agregado del motor de saldos, lista de cuentas activas con saldo coloreado, lista de últimos N movimientos. Pull-to-refresh recalcula vista. Vive como StreamBuilder sobre stream cacheado del `State`.
- RF-008: **CRUD cuentas**: lista (`accounts_list_screen.dart`), formulario crear/editar (`account_form_screen.dart`). Bolsa singleton es solo lectura (RN-004). Eliminar exige saldo cero (RN-007); UI muestra mensaje claro si no.
- RF-009: **CRUD categorías**: lista (`categories_list_screen.dart`) con chips de filtro por `applies_to`, formulario crear/editar (`category_form_screen.dart`) con color picker + icon picker del catálogo + preview live del badge. Archivar (soft delete) con confirmación que advierte que los movimientos existentes pierden el badge visual.
- RF-010: **CRUD movimientos**: lista (`entries_list_screen.dart`) paginada con filtros (kind, account, rango fecha) en bottom-sheet, formulario crear (`entry_form_screen.dart`) con KindPicker contextual y campos por kind, edición (kind inmutable), cancelar (soft delete con confirmación destructiva). Los 5 kinds funcionando idénticos al backend (RN-011).
- RF-011: motor de saldos derivados en `mobile/lib/data/financial_state.dart`: helpers `accountBalance(accountId)`, `bo()`, `de()`, `cr()` ejecutando SQL agregado contra `journal_entries` no canceladas y `accounts` no archivadas.
- RF-012: **Settings** (`settings_screen.dart`): botón "Exportar respaldo" → genera JSON + abre share sheet de Android, botón "Importar respaldo" → file picker + confirmación destructiva + ejecuta import, versión de la app visible (`kAppVersion`), link a la rama legacy/web como texto plano informativo.
- RF-013: catálogo de colores e íconos `mobile/lib/constants/category_catalog.dart` con los 10 slugs de color + 30 slugs de ícono idénticos al backend y al cliente Flutter online actual.
- RF-014: tema oscuro réplica del cliente Flutter online actual: `mobile/lib/theme/fincore_colors.dart` con las 21 constantes Color + `fincore_theme.dart` con ColorScheme.dark custom. 100% reutilizable del proyecto anterior.
- RF-015: enums `mobile/lib/constants/{kinds, account_types}.dart` con `JournalKind` y `AccountType` + helpers (`apiValue`, `label`, `acceptsCategory`, `validCategoryAppliesTo`, `canBeOrigin`, `canBeDestination`). 100% reutilizable.
- RF-016: router `mobile/lib/router/app_router.dart` con `go_router` arranca en `/first-run` si BD vacía, sino en `/dashboard`. Rutas: `/dashboard`, `/accounts`, `/accounts/new`, `/accounts/:id/edit`, `/categories`, `/categories/new`, `/categories/:id/edit`, `/entries`, `/entries/new`, `/entries/:id/edit`, `/settings`. Sin redirects de auth.
- RF-017: `AppDependencies` simplificado: expone `database` (drift) y los DAOs (`accountsDao`, `categoriesDao`, `entriesDao`, `stateService`, `backupService`). Sin `apiClient`, `tokenStorage`, `authState`, `authApi`, `*Api`.
- RF-018: suite de tests con `flutter_test`:
  - Capa de datos con drift en memoria: CRUD por DAO, cascada y FK constraint, saldos derivados para los 5 kinds, soft delete y filtros de listados.
  - Round-trip de backup: BD con datos → export JSON → BD limpia → import → contenido idéntico (round-trip ID por ID).
  - Migración v1: schema se crea correctamente desde cero.
  - Caso destructivo de import: import de JSON corrupto NO debe corromper la BD existente (transacción aborta).
  - Widget tests con `testApp` helper de los flujos críticos: first-run import, dashboard render, crear movimiento por cada kind, editar, cancelar, settings backup export.
  - `flutter analyze` sin issues.
- RF-019: APK release: `flutter build apk --release` produce APK instalable sin warnings críticos, instalado en el Redmi Note 13 del usuario (smoke manual). Manifest declara `INTERNET` y nada más (RN-015).
- RF-020: **documentación**:
  - `mobile/README.md` con qué es la app, cómo correr en Linux desktop, cómo construir APK, cómo importar el backup del backend legacy la primera vez.
  - `CLAUDE.md` raíz reescrito de cero para la nueva era (Flutter local-first), con sección "Arquitectura" + "Comandos" + "Decisiones" + "Roadmap futuro".
  - `README.md` raíz reescrito.
  - Nota de pivote en `engineering/specs/flutter-local-mvp/` con link explícito a la rama `legacy/web-and-online-flutter` para que cualquier agente futuro pueda encontrar el código viejo.

## Casos principales

- Primer arranque del lanzamiento (caso real de Diego): pantalla "Primer arranque" → "Arrancar limpio" → diálogo de confirmación → BD obtiene Bolsa singleton + 10 categorías default → navega a `/dashboard` con BO=$0. Diego empieza a capturar movimientos.
- Primer arranque eligiendo "Importar respaldo" (caso futuro): tap → file picker → seleccionar JSON v1 → la BD se llena con el contenido del backup → navega a `/dashboard`.
- Captura cotidiana: home Android → tap en ícono FinCore → dashboard → FAB "+" → seleccionar "Gasto" → cuenta + monto + categoría + descripción → guardar → vuelve al dashboard con saldo actualizado. **Todo offline.**
- Pago de tarjeta: "+" → "Pago de tarjeta" → origen (cash o debit) + destino (credit) + monto → guardar. Si excede la deuda actual, mensaje "No podés pagar más de lo que debés a la tarjeta." (RN-003).
- Editar movimiento ingresado por error: lista → tap → cambiar monto/descripción/fecha → guardar.
- Cancelar movimiento: lista → tap → "Cancelar movimiento" → confirmar → desaparece de la lista (soft delete RN-006).
- Backup manual antes de hacer algo riesgoso: Settings → "Exportar respaldo" → share sheet → guardar el JSON donde quiera (Drive, email, etc.).
- Restaurar BD desde respaldo: Settings → "Importar respaldo" → seleccionar archivo → confirmar reemplazo total → BD reemplazada → dashboard refleja contenido del backup.
- Actualizar la app a una versión futura con schema v2: las migraciones se aplican automáticamente, los datos sobreviven (RN-005, RF-004).

## Casos borde

- BD vacía sin backup disponible: la opción "Arrancar limpio" garantiza que el usuario puede empezar sin importar nada.
- Importar JSON corrupto o de versión desconocida (> 1): rechaza con mensaje claro, no toca la BD existente.
- Importar JSON v1 que no es de FinCore (otro app con misma versión pero schema distinto): rechaza por validación de estructura.
- Importar JSON vacío (`accounts: []`, etc.): rechaza con mensaje "Backup vacío" para evitar BD inutilizable.
- Importar dos veces seguidas el mismo backup: reemplazo idempotente, resultado igual al primero.
- Crear cuenta con nombre duplicado: backend la rechazaba con `duplicate_account_name`. El cliente local replica la validación a nivel DAO + mensaje en UI.
- Crear categoría con nombre duplicado: idem.
- Crédito con `closing_day == payment_day`: validación local rechaza con mensaje claro (igual que `invalid_credit_metadata` del backend).
- Bajar `credit_limit` por debajo de la deuda actual: validación rechaza (`invalid_credit_limit`).
- Eliminar cuenta con saldo distinto a cero: rechaza con "No podés archivar una cuenta con saldo distinto de cero" (RN-007).
- Eliminar Bolsa: rechaza con "La Bolsa no se puede eliminar" (RN-004).
- Editar Bolsa para cambiar su `type`: bloqueado, no hay UI para hacerlo.
- Categoría con `applies_to=income` seleccionada en form de gasto: el `CategoryPicker` filtra para no mostrarla (UI defensiva).
- Movimiento con fecha futura: aceptado por la libreta libre.
- Caracteres UTF-8 / emojis en descripciones: soportados por SQLite + drift sin configuración adicional.
- Texto largo (200+ caracteres) en descripciones: `maxLines: 2 + overflow: ellipsis` en listas, expandido en pantalla de edición.
- Doble tap rápido en "Guardar": mutex local impide envío duplicado (RN-016).
- Cancelar movimiento ya cancelado (race entre sesiones distintas): no aplica acá porque single-user single-device.
- Editar movimiento con cuenta archivada en el medio: DAO rechaza con mensaje "La cuenta seleccionada ya no está activa".
- Pérdida de la BD por corrupción del FS de Android: la única salvaguarda es el último backup exportado; comunicado en Settings con mensaje "Exporta respaldo regularmente".
- Migración futura de v1 → v2 (sprint posterior): la app no debe recrear la BD del usuario; los datos sobreviven. Test específico en sprint donde aparezca v2.

## Criterios de aceptacion

- Rama `legacy/web-and-online-flutter` existe en `origin` y `git checkout legacy/web-and-online-flutter` reproduce el repo completo previo al pivote.
- `git status` en `main` no muestra `backend/`, `frontend/`, `compose*.yaml`, `Dockerfile`, `docker/`, `db/`, `fly.toml`, `tests-e2e/`, `docs/api`, `docs/cli`, `docs/frontend`, `docs/scripts`, ni `scripts/fincore`/`scripts/install.sh`.
- `mobile/` en `main` contiene proyecto Flutter local-first nuevo, no el cliente online anterior.
- Instalar el APK release en el Android del usuario y completar: primer arranque → "Arrancar limpio" → dashboard con BO/DE/CR en $0 + Bolsa + 10 categorías default → crear ingreso a la Bolsa → crear gasto + transferencia + pago de tarjeta → editar uno → cancelar uno → exportar respaldo desde Settings (recibe JSON v1) → simular restore importando el mismo JSON → estado idéntico. **Todo offline (modo avión activado en el celular durante la prueba).**
- `flutter test` en verde con ≥ 25 tests (mínimo absoluto; típicamente saldrá 40+ entre DAOs, motor de saldos, backup round-trip, widget tests).
- `flutter analyze` sin issues.
- `flutter build apk --release` produce APK instalable sin warnings críticos.
- Manifest Android declara únicamente `android.permission.INTERNET` y ningún otro (verificado por `aapt dump permissions`).
- Test específico de import corrupto: un JSON inválido NO destruye la BD existente. La transacción aborta y los datos previos se conservan intactos.
- `mobile/README.md` cubre: qué es, cómo correr, cómo construir APK, cómo importar el backup la primera vez, cómo crear el JSON exportable del backend legacy si Diego pierde el archivo (instrucciones para hacer checkout de la rama legacy y correr el endpoint).
- `CLAUDE.md` raíz reescrito de cero refleja la nueva arquitectura local-first y no menciona Laravel/Vue/Tailscale/Docker en presente.

## Criterios medibles de exito

- Arranque frío (ícono → dashboard interactivo) **< 1 segundo** en el Redmi Note 13 del usuario, sin red, sin laptop encendida.
- 0 requests HTTP salientes durante una sesión completa de uso (verificable con modo avión activado).
- 0 permisos Android más allá de `INTERNET`.
- ≥ 25 tests verdes en `flutter test` (mix de datos + widgets + backup).
- Round-trip de backup verificado: hash de la BD tras export-wipe-import es igual al de antes del export (a nivel de contenido, no de bytes del archivo SQLite).
- Tamaño del APK release < 50 MB (sin `--split-per-abi`; el actual del cliente online era 43 MB, este debería estar similar o levemente menor por eliminar dio/http).
- Migración inicial completada: el JSON real del backend de Diego se importa sin pérdida ni error. Los movimientos y saldos coinciden 1:1 con lo que tenía en el backend antes del pivote.

## Riesgos

- **Stack drift+SQLite+codegen tiene una curva de aprendizaje** que el cliente Flutter online actual NO usaba (era HTTP puro). Mitigación: dogear ya tiene drift+codegen funcionando con todas las trampas documentadas en su `CLAUDE.md` y `engineering/specs/flutter-local-mvp/`. Replicar el patrón.
- **Patrones de drift en widget tests** (override de `libsqlite3.so.0` en Linux, `testApp` helper que drena Timer interno, `select().get()` en vez de `watch().first` bajo reloj falso) son trampas conocidas que tomaron horas en dogear. Mitigación: copiar y adaptar el setup de dogear desde el principio, no descubrirlas en debugging.
- **Migración de los datos reales del usuario**: si el JSON del backend legacy tiene un schema sutilmente distinto del que asume el importador (ej. campos null que el cliente local asume no-null), puede fallar. Mitigación: el formato JSON es el mismo que el backend produce y consume, ya está validado por suite de tests del sprint `respaldos` en el backend. Test específico con el JSON real de Diego antes de cerrar el sprint.
- **Pérdida del histórico del backend Laravel**: descartado como riesgo el 2026-06-17. Diego confirmó que prefiere arrancar de cero sin migrar los datos del backend. El histórico del backend queda intacto en la rama legacy si en algún futuro decide recuperarlo manualmente.
- **Reutilización de UI del cliente online actual**: las pantallas reciben datos de `*Api` y los pasan al render. Cambiar la fuente a DAOs requiere refactor en cada pantalla. Mitigación: el shape de los modelos no cambia mucho (sólo agregan anotaciones drift); las pantallas siguen renderizando `List<Account>`, `List<JournalEntry>`, etc. Refactor mecánico, no de diseño.
- **Build APK desde el día 1**: el APK release actual usa archs múltiples y pesa 43 MB. La versión local-first sin dio+http debería pesar similar o menos. Si excede 50 MB, evaluar `--split-per-abi` o sumar a desviaciones.
- **`mobile/` actual borrado**: el repo `main` actual tiene 2 semanas de trabajo en `mobile/` que se va a la rama legacy. Si la rama no se respalda correctamente y `main` pierde ese código, hay riesgo de pérdida. Mitigación: la rama legacy se pushea a `origin` antes de cualquier `rm -rf` en main, verificable con `git log origin/legacy/web-and-online-flutter`.
- **`applicationId` igual al cliente online actual**: si Diego tiene la app vieja instalada y se reinstala la nueva, Android la reemplaza con confusión de datos (los datos viejos eran HTTP cache; los nuevos son SQLite). Mitigación: el smoke incluye desinstalar la app vieja antes de instalar la nueva. APK nueva genera BD limpia y muestra "Primer arranque".

## Supuestos

- S-001: el formato JSON v1 sigue siendo el producido por `/api/finance/backup/export` del backend legacy (estructura documentada en `engineering/specs/respaldos/`) para que cualquier import futuro de un backup del backend siga funcionando. El cliente local lee EXACTAMENTE ese formato. No se construye un formato "FinCore Flutter" distinto.
- S-002: Diego no va a migrar los datos del backend al MVP. Decisión cerrada el 2026-06-17 (ver `clarificaciones.md`). La pantalla "Primer arranque" mantiene ambos botones por resiliencia futura, pero T001 del plan original (exportar JSON del backend) queda descartada.
- S-003: el applicationId `io.github.gregori100.fincore` ya no requiere confirmación (decisión cerrada en sprint anterior, vigente). Inmutable post-Play Store.
- S-004: la carpeta del proyecto Flutter dentro del monorepo se llama `mobile/` (decisión cerrada en sprint anterior). El proyecto nuevo vive en la misma carpeta tras borrar el contenido del cliente online.
- S-005: drift **con codegen** (`build_runner`). Decisión P-003 cerrada. Anotaciones de tabla en `database.dart` + `dart run build_runner build` produce companions tipados, queries chequeadas en compile-time, streams reactivos `watch()` que emiten cuando cambia el contenido de las tablas observadas. Mismo patrón que dogear ya validó.
- S-006: **soft delete** (`deleted_at TEXT ISO-8601 NULL`) para cancelar movimientos y archivar cuentas/categorías. Decisión P-004 cerrada. Todos los DAOs filtran `deleted_at IS NULL` por defecto. Cancelar/archivar setea `deleted_at = ISO8601(now)`. Sin UI para reactivar (terminal, RN-006/RN-007). Compatible con sync futuro y con la posibilidad de recuperar reportes históricos. Hard delete sólo aplica al import (reemplazo total) y al primer arranque "Arrancar limpio".
- S-007: saldos **derivados sobre la marcha** vía SQL agregado, sin columna `balance`. Decisión P-005 cerrada. El `FinancialStateService` expone `Stream<num>` para BO/DE/CR y saldo por cuenta usando `watch()` de drift, que cachea automáticamente entre renders no-relacionados y solo recalcula cuando cambia el contenido de las tablas observadas. Cero estado adicional, cero riesgo de inconsistencia. Índices sobre `journal_entries(account_origin_id)`, `journal_entries(account_destination_id)`, `journal_entries(deleted_at)` para garantizar < 10ms total en queries agregadas incluso con 50k+ entries. Si en el futuro lejano la performance se degrada por volumen extremo, sprint específico introducirá materializado por trigger.
- S-008: tema único oscuro réplica del cliente Flutter online actual; reutilizable 1:1 (mismo `fincore_colors.dart` y `fincore_theme.dart`).
- S-009: `versionName = 0.2.0`, `versionCode = 2`. Decisión P-002 cerrada. Como el `applicationId` se mantiene (`io.github.gregori100.fincore`), Android trata el APK nuevo como upgrade del APK del cliente online (versionCode=1) — `versionCode=2` evita `INSTALL_FAILED_VERSION_DOWNGRADE` sin requerir desinstalar manualmente la app vieja. El minor bump en `versionName` refleja simbólicamente el pivote arquitectónico (online → local-first) sin pretender ser una 1.0.
- S-010: tests con drift en memoria + `mocktail` para mockear lo poco que quede de capas externas (file picker, share sheet). El helper `testApp` se replica del de dogear con adaptaciones mínimas.
- S-011: el smoke manual se hace por el usuario en su Redmi Note 13. Daemon adb ya está autorizado del sprint anterior; no requiere sudo nuevamente salvo reboot del laptop.
- S-012: el código del cliente Flutter online actual (`mobile/lib/` antes del pivote) es referencia constante durante el sprint para copiar tema, catálogo, widgets, pantallas con ajustes mínimos. Se accede haciendo `git show legacy/web-and-online-flutter:mobile/lib/...` o teniendo un worktree separado.
- S-013: las 5 preguntas P-001 a P-005 fueron respondidas el 2026-06-17 (ver `clarificaciones.md`). Ninguna queda pendiente. La spec está lista para `spec-planear`.

## Impacto esperado

- **Producto**: FinCore deja de ser una app web multi-usuario con cliente móvil online y pasa a ser una **app Android local-first** con la que Diego puede capturar movimientos en cualquier momento y lugar, sin depender de su laptop, su red, ni ningún cert TLS. Los datos viven en el celular; los respaldos son archivos JSON que él guarda donde quiera.
- **Repo**: `main` cambia drásticamente de identidad (de stack web-y-móvil-cliente a sólo móvil local). Historia y trazabilidad se preservan; el código previo es recuperable haciendo checkout de la rama legacy.
- **Proceso**: el flujo specs → plan → implementación → quality review sigue idéntico. Cambian las herramientas de verificación (drift en memoria, `flutter test`, `flutter analyze`) y el target del smoke (Android real, modo avión activable).
- **Costos operativos**: cero. Ya no hay backend que mantener, ni Tailscale que monitorear, ni Docker que orquestar. El día que el usuario decida subir a hosting real para sync, esa es una decisión nueva con su propia spec.
- **Roadmap posterior natural**:
  1. Publicación en Play Store cuando el uso real lo amerite (spec aparte).
  2. Auto-backup a Google Drive del usuario (spec aparte).
  3. Recuperación de reportes core (`by-category`, `cashflow-monthly`, `by-account`) cuando Diego los extrañe (specs separadas; ver memoria `features-lost-on-flutter-pivot`).
  4. Plan engine local cuando se justifique.
  5. Sync API + auth + multi-dispositivo — el rumbo "muy futuro" que el usuario confirmó.

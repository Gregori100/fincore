# Resumen extenso — flutter-local-mvp

## Contexto

### Motivación del pivote (2026-06-12)

FinCore venía operando como backend Laravel + frontend Vue + cliente Flutter online accediendo vía Tailscale Funnel a un stack productivo casero (`compose.tailscale.yml`). En uso real Diego descubrió que la dependencia de laptop encendida + Tailscale + cert TLS válido hacía la app inutilizable en el momento de captura (que es el momento exacto en que se registra un gasto). Se decidió pivotar a app Flutter Android **local-first single-user**, mismo modelo que validó dogear: SQLite local con drift como única fuente de verdad, sin red, sin login.

### Decisión adicional del 2026-06-17

Inicialmente el plan T001 contemplaba exportar el JSON real del backend (cuentas, categorías, movimientos de Diego) y importarlo al primer arranque para preservar datos. Diego decidió **arrancar de cero sin migrar**: la app incluye la pantalla "Importar respaldo" para futuros restores, pero el lanzamiento inicial fue "Arrancar limpio".

### Cierre de spec y plan

- Spec aprobada en `engineering/specs/flutter-local-mvp/spec.md` (20 RFs, 16 RNs, 13 supuestos).
- Preguntas P-001..P-005 cerradas en `clarificaciones.md`.
- Plan técnico en `plan/plan.md`, tareas T001-T055 en `plan/tasks.md`, test-plan en `plan/test-plan.md`.

## Relación con el plan

El plan ejecutado cubre todas las tareas T002 → T055. La única excepción consciente:

- **T001 DESCARTADA** (no se exporta el JSON del backend).
- **T043-T045 (widget tests) aplazados** y documentados en `desviaciones-plan.md`.

Todos los demás desvíos están documentados como adiciones polish del smoke iterativo, no como cambios de scope.

## Cambios principales por capa

### Estructura del repo

- Rama `legacy/web-and-online-flutter` preserva todo el stack pre-pivote (backend Laravel, frontend Vue, cliente Flutter online, Docker stack, scripts CLI).
- `main` queda con `engineering/specs/` + `mobile/` + `CLAUDE.md` + `README.md`. Borrados de main: `backend/`, `frontend/`, `mobile/` online, `docker/`, `compose*.yml`, `fly.toml`, `tests-e2e/`, `docs/api/cli/frontend/scripts/deploy`, `scripts/fincore`, `scripts/install.sh` (430 archivos en commit `chore(pivote)`).

### Capa de datos (`mobile/lib/data/`)

- `database.dart`: 3 tablas drift (Accounts, Categories, JournalEntries) con FK references explícitas y 6 índices (3 críticos sobre journal_entries + 3 auxiliares). schemaVersion = 1. beforeOpen PRAGMA foreign_keys = ON. `build.yaml` con `store_date_time_values_as_text: true` para preservar subsegundos en round-trip backup.
- `database.g.dart`: generado por `drift_dev` + `build_runner` (47 outputs).
- `uuid.dart`: generador UUID v7 compatible con backend Laravel `HasUuids`.
- `daos/accounts_dao.dart`, `daos/categories_dao.dart`, `daos/entries_dao.dart`: CRUD + validaciones de dominio (Bolsa singleton, duplicate name, invalid credit metadata, OverpayDebt, RN-011 validation de tipo↔kind, libreta libre en saldos negativos).
- `financial_state.dart`: `customSelect` con `readsFrom: {accounts, journalEntries}` para BO/DE/CR + balance por cuenta. Drift cachea automáticamente entre rebuilds.
- `seed.dart`: crea Bolsa + 10 categorías default (3 income + 7 expense). Idempotente.
- `bootstrap.dart`: `hasBolsa(db)` decide si la BD está vacía → router redirige a `/first-run`.
- `backup.dart`: JSON v1 idéntico al backend (sin user_id, sin plan, sin soft-deleted). Import transaccional valida estructura + version + Bolsa + FKs antes de tocar BD. Errores tipados (`invalid_json`, `unsupported_version`, `missing_bolsa`, `invalid_reference`). Método nuevo `wipeAll()` extraído para reuso en reset de cuenta.

### Capa de presentación (`mobile/lib/screens/` y `widgets/`)

- `app_dependencies.dart`: `AppDependencies` + `AppDependenciesProvider` InheritedWidget. Sin authState/tokenStorage/apiClient.
- `router/app_router.dart`: `go_router` 14.6 con `FirstRunState ValueNotifier<bool?>` como `refreshListenable`. `initialLocation: '/splash'`. Redirect a `/first-run` si no hay Bolsa; a `/dashboard` si ya hay.
- `screens/`:
  - `splash_screen.dart`: logo + spinner mientras se chequea Bolsa.
  - `first_run_screen.dart`: dos cards (Importar respaldo / Arrancar limpio).
  - `dashboard_screen.dart`: 3 cards BO/DE/CR + lista cuentas + lista últimos movimientos. Skeletons en todas las zonas reactivas. AppBar con wordmark + acceso a Categorías + Settings.
  - `accounts_list_screen.dart` + `account_form_screen.dart`: CRUD de cuentas con DropdownMenu M3.
  - `categories_list_screen.dart` + `category_form_screen.dart`: CRUD de categorías con preview live del badge.
  - `entries_list_screen.dart` + `entry_form_screen.dart`: lista paginada + filtros + alta/edición con KindPicker contextual + AccountPicker + CategoryPicker + cancelación terminal.
  - `settings_screen.dart`: secciones Organización (link a Categorías), Respaldo (Exportar/Importar), Zona peligrosa (Reiniciar cuenta), Acerca de, Legacy.
- `widgets/`:
  - `fincore_logo.dart`: wordmark RichText con tagline configurable.
  - `account_picker.dart`, `category_picker.dart`: `DropdownMenu<T>` M3 con width del field.
  - `account_balance_hint.dart`: chip reactivo debajo de pickers con saldo/deuda.
  - `skeleton.dart`: `Skeleton` y `SkeletonCard` con pulse animado.
  - `error_snackbar.dart`: snackbars success/warning/error con dismiss on tap.
  - Resto de widgets (BaseCard, ConfirmDialog, AppliesToPicker, ColorPicker, IconPicker, KindPicker, AccountTypePicker, AmountFormatter, CategoryBadge) portados del legacy con adaptaciones para drift en lugar de Api.

### Configuración nativa (`mobile/android/`)

- `applicationId = io.github.gregori100.fincore` (mantiene compatibilidad con APK del cliente online).
- `minSdk = 24`, `targetSdk = 35`, `versionCode = 27`, `versionName = "0.2.0"`.
- `ndkVersion = "27.0.12077973"` (requerido por los plugins nativos).
- `AndroidManifest.xml`: solo permiso `INTERNET` (sin uso runtime; reserva para futuro sync).
- Icono adaptive + monochrome themed generado con `flutter_launcher_icons` desde `assets/icon/icon_full.png`.

## Desviaciones respecto al plan

Detalladas en `desviaciones-plan.md`. Resumen:

1. **T001 descartada**: no migración del JSON del backend.
2. **Residuos del FS en backend/vendor/ y frontend/node_modules/**: permission denied al borrar (containers Docker con UID root); no bloqueante.
3. **Modelos de dominio duplicados** entre `lib/models/` y drift: necesario porque widgets reutilizables tipan contra los modelos del legacy. Duplicación tolerable.
4. **Widget tests aplazados** (T043-T045): justificado por exhaustividad de tests de datos (56 verdes) y smoke manual.
5. **Bugs detectados en smoke**: 3 críticos (back cierra app, form blanco por DateFormat, bootstrap frágil) + ~14 polish UX. Todos corregidos antes del cierre.
6. **Adiciones polish**: logo wordmark + splash screen + system bars + icono launcher + skeletons + balance hints + snackbars rediseñados + filtros con safe area + reset de cuenta. Ninguno cambia reglas de negocio ni datos.

## Pruebas realizadas

### Automatizadas

- **`flutter test`**: 56 tests verdes.
  - `database_test.dart`: 29 tests (schema, PRAGMA, AccountsDao, CategoriesDao, EntriesDao por los 5 kinds, seed).
  - `financial_state_test.dart`: 12 tests (BO/DE/CR, stream reactivo, archive, balance sincrónico vs stream).
  - `backup_test.dart`: 7 tests (round-trip, JSON inválido, version > 1, missing Bolsa, FK rota, idempotencia, BD vacía).
  - `invariants_test.dart`: 8 tests (libreta libre, RN-011, OverpayDebt, cuentas archivadas, categorías incompatibles).
- **`flutter analyze`**: 0 errores, 0 warnings.

### Manuales

- Diego instaló APK en Redmi y validó:
  - Primer arranque (pantalla con dos opciones).
  - Arrancar limpio → Dashboard con BO=0, DE=0 (CR depende del límite configurado).
  - Crear cuenta debit + tarjeta credit + categoría custom.
  - Registrar los 5 kinds (income, expense, credit_expense, debt_payment, transfer).
  - Editar movimiento y cancelar.
  - Modo avión: todo el CRUD funciona offline.
  - Export → share sheet → guardar JSON. Import → confirmación destructiva → BD restaurada idéntica.
  - Reset de cuenta → vuelve a `/first-run`.

## Pruebas recomendadas (próximos sprints)

- Widget tests para `entry_form_screen` bootstrap (cuentas + categorías + DateFormat).
- Widget test para back nativo desde sub-pantallas (PopScope del KindPicker).
- Widget test para flujo de filtros (sheet abre, scroll, botones visibles).
- Integration test del flujo completo first-run → alta → export → import.

## Riesgos residuales

- **UI sin red de seguridad automática**: el smoke iterativo encontró 3 bugs críticos (form blanco por DateFormat, navegación con stack duplicado, snackbar dismiss). Una regresión similar en el futuro requeriría otro smoke manual completo.
- **Bump frágil de versionCode**: cada release incremental requirió un `versionCode++` para evitar `INSTALL_FAILED_VERSION_DOWNGRADE` en el cel de Diego (el split-per-abi prepende el código de arquitectura al versionCode). Documentar en `mobile/README.md`.
- **`flutter_launcher_icons.yaml` duplica config con pubspec.yaml**: ambas tienen la config del icon. Si en algún momento se cambian assets, actualizar ambas. Idealmente borrar el yaml externo y dejar solo el bloque en `pubspec.yaml`.
- **Single user**: la app no contempla múltiples usuarios. Si Diego presta el cel a un familiar para que también lleve su libreta, ambos comparten la misma BD.

## Posibles regresiones

- **Próximas migraciones de schema**: `schemaVersion = 1` no se ha incrementado. Cuando se agreguen tablas o columnas, hay que implementar `onUpgrade` en `database.dart` y asegurar compatibilidad con respaldos JSON v1.
- **Drift cache invalidation**: si se modifica el SQL crudo de `financial_state.dart` y no se actualiza `readsFrom: {accounts, journalEntries}`, drift no invalidará el cache y los saldos quedarían stale.
- **`store_date_time_values_as_text: true`**: si se cambia este flag en `build.yaml`, los respaldos exportados antes del cambio dejan de ser importables (formato de fecha distinto).

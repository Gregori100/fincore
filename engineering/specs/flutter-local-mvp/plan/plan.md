# Plan técnico — flutter-local-mvp

## Enfoque técnico

App Flutter Android single-user **local-first puro** con SQLite vía **drift** como única fuente de verdad. Sin red en runtime, sin auth, sin sesión. Reuso intensivo del cliente Flutter online actual (`mobile/lib/` hoy en `main`) en lo que no toca capa de datos: tema, catálogo de colores/íconos, enums, widgets, pantallas. Reemplazo total de la capa que sí cambia: `api/` (HTTP) → `data/` (drift + DAOs); `LoginScreen`/`VerifyEmailScreen`/`token_storage` → eliminados; `AuthSession`/`AuthStateNotifier` → eliminados; `AppDependencies` simplificado.

El pivote arquitectónico se ejecuta como **destrucción + reconstrucción** del `main`, con todo el código previo preservado intacto en una rama `legacy/web-and-online-flutter` empujada a `origin` antes de cualquier borrado. La spec lo declara irreversible-ish: el camino de vuelta existe (checkout de la rama) pero no se trabaja en paralelo.

El motor de saldos se implementa con **streams reactivos de drift**: el `FinancialStateService` expone `Stream<num>` para BO/DE/CR y por cuenta, soportado por `select(...).watch().map(calcSum)`. Drift emite un valor nuevo solo cuando cambia el contenido de las tablas involucradas; los rebuilds del widget reusan el último valor en memoria. Performance objetivo: < 10 ms para BO/DE/CR + N saldos de cuentas con dataset realista (≤ 50k entries), garantizado por índices sobre `journal_entries(account_origin_id)`, `journal_entries(account_destination_id)` y `journal_entries(deleted_at)`.

Backup JSON v1 con formato **idéntico** al producido por `/api/finance/backup/export` del backend Laravel (legacy). Esto permite la **migración inicial de los datos reales de Diego** sin escribir un transformador: el JSON exportado del backend se importa tal cual en la nueva app. Mismo formato sirve también después para restaurar respaldos posteriores del propio cliente local.

El sprint NO requiere trabajo previo del usuario. Diego decidió el 2026-06-17 arrancar de cero sin importar datos del backend legacy (ver `clarificaciones.md`); T001 del plan original queda descartada. La pantalla "Primer arranque" conserva ambos botones (Arrancar limpio / Importar respaldo) por resiliencia futura: Diego va a empezar con "Arrancar limpio" en el lanzamiento, y "Importar respaldo" queda lista para restaurar backups propios que él mismo genere desde Settings tras meses de uso.

## Requisitos funcionales cubiertos

- RF-001: rama `legacy/web-and-online-flutter` creada con todo el código previo intacto. T002 (creación local + push) + T003 (verificación remota).
- RF-002: `main` retira backend/, frontend/, mobile/ (online), compose.yaml, compose.tailscale.yml, Dockerfile, db/, docker/, scripts/fincore + scripts/install.sh, fly.toml, tests-e2e/, docs/{api,cli,frontend,scripts,deploy}. T004 (un solo commit de borrado masivo).
- RF-003: proyecto Flutter en `mobile/` con applicationId, versionName=0.2.0, versionCode=2, targets android+linux. T005-T009.
- RF-004: schema drift v1 con índices en journal_entries. T015 (database.dart) + T016 (codegen) + tests T039.
- RF-005: backup.dart con serializer/parser JSON v1, import transaccional. T024 + tests T041.
- RF-006: pantalla "Primer arranque" con dos opciones. T028 + T035.
- RF-007: Dashboard con streams reactivos. T029 con su _State cacheando stream.
- RF-008: CRUD cuentas. T030-T031.
- RF-009: CRUD categorías. T032-T033.
- RF-010: CRUD movimientos por kind. T034.
- RF-011: motor de saldos derivados. T020 (StateService) + tests T040.
- RF-012: Settings con backup export/import. T035.
- RF-013: catálogo. T013 (port desde legacy).
- RF-014: tema. T012 (port desde legacy).
- RF-015: enums kinds + account_types. T013 (port).
- RF-016: router con redirect a /first-run si BD vacía. T026.
- RF-017: AppDependencies simplificado con database + DAOs. T025.
- RF-018: suite de tests. T039-T045.
- RF-019: APK release + smoke. T048-T051.
- RF-020: documentación. T052-T054.

## Archivos o módulos probablemente afectados

**Borrados en main** (van a legacy):

- `backend/` completo.
- `frontend/` completo.
- `mobile/` actual completo (cliente online).
- `compose.yaml`, `compose.tailscale.yml`, `Dockerfile`, `fly.toml`.
- `db/`, `docker/`.
- `scripts/install.sh`, `scripts/fincore`.
- `tests-e2e/`.
- `docs/api/`, `docs/cli/`, `docs/frontend/`, `docs/scripts/`, `docs/deploy.md`, `docs/deploy-tailscale.md`.
- `.env*` en raíz, `.gitignore` se simplifica.
- `package.json`, `package-lock.json`, `node_modules/` raíz.
- `test-results/`.

**Conservados en main**:

- `engineering/` con todas las specs históricas. La spec del sprint actual vive en `engineering/specs/flutter-local-mvp/`. Las del cliente online (`flutter-mvp-cliente/`) y previas quedan como histórico.
- `.git/` (historia preservada; la rama legacy convive con la nueva era).
- README.md raíz (reescrito).
- CLAUDE.md raíz (reescrito).

**Nuevos en main** (`mobile/`):

- `mobile/pubspec.yaml`, `mobile/analysis_options.yaml`, `mobile/build.yaml`, `mobile/README.md`.
- `mobile/android/app/build.gradle.kts` (applicationId, versionCode=2, versionName=0.2.0, minSdk=24, targetSdk=35).
- `mobile/android/app/src/main/AndroidManifest.xml` (declara INTERNET solo).
- `mobile/lib/main.dart` (DI: database + DAOs + go_router; sin FINCORE_API_URL).
- `mobile/lib/app_dependencies.dart` (InheritedWidget con `database`, `accountsDao`, `categoriesDao`, `entriesDao`, `stateService`, `backupService`).
- `mobile/lib/data/`:
  - `database.dart` (tablas drift + schemaVersion + onUpgrade stub + beforeOpen PRAGMA + índices).
  - `database.g.dart` (generado por build_runner; no editar a mano).
  - `daos/accounts_dao.dart`, `daos/categories_dao.dart`, `daos/entries_dao.dart`.
  - `data/financial_state.dart` (StateService con `Stream<num>` para BO/DE/CR y por cuenta).
  - `data/backup.dart` (serializer JSON v1 + parser/importer transaccional).
  - `data/seed.dart` (Bolsa singleton + 10 categorías default para "Arrancar limpio").
  - `data/bootstrap.dart` (helpers `hasBolsa()` para detectar primer arranque).
- `mobile/lib/theme/`, `mobile/lib/constants/`, `mobile/lib/widgets/`: portados 1:1 del legacy con `git show legacy/web-and-online-flutter:mobile/lib/...`.
- `mobile/lib/screens/`:
  - `first_run_screen.dart` (nueva).
  - `dashboard_screen.dart`, `accounts_*`, `categories_*`, `entries_*`, `settings_screen.dart` (portados con reemplazo de `*Api` por `*Dao`).
- `mobile/lib/router/app_router.dart` (sin redirects de auth; redirect a /first-run si `!hasBolsa`).
- `mobile/scripts/run-linux.sh`, `mobile/scripts/build-apk.sh` (ya no requieren FINCORE_API_URL).
- `mobile/test/`:
  - `helpers/test_app.dart` (monta app con BD en memoria, drena Timer en tearDown).
  - `helpers/sqlite_override.dart` (override de libsqlite3.so.0 para Linux).
  - `helpers/factories.dart` (fixtures de accounts/categories/entries).
  - `data/database_test.dart`, `data/financial_state_test.dart`, `data/backup_test.dart`.
  - `data/daos/{accounts,categories,entries}_dao_test.dart`.
  - `screens/{dashboard,entry_form,first_run,settings}_test.dart`.

**Modificados en main**:

- `README.md` raíz: reescrito de cero (proyecto Flutter local-first single-user).
- `CLAUDE.md` raíz: reescrito de cero (arquitectura local-first, comandos Flutter, decisiones, roadmap).
- `.gitignore` raíz: simplificado (dejar lo de Flutter + IDE OS; quitar todo lo de Docker/PHP/Vue/Tailscale).

## Entidades y estados afectados

**`accounts`** (tabla drift):

- Estados relevantes: activa (`deleted_at IS NULL`) vs archivada (`deleted_at` con timestamp).
- Invariantes:
  - Existe exactamente una fila con `type = 'cash'` y `is_protected = true` (la Bolsa singleton, RN-004).
  - Si `type = 'credit'` y se guarda nueva metadata, `closing_day != payment_day` (RN-013, valida el form + DAO defensivo).
  - Si `type != 'credit'`, campos `credit_limit`, `closing_day`, `payment_day`, `interest_rate`, `minimum_payment_pct` quedan NULL.
- Transición activa → archivada: requiere saldo derivado = 0 (RN-007). Validación en el `accounts_dao.archive(id)`.
- Sin transición archivada → activa.

**`categories`** (tabla drift):

- Estados: activa vs archivada.
- Invariantes: `applies_to ∈ ('income','expense','both')`; `color_slug` y `icon_slug` deben existir en el catálogo (RF-013).
- Transición activa → archivada: irreversible. La UI no muestra categorías archivadas pero entries históricos conservan su `category_id` (la relación se trata como `null` en queries que joinean por activos, igual que el backend).

**`journal_entries`** (tabla drift):

- Estados: activo vs cancelado (`deleted_at`).
- Invariantes (cumplidos por DAO + form):
  - `amount > 0` siempre.
  - `kind` determina presencia de `account_origin_id` y `account_destination_id` según RN-011.
  - Si `account_origin_id != null` y la cuenta está archivada, el DAO rechaza la operación (la UI también filtra).
  - Si `kind` ∈ `(debt_payment, transfer)`, `category_id` debe ser NULL.
- Transición activo → cancelado: terminal, sin reactivación.
- "Libreta libre": el DAO NO bloquea gastos que dejen saldo negativo ni cargos que excedan `credit_limit`. ÚNICA validación bloqueante: `OverpayDebt` al pagar más de la deuda actual a una tarjeta.

**Bolsa singleton**: en `data/seed.dart` se crea con `id = UUID v7()`, `type = 'cash'`, `is_protected = true`, `name = 'Bolsa'`. El `accounts_dao` rechaza intentos de:

- Crear una segunda cuenta con `type = 'cash'`.
- Eliminar una cuenta con `is_protected = true`.
- Editar `type` de la Bolsa (la UI ni siquiera lo expone).

**Saldos derivados** (no son tabla; son streams del `FinancialStateService`):

- `accountBalance(accountId)`:
  - Si la cuenta es `cash` o `debit`: `(Σ amount WHERE account_destination_id = id AND deleted_at IS NULL) − (Σ amount WHERE account_origin_id = id AND deleted_at IS NULL)`.
  - Si la cuenta es `credit`: `(Σ amount WHERE account_origin_id = id AND deleted_at IS NULL) − (Σ amount WHERE account_destination_id = id AND deleted_at IS NULL)` (representa deuda actual).
- `bo()`: suma de `accountBalance` de cuentas no archivadas con type ∈ (cash, debit).
- `de()`: suma de `accountBalance` de cuentas no archivadas con type = credit.
- `cr()`: suma de `(credit_limit − accountBalance)` para cuentas no archivadas con type = credit y credit_limit != null.
- Implementación: cada stream usa `customSelect(sql, readsFrom: {accounts, journalEntries}).watchSingle()` para que drift detecte cambios y reemita.

## Compatibilidad con datos y procesos existentes

- **Datos del usuario actual** (backend Laravel Postgres): NO se migran al MVP. Diego decidió arrancar de cero el 2026-06-17. Los datos quedan accesibles en la rama legacy si en el futuro decide recuperarlos. El formato JSON v1 producido por `/api/finance/backup/export` del backend sigue siendo el contrato para los backups propios del cliente local (RF-005).
- **Migración de schema futura**: `schemaVersion = 1` deja la puerta abierta. `MigrationStrategy.onUpgrade` queda con stub que el sprint del v2 implementa. RN-005 garantiza que nunca se recrea la BD del usuario.
- **Backend Laravel y Vue web**: quedan en la rama `legacy/web-and-online-flutter` sin mantenimiento. Si Diego necesita levantarlos de nuevo (para regenerar un backup, por ejemplo), hace `git checkout legacy/web-and-online-flutter` y sigue las instrucciones del CLAUDE.md de esa rama.
- **APK del cliente online** instalado actualmente en el Redmi (versionCode=1): se reemplaza por el nuevo APK (versionCode=2) sin requerir desinstalación manual. El primer arranque del APK nuevo encuentra BD vacía (porque drift abre un archivo SQLite distinto al storage que usaba el cliente online vacío) y dispara la pantalla "Primer arranque".
- **Engineering history**: todas las specs anteriores (`flutter-mvp-cliente/`, `respaldos/`, `plan/`, los 7 reportes, etc.) quedan en `engineering/specs/` como referencia histórica. El CLAUDE.md raíz nuevo aclarará que son obsoletas pero útiles para entender el dominio.
- **Memoria** (`~/.claude/projects/.../memory/`): ya actualizada en este turno con `project_context.md`, `features-lost-on-flutter-pivot.md`, `feedback_simplicity_over_features.md`. Sirve como mapa del pivote para futuros agentes.

## Cambios de datos

No aplica como migración SQL. El cambio de "datos" es el destructivo cambio de repo (legacy + main reconstruido), cubierto en T002-T004. Después de eso, schema drift v1 es la única migración real, que se ejecuta automáticamente al primer arranque de la app instalada.

## Cambios de API

No aplica. La app no expone ni consume API en este sprint. El `formato JSON v1 de backup` es el único contrato externo, y se hereda del backend legacy sin cambios.

## Cambios de integraciones

No aplica. Sin integraciones externas. El share sheet de Android para exportar y el file picker para importar son del sistema operativo, no integraciones de terceros.

## Cambios de UI

UI totalmente reconstruida en `mobile/` (proyecto Flutter nuevo):

- Tema oscuro réplica del cliente online (port directo).
- Catálogo de colores e íconos para categorías (port directo).
- Widgets compartidos (port directo).
- Pantallas: las 7 del cliente online portadas con reemplazo de `*Api` por `*Dao` + 1 pantalla nueva (`first_run_screen.dart`).
- Router: sin redirects de auth; redirect a `/first-run` si la BD no tiene Bolsa.

UI fuera de scope (no se construye en este sprint, ver Fuera de alcance de spec): reportes, Excel export, Plan engine, settings administrativas avanzadas, auth.

## Cambios de permisos

- Manifest declara únicamente `android.permission.INTERNET` (RN-015). La app no usa la red en runtime, pero el permiso se preserva para que el día del sync futuro no requiera releasear cambiando el manifest.
- Sin permisos runtime nuevos. file_picker y share_plus operan sin permisos extra en Android moderno (usan el SAF).

## Riesgos técnicos

- **Pérdida del histórico del backend Laravel**: descartado como riesgo el 2026-06-17. Diego confirmó que prefiere arrancar de cero. Los datos del backend quedan inmovilizados en la rama `legacy/web-and-online-flutter`; si en algún futuro lejano quiere recuperarlos, hace checkout + levanta el stack + exporta + importa el JSON desde Settings.
- **Trampas conocidas de drift + Flutter testing** (override de libsqlite3.so.0 en Linux VM, `Timer is still pending` si testApp no drena el Timer interno de drift en tearDown, `watch().first` que cuelga bajo reloj falso): mitigado replicando el setup de dogear desde T036. Riesgo si no se hace bien: los widget tests revientan con error críptico.
- **build_runner conflicts**: la primera vez que se corre `dart run build_runner build` puede pedir `--delete-conflicting-outputs`. Documentado en `mobile/README.md` y en `mobile/scripts/codegen.sh`. Riesgo si se ignora: confusión por archivos `.g.dart` viejos.
- **`store_date_time_values_as_text`**: si build.yaml no se configura correctamente desde T010, drift trunca subsegundos en `DateTimeColumn`, lo que rompe el orden estable de movimientos creados en el mismo segundo y el round-trip del backup. dogear lo documenta como gotcha histórico. Mitigación: T010 incluye la línea exacta de build.yaml.
- **Reuso de pantallas del cliente online**: las pantallas reciben datos vía `AppDependencies.of(context).accountsApi.list()` (Future). El cambio a DAOs es vía streams (`watch()`). Las pantallas deben refactorizar de `FutureBuilder` a `StreamBuilder` + cachear el stream en el `State`. Riesgo si se hace mal: rebuild loops o streams duplicados que disparan queries innecesarias. Mitigación: patrón documentado en `mobile/README.md` y verificado en widget tests.
- **`flutter create` en `mobile/` cuando la carpeta ya existe** (porque vino vacía tras T004): el comando flutter create rechaza si la carpeta tiene contenido. Mitigación: T004 deja `mobile/` borrada del todo, T005 ejecuta `flutter create` en raíz y crea `mobile/` nuevo.
- **`applicationId` y conflictos con app vieja**: como el applicationId es el mismo (`io.github.gregori100.fincore`), si el storage que drift usa para `database.sqlite` está en `getApplicationDocumentsDirectory()`, Android puede preservar el directory en upgrade (no en uninstall). Como el cliente online no usaba SQLite, el directorio estará vacío y la nueva app verá BD vacía → pantalla "Primer arranque". Verificado en smoke T050.
- **Tamaño APK**: el cliente online pesaba 43 MB. Sin `dio` ni `http`, pero con `drift` y `sqlite3_flutter_libs` (incluye binarios native), debería ser similar (~40-45 MB). Criterio de spec es < 50 MB. Si se excede, evaluar `--split-per-abi`.
- **Linux desktop sigue requiriendo libs del sistema** (libgtk-3-dev, libsecret-1-dev, sqlite3, etc.). Heredado del cliente online. No bloqueante para Android. Documentado en README como prerequisito opcional para dev en Linux desktop.
- **Hacer pivote sin perder histórico de git**: si la rama `legacy/web-and-online-flutter` no se pushea a `origin` antes de T004, perder el código en main equivale a perder el cliente online completo. Mitigación: T003 verifica `git log origin/legacy/web-and-online-flutter` antes de proceder.
- **Memoria desactualizada de los agentes futuros**: el CLAUDE.md raíz y las memorias deben quedar consistentes con la nueva era. La memoria ya se actualizó en este turno; T053 (CLAUDE.md raíz reescrito) cierra el círculo en el repo.

## Estrategia de pruebas

Cobertura por capa (detalle en `test-plan.md`):

- **Data layer (drift en memoria)**: CRUD por DAO, soft delete con filtros, cascada FK con `PRAGMA foreign_keys = ON`, validaciones de DAO (Bolsa singleton, OverpayDebt, closing != payment, archive con saldo cero).
- **Motor de saldos (`financial_state_test.dart`)**: BO/DE/CR con dataset variado, saldos por cuenta para cada uno de los 5 kinds (income, expense, credit_expense, debt_payment, transfer), entries cancelados no cuentan, cuentas archivadas no cuentan en agregados.
- **Backup (`backup_test.dart`)**: round-trip export → wipe → import → contenido idéntico (mismo set de UUIDs, mismos amounts, mismas fechas exactas con subsegundos). Import de JSON corrupto/vacío/versión desconocida NO toca la BD existente (transacción aborta).
- **Migración inicial con JSON real del backend**: test fixture que toma un sample del JSON que produce `/api/finance/backup/export` (snapshot guardado en `test/fixtures/backend_export_sample.json`) y verifica que importa sin pérdida.
- **Widget tests** (helper `testApp` con BD en memoria): first run import flow, first run "Arrancar limpio", dashboard con dataset → muestra BO/DE/CR + cuentas + entries, crear movimiento de cada kind desde entry_form, editar, cancelar, settings export → captura del JSON producido coincide con lo esperado.
- **Smoke manual en Android del usuario**: instalar APK release nuevo, primer arranque con el JSON real → BO/DE/CR coinciden con los del backend antes del pivote → crear gasto en modo avión → todo funciona → exportar nuevo backup → importar el nuevo → estado idéntico.

## Estrategia de rollback

Tres niveles de rollback disponibles:

1. **Rollback de código del sprint** (antes del merge a `main` desde la branch del sprint): `git reset --hard origin/main` deshace todo el trabajo del sprint. La rama `legacy/web-and-online-flutter` sigue existiendo en `origin` independiente.
2. **Rollback del pivote completo** (si Diego decide volver al modelo online en el futuro lejano): `git checkout legacy/web-and-online-flutter` y trabajar desde ahí. El código del cliente online + backend + Vue + Tailscale está intacto.
3. **Rollback de datos del usuario** (si la migración inicial sale mal): Diego conserva el JSON exportado fuera del repo. Si la BD local queda en estado raro, Settings → "Importar respaldo" → re-importa el JSON original → estado limpio.

Sin rollback automático de instalación Android: si el APK release del sprint nuevo deja la app en estado roto, el flujo de recuperación es:
- Desinstalar la app desde Android (perdiendo la BD local actual).
- Reinstalar APK del cliente online (queda solo si Diego conservó el `.apk` antiguo en disco).
- O reinstalar APK nuevo y re-importar el JSON.

## Orden sugerido de implementación

Fases secuenciales con dependencia estricta entre fases. Dentro de cada fase, varias tareas son paralelizables (anotadas en `tasks.md`).

1. **Fase 0 — Pre-pivote**: DESCARTADA. Diego no migra datos del backend.
2. **Fase 1 — Preservar legacy**: crear rama, push a origin, verificación remota.
3. **Fase 2 — Destruir legacy en main**: un solo commit que borra todo el código legacy.
4. **Fase 3 — Fundación Flutter local**: flutter create, applicationId, manifest, build.gradle, pubspec, build.yaml, analysis_options, scripts.
5. **Fase 4 — Portado desde legacy**: tema, catálogo, enums, widgets (vía `git show legacy/...`).
6. **Fase 5 — Capa de datos**: database.dart con tablas + índices, codegen, DAOs, StateService, backup, seed, bootstrap, AppDependencies.
7. **Fase 6 — Router y pantallas**: router con redirect a /first-run, FirstRunScreen, port de Dashboard/Accounts/Categories/Entries/Settings adaptando API→DAO.
8. **Fase 7 — Tests**: helpers (testApp, sqlite_override, factories), tests de DAOs, motor saldos, backup round-trip, widget tests, flutter analyze 0 issues.
9. **Fase 8 — Build release + smoke**: manifest validado, build APK, instalación en Android del usuario, smoke con JSON real importado, smoke modo avión.
10. **Fase 9 — Documentación + QR**: README mobile reescrito, CLAUDE.md raíz reescrito, branch-quality-review final.

## Casos borde que condicionan la solución

- **Diego pierde el JSON de un backup propio** (post-lanzamiento, cuando ya esté usando la app): si genera un export desde Settings y pierde el archivo antes de probar el restore, no hay reciclaje. Mitigación cultural: el botón Export muestra mensaje "Guardá este archivo en lugar seguro (Drive, email a vos mismo, etc.)". El flujo de Arrancar limpio queda disponible como reset si todo lo demás falla.
- **JSON corrupto / no es de FinCore / version desconocida**: import rechaza con mensaje específico y NO toca BD existente. Test específico en T041.
- **JSON con UUIDs duplicados** (en accounts o entries): import aborta porque la transacción de drift falla por PK conflict. Tratado como error de validación con mensaje claro.
- **JSON sin Bolsa** (improbable porque backend siempre la incluye): el importador detecta y crea la Bolsa default antes de aceptar las demás cuentas. O alternativa: aborta con mensaje "Backup inválido: falta Bolsa". A definir en T024 — se elige aborto para no enmascarar exports rotos.
- **Primer arranque sin Bolsa y usuario sale de la pantalla** (back button o swipe del task switcher): la próxima vez vuelve a `/first-run`. No hay forma de saltarla sin elegir una de las dos opciones.
- **Cancelar movimiento ya cancelado** (race entre dos sesiones de la misma app): no aplica en single-user single-device.
- **Crear cuenta con nombre exactamente igual a una archivada**: el constraint de unicidad del DAO debería permitirlo (la archivada está soft-deleted; el constraint es `UNIQUE(name) WHERE deleted_at IS NULL`). Verificar en T015.
- **Bolsa con saldo `NULL`** vs **saldo 0**: el `accountBalance` debe devolver 0 si no hay entries, no NULL. Verificar en T020.
- **Catálogo desactualizado**: si la BD tiene un `color_slug` o `icon_slug` que el código local no conoce (improbable si la migración inicial usa el catálogo del backend), el helper `colorBySlug` / `iconBySlug` devuelve fallback (gris + label_outline). Heredado del cliente online.
- **Fechas con subsegundos no preservadas** si build.yaml no está configurado: gotcha histórico de dogear. T010 lo previene.
- **Backup exportado con BD vacía**: se permite, el JSON queda con arrays vacíos. Al importarlo, BD queda vacía (excepto la Bolsa default si "Arrancar limpio" después). Aceptable.
- **Importar backup mientras la app está en mitad de un formulario**: el import requiere navegar a Settings, no hay manera de hacerlo "en paralelo". Aceptable.
- **`flutter test` corre en `/tmp` de la VM Linux donde no hay sqlite3 system library**: sin el override de `libsqlite3.so.0` desde dart, los tests fallan con "Failed to load dynamic library". Mitigación: T036 implementa el override.
- **`pumpAndSettle` cuelga con streams infinitos de drift**: aprendizaje de dogear. Widget tests usan `pump(Duration)` con timeout corto, no `pumpAndSettle()`. Documentado en testApp helper.
- **Tamaño APK > 50 MB**: si el build pesa más por incluir drift + sqlite3 nativos para todas las arches, evaluar `--split-per-abi`. Criterio de spec.

## Preguntas o supuestos que siguen afectando la implementación

Todas las preguntas (P-001..P-005) están cerradas. Los supuestos S-001..S-013 quedan vigentes, ninguno bloqueante. Posibles tensiones técnicas que podrían surgir durante implementación:

- **Si `drift ^2.20.0` exige Dart SDK 3.5+** (más nuevo del que Flutter 3.29.3 trae): anclar a una versión compatible (probablemente `drift ^2.15` si hace falta). Decisión durante T009.
- **Si `share_plus ^10` exige Kotlin 2.1+** (similar al gotcha de dogear): subir Kotlin en `android/settings.gradle.kts`. Decisión durante T007.
- **Si `file_picker` requiere permisos extra en Android 13+** (READ_MEDIA_IMAGES, etc.): se documenta como gotcha sin agregar el permiso al manifest del MVP (cero permisos extras es criterio de spec). Si bloquea, escalación.
- **Linux desktop no es target principal**: si T050 (`flutter run -d linux`) requiere libs de sistema que la VM no tiene, el smoke se hace solo en Android (el target real). Documentado como desviación menor en `implementation/`.

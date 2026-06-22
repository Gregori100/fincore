# Hardening v3 — widget tests + verificación de APK + cleanup defensivo del cache

## Resumen

Sprint técnico de continuidad sobre la app FinCore Flutter Android local-first. Cierra **4 ítems** del backlog del sprint anterior `flutter-local-hardening-v2` (commit `43b2c0e`, APK `0.3.6+38`):

1. **Widget test del `entry_form_screen`** (cancel + submit en modo edit) que blinda la regresión del gray screen detectada en smoke (iteraciones post-smoke #1-#2 del v2).
2. **Widget tests T043-T045 del MVP original** (dashboard, entry_form para los 5 kinds, listas de accounts/categories) aplazados desde el primer sprint.
3. **Script `scripts/verify-apk.sh`** con `aapt2` para detectar `INSTALL_FAILED_VERSION_DOWNGRADE` antes del sideload.
4. **`_ReplayBalanceStream.onCancel`** que libera la entrada del cache cuando se va el último listener (RF-002 hermano del cleanup del v2 — defensivo, sin reporte de bug).

Sin features visibles. Resultado esperado: harness de widget tests reusable + cobertura de UI + tooling local de validación de APK + cleanup defensivo del cache.

Queda **fuera de scope** (movido a backlog futuro): registrar `EntriesDao` en `@DriftDatabase(daos: [...])`. Bloqueado por el constructor de `EntriesDao` que requiere `FinancialStateService` (drift solo inyecta el database). Implica invertir la dependencia y tocar mucho código por una ganancia cosmética. Se evaluará en un sprint dedicado si surge necesidad.

## Problema a resolver

El sprint v2 cerró con 4 ítems no bloqueantes documentados en `engineering/specs/flutter-local-hardening-v2/implementation/pendientes.md`:

1. **Sin widget tests del `entry_form_screen`**: el bug del gray screen post-smoke (que causó 2 iteraciones de hotfix) habría sido detectado en tests si hubiera un widget test que cargara la pantalla en modo edit con `_kind = null` por el reset del `PopScope`. Hoy ninguna suite carga UI: solo se testean DAOs.
2. **T043-T045 del MVP aplazados**: los widget tests bootstrap de dashboard, entry_form (5 kinds) y listas siguen aplazados desde el primer sprint. Cualquier refactor de UI puede romper sin que la suite avise.
3. **Sin verificación local del APK**: durante el sprint v2 hubo varias iteraciones con `INSTALL_FAILED_VERSION_DOWNGRADE` por olvidar bumpear `versionCode` en `android/app/build.gradle.kts` además de `pubspec.yaml`. Flutter `--split-per-abi` prepende `2000` al `versionCode` para el arm64 (entonces `38` → APK `2038`), lo cual es no obvio.
4. **`_ReplayBalanceStream` sin `onCancel`**: el T007 del v2 pasa sin liberar la entrada del cache cuando se va el último listener. Hoy no se manifiesta porque los `StreamBuilder` viven mientras la pantalla está montada. Si en el futuro un caller hace subscribe/unsubscribe agresivo (ej. polling manual), puede aparecer `Bad state: Cannot add new events after calling close`.

Dejarlos abiertos arrastra dos consecuencias:
- **Cualquier sprint de UI nuevo** (probablemente reportes) repite la fricción de no tener harness de widget tests + no tener cobertura de las pantallas core.
- **Cualquier iteración de hotfix con sideload rápido** vuelve a tropezar con el `INSTALL_FAILED_VERSION_DOWNGRADE` sin pista clara.

El sprint v3 cierra los 4 con cambios localizados y deja el codebase listo para arrancar el sprint de **reportes** sin arrastrar deuda de UI no testeada.

## Objetivo

- Crear un **harness de widget tests** (mock de `AppDependencies`, BD in-memory, `MaterialApp.router` de prueba) que sirva como base para el v3 y para sprints futuros de UI.
- Cubrir con widget tests las pantallas core: `entry_form_screen` (cancel + submit + los 5 kinds), `dashboard_screen` (BO/DE/CR), `accounts_list_screen`, `categories_list_screen`.
- Agregar `scripts/verify-apk.sh` que valida `versionCode` del APK construido contra el esperado (con el prefix `2000` del `--split-per-abi` arm64) y falla con error claro si no coincide.
- Agregar `onCancel` en `_ReplayBalanceStream` que libera la entrada del cache de `FinancialStateService` cuando se va el último listener + test de subscribe/unsubscribe/resubscribe.
- Bumpear a `0.3.7+39` (patch, sin features ni breaking).
- Mantener `flutter analyze` limpio. Subir suite de tests de **93 → ≥ 100 verdes** (4 widget tests nuevos del harness + 1 test del cache + 2 widget tests adicionales mínimos del MVP).

## Alcance

- Crear `mobile/test/helpers/widget_test_harness.dart` con factory `buildTestApp({initialRoute, seedFn})` que monta la app con BD in-memory y router de prueba.
- Widget test `entry_form_screen` en modo edit: simular toque a "Cancelar movimiento" y a "Guardar cambios", verificar que la pantalla cierra sin crash. **Bloqueador de la regresión gray screen.**
- Widget tests T043-T045 del MVP (mínimo deseable):
  - **T043 — dashboard**: BD vacía vs con datos sembrados; verificar BO/DE/CR rendereado correctamente.
  - **T044 — entry_form**: para cada uno de los 5 kinds (`income`, `expense`, `credit_expense`, `debt_payment`, `transfer`), montar form en `/entries/new`, seleccionar kind, verificar que el `AccountPicker` muestra las cuentas correctas según RN-011.
  - **T045 — listas**: `accounts_list_screen` y `categories_list_screen` con BD sembrada; verificar que la lista rendea las filas + tap navega al form de edición.
- `scripts/verify-apk.sh`: lee `versionCode` esperado desde `mobile/pubspec.yaml` (`+N`), ejecuta `aapt2 dump badging` sobre el APK arm64 construido, compara con `2000 + N`, falla con mensaje claro si no coincide.
- `_ReplayBalanceStream.onCancel`: cuando el último listener cancela, llamar callback opcional `onLastListenerCanceled` que `FinancialStateService` usa para `_balanceCache.remove(accountId)`. Test que valida subscribe → unsubscribe → re-subscribe genera nuevo stream y entrega valores.
- Bump a `0.3.7+39` (`pubspec.yaml` + `android/app/build.gradle.kts`).
- Build APK release split-per-abi y validar con el nuevo script.

## Fuera de alcance

- **Registrar `EntriesDao` en `@DriftDatabase(daos: [...])`**: queda diferido. Implica invertir la dependencia con `FinancialStateService`. Riesgo alto por ganancia cosmética.
- **Widget tests exhaustivos de cada CRUD**: el alcance del MVP era "bootstrap test" por pantalla, no cobertura de cada flujo. Los tests del v3 cubren el flujo principal de cada pantalla, no todas las variantes.
- **Tests de integración E2E** (Patrol, `integration_test`): scope distinto. Los widget tests del sprint usan `flutter_test` puro.
- **CI con GitHub Actions o similar**: el script `verify-apk.sh` se ejecuta localmente. Pipeline real queda para un sprint dedicado si se decide publicar a Play Store.
- **Refactor de la inyección de dependencias** (`get_it`, `provider`, `riverpod`): el harness reusa el patrón actual `AppDependencies`. No introduce framework nuevo.
- **Features nuevas**: reportes, filtros adicionales, multi-usuario, sync con backend — todo backlog de producto.
- **Migraciones de schema, cambios en DAOs**: no se tocan. El sprint es estrictamente de testing + tooling + un cleanup defensivo.

## Reglas de negocio

Las reglas del MVP + RN-H01/H02/H03 + lo agregado en v1/v2 no cambian. Este sprint NO introduce nuevas reglas de negocio. Solo agrega tests defensivos que validan que las reglas existentes se cumplen desde la UI.

## Requisitos funcionales

### Familia 1 — Harness de widget tests (T001)

- **RF-001**: crear `mobile/test/helpers/widget_test_harness.dart` con función pública `Future<void> pumpFincoreApp(WidgetTester tester, {String initialRoute = '/dashboard', void Function(AppDatabase db)? seed})`. El harness:
  - Inicializa `AppDatabase` con `NativeDatabase.memory()`.
  - Llama opcionalmente `seed(db)` para sembrar datos antes del primer build.
  - Construye `AppDependencies` con los DAOs reales sobre la BD in-memory.
  - Monta `MaterialApp.router(routerConfig: ...)` con el router de la app pero arrancando en `initialRoute`.
  - Llama `tester.pumpAndSettle()` y deja la app lista para interactuar.
- **RF-002**: la inicialización de SQLite en tests sigue el patrón `test/helpers/sqlite_override.dart` que ya existe en el proyecto (override de `libsqlite3.so.0` para Linux desktop). El harness reutiliza este helper sin duplicar.

### Familia 2 — Widget test del entry_form_screen edit (T002)

- **RF-003**: agregar `mobile/test/screens/entry_form_screen_test.dart` con dos tests:
  - **Cancel en edit**: sembrar 1 income, navegar a `/entries/$id/edit`, encontrar y tocar "Cancelar movimiento", confirmar el diálogo, verificar que `EntryFormScreen` ya no existe en el tree.
  - **Submit en edit**: sembrar 1 expense, navegar a `/entries/$id/edit`, modificar el monto, tocar "Guardar cambios", verificar que `EntryFormScreen` ya no existe en el tree.
- **RF-004**: los tests deben fallar si se reintroduce la regresión del gray screen (build con `_kind = null` en modo edit). El harness debe propagar los errores de `_buildForm` para que el test los capture en lugar de renderear silenciosamente un ErrorWidget gris.

### Familia 3 — Widget tests T043-T045 del MVP (T003-T005)

- **RF-005** (T043 dashboard): agregar `mobile/test/screens/dashboard_screen_test.dart` con:
  - **BD vacía**: montar `/dashboard`, verificar que la lista de cuentas muestra solo "Bolsa" (creada por seed default), BO = $0.00.
  - **Con datos**: sembrar bolsa + 1 ingreso de $1000, montar `/dashboard`, verificar BO = $1000.00, DE = $0.00, CR = $0.00.
- **RF-006** (T044 entry_form 5 kinds): agregar `mobile/test/screens/entry_form_kinds_test.dart` con 5 tests, uno por kind. Cada test:
  - Siembra una bolsa (cash) + un debit + un credit + categorías.
  - Monta `/entries/new`.
  - Selecciona el kind correspondiente con el `KindPicker`.
  - Verifica que el `AccountPicker` origen y destino muestran solo las cuentas válidas según RN-011 (income: dest cash/debit; expense: orig cash/debit; credit_expense: orig credit; debt_payment: orig cash/debit + dest credit; transfer: orig cash/debit + dest cash/debit).
- **RF-007** (T045 listas): agregar `mobile/test/screens/accounts_list_screen_test.dart` y `mobile/test/screens/categories_list_screen_test.dart` con:
  - Sembrar BD con N cuentas/categorías.
  - Montar la pantalla, verificar que cada nombre aparece en el tree.
  - Tap sobre una fila navega al form de edición correspondiente (`/accounts/$id/edit` o `/categories/$id/edit`).

### Familia 4 — Script verify-apk.sh (T006)

- **RF-008**: crear `scripts/verify-apk.sh` en la raíz del repo. El script:
  - Lee la versión desde `mobile/pubspec.yaml` (línea `version: X.Y.Z+N`).
  - Recibe como argumento la ruta al APK construido (default: `mobile/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`).
  - Ejecuta `~/Android/Sdk/build-tools/<latest>/aapt2 dump badging <apk>`, extrae `versionCode='<X>'`.
  - Compara con `2000 + N` (prefix de arm64 con `--split-per-abi`).
  - Imprime OK con la versión esperada vs encontrada y exit 0 si coincide.
  - Imprime ERROR con la diferencia y exit 1 si no coincide.
  - El script es bash POSIX-ish con `set -euo pipefail`.
- **RF-009**: el script tolera que `aapt2` no esté en el PATH (busca en `~/Android/Sdk/build-tools/*/aapt2`, agarra la versión más nueva). Si no encuentra, imprime instrucciones para instalar Android SDK build tools y exit 2.

### Familia 5 — onCancel en _ReplayBalanceStream (T007)

- **RF-010**: en `mobile/lib/data/financial_state.dart`, agregar al constructor de `_ReplayBalanceStream` un parámetro opcional `void Function()? onLastListenerCanceled`. Cuando el `Set<MultiStreamController> _listeners` queda vacío tras un `.remove(controller)`:
  - Cancelar `_upstreamSub` (liberar la suscripción a drift).
  - Setear `_upstreamSub = null`.
  - Resetear `_last = null` (la próxima suscripción re-bootstrappea desde drift).
  - Llamar `onLastListenerCanceled?.call()` para que `FinancialStateService` saque la entry del `_balanceCache`.
- **RF-011**: en `FinancialStateService.watchAccountBalance(accountId, accountType)`, cuando se crea un `_ReplayBalanceStream` nuevo, pasarle `onLastListenerCanceled: () => _balanceCache.remove(cacheKey)`. La key del cache es `(accountId, accountType)` (string concatenado o record). Documentar el patrón en `CLAUDE.md` (sección "Capa de datos") como nota de implementación.
- **RF-012**: agregar test `subscribe → unsubscribe → re-subscribe genera nuevo stream broadcast funcional` en `mobile/test/data/financial_state_test.dart`. Verifica que tras cancelar el último listener, una nueva llamada a `watchAccountBalance` retorna un Stream que sí entrega valores (no un Stream cerrado). Comprobar `identical(s1, s2) == false` por defecto (porque la entry se limpió del cache).

### Familia 6 — Bump de versión + smoke (T008-T010)

- **RF-013**: bumpear a `0.3.7+39` en `mobile/pubspec.yaml` y `mobile/android/app/build.gradle.kts` (`versionCode = 39`, `versionName = "0.3.7"`).
- **RF-014**: ejecutar `flutter build apk --release --split-per-abi` y validar con `scripts/verify-apk.sh`. Smoke en Redmi: instalar el APK arm64, verificar que la app abre, Dashboard responde, "Acerca de" muestra `0.3.7+39`. No requiere replicar el smoke completo del v2 (los tests defensivos del v3 ya cubren los flujos críticos).

## Casos principales

1. **Detección automática de regresión del gray screen**: cualquier PR futura que rompa la lógica del `PopScope` en `entry_form_screen` falla el test del RF-003 antes de llegar al smoke manual.
2. **Cobertura mínima de UI**: refactorizar el `KindPicker` o el `AccountPicker` ya no requiere validar manualmente los 5 kinds en el cel — los 5 tests del RF-006 lo hacen.
3. **Build APK con downgrade detectado**: si Diego olvida bumpear `versionCode` en `build.gradle.kts` antes de `flutter build`, el `verify-apk.sh` lo detecta antes del `adb install` y muestra el mismatch con el valor esperado.
4. **Cleanup defensivo del cache**: si en el futuro una pantalla de reportes hace subscribe/unsubscribe agresivo al mismo balance, el cache se libera limpiamente y el siguiente subscribe arma un stream nuevo.

## Casos borde

- **`pumpFincoreApp` con seed que falla**: si el seed lanza, el test debe fallar con el error original del seed, no con un timeout de `pumpAndSettle()`. Validar que `tester.pumpAndSettle()` propaga el error.
- **Widget test en CI/headless**: el `sqlite_override.dart` ya cubre Linux desktop. Si en el futuro se corre en CI con Docker, validar que la lib de SQLite está disponible. Fuera de scope ahora.
- **`AppDependencies` con DAOs reales sobre BD in-memory**: el seed por default debe incluir Bolsa (singleton creada por `seedDefaults`). Los tests del dashboard asumen esto.
- **`KindPicker` no editable en modo edit**: el test del RF-006 monta `/entries/new`, no `/entries/$id/edit`. El kind solo es seleccionable en alta.
- **`verify-apk.sh` con `aapt2` en path raro**: si Diego tiene Android SDK en `/opt/android-sdk` o similar, agregar variable de entorno `ANDROID_HOME` para override. Por default busca en `~/Android/Sdk/build-tools/*/aapt2`.
- **`_ReplayBalanceStream` con todos los listeners cancelados y reset_async pendiente**: si un evento upstream llega entre el `_upstreamSub.cancel()` y la nueva subscripción, debe ignorarse limpiamente. El cancel del sub debe ser síncrono.
- **APK validado contra versión incorrecta de pubspec**: si Diego edita `build.gradle.kts` pero olvida `pubspec.yaml`, el script detecta el mismatch y exit 1. Caso opuesto: misma detección.

## Criterios de aceptacion

- `flutter test` ejecuta y reporta **al menos 100 tests verdes** (93 actuales + 7 mínimos: 2 del RF-003, 2 del RF-005, 5 del RF-006 (uno por kind), 2 del RF-007 (accounts + categories), 1 del RF-012). Total estimado: 102-105.
- `flutter analyze` reporta 0 errores. Los hints info preexistentes permanecen aceptables.
- `scripts/verify-apk.sh` exit 0 cuando se le pasa el APK arm64 del `0.3.7+39` recién construido. Imprime `versionCode esperado: 2039, encontrado: 2039 ✓`.
- `flutter build apk --release --split-per-abi` produce APK arm64 con `versionCode = 39` (real `2039`) y `versionName = "0.3.7"`.
- APK arm64 instala limpiamente sobre el `0.3.6+38` previamente instalado en el Redmi sin perder datos.
- Manual mínimo: Dashboard abre, "Acerca de" muestra `0.3.7+39`. No se requiere replicar el smoke completo del v2.
- Documentación: `engineering/specs/flutter-local-hardening-v3/implementation/` contiene `progreso.md`, `pendientes.md`, `pruebas.md`, `desviaciones-plan.md` (vacío si no hay desviaciones), `resumen-ejecutivo.md`, `resumen-extenso.md`.
- `CLAUDE.md` recibe una nota en la sección "Capa de datos" sobre el patrón `onLastListenerCanceled` del cache de streams.
- Repositorio: los 4 ítems del backlog quedan referenciados como cerrados. El ítem 5 (registrar `EntriesDao` en `@DriftDatabase`) queda explícito en `pendientes.md` como diferido a un sprint dedicado.

## Criterios medibles de exito

- **Cobertura de tests**: de 93 → ≥ 100 verdes (≥ 7.5 % de crecimiento). Los widget tests defensivos cubren los flujos de UI que hoy solo se validan en smoke manual.
- **Harness de widget tests reusable**: 1 archivo (`widget_test_harness.dart`) que cualquier sprint futuro de UI puede importar para montar la app con BD in-memory en 1 línea.
- **Detección de version downgrade**: tiempo entre "olvidé bumpear versionCode" y "lo descubro" pasa de "tras `adb install -r` fallido" a "antes del install, en el output del script".
- **Robustez del cache de streams**: capacidad demostrable de manejar subscribe/unsubscribe/resubscribe sin leak ni stream cerrado.

## Riesgos

- **`pumpFincoreApp` complejo de implementar**: `AppDependencies` hoy se inicializa en `main.dart` con BD real. El harness necesita inyectarla con BD in-memory sin modificar el `main.dart`. Mitigación: si `AppDependencies` no acepta inyección, agregar constructor `AppDependencies.forTesting({required AppDatabase db})` en una línea.
- **Router de la app con `refreshListenable` complejo**: `FirstRunState` requiere `hasBolsa()` async. El harness debe esperar a que resuelva antes de buildear, o sembrar Bolsa de entrada (default cuando el caller no pasa `seed`). Mitigación: por default el harness siembra Bolsa, lo cual cubre el 95 % de los casos.
- **Tests del `entry_form_screen` con widgets internos privados** (`_kind`, `_isEdit`): no hay acceso directo desde el test. Mitigación: testear el comportamiento observable (form cerrado, snackbar visible) en lugar del estado interno.
- **`aapt2` no presente en Sdk de Diego**: si la build tools instalada no incluye `aapt2`, el script falla con instrucciones. Mitigación: el `flutter build apk` ya lo usa internamente, así que está instalado. Pero documentar la dependencia.
- **`onLastListenerCanceled` cancelando entry del cache mientras otro caller está leyendo `_balanceCache[k]`**: race condition entre el `onLastListenerCanceled` y un `_balanceCache.putIfAbsent`. Mitigación: el Map de Dart es single-threaded por isolate; no hay race real. Pero si en el futuro se hace `compute()` con isolates separados, evaluar. Por ahora seguro.
- **Bump a `0.3.7+39` con `flutter pub upgrade` involuntario**: si entre v2 y v3 alguna dep sufre un bump remoto, `flutter pub get` puede traer una nueva versión menor. Mitigación: revisar `pubspec.lock` antes del build final.

## Supuestos

- **Versionado**: `0.3.7+39` aceptado por Diego. Patch porque son fixes técnicos sin features ni breaking changes.
- **`AppDependencies` inyectable**: si la clase actual no permite inyectar la BD desde tests, se agrega un constructor `forTesting`. Cambio menor.
- **`scripts/verify-apk.sh` corre solo en Linux desktop**: el script usa rutas tipo `~/Android/Sdk/...`. Si Diego cambia de máquina o de OS, ajustar el script. Por ahora asume el setup actual.
- **`FirstRunState` con BD vacía y BD sembrada con Bolsa**: el harness por default siembra Bolsa para evitar el redirect a `/first-run`. Tests que quieren probar el first-run pasan `seed: (db) => null` (sin siembra) y montan `/splash`.
- **Tests pueden agotar el batch de drift `customSelect`**: si la suite ejecuta 100+ tests y cada uno crea/destruye BD in-memory, el límite del file descriptor de SQLite no se toca (in-memory). Sin riesgo material.

## Impacto esperado

- **Cobertura de tests** sube a ≥ 100 verdes; el harness de widget tests queda disponible para todos los sprints futuros de UI.
- **Deuda técnica residual del v2** pasa de 4 ítems a 1 (registrar `EntriesDao`, diferido a sprint dedicado si surge necesidad).
- **Tiempo de iteración con APKs** baja: el `verify-apk.sh` evita el ciclo "build → install → INSTALL_FAILED → diagnóstico → bump → rebuild".
- **Robustez del cache de streams** queda preparada para features que hagan subscribe/unsubscribe agresivo (ej. reportes con múltiples vistas).
- **Cero impacto visible para el usuario** salvo el bump de versión en Settings → "Acerca de".

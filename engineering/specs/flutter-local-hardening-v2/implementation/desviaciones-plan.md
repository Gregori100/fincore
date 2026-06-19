# Desviaciones del plan — flutter-local-hardening-v2

Diferencias entre `plan/tasks.md` y la implementación real, con razón y mitigación.

## Fase 0 — Registro parcial de DAOs en `@DriftDatabase`

- **Plan original**: registrar `daos: [AccountsDao, CategoriesDao, EntriesDao]` en `@DriftDatabase` (T001 / RF-007).
- **Real**: registrar solo `daos: [AccountsDao, CategoriesDao]`. `EntriesDao` queda fuera.
- **Razón**: drift codegen genera el constructor `EntriesDao(this as FincoreDatabase)` con un solo argumento (la database), pero el constructor real es `EntriesDao(super.db, this._state)` y requiere también `FinancialStateService`. El intento de codegen completo falla con `Too few positional arguments: 2 required, 1 given` en `database.g.dart:2095`.
- **Mitigación**:
  - RF-008 (reemplazar query inline por `attachedDatabase.categoriesDao.findActiveById`) sigue cubierto porque `CategoriesDao` sí se registra.
  - `EntriesDao` sigue accesible vía `AppDependencies.of(context).entriesDao` (sin cambio).
  - El `@DriftDatabase` lleva comentario explicando el motivo del registro parcial, para que un futuro mantenedor no agregue `EntriesDao` y rompa el build.
- **Sin impacto en RFs**: el objetivo del sprint sigue cubierto.

## Post-smoke (2026-06-19) — "Pantalla gris muerto" tras cancelar/editar movimiento (causa raíz real)

Tras instalar `0.3.2+34` (replay-1) Diego confirmó que el bug seguía: al cancelar O editar un movimiento, **toda la pantalla quedaba gris pleno** (sin AppBar, sin FAB, sin Skeleton animado, app congelada pero hardware back funciona y vuelve a Dashboard/entries).

- **Causa raíz real**: race en `entry_form_screen.dart` entre `PopScope.canPop` y `_saving`.
  1. `_cancel`/`_submit` setea `_saving = true` → `PopScope.canPop = (_isEdit || _kind == null) && !_saving` pasa a `false`.
  2. Tras el `await deps.entriesDao.cancel/updateEntry(...)`, llama `Navigator.maybePop()`.
  3. El pop es **bloqueado** por PopScope (canPop=false). Flutter dispara `onPopInvokedWithResult(didPop: false, ...)`.
  4. El callback resetea **el form completo** (`_kind = null`, `_originId = null`, etc.) pensando que era un back desde alta sin kind elegido.
  5. `finally` setea `_saving = false` y rebuild.
  6. Como `_isEdit == true`, el build entra al `else _buildForm()`. `_buildForm` arranca con `final k = _kind!;` → **null check exception**.
  7. En release, Flutter renderiza el `ErrorWidget` que es **gris pleno sin children**. Diego ve la pantalla gris.
- **Fix** (commit `0.3.3+35`):
  - `_cancel` y `_submit` ahora hacen `setState(() => _saving = false)` **antes** de `Navigator.maybePop()`, así `canPop` pasa a `true` y el pop ocurre normalmente. El `finally` lo hace de nuevo de forma idempotente si seguimos montados tras una excepción.
  - `PopScope.onPopInvokedWithResult` ahora retorna temprano si `_isEdit` o si `_kind == null`. Solo resetea el form en el caso original: alta con kind ya elegido, back desde el form.
- **Sobre el replay-1 (`_ReplayBalanceStream`)**: el fix anterior (`0.3.2+34`) introdujo replay-1 en `watchAccountBalance` pensando que el bug era de stream broadcast sin replay. Resultó ser un diagnóstico incorrecto del síntoma. Igualmente se conserva el replay-1 como protección defensiva: cubre escenarios reales donde un `StreamBuilder` se monta tarde y debería recibir el último valor cacheado sin esperar a un cambio en `journal_entries`. Cubierto por test "replay-1: nuevo suscriptor recibe el último valor cacheado".
- **Bump**: `0.3.2+34` → `0.3.3+35`. APK rebuildeado y verificado (`versionCode='2035'`, `versionName='0.3.3'`).
- **Tests**: 92/92 verdes (el bug es de UI, no cubierto por unit tests; un widget test del `entry_form_screen` cancel/submit lo defendería — queda en `pendientes.md`).

### Iteración `0.3.6+38` — `StreamController.broadcast.onListen` no triggera con suscripciones simultáneas

Tras instalar `0.3.5+37`, Diego confirmó que el Skeleton del hint aparecía pero **nunca era reemplazado por el monto real**. El cambio del frame anterior solo cambió el síntoma (`$0.00` → Skeleton) pero el bug subyacente persistía: el segundo suscriptor al stream cacheado nunca recibía el valor cacheado.

- **Causa**: `StreamController.broadcast(onListen: _onListen)` invoca `onListen` **solo cuando un listener llega tras un período de cero listeners**. Cuando Diego abre el form de alta, el Dashboard mantiene sus `_BalanceLabel` suscritos (go_router con push no desmonta el widget anterior). Al seleccionar una cuenta en el form, el `AccountBalanceHint` se suscribe al mismo stream cacheado → como ya había listeners (los del Dashboard), `onListen` NO se invoca → no hay replay del `_last` → el StreamBuilder del hint queda esperando el próximo cambio en `journal_entries` que típicamente nunca llega. Mi test previo "replay-1" no capturaba esto porque cancelaba el primer listener antes de suscribir el segundo, dejando el controller en estado de cero listeners.
- **Fix**: `_ReplayBalanceStream` re-implementado con `Stream<double>.multi(_handleListen, isBroadcast: true)`. `Stream.multi` invoca `_handleListen` **por cada `.listen()`**, no solo con el primero. Cada nuevo suscriptor recibe un `MultiStreamController` propio donde el replay del `_last` se escribe individualmente con `addSync(last)`. El upstream a drift se mantiene lazy (`_ensureUpstream()`) y se cancela en `dispose()`. Forward del valor a todos los listeners actuales con un set `_listeners`.
- **Test defensivo** (`financial_state_test.dart`): "replay-1: segundo suscriptor recibe último valor SIN cancelar el primero". Suscribe A, recibe valor 500, SIN cancelar A entra B y debe recibir 500 inmediatamente. Después se registra un income más y ambos reciben 600.
- **Bump**: `0.3.5+37` → `0.3.6+38`. APK verificado (`versionCode='2038'`, `versionName='0.3.6'`).
- **Tests**: 92 → **93 verdes**.

### Iteración `0.3.5+37` — `AccountBalanceHint` mostraba "0" falso en el primer frame

Tras instalar `0.3.4+36`, Diego reportó que al abrir el form de alta y seleccionar una cuenta, el hint debajo del picker mostraba `Saldo: $0.00` cuando esperaba un número distinto.

- **Causa**: `account_balance_hint.dart` hacía `final balance = snapshot.data ?? 0.0;`. El primer frame del `StreamBuilder` siempre tiene `snapshot.data == null` porque el valor del replay-1 llega vía `scheduleMicrotask` en el siguiente turno del event loop. El antiguo fallback `?? 0.0` pintaba "Saldo: $0.00" durante ese primer frame y confundía a Diego (cuando la cuenta tenía saldo distinto de cero).
- **Fix**: el `StreamBuilder` ahora muestra `Skeleton(width: 90, height: 12)` mientras `!snapshot.hasData`, consistente con `_BalanceLabel` y `_TotalCard` del Dashboard. En cuanto llega el valor real (típicamente 1 microtask después si el cache lo tenía, o 1-2 frames si es la primera vez), reemplaza por el monto formateado.
- **Aclaración de fórmula**: el balance es el agregado total instantáneo, sin filtro de fecha. Movimientos futuros también suman (decisión de producto a confirmar en sprint de reportes).
- **Bump**: `0.3.4+36` → `0.3.5+37`. APK verificado (`versionCode='2037'`, `versionName='0.3.5'`).
- **Tests**: 92/92 verdes.

### Iteración `0.3.4+36` — `setState` no es síncrono con el rebuild

Tras instalar `0.3.3+35`, Diego confirmó que la pantalla gris desapareció PERO el form **no se cerraba** tras el cancel/submit: aparecía el snackbar verde y la pantalla de edición seguía visible.

- **Causa**: `setState(() => _saving = false)` marca el state como dirty pero el rebuild ocurre **en el próximo frame**. Al llamar `Navigator.maybePop()` en la misma línea, el `PopScope` aún tiene `canPop = false` (frame anterior) → el pop se bloqueaba. Esta vez sin daño visible porque el `onPopInvokedWithResult` ahora retorna temprano en `_isEdit`, pero la ventana quedaba abierta.
- **Fix**: el `maybePop` ahora se agenda con `WidgetsBinding.instance.addPostFrameCallback`, garantizando que se ejecuta tras el rebuild que aplica `_saving = false`. En ese frame `PopScope.canPop = true` y el pop ocurre limpiamente.
- **Bump**: `0.3.3+35` → `0.3.4+36`. APK verificado (`versionCode='2036'`, `versionName='0.3.4'`).
- **UX confirmado**: cerrar el form tras snackbar de éxito **sí** es el patrón Material Design correcto. La confirmación va por snackbar, no por dejar el form abierto.

## Post-smoke (2026-06-19) — Regresión "vista en gris" tras cancelar movimiento (diagnóstico incorrecto, ver sección arriba)

Diego detectó durante T015 el siguiente bug: al cancelar un movimiento desde `entry_form_screen` y volver al Dashboard, las cuentas mostraban Skeleton (vista gris) en vez del balance actualizado.

- **Causa raíz**: `.asBroadcastStream()` simple sobre el `customSelect.watchSingle()` cacheado no replay el último valor a suscriptores nuevos. Flujo:
  1. Dashboard montado → cada `_BalanceLabel` suscribe al stream cacheado → recibe primer valor → muestra balance.
  2. Navegación a `/entries/:id/edit` → Dashboard desmonta, suscripciones cancelan.
  3. `entriesDao.cancel(...)` ejecuta dentro de transacción → drift emite nuevo evento al broadcast con cero listeners → evento se pierde.
  4. `Navigator.pop()` → Dashboard re-monta → re-suscribe al broadcast → `snap.hasData == false` (sin replay) → renderiza `Skeleton` hasta el próximo cambio en `journal_entries`.
- **Fix**: `mobile/lib/data/financial_state.dart` ahora envuelve cada source de drift en `_ReplayBalanceStream`: un `StreamController.broadcast` propio que guarda el último valor emitido y lo re-emite vía `scheduleMicrotask` cuando un nuevo listener llega. `invalidateAccount` / `invalidateAll` ahora llaman `dispose()` para cancelar el upstream y cerrar el controller.
- **Test defensivo** (`financial_state_test.dart`): "replay-1: nuevo suscriptor recibe el último valor cacheado sin esperar nuevos cambios". Suscribe, recibe valor inicial, cancela, dispara un income SIN listeners, re-suscribe y verifica que el nuevo listener recibe el valor actualizado por replay.
- **Bump**: `0.3.1+33` → `0.3.2+34`. Patch porque el cambio es un fix con cobertura de test, sin features nuevas. APK rebuildeado y verificado con `aapt2` (`versionCode='2034'`, `versionName='0.3.2'`).
- **Tests**: 91 → 92 verdes.

## Post-review — Mejoras M1, M2, M3 del quality review

El `branch-quality-review` (T017) detectó 3 hallazgos `Media` que se aplicaron en la misma sesión:

- **M1 — `characters` como dependencia directa**: `mobile/pubspec.yaml` la declaraba implícitamente vía Flutter SDK (transitive). Se agregó `characters: ^1.4.0` en `dependencies:` para evitar warning de `depend_on_referenced_packages` y blindar contra cambios futuros del SDK.
- **M2 — DAOs canónicos del codegen en `AppDependencies`**: `app_dependencies.dart` instanciaba `AccountsDao(database)` y `CategoriesDao(database)` manualmente, lo que creaba 2 instancias paralelas a las generadas por `@DriftDatabase(daos: [...])`. Se reemplazó por `database.accountsDao` y `database.categoriesDao`. `EntriesDao` queda manual por incompatibilidad de constructor (ver desviación de Fase 0).
- **M3 — Test endurecido de 200 chars exactos**: `backup_test.dart` usaba `try/catch` que daba verde si el import lanzaba por una excepción ajena a `string_too_long`. Se cambió a assert directo sobre `ImportReport.categoriesCount == 1` + verificación del nombre persistido en la BD.

Las 3 mejoras se validaron con `flutter analyze` (0 errores, 5 hints info preexistentes) y `flutter test` (91/91 verdes). APK rebuildeado y verificado con `aapt2`.

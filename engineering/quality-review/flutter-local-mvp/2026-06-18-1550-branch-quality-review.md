# Branch Quality Review: flutter-local-mvp

## Metadata

- Fecha: 2026-06-18 15:50 CDMX
- Rama revisada: `main`
- Rama base: pre-pivote (`b02eb42` y previos)
- Rango: HEAD = `bec19a1` (commit del pivote). Todo el sprint está como **working tree changes + untracked** (no hay commits adicionales). El review aplica al árbol pendiente de commit.
- Commit HEAD: `bec19a1d12a799ec6183531c47a87a764008ec23`
- Autor de revisión: skill `branch-quality-review` con 6 subagentes en paralelo
- Carpeta de reporte: `engineering/quality-review/flutter-local-mvp/`

## Resumen ejecutivo

- El sprint ejecuta el pivote completo de FinCore a app Flutter Android local-first con SQLite/drift. Capa de datos cubierta por **56 tests verdes**, `flutter analyze` limpio, APK 19.5 MB validado en smoke manual por Diego en el Redmi.
- Hay **1 bloqueante crítico de exposición de secretos** (`.gitignore` raíz simplificado de más, `.env.tailscale` contiene `APP_KEY` y queda sin proteger contra `git add -A`).
- **4 hallazgos altos adicionales** sobre integridad transaccional (`OverpayDebt` y `archive` con check+write fuera de la misma transacción) y robustez (PopScope no bloquea back durante save, `wipeAll()` sin test).
- La filosofía single-user / UI-thread mitiga los race conditions, pero los hallazgos quedan como **deuda explícita** para no perderlos cuando aparezca sync con backend.
- La rama es **entregable tras resolver el bloqueante** B1 (cosmético de minutos). El resto puede ir al backlog del próximo sprint sin bloquear la salida del MVP.

## Alcance revisado

- Commits: ninguno (todo working tree). Revisión sobre el árbol pendiente.
- Archivos principales:
  - `mobile/lib/data/` (database, daos, financial_state, backup, uuid)
  - `mobile/lib/screens/` (entry_form, settings, dashboard, entries_list, accounts_list, first_run)
  - `mobile/lib/widgets/` (error_snackbar, account_picker, category_picker, skeleton)
  - `mobile/android/app/build.gradle.kts` + `AndroidManifest.xml`
  - `mobile/pubspec.yaml` + `build.yaml`
  - `mobile/test/data/` (4 suites)
  - `.gitignore`, `CLAUDE.md`, `README.md` raíz
  - `engineering/specs/flutter-local-mvp/implementation/` (6 archivos)
- Áreas: seguridad/secretos, concurrencia/transacciones, SQL/performance, UX/frontend, tests/cobertura, build/docs.
- Comandos usados:
  - `git status --short`, `git log`, `git rev-parse`, `git diff --stat`, `git check-ignore -v`
  - `grep -rn`, `head`, `ls -la`
  - Lectura directa de archivos críticos del DAO, backup, screens y manifest.

## Hallazgos bloqueantes

> **Status post-review (2026-06-18)**: los 5 bloqueantes fueron corregidos en la versión `0.2.0+28`. El detalle de cada fix está al final de cada hallazgo en la sección "Fix aplicado".

### B1. `.gitignore` raíz no protege `.env.tailscale` con APP_KEY ni `.env`

- Severidad: **Crítica**
- Área: secretos / versionamiento
- Evidencia:
  - `.gitignore` (raíz) ahora solo contiene IDE/OS ignores y un comentario. Antes del cambio del sprint exigía explícitamente `/.env` y `/.env.tailscale`.
  - `git status --short` lista `?? .env` y `?? .env.tailscale` como untracked en el árbol actual.
  - `.env.tailscale` cabecera: _"Variables del stack productivo casero... Este archivo NO se commitea (.gitignore lo excluye)."_ — el comentario interno asume protección que ya no existe.
  - `.env.tailscale` contiene `APP_KEY=base64:...` y credenciales del stack Tailscale (según el reporte del subagente de seguridad y la inspección de la cabecera).
- Riesgo: un `git add -A` o `git add .` desde la raíz **commitea ambos archivos con secretos al historial**. Como no hay base remota nueva (HEAD = `bec19a1`), aún no se publicó, pero el primer push después de cerrar el sprint los expondría.
- Recomendación: agregar al `.gitignore` raíz antes de cualquier commit del sprint:
  ```
  .env
  .env.tailscale
  *.ts.net.crt
  *.ts.net.key
  .phpunit.result.cache
  .playwright-mcp/
  ```
  Verificar con `git check-ignore -v .env .env.tailscale` que ambos quedan ignorados antes de hacer `git add`. Si por accidente ya se hizo `git add` de alguno, removerlo del index con `git rm --cached .env .env.tailscale`.
- Depende de: nada. Resolver primero antes de cualquier `git add`.
- **Fix aplicado**: agregadas las reglas `.env`, `.env.tailscale`, `*.ts.net.crt`, `*.ts.net.key`, `.phpunit.result.cache`, `.playwright-mcp/` al `.gitignore` raíz. Verificado con `git check-ignore -v .env .env.tailscale` → `.gitignore:13` y `.gitignore:14`.

### B2. `OverpayDebt`: read del balance + insert fuera de la misma transacción

- Severidad: **Alta**
- Área: integridad transaccional / lógica financiera
- Evidencia: `mobile/lib/data/daos/entries_dao.dart` en `registerDebtPayment`:
  ```dart
  final deuda = await _state.accountBalanceNow(accountDestinationId);
  if (amount > deuda) {
    throw const EntriesDaoError('overpay_debt', ...);
  }
  return _register(...);   // INSERT separado
  ```
  El check y la escritura no comparten una `db.transaction`. En **single-isolate Dart** (Flutter Android es un único event loop) el riesgo es bajo, pero si dos taps muy rápidos del botón "Guardar" disparan ambos `await accountBalanceNow` antes de que el primero llegue a `_register`, ambos pasan el check con la misma deuda observada y el segundo deja overpay.
- Riesgo: la única validación bloqueante de la libreta libre (OverpayDebt) puede ser bypaseada por una race condition real al pulsar rápido el botón Guardar dos veces; deja la tarjeta con saldo a favor (sin sentido contable).
- Recomendación: envolver el check + insert en una sola transacción dentro de `registerDebtPayment`:
  ```dart
  return _db.transaction(() async {
    final deuda = await _state.accountBalanceNow(accountDestinationId);
    if (amount > deuda) throw const EntriesDaoError('overpay_debt', ...);
    return _register(...);
  });
  ```
  Adicionalmente: en `entry_form_screen._submit` ya hay un guard `if (_saving) return`, pero el toggle a `_saving = true` ocurre dentro de un `setState` async — por las dudas, mover el guard antes de cualquier await y deshabilitar el botón Guardar visualmente cuando `_saving == true` (hoy ya muestra spinner, validar que el `onPressed: _saving ? null : _submit` esté en todos los paths).
- Depende de: nada.
- **Fix aplicado**: `registerDebtPayment` en `entries_dao.dart` ahora envuelve `_state.accountBalanceNow(...)` + check + `_register(...)` dentro de `transaction(() async { ... })`. Check y escritura quedan atómicos.

### B3. `AccountsDao.archive()`: balance leído fuera de la transacción del update

- Severidad: **Alta**
- Área: integridad transaccional
- Evidencia: `mobile/lib/data/daos/accounts_dao.dart` en `archive()`:
  ```dart
  final balance = await stateService.accountBalanceNow(id);
  if (balance != 0) throw const AccountsDaoError('account_not_empty', ...);
  await (update(accounts)..where((a) => a.id.equals(id))).write(...);
  ```
  Mismo patrón que B2. La precondición "balance == 0" se valida sobre una lectura previa al update.
- Riesgo: si un evento async insertara una entry sobre esa cuenta entre la lectura y el update, archivamos una cuenta con saldo distinto de cero. Hoy improbable en single-user single-isolate, pero la única forma de evitar la deuda es transaccional.
- Recomendación: envolver check + update en `db.transaction`:
  ```dart
  await _db.transaction(() async {
    final balance = await stateService.accountBalanceNow(id);
    if (balance != 0) throw const AccountsDaoError('account_not_empty', ...);
    await (update(accounts)..where((a) => a.id.equals(id))).write(...);
  });
  ```
- Depende de: B2 (mismo patrón; aplicar el fix de transacción de manera consistente para que quede como convención).
- **Fix aplicado**: `archive()` en `accounts_dao.dart` ahora envuelve `stateService.accountBalanceNow(id)` + check + `update(accounts).write(...)` dentro de `transaction(() async { ... })`. Misma convención que B2.

### B4. `BackupService.wipeAll()` sin cobertura de test

- Severidad: **Alta**
- Área: tests / robustez de operación destructiva
- Evidencia:
  - `BackupService.wipeAll()` se extrajo en este sprint (`mobile/lib/data/backup.dart`) y se invoca desde Settings → "Reiniciar cuenta" para borrar TODO antes de redirigir a `/first-run`.
  - `mobile/test/data/backup_test.dart` cubre import/export pero **no hay test directo de `wipeAll()`**. La lógica de `_wipeTablesInternal` se ejercita indirectamente por los tests de import, pero no se valida en aislamiento que la BD quede 100% vacía ni que el FirstRunState detecte la BD vacía después.
- Riesgo: cualquier futura modificación del método (agregar tablas, cambiar orden de delete, errores de FK) puede romper la única operación irreversible del usuario sin que ningún test lo capture.
- Recomendación: agregar a `backup_test.dart`:
  ```dart
  test('wipeAll vacía las 3 tablas y deja la BD lista para reseed', () async {
    await seed();
    expect((await accountsDao.listAll()).length, greaterThan(0));
    await backup.wipeAll();
    expect(await accountsDao.listAll(), isEmpty);
    expect(await categoriesDao.listAll(), isEmpty);
    expect(await entriesDao.watchPage().first, isEmpty);
    expect(await hasBolsa(db), isFalse);
  });
  ```
- Depende de: B2/B3 si terminan tocando el patrón de transacción.
- **Fix aplicado**: nuevo test `'wipeAll vacía las 3 tablas y deja la BD lista para reseed'` en `backup_test.dart` que valida (a) que la BD seedeada tiene contenido, (b) que tras `wipeAll()` las 3 tablas quedan vacías, (c) que `hasBolsa(db)` devuelve `false` (precondición del redirect a `/first-run`). Total tests: 56 → **57 verdes**.

### B5. `PopScope.canPop` no excluye `_saving == true`: back durante save puede dejar inconsistencia

- Severidad: **Alta**
- Área: UX / integridad de estado de UI
- Evidencia: `mobile/lib/screens/entry_form_screen.dart`:
  ```dart
  PopScope(
    canPop: _isEdit || _kind == null,   // no contempla _saving
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) return;
      setState(() { _kind = null; ... });  // resetea campos
    },
  ```
  Mientras `_saving == true` el `await deps.entriesDao.register*(...)` está en curso. Si el usuario presiona back en ese momento, `canPop` evalúa a `_isEdit || _kind == null` (true si edición; false si alta con kind seleccionado). En alta, el back queda interceptado y resetea `_kind` a null mientras la transacción al DAO sigue corriendo. Cuando completa, ya estamos en otra pantalla mental (KindPicker) pero el `await` original puede dispararse `Navigator.maybePop()` o `showSuccessSnackbar` sobre un estado distinto.
- Riesgo: snackbar de éxito apareciendo después de que el usuario abandonó el alta; o peor, `Navigator.maybePop()` durante el `_saving=true` que cierra el form mientras el DAO está escribiendo.
- Recomendación: bloquear el back mientras hay save en curso:
  ```dart
  PopScope(
    canPop: (_isEdit || _kind == null) && !_saving,
    ...
  )
  ```
  Adicionalmente, si el usuario alcanzó a tocar el botón "Cambiar tipo" (`onPressed: () => setState(() => _kind = null)`) mientras `_saving == true`, también debería estar deshabilitado.
- Depende de: nada.
- **Fix aplicado**: `PopScope.canPop` ahora es `(_isEdit || _kind == null) && !_saving`. Adicionalmente, el botón "Cambiar tipo (...)" tiene `onPressed: _saving ? null : () => setState(() => _kind = null)`, deshabilitándose durante el save.

## Hallazgos no bloqueantes

### M1. `BackupService.importFromJson` no valida enums (`kind`, `type`, `applies_to`)

- Severidad: Media
- Área: integridad de datos / superficie de ataque del import
- Evidencia: `mobile/lib/data/backup.dart` construye los Companion sin validar que `kind ∈ {income, expense, credit_expense, debt_payment, transfer}`, ni `type ∈ {cash, debit, credit}`, ni `applies_to ∈ {income, expense, both}`. La validación existe en los DAOs (`_validKinds`) pero el batch insert del import los esquiva.
- Impacto: un JSON corrupto o malintencionado puede insertar `kind = 'hacked'` que rompe la UI y los SUMs agregados de `financial_state`. SQLite no tiene CHECK constraints declarados en estas columnas.
- Recomendación: agregar guardas en los métodos `_entryFromJson` / `_accountFromJson` / `_categoryFromJson` (antes del Companion) que verifiquen los enums y lancen `BackupError('invalid_kind', ...)`. Reusar las constantes ya existentes en los DAOs.
- Depende de: nada.

### M2. `BackupService.importFromJson` no valida `amount > 0`

- Severidad: Media
- Área: integridad financiera
- Evidencia: `_entryFromJson` toma `(json['amount'] as num).toDouble()` sin verificar `> 0`. Los DAOs sí validan en register*, pero el import bypasea.
- Impacto: un JSON con `amount: 0` o `amount: -100` inserta entries que rompen balance.
- Recomendación: validar `amount > 0` en `_entryFromJson` con `BackupError('invalid_amount', ...)`.
- Depende de: M1 (mismo punto del código).

### M3. Sin validación de longitud máxima en strings del import

- Severidad: Media
- Área: integridad / DoS local
- Evidencia: `database.dart` declara `TextColumn get name => text()();` sin `withLength()`. El import toma `json['name']` tal cual.
- Impacto: un JSON con `name` de 10 MB se inserta y rompe la UI o satura el cel al renderizarlo. Bajo riesgo en single-user (el usuario es quien arma sus propios respaldos), pero define superficie blanda.
- Recomendación: validar `name.length ≤ 200`, `description.length ≤ 1000` en el import antes de construir Companion. Documentar los límites en `mobile/README.md`.
- Depende de: M1 (mismo punto del código).

### M4. Sin validación de formato UUID en campos `id` del import

- Severidad: Media
- Área: integridad / unicidad
- Evidencia: import acepta `json['id'] as String` directo. Drift usa prepared statements (no hay SQL injection), pero permite IDs con formato arbitrario.
- Impacto: si Diego importa un respaldo con `id: '1'` y luego crea entries reales, las colisiones futuras son posibles. Bajo riesgo dado que el UUID v7 generado tiene 128 bits de entropía mixta.
- Recomendación: validar con regex `^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-7[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$` (UUID v7) antes del Companion, o aceptar UUIDs v4/v7 con regex más laxa.
- Depende de: M1.

### M5. `AndroidManifest.xml` sin `android:allowBackup="false"`

- Severidad: Media
- Área: privacidad de datos local
- Evidencia: `mobile/android/app/src/main/AndroidManifest.xml` no declara `android:allowBackup`. Default Android = `true`.
- Impacto: alguien con USB debugging habilitado en el cel desbloqueado puede ejecutar `adb backup io.github.gregori100.fincore` y extraer la BD SQLite con todos los movimientos.
- Recomendación: agregar a `<application>`:
  ```xml
  android:allowBackup="false"
  android:fullBackupContent="false"
  android:dataExtractionRules="@xml/data_extraction_rules"
  ```
  Documentar que el flujo oficial de respaldo es Settings → Exportar JSON.
- Depende de: nada.

### M6. APK release firmado con clave debug

- Severidad: Media (no bloqueante para sideload)
- Área: distribución
- Evidencia: `android/app/build.gradle.kts:34`: `signingConfig = signingConfigs.getByName("debug")`. Comentario TODO presente.
- Impacto: válido para el Redmi de Diego; rechazado por Play Store; potencial reemplazo por APK firmada con la misma clave debug pública si alguien intenta distribuirla maliciosamente.
- Recomendación: ya documentado en `implementation/pendientes.md`. Para distribución más allá del sideload personal, generar release key y configurar `signingConfigs.release`.
- Depende de: nada.

### M7. Reset destructivo no fuerza exportar respaldo previo

- Severidad: Media
- Área: UX / prevención de pérdida de datos
- Evidencia: `mobile/lib/screens/settings_screen.dart` → `_resetAccount()` muestra `showConfirmDialog` con texto "No hay vuelta atrás (excepto si tenés un respaldo guardado)" pero no verifica que exista respaldo ni ofrece exportar primero.
- Impacto: si Diego olvida exportar antes, perdió todo. La advertencia textual depende de que la lea con atención.
- Recomendación: ofrecer un flujo de dos pasos:
  1. Botón "Exportar y reiniciar" que dispara `_export()` primero y, tras share sheet exitoso, propone `_resetAccount()`.
  2. Botón "Reiniciar sin exportar" con segunda confirmación enfática.
- Depende de: nada.

### M8. Falta índice compuesto en `journal_entries(occurred_at DESC, deleted_at)` para `watchPage`

- Severidad: Alta (perf futura)
- Área: SQL
- Evidencia: `mobile/lib/data/database.dart` declara índices simples sobre `account_origin_id`, `account_destination_id`, `deleted_at`, `kind`. La query de `watchPage` ordena por `occurred_at DESC, created_at DESC` con `WHERE deleted_at IS NULL` y filtros opcionales.
- Impacto: con 50k+ entries la lista de movimientos requiere filesort. Hoy con cientos de entries no se nota; en 6-12 meses de uso real puede degradar.
- Recomendación: agregar como sentencia adicional en `onCreate` (y al implementar `onUpgrade` cuando suba la versión):
  ```sql
  CREATE INDEX idx_entries_occurred_active
    ON journal_entries(occurred_at DESC) WHERE deleted_at IS NULL;
  ```
  Adicionalmente considerar índices parciales para `account_origin_id`, `account_destination_id` filtrados por `deleted_at IS NULL`.
- Depende de: M14 (schemaVersion).

### M9. `FinancialStateService.watchAccountBalance` no cachea streams: N suscripciones en Dashboard

- Severidad: Media
- Área: performance / memoria
- Evidencia: cada `_BalanceLabel(accountId)` del Dashboard crea un `customSelect(...).watchSingle()` nuevo. Con 10 cuentas se mantienen 10 streams + BO + DE + CR + cuentas + entries = ~15 listeners activos.
- Impacto: cada insert en `journal_entries` dispara reevaluación de 15 streams. En cels low-end puede impactar el frame rate.
- Recomendación: cachear streams por `(accountId, accountType)` en un `Map<String, Stream<double>>` interno del service, retornando el mismo stream para suscripciones repetidas. Drift se encarga de coalescer la query.
- Depende de: nada.

### M10. Streams Drift sin valor inicial: skeletons del Dashboard persisten hasta el primer cambio

- Severidad: Media
- Área: UX percibida
- Evidencia: `customSelect(...).watchSingle()` emite solo cuando hay un cambio detectado por `readsFrom`. Al montar el Dashboard inmediatamente después de "Arrancar limpio" los streams pueden tardar en emitir el primer valor.
- Impacto: el skeleton anima 1-3 frames de más antes de mostrar los ceros reales. No es bloqueante pero refuerza la sensación de "tarda".
- Recomendación: usar `customSelect(...).watchSingleOrNull()` con `.map((row) => row?.read<double>('total') ?? 0)` o un `startWith(0.0)` al stream. Verificar que drift emita el primer query result sin esperar trigger.
- Depende de: nada.

### M11. Export sin límite: JSON gigante puede saturar memoria

- Severidad: Media
- Área: performance / robustez
- Evidencia: `BackupService.exportToJson()` hace `select(journalEntries).where(deletedAt.isNull()).get()` sin paginación + `jsonEncode` en memoria.
- Impacto: con 10k+ entries el JSON puede pesar decenas de MB y el `jsonEncode` corre en el UI thread. En cels de 2 GB de RAM puede saturar o congelar.
- Recomendación: hoy aceptable porque Diego no tiene volumen alto. Documentar como límite conocido en `pendientes.md`. Cuando aparezca el problema, fragmentar export en streaming o mover a un Isolate.
- Depende de: nada.

### M12. `schemaVersion = 1` con `onUpgrade` stub: futuras migraciones son crash silencioso

- Severidad: Alta (futuro inmediato)
- Área: migraciones / compatibilidad
- Evidencia: `mobile/lib/data/database.dart` tiene `schemaVersion: 1` y `onUpgrade: (m, from, to) async {}` vacío con comentario "Stub para futuras migraciones".
- Impacto: cuando se incremente a 2 sin implementar `m.alterTable` / `m.addColumn`, las instalaciones existentes crashean al abrir.
- Recomendación: agregar como **primer paso del próximo sprint** un guardrail temporal: `onUpgrade: (m, from, to) async { throw UnimplementedError('Schema upgrade $from → $to no implementado'); }`. Documentar en CLAUDE.md y `pendientes.md` que cualquier PR que toque schema requiere implementar la migración antes de incrementar `schemaVersion`.
- Depende de: nada.

### M13. `kAppVersion` hardcoded en `settings_screen.dart` (triple sync)

- Severidad: Media
- Área: docs / mantenibilidad
- Evidencia: `lib/screens/settings_screen.dart:19`: `const String kAppVersion = '0.2.0+27';` debe mantenerse manualmente sincronizado con `pubspec.yaml` y `android/app/build.gradle.kts`.
- Impacto: Diego ya documentó el riesgo en `pendientes.md`. Hoy las tres fuentes están alineadas en `0.2.0+27`.
- Recomendación: refactor con `package_info_plus` para leer la versión del manifest en runtime. Mientras tanto, lint check manual antes de cada release.
- Depende de: nada.

### M14. `categories_dao.archive()` deja `category_id` colgando en entries históricos

- Severidad: Baja
- Área: integridad lógica
- Evidencia: el comentario del DAO indica que la UI filtra activos. El widget `CategoryBadge` lee la relación que devuelve null para archivadas — funciona, pero depende de que los joins de listas siempre filtren por `categories.deletedAt IS NULL`.
- Impacto: si un nuevo screen olvida ese filtro, mostrará entries con una categoría fantasma.
- Recomendación: documentar la convención en `CLAUDE.md` y agregar un helper `categoriesDao.findActiveById(id)` que aplique el filtro. Considerar un assertion en debug.
- Depende de: nada.

### M15. `updateEntry` no re-valida categoría heredada si el caller no toca `categoryId`

- Severidad: Baja
- Área: validación de dominio
- Evidencia: cuando `clearCategory=false` y `categoryId == null`, conserva `existing.categoryId`. Si esa categoría fue archivada entre el insert original y este update, el entry queda con FK a categoría archivada.
- Impacto: la UI seguirá mostrando "Sin categoría" (la relación es null), pero la BD tiene un FK a archivada. Inconsistencia menor.
- Recomendación: en `updateEntry`, después de calcular `effectiveCategoryId`, validar siempre que la categoría esté activa, aunque no haya cambiado. Si fue archivada, forzar `categoryId = null`.
- Depende de: nada.

### M16. Tests de `cancel` idempotencia no verifican que el balance no se duplique

- Severidad: Media
- Área: cobertura de tests
- Evidencia: `database_test.dart` solo verifica que `cancel(id)` dos veces no lanza. No comprueba que el balance post-segundo-cancel sea idéntico al post-primer-cancel.
- Impacto: una regresión futura que reverse el balance en cada cancel pasaría tests pero rompería contabilidad.
- Recomendación: extender el test con `expect(balanceAfterFirstCancel, balanceAfterSecondCancel)`.
- Depende de: nada.

### M17. Falta filtro por categoría en `entries_list_screen` (decisión UX)

- Severidad: Media
- Área: UX / consistencia funcional
- Evidencia: el filter sheet permite filtrar por kind y cuenta, no por categoría.
- Impacto: el usuario que organizó sus entries con categorías no puede listar "todos los movimientos de Comida".
- Recomendación: si es decisión consciente, anotar en `pendientes.md` como backlog. Si es omisión, agregar el filtro al sheet + extender `watchPage` con `category_id`.
- Depende de: nada.

### M18. Tests de transiciones complejas en `updateEntry` faltan

- Severidad: Media
- Área: cobertura
- Evidencia: hay tests de validaciones puntuales (origin null en income, etc.) pero no de transiciones (cambiar amount + fecha + cuenta a la vez).
- Impacto: bugs en la combinación de cambios pueden no detectarse.
- Recomendación: agregar un grupo de tests para `updateEntry` que combine los 5 campos editables en escenarios reales.
- Depende de: nada.

### M19. Hint cosmético `prefer_const_constructors` en `widgets/skeleton.dart:75`

- Severidad: Baja
- Área: tooling
- Evidencia: el único warning de `flutter analyze`.
- Impacto: ninguno funcional. Cosmético.
- Recomendación: cambiar `Row(...)` por `const Row(...)` en la línea indicada.
- Depende de: nada.

### M20. Snackbar warning (#EBBD52) con texto blanco roza el umbral WCAG AA

- Severidad: Baja
- Área: accesibilidad
- Evidencia: el color `warning` con blanco da ~3.8:1, por debajo del 4.5:1 AA.
- Impacto: lectura difícil en exterior con sol o usuarios con baja visión.
- Recomendación: usar `FincoreColors.canvas` (oscuro) como color de texto cuando el fondo del snackbar es warning.
- Depende de: nada.

### M21. Falta `Semantics` / `tooltip` en algunos iconos críticos

- Severidad: Baja
- Área: accesibilidad
- Evidencia: el filter icon de `entries_list_screen` y el chevron de `account_picker` no exponen labels semánticos. Otros sí (los AppBar IconButton tienen `tooltip`).
- Impacto: TalkBack no narra correctamente.
- Recomendación: agregar `tooltip` a los `IconButton` que falten; envolver iconos puramente decorativos sin label con `Semantics(excludeSemantics: true)`.
- Depende de: nada.

### M22. `ndkVersion` hardcoded vs `flutter.ndkVersion`

- Severidad: Baja
- Área: mantenibilidad
- Evidencia: `android/app/build.gradle.kts:11`: `ndkVersion = "27.0.12077973"`.
- Impacto: cuando Flutter actualice el NDK default, esta línea queda detrás y requiere bump manual. Fue necesario porque los plugins exigían 27 cuando Flutter default era 26; eso puede cambiar.
- Recomendación: dejar como está pero comentar el motivo y la fecha del fix. Revisar tras cada `flutter upgrade`.
- Depende de: nada.

### M23. Dependencias con `^` floating sin pin de minor

- Severidad: Baja
- Área: reproducibilidad
- Evidencia: `pubspec.yaml` usa `^` en todas las deps clave.
- Impacto: `flutter pub upgrade` puede romper algo. Hoy no se ejecuta seguido.
- Recomendación: dejar `^` para iteración rápida; antes de un release "estable" generar `pubspec.lock` y considerar pinear las críticas (`drift`, `go_router`, `sqlite3_flutter_libs`).
- Depende de: nada.

### M24. `DropdownMenu` con `enableSearch: false` aún permite typing fantasma

- Severidad: Baja
- Área: UX
- Evidencia: el M3 `DropdownMenu` ignora `enableSearch: false` para teclear (lo deshabilita solo para el filtro), por lo que un usuario que toque el teclado mientras el menú está abierto ve highlight raro.
- Impacto: cosmético; no rompe selección.
- Recomendación: agregar `requestFocusOnTap: false` ya está, suficiente. Si molesta, considerar volver a `DropdownButtonFormField` envuelto en `SizedBox(width)`.
- Depende de: nada.

### M25. No hay loader de progreso en `FirstRunScreen` durante import grande

- Severidad: Baja
- Área: UX percibida
- Evidencia: `_importBackup()` muestra el spinner del estado `_working` pero sin progreso.
- Impacto: con un JSON de 10k entries el usuario puede creer que se colgó.
- Recomendación: hoy aceptable porque el volumen real es bajo. Cuando aparezca el problema, exponer un `Stream<double>` de progreso desde el import o aceptar la simplificación con un texto "Procesando, no cierres la app".
- Depende de: nada.

## Plan de corrección ordenado

1. **B1 — Restaurar `.gitignore` raíz** para proteger `.env`, `.env.tailscale`, `*.ts.net.crt`, `*.ts.net.key`, `.phpunit.result.cache`, `.playwright-mcp/`. Verificar con `git check-ignore -v` antes de cualquier `git add`. **HACER PRIMERO**.
2. **B2 + B3 — Envolver check + write en transacción** en `entries_dao.registerDebtPayment` y `accounts_dao.archive`. Aplicar el mismo patrón en futuras Actions donde se decida una escritura con base en una lectura previa.
3. **B5 — `PopScope.canPop: (_isEdit || _kind == null) && !_saving`** en `entry_form_screen` + deshabilitar "Cambiar tipo" mientras `_saving`.
4. **B4 — Agregar test directo de `BackupService.wipeAll()`** en `backup_test.dart` (~10 líneas, ver evidencia).
5. **M1 + M2 + M3 + M4 — Validaciones en `_entryFromJson` / `_accountFromJson` / `_categoryFromJson`** (enums + amount + length + UUID regex) para cerrar la superficie del import.
6. **M5 — Agregar `android:allowBackup="false"`** al `AndroidManifest.xml`.
7. **M12 — Guardrail temporal en `onUpgrade`**: `throw UnimplementedError('Schema upgrade $from → $to no implementado');` para que un bump accidental falle fuerte.
8. **M8 — Agregar índice parcial `journal_entries(occurred_at DESC) WHERE deleted_at IS NULL`** en `onCreate`. Bumpar `schemaVersion` a 2 y implementar `onUpgrade` que ejecute el `CREATE INDEX` (necesario para usuarios existentes).
9. **M9 — Cachear `watchAccountBalance` en un `Map<String, Stream<double>>`** dentro de `FinancialStateService`.
10. **M16 + M18 — Extender suite de tests** con `cancel idempotente preserva balance` y matriz de transiciones de `updateEntry`.
11. **M7, M17, M19, M20, M21, M22, M23, M24, M25** — Cleanup en backlog del próximo sprint. Documentar todos en `implementation/pendientes.md`.

## Validaciones recomendadas

Antes de cerrar el sprint:

- `git check-ignore -v .env .env.tailscale` → ambos deben aparecer ignorados.
- `flutter test` → debe seguir en 56+ verde tras B4 + M16 + M18.
- `flutter analyze` → debe quedar en 0 issues tras M19.
- `flutter build apk --release --split-per-abi` → smoke local + reinstalar APK arm64 en el Redmi tras los fixes B2/B3/B5.
- Verificación manual: crear movimiento, presionar back rápido durante save, confirmar que el form no se cierra.
- Verificación manual: Settings → Reiniciar cuenta tras los fixes, confirmar que `/first-run` carga limpio.

## Limitaciones

- **No se ejecutó el APK del review**: la revisión es estática sobre el árbol pendiente. Los hallazgos UX se inferieron del código + el smoke iterativo previo de Diego.
- **No se midió rendimiento real con 10k+ entries**: las recomendaciones de índice (M8) son preventivas; no hay evidencia empírica del cuello.
- **Race conditions B2/B3**: en single-isolate Dart el escenario requiere tap rápido del usuario, no hay test que lo demuestre hoy. El fix es preventivo y consistente con la doctrina del backend Laravel previo.
- **Permisos y datos en `.env`/`.env.tailscale`**: se inspeccionaron solo las cabeceras para evitar leer secretos. El subagente reportó `APP_KEY=base64:...` en `.env.tailscale`; conviene auditar el archivo completo y rotar la clave si en algún momento se sospecha que pudo haberse comiteado.
- **Tests de widgets (T043-T045)**: aplazados deliberadamente con justificación en `desviaciones-plan.md`. La revisión acepta el trade-off; el riesgo queda en `pendientes.md`.
- **Plataformas no Android**: la app declara target Linux para tests, pero el review se centró en Android. Si Diego decide distribuir en Linux desktop hay que revisar nuevamente.

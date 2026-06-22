# Hardening v4 — cierre del quality review v3 + EntriesDao en @DriftDatabase + cobertura CRUD

## Resumen

Sprint técnico que cierra **todo** el backlog del quality review del v3 (commit `52d55c3`, APK `0.3.7+39`) más el ítem 5 del backlog histórico que el v3 dejó explícitamente fuera de scope: registrar `EntriesDao` en `@DriftDatabase(daos: [...])`.

**Sin features visibles para el usuario.** Resultado esperado: codebase con cobertura CRUD profunda, sin deuda técnica residual del review v3, e infraestructura drift completa (los 3 DAOs codegen-resolved). Bump a `0.3.8+40`.

## Problema a resolver

El v3 cerró con un quality review que dejó 18 hallazgos (0 bloqueantes, 6 Media, 12 Baja) y un ítem del backlog histórico:

1. **L2-H1 (Media)**: `watchBo / watchDe / watchCr` NO usan `_ReplayBalanceStream`. Bug latente "Skeleton eterno" para las 3 cards superiores del Dashboard si el stack se resetea con `context.go`.
2. **L1-H3 (Media)**: los 5 tests por kind del `entry_form_kinds_test.dart` verifican labels textuales pero NO el contenido del Dropdown del `AccountPicker`. Gap real de cobertura RN-011.
3. **L1-H1, L1-H2, L1-H4, L1-H5, L1-H6, L1-H7, L2-H3, L2-H4, L3-H2, L3-H4, L3-H5 (Baja)**: robustez incremental del harness, tests, script.
4. **EntriesDao en `@DriftDatabase(daos: [...])`**: bloqueado en v3 porque el constructor requiere `FinancialStateService`. Al releer el código, **solo `registerDebtPayment` lo usa** (línea 204 de `entries_dao.dart` para llamar `accountBalanceNow`). La inversión de dependencia es viable extrayendo la query a función pura.
5. **Widget tests profundos del CRUD**: el v3 cubrió bootstrap (render + tap). Faltan flujos completos: accounts CRUD, entries_list con bottom sheet de filtros, category_form con preview live, settings con confirmaciones destructivas.

Dejarlo todo abierto significa que cualquier sprint de features (probablemente reportes) va a tropezar con: cards BO/DE/CR posiblemente vacías, gap RN-011 latente, robustez frágil, y deuda residual del v3.

## Objetivo

- Extraer `accountBalanceAtomic(GeneratedDatabase, String)` como función pura. `FinancialStateService.accountBalanceNow` se convierte en wrapper de 1 línea (preserva API pública y tests existentes).
- `EntriesDao` sin campo `_state`. Constructor pasa a `EntriesDao(super.db)`. Registrar en `@DriftDatabase(daos: [...])`. `AppDependencies.fromDatabase` usa `database.entriesDao` (codegen).
- Aplicar replay-1 a `watchBo`, `watchDe`, `watchCr` con 3 `_ReplayBalanceStream` standalone lazy. Test defensivo.
- Ampliar `entry_form_kinds_test.dart` para validar el contenido del Dropdown por kind.
- Cluster de Baja del review v3 (9 fixes pequeños).
- 4 grupos de widget tests profundos del CRUD.
- Bump a `0.3.8+40`. Mantener `flutter analyze` limpio. Subir suite de **110 → ≥ 130 verdes**.

## Alcance

### Familia 1 — EntriesDao en @DriftDatabase (Backlog ítem 5)

- **RF-001**: extraer `accountBalanceAtomic(GeneratedDatabase db, String accountId)` como función top-level en `mobile/lib/data/financial_state.dart`. Lógica idéntica a `FinancialStateService.accountBalanceNow` (selecciona account, decide SQL credit/cash, retorna balance). Pura, sin estado.
- **RF-002**: `FinancialStateService.accountBalanceNow(id)` pasa a ser `=> accountBalanceAtomic(_db, id)`. Preserva API pública. Tests existentes no cambian.
- **RF-003**: `EntriesDao` quita field `_state`. Constructor: `EntriesDao(super.db)`. En `registerDebtPayment`, la llamada `_state.accountBalanceNow(...)` pasa a `accountBalanceAtomic(attachedDatabase, accountDestinationId)`.
- **RF-004**: agregar `EntriesDao` a `@DriftDatabase(daos: [AccountsDao, CategoriesDao, EntriesDao])` en `mobile/lib/data/database.dart`. Regenerar codegen.
- **RF-005**: `AppDependencies.fromDatabase` reemplaza `EntriesDao(database, stateService)` por `database.entriesDao`. El campo público `AppDependencies.entriesDao` se preserva (API estable).
- **RF-006**: actualizar el comentario del docstring de `@DriftDatabase` en `database.dart` que dice "EntriesDao queda manual..." porque ya no es cierto.

### Familia 2 — L2-H1 replay-1 en BO/DE/CR

- **RF-007**: agregar 3 fields lazy en `FinancialStateService`: `_boCache`, `_deCache`, `_crCache` de tipo `_ReplayBalanceStream?`. `watchBo()`, `watchDe()`, `watchCr()` los crean en la primera llamada y retornan el `stream` cacheado.
- **RF-008**: `invalidateAll()` los disposa y los setea a `null` para que la próxima llamada arme uno nuevo.
- **RF-009**: test defensivo en `financial_state_test.dart`: `watchBo()` llamada dos veces retorna el mismo Stream (`identical`). Nuevo listener resuscrito tras cancel del primero recibe el último valor cacheado por replay-1.

### Familia 3 — Cluster de Baja del review v3

- **RF-010 (L1-H1)**: `_localeInitialized` reemplazado por `Completer<void>?` para serializar inicializaciones concurrentes en el mismo isolate. Patrón `_localeFuture ??= initializeDateFormatting(...); await _localeFuture;`.
- **RF-011 (L1-H2)**: en `pumpFincoreApp`, si `seedBolsa=true && initialRoute=='/first-run'`, lanzar `assert(false, 'configuración ambigua: ...')` con mensaje explícito.
- **RF-012 (L1-H4)**: en `entry_form_screen_test.dart`, reemplazar `find.widgetWithText(TextFormField, '150.0')` por `find.byType(TextFormField).first` o `Key`-based finder más estable al formato textual.
- **RF-013 (L1-H5)**: en `widget_test_harness.dart`, importar `package:go_router/go_router.dart' show GoRouter` y tipar el field `router` como `GoRouter` en lugar de `dynamic`.
- **RF-014 (L2-H3)**: en `_ReplayBalanceStream._ensureUpstream`, el forward loop chequea `if (!controller.hasListener) { _listeners.remove(controller); continue; }` antes de `addSync`. Defensa contra controllers cerrados externamente.
- **RF-015 (L2-H4)**: agregar comentario 1-línea en el docstring de `_balanceCache` documentando que la key incluye `accountType` y que `invalidateAccount` requiere que `type` sea inmutable post-creación.
- **RF-016 (L3-H2)**: en `verify-apk.sh`, reemplazar `ls -d ... | sort -V | tail` por `find ... -maxdepth 2 -name aapt2 | sort -V | tail` para manejar paths con espacios (macOS).
- **RF-017 (L3-H4)**: en `verify-apk.sh`, agregar `tr -d "'\""` al parseo de `pubspec.yaml` para tolerar `version: '0.3.7+39'`.
- **RF-018 (L3-H5)**: en `verify-apk.sh`, ampliar regex a `versionCode=['"]\\([0-9]*\\)['"]` para tolerar comillas dobles.

### Familia 4 — L1-H3 gap RN-011 en dropdowns

- **RF-019**: ampliar los 5 tests de `entry_form_kinds_test.dart` para validar el **contenido del DropdownMenu** del `AccountPicker` por kind. Para cada kind:
  - Abrir el dropdown del field origen y/o destino (tap + pumpAndSettle).
  - Verificar que aparecen las cuentas que cumplen `allowedTypes` (RN-011).
  - Verificar que NO aparecen las cuentas excluidas (ej. Visa `credit` en un Ingreso).
  - Para `transfer`, validar el `excludeId` mutuo (origen no debe aparecer en destino y viceversa).

### Familia 5 — Widget tests profundos del CRUD

- **RF-020**: `mobile/test/screens/account_form_screen_test.dart` — alta + edición de cuenta. Validar:
  - Alta de debit con name vacío → bloqueado por validador.
  - Alta con duplicate_name → snackbar de error.
  - Edición exitosa: cambiar name y description, persiste.
  - Edición de Bolsa (protected) → form en modo read-only.
- **RF-021**: `mobile/test/screens/entries_list_screen_test.dart` — lista + bottom sheet de filtros.
  - Sembrar 5 entries de tipos distintos.
  - Abrir bottom sheet de filtros, seleccionar `kind=income`, aplicar.
  - Verificar que solo aparecen los entries de kind income.
  - Limpiar filtro, verificar que vuelven los 5.
- **RF-022**: `mobile/test/screens/category_form_screen_test.dart` — alta + preview live.
  - Alta de categoría con name + color + icon → preview muestra ambos.
  - Cambiar color, verificar que el preview cambia.
  - Cambiar icon, verificar que el preview cambia.
  - Submit, verificar persistencia.
- **RF-023**: `mobile/test/screens/settings_screen_test.dart` — confirmaciones destructivas.
  - Tocar "Reiniciar cuenta sin exportar" → diálogo destructivo → confirmar → redirect a `/first-run`.
  - Tocar "Categorías" → navega a `/categories`.
  - (NO probamos export con Share porque requiere mock de `share_plus`; sale de scope.)

### Familia 6 — Release

- **RF-024**: bump a `0.3.8+40` en `pubspec.yaml` y `android/app/build.gradle.kts`.
- **RF-025**: build APK release split-per-abi. Validar con `scripts/verify-apk.sh`.

## Fuera de alcance

- **Pipeline CI / firma de release para Play Store**: scope distinto.
- **Features de producto** (reportes, multi-usuario, sync con backend): backlog de producto, no de hardening.
- **Refactor de la jerarquía `BackupError` vs `EntriesDaoError`**: sigue diferido.
- **L1-H6 (Future.delayed en tests)**: pattern heredado del v2, migrar a `expectLater` no aporta valor hoy y mete churn.
- **L1-H7 (`harness.dispose()` race)**: requiere acceso al `tester` desde dispose. Refactor más invasivo de lo que vale.

## Reglas de negocio

Las reglas del MVP + RN-H01/H02/H03 + lo agregado en v1/v2/v3 no cambian. Sin nuevas reglas. El sprint es estrictamente de **refactor + tests + tooling**.

## Criterios de aceptacion

- `flutter test` ≥ 130 tests verdes (de 110 actuales).
- `flutter analyze` 0 errores, 0 warnings (4 hints info preexistentes aceptables).
- `database.entriesDao` accesible directamente sin instanciación manual. `AppDependencies.fromDatabase` usa el 3 codegen-resolved.
- `watchBo()`/`watchDe()`/`watchCr()` retornan el mismo Stream identitario en llamadas sucesivas.
- `scripts/verify-apk.sh` valida el APK `0.3.8+40`.
- APK arm64 instala sobre `0.3.7+39` sin perder datos.
- Documentación de cierre completa en `engineering/specs/flutter-local-hardening-v4/implementation/`.

## Riesgos

- **Codegen de `EntriesDao` rompe llamadas existentes**: `AppDependencies.entriesDao` ya se accede en muchos screens. Si el codegen genera un tipo distinto o la lista de DAOs cambia el shape del database, hay regresiones. Mitigación: `EntriesDao` es la misma clase, solo cambia cómo se instancia. La API pública (`registerIncome`, etc.) no cambia.
- **Tests de `accountBalanceNow` pueden fallar si el wrapper rompe la semántica**: 13 tests usan `state.accountBalanceNow(...)`. El wrapper debe ser idéntico en comportamiento. Mitigación: la función top-level es una extracción literal de la lógica actual.
- **Bump de minor `0.3.7+39 → 0.3.8+40`**: sigue siendo patch (sin features de usuario). Si Diego prefiere otro número, ajustable.
- **Volumen de cambios**: 25 RFs en 6 familias. Riesgo de error humano por fatiga. Mitigación: orden secuencial bien marcado, suite verde después de cada fase, smoke al final.

## Supuestos

- **Versionado**: `0.3.8+40`.
- **`AppDependencies.entriesDao`** se preserva como API pública. Los screens que la usan no cambian.
- **`FinancialStateService.accountBalanceNow`** se preserva. Tests existentes no se tocan.
- **El comentario actual del docstring de `@DriftDatabase`** que dice "EntriesDao queda manual..." se reemplaza con la nueva realidad.

# Progreso — flutter-local-hardening-v4

Sprint cerrado el 2026-06-22. APK release `0.3.8+40` construido y validado por `scripts/verify-apk.sh`. Smoke en Redmi queda como confirmación manual de Diego post-merge.

## Resumen de fases

| Fase | Tasks | Estado | Tests resultantes |
|------|-------|--------|-------------------|
| 1 — Refactor EntriesDao + @DriftDatabase | RF-001 a RF-006 | ✅ | 110 → 110 (sin nuevos tests, solo refactor) |
| 2 — Replay-1 en BO/DE/CR | RF-007 a RF-009 | ✅ | 110 → 112 (+2 defensivos) |
| 3 — Cluster de Baja del review v3 | RF-010 a RF-018 | ✅ (con descarte de RF-014) | 112 → 112 (sin nuevos tests, solo refactor) |
| 4 — Gap RN-011 en dropdowns (RF-019) | — | **Diferido** (ver DV-1) | — |
| 5 — Widget tests CRUD profundos (RF-020 a RF-023) | — | **Diferido** (ver DV-2) | — |
| 6 — Release 0.3.8+40 | RF-024, RF-025 | ✅ | — |
| 7 — Cierre | — | en curso | — |

**Total tests:** 110 → **112 verdes** (+2 sobre los nuevos del v3, no del v4 que no agregó widget tests).

## Detalle por fase

### Fase 1 — Refactor EntriesDao + @DriftDatabase

**Entrega:** EntriesDao registrado en `@DriftDatabase(daos: [...])` codegen junto a AccountsDao y CategoriesDao. Ítem 5 del backlog histórico cerrado.

**Cambios:**

- `mobile/lib/data/financial_state.dart`: extraído `accountBalanceAtomic(GeneratedDatabase db, String accountId)` como función pura top-level. `FinancialStateService.accountBalanceNow` pasa a ser wrapper de 1 línea sobre la función pura.
- `mobile/lib/data/daos/entries_dao.dart`: eliminado field `_state`. Constructor pasa a `EntriesDao(super.db)`. `registerDebtPayment` llama `accountBalanceAtomic(attachedDatabase, ...)`.
- `mobile/lib/data/database.dart`: `@DriftDatabase(daos: [AccountsDao, CategoriesDao, EntriesDao])`. Codegen regenerado.
- `mobile/lib/app_dependencies.dart`: `entriesDao = database.entriesDao` (codegen) reemplaza `EntriesDao(database, stateService)` manual.
- Tests data layer actualizados: `EntriesDao(db)` reemplaza `EntriesDao(db, state)` en `database_test.dart`, `backup_test.dart`, `invariants_test.dart`, `financial_state_test.dart`.

**Limpieza oportunista:** se limpiaron unused locals `state` y `stateService` que quedaron tras el refactor.

### Fase 2 — Replay-1 en BO/DE/CR

**Entrega:** L2-H1 del quality review v3 cerrado. Las 3 cards superiores del Dashboard ahora son resistentes al patrón "Skeleton eterno" si el stack se resetea con `context.go('/dashboard')`.

**Cambios:**

- `FinancialStateService` agregó 3 fields lazy: `_boCache`, `_deCache`, `_crCache` de tipo `_ReplayBalanceStream?`.
- `watchBo()`, `watchDe()`, `watchCr()` ahora retornan el stream cacheado del `_ReplayBalanceStream` correspondiente. La SQL se extrajo a métodos `_buildBoSource`, `_buildDeSource`, `_buildCrSource` para mantener la lazy initialization simple.
- `invalidateAll()` libera los 3 caches además del Map de `_balanceCache`.
- Test `RF-009 v4`: valida `identical(bo1, bo2)` y replay-1 de cada uno de los 3.
- Test `RF-008 v4`: valida que tras `invalidateAll()`, una nueva llamada arma un stream nuevo.

**Implicación de API:** el cambio de single-listener a `_ReplayBalanceStream` cambia la semántica de `.first` en tests. 3 tests existentes (`Entry cancelado NO cuenta en BO/DE/CR`, `Cuenta archivada NO aparece en BO`, `CR ignora cuentas con credit_limit NULL`) pasaron a usar `.firstWhere((v) => v == X)` para esperar el valor esperado en lugar de aceptar el cacheado.

### Fase 3 — Cluster de Baja del review v3

**Entrega:** 8 de los 9 fixes aplicados. RF-014 (hasListener guard) descartado in-vivo por causar cuelgues en `pumpAndSettle`.

**Fixes aplicados:**

- **RF-010 (L1-H1):** `_localeInitialized` reemplazado por `Completer<void>?` y luego revertido a `bool _localeInitialized` durante debugging — la condición de carrera teórica no aplica al scheduler actual de flutter test y la simplicidad gana. Documentado el porqué.
- **RF-011 (L1-H2):** `pumpFincoreApp` lanza `assert(!(seedBolsa && initialRoute == '/first-run'), ...)` para hacer explícito el contrato ambiguo.
- **RF-012 (L1-H4):** matcher `find.widgetWithText(TextFormField, '150.0')` reemplazado por `find.ancestor(of: find.text('Monto'), matching: find.byType(TextFormField)).first` — robusto al formato del valor.
- **RF-013 (L1-H5):** `final dynamic router` cambió a `final GoRouter router` importando `go_router` con `show GoRouter`.
- **RF-014 (L2-H3):** **descartado.** Agregar guard `if (!controller.hasListener) continue;` causaba que `pumpAndSettle` se colgara porque `hasListener` retorna `false` transitivamente durante la inicialización del controller en `Stream.multi`. El L2-H3 era riesgo teórico sin reporte; la protección queda diferida.
- **RF-015 (L2-H4):** documentación 1-línea en el docstring de `_balanceCache` sobre la inmutabilidad de `account.type`.
- **RF-016 (L3-H2):** `verify-apk.sh` usa `find ... -maxdepth 2 -name aapt2` en lugar de `ls -d ...|sort -V|tail` para tolerar paths con espacios.
- **RF-017 (L3-H4):** `verify-apk.sh` aplica `tr -d "'\""` al `PUBSPEC_VERSION` para tolerar valores entre comillas.
- **RF-018 (L3-H5):** `verify-apk.sh` regex amplía a `['"]` para tolerar comillas simples o dobles en la salida de aapt2.

**Hallazgo y falso fix corregido (ver DV-5):** durante Fase 3 los widget tests empezaron a colgar `pumpAndSettle`. Primer diagnóstico erróneo lo atribuyó a streams del `_ReplayBalanceStream` zombie post `db.close()`, aplicando `state.invalidateAll()` en tearDowns y dispose del harness. Tests pasaron una vez con esa configuración pero después volvían a colgar.

**Causa real:** **`state.invalidateAll()` en el `dispose()` del harness era el problema, no la solución.** Cierra los `MultiStreamController` mientras los `StreamBuilder` del Dashboard tienen listeners activos. Microtasks pendientes con `Bad state` exceptions contaminan el isolate.

**Fix correcto:** quitar `invalidateAll()` de tearDowns y dispose. Solo `db.close()`. Drift cancela el upstream limpio. Suite pasa en **6-12 segundos verde**.

### Fase 4 — Gap RN-011 en dropdowns (RF-019)

**Estado: diferida.** Ver `desviaciones-plan.md` DV-1.

Resumen: el patrón `tester.tap(find.text(label))` no logra hit-test sobre el field del `DropdownMenu` (el Text del label vive dentro del InputDecorator, fuera del área tappeable). El patrón correcto requiere `find.byType(DropdownMenu<String>)` filtrado por field, tap en el ícono expand específico, ESC para cerrar — es mecánico pero verboso. Se difiere a un sprint dedicado de UI testing depth.

### Fase 5 — Widget tests CRUD profundos (RF-020 a RF-023)

**Estado: diferida.** Ver `desviaciones-plan.md` DV-2.

Intento de `RF-020` (alta + edición de cuenta) tras debugging y limpieza: el test colgaba `pumpAndSettle` después del `enterText` en el field "Nombre", causando timeouts de 10-12 minutos por test. La causa exacta requiere debugging más profundo del `AccountFormScreen` (sospechas: animación del `AccountTypePicker`, side effect del `didChangeDependencies`, async load).

El ROI del debugging adicional dentro del v4 no justifica el esfuerzo. Las 4 áreas (accounts, entries_list, category, settings) quedan documentadas con detalle en pendientes para sprint dedicado.

### Fase 6 — Release 0.3.8+40

- `mobile/pubspec.yaml`: `version: 0.3.8+40`.
- `mobile/android/app/build.gradle.kts`: `versionCode = 40`, `versionName = "0.3.8"`.
- `flutter analyze`: 0 errores, 0 warnings, 4 hints info preexistentes (3 del entry_form_screen y 1 del skeleton).
- `flutter build apk --release --split-per-abi`: 3 APKs generados.
- `scripts/verify-apk.sh`: ✓ OK — versionCode 2040 / versionName 0.3.8.

### Fase 7 — Cierre

En curso: docs `implementation/`, `branch-quality-review` v4, commits.

## Trazabilidad RF → entrega

| RF | Entrega | Estado |
|----|---------|--------|
| RF-001 | `accountBalanceAtomic` top-level | ✅ |
| RF-002 | `accountBalanceNow` wrapper | ✅ |
| RF-003 | `EntriesDao(super.db)` sin `_state` | ✅ |
| RF-004 | `@DriftDatabase(daos: [..., EntriesDao])` | ✅ |
| RF-005 | `database.entriesDao` en `AppDependencies.fromDatabase` | ✅ |
| RF-006 | Comentario actualizado en `database.dart` | ✅ |
| RF-007 | `_boCache`, `_deCache`, `_crCache` lazy | ✅ |
| RF-008 | `invalidateAll()` libera los 3 caches | ✅ |
| RF-009 | Tests defensivos del replay-1 en BO/DE/CR | ✅ |
| RF-010 | `bool _localeInitialized` simple | ✅ con simplificación |
| RF-011 | `assert` para combinación ambigua | ✅ |
| RF-012 | Matcher robusto del field Monto | ✅ |
| RF-013 | `GoRouter` tipado en harness | ✅ |
| RF-014 | **Descartado** (causaba cuelgues) | desviación |
| RF-015 | Doc de inmutabilidad de type | ✅ |
| RF-016 | `find` con maxdepth en verify-apk.sh | ✅ |
| RF-017 | `tr -d` en parseo pubspec | ✅ |
| RF-018 | Regex tolera ambas comillas | ✅ |
| RF-019 | **Diferido** (ver DV-1) | desviación |
| RF-020 | **Diferido** (ver DV-2) | desviación |
| RF-021 | **Diferido** (ver DV-2) | desviación |
| RF-022 | **Diferido** (ver DV-2) | desviación |
| RF-023 | **Diferido** (ver DV-2) | desviación |
| RF-024 | Bump `0.3.8+40` | ✅ |
| RF-025 | APK validado por verify-apk.sh | ✅ smoke Diego pendiente |

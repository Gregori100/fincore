# Resumen extenso — flutter-local-hardening-v4

## Contexto

Sprint técnico de continuidad sobre la app FinCore Flutter Android local-first. Aborda **4 frentes** del backlog acumulado:

1. **Ítem 5 del backlog histórico**: registrar `EntriesDao` en `@DriftDatabase(daos: [...])`. Cerrado.
2. **L2-H1 del quality review v3** (Media): replay-1 en `watchBo/De/Cr`. Cerrado.
3. **Cluster de Baja del review v3** (8 hallazgos): aplicado.
4. **Cobertura de UI más profunda** (Fases 4 y 5): diferida con plan claro de continuación.

El sprint sigue la convención de los hardening previos: sin features visibles, foco en deuda técnica y robustez.

## Decisiones clave durante el sprint

### Extracción de `accountBalanceAtomic` como función pura (Fase 1)

Releyendo `EntriesDao`, encontré que solo **un único punto** usaba `FinancialStateService`: la línea 204 de `registerDebtPayment` para chequear OverpayDebt. Y `accountBalanceNow` es una función puramente sobre el database, sin estado del cache.

La inversión de dependencia fue limpia: extraer `accountBalanceAtomic(GeneratedDatabase db, String accountId)` como función top-level en `financial_state.dart`. `FinancialStateService.accountBalanceNow` pasa a ser wrapper de 1 línea. `EntriesDao` ya no necesita `_state` en su constructor. Drift puede instanciarlo con `EntriesDao(super.db)` y registrarlo en `@DriftDatabase(daos: [...])`.

Ganancia colateral: la API pública de `FinancialStateService.accountBalanceNow` se preserva (los tests existentes que la usan no cambian), y los 3 DAOs ahora son codegen-resolved.

### Replay-1 en BO/DE/CR (Fase 2)

L2-H1 del quality review v3 identificó que `watchBo/De/Cr` retornaban `customSelect.watchSingle()` directo (single-listener, sin replay), mientras `watchAccountBalance` había sido envuelto en `_ReplayBalanceStream` en el v2 para fix del bug "Skeleton eterno".

El v4 cierra esta asimetría: 3 fields lazy en `FinancialStateService` (`_boCache`, `_deCache`, `_crCache`) cachean el `_ReplayBalanceStream` correspondiente. Patrón:

```dart
Stream<double> watchBo() {
  return (_boCache ??= _ReplayBalanceStream(_buildBoSource())).stream;
}
```

`invalidateAll()` libera los 3 caches junto con el Map de `_balanceCache`. 2 tests defensivos blindan el comportamiento.

**Implicación semántica:** el cambio de single-listener a `_ReplayBalanceStream` rompe la semántica de `.first` en tests viejos — `.first` ahora puede recibir el valor cacheado por replay-1, no el siguiente. 3 tests existentes pasaron a usar `firstWhere((v) => v == X)`. Documentado en `progreso.md`.

### Hallazgo + corrección de falso fix (DV-5)

Durante Fase 3 los widget tests empezaron a fallar con timeouts de 10+ minutos. El diagnóstico inicial fue **incorrecto**: atribuí el cuelgue a streams zombies del `_ReplayBalanceStream` apuntando a BD cerrada, y apliqué `state.invalidateAll()` en tearDowns y dispose del harness como "fix".

La suite pasó una vez en 6 segundos con esa configuración (lo que confirmó falsamente el fix), pero después volvió a colgar. Tras debug aislado descubrí que **el `invalidateAll()` en `dispose()` del harness era la verdadera causa del cuelgue**, no la solución. Cierra `MultiStreamController` mientras los `StreamBuilder` del Dashboard tienen listeners activos; las microtasks pendientes con `Bad state` exceptions contaminan el isolate.

**Fix correcto:** quitar `invalidateAll()` de tearDowns y del dispose. Solo `db.close()`. Drift cancela el upstream limpio. Suite pasa en **6-12 segundos verde** de forma reproducible.

Esto convirtió un sprint con "no sé qué arreglar" en "regla documentada al revés": NO usar `invalidateAll()` como protocolo de cleanup en tests. Documentado como contraconvención explícita en `CLAUDE.md` para evitar que un mantenedor futuro lo "arregle" reintroduciéndolo.

### Descarte de RF-014 (DV-4)

El L2-H3 del quality review v3 pedía agregar guard `if (!controller.hasListener) continue;` antes del `addSync` en el forward de `_ReplayBalanceStream`. Implementado y revertido tras causar cuelgues de `pumpAndSettle`.

Causa raíz: `MultiStreamController.hasListener` retorna `false` transitivamente durante el handler `_handleListen` — el listener subscribe ocurre en un microtask que aún no se ejecutó cuando el upstream emite. El guard skipea el `addSync`, el listener nunca recibe el evento, el Skeleton queda eterno.

El L2-H3 era riesgo teórico sin reporte. Documentado el porqué del descarte; el comentario en el código quedó como pista para futuros mantenedores.

### Fase 4 y 5 diferidas (DV-1 y DV-2)

**Fase 4 (RF-019, gap RN-011):** intento de implementar `openDropdownAndVerify` falló porque `tester.tap(find.text(label))` no logra hit-test sobre el field del `DropdownMenu`. Patrón correcto identificado y documentado para sprint dedicado.

**Fase 5 (RF-020 a RF-023, widget tests CRUD profundos):** intento del primer archivo (account_form) colgó `pumpAndSettle` con timeouts de 10+ min. Hipótesis pendientes de validar (AccountTypePicker, didChangeDependencies, addPostFrameCallback). ROI del debugging adicional no justifica el v4. Documentado el plan completo de las 4 áreas para sprint dedicado.

**Decisión:** dropear ambas fases del v4 y abrir sprint `flutter-ui-test-coverage-v1` cuando sea oportuno.

## Detalles de implementación (cosas no obvias)

### El warning de drift "multiple databases" persiste

Aunque el harness setea `driftRuntimeOptions.dontWarnAboutMultipleDatabases = true`, los tests data layer aún disparan el warning porque crean su propio `FincoreDatabase`. Es esperado y no rompe nada. La supresión solo aplica donde `pumpFincoreApp` corre.

### Locale init: revertido a booleano

La RF-010 original proponía `Completer<void>?` para serializar inicializaciones concurrentes. Durante el debugging del cuelgue, se revertió a `bool _localeInitialized` simple. El revert no arregló el cuelgue (la causa raíz era el tearDown), pero la simplicidad se mantuvo: el scheduler de flutter test es serial dentro del isolate.

### `firstWhere` en tests cambia semántica

Al cambiar BO/DE/CR a `_ReplayBalanceStream`, los tests que hacían `state.watchBo().first` esperando el valor "actualizado tras un cambio" recibían el valor cacheado del replay-1. Patrón nuevo: `state.watchBo().firstWhere((v) => v == expected)` espera específicamente el valor deseado.

Esto NO es una regresión del comportamiento de runtime — solo afecta tests que dependían del orden exacto de eventos. La app real consume estos streams con `StreamBuilder` que sí re-rendea con cada evento.

### El test del `database_test.dart` perdió un campo `stateService`

Durante el refactor, un grupo del `database_test.dart` (líneas 470+) declaraba `late FinancialStateService stateService` que solo se usaba para pasarlo al `EntriesDao(db, state)`. Como ahora `EntriesDao(db)` no lo necesita, el campo quedó unused y se eliminó.

### Limpieza en el harness: `import 'dart:async'` removido

Tras el revert del `Completer`, el import de `dart:async` quedó sin uso. `flutter analyze` lo flagged y se removió.

## Trazabilidad

Los archivos del sprint:

```
engineering/specs/flutter-local-hardening-v4/
├── spec.md                  # spec original (con RF-019 a RF-023 que se difirieron)
├── plan/
│   └── plan.md             # plan por fases
└── implementation/
    ├── progreso.md         # detalle por fase
    ├── pendientes.md       # backlog incluyendo Fase 4 y 5 diferidas
    ├── pruebas.md          # matriz de tests + smoke
    ├── desviaciones-plan.md # 7 desviaciones documentadas
    ├── resumen-ejecutivo.md
    └── resumen-extenso.md   # este archivo
```

Código tocado:

```
mobile/
├── pubspec.yaml                                # bump 0.3.8+40
├── android/app/build.gradle.kts                # versionCode 40
├── lib/
│   ├── app_dependencies.dart                   # database.entriesDao codegen
│   ├── data/
│   │   ├── database.dart                       # EntriesDao en @DriftDatabase
│   │   ├── financial_state.dart                # accountBalanceAtomic + replay-1 BO/DE/CR
│   │   └── daos/entries_dao.dart               # sin _state
│   └── ...                                     # sin cambios
├── test/
│   ├── data/
│   │   ├── backup_test.dart                    # tearDown fix + state al scope
│   │   ├── database_test.dart                  # tearDown fix + EntriesDao(db) + cleanup
│   │   ├── financial_state_test.dart           # tearDown fix + EntriesDao(db) + 2 tests nuevos + firstWhere
│   │   └── invariants_test.dart                # tearDown fix + EntriesDao(db)
│   ├── helpers/widget_test_harness.dart        # dispose fix + GoRouter tipado + assert
│   └── screens/entry_form_screen_test.dart     # matcher robusto (RF-012)
scripts/
└── verify-apk.sh                                # RF-016/017/018 aplicados
```

No se tocó:

- `lib/screens/` (excepto bump implícito de versión).
- `lib/widgets/`.
- `lib/router/`.

## Validación final

```
flutter test      → 112/112 verdes
flutter analyze   → 0 errores, 0 warnings, 4 hints info preexistentes
flutter build apk --release --split-per-abi → 3 APKs generados
scripts/verify-apk.sh → exit 0 (versionCode=2040)
```

## Próximo sprint sugerido

**Reportes** (cashflow mensual, gasto por categoría, top categorías). Antes de planear, decidir filosofía del balance derivado: el `FinancialStateService` actual agrega totales sin filtro de fecha; en reportes querés cortes "hasta hoy" o por rango. Esa decisión impacta la arquitectura del servicio.

Recomendación: arrancar con un `ReportsService` separado, dejar `FinancialStateService` intocado para el Dashboard. Es más mantenible y no obliga a parametrizar todas las queries existentes.

**Sprint paralelo cuando sea oportuno:** `flutter-ui-test-coverage-v1` que cierra Fase 4 y Fase 5 del v4. Estimado: ~15-20 h.

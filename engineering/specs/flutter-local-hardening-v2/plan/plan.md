# Plan técnico — flutter-local-hardening-v2

## Enfoque técnico

Sprint aditivo de cleanup técnico sobre `flutter-local-hardening` (commit `ecb9893`, APK `0.3.0+32`). Cierra 10 ítems de deuda residual con cambios localizados y sin tocar reglas de negocio. Cero impacto en datos del usuario; el único cambio "estructural" es el codegen de drift al registrar `daos: [...]` en `@DriftDatabase`. Bump a `0.3.1+33` (patch release).

Trabaja sobre cinco capas existentes:

1. **Capa de datos** (`mobile/lib/data/`): `@DriftDatabase` con `daos: [...]` + regeneración de `database.g.dart`; refactor de `EntriesDao.updateEntry` para delegar `findActiveById`; `FinancialStateService.watchAccountBalance` retorna stream broadcast (cacheable y con cleanup); `BackupService` con truncado por characters en lugar de substring.
2. **Capa de presentación** (`mobile/lib/widgets/` + `screens/`): foreground del snackbar inyectado desde los helpers; `Share.shareXFiles` con timeout de 2 minutos + fallback `ShareResultStatus.unavailable`.
3. **Tests** (`mobile/test/data/`): 4 tests defensivos nuevos para cubrir huecos identificados en el review previo.
4. **Documentación pública** (`mobile/README.md`): sección nueva "Importar respaldos: límites y validaciones".
5. **Trazabilidad del sprint anterior** (`engineering/specs/flutter-local-hardening/implementation/desviaciones-plan.md`): completar 3 desviaciones menores que no quedaron documentadas.

No cambia: filosofía libreta libre, nomenclatura snake_case de errores tipados, contrato del backup JSON v1, soft-delete terminal, RN-H01/H02/H03.

### Decisión técnica relevante

El comportamiento de `asBroadcastStream()` con cleanup al perder el último listener no está documentado de forma uniforme entre versiones de drift. **Estrategia de plan**: implementar con `.asBroadcastStream()` simple primero, agregar test RF-006 que se suscribe + cancela + resuscribe + verifica. Si el test falla porque el stream queda cerrado, agregar `onCancel` en el broadcast que limpia la entrada del Map. Documentar el patrón final en `CLAUDE.md` solo si se requiere el cleanup explícito (no hay ruido a priori).

## Requisitos funcionales cubiertos

- **RF-001** (broadcast stream): cubierto por T003. `FinancialStateService.watchAccountBalance` retorna `Stream<double>` broadcast cacheado. La implementación inicial usa `.asBroadcastStream()`; si el test de doble suscripción + cancelación detecta cleanup faltante, se agrega `onCancel` que invoca `invalidateAccount` para esa key.
- **RF-002** (cleanup al perder último listener): cubierto condicionalmente por T003 según resultado de T007.
- **RF-003** (test 200 chars exacto): cubierto por T004 con un nuevo test en `backup_test.dart`.
- **RF-004** (test `wipeAll` invalida cache): cubierto por T005 con un test que cruza `BackupService` + `FinancialStateService`.
- **RF-005** (test `watchPage` filtra archivadas): cubierto por T006 con un test en `database_test.dart`.
- **RF-006** (test broadcast doble suscriptor): cubierto por T007 con un test en `financial_state_test.dart`. Es el test que decide si T003 necesita `onCancel`.
- **RF-007** (registrar daos en `@DriftDatabase`): cubierto por T001. Anotación bumpea de `@DriftDatabase(tables: [Accounts, Categories, JournalEntries])` a `@DriftDatabase(tables: [...], daos: [AccountsDao, CategoriesDao, EntriesDao])`. Codegen con `dart run build_runner build --delete-conflicting-outputs`.
- **RF-008** (delegar `findActiveById`): cubierto por T002. La query inline en `EntriesDao.updateEntry` se reemplaza por `attachedDatabase.categoriesDao.findActiveById(effectiveCategoryId)`. Depende de T001.
- **RF-009** (foreground inyectado en snackbar): cubierto por T008. `_buildFincoreSnackBar` recibe `Color foreground` como parámetro requerido; los helpers `showSuccessSnackbar`/`showErrorSnackbar`/`showWarningSnackbar` deciden el color.
- **RF-010** (timeout en share): cubierto por T009. `Share.shareXFiles` envuelto en `.timeout(Duration(minutes: 2), onTimeout: () => const ShareResult(raw: '', status: ShareResultStatus.unavailable))`.
- **RF-011** (characters.take para truncados): cubierto por T010. Se importa `package:characters/characters.dart` en `backup.dart`. Se aplica en `_validateUuid` (16 chars) y `_parseDate` (32 chars).
- **RF-012** (README import): cubierto por T011. Nueva sección con catálogo de errores y límites.
- **RF-013** (desviaciones plan anterior): cubierto por T012. Edición markdown del archivo del sprint anterior.

## Archivos o módulos probablemente afectados

Confirmados por inspección del repo:

- `mobile/lib/data/database.dart` — anotación `@DriftDatabase` línea 89, bumpea con `daos: [...]` (T001).
- `mobile/lib/data/database.g.dart` — regenerado por codegen (T001). Se commitea junto con el cambio.
- `mobile/lib/data/daos/entries_dao.dart` — refactor de `updateEntry` (T002). Eliminar query inline (~6 líneas) y reemplazar por delegación a `attachedDatabase.categoriesDao.findActiveById(...)`.
- `mobile/lib/data/financial_state.dart` — refactor del cache de streams (T003). Aplicar `.asBroadcastStream()` antes de guardar en `_balanceCache`. Posible agregar `onCancel` callback si T007 lo exige.
- `mobile/lib/data/backup.dart` — agregar `import 'package:characters/characters.dart';` + reemplazar `substring(0, 16)` por `value.characters.take(16).string` en `_validateUuid` y `substring(0, 32)` por `raw.characters.take(32).string` en `_parseDate` (T010).
- `mobile/lib/widgets/error_snackbar.dart` — refactor de la firma de `_buildFincoreSnackBar` para recibir `Color foreground` (línea 92) y actualizar los 3 helpers (líneas 152, 166, 180) (T008).
- `mobile/lib/screens/settings_screen.dart` — timeout en `Share.shareXFiles` (línea 53) (T009).
- `mobile/test/data/backup_test.dart` — test 200 chars exacto (T004).
- `mobile/test/data/financial_state_test.dart` — test wipeAll invalida cache (T005) + test broadcast doble suscriptor (T007).
- `mobile/test/data/database_test.dart` — test watchPage filtra archivadas (T006).
- `mobile/pubspec.yaml` — bump `version: 0.3.1+33` (T013).
- `mobile/android/app/build.gradle.kts` — bump `versionCode = 33`, `versionName = "0.3.1"` (T013).
- `mobile/README.md` — nueva sección "Importar respaldos: límites y validaciones" (T011).
- `engineering/specs/flutter-local-hardening/implementation/desviaciones-plan.md` — 3 desviaciones menores agregadas (T012).
- `CLAUDE.md` raíz — opcional, solo si T003 introduce convención nueva (onCancel del broadcast).

## Entidades y estados afectados

- **Schema de BD**: sin cambios. `schemaVersion` sigue en 2.
- **DAOs registrados en `@DriftDatabase`**: cambio de shape interno. Después del codegen, `attachedDatabase` expone getters `accountsDao`, `categoriesDao`, `entriesDao`. Esto es estrictamente aditivo: los DAOs siguen disponibles vía `AppDependencies` y la regeneración no cambia tipos públicos.
- **Cache de streams**: shape interno cambia. La función pública `watchAccountBalance(accountId, accountType)` sigue retornando `Stream<double>` con la misma semántica de eventos; lo que cambia es que el Stream subyacente es broadcast (acepta múltiples suscriptores).
- **`BackupError` y `DomainError`**: sin cambios.
- **Códigos de error tipados**: sin cambios. No se agregan códigos nuevos.

Invariantes preservadas: libreta libre, archive en cascada, soft-delete terminal, RN-H01/H02/H03.

## Compatibilidad con datos y procesos existentes

- **BD del usuario en `0.3.0+32`**: al abrir `0.3.1+33`, drift detecta `schemaVersion == 2` y no ejecuta migración. Datos preservados.
- **Respaldos JSON v1 existentes**: el formato no cambia. Mensajes de error con preview truncado por characters siguen siendo amigables.
- **`database.g.dart` regenerado**: queda en git. Si Diego clona el repo desde cero, `dart run build_runner build --delete-conflicting-outputs` reproduce exactamente. El `.g.dart` actual y el nuevo difieren solo en los getters de DAOs agregados; ningún cambio en tablas o columnas.
- **APK `0.3.0+32` → `0.3.1+33`**: instalación con `adb install -r` preserva datos. Sin necesidad de wipeAll. Downgrade `0.3.1+33 → 0.3.0+32` queda no-soportado igual que en sprints anteriores (documentado en `pendientes.md`).
- **Códigos de error en UI**: la lista mostrada al usuario en mensajes amigables no cambia; lo que cambia es la presentación del preview truncado (caso borde con emoji).
- **Snackbar API**: la firma pública de `showSuccessSnackbar/showWarningSnackbar/showErrorSnackbar` no cambia. Solo cambia la firma interna de `_buildFincoreSnackBar`.

## Cambios de datos

No aplica. Cero cambios de schema, columnas, índices o filas.

## Cambios de API

No aplica. La app sigue sin red.

## Cambios de integraciones

No aplica. El share sheet de Android es API estándar de plataforma, sin cambio de uso. Solo se agrega timeout defensivo.

## Cambios de UI

Mínimos invisibles para el usuario:

- Snackbar warning sigue con texto canvas oscuro sobre fondo amarillo (sin cambio visual). RF-009 cambia solo la implementación interna del cálculo del foreground.
- "Acerca de" mostrará `0.3.1+33` después del bump (cambio visible pero esperado para release).

Cero pantallas nuevas. Cero rutas de `go_router` modificadas. Cero flujos de UX nuevos.

## Cambios de permisos

No aplica. Android Manifest sin cambios.

## Riesgos técnicos

- **Codegen rompe tipos generados** (T001): registrar `daos: [...]` puede modificar el shape de `database.g.dart` de forma inesperada. Mitigación: ejecutar `flutter analyze` + `flutter test` inmediatamente después del codegen. Si compila y tests pasan, OK. Si rompe, revertir y documentar como desviación.
- **Broadcast stream cierra al perder el último listener** (T003): si drift cierra el stream subyacente, la próxima suscripción recibe error o stream cerrado. Mitigación: test RF-006 detecta este caso. Si falla, agregar `onCancel` que limpia la entrada del Map.
- **Broadcast stream sin replay del último evento**: por contrato, `asBroadcastStream` NO entrega eventos pasados a suscriptores tardíos. drift normalmente emite al suscribirse si hay readsFrom; verificar empíricamente que el primer evento llega al primer listener. Mitigación: si la UI dependía implícitamente del primer evento inmediato, los `Skeleton` pueden mantenerse un instante más. Validable en smoke.
- **`characters` package en runtime de Flutter 3.29.3**: el paquete es transitivo de Flutter, sin riesgo de incompatibilidad. Verificar con `flutter analyze` después de agregar el import.
- **Timeout de `Share.shareXFiles`** (T009): si el usuario abre share legítimo y se queda 2+ min eligiendo destino, el timeout dispara cancelando. Riesgo bajo en práctica. Mitigación: documentar como límite conocido.
- **Bump `0.3.0+32` → `0.3.1+33`**: si Diego no había aceptado el bump, ajustar. Por defecto se aplica.
- **`_buildFincoreSnackBar` con nueva firma**: si algún caller no pasa el `foreground`, falla en compile time. Bien: cualquier caller olvidado es un error visible, no silent.
- **Test RF-006 frágil con timing async**: la cancelación + resuscripción puede requerir `Future.delayed(Duration.zero)` o `pump()` para que el broadcast complete su ciclo. Mitigación: documentar el patrón si surge.

## Estrategia de pruebas

Detallada en `test-plan.md`. Resumen por capa:

- **Tests unitarios nuevos**: 4 mínimos (RF-003, RF-004, RF-005, RF-006) en las 3 suites existentes. Suite total sube de 87 a ≥ 91 verde.
- **Tests unitarios existentes**: 87 actuales deben seguir verdes después del codegen y de los refactors (RF-007, RF-008, RF-009).
- **`flutter analyze`**: 0 errores tras cada T, mantiene 4 hints info preexistentes.
- **Codegen**: `dart run build_runner build --delete-conflicting-outputs` ejecuta sin errores nuevos.
- **Smoke manual Diego (T015)**: instalar `0.3.1+33` sobre `0.3.0+32` en el Redmi, validar puntos críticos.

## Estrategia de rollback

Sprint aditivo sin cambios de schema. Rollback por familia:

- **Familia 1 (broadcast)**: revertir cambios en `financial_state.dart`. Si el cache funcionaba antes, sigue funcionando con suscriptor único. Sin impacto en datos.
- **Familia 2 (tests)**: revertibles sin impacto.
- **Familia 3 (codegen)**: revertir `@DriftDatabase` a `tables: [...]` solo y regenerar `database.g.dart` con `daos: []`. Revertir T002 (volver a query inline). Sin impacto en datos.
- **Familia 4 (UX)**: revertir cambios en `error_snackbar.dart` y `settings_screen.dart`. Sin impacto persistente.
- **Familia 5 (characters)**: revertir a `substring`. Sin impacto.
- **Familia 6 (docs)**: revertir markdown.

**Límite conocido** (heredado): downgrade `0.3.1+33 → 0.3.0+32` sobre BD migrada no es soportado por drift. Mismo caso que sprints anteriores; documentado.

## Orden sugerido de implementación

Orden por dependencia + paralelización razonable. 6 fases.

**Fase 0 — Codegen base** (bloqueante de T002):

1. T001 — registrar `daos: [AccountsDao, CategoriesDao, EntriesDao]` en `@DriftDatabase` + `dart run build_runner build --delete-conflicting-outputs`.

**Fase 1 — Refactors core + tests defensivos** (paralelizable entre sí; T002 depende de T001):

2. T002 — `EntriesDao.updateEntry` delega a `attachedDatabase.categoriesDao.findActiveById`.
3. T003 — `FinancialStateService.watchAccountBalance` retorna broadcast stream.
4. T004 — test 200 chars exacto (RF-003).
5. T005 — test wipeAll invalida cache (RF-004).
6. T006 — test watchPage filtra archivadas (RF-005).
7. T007 — test broadcast doble suscriptor (RF-006). Si falla, ajustar T003 con `onCancel`.

**Fase 2 — Refactors menores** (paralelizables entre sí; ninguno depende del anterior):

8. T008 — snackbar foreground inyectado.
9. T009 — timeout en `Share.shareXFiles`.
10. T010 — characters.take en truncados de mensajes.

**Fase 3 — Documentación** (paralelizables entre sí):

11. T011 — sección "Importar respaldos: límites y validaciones" en `mobile/README.md`.
12. T012 — completar `desviaciones-plan.md` del sprint anterior.

**Fase 4 — Release**:

13. T013 — bump `0.3.1+33` (pubspec + gradle).
14. T014 — `flutter build apk --release --split-per-abi` + verificación `aapt`.

**Fase 5 — Smoke manual** (Diego):

15. T015 — instalar `0.3.1+33` sobre `0.3.0+32`, validar:
    - App abre, datos preservados, Settings → "Acerca de" muestra `0.3.1+33`.
    - Edit entry con categoría archivada sigue funcionando (regresión RF-005).
    - Settings → Exportar y luego reiniciar → cancelar el share rápido → snackbar warning "Exportación cancelada".
    - (Opcional) reproducir el caso de share colgado de Share.shareXFiles: no hay forma estándar de simularlo manualmente, así que confirmar solo que el flujo normal sigue funcionando.

**Fase 6 — Cierre**:

16. T016 — crear `engineering/specs/flutter-local-hardening-v2/implementation/` con 6 archivos estándar (progreso, desviaciones-plan, pendientes, implementation-review, resumen-ejecutivo, resumen-extenso).
17. T017 — invocar `branch-quality-review` con slug `flutter-local-hardening-v2`. Si aparecen bloqueantes, resolver in-sprint.

## Casos borde que condicionan la solución

- **Broadcast stream con suscriptor que llega tarde** (T003 + T007): por contrato, `asBroadcastStream` NO replica eventos pasados. drift emite al suscribirse si hay readsFrom previo; el primer listener debería recibir un evento inicial. Suscriptores tardíos esperan al próximo cambio. Test RF-006 debe suscribir dos listeners cuasi-simultáneamente y verificar que el segundo no se queda sin eventos al recibir un trigger.
- **Cancelación del último listener** (T003 + T007): si drift cierra el stream subyacente al perder el último listener y la entry del Map sobrevive, la próxima `watchAccountBalance` con la misma key entrega un stream cerrado (eventos error o nada). Test RF-006 debe: suscribir → cancelar → resuscribir → emitir cambio → verificar que el nuevo listener recibe el cambio. Si falla, T003 agrega `onCancel` que invoca `invalidateAccount` para esa key.
- **`Share.shareXFiles.timeout(Duration(minutes: 2))`** (T009): cuando dispara, el flow `_exportThenReset` recibe `ShareResult` con `status: ShareResultStatus.unavailable`. El flujo ya tiene rama para ese status y muestra warning. Validar que no se procede al wipe.
- **`characters.take(16)` con string ASCII**: indistinguible de `substring(0, 16)`. Cero cambio observable.
- **`characters.take(16)` con string de menos de 16 grapheme clusters**: retorna el string completo. Comportamiento esperado (sin truncado innecesario).
- **`characters.take(16)` con emoji compuesto (4 surrogates)**: el emoji cuenta como 1 grapheme cluster. `take(16)` toma 16 emojis o menos, no 4 (que sería el caso con `substring`).
- **Test 200 chars exacto** (T004 + RF-003): el helper `buildPayload(categoryName: 'A' * 200)` debe pasar. Si pasa con OTRO `BackupError` (ej. `invalid_uuid_format` por payload mal armado), el test debe verificar que el código NO es `string_too_long`, no que NO lance.
- **Test wipeAll invalida cache** (T005 + RF-004): requiere setUp con `BackupService(database, stateService)`. Si el setUp viejo solo pasa `database`, ajustar antes del test (puede romper otros tests del archivo).
- **Test watchPage filtra archivadas** (T006 + RF-005): el setUp ya seedea Bolsa + debit + credit + 2 categorías. Reutilizar. Crear un entry con categoryId activa, archivar la categoría, leer `watchPage()`, verificar que `result.first.category == null`.
- **Codegen drift con `daos: [...]`** (T001): si la regeneración cambia algún tipo público (improbable porque los DAOs ya tenían `@DriftAccessor`), tests pueden fallar al compilar. Recomendación: ejecutar `flutter test` inmediatamente después de T001. Si pasa, OK. Si rompe, evaluar caso por caso.
- **Bump de versión** (T013): coordinar con `kAppVersion` ya eliminado del sprint anterior. Solo 2 lugares a sincronizar (`pubspec.yaml`, `build.gradle.kts`).

## Preguntas o supuestos que siguen afectando la implementación

No hay preguntas pendientes (`preguntas.md` no existe). Supuestos que el plan asume:

- **Comportamiento de `asBroadcastStream`**: drift mantiene la suscripción interna mientras haya listeners; cuando se cancela el último, drift puede cerrar la suscripción. El plan implementa primero sin `onCancel` y agrega solo si T007 lo exige.
- **Codegen reproducible**: `dart run build_runner build --delete-conflicting-outputs` regenera `database.g.dart` con los daos. Si Diego clona el repo desde cero, debe ejecutar este comando antes de `flutter test`.
- **Test RF-006 estable**: la doble suscripción no requiere tickers ni `pump()` porque no es widget test. Si surge inestabilidad por timing async, documentar.
- **`characters` package**: incluido en Flutter SDK por default; no agrega dependencia nueva al pubspec.
- **Bump aceptado**: `0.3.1+33` como patch release técnico.
- **`mobile/README.md` con sección nueva**: ubicación queda a criterio del implementador; sugerencia: después de "Setup desde cero" o antes de "Cómo recuperar el cliente web legacy".
- **Smoke manual T015**: cubre rollback de datos + bump visible + flujo de export. NO cubre el caso del share colgado (sin forma estándar de reproducir).

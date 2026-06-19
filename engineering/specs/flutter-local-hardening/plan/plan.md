# Plan técnico — flutter-local-hardening

## Enfoque técnico

Sprint aditivo de cleanup técnico sobre la app Flutter Android local-first del MVP anterior. Sin reescritura ni rediseño: cada RF toca un punto puntual del código existente, valida la entrada, agrega un guardrail, mueve un valor hardcoded a runtime o documenta una convención. Cero cambios visibles para el usuario salvo dos micro-cambios (flujo de reset con dos botones y color de texto del snackbar warning) que se validan en smoke manual.

Se trabaja sobre las cuatro capas habituales:

1. **Capa de datos** (`mobile/lib/data/`): validaciones de entrada en `BackupService`, guardrail + migración real en `database.dart`, cache de streams en `FinancialStateService`, helper `findActiveById` en `CategoriesDao`, validación de categoría activa en `EntriesDao.updateEntry`.
2. **Capa de presentación** (`mobile/lib/screens/` + `lib/widgets/`): flujo de dos botones en `SettingsScreen`, lectura asíncrona de `package_info_plus` para `kAppVersion`, contraste WCAG en snackbar warning, tooltips/Semantics en iconos críticos.
3. **Capa nativa Android** (`mobile/android/`): atributos de privacidad en `AndroidManifest.xml` + nuevo `res/xml/data_extraction_rules.xml`.
4. **Tooling y docs**: `pubspec.yaml` agrega `package_info_plus`, `CLAUDE.md` documenta tres convenciones nuevas (migraciones, ndkVersion, deps `^`), `mobile/README.md` menciona los límites del import.

El bump de versión es `0.3.0+30` (versionCode 30, versionName "0.3.0") asumiendo el supuesto de la spec; se sincroniza solo en `pubspec.yaml` y `android/app/build.gradle.kts` porque RF-016 elimina la tercera fuente manual (`kAppVersion` en `settings_screen.dart`).

Se mantiene la filosofía libreta libre, la nomenclatura snake_case de códigos de error, el contrato del backup JSON v1 (sin breaking changes en el formato) y el soft-delete terminal. Las reglas nuevas RN-H01/H02/H03 de la spec encajan dentro de ese marco.

### Decisión técnica relevante (no era explícita en la spec)

Al revisar `lib/widgets/error_snackbar.dart` se confirmó que `showErrorSnackbar` rutea por tipo con `switch (error)`: hoy el branch para `BackupError()` no existe, por lo que un `BackupError` cae en el branch genérico `Exception() => error.toString().replaceFirst('Exception: ', ...)` y muestra texto crudo del estilo `"BackupError(invalid_json): ..."`. Para que **RF-007** (mensajes amigables para los nuevos códigos del import) funcione realmente, hace falta:

- crear `backupErrorToMessage(BackupError error)` en `error_snackbar.dart` con el switch case por código (alineado al estilo de `domainErrorToMessage`); y
- agregar el branch `BackupError() => backupErrorToMessage(error)` en el switch de `showErrorSnackbar` antes del branch `Exception()`.

Esta tarea queda foliada como T009 dentro del plan.

## Requisitos funcionales cubiertos

- **RF-001 / RF-002 / RF-003** (validación de enums en import): cubiertos por T005, que agrega guardas en `_entryFromJson`, `_accountFromJson` y `_categoryFromJson` con constantes locales `_validKinds`, `_validAccountTypes`, `_validAppliesToTypes` y lanza `BackupError` tipado por cada uno.
- **RF-004** (amount > 0 en import): cubierto por T006 dentro de `_entryFromJson`.
- **RF-005** (longitudes máximas): cubierto por T007 con constantes `_kMaxNameLength = 200`, `_kMaxDescriptionLength = 1000`.
- **RF-006** (formato UUID v4/v7): cubierto por T008 con regex documentada en la spec.
- **RF-007** (mapeo de errores tipados): cubierto por T009 con `backupErrorToMessage` nuevo + ruteo en `showErrorSnackbar`.
- **RF-008** (allowBackup=false + dataExtractionRules): cubierto por T004.
- **RF-009** (guardrail UnimplementedError en onUpgrade): cubierto por T002, prerequisito para T010.
- **RF-010** (convención de migraciones documentada): cubierto por T003 (sección nueva en `CLAUDE.md`).
- **RF-011** (índice parcial + schemaVersion 1→2 + onUpgrade real): cubierto por T010, depende de T002.
- **RF-012** (cache de streams en `FinancialStateService`): cubierto por T011.
- **RF-013** (reset destructivo con dos botones): cubierto por T014.
- **RF-014** (validación de categoría activa en `updateEntry`): cubierto por T013, depende de T012.
- **RF-015** (helper `findActiveById` + convención de filtros): cubierto por T012; documentación del filtro va dentro de T003.
- **RF-016** (`kAppVersion` con `package_info_plus`): cubierto por T015, depende de T001.
- **RF-017** (política de `ndkVersion` documentada): cubierto por T003.
- **RF-018** (política de deps `^` documentada): cubierto por T003.
- **RF-019** (snackbar warning con texto canvas oscuro): cubierto por T016.
- **RF-020** (tooltips/Semantics en iconos críticos): cubierto por T017.
- **RF-021** (test cancel idempotente preserva balance): cubierto por T018.
- **RF-022** (matriz de transiciones de updateEntry): cubierto por T019, depende de T013.

## Archivos o módulos probablemente afectados

Confirmados por inspección del repo:

- `mobile/pubspec.yaml` — agregar `package_info_plus` (T001) + bump de versión (T021).
- `mobile/lib/data/backup.dart` — agregar constantes `_validKinds/_validAccountTypes/_validAppliesToTypes`, constantes de longitud, regex UUID, validaciones en los tres `_*FromJson` (T005, T006, T007, T008).
- `mobile/lib/data/database.dart` — `onUpgrade` con guardrail (T002), bump `schemaVersion` 1→2, agregar índice parcial en `onCreate`, agregar rama `if (from == 1 && to == 2)` en `onUpgrade` (T010).
- `mobile/lib/data/financial_state.dart` — agregar Map cache `Map<String, Stream<double>>`, refactor de `watchAccountBalance`, exponer método `invalidateAccount(String accountId)` y `invalidateAll()` (T011).
- `mobile/lib/data/daos/categories_dao.dart` — agregar `findActiveById(String id)` (T012).
- `mobile/lib/data/daos/entries_dao.dart` — en `updateEntry`, después de calcular `effectiveCategoryId`, verificar activación; si archivada, forzar `categoryId = null` en el write (T013). También llamar a `_state.invalidateAccount(...)` desde `_register`/`updateEntry`/`cancel`... pendiente de verificar si conviene o si drift `readsFrom` ya lo cubre.
- `mobile/lib/data/daos/accounts_dao.dart` — invocar `_state.invalidateAccount(id)` dentro de `archive(id)` (T011 hermano).
- `mobile/lib/screens/settings_screen.dart` — refactor de `_resetAccount` con flujo de dos botones; refactor de "Acerca de" con `FutureBuilder<PackageInfo>` (T014, T015).
- `mobile/lib/widgets/error_snackbar.dart` — agregar `backupErrorToMessage`, ruteo en `showErrorSnackbar`, ajuste de color en `_buildFincoreSnackBar` para el caso warning (T009, T016).
- `mobile/lib/screens/entries_list_screen.dart` — tooltip en filter `IconButton` (T017).
- `mobile/lib/screens/first_run_screen.dart` — `Semantics(excludeSemantics: true)` en chevrons decorativos (T017).
- `mobile/lib/screens/dashboard_screen.dart` — tooltip en FAB extended (T017).
- `mobile/android/app/src/main/AndroidManifest.xml` — atributos `allowBackup`, `fullBackupContent`, `dataExtractionRules` (T004).
- `mobile/android/app/src/main/res/xml/data_extraction_rules.xml` — archivo nuevo (T004).
- `mobile/android/app/build.gradle.kts` — bump `versionCode` 30 + `versionName` "0.3.0" (T021).
- `CLAUDE.md` raíz — secciones nuevas: convención de migraciones (RF-010), convención de joins con categorías archivadas (RF-015), política de `ndkVersion` (RF-017), política de deps `^` (RF-018) (T003).
- `mobile/README.md` — mencionar límites de longitud del import (T007 hermano).
- `mobile/test/data/backup_test.dart` — tests de validaciones del import (T020).
- `mobile/test/data/database_test.dart` — test cancel idempotente preserva balance + transiciones updateEntry (T018, T019).
- `mobile/test/data/migration_test.dart` (nuevo, opcional) o reusar `database_test.dart` para validar la migración (T020 hermano).

## Entidades y estados afectados

- **JournalEntry.categoryId**: pasa de "puede apuntar a categoría archivada históricamente" a "siempre apunta a categoría activa o es null". La invariante se aplica solo en operaciones futuras (`updateEntry`); los entries históricos creados antes del sprint no se modifican.
- **Account**: sin cambios en el modelo. La operación `archive(id)` agrega un side-effect: invalida la entrada del cache de streams en `FinancialStateService`.
- **Category**: sin cambios en el modelo. Helper nuevo `findActiveById` que filtra `deletedAt.isNull()`.
- **Schema de BD**: `schemaVersion` pasa de 1 a 2. La migración 1→2 es aditiva (CREATE INDEX), no destructiva. Datos existentes intactos.
- **Cache de streams**: nueva estructura interna `Map<String, Stream<double>>` en `FinancialStateService`. Se invalida en dos eventos: `wipeAll()` (limpia todo) y `accountsDao.archive(id)` (limpia la key específica).
- **Códigos de error tipados**: se agregan 5-6 códigos snake_case nuevos al catálogo (`invalid_kind`, `invalid_account_type` versión import, `invalid_applies_to`, `invalid_amount`, `string_too_long`, `invalid_uuid_format`). El código existente `invalid_account_type` ya está en `domainErrorToMessage` para el DAO; el del import comparte el mismo código pero llega vía `BackupError` y se enruta por `backupErrorToMessage`.

Invariantes que NO cambian: libreta libre completa, OverpayDebt como única validación bloqueante, soft-delete terminal, Bolsa singleton, archive en cascada del sprint anterior, transacciones de los DAOs.

## Compatibilidad con datos y procesos existentes

- **BD existente con `schemaVersion = 1`**: al abrir la app `0.3.0+30` por primera vez, `onUpgrade(1, 2)` se ejecuta una sola vez y agrega el índice parcial. Los datos del usuario (cuentas, categorías, entries) quedan intactos.
- **Respaldos JSON v1 existentes**: el formato no cambia. Un respaldo exportado por `0.2.0+29` se importa sin problemas en `0.3.0+30` siempre que cumpla las validaciones nuevas (que son las mismas reglas de dominio que ya existían en los DAOs; un respaldo legítimo siempre las cumple). El único caso donde un respaldo "ok antes" sería rechazado es si tiene `amount = 0` o IDs no-UUID, lo que indicaría que el respaldo original ya era inválido.
- **Respaldos JSON externos malintencionados**: rechazados con `BackupError` tipado + rollback de transacción + snackbar amigable.
- **Movimientos con categoría archivada antes del sprint**: el comportamiento se mantiene: la relación de drift devuelve null y la UI muestra "Sin categoría". Lo nuevo es que `updateEntry` después de RF-014 limpia explícitamente el `category_id` colgante.
- **APK `0.2.0+29` desinstalado y luego se instala `0.3.0+30`**: BD limpia, `onCreate` se ejecuta con el set completo de índices (incluido el nuevo parcial); equivale a primer arranque normal.
- **Downgrade `0.3.0+30` → `0.2.0+29` en cel del usuario**: NO soportado. La BD ya tiene `schemaVersion = 2` y la app vieja espera 1; drift puede reventar al abrir. Se documenta como límite conocido en `pendientes.md` del sprint.

No hay procesos vecinos que se vean afectados: la app es single-user single-instance.

## Cambios de datos

- **Schema**: nuevo índice `CREATE INDEX idx_entries_occurred_active ON journal_entries(occurred_at DESC) WHERE deleted_at IS NULL`. `schemaVersion` pasa a 2.
- **Sin cambios en columnas, tablas, FKs ni constraints**.
- **Datos del usuario**: ninguna fila se altera por la migración; el índice es estructura auxiliar. La única alteración de datos posible viene de **RF-014** (`updateEntry` con categoría archivada forzando `categoryId = null`), pero solo cuando el usuario explícitamente edite un entry afectado.

## Cambios de API

No aplica. La app es local sin red.

## Cambios de integraciones

No aplica. Salvo el share sheet de Android para "Exportar respaldo" (API estándar de la plataforma, sin cambio en uso).

## Cambios de UI

Mínimos:

- **SettingsScreen** (RF-013): la card "Zona peligrosa" pasa de un único botón rojo "Reiniciar cuenta" a dos botones apilados:
  - **Botón primario azul (acento)**: "Exportar respaldo y luego reiniciar". Lanza share sheet; tras share exitoso, muestra un segundo `confirmDialog` enfático antes del `wipeAll()`.
  - **Botón secundario rojo outline**: "Reiniciar sin exportar". Confirmación destructiva como hoy.
- **SettingsScreen** (RF-016): la card "Acerca de" muestra la versión leída de `PackageInfo` vía `FutureBuilder`. Mientras carga, muestra un `Skeleton` corto en el lugar del número.
- **Snackbar warning** (RF-019): el texto y el icono pasan de `Colors.white` a `FincoreColors.canvas` (#1F242B). El fondo amarillo `#EBBD52` no cambia. Visual: texto oscuro sobre amarillo, contraste ≥7:1.
- **Iconos críticos con tooltip** (RF-020): el filter icon de `entries_list_screen`, el FAB extended del Dashboard y el FAB chico de Entries, el "Cambiar tipo" de entry_form. Los chevrons decorativos en first_run y settings se envuelven con `Semantics(excludeSemantics: true)`.

Cero pantallas nuevas. Cero rutas de `go_router` modificadas.

## Cambios de permisos

Android Manifest:

- Agregar `android:allowBackup="false"` y `android:fullBackupContent="false"` en `<application>`.
- Agregar `android:dataExtractionRules="@xml/data_extraction_rules"` en `<application>`.
- Nuevo archivo `res/xml/data_extraction_rules.xml` con bloques `cloud-backup` y `device-transfer` denegados (`<exclude>` o `<include domain="...">` según convención Android API 31+).

No se agrega ni quita ningún `uses-permission` (sigue solo `INTERNET`).

## Riesgos técnicos

- **Migración 1→2 con muchos entries**: el `CREATE INDEX` puede tardar segundos en BDs con histórico grande. Mitigación: el splash del MVP cubre la espera; el índice es parcial, no escanea filas con `deleted_at IS NOT NULL`. Si Diego nota tirón en su Redmi con su volumen real, evaluar `Isolate` en sprint futuro.
- **`package_info_plus` en cels viejos**: requiere API 21+; el `minSdk = 24` lo cubre. Riesgo residual de excepción durante init. Mitigación: `FutureBuilder` con `builder` que muestra `'dev'` o cadena vacía si falla, sin reventar la pantalla.
- **Cambio del color del snackbar warning**: el feel visual cambia. Mitigación: Diego valida en smoke; si rechaza, evaluar oscurecer el fondo `#EBBD52` para mantener texto blanco con contraste.
- **Cache de streams con leaks por orden de invalidación**: si `archive(id)` no invoca `_state.invalidateAccount(id)` antes del `_state.watchAccountBalance` siguiente, la key sobreviviente apunta a un stream de cuenta borrada. Mitigación: tests específicos que verifiquen que el Map queda vacío después de `archive` y `wipeAll`.
- **`updateEntry` forzando categoría null silenciosamente** (RF-014/RN-H03): comportamiento esperado por la spec, pero el usuario que abra un entry viejo no es notificado de que su categoría se "perdió". Mitigación: el badge ya se mostraba vacío antes del fix; el cambio es consistencia interna. Si Diego prefiere notificar, agregar un snackbar amarillo al primer save con categoría perdida (decisión post-smoke).
- **Bump de versión a `0.3.0` interpretado como release menor breaking**: SemVer no aplica formalmente en apps Android single-user, pero documentación interna debe ser clara. Mitigación: el commit del sprint explica que es release menor aditivo, no breaking.
- **Política de versiones `^` documentada pero no enforzada**: depende de disciplina. Mitigación: aceptar como compromiso; CI en sprint futuro.
- **`BackupError` no implementa `DomainError`**: la decisión técnica del plan agrega `backupErrorToMessage` separado en lugar de unificar. Mantiene separación de capas (backup vs dominio) pero duplica el patrón switch case. Aceptable para este sprint; refactor a `sealed class` queda para futuro.
- **Tests del schema migración**: en SQLite in-memory no se puede simular "abrir BD con schemaVersion=1 y luego ver migración". Mitigación: test programa una BD versión 1 manualmente (via `customStatement` o construyendo `NativeDatabase` con `migrationStrategy` mock) y valida que `onUpgrade(1, 2)` agrega el índice. Si la simulación es muy frágil, validar manualmente en smoke.

## Estrategia de pruebas

Detallada en `test-plan.md`. Resumen:

- **Unitarias** (4 suites existentes + ampliaciones): validaciones del import (`backup_test`), migración 1→2 (en `database_test` o nuevo `migration_test`), idempotencia contable de cancel (`database_test`), matriz de transiciones de updateEntry (`database_test`), cache de streams (`financial_state_test`), invalidación del cache en archive/wipeAll (`backup_test` o `financial_state_test`).
- **Smoke manual de Diego**: instalar APK sobre `0.2.0+29`, validar que datos persisten, ejecutar `adb backup` y confirmar rechazo, importar JSON con `kind: 'hacked'` y ver snackbar rojo amigable, editar entry con categoría archivada y ver `categoryId = null` post-save, tocar "Exportar y luego reiniciar" y verificar flujo, activar TalkBack y narrar iconos críticos.
- **Validaciones automáticas**: `flutter test` ≥ 67 verdes, `flutter analyze` 0 errores, `flutter build apk --release --split-per-abi` exitoso.

## Estrategia de rollback

Sprint aditivo. Rollback parcial por familia:

- **Familia 1 (import)**: revertir cambios en `backup.dart` y `error_snackbar.dart`. Sin impacto en datos persistidos.
- **Familia 2 (Android Manifest)**: revertir el manifest a la versión sin `allowBackup`. Sin impacto en datos.
- **Familia 3 (schema)**: la migración 1→2 es aditiva (CREATE INDEX). Para revertir: `DROP INDEX idx_entries_occurred_active` + bajar `schemaVersion` a 1 (requiere migración manual fuera del flujo normal de drift; no soportado por drift sin reset). En la práctica, el rollback de la familia 3 implica reinstalar `0.2.0+29` con BD wiped y reimportar respaldo previo.
- **Familia 4 (cache de streams)**: revertir el refactor de `watchAccountBalance` y quitar el Map. Sin impacto en datos.
- **Familia 5 (UX)**: revertir cambios en `settings_screen` y `entries_dao`. Sin impacto persistente salvo entries que ya hayan tenido `categoryId` limpiado por RF-014; eso no es reversible sin restaurar respaldo previo.
- **Familia 6/7/8**: revertibles sin impacto.

**Límite conocido** (también en `pendientes.md`): downgrade `0.3.0+30` → `0.2.0+29` sobre BD migrada no es soportado por drift sin `wipeAll`.

## Orden sugerido de implementación

Orden por dependencia + paralelización razonable:

**Fase 0 — Base independiente** (paralelizable entre sí):

1. T001 — agregar `package_info_plus` a `pubspec.yaml` + `flutter pub get`.
2. T002 — guardrail `onUpgrade` con `UnimplementedError` (RF-009).
3. T003 — actualizar `CLAUDE.md` con las 4 convenciones nuevas (RF-010, RF-015, RF-017, RF-018).
4. T004 — `AndroidManifest.xml` + `data_extraction_rules.xml` (RF-008).

**Fase 1 — Capa de datos: import** (paralelizable entre familia 1; depende solo de T002 trivialmente):

5. T005 — validar enums en los tres `_*FromJson` (RF-001, RF-002, RF-003).
6. T006 — validar `amount > 0` (RF-004).
7. T007 — validar longitudes con constantes `_kMaxNameLength` y `_kMaxDescriptionLength` (RF-005). Actualizar `mobile/README.md`.
8. T008 — validar formato UUID con regex (RF-006).
9. T009 — `backupErrorToMessage` + ruteo en `showErrorSnackbar` (RF-007). Depende de T005..T008 para conocer todos los códigos a mapear.

**Fase 2 — Capa de datos: schema y streams**:

10. T010 — bump `schemaVersion` 1→2 + índice parcial en `onCreate` + rama `if (from == 1 && to == 2)` en `onUpgrade` (RF-011). Depende de T002.
11. T011 — cache de streams en `FinancialStateService` + invalidación en `archive` y `wipeAll` (RF-012). Independiente de T010.

**Fase 3 — Capa de datos: categorías**:

12. T012 — `CategoriesDao.findActiveById` (RF-015).
13. T013 — `EntriesDao.updateEntry` valida categoría activa y fuerza null si archivada (RF-014). Depende de T012.

**Fase 4 — Presentación**:

14. T014 — `SettingsScreen._resetAccount` con flujo de dos botones (RF-013).
15. T015 — `kAppVersion` con `PackageInfo` + `FutureBuilder` (RF-016). Depende de T001.
16. T016 — snackbar warning con texto canvas oscuro (RF-019).
17. T017 — tooltips/Semantics en iconos críticos (RF-020).

**Fase 5 — Tests**:

18. T018 — test `cancel idempotente preserva balance` (RF-021).
19. T019 — grupo de tests de transiciones de `updateEntry` (RF-022). Depende de T013.
20. T020 — tests de validaciones del import (T005..T008) + test de migración 1→2 + tests del cache de streams (familia 4).

**Fase 6 — Release**:

21. T021 — bump `versionName = "0.3.0"` + `versionCode = 30` en `pubspec.yaml` y `android/app/build.gradle.kts`.
22. T022 — `flutter build apk --release --split-per-abi`.
23. T023 — smoke manual de Diego: instala APK sobre `0.2.0+29`, valida migración + flujos críticos (incluye `adb backup` rechazo, import malicioso, reset con dos botones, TalkBack).

**Fase 7 — Cierre**:

24. T024 — crear `engineering/specs/flutter-local-hardening/implementation/` con `progreso.md`, `desviaciones-plan.md`, `pendientes.md` (M6, M11, M17, M19, M24, M25 + downgrade no soportado + límite conocido del cache si aparece), `implementation-review.md`, `resumen-ejecutivo.md`, `resumen-extenso.md`.
25. T025 — `branch-quality-review` con slug `flutter-local-hardening`. Reporte en `engineering/quality-review/flutter-local-hardening/`. Si aparecen bloqueantes nuevos, resolverlos en la misma sesión como hicimos en el sprint anterior.

## Casos borde que condicionan la solución

- **Import con `kind = 'hacked'` o `type = 'savings'` o `applies_to = 'whatever'`**: el `BackupError` se lanza ANTES del batch insert, dentro de la fase de parseo (`_*FromJson`). La transacción no llega a abrirse. La BD existente queda intacta. (Hoy ya tiene rollback de transacción para JSON inválido — esto solo cierra el hueco de enums.)
- **Import con `amount = 0.0` o `amount = -100.5` o `amount = null`**: rechaza con `invalid_amount`. El caso `null` se cubre por el cast `(json['amount'] as num)` que lanza `TypeError` antes; lo dejamos sin manejo explícito (es indistinguible del rechazo por `invalid_json` en el wrapper general).
- **Import con `name` de exactamente 200 caracteres**: pasa. **201**: rechaza con `string_too_long`. Mensaje debe incluir nombre del campo (`'name'`) y longitud observada.
- **Import con `description = null`**: pasa (descripción es opcional, no se valida longitud).
- **Import con `id = '01923456-789a-7bcd-8def-0123456789ab'`** (UUID v7 válido): pasa.
- **Import con `id = '01923456-789a-4bcd-8def-0123456789ab'`** (UUID v4 válido): pasa (regex acepta v4 y v7).
- **Import con `id = '01923456-789a-3bcd-8def-0123456789ab'`** (UUID v3, no esperado): rechaza con `invalid_uuid_format`.
- **Import con `id` en MAYÚSCULAS**: regex `[a-fA-F]` acepta ambos. Pasa.
- **Migración 1→2 con BD ya en versión 2**: drift no llama `onUpgrade`. Idempotente por contrato del framework.
- **Migración 1→2 con error al CREATE INDEX** (improbable, pero p.ej. nombre colisiona): drift propaga la excepción; la app crashea al abrir. Mitigación: el índice tiene nombre único `idx_entries_occurred_active` no colisionante.
- **Bump accidental a `schemaVersion = 3` sin rama**: `onUpgrade(2, 3)` lanza `UnimplementedError`. Visible en logs. La build de release NO lo previene; el guardrail es para QA.
- **`updateEntry` sobre entry cuya categoría se archivó AYER**: post-RF-014, el write incluye `categoryId = null`. La UI ya mostraba "Sin categoría" antes, no hay cambio visual.
- **`updateEntry` cambiando `categoryId` explícitamente de archivada a otra archivada**: `_validateCategoryForKind` aplicado a la NUEVA `categoryId` detecta archivada y forza null. Comportamiento consistente con el caso anterior.
- **`updateEntry` con `clearCategory = true` y `categoryId = X`**: la prioridad de `clearCategory` se respeta como hoy; el write usa null sin pasar por la validación de RF-014.
- **Cache de streams: dos suscripciones simultáneas a la misma `(accountId, accountType)`**: la primera crea el stream y lo guarda en el Map; la segunda recibe el mismo stream. Drift coalesces la query subyacente.
- **Cache: `archive(id)` invalida la key `'$id:type'`** pero los suscriptores existentes (StreamBuilder en el Dashboard) tienen referencia al stream viejo. Como la cuenta ya está archivada y desaparece del `watchActive` del Dashboard, los StreamBuilder se desmontan. El stream viejo queda sin listeners y se cierra. No hay leak.
- **Cache: `wipeAll()` invalida todo**: equivalente al caso anterior multiplicado por N. Después del wipe, el Dashboard se desmonta por el redirect a `/first-run`.
- **Share sheet cancelado**: `Share.shareXFiles` retorna `ShareResult` con `status: ShareResultStatus.dismissed` o `unavailable`. El flow "Exportar y luego reiniciar" debe inspeccionar ese status; si no es `success`, no procede al reset y muestra snackbar neutro "Exportación cancelada".
- **Share sheet con error técnico** (sin app de destino): mismo manejo que cancelado.
- **`package_info_plus` falla en `init`**: el `FutureBuilder` recibe error; el `builder` muestra `'dev'`.
- **TalkBack activado con `Semantics(excludeSemantics: true)`**: los chevrons decorativos no se narran; el card padre (que sí tiene `onTap` con label visible) sí se narra.
- **APK reinstalado con `versionCode = 30` sobre `versionCode = 29` con datos del usuario**: drift detecta `schemaVersion = 1` en disco vs `schemaVersion = 2` en código, ejecuta `onUpgrade(1, 2)`. Datos del usuario preservados.

## Preguntas o supuestos que siguen afectando la implementación

No hay preguntas pendientes (`preguntas.md` no existe). Supuestos relevantes que el plan asume:

- **Versionado**: `0.3.0+30` aceptado por Diego. Si prefiere `0.2.1+30`, ajuste trivial en T021 y CLAUDE.md.
- **`BackupError` separado de `DomainError`**: se mantiene la separación; `backupErrorToMessage` vive en `error_snackbar.dart` junto a `domainErrorToMessage`. Refactor a `sealed class` queda para sprint futuro.
- **Cache de streams invalida en `archive` y `wipeAll`**: no en `updateEntry`, `cancel`, `register*` porque drift `readsFrom` ya invalida automáticamente. Riesgo asumido por la spec.
- **Migración 1→2 incluye SOLO el índice parcial**: cualquier otro cambio de schema queda para futuros sprints con rama propia.
- **Tests de migración**: aceptable validar en `database_test.dart` con setup manual de BD vieja; si la simulación es frágil, complementar con smoke manual de Diego instalando APK sobre `0.2.0+29`.
- **Downgrade no soportado**: documentado en `pendientes.md` post-sprint como límite conocido.
- **Snackbar warning con texto canvas**: si Diego rechaza el feel, fallback a oscurecer el fondo. Decisión post-smoke.
- **TalkBack manual**: no hay tests automatizados de a11y; validación queda en smoke.

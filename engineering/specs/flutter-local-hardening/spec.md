# Hardening + cleanup del sprint flutter-local-mvp

## Resumen

Sprint técnico que cierra 20 de los 25 hallazgos no bloqueantes detectados por el `branch-quality-review` del sprint anterior `flutter-local-mvp` (commit `44c3614`, APK `0.2.0+29`). Sin features visibles para el usuario; foco en robustez del import de respaldos, privacidad de la BD local, performance en mediano plazo, guardrails de migraciones de schema, accesibilidad y mantenibilidad del código de versión. Resultado esperado: app con misma funcionalidad observable pero con superficie de error más cerrada y deuda técnica del MVP reducida a cinco ítems explícitos de backlog futuro.

## Problema a resolver

El sprint `flutter-local-mvp` se cerró con 56 → 59 tests verdes y 5 bloqueantes corregidos in-sprint, pero el `branch-quality-review` identificó 25 hallazgos no bloqueantes documentados como M1..M25 en `engineering/quality-review/flutter-local-mvp/2026-06-18-1550-branch-quality-review.md`. Cinco de esos hallazgos son cosméticos o features visibles que no aplican a un sprint técnico (M6, M11, M17, M19, M24, M25). Los veinte restantes representan deuda técnica concreta:

- El import de JSON acepta enums inválidos, montos no positivos, longitudes ilimitadas y UUIDs malformados.
- El APK Android permite `adb backup` extraer la BD local con todos los movimientos.
- `schemaVersion = 1` con `onUpgrade` stub puede crashear silenciosamente si alguien bumpea el número sin implementar la migración.
- `watchAccountBalance` no cachea streams; con N cuentas hay N suscripciones idénticas que cuestan memoria.
- La lista de movimientos carece de un índice parcial sobre `occurred_at DESC` filtrado por `deleted_at IS NULL`; el `watchPage` degradará con 50k+ entries.
- El reset destructivo en Settings no ofrece exportar respaldo previo.
- `updateEntry` no re-valida si la categoría heredada fue archivada entre el insert original y el update.
- `kAppVersion` está hardcoded en tres archivos sincronizados a mano cada release.
- El snackbar amarillo de warning roza el umbral WCAG AA con texto blanco.
- Algunos iconos críticos no tienen `Semantics`/`tooltip` para TalkBack.
- No hay test de `cancel` idempotente verificando balance ni matriz de transiciones de `updateEntry`.
- Convenciones de `ndkVersion` y dependencias `^` no están documentadas.

Dejarlos sin atacar genera riesgo creciente en seis frentes: integridad de datos por respaldos hostiles, privacidad por exfiltración vía `adb backup`, performance al crecer el histórico, regresiones silentes en futuras migraciones, accesibilidad de cumplimiento mínimo y mantenibilidad por desincronizaciones manuales.

## Objetivo

Reducir la deuda técnica del MVP del 100 % (25 hallazgos abiertos) a 20 % (5 ítems explícitamente diferidos a backlog) sin tocar el modelo de dominio ni las pantallas existentes, manteniendo la libreta libre intacta. Bumpear `schemaVersion` de 1 a 2 con `onUpgrade` real y documentar la convención para evitar bumps accidentales en el futuro. Llevar la suite de tests de 59 a ~70 verdes con coberturas nuevas en validaciones de import, transiciones de `updateEntry` y idempotencia contable de `cancel`.

## Alcance

- Validaciones de entrada en `BackupService.importFromJson` (enums, monto, longitudes, UUID, errores tipados nuevos).
- Configuración Android: `android:allowBackup="false"`, `android:fullBackupContent="false"`, `dataExtractionRules`.
- Migración `schemaVersion` 1 → 2: índice parcial nuevo + `onUpgrade` real + guardrail para versiones no implementadas.
- Performance: cache de streams en `FinancialStateService.watchAccountBalance` con invalidación en `wipeAll`/`archive`.
- UX robustecida: reset destructivo con flujo de dos botones (Exportar+Reiniciar / Reiniciar sin exportar) y validación de categoría activa en `updateEntry`.
- Mantenibilidad: `kAppVersion` desde `package_info_plus` con fallback en tests; helper `findActiveById` en `categoriesDao`; convenciones de migraciones, `ndkVersion` y deps `^` documentadas en `CLAUDE.md`.
- Accesibilidad: contraste WCAG AA en snackbar warning y `Semantics`/`tooltip` en iconos críticos.
- Tests adicionales: `cancel idempotente preserva balance` y matriz de transiciones de `updateEntry`.
- Bump de versión a `0.3.0+30` (versión menor por la suma de cambios, no breaking) sincronizado en `pubspec.yaml`, `android/app/build.gradle.kts` y vía `package_info_plus` en runtime.

## Fuera de alcance

- **M6** (firma de release para Play Store): requiere clave privada y proceso de distribución; queda para spec separada cuando aparezca demanda.
- **M11** (export en streaming para JSON gigantes): hoy Diego no tiene volumen alto; difiero hasta evidencia empírica de OOM.
- **M17** (filtro por categoría en `entries_list_screen`): es feature visible, no cleanup técnico; entrar al sprint de reportes futuro.
- **M19** (hint cosmético `prefer_const_constructors`): tres líneas; se corrige in-sprint si conviene pero no es un RF foliado.
- **M24** (typing fantasma en `DropdownMenu` M3): comportamiento del widget de Material 3, no del código.
- **M25** (loader de progreso en `FirstRunScreen` durante import): aceptable hoy según el quality review.
- Widget tests aplazados T043-T045 del sprint anterior: revisar en otro sprint dedicado a coverage UI.
- Reactivación de archivados, edición de `kind` en movimientos, multi-usuario, sync con backend, reportes, plan engine, refactor de modelos duplicados: backlog ya documentado en `engineering/specs/flutter-local-mvp/implementation/pendientes.md`.

## Reglas de negocio

Las reglas del MVP no cambian. Se mantiene la libreta libre completa, la nomenclatura de errores tipados snake_case, los 5 kinds, RN-011 sobre tipo↔cuenta, el soft-delete terminal y el archive en cascada introducido al cierre del sprint anterior. Se agregan tres reglas nuevas alineadas con ese marco:

- **RN-H01**: el `BackupService.importFromJson` rechaza payloads con valores fuera del catálogo (`kind`, `type`, `applies_to`), montos no positivos, strings que exceden los límites declarados o IDs con formato no UUID. Cada caso lanza un `BackupError` tipado distinto y no toca la BD existente (rollback de transacción).
- **RN-H02**: cualquier futuro PR que incremente `schemaVersion` en `database.dart` está obligado a implementar la migración correspondiente en `onUpgrade`. El guardrail por defecto lanza `UnimplementedError` para evitar crashes silenciosos en producción.
- **RN-H03**: si `updateEntry` recibe un entry cuya `category_id` heredada apunta a una categoría archivada, fuerza `categoryId = null` en el write (no falla con error). Mantiene la consistencia visual de "Sin categoría" y elimina FKs colgantes en cascada.

## Requisitos funcionales

### Familia 1 — Seguridad del import (M1-M4)

- **RF-001**: `BackupService._entryFromJson` valida que `kind` ∈ `{income, expense, credit_expense, debt_payment, transfer}`. Si no, lanza `BackupError('invalid_kind', mensaje)`.
- **RF-002**: `BackupService._accountFromJson` valida que `type` ∈ `{cash, debit, credit}`. Si no, lanza `BackupError('invalid_account_type', mensaje)`.
- **RF-003**: `BackupService._categoryFromJson` valida que `applies_to` ∈ `{income, expense, both}`. Si no, lanza `BackupError('invalid_applies_to', mensaje)`.
- **RF-004**: `BackupService._entryFromJson` valida que `amount > 0`. Si no, lanza `BackupError('invalid_amount', mensaje)`.
- **RF-005**: las tres funciones `_*FromJson` validan que `name.length ≤ 200` y `description.length ≤ 1000`. Si alguna excede, lanza `BackupError('string_too_long', mensaje con campo y longitud)`.
- **RF-006**: las tres funciones `_*FromJson` validan que el campo `id` matchee la regex de UUID v4/v7 (`^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[47][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$`). Si no, lanza `BackupError('invalid_uuid_format', mensaje con campo y valor truncado)`.
- **RF-007**: los nuevos códigos de error (`invalid_kind`, `invalid_account_type` versión import, `invalid_applies_to`, `invalid_amount`, `string_too_long`, `invalid_uuid_format`) están mapeados en `domainErrorToMessage` de `lib/widgets/error_snackbar.dart` a mensajes amigables en español que incluyen el campo afectado cuando corresponde.

### Familia 2 — Privacidad de datos locales (M5)

- **RF-008**: `mobile/android/app/src/main/AndroidManifest.xml` declara en `<application>` los atributos `android:allowBackup="false"`, `android:fullBackupContent="false"` y `android:dataExtractionRules="@xml/data_extraction_rules"`. El archivo `mobile/android/app/src/main/res/xml/data_extraction_rules.xml` existe y deniega tanto `cloud-backup` como `device-transfer`.

### Familia 3 — Schema y migraciones (M12)

- **RF-009**: `mobile/lib/data/database.dart` redefine `onUpgrade` para que, por defecto, lance `UnimplementedError('Schema upgrade $from → $to no implementado')`. Las migraciones concretas se agregan como `if (from == X && to == Y) { ... }` antes del throw.
- **RF-010**: `CLAUDE.md` documenta la convención: cualquier PR que toque `schemaVersion` o las definiciones de tablas requiere implementar la migración correspondiente en `onUpgrade` antes de mergear. La sección queda bajo "Capa de datos / Migraciones".

### Familia 4 — Performance SQL (M8, M9)

- **RF-011**: `mobile/lib/data/database.dart` agrega en `onCreate` la sentencia `CREATE INDEX idx_entries_occurred_active ON journal_entries(occurred_at DESC) WHERE deleted_at IS NULL`. `schemaVersion` se bumpea a 2 y `onUpgrade` incluye la rama `if (from == 1 && to == 2) { await m.customStatement('CREATE INDEX ...'); }` para que instalaciones existentes migren sin crear la BD desde cero.
- **RF-012**: `FinancialStateService` mantiene un `Map<String, Stream<double>>` interno keyado por `'$accountId:$accountType'`. `watchAccountBalance` retorna el stream cacheado si existe; si no, crea uno nuevo con `customSelect(...).watchSingle()` y lo guarda. El cache se invalida (vacía) en dos eventos: cuando `BackupService.wipeAll()` se ejecuta y cuando `AccountsDao.archive(id)` se ejecuta para esa cuenta específica.

### Familia 5 — UX robustecida (M7, M14, M15)

- **RF-013**: `SettingsScreen._resetAccount` reemplaza el botón único actual por dos botones bajo la card "Zona peligrosa":
  - **Botón primario (acento azul)**: "Exportar respaldo y luego reiniciar". Al tocarlo dispara `_export()` (share sheet). Si el usuario completó el share, muestra un segundo `confirmDialog` con texto "El respaldo se compartió correctamente. ¿Continuar con el reseteo?" y, tras confirmar, ejecuta `wipeAll()`. Si el share fue cancelado, no procede al reset.
  - **Botón secundario (outline rojo)**: "Reiniciar sin exportar". Muestra un `confirmDialog` enfático con el texto actual ("Esto BORRA toda tu BD...") y, tras confirmar, ejecuta `wipeAll()`.
- **RF-014**: `EntriesDao.updateEntry` calcula `effectiveCategoryId` como hoy. Antes del write, si `effectiveCategoryId != null`, ejecuta `_validateCategoryForKind` y, si la categoría está archivada, fuerza `effectiveCategoryId = null` en el write (no lanza error). Si la categoría está activa pero no aplica al kind, mantiene el error `invalid_category_applies_to`.
- **RF-015**: `CategoriesDao` expone un método nuevo `findActiveById(String id)` que retorna `null` si la categoría no existe o está archivada. `CLAUDE.md` documenta la convención: "todo join sobre `categories` desde la UI debe filtrar `deletedAt.isNull()` o usar `findActiveById` para evitar mostrar categorías fantasma".

### Familia 6 — Mantenibilidad (M13, M22, M23)

- **RF-016**: `lib/screens/settings_screen.dart` reemplaza `const String kAppVersion = '0.3.0+30'` por una lectura asíncrona de `PackageInfo.fromPlatform()` (paquete `package_info_plus`). El widget de "Acerca de" se renderiza con `FutureBuilder<PackageInfo>`. En tests, donde `PackageInfo.fromPlatform()` no resuelve, se usa fallback al string hardcoded `'dev'` o vacío sin reventar.
- **RF-017**: `CLAUDE.md` documenta la política de `ndkVersion`: "el valor en `android/app/build.gradle.kts` está hardcoded en `27.0.12077973` porque los plugins nativos del proyecto lo requieren. Revisar tras cada `flutter upgrade` por si el default del SDK cambia; si Flutter actualiza a 28 y los plugins lo soportan, bumpear y eliminar el override."
- **RF-018**: `CLAUDE.md` documenta la política de versiones `^` en `pubspec.yaml`: "no ejecutar `flutter pub upgrade` sin revisar changelogs de `drift`, `go_router` y `sqlite3_flutter_libs`. Para iteración rápida se mantienen las versiones flotantes; para releases estables se evalúa pinear las críticas a una versión exacta."

### Familia 7 — Accesibilidad (M20, M21)

- **RF-019**: `lib/widgets/error_snackbar.dart` cambia el color del texto del snackbar `warning` de `Colors.white` a `FincoreColors.canvas` (negro oscuro #1F242B). El icono y el texto comparten ese color para mantener consistencia. El contraste pasa de ~3.8:1 a ≥7:1 contra el fondo `#EBBD52`.
- **RF-020**: los siguientes iconos críticos reciben `tooltip` o `Semantics`:
  - `IconButton` con filter icon en `entries_list_screen.dart`: `tooltip: 'Filtros'`.
  - Chevron derecho de `_OptionCard` en `first_run_screen.dart` y de la card de Categorías en `settings_screen.dart`: envueltos en `Semantics(excludeSemantics: true)` por ser decorativos.
  - Botón "Cambiar tipo" en `entry_form_screen.dart`: ya tiene label visible; agregar `tooltip: 'Cambiar tipo de movimiento'` para TalkBack.
  - Icon del FAB del Dashboard y de Entries list: `tooltip` con el label visible del FAB.

### Familia 8 — Tests adicionales (M16, M18)

- **RF-021**: nuevo test en `mobile/test/data/database_test.dart`: `'cancel idempotente preserva balance'`. Crea un income de $500 sobre Bolsa, captura `accountBalanceNow(bolsa)` después del primer cancel, ejecuta cancel una segunda vez, verifica que el balance post-segundo-cancel coincide con el post-primer-cancel y que ambos son 0.
- **RF-022**: nuevo grupo de tests en `mobile/test/data/database_test.dart` bajo `group('EntriesDao.updateEntry transiciones')`. Cubre al menos cuatro escenarios:
  - Editar `amount` + `description` + `occurredAt` simultáneamente en un income; verifica que los tres campos persisten.
  - Editar `categoryId` a una categoría compatible (income → income); verifica el cambio.
  - Editar `categoryId` a una categoría con `applies_to` incompatible (intentar pasar a una expense en un income); verifica que lanza `invalid_category_applies_to`.
  - Editar `accountOriginId` en un expense a otra cuenta cash/debit activa; verifica que persiste y no rompe `_validateAccountTypes`.

## Casos principales

1. **Import limpio**: el usuario importa un JSON exportado por la misma versión de la app. Todas las validaciones (RF-001..RF-006) pasan, el batch insert se ejecuta dentro de la transacción y el FirstRunState se marca `true`.
2. **Reset con exportar primero**: el usuario en Settings toca "Exportar respaldo y luego reiniciar", completa el share sheet, confirma el segundo diálogo, la BD se vacía y la app redirige a `/first-run`.
3. **App actualiza de `0.2.0+29` a `0.3.0+30`**: la BD existente con `schemaVersion = 1` se migra a `schemaVersion = 2` ejecutando `onUpgrade` que solo agrega el índice parcial. Los datos del usuario se preservan intactos.
4. **Editar una entry con categoría que se archivó después del insert**: el usuario abre el form, toca Guardar sin cambiar `categoryId`; `updateEntry` detecta que la categoría heredada está archivada y persiste el entry con `categoryId = null`. El badge desaparece de la UI.
5. **Dashboard con 10 cuentas activas**: al cargar, `_BalanceLabel` para cada cuenta llama `watchAccountBalance(id, type)`. El cache devuelve el mismo stream para llamadas repetidas, drift coalesces la query y los listeners compartidos se reevalúan una sola vez por cambio en `journal_entries`.

## Casos borde

- **Import con `kind = 'hacked'`**: rechaza con `invalid_kind`; la BD existente queda intacta (rollback de transacción + validación previa al insert).
- **Import con `amount = 0` o `amount = -100`**: rechaza con `invalid_amount`; mismo rollback.
- **Import con `name` de 500 caracteres**: rechaza con `string_too_long` indicando el campo y la longitud observada.
- **Import con `id = 'abc'`**: rechaza con `invalid_uuid_format` indicando el campo y el valor truncado a los primeros 16 caracteres en el mensaje.
- **Share sheet cancelado en el flujo "Exportar y luego reiniciar"**: no procede al reset; el usuario vuelve a la pantalla Settings con el estado limpio (sin spinner colgado, sin snackbar de error).
- **Cuenta archivada con balance distinto a cero por movimientos compensatorios**: el cache de streams elimina solo la entrada de esa cuenta; los streams del resto del Dashboard siguen vivos.
- **App con `schemaVersion = 1` instalada que abre por primera vez `0.3.0+30`**: `onUpgrade(1, 2)` se ejecuta una sola vez, agrega el índice y el BD queda con `schemaVersion = 2`. Reabrir la app no re-ejecuta la migración.
- **Bump accidental a `schemaVersion = 3` sin implementar la rama**: la app crashea al abrir con `UnimplementedError` visible en logs. La build de release no lo previene; el guardrail es para detectarlo en QA antes de Play Store.
- **`PackageInfo.fromPlatform()` falla en un cel con Android 7.0 viejo**: el fallback retorna `'dev'` o cadena vacía sin reventar la pantalla de Settings.
- **TalkBack activado**: los iconos críticos con tooltip se narran con el label correcto; los decorativos (chevrons) son ignorados por `Semantics(excludeSemantics: true)`.

## Criterios de aceptacion

- `flutter test` ejecuta y reporta **al menos 67 tests verdes** (59 actuales + 6 nuevos mínimos del scope: 4 de transiciones de `updateEntry`, 1 de `cancel` idempotente con balance, 1 mínimo de validaciones del import por familia que detecte regresiones).
- `flutter analyze` reporta 0 errores y 0 warnings (los hints `info` de `prefer_const_constructors` permanecen aceptables).
- `flutter build apk --release --split-per-abi` produce un APK arm64 con `versionCode = 30` y `versionName = "0.3.0"` que instala limpiamente sobre el `0.2.0+29` existente en el Redmi de Diego sin perder datos.
- Manual: ejecutar `~/Android/Sdk/platform-tools/adb backup io.github.gregori100.fincore` sobre el cel rechaza la operación con "Backup not allowed".
- Manual: importar un JSON modificado a mano con `"kind": "hacked"` en una entry muestra el snackbar rojo con el mensaje amigable mapeado por `domainErrorToMessage`. La BD previa al import queda intacta.
- Manual: editar un entry cuya categoría se archivó después del insert y tocar Guardar persiste el entry con `categoryId = null` (el badge desaparece) sin lanzar error visible.
- Manual: en Settings, tocar "Exportar respaldo y luego reiniciar" abre el share sheet; al completarlo, muestra el segundo diálogo de confirmación; al confirmarlo, redirige a `/first-run`. Tocar "Reiniciar sin exportar" omite el share sheet pero requiere confirmación enfática.
- Manual: con 5+ cuentas activas en el Dashboard, abrir DevTools (en debug) y verificar que `FinancialStateService` mantiene un solo stream por `(accountId, accountType)` en lugar de N suscripciones idénticas.
- Manual: TalkBack activado en el cel narra correctamente los iconos del filter, FABs y "Cambiar tipo".
- Documentación: `CLAUDE.md` contiene las tres secciones nuevas (migraciones, ndkVersion, deps ^) y la convención de `categoriesDao.findActiveById`. `mobile/README.md` menciona los límites de longitud de campos del import.
- Repositorio: `engineering/quality-review/flutter-local-mvp/...` queda intacto. Los 20 hallazgos atacados quedan referenciados como cerrados en `implementation/desviaciones-plan.md` del nuevo sprint con el ID del fix. Los 5 hallazgos diferidos quedan listados explícitamente como fuera de alcance en `implementation/pendientes.md`.

## Criterios medibles de exito

- **Cobertura de tests**: subir de 59 a ≥67 verdes (≥13.5 % de crecimiento).
- **Deuda técnica del quality review**: bajar de 25 abiertos a 5 abiertos explícitos (80 % de cierre).
- **Archivos sincronizados manualmente para versión**: bajar de 3 (`pubspec.yaml`, `build.gradle.kts`, `settings_screen.dart`) a 2 (`pubspec.yaml`, `build.gradle.kts`).
- **Performance de `watchPage`** con 50k entries sintéticos (test de stress opcional): tiempo de query ≤ 10 ms con el índice parcial nuevo, vs el budget de la spec MVP. Si el test de stress no se implementa, validar al menos que el plan de ejecución (`EXPLAIN QUERY PLAN`) usa el índice nuevo.
- **Streams activos en Dashboard con 10 cuentas**: bajar de 15 a 5 (3 BO/DE/CR + 1 lista cuentas + 1 lista entries; balances individuales coalescidos por cache).
- **Contraste WCAG**: snackbar warning pasa de 3.8:1 a ≥7:1.
- **Superficie de ataque del import**: bajar de 4 campos sin validar (kind, type, applies_to, amount, longitudes, UUID) a 0.

## Riesgos

- **Migración 1 → 2 con datos reales**: ejecutar `CREATE INDEX` sobre una BD con muchos entries puede tardar varios segundos al abrir la app. Mitigación: el índice parcial es liviano (solo filas con `deleted_at IS NULL`); el `await m.customStatement` espera la finalización antes de continuar; el splash del MVP cubre el tiempo de carga si es perceptible. Si Diego tiene >10k entries reales para el bump y nota tirón, evaluar mover la migración a un `Isolate`.
- **`package_info_plus` en cels viejos**: la versión 8.x del paquete requiere Android API 21+ (todo cubierto por `minSdk = 24`), pero un caso borde podría tirar excepción. Mitigación: el fallback en `FutureBuilder` muestra `'dev'` o cadena vacía en lugar de reventar.
- **Cambio del color de texto del snackbar warning**: el feel visual cambia (texto oscuro sobre fondo amarillo en lugar de blanco). Diego podría percibirlo como menos llamativo. Mitigación: smoke manual antes de cerrar el sprint; si rechaza el cambio, evaluar oscurecer el fondo `#EBBD52` para mantener texto blanco con contraste suficiente.
- **Cache de streams con leaks**: si la invalidación en `archive` o `wipeAll` no se ejecuta en el orden correcto, una entrada del Map puede sobrevivir a la cuenta borrada. Mitigación: tests específicos que verifiquen que después de `archive(id)` el cache no contiene la key para esa cuenta.
- **`updateEntry` forzando `categoryId = null` por categoría archivada**: el comportamiento es silencioso (no muestra error al usuario). Si el usuario esperaba que su entry mantuviera el badge, podría sorprenderse. Mitigación: el badge ya se mostraba vacío antes del fix (la relación devolvía null); el cambio asegura consistencia interna sin alterar la percepción visual.
- **Bump a `0.3.0+30`** con BD migrada que se quiere downgrade: si Diego instala un APK viejo `0.2.0+29` después de migrar a `schemaVersion = 2`, la BD ya tiene el índice y `schemaVersion = 2` mientras la app espera `schemaVersion = 1`. Drift puede reventar. Mitigación: no se downgrades en el flujo normal; documentar en `pendientes.md` que el downgrade requiere `wipeAll()` previo.
- **Política de versiones `^` documentada pero no enforzada**: depende de disciplina humana. Mitigación: aceptar como compromiso del sprint; en sprint futuro de CI evaluar agregar workflow que bloquee bumps no revisados.

## Supuestos

- Diego acepta el bump de `versionName` a `0.3.0` para reflejar la suma de cambios técnicos (no breaking). Si prefiere `0.2.1+30`, el cambio es trivial pero la documentación de "release menor" en CLAUDE.md asume `0.3.0`.
- Los nuevos códigos de error tipados del import (`invalid_kind`, `invalid_account_type` versión import, `invalid_applies_to`, `invalid_amount`, `string_too_long`, `invalid_uuid_format`) usan snake_case existente y se mapean en `domainErrorToMessage` a mensajes amigables en español.
- El cache de streams en `FinancialStateService` se invalida totalmente con `wipeAll()` y parcialmente (solo la key afectada) con `AccountsDao.archive(id)`. No se invalida en `updateEntry` o `cancel` porque drift ya reemite vía `readsFrom`.
- El fallback de `package_info_plus` en tests usa `'dev'` o cadena vacía; los tests no validan el contenido del label sino su ausencia de excepción.
- La migración `schemaVersion 1 → 2` incluye SOLO el índice parcial nuevo. Cualquier otro cambio de schema queda para sprints futuros con su propia rama en `onUpgrade`.
- El `data_extraction_rules.xml` deniega tanto `cloud-backup` como `device-transfer`. Si Android añade otra categoría futura, se ajusta entonces.
- El flujo "Exportar y luego reiniciar" no maneja casos de share sheet con error técnico (sin app de destino, espacio en disco lleno, etc.). Si el `_export()` falla, muestra el snackbar rojo y no procede al reset; el usuario puede reintentar.
- Los tests de transiciones de `updateEntry` (RF-022) son al menos 4 escenarios; agregar más es bienvenido pero no requerido para cerrar el sprint.

## Impacto esperado

- **Robustez del import** sube de "best-effort" a validación estricta: 20 % menos superficie de ataque para respaldos malintencionados o accidentalmente corruptos.
- **Privacidad de la BD local** mejora: `adb backup` queda bloqueado, el flujo oficial es Export JSON desde Settings.
- **Performance percibida** en mediano plazo: el índice parcial garantiza que `watchPage` se mantenga sub-10 ms hasta 50k+ entries; el cache de streams baja N suscripciones idénticas a 1.
- **Seguridad de futuras migraciones**: cualquier bump accidental de `schemaVersion` crashea visiblemente en QA en lugar de corromper la BD silenciosamente.
- **Accesibilidad mínima**: snackbar warning cumple WCAG AA; TalkBack narra iconos críticos.
- **Mantenibilidad del versionado**: bajan los lugares a sincronizar a mano; menor probabilidad de "Acerca de" mostrando una versión vieja por descuido.
- **Cobertura de tests**: las transiciones de `updateEntry` y la idempotencia contable de `cancel` quedan blindadas; el riesgo de regresiones silentes en contabilidad cae.
- **Deuda técnica del MVP**: pasa de 25 hallazgos abiertos a 5 explícitamente diferidos, dejando el codebase mejor preparado para los sprints de features (reportes, sync, plan engine).
- **Cero impacto visible para el usuario final** salvo el flujo nuevo de reset con dos botones y el cambio cromático del snackbar warning, ambos validados en smoke manual.

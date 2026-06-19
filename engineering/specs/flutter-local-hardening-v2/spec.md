# Hardening v2 — cierre de deuda residual del sprint flutter-local-hardening

## Resumen

Sprint técnico de continuidad sobre la app FinCore Flutter Android local-first. Cierra los **10 ítems** de deuda residual que quedaron diferidos al cerrar el sprint anterior `flutter-local-hardening` (commit `ecb9893`, APK `0.3.0+32`): 9 hallazgos no bloqueantes del `branch-quality-review` del 2026-06-19 + 1 test de regresión descubierto en el smoke manual de Diego. Sin features visibles para el usuario; foco en robustez, mantenibilidad, accesibilidad de la jerarquía de errores, cobertura de tests y documentación pública. Resultado esperado: codebase listo para arrancar el siguiente sprint de features (probablemente reportes) sin arrastrar deuda técnica del hardening previo.

## Problema a resolver

El sprint `flutter-local-hardening` cerró 20 de los 25 hallazgos del review original + atacó in-sprint 3 bloqueantes detectados al final + corrigió 1 regresión post-smoke. Los **9 hallazgos no bloqueantes restantes** + **1 test defensivo** quedaron documentados como deuda en:

- `engineering/specs/flutter-local-hardening/implementation/pendientes.md`.
- `engineering/quality-review/flutter-local-hardening/2026-06-19-1019-branch-quality-review.md` (sección "Hallazgos no bloqueantes").
- Comentario al cierre del sprint sobre el test del join de categorías archivadas (regresión real corregida en código, pero sin test específico de defensa).

Dejarlos sin atacar tiene tres consecuencias concretas:

1. **Bug latente en el cache de streams**: la implementación cachea streams retornados por drift `.watchSingle()`. Esos streams son single-listener por default. Hoy no se manifiesta porque la UI consume cada `(accountId, accountType)` desde exactamente un widget activo, pero cualquier feature futura que agregue un segundo widget al mismo balance lanzará `StateError: Stream has already been listened to` en runtime sin warning.
2. **Cobertura de tests con huecos identificados**: el límite inclusivo de 200 chars en strings del import, la invalidación del cache desde `wipeAll`, el filtro de categorías archivadas en `watchPage` y el comportamiento broadcast del cache no tienen tests. Cualquier regresión en esos puntos pasa al smoke manual.
3. **Mantenibilidad menor**: foreground del snackbar inferido por igualdad de instancia, `Share.shareXFiles` sin timeout, query inline `findActiveById` duplicada del helper, truncado UTF-16 en mensajes de error, README sin documentar límites del import, y desviaciones menores no documentadas en el sprint anterior.

El siguiente sprint planeado son **reportes** (features visibles). Convencional dejar el codebase con esta deuda quemaría tiempo de ese sprint en pequeñas correcciones que conviene cerrar antes.

## Objetivo

Cerrar los 10 ítems del scope con cambios localizados y sin tocar reglas de negocio. Bumpear a `0.3.1+33` (patch release porque son fixes técnicos, no breaking, no features). Mantener `flutter analyze` limpio y subir la suite de tests de **87 → ≥ 91 verdes** con 4 tests defensivos nuevos. El quality review final puede repetirse y los 10 ítems quedan cerrados explícitamente.

## Alcance

- Refactor del cache en `FinancialStateService.watchAccountBalance` para devolver streams broadcast (RH2-001 / M6).
- Tests defensivos: límite 200 chars exacto inclusivo en import (RH2-002 / M7), `wipeAll` invalida cache (RH2-003 / M8), `watchPage` filtra categorías archivadas (RH2-004 / regresión smoke), `watchAccountBalance` retorna stream broadcast suscriptible 2+ veces (RH2-001 hermano de implementación).
- Refactor estructural: registrar DAOs en `@DriftDatabase`, regenerar `database.g.dart`, eliminar query inline de `findActiveById` en `EntriesDao.updateEntry` (RH2-005 / M12).
- Refactor del color del snackbar: foreground inyectado desde los helpers en lugar de inferido por igualdad de instancia (RH2-006 / M9).
- Timeout en `Share.shareXFiles` con manejo de `onTimeout` que libera `_working = false` y muestra warning (RH2-007 / M10).
- Truncado por caracteres reales (`characters.take(N).string`) en mensajes de error de import en lugar de `substring` por code units (RH2-008 / M14).
- Documentación pública: nueva sección en `mobile/README.md` con límites y catálogo de errores del import (RH2-009 / M4).
- Completar `engineering/specs/flutter-local-hardening/implementation/desviaciones-plan.md` con las desviaciones menores que faltaron (RH2-010 / M13).
- Bump a `0.3.1+33` (pubspec.yaml + android/app/build.gradle.kts) y build APK release split-per-abi.

## Fuera de alcance

- **Bug del cache de streams en producción**: no hay reportes ni evidencia empírica. El refactor a broadcast es defensivo, no recuperativo. Si en uso real aparece otro bug del cache, se trata como nuevo hallazgo.
- **Tests de migración 1→2 con `_executeMigrationAtVersion`**: la herramienta de drift testing existe pero requiere setup específico. Sigue pendiente para un sprint dedicado.
- **Refactor de la jerarquía `BackupError` vs `DomainError`**: el plan v1 evaluó unificarlas en una `sealed class` pero se difirió. Sigue diferido.
- **Reactivación de archivados, edición de `kind`, multi-usuario, sync con backend, reportes, plan engine**: backlog de producto, no de hardening.
- **Pipeline CI / firma de release para Play Store**: scope distinto.
- **Optimización de export en streaming para JSON gigantes**: sin demanda real todavía.
- **Filtro por categoría en `entries_list_screen`**: feature visible, entra al sprint de reportes.
- **Hints `prefer_const_constructors`** en `skeleton.dart:75` y `entry_form_screen.dart:260/262`: cosméticos.
- **Loader de progreso en `FirstRunScreen` durante import grande**: aceptable hoy.
- **`DropdownMenu` M3 typing fantasma**: comportamiento del widget.
- **Widget tests aplazados** del MVP (T043-T045): siguen aplazados.

## Reglas de negocio

Las reglas del MVP + las RN-H01/H02/H03 del sprint anterior no cambian. Este sprint NO introduce nuevas reglas de negocio. Las consecuencias técnicas relevantes:

- **RN-H01** (import valida estructura + rollback): se preserva. La única diferencia es que los mensajes de error truncados por `characters` siguen siendo amigables aunque el valor incluya emoji o chars multi-byte.
- **RN-H02** (migraciones requieren `onUpgrade`): se preserva.
- **RN-H03** (`updateEntry` limpia silenciosamente categoría heredada archivada): se preserva. RH2-004 agrega test que valida que la consecuencia visible en los listados (badge ausente) se mantiene.

## Requisitos funcionales

### Familia 1 — Streams broadcast (RH2-001)

- **RF-001**: `FinancialStateService.watchAccountBalance(accountId, accountType)` devuelve un Stream broadcast. La cacheabilidad sigue: dos llamadas con la misma `(accountId, accountType)` retornan el mismo Stream y dos suscriptores simultáneos reciben los mismos eventos sin lanzar `StateError`. Implementación: aplicar `.asBroadcastStream()` después de `.watchSingle()` (o equivalente que satisfaga la semántica broadcast antes de guardar en `_balanceCache`).
- **RF-002**: cuando todos los suscriptores se cancelan, el stream broadcast debe permitir nuevas suscripciones futuras sin recrear la entry del cache (drift maneja el cierre del stream subyacente; el caso a evitar es que el cache queden con un stream cerrado que retorne errores). Si el comportamiento de drift fuerza recrear, documentar en `CLAUDE.md` la convención y eliminar la entrada del cache en algún hook si fuera necesario.

### Familia 2 — Tests defensivos (RH2-002, RH2-003, RH2-004 + hermano de RF-001)

- **RF-003**: agregar test `Import con name de 200 chars exactos pasa validación` en `mobile/test/data/backup_test.dart`. El test crea un payload válido salvo por `name = 'A' * 200` y verifica que NO se lanza `BackupError('string_too_long', ...)`. Si lanza otro `BackupError`, se permite (no es la condición que se testea).
- **RF-004**: agregar test `wipeAll invalida cache de streams` en `mobile/test/data/financial_state_test.dart` o `backup_test.dart`. Sembrar BD con datos, suscribirse a `watchAccountBalance(bolsa, 'cash')`, ejecutar `backup.wipeAll()`, llamar `watchAccountBalance(bolsa, 'cash')` de nuevo y verificar que retorna un Stream distinto del original (`identical(s1, s2) == false`).
- **RF-005**: agregar test `watchPage no incluye badge para categorías archivadas` en `mobile/test/data/database_test.dart`. Sembrar entry con `categoryId = X` (activa), archivar X, leer `watchPage()` y verificar que el primer `EntryWithRelations.category` retornado es `null` (no la fila de la categoría archivada). Defensa contra la regresión del sprint anterior.
- **RF-006**: agregar test `watchAccountBalance cacheado acepta múltiples suscriptores simultáneos` en `mobile/test/data/financial_state_test.dart`. Suscribir dos `StreamSubscription` distintos a la misma `(accountId, accountType)` y verificar que no se lanza excepción y que ambos reciben emisiones tras un insert.

### Familia 3 — Refactor estructural drift (RH2-005)

- **RF-007**: registrar `daos: [AccountsDao, CategoriesDao, EntriesDao]` en la anotación `@DriftDatabase` de `mobile/lib/data/database.dart`. Regenerar `database.g.dart` con `dart run build_runner build --delete-conflicting-outputs`. Validar que el codegen completa sin warnings nuevos.
- **RF-008**: reemplazar la query inline `(select(categories)..where(c.id.equals(...) & c.deletedAt.isNull())).getSingleOrNull()` dentro de `EntriesDao.updateEntry` por delegación a `attachedDatabase.categoriesDao.findActiveById(effectiveCategoryId)`. La lógica de RN-H03 (silent clear si retorna null) se mantiene idéntica.

### Familia 4 — Robustez UX (RH2-006, RH2-007)

- **RF-009**: refactor de `lib/widgets/error_snackbar.dart`. La función `_buildFincoreSnackBar` recibe un parámetro adicional `Color foreground` (en lugar de inferirlo por `==` con `FincoreColors.warning`). Los helpers `showSuccessSnackbar` (`foreground = Colors.white`), `showErrorSnackbar` (`Colors.white`) y `showWarningSnackbar` (`FincoreColors.canvas`) son quienes deciden el color. Esto rompe el acoplamiento con la comparación de instancia y deja explícito el contrato.
- **RF-010**: envolver el `await Share.shareXFiles(...)` dentro de `_exportInternal` de `mobile/lib/screens/settings_screen.dart` con `.timeout(Duration(minutes: 2), onTimeout: () => const ShareResult(raw: '', status: ShareResultStatus.unavailable))`. El resto del flujo `_exportThenReset` ya distingue `ShareResultStatus.success` del resto, así que el timeout cae al snackbar warning "Exportación cancelada" sin necesidad de manejo adicional.

### Familia 5 — Robustez del import (RH2-008)

- **RF-011**: en `lib/data/backup.dart`, dentro de `_validateUuid`, reemplazar `value.substring(0, 16)` por `value.characters.take(16).string`. Importar `package:characters/characters.dart`. Mismo cambio en `_parseDate` para el truncado a 32 chars del mensaje `invalid_date_format`.

### Familia 6 — Documentación (RH2-009, RH2-010)

- **RF-012**: agregar a `mobile/README.md` una sección **"Importar respaldos: límites y validaciones"** después del bloque actual de "Setup desde cero" o donde corresponda según la estructura del README. La sección documenta:
  - Los 10 códigos de error tipados del import (`invalid_json`, `unsupported_version`, `missing_bolsa`, `invalid_reference`, `invalid_kind`, `invalid_account_type`, `invalid_applies_to`, `invalid_amount`, `string_too_long`, `invalid_uuid_format`, `invalid_date_format`, `invalid_credit_limit`, `invalid_credit_metadata`, `invalid_color_slug`, `invalid_icon_slug`, `protected_account`).
  - Límites declarados: `name ≤ 200`, `description ≤ 1000`, `amount > 0`, UUID v4/v7, credit metadata (`credit_limit > 0`, `closing_day/payment_day ∈ [1,31]` y distintos, `interest_rate/minimum_payment_pct ∈ [0,1]`), Bolsa singleton.
  - Nota que el formato es JSON v1 compatible con el backend Laravel legacy.
- **RF-013**: completar `engineering/specs/flutter-local-hardening/implementation/desviaciones-plan.md` con tres desviaciones menores que no quedaron documentadas:
  - `isNull` matcher ambiguo entre drift y `flutter_test` → cambiado a `equals(null)` en `database_test.dart`.
  - `_buildPayload` renombrado a `buildPayload` por lint `no_leading_underscores_for_local_identifiers`.
  - Query inline `findActiveById` en `EntriesDao.updateEntry` por falta de `daos: [...]` registrados. Anotar que RH2-005 del sprint v2 lo resuelve.

## Casos principales

1. **Refactor del cache de streams**: el Dashboard sigue funcionando idéntico para el usuario. Internamente, `watchAccountBalance` retorna un broadcast stream cacheable que permite múltiples suscriptores. Cualquier feature futura puede agregar un widget secundario al mismo balance sin crash.
2. **Migración a daos registrados**: tras el codegen, `attachedDatabase.categoriesDao` queda disponible. `EntriesDao.updateEntry` delega su validación de categoría activa al helper canónico. La duplicación desaparece.
3. **Snackbar warning con color explícito**: el desarrollador que en el futuro pase un color modificado (ej. con opacidad) recibe el foreground que él especifique, no un default que falla por comparación de instancia.
4. **Share sheet colgado**: si el usuario inicia "Exportar respaldo y luego reiniciar" y el share sheet del sistema no responde durante 2 minutos, el timeout dispara, el flow muestra "Exportación cancelada. No se reinició la BD." y los botones de Settings se reactivan sin necesidad de reiniciar la app.
5. **Documentación del import accesible**: cualquier usuario que arme un JSON manualmente (testing, scripts, importación de respaldos legacy) puede leer en el README las reglas y entender por qué un import puede rechazar.

## Casos borde

- **Stream broadcast con suscriptor que llega tarde**: drift emite el último valor conocido cuando hay readsFrom previo, pero `.asBroadcastStream()` por contrato no replica el valor anterior. Verificar si la UI necesita el primer evento inmediato o si el `StreamBuilder` con `initialData` cubre. Si surge, documentar como límite.
- **Cancelación de todos los suscriptores**: cuando el último listener cancela, el broadcast stream interno puede cerrarse. Si la entrada del cache queda apuntando a un stream cerrado, una próxima suscripción debe recibir error o crear stream nuevo. Comportamiento esperado: drift recrea la suscripción interna en el siguiente listener si el `customSelect` original sigue vivo. Si esto no se cumple, agregar lógica de "limpiar entrada al perder último listener". Es caso borde a validar en implementación.
- **`name` con exactamente 200 chars en el import**: pasa (RF-003).
- **`name` con 200 chars ASCII vs 200 chars de emoji multi-byte**: la longitud cuenta code units UTF-16; un emoji de 2 surrogates cuenta 2. El test usa ASCII; el comportamiento con multi-byte queda como dato observable (no es regresión).
- **Truncado en mensaje de error con string de 1 emoji**: con `characters.take(16)` el preview muestra el emoji completo. Con `substring(0, 16)` por code units, un emoji al char 16 quedaría partido. RF-011 lo resuelve.
- **Share sheet retorna status `success` pero el sistema reportó timeout antes**: improbable. El timeout es 2 min; en práctica el share sheet retorna en segundos. Si pasa, el flow trata el evento como `unavailable` (timeout fallback) y no procede al reset. Conservador.
- **`flutter pub get` después del bump tira deps incompatibles**: improbable porque el sprint no agrega deps nuevas. Validar igual.
- **Codegen rompe tests existentes**: si registrar `daos: [...]` cambia el shape de algún tipo generado, algunos tests pueden compilar mal. Validar `flutter analyze` + `flutter test` post-codegen.
- **`backup.ab` post smoke**: el `.gitignore` ya lo excluye (`*.ab` agregado en sprint anterior). Verificar que sigue ignorado tras este sprint.

## Criterios de aceptacion

- `flutter test` ejecuta y reporta **al menos 91 tests verdes** (87 actuales + 4 mínimos: RF-003, RF-004, RF-005, RF-006).
- `flutter analyze` reporta 0 errores y 0 warnings (los hints info preexistentes permanecen aceptables).
- `dart run build_runner build --delete-conflicting-outputs` ejecuta sin errores y `database.g.dart` queda regenerado con los getters de DAOs.
- `flutter build apk --release --split-per-abi` produce APK arm64 con `versionCode = 33` y `versionName = "0.3.1"`. `aapt dump badging` confirma `versionCode='2033'` (arm64 prefix + 33).
- APK arm64 instala limpiamente sobre el `0.3.0+32` previamente instalado en el Redmi sin perder datos.
- Manual: tocar el botón "Exportar respaldo y luego reiniciar" + cancelar share inmediatamente → snackbar warning "Exportación cancelada" (verifica que el flujo de fallback sigue OK).
- Manual: Settings → "Acerca de" sigue mostrando `0.3.1+33`.
- Documentación: `mobile/README.md` contiene la nueva sección con la lista de los 10+ códigos de error y los límites; cita "JSON v1 compatible con el backend Laravel legacy".
- Documentación: `engineering/specs/flutter-local-hardening/implementation/desviaciones-plan.md` contiene las 3 desviaciones menores agregadas con nota de que RH2-005 resuelve la duplicación.
- Repositorio: los 10 ítems del scope quedan referenciados como cerrados en `implementation/desviaciones-plan.md` del nuevo sprint con el ID del fix.

## Criterios medibles de exito

- **Cobertura de tests**: de 87 → ≥ 91 verdes (≥ 4.6 % de crecimiento). Los 4 tests nuevos cubren los huecos identificados; cualquier regresión futura en esos puntos se detecta automáticamente.
- **Reducción de deuda técnica del review previo**: de 9 abiertos → 0 abiertos (con el dato visible en `implementation/pendientes.md` del sprint v2).
- **Reducción de duplicación de código**: de 1 query inline duplicada de `findActiveById` → 0.
- **Robustez del cache de streams**: capacidad demostrable de soportar 2+ suscriptores simultáneos sin `StateError` (cubierto por RF-006).
- **Robustez del flujo de export**: tiempo máximo bloqueado por share sheet sin respuesta pasa de "indefinido" a "2 minutos" antes de recuperarse automáticamente.

## Riesgos

- **`asBroadcastStream()` cambia semántica del primer evento**: los broadcast streams no entregan el último valor a suscriptores tardíos por contrato. Si la UI dependía implícitamente del primer event inmediato (`StreamBuilder` lo trata como `initialData = null`), no debería romperse pero hay que validar empíricamente. Mitigación: probar en el Redmi tras el cambio y observar si los `Skeleton` siguen mostrándose por un instante mayor que antes.
- **`asBroadcastStream()` y cleanup de drift**: si el broadcast stream se cierra al perder el último listener pero queda cacheado en el Map, una siguiente suscripción podría recibir error de stream cerrado. Mitigación: implementar `onCancel` que elimine la entrada del Map cuando se cancela el último listener, o usar `StreamController.broadcast()` propio para tener control. Implementación lo decide; documentar el patrón en `CLAUDE.md` si surge sutileza.
- **Codegen de drift con `daos: [...]`**: regenerar `database.g.dart` puede afectar nombres o tipos generados. Si la versión cambiada del `.g.dart` no se commitea correctamente, futuros checkouts requieren ejecutar `build_runner` antes de compilar. Mitigación: documentar paso de codegen en `mobile/README.md` (ya está) y verificar que el `.g.dart` queda en git.
- **`Share.shareXFiles` con timeout 2 min**: si el usuario abre un share sheet legítimo y se queda 2+ min eligiendo destino, el timeout dispara aunque eventualmente complete. Riesgo bajo: en práctica los usuarios deciden destino en segundos. Mitigación: registrar como límite conocido.
- **Bump de patch `0.3.0+32` → `0.3.1+33`**: si Diego ya ve la versión `0.3.0+32` instalada como "estable", puede que prefiera congelarla. Mitigación: confirmar antes del build final que el bump es OK. Por defecto se aplica.
- **`characters.take(N).string`**: la API del paquete `characters` es estable en Flutter 3.x. Sin riesgo material; documentar el patrón.

## Supuestos

- **Versionado**: `0.3.1+33` aceptado por Diego. Patch porque son fixes técnicos sin features ni breaking changes. Si prefiere `0.3.0+33`, ajuste trivial pero la documentación asume `0.3.1`.
- **Broadcast stream y drift**: la semántica esperada es que `drift.customSelect(...).watchSingle().asBroadcastStream()` mantiene el comportamiento de invalidación `readsFrom` y entrega eventos a múltiples suscriptores simultáneos. Si durante la implementación surge que drift requiere un patrón distinto, ajustar en `desviaciones-plan.md`.
- **Cleanup del cache al perder último listener**: si drift no maneja el cierre automáticamente, la implementación agrega `onCancel` en el broadcast para sacar la entrada del cache. Si lo maneja, no hace falta. La diferencia se resuelve durante implementación + tests.
- **Codegen incremental**: `dart run build_runner build --delete-conflicting-outputs` regenera todo el `.g.dart`. Es seguro. Si surge conflicto con `accounts_dao.g.dart` etc., evaluar caso a caso.
- **`mobile/README.md` con nueva sección**: ubicación de la sección queda a criterio del implementador; la spec sugiere "después de Setup desde cero" pero puede ir donde naturalmente fluya en el README actual.
- **Test de `watchPage no incluye badge para categorías archivadas` (RF-005)**: el setUp del test ya seedea Bolsa, debit y dos categorías. Reutilizar; archivar la categoría con `archive(catId)` y verificar.
- **Tests del cache (RF-004, RF-006)**: si la inyección actual de `BackupService(database, stateService)` complica el setUp, alternativa es testear `state.invalidateAll()` directamente con un fake `BackupService` que solo llame `invalidateAll`.

## Impacto esperado

- **Cobertura de tests** sube a ≥ 91 verdes; los 4 ítems defensivos cubren huecos conocidos y dejan el codebase resistente a regresiones futuras en esos puntos.
- **Deuda técnica del review previo** pasa de 9 a 0 ítems abiertos.
- **Robustez del cache de streams** queda preparada para soportar features que necesiten observar el mismo balance desde múltiples widgets (ejemplo: pantalla de reportes que muestre el saldo actual junto a un detalle).
- **Robustez del flujo de export** queda preparada para Sistemas Android con share sheet inestable: 2 min de tolerancia + fallback automático.
- **Mantenibilidad del snackbar**: el color foreground se decide explícitamente por el caller; futuros refactors del color de fondo no rompen el contraste WCAG.
- **Documentación del import accesible**: el desarrollador que arme un JSON manualmente o que extienda el formato a `version: 2` tiene la referencia en el README sin tener que leer el código.
- **Cero impacto visible para el usuario** salvo el bump de versión visible en Settings → "Acerca de".

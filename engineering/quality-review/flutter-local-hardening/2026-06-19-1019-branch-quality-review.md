# Branch Quality Review: flutter-local-hardening

## Metadata

- Fecha: 2026-06-19 10:19 CDMX
- Rama revisada: `main`
- Rama base: `44c3614` (commit de cierre de `flutter-local-mvp`)
- Rango: HEAD = `44c3614` + working tree (sin commits adicionales). Sprint pendiente de commit.
- Commit HEAD: `44c3614`
- Autor de revisión: skill `branch-quality-review` con 6 subagentes Explore en paralelo + validación manual de hallazgos críticos.
- Carpeta de reporte: `engineering/quality-review/flutter-local-hardening/`

## Resumen ejecutivo

- Sprint técnico que cierra 20 de los 25 hallazgos no bloqueantes del review previo (`flutter-local-mvp/2026-06-18-1550`). Tests pasaron de 59 → **81 verdes**, `flutter analyze` queda en 4 hints info cosméticos preexistentes. APK arm64 = 19.5 MB, `versionCode='2030'`, `allowBackup=0x0` y `dataExtractionRules` confirmados con `aapt`.
- Hallazgos: **3 bloqueantes** (1 crítico de import sin try-catch en `_parseDate`, 1 alto de UX donde el form de edición rompe la promesa de RN-H03, 1 alto de validación faltante en metadata de credit accounts) + **11 no bloqueantes** + algunos falsos positivos descartados por validación manual.
- **El sprint NO está listo para commit** sin resolver al menos B1, B2 y B3. Los 3 son fixes pequeños (5-30 líneas cada uno) que pueden aplicarse in-sprint como hicimos en `flutter-local-mvp`.
- Riesgos residuales que sobreviven al sprint: hallazgo latente del cache de streams (`watchSingle()` retorna stream single-listener, no se manifiesta hoy pero queda como deuda), falta test de migración 1→2 en suite automática, README sin documentar límites del import.

## Alcance revisado

- Commits: ninguno (working tree). 21 archivos modificados, ~824 insertions / 79 deletions según `git diff --stat`.
- Archivos principales:
  - **Capa de datos**: `mobile/lib/data/backup.dart`, `database.dart`, `financial_state.dart`, `daos/{accounts,categories,entries}_dao.dart`.
  - **Presentación**: `mobile/lib/screens/{settings,first_run,entries_list,dashboard,entry_form}_screen.dart`, `widgets/error_snackbar.dart`.
  - **Android**: `AndroidManifest.xml`, `build.gradle.kts`, nuevo `res/xml/data_extraction_rules.xml`.
  - **Tooling**: `pubspec.yaml`, `pubspec.lock`, `app_dependencies.dart`, `CLAUDE.md` raíz.
  - **Tests**: `test/data/{database,backup,financial_state}_test.dart`.
  - **Spec/plan/impl**: `engineering/specs/flutter-local-hardening/` (carpeta nueva).
- Áreas: seguridad import, concurrencia/cache, SQL/migración, UX/frontend, tests, build/docs.
- Comandos usados: `git diff --stat`, `git status --short`, `git log`, `grep -rn`, lectura directa de archivos críticos. Validación cruzada manual de hallazgos sospechosos (B2 categoryId del form, B6 watchSingle).

## Hallazgos bloqueantes

> **Status post-review (2026-06-19, versión `0.3.0+31`)**: los 3 bloqueantes (B1, B2, B3) + cinco no-bloqueantes (M1, M2, M3, M5, M11) fueron corregidos en la misma sesión. Tests pasaron de 81 → **87 verdes**. Detalle al final de cada hallazgo.

### B1. `_parseDate()` no maneja `FormatException`; un timestamp inválido aborta el import sin error tipado

- Severidad: **Crítica**
- Área: integridad / superficie del import
- Evidencia: `mobile/lib/data/backup.dart` en `_parseDate`:
  ```dart
  DateTime? _parseDate(dynamic raw) {
    if (raw is String) return DateTime.parse(raw);
    return null;
  }
  ```
  Llamado desde los 3 `_*FromJson` para `created_at`, `updated_at` y `occurred_at`. Si el JSON tiene `"occurred_at": "2026-99-99"` o `"foo"`, `DateTime.parse` lanza `FormatException`, que NO se mapea como `BackupError`. Cae en el `Exception()` branch del `showErrorSnackbar` y muestra el `toString()` crudo.
- Riesgo: el sprint declaró que el import endurecido rechaza payloads corruptos con error amigable. Este caso bypasea ese contrato: el usuario ve un mensaje técnico ("FormatException: Trying to read..."). Peor: si la `FormatException` ocurre durante el batch de inserción (no en el parseo previo), la transacción se rollbackea pero el flow de UI termina con error genérico.
- Recomendación: envolver `DateTime.parse` en try/catch y lanzar `BackupError('invalid_date_format', ...)` con el nombre del campo y el valor recibido. Agregar caso al switch de `backupErrorToMessage` con mensaje amigable. Agregar test en `backup_test.dart`.
- Depende de: nada.
- **Fix aplicado**: `_parseDate` envuelve `DateTime.parse` en try/catch y lanza `BackupError('invalid_date_format', ...)` con preview truncado a 32 chars. Caso nuevo en `backupErrorToMessage`. Test `Import con timestamp inválido rechaza con invalid_date_format` agregado.

### B2. Form de edición pasa `categoryId: _categoryId` siempre → la "limpieza silenciosa" de RN-H03 NO funciona en producción

- Severidad: **Alta**
- Área: integridad de regla de dominio / UX
- Evidencia:
  - `mobile/lib/screens/entry_form_screen.dart:151-152`:
    ```dart
    categoryId: _kind!.acceptsCategory ? _categoryId : null,
    clearCategory: _kind!.acceptsCategory && _categoryId == null,
    ```
    En modo edición `_bootstrap` setea `_categoryId = item.entry.categoryId` (línea 78). Si el usuario NO toca el `CategoryPicker`, `_categoryId` mantiene el valor original. Al guardar, **siempre** pasa `categoryId: _categoryId` (el ID heredado).
  - `mobile/lib/data/daos/entries_dao.dart:311-317`: el DAO interpreta `categoryId != null` como "cambio explícito" y llama `_validateCategoryForKind`, que lanza `invalid_category_applies_to` si la categoría está archivada.
  - El test que cubre RN-H03 en `database_test.dart:562` archiva la categoría DESPUÉS del insert y llama `updateEntry(id: id, amount: 90)` sin pasar `categoryId`. Por eso pasa: el caller NO envía categoryId, entra al branch "heredada" y se limpia. El form de UI NO se comporta así.
- Riesgo: la promesa de RN-H03 (categoría heredada archivada se limpia silenciosamente al editar) NO se cumple cuando el camino real es el form de edición. El usuario verá un snackbar rojo "La categoría no aplica a este tipo de movimiento" al intentar guardar cualquier cambio en un entry con categoría archivada. Es exactamente el escenario que la regla intentaba evitar.
- Recomendación: dos opciones, elegir una:
  1. En el form, al cargar el entry en `_bootstrap`, validar la categoría con `categoriesDao.findActiveById(id)`. Si retorna null, resetear `_categoryId = null` desde el cargado y mostrar nota visual breve ("La categoría original fue archivada").
  2. Agregar un flag `_categoryIdChanged: bool` que arranca en false. El picker `onChanged` lo pone en true. Al guardar, pasar `categoryId: _categoryIdChanged ? _categoryId : null` y `clearCategory: _categoryIdChanged && _categoryId == null`. Así el DAO recibe `null` cuando el usuario no tocó y aplica el branch heredado correctamente.
  La opción 1 es más UX, la opción 2 es menos invasiva. Recomiendo (1) porque informa al usuario.
- Depende de: nada (decisión de diseño UX).
- **Fix aplicado**: opción 1 elegida. En `entry_form_screen._bootstrap`, si el entry tiene `categoryId != null`, se valida con `categoriesDao.findActiveById(...)`. Si retorna null (categoría archivada), `_categoryId` queda en null para que el subsiguiente write entre al branch heredado del DAO y limpie silenciosamente. Test M5 confirma que el path explícito sigue rechazando para defenderse de futuras regresiones.

### B3. Validación faltante de campos numéricos de credit en `_accountFromJson`

- Severidad: **Alta**
- Área: integridad de datos / superficie del import
- Evidencia: `mobile/lib/data/backup.dart` en `_accountFromJson`:
  ```dart
  closingDay: Value(json['closing_day'] as int?),
  paymentDay: Value(json['payment_day'] as int?),
  creditLimit: Value((json['credit_limit'] as num?)?.toDouble()),
  interestRate: Value((json['interest_rate'] as num?)?.toDouble()),
  minimumPaymentPct: Value((json['minimum_payment_pct'] as num?)?.toDouble()),
  ```
  Ningún check de rango. El DAO en runtime valida (`AccountsDao.create` rechaza `closingDay < 1 || > 31`, `creditLimit <= 0`, `closingDay == paymentDay`), pero ese código solo corre en alta desde la UI, no en import batch.
- Riesgo: un JSON con `closing_day: 99` o `credit_limit: -500` se inserta. La cuenta queda corrupta. La UI puede o no romperse según el campo (un `closing_day = 99` se renderiza pero confunde al usuario; un `credit_limit < 0` puede romper cálculos de CR en `financial_state.dart`).
- Recomendación: agregar validaciones en `_accountFromJson` antes del Companion, con códigos tipados existentes del DAO (`invalid_credit_metadata`, `invalid_credit_limit`):
  ```dart
  if (type == 'credit') {
    if (closingDay == null || closingDay < 1 || closingDay > 31) throw BackupError('invalid_credit_metadata', '...');
    if (paymentDay == null || paymentDay < 1 || paymentDay > 31) throw BackupError('invalid_credit_metadata', '...');
    if (closingDay == paymentDay) throw BackupError('invalid_credit_metadata', '...');
    if (creditLimit == null || creditLimit <= 0) throw BackupError('invalid_credit_limit', '...');
  }
  if (interestRate != null && (interestRate < 0 || interestRate > 1)) throw BackupError('invalid_credit_metadata', '...');
  if (minimumPaymentPct != null && (minimumPaymentPct < 0 || minimumPaymentPct > 1)) throw BackupError('invalid_credit_metadata', '...');
  ```
  Mapear los nuevos códigos en `backupErrorToMessage` (los del DAO ya están en `domainErrorToMessage`, pero el branch ahora rutea `BackupError` por su propia función).
- Depende de: nada.
- **Fix aplicado**: `_accountFromJson` ahora valida (cuando `type == 'credit'`): `credit_limit > 0`, `closing_day ∈ [1,31]`, `payment_day ∈ [1,31]`, `closing_day != payment_day`. Además valida `interest_rate ∈ [0,1]` y `minimum_payment_pct ∈ [0,1]` cuando están presentes. Reutiliza códigos `invalid_credit_limit` e `invalid_credit_metadata`. Tests para credit_limit ≤ 0 y closing_day fuera de rango agregados a `backup_test.dart`.

## Hallazgos no bloqueantes

### M1. `is_protected` no valida invariante de Bolsa singleton

- Severidad: Media
- Área: integridad de invariante
- Evidencia: `_accountFromJson` acepta `is_protected` tal cual del JSON. Un payload con dos cuentas `type=cash` ambas con `is_protected=true`, o una `type=debit` con `is_protected=true`, se importa sin error. La pantalla `AccountsListScreen` espera una única Bolsa singleton.
- Impacto: comportamiento indefinido en el UI; el `seedDefaults` posterior puede crear otra Bolsa o saltarse el chequeo según el código.
- Recomendación: tras parsear `accountsParsed`, validar antes de la transacción:
  ```dart
  final protected = accountsParsed.where((a) => a.isProtected.value).toList();
  if (protected.length > 1) throw BackupError('missing_bolsa', 'El respaldo tiene más de una Bolsa.');
  if (protected.any((a) => a.type.value != 'cash')) throw BackupError('protected_account', '...');
  ```
- Depende de: B3 (mismo módulo).

### M2. `color_slug` e `icon_slug` no validados contra catálogo

- Severidad: Media
- Área: integridad de catálogo
- Evidencia: `_categoryFromJson` acepta los slugs tal cual. El DAO los valida en runtime pero el import los bypasea.
- Impacto: el `CategoryBadge` cae en fallback gris/icon genérico sin alertar al usuario. Datos válidos persisten "ocultos".
- Recomendación: importar las constantes `kCategoryColorSlugs` y `kCategoryIconSlugs` (o equivalentes en `lib/constants/category_catalog.dart`) y validar en `_categoryFromJson`. Los códigos `invalid_color_slug` y `invalid_icon_slug` ya existen en el catálogo de errores.
- Depende de: B3 (mismo módulo).

### M3. Falta feedback al cancelar el segundo confirmDialog del flujo "Exportar y luego reiniciar"

- Severidad: Media
- Área: UX
- Evidencia: `mobile/lib/screens/settings_screen.dart` en `_exportThenReset`. Si el usuario completa el share OK y después cancela el segundo `showConfirmDialog`, la función simplemente retorna sin snackbar. El usuario queda en Settings sin contexto de qué pasó (¿se reinició? ¿se exportó? ¿qué hago ahora?).
- Impacto: confusión menor pero recurrente.
- Recomendación: agregar antes del `return` cuando `!confirmed`:
  ```dart
  showSuccessSnackbar(context, 'Respaldo exportado. Reseteo cancelado.');
  ```
- Depende de: nada.

### M4. `mobile/README.md` no documenta los límites del import

- Severidad: Media
- Área: docs
- Evidencia: el plan T007 instruyó actualizar `mobile/README.md` con los límites del import (200 chars en name, 1000 en description, UUID v4/v7, amount > 0). Buscando en el archivo no aparece esa sección. `progreso.md` lo declaró cumplido pero no se reflejó en el README.
- Impacto: si alguien quiere generar un JSON manualmente (testing, scripts), no tiene la referencia de los límites.
- Recomendación: agregar sección "Importar respaldos: límites y validaciones" al README mencionando los 6 códigos de error y sus condiciones.
- Depende de: nada.

### M5. Falta test `updateEntry con categoryId explícito archivado lanza error`

- Severidad: Media
- Área: cobertura tests
- Evidencia: el grupo `EntriesDao.updateEntry transiciones` cubre 6 escenarios pero no incluye el caso "caller pasa explícitamente una categoryId que está archivada". Ese caso es exactamente el bug B2: el form siempre lo pasa así. Sin test, futuras regresiones (incluida la corrección de B2) son frágiles.
- Recomendación: agregar a `database_test.dart`:
  ```dart
  test('updateEntry con categoryId explícito archivado rechaza con invalid_category_applies_to', () async {
    final id = await entriesDao.registerIncome(
      accountDestinationId: bolsaId, amount: 100, occurredAt: DateTime.now(),
    );
    await categoriesDao.archive(catSueldo);
    expect(
      () => entriesDao.updateEntry(id: id, categoryId: catSueldo),
      throwsA(isA<EntriesDaoError>().having((e) => e.code, 'code', 'invalid_category_applies_to')),
    );
  });
  ```
- Depende de: B2 (mismo comportamiento).

### M6. `watchSingle()` cacheado podría romper si dos suscriptores leen la misma key

- Severidad: Media (latente, no se manifiesta hoy)
- Área: concurrencia / arquitectura del cache
- Evidencia: `mobile/lib/data/financial_state.dart:47` retorna `customSelect(...).watchSingle()` y lo guarda en el cache. En drift 2.20, `.watchSingle()` retorna típicamente un Stream single-listener (verificación documental pendiente; los tests del sprint pasan porque cada key se consume por exactamente 1 listener en la UI actual).
- Impacto hoy: ninguno. Cada cuenta tiene UN `_BalanceLabel` en el Dashboard y UN `AccountBalanceHint` en el form de movimiento; nunca coinciden simultáneamente sobre el mismo `(accountId, accountType)` con el mismo Stream. **Esto puede cambiar** si se agrega UI nueva que muestre el saldo en más de un widget vivo a la vez (ej. panel "Mi resumen" + lista de movimientos en una sola pantalla compuesta).
- Riesgo futuro: `StateError: Stream has already been listened to` al segundo `StreamBuilder`.
- Recomendación: cambiar la implementación del cache para retornar un broadcast stream:
  ```dart
  final stream = _db.customSelect(...).watchSingle().asBroadcastStream();
  ```
  Y agregar test que se suscriba dos veces al stream cacheado y confirme que ambos listeners reciben events. Si el broadcast cambia el comportamiento de cierre del listener (los listeners deben cancelarse explícitamente para liberar la query), documentar en CLAUDE.md.
- Depende de: nada (defensivo).

### M7. Falta test del límite 200 chars EXACTO (inclusivo)

- Severidad: Baja
- Área: cobertura tests
- Evidencia: hay test para 201 chars (rechaza) y "" (pasa), pero no para 200 exactos (pasa). El código usa `value.length > max` (estricto), así que 200 chars debería pasar. Sin test explícito, una regresión a `>=` no se detectaría.
- Recomendación: agregar test:
  ```dart
  test('Import con name = 200 chars pasa validación', () async {
    final boundary = 'A' * 200;
    try { await backup.importFromJson(buildPayload(categoryName: boundary)); }
    catch (e) { expect(e, isA<BackupError>().having((e) => (e as BackupError).code, 'code', isNot('string_too_long'))); }
  });
  ```
- Depende de: nada.

### M8. Falta test de `wipeAll` invalidando el cache

- Severidad: Baja
- Área: cobertura tests
- Evidencia: el cache se invalida desde `BackupService.wipeAll()` (línea verificada). Hay test que valida que las 3 tablas quedan vacías post-`wipeAll`, pero ningún test confirma que el `_balanceCache` también queda vacío (a través de `identical()` antes/después).
- Recomendación: en `financial_state_test.dart` agregar:
  ```dart
  test('wipeAll invalida cache de balances', () async {
    final s1 = state.watchAccountBalance(bolsa, 'cash');
    await deps.backupService.wipeAll();  // necesita BackupService inyectado
    final s2 = state.watchAccountBalance(bolsa, 'cash');
    expect(identical(s1, s2), isFalse);
  });
  ```
  Alternativa: agregar el assert al test ya existente `wipeAll vacía las 3 tablas` en `backup_test.dart`.
- Depende de: nada.

### M9. Comparación de color por igualdad de instancia en snackbar

- Severidad: Baja
- Área: robustez UI
- Evidencia: `error_snackbar.dart`:
  ```dart
  final foreground = background == FincoreColors.warning ? FincoreColors.canvas : Colors.white;
  ```
  Funciona porque `FincoreColors.warning` es `const`. Si en el futuro algún caller pasa `FincoreColors.warning.withValues(alpha: 0.8)`, la comparación `==` falla y vuelve a texto blanco, rompiendo el contraste WCAG.
- Impacto hoy: nulo. Defensivo.
- Recomendación: pasar el `foreground` calculado como parámetro desde los helpers `showSuccessSnackbar/showWarningSnackbar/showErrorSnackbar` en lugar de inferirlo en el builder.
- Depende de: nada.

### M10. `Share.shareXFiles` sin timeout

- Severidad: Baja
- Área: robustez UX
- Evidencia: `settings_screen.dart` en `_exportInternal`: `final result = await Share.shareXFiles(...)`. Si el share sheet del sistema queda colgado (bug del plugin, app destino crasheada), el await nunca completa, `_working = true` persiste indefinidamente y todos los botones quedan deshabilitados.
- Impacto: improbable pero recoverable solo con reinicio de app.
- Recomendación: envolver con `.timeout(Duration(minutes: 2), onTimeout: () => const ShareResult(raw: '', status: ShareResultStatus.unavailable))`.
- Depende de: nada.

### M11. `CREATE INDEX` sin `IF NOT EXISTS` en `onUpgrade(1, 2)`

- Severidad: Baja
- Área: robustez de migración
- Evidencia: `database.dart` la rama 1→2 ejecuta `CREATE INDEX idx_entries_occurred_active ...` sin `IF NOT EXISTS`. Drift garantiza por contrato que `onUpgrade` se ejecuta una vez por bump, pero si por algún motivo se reejecuta (crash en medio + reinicio agresivo en algunos OEMs), el segundo CREATE INDEX lanza "index already exists".
- Recomendación: agregar `IF NOT EXISTS` defensivamente. No es un anti-patrón porque drift mantiene el versionado por separado, y el nombre del índice es único.
- Depende de: nada.

### M12. Duplicación de query `findActiveById` entre `CategoriesDao` y `EntriesDao` inline

- Severidad: Baja
- Área: mantenibilidad
- Evidencia: `categories_dao.dart` expone `findActiveById(id)` para uso externo (RF-015 + documentación en CLAUDE.md). `entries_dao.dart:326` repite la misma query inline en `updateEntry` con un comentario explicando que el accessor no existe. Si la lógica de "activo" cambia (ej. se agrega tombstone), hay que actualizar en dos lugares.
- Recomendación: registrar `daos: [AccountsDao, CategoriesDao, EntriesDao]` en `@DriftDatabase` y regenerar `database.g.dart`. Reemplazar el inline por `attachedDatabase.categoriesDao.findActiveById(...)`. Es un sprint chico futuro, no urgente.
- Depende de: nada.

### M13. Desviaciones menores no documentadas en `desviaciones-plan.md`

- Severidad: Baja
- Área: trazabilidad
- Evidencia: `progreso.md` menciona dos cambios menores que ocurrieron en Fase 5 (`isNull` ambiguo entre drift y matcher → cambiado a `equals(null)`; `_buildPayload` con underscore por lint → renombrado a `buildPayload`). `desviaciones-plan.md` solo documenta 3 desviaciones grandes.
- Recomendación: agregar sección "Fase 5 — Cambios menores de API" en `desviaciones-plan.md` con esos dos ítems.
- Depende de: nada.

### M14. Truncado de UUID inválido por `substring` no respeta multi-byte chars

- Severidad: Baja
- Área: mensajes de error
- Evidencia: `backup.dart` `_validateUuid` hace `value.substring(0, 16)` para el preview en el mensaje de error. Si el caller envía un string con caracteres multi-byte (UTF-16 surrogates, emojis), el corte puede partir un código y dejar un char inválido en el mensaje.
- Impacto: cosmético; afecta solo el mensaje de error visible al usuario.
- Recomendación: usar `value.characters.take(16).string` del paquete `characters` (incluido en Flutter por default).
- Depende de: nada.

## Hallazgos descartados (falsos positivos)

Validados manualmente durante la revisión:

- **"AccountsDao.archive no llama invalidateAccount"** (reportado por el subagente de dominio): falso. El código en `accounts_dao.dart` invoca `stateService?.invalidateAccount(id)` después de la transacción. El subagente leyó una versión sin el cambio.
- **"Guardrail `UnimplementedError` causa crash en producción"** (reportado por SQL): es comportamiento intencional documentado en RN-H02. El crash es la salvaguarda; cualquier bump accidental de `schemaVersion` debe fallar fuerte en QA antes de llegar a usuarios.
- **"`fullBackupContent="false"` sintaxis inválida en Android 12+"** (reportado por seguridad): el atributo es válido como booleano literal en todas las versiones de Android. En 12+ tiene precedencia menor que `dataExtractionRules`, pero no es inválido. Mantener.
- **"Comentario de UUID regex confuso"** (reportado por seguridad): el comentario dice "octava nibble es 4 o 7" cuando debería decir "13ava posición". Es trivial pero el regex en sí es correcto. No vale como hallazgo accionable.
- **"Skeleton width 60 vs string final muy distinto"** (reportado por UX): el string final es `'0.3.0+30'` = 8 chars en monospace fontSize 13 ≈ 56 dp. El skeleton de 60 dp es razonable. No es hallazgo.

## Plan de corrección ordenado

1. **B1 — `_parseDate` con try/catch** y nuevo código `invalid_date_format`. Agregar al switch de `backupErrorToMessage` y test en `backup_test.dart`. 10 líneas.
2. **B3 — Validaciones de credit metadata** en `_accountFromJson` (closing/payment day rango, credit_limit > 0, closing != payment, rates en [0, 1]). Reutilizar códigos `invalid_credit_metadata` e `invalid_credit_limit`. Tests en `backup_test.dart`. ~30 líneas.
3. **B2 — Form de edición**: implementar opción 1 (validar categoría heredada en `_bootstrap` y resetear `_categoryId = null` con nota visual si está archivada). Test en `database_test.dart` para confirmar el path desde el form a través del DAO.
4. **M5** — Test `updateEntry con categoryId explícito archivado rechaza` (validación post-fix de B2).
5. **M1 + M2** — Validaciones de Bolsa singleton + slugs de catálogo en import.
6. **M3** — Snackbar de feedback cuando segundo confirmDialog se cancela.
7. **M4** — Documentar límites del import en `mobile/README.md`.
8. **M7 + M8** — Tests boundary 200 chars + wipeAll invalidando cache.
9. **M6** — Aplicar `.asBroadcastStream()` al cache + test de doble suscripción. Hacer aunque no se manifieste hoy.
10. **M9 + M10 + M11 + M12 + M13 + M14** — Cleanup menor, backlog del próximo sprint o batch al final del actual.
11. Rebuildar APK con versionCode `+1` (sería `0.3.0+31`) tras aplicar los fixes; los códigos arm64 actuales (`2030`) deben subir a `2031` para evitar `INSTALL_FAILED_VERSION_DOWNGRADE`.
12. Re-ejecutar `flutter test` (espera 81+ verdes con los tests nuevos) y `flutter analyze` (espera 4 hints info).
13. **T023 smoke manual de Diego** post-fixes.

## Validaciones recomendadas

Antes de cerrar el sprint:

- `flutter test` debe quedar en **≥ 85 tests verdes** (81 + 4-5 nuevos por B1/B2/B3/M5/M7/M8).
- `flutter analyze` debe quedar limpio.
- `flutter build apk --release --split-per-abi` exitoso. `aapt dump xmltree` debe confirmar nuevamente `allowBackup=0x0`.
- Smoke manual de Diego sobre el Redmi con el APK final post-fixes:
  1. Editar un entry cuya categoría está archivada → el form debe cargar con la categoría "limpiada" desde el bootstrap (B2 fix).
  2. Importar un JSON con `"occurred_at": "invalid"` → snackbar rojo amigable (B1 fix).
  3. Importar un JSON con `"closing_day": 99` en una cuenta credit → snackbar rojo amigable (B3 fix).
  4. Tocar "Exportar respaldo y luego reiniciar" + cancelar el segundo dialog → snackbar verde "Respaldo exportado. Reseteo cancelado." (M3 fix).
- Documentar en `progreso.md` y `desviaciones-plan.md` los fixes aplicados con referencia a los B1/B2/B3/M*.

## Limitaciones

- **No se ejecutó el APK del review**: la revisión es estática. Los hallazgos UX (B2, M3) se inferieron del código + lectura del form.
- **`watchSingle()` broadcast vs single-listener (M6)**: no se ejecutó un test empírico de doble suscripción. La hipótesis del subagente es razonable (drift retorna single-listener por default) pero merece confirmación empírica antes de declarar bug. Por eso queda como "latente" no como bloqueante.
- **Validación manual de B2** se hizo leyendo `entry_form_screen.dart` y `entries_dao.dart` línea por línea. El bug es claro en código pero no se reprodujo en runtime; el smoke manual de Diego lo confirma o lo descarta.
- **Tests de migración** se omiten por simulación frágil. La migración real se valida en el smoke manual (Diego instala APK nuevo sobre `0.2.0+29`).
- **Backend Laravel, frontend Vue**: fuera de alcance del sprint y del review.
- **Compatibilidad con respaldos JSON v1 reales del backend legacy**: no se probó con un JSON real de Diego. Si Diego algún día decide importar el respaldo del backend Laravel productivo, los nuevos checks pueden rechazar campos que el backend legítimo enviaba. Conviene un round-trip end-to-end con datos reales antes de declarar "compatibilidad total con v1".

# Plan de pruebas — flutter-local-hardening-v2

## Casos borde detectados

Más allá de los listados en la spec, casos borde que aparecen al pensar en huecos del código real:

### Broadcast stream (T003 + T007)

- **2 suscriptores simultáneos**: ambos deben recibir el evento tras un insert. Sin broadcast, el segundo lanza `StateError`.
- **Cancelar último listener y resuscribir**: si drift cierra el stream subyacente, el nuevo listener no recibe nada. Si no cierra, queda OK. Esta es la decisión que distingue si T003 necesita `onCancel`.
- **Múltiples eventos rápidos**: el broadcast no debe dropear eventos para ningún suscriptor. drift `customSelect` con `readsFrom` no garantiza orden estricto, pero sí completitud.
- **Suscriptor que llega después del primer evento**: por contrato del broadcast no recibe el evento histórico. El primer listener recibe el evento inicial al suscribirse (drift así lo hace). Si la UI dependía implícitamente del primer evento inmediato, los `Skeleton` se mantienen un instante más.
- **`watchAccountBalance` con accountId UUID válido pero cuenta inexistente en BD**: la query SQL devuelve `balance = 0`. Sin colisión de cache porque el accountId es único.
- **Cache con 30+ entradas**: caso single-user no realista; mencionado como contexto del sprint.

### Tests defensivos (T004-T007)

- **Test 200 chars exacto** (T004): el límite es `<= 200` en código. `name = 'A' * 200` debe pasar la validación de longitud. Si lanza otro `BackupError` (improbable con el payload completo del helper), verificar que NO es `string_too_long`.
- **Test wipeAll invalida cache** (T005): si el setUp no inyecta `state` al `BackupService`, la invalidación no se dispara y el test falla. Asegurar setUp correcto antes del test.
- **Test watchPage filtra archivadas** (T006): el join debe filtrar `deletedAt.isNull()`. Si el fix del sprint anterior se revierte por error, este test falla. Es la defensa principal contra la regresión post-smoke.
- **Test broadcast doble suscriptor** (T007): timing async puede requerir `Future.delayed(Duration(milliseconds: 100))` para que drift complete la emisión tras un insert. Si los 100 ms son insuficientes, ajustar a 300 ms.

### Refactor codegen (T001 + T002)

- **`build_runner` con `--delete-conflicting-outputs`**: borra archivos generados existentes. Si el dev modificó `database.g.dart` a mano, esos cambios se pierden (no debería ser el caso).
- **`@DriftDatabase` con `daos: [...]` y getters generados**: el nombre del getter es lowerCamelCase del nombre de la clase. `AccountsDao` → `accountsDao`. drift no permite colisión con tablas (`accounts` vs `accountsDao`); deben ser distintos.
- **`attachedDatabase.categoriesDao` retorna instancia singleton**: drift crea una sola instancia por database. Si T002 llama `findActiveById` durante una transacción de `updateEntry`, no se crean nuevas conexiones.

### Refactor snackbar (T008)

- **Caller olvidado de `foreground`**: compila error visible. Bien (no silent).
- **`Colors.white` vs `FincoreColors.canvas`**: la decisión queda en el caller (`showWarningSnackbar` → canvas; `showSuccessSnackbar`/`showErrorSnackbar` → white).
- **Caller futuro con color custom**: si alguien crea `showInfoSnackbar(...)` en el futuro, debe explicitar `foreground`. Documentado por la firma.

### Refactor timeout share (T009)

- **`Share.shareXFiles` retorna en < 2 minutos**: timeout no se dispara. Flow normal.
- **Usuario tarda > 2 min eligiendo destino**: timeout dispara con `ShareResultStatus.unavailable`. Flow trata como cancelado. Caso raro pero documentado.
- **`Share.shareXFiles` lanza excepción**: el `try/catch` envolvente del `_exportThenReset` la captura y muestra snackbar de error. Sin cambio.
- **Caller del `_export` (NO el flujo `_exportThenReset`, sino el botón "Exportar respaldo" de Settings)**: también usa `_exportInternal`. Si el timeout dispara, el `_export` muestra un snackbar warning. Aceptable.

### Refactor characters (T010)

- **String ASCII corto**: `value.characters.length` = `value.length`. Comportamiento idéntico a `substring`.
- **String con UUID válido (36 chars ASCII)**: nunca pasa el `if (length <= 16)` (válido) o devuelve los primeros 16 chars (inválido para preview). Mismo resultado que antes.
- **String con emoji**: `characters.length` cuenta grapheme clusters; `substring` cuenta code units. Para preview de error: `🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉` (16 emojis, cada uno 2 code units = 32 UTF-16) → `substring(0, 16)` corta a 8 emojis con probable surrogate roto en el último → `characters.take(16)` retorna los 16 emojis enteros.
- **String corto con emoji al final**: si el string tiene 15 chars + 1 emoji al final (17 grapheme), `characters.take(16)` retorna 15 chars + emoji entero. `substring` puede romper el surrogate.

### Documentación (T011, T012)

- **Sección de catálogo de errores**: lista debe estar completa (incluir TODOS los códigos, no solo los del sprint anterior). Validar manualmente con `grep -rn "BackupError(" mobile/lib/data/backup.dart`.
- **`mobile/README.md` se renderiza en GitHub**: si Diego decide publicar el repo, el markdown debe renderizar bien (sin chars exóticos).

## Pruebas unitarias necesarias

### Suite `backup_test.dart`

- T004 (RF-003): `Import con name de 200 chars exactos pasa validación de longitud`. Helper `buildPayload(categoryName: 'A' * 200)`. Verificar que si lanza, el código NO es `string_too_long`.
- Tests existentes (18 verdes): deben seguir pasando tras T010 (characters.take en mensajes).

### Suite `financial_state_test.dart`

- T005 (RF-004): `wipeAll invalida cache de streams`. Requiere `BackupService(database, state)` en setUp. Verificar `identical(s1, s2) == false` después del wipeAll.
- T007 (RF-006): `watchAccountBalance cacheado acepta múltiples suscriptores simultáneos`. Dos `.listen(...)` al mismo stream, ambos reciben evento. Adicional: cancelar todo, resuscribir, evento nuevo llega al nuevo listener (defiende RF-002 condicional).
- Tests existentes (22 verdes): deben seguir verdes tras T003 (broadcast).

### Suite `database_test.dart`

- T006 (RF-005): `watchPage no incluye badge para categorías archivadas`. Setup ya tiene `catSueldo` y `catComida`. Crear income con `catSueldo`, archivar `catSueldo`, leer `watchPage`, verificar `category` null.
- Tests existentes (41 verdes): deben seguir verdes tras T001 (codegen) y T002 (delegación a `findActiveById`).

### Suite `invariants_test.dart`

- Tests existentes (8 verdes): sin cambios esperados.

## Pruebas de integración o API necesarias

No aplica. App local sin red ni API.

## Pruebas de UI o flujo necesarias si aplica

Widget tests siguen aplazados como en sprints anteriores. Validación queda en smoke manual de T015.

## Pruebas de permisos y seguridad si aplica

Heredados sin cambio:
- `adb backup io.github.gregori100.fincore` debe seguir rechazando (validar con `aapt dump xmltree`).
- `dataExtractionRules.xml` sin cambios.

## Pruebas de datos, migración o compatibilidad si aplica

- **Migración 0.3.0+32 → 0.3.1+33**: NO hay cambio de `schemaVersion` (sigue en 2). drift no ejecuta `onUpgrade`. Datos del usuario preservados sin esfuerzo. Validable en smoke T015 punto 1.
- **Reinstalación con datos**: `adb install -r` preserva datos. Smoke T015 punto 1.
- **Codegen reproducible**: `dart run build_runner build --delete-conflicting-outputs` regenera `database.g.dart` con `daos: [...]`. Si Diego clona el repo desde cero, esto debe ejecutarse antes de `flutter test`. Documentado en `mobile/README.md` ya.

## Pruebas de regresión sobre flujos existentes

Suite existente (87 tests) debe seguir verde tras cada T:

- Schema/CRUD básico (database_test).
- BO/DE/CR + balance por cuenta + stream reactivo + cache (financial_state_test).
- Round-trip backup + validaciones import + wipeAll + cache (backup_test).
- Libreta libre + RN-011 + OverpayDebt + archive cascade + RN-H03 (invariants_test, database_test).

Particular atención a:

- Test `watchAccountBalance cacheado retorna mismo Stream` (sprint anterior): debe seguir verde tras T003. El identidad sigue funcionando porque el cache guarda la misma referencia.
- Tests de transiciones de `updateEntry` (sprint anterior, 7 tests): el refactor T002 a `attachedDatabase.categoriesDao.findActiveById` no cambia el comportamiento. Deben seguir verdes.
- Tests del snackbar (no hay tests unitarios del widget; solo smoke). T008 no debería romper nada.

## Pruebas manuales o smoke tests necesarios

Listados en T015. Resumen:

1. Migración silenciosa: `0.3.0+32` → `0.3.1+33` preserva datos.
2. Bump visible: Settings → "Acerca de" muestra `0.3.1+33`.
3. Regresión join archive: entry con categoría archivada NO muestra badge en listados.
4. Fallback de timeout: cancelar share rápido → snackbar warning. (No es testable el caso de share colgado real.)

## Datos de prueba recomendados

Tests usan in-memory SQLite con setUps existentes. No se necesita JSON externo para los 4 tests nuevos.

Para smoke T015:
- BD del Redmi con datos reales de Diego (ya está, post `0.3.0+32`).
- Mínimo 1 entry con categoría activa que se archivará durante el smoke (punto 3).

## Comandos o validaciones locales sugeridas

```bash
cd mobile
export PATH="$HOME/development/flutter/bin:$PATH"

# Después de T001 (codegen)
dart run build_runner build --delete-conflicting-outputs
flutter analyze     # 0 errores
flutter test        # 87 verdes (no agregamos tests todavía)

# Por cada tarea T002..T012
flutter analyze     # 0 errores
flutter test        # incrementa: 87 → 88 (T004) → 89 (T005) → 90 (T006) → 91 (T007)

# Cierre
flutter build apk --release --split-per-abi
~/Android/Sdk/build-tools/35.0.1/aapt dump badging build/app/outputs/flutter-apk/app-arm64-v8a-release.apk | grep -E "(versionCode|versionName|package)"
~/Android/Sdk/build-tools/35.0.1/aapt dump xmltree build/app/outputs/flutter-apk/app-arm64-v8a-release.apk AndroidManifest.xml | grep -E "(allowBackup|dataExtractionRules)"
~/Android/Sdk/platform-tools/adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

## Criterios mínimos para aprobar la implementación

- `flutter test`: **≥ 91 verdes** (87 + 4 mínimos: T004, T005, T006, T007).
- `flutter analyze`: 0 errores, 0 warnings (4 hints info cosméticos preexistentes aceptables).
- `flutter build apk --release --split-per-abi`: 3 APKs sin errores; arm64 ≤ 20 MB.
- `aapt dump badging` muestra `versionCode='2033'` y `versionName='0.3.1'`.
- `aapt dump xmltree AndroidManifest.xml` confirma `allowBackup=0x0` y `dataExtractionRules` siguen aplicados.
- Smoke manual T015 OK por Diego en los 4 puntos.
- Documentación: `mobile/README.md` con sección de límites del import; `desviaciones-plan.md` del sprint anterior con 3 desviaciones menores agregadas.
- `database.g.dart` regenerado y commiteado.

## Validación final recomendada

Al cerrar el sprint, invocar el skill `branch-quality-review` con slug `flutter-local-hardening-v2`. Esa skill genera su propio reporte en `engineering/quality-review/flutter-local-hardening-v2/`. No duplicar contenido en `implementation/`; desde `implementation-review.md` referenciar la ruta del reporte y resumir solo bloqueantes, riesgos y acciones.

El sprint queda apto para commit cuando:

- el reporte del quality review está generado, y
- los bloqueantes (si hay) están resueltos o aceptados explícitamente como deuda con justificación documentada en `pendientes.md`.

Si el quality review no está disponible, hacer revisión equivalente manual con esta checklist:

- ¿Codegen ejecutado y `database.g.dart` commiteado?
- ¿`EntriesDao.updateEntry` delega a `attachedDatabase.categoriesDao.findActiveById` sin query inline?
- ¿`watchAccountBalance` retorna stream broadcast confirmado por test de doble suscriptor?
- ¿`watchPage` filtra categorías archivadas confirmado por test específico?
- ¿`_buildFincoreSnackBar` recibe `foreground` como parámetro y los 3 helpers lo pasan?
- ¿`Share.shareXFiles` con timeout 2 min y fallback `unavailable`?
- ¿`backup.dart` usa `characters.take()` en lugar de `substring()` en `_validateUuid` y `_parseDate`?
- ¿`mobile/README.md` con sección "Importar respaldos"?
- ¿`desviaciones-plan.md` del sprint anterior con 3 desviaciones menores agregadas?
- ¿APK `0.3.1+33` instala sobre `0.3.0+32` sin pérdida de datos?

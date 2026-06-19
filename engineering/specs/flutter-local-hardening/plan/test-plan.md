# Plan de pruebas — flutter-local-hardening

## Casos borde detectados

Algunos ya están en la spec; este test-plan agrega los que aparecen al pensar en huecos del código real.

### Validaciones del import (RF-001 a RF-006)

- `kind` con valor exactamente `"income"`, `"expense"`, `"credit_expense"`, `"debt_payment"`, `"transfer"` (los 5 válidos).
- `kind = 'INCOME'` (mayúsculas) — debería rechazar por `invalid_kind` (las constantes son lowercase).
- `kind` con string vacío `""` — rechaza por `invalid_kind`.
- `type` con valor `"savings"` o `"loan"` — rechaza por `invalid_account_type`.
- `applies_to = "any"` — rechaza por `invalid_applies_to`.
- `amount = 0.0` exacto — rechaza por `invalid_amount`.
- `amount = 0.000001` (positivo mínimo) — pasa.
- `amount = -100.5` — rechaza.
- `amount` como string `"100"` en el JSON — el cast `(json['amount'] as num)` falla con `TypeError`; el wrapper general lo captura como `invalid_json`. Documentar como caso esperado.
- `name = ""` (vacío) — no es null, pero la longitud 0 cumple `<= 200`. ¿Debería rechazar? Hoy los DAOs sí rechazan name vacío. **Decisión del plan**: dejar al DAO la validación de "vacío" durante el insert; el import solo valida longitud máxima. Si SQLite con el insert no rechaza vacío, queda como dato curioso del usuario.
- `name` con exactamente 200 caracteres — pasa.
- `name` con 201 caracteres — rechaza por `string_too_long`.
- `description = null` — pasa (no valida null).
- `description` con 1001 caracteres — rechaza.
- `id` con UUID v4 — pasa.
- `id` con UUID v7 — pasa.
- `id` con UUID v3 (`...-3xxx-...`) — rechaza por `invalid_uuid_format`.
- `id = '1'` — rechaza.
- `id` con UUID en mayúsculas (`A1B2C3D4-...`) — pasa (regex `[a-fA-F]`).
- `category_id = null` en un entry — pasa (es opcional).
- `category_id` con UUID inválido — rechaza por `invalid_uuid_format`.

### Migración 1 → 2 (RF-011)

- BD limpia, primera apertura con código `schemaVersion = 2`: `onCreate` ejecuta los 7 CREATE INDEX. El índice parcial nuevo está presente.
- BD con `schemaVersion = 1` en disco abre con código `schemaVersion = 2`: `onUpgrade(1, 2)` ejecuta el CREATE INDEX. Datos del usuario intactos. Segunda apertura no re-ejecuta `onUpgrade`.
- BD con `schemaVersion = 2` que abre con código `schemaVersion = 3` (hipotético bump accidental): `onUpgrade(2, 3)` lanza `UnimplementedError` con mensaje claro.
- BD con índice ya creado por algún motivo (improbable, pero defensivo): `CREATE INDEX IF NOT EXISTS` no aplica aquí porque el nombre es único; si llegara a colisionar, el `CREATE INDEX` falla con `SQLITE_ERROR`. **Decisión del plan**: NO usar `IF NOT EXISTS` porque queremos detectar el problema; la migración es idempotente por contrato de drift (se ejecuta una sola vez).

### Cache de streams (RF-012)

- Primera llamada a `watchAccountBalance(id, type)`: crea el Stream, lo guarda en el Map.
- Segunda llamada a `watchAccountBalance(id, type)` con la misma key: retorna el mismo Stream.
- Llamada a `watchAccountBalance(id, 'cash')` y `watchAccountBalance(id, 'debit')`: dos keys distintas en el Map (`'$id:cash'` y `'$id:debit'`). Caso teórico raro porque un account tiene un solo type, pero el contrato de la key debe ser estricto.
- `archive(id)` cuando hay key `'$id:cash'` en el Map: invalidación borra esa key. Otros entries del Map intactos.
- `wipeAll()`: invalidación borra TODAS las keys.
- StreamBuilder en Dashboard con stream cacheado: cuando el padre se desmonta, el StreamBuilder cierra su listener. Si era el único listener del stream cacheado, drift cierra la subscription subyacente.
- Race: thread A llama `watchAccountBalance(X, 'cash')` mientras thread B llama `invalidateAccount(X)`. En Dart single-isolate no hay race real, pero el plan asume orden determinístico.

### `updateEntry` con categoría archivada (RF-014)

- Entry creado con `categoryId = X` (activa). Después, `X` se archiva. Usuario abre el entry, toca Guardar sin tocar `categoryId`. Resultado: `effectiveCategoryId = X`; el helper `findActiveById(X)` retorna null; el write incluye `categoryId = const Value(null)`. Sin error, sin snackbar.
- Entry con `categoryId = null`. Usuario edita y deja `null`. Sin cambio.
- Entry con `categoryId = X` activa. Usuario cambia a `categoryId = Y` también activa y compatible. `_validateCategoryForKind(Y)` pasa; write con `categoryId = Y`.
- Entry con `categoryId = X` activa. Usuario cambia a `categoryId = Z` activa pero incompatible con kind. Lanza `invalid_category_applies_to`.
- Entry con `categoryId = X` archivada. Usuario cambia a `categoryId = Y` también archivada. `findActiveById(Y)` retorna null; forza `categoryId = null` sin error. (Comportamiento intencional: la regla H03 no distingue entre "heredada" y "nueva" si ambas están archivadas.)
- Entry con `clearCategory = true` y `categoryId = X` activa. Prioridad del flag `clearCategory`: el write usa null sin pasar por la validación nueva.

### Reset destructivo con dos botones (RF-013)

- Tap "Exportar respaldo y luego reiniciar" → share sheet → user toca "Cancelar" → snackbar warning "Exportación cancelada. No se reinició la BD." Estado: Settings sin spinner, BD intacta.
- Tap "Exportar respaldo y luego reiniciar" → share sheet exitoso → segundo `confirmDialog` → user cancela → BD intacta, vuelve a Settings.
- Tap "Exportar respaldo y luego reiniciar" → share sheet exitoso → segundo `confirmDialog` → user confirma → `wipeAll()` → redirect a `/first-run`.
- Tap "Reiniciar sin exportar" → `confirmDialog` → user cancela → BD intacta.
- Tap "Reiniciar sin exportar" → `confirmDialog` → user confirma → `wipeAll()` → redirect.
- Sin app de destino para share (cel sin Drive ni mail): el share retorna `unavailable`; mismo manejo que cancelado.

### Snackbar warning con texto canvas (RF-019)

- En modo oscuro de la app (único modo soportado hoy): fondo amarillo `#EBBD52` + texto negro `#1F242B` da contraste ~10:1.
- Snackbar success (verde) sigue con texto blanco.
- Snackbar error (rojo) sigue con texto blanco.

### Accesibilidad TalkBack (RF-020)

- TalkBack ON: FAB extended del Dashboard se narra como "Movimiento, botón. Nuevo movimiento" (label visible + tooltip).
- TalkBack ON: filter icon de Entries list se narra como "Filtros, botón".
- TalkBack ON: chevrons decorativos no se narran (Semantics.excludeSemantics).
- TalkBack ON: cards de first_run "Importar respaldo" y "Arrancar limpio" se narran con su título y descripción.

### kAppVersion con package_info_plus (RF-016)

- App ejecutándose en cel: muestra `0.3.0+30` real.
- En tests con `flutter test`: `PackageInfo.fromPlatform()` puede lanzar `MissingPluginException` porque no hay platform channel. El `FutureBuilder` recibe error; el `builder` muestra `'dev'`. No revienta la pantalla.

### Bumps de schemaVersion sin migración (RF-009)

- Cambiar `schemaVersion = 1` a `schemaVersion = 2` en código + olvidar agregar la rama `if (from == 1 && to == 2)` en `onUpgrade`: al abrir la app sobre BD vieja, el guardrail lanza `UnimplementedError`. La app crashea visiblemente; no corrompe datos.

### AndroidManifest sin allowBackup (RF-008)

- `adb backup io.github.gregori100.fincore` retorna "Backup not allowed" sin generar archivo `.ab`.
- `adb shell pm dump io.github.gregori100.fincore | grep allowBackup`: retorna `allowBackup=false`.
- `dataExtractionRules` se respeta en Android 12+; en versiones previas el `allowBackup="false"` solo aplica.

## Pruebas unitarias necesarias

Listadas por tarea (T-NN) y suite donde van.

### `backup_test.dart` (Familia 1 — validaciones import)

- `Import con kind inválido rechaza con invalid_kind` (T020 → RF-001).
- `Import con kind en mayúsculas rechaza con invalid_kind` (T020 → RF-001 borde).
- `Import con type inválido rechaza con invalid_account_type` (T020 → RF-002).
- `Import con applies_to inválido rechaza con invalid_applies_to` (T020 → RF-003).
- `Import con amount = 0 rechaza con invalid_amount` (T020 → RF-004).
- `Import con amount = -100 rechaza con invalid_amount` (T020 → RF-004).
- `Import con name de 201 chars rechaza con string_too_long` (T020 → RF-005, mensaje incluye campo).
- `Import con description de 1001 chars rechaza con string_too_long` (T020 → RF-005).
- `Import con name vacío string pasa la validación de longitud` (T020 → caso borde).
- `Import con id no UUID rechaza con invalid_uuid_format` (T020 → RF-006, mensaje incluye campo).
- `Import con UUID v4 pasa` (T020 → RF-006 borde).
- `Import con UUID v7 pasa` (T020 → RF-006 borde).
- `Import con UUID v3 rechaza con invalid_uuid_format` (T020 → RF-006 borde).
- `Import con category_id no UUID en un entry rechaza con invalid_uuid_format` (T020 → RF-006).
- `BD existente intacta tras rechazo por invalid_kind` (T020 → cobertura de rollback consistente con el patrón ya existente para invalid_json).

### `database_test.dart` (Familia 3, 4, 5)

- `cancel idempotente preserva balance` (T018 → RF-021).
- `updateEntry transiciones: amount + description + occurredAt simultáneo` (T019 → RF-022).
- `updateEntry transiciones: cambia categoryId a una compatible` (T019 → RF-022).
- `updateEntry transiciones: rechaza categoryId con applies_to incompatible` (T019 → RF-022).
- `updateEntry transiciones: cambia accountOriginId a otra cuenta activa` (T019 → RF-022).
- `updateEntry con categoría archivada heredada limpia categoryId silenciosamente` (T019 → RF-014).
- `updateEntry con clearCategory=true ignora categoría activa` (T019 → caso borde RF-014).
- `Migración 1 → 2 ejecuta el CREATE INDEX y queda en schemaVersion 2` (T020 → RF-011). Si la simulación es muy compleja, complementar con smoke manual.
- `onUpgrade(2, 3) lanza UnimplementedError` (T020 → RF-009).
- `findActiveById retorna null para categoría archivada` (T020 → RF-015).
- `findActiveById retorna la Category para activa` (T020 → RF-015).

### `financial_state_test.dart` (Familia 4)

- `watchAccountBalance retorna el mismo Stream para llamadas con la misma key` (T020 → RF-012).
- `watchAccountBalance retorna Streams distintos para keys distintas` (T020 → RF-012 borde).
- `invalidateAccount borra solo las keys de esa cuenta` (T020 → RF-012).
- `invalidateAll vacía el Map completo` (T020 → RF-012).
- `archive(id) limpia las keys de esa cuenta del cache` (T020 → RF-012 integración con AccountsDao).
- `wipeAll() limpia todo el cache` (T020 → RF-012 integración con BackupService).

## Pruebas de integración o API necesarias

No aplica. La app es local-first sin API ni red.

## Pruebas de UI o flujo necesarias si aplica

Widget tests aplazados como en el sprint anterior (T043-T045 del MVP). Si se decide implementarlos en este sprint como mejora, agregar:

- `settings_screen_test`: tap "Exportar respaldo y luego reiniciar" abre share sheet mock; tras success, muestra el segundo confirmDialog; tras confirmar, redirige.
- `settings_screen_test`: "Acerca de" muestra el string del FutureBuilder (mock de PackageInfo).
- `error_snackbar_test`: snackbar warning renderiza texto con color canvas y contraste verificable.

Si NO se implementan, validación queda en smoke manual de T023.

## Pruebas de permisos y seguridad si aplica

- **`adb backup io.github.gregori100.fincore`**: debe rechazar con "Backup not allowed" (T023 manual).
- **`aapt dump badging app-arm64-v8a-release.apk | grep allowBackup`**: debe mostrar `application:android:allowBackup='false'` (T022 automatizado).
- **`adb shell pm dump io.github.gregori100.fincore | grep allowBackup`**: debe retornar `allowBackup=false` (T023 manual, opcional).
- **Import de respaldo con `kind = 'hacked'`**: snackbar rojo con mensaje amigable (T023 manual).
- **Import de respaldo con `id = '1'`**: snackbar rojo con mensaje amigable indicando UUID inválido (T023 manual).

## Pruebas de datos, migración o compatibilidad si aplica

- **Migración 1 → 2 en BD del usuario real**: simulada en `database_test.dart` (T020) y validada en smoke de T023 sobre el Redmi de Diego con el `0.2.0+29` instalado actualmente.
- **Compatibilidad con respaldos JSON v1 legítimos del backend Laravel legacy** (si Diego decide algún día importarlos): el formato no cambia. Los respaldos legítimos pasan las validaciones nuevas (cumplen reglas de dominio). No se prueba en este sprint a falta de respaldos reales, pero está documentado en `pendientes.md` del MVP como recomendación.
- **Downgrade `0.3.0+30 → 0.2.0+29`**: NO soportado. Documentar en `pendientes.md` del sprint actual.

## Pruebas de regresión sobre flujos existentes

Suite existente (59 tests) debe seguir verde tras cada T:

- Schema/PRAGMA/CRUD básico (database_test).
- BO/DE/CR + balance por cuenta + stream reactivo (financial_state_test).
- Round-trip backup + JSON inválido + version > 1 + missing Bolsa + FK rota + idempotencia + wipeAll (backup_test).
- Libreta libre + RN-011 + OverpayDebt + archive en cascada (invariants_test).

En particular: el archive cascade del sprint anterior NO debe romperse al agregar la invalidación del cache de streams en T011.

## Pruebas manuales o smoke tests necesarios

Listadas en T023 con detalle. Resumen:

1. APK instala sobre 0.2.0+29 sin perder datos.
2. Settings → Acerca de muestra `0.3.0+30`.
3. `adb backup` rechazado.
4. Import malicioso con kind inválido → snackbar rojo amigable.
5. Editar entry con categoría archivada → categoryId queda en null sin error.
6. Reset con flujo "Exportar y luego reiniciar" funciona end-to-end.
7. (Opcional) TalkBack narra iconos críticos.

## Datos de prueba recomendados

- **JSON de respaldo válido** generado por export de la propia app con al menos: 1 Bolsa + 1 debit + 1 credit + 5 categorías activas + 1 categoría archivada + 10 movimientos cubriendo los 5 kinds.
- **JSON malicioso 1**: cambiar `"kind": "income"` a `"kind": "hacked"` en una entry. Esperado: `invalid_kind`.
- **JSON malicioso 2**: cambiar `"amount": 100` a `"amount": -50`. Esperado: `invalid_amount`.
- **JSON malicioso 3**: cambiar `"id": "01abc..."` a `"id": "1"`. Esperado: `invalid_uuid_format`.
- **JSON malicioso 4**: agregar `"name": "<200+ chars>"` a una cuenta. Esperado: `string_too_long`.
- **BD con `schemaVersion = 1`**: el Redmi de Diego con `0.2.0+29` instalado ya tiene esta BD; sirve para validar la migración en T023.

## Comandos o validaciones locales sugeridas

```bash
cd mobile
export PATH="$HOME/development/flutter/bin:$PATH"

# Por tarea
flutter analyze            # 0 errores tras cada T
flutter test               # incrementa: 59 → 60 (T018) → ~65 (T019) → ~70 (T020)

# Cierre
flutter build apk --release --split-per-abi
~/Android/Sdk/build-tools/35.0.1/aapt dump badging build/app/outputs/flutter-apk/app-arm64-v8a-release.apk | grep -E "(versionCode|allowBackup|package)"
~/Android/Sdk/platform-tools/adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk

# Validación adb backup (cel desbloqueado, USB debug ON)
~/Android/Sdk/platform-tools/adb backup io.github.gregori100.fincore
# Esperado: "Backup not allowed" o equivalente. NO debe generar archivo .ab.
```

## Criterios mínimos para aprobar la implementación

- `flutter test` reporta **≥ 67 tests verdes** (59 actuales + 6 mínimos del scope).
- `flutter analyze` reporta **0 errores y 0 warnings**.
- `flutter build apk --release --split-per-abi` produce APK arm64 que instala sobre `0.2.0+29` sin perder datos.
- `aapt dump badging` muestra `versionCode='2030'` y `allowBackup='false'` en el APK arm64.
- Smoke manual de T023 OK por Diego en los 7 puntos.
- Documentación: `CLAUDE.md` con las 4 secciones nuevas; `mobile/README.md` con límites del import; `engineering/specs/flutter-local-hardening/implementation/` con los 6 archivos obligatorios.
- Quality review de T025 ejecutado y bloqueantes (si hay) resueltos o aceptados explícitamente.

## Validación final recomendada

Al cerrar el sprint, ejecutar el skill `branch-quality-review` con slug `flutter-local-hardening`. Esa skill genera su propio reporte en `engineering/quality-review/flutter-local-hardening/`. No duplicar el contenido del reporte dentro de `implementation/`; desde `implementation-review.md` referenciar la ruta del reporte y resumir solo bloqueantes, riesgos y acciones.

El sprint queda apto para commit cuando:

- el reporte del quality review está generado, y
- los bloqueantes (si hay) están resueltos o aceptados explícitamente como deuda con justificación.

Si el quality review no está disponible por la razón que sea, hacer revisión equivalente manual con esta checklist:

- ¿Las 6 validaciones del import (M1-M4) están aplicadas en los tres `_*FromJson` y cada una tiene su test?
- ¿`android:allowBackup="false"` está en el manifest y validado en el APK?
- ¿`schemaVersion = 2` con `onUpgrade(1, 2)` implementado y test que lo cubre?
- ¿Cache de streams en `FinancialStateService` invalidado correctamente en `archive` y `wipeAll`?
- ¿`SettingsScreen` muestra dos botones en "Zona peligrosa" y el flujo de share sheet funciona end-to-end?
- ¿`kAppVersion` ya no está hardcoded y la card "Acerca de" lee de `PackageInfo`?
- ¿Snackbar warning con texto canvas tiene contraste ≥7:1?
- ¿TalkBack narra tooltips en iconos críticos?
- ¿Tests adicionales (`cancel` idempotente preserva balance + transiciones `updateEntry`) en verde?
- ¿APK instala sobre `0.2.0+29` sin perder datos?
- ¿Los 5 ítems fuera de alcance (M6, M11, M17, M19, M24, M25) están explícitamente en `pendientes.md` del sprint?

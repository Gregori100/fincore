# Plan de pruebas — flutter-local-mvp

## Casos borde detectados

Heredados de la spec más casos emergentes al modelar la implementación:

- **JSON real del backend con campos null o extras**: el backend produce JSON con la forma exacta del sprint `respaldos`. Si el JSON real tiene un campo extra (ej. `monthly_limit` que el cliente local soporta en schema pero la UI ignora) el importer debe tolerarlo sin fallar.
- **JSON con `version: 0` o `version: 99`**: la primera implementación rechaza todo lo distinto de 1. Verificable.
- **JSON con `accounts: []` (sin Bolsa)**: rechazo explícito `BackupMissingBolsaError`. Tampoco se crea Bolsa default automáticamente porque enmascararía un export roto.
- **JSON con dos cuentas tipo cash** (improbable pero posible si el export del backend está roto): el importer acepta solo la primera y rechaza la segunda como duplicate (constraint del schema sobre `type = cash` unicidad — implementar con `UNIQUE(type) WHERE type = 'cash' AND deleted_at IS NULL` o validación al insert).
- **JSON con UUID v4 en lugar de v7** (los backups del backend siempre son v7 por contrato, pero si Diego copia datos de otra app que use v4): el importer acepta porque drift no valida el formato del UUID. Aceptable; soft delete y sync futuro funcionan con cualquier UUID.
- **Importar JSON con entries que referencian cuenta o categoría no incluida en `accounts`/`categories`**: FK constraint del schema lo rechaza al insert. Test específico verifica el comportamiento.
- **Crear Bolsa cuando ya existe**: el DAO rechaza con error específico. La UI ni siquiera ofrece la opción.
- **Editar la Bolsa para cambiar `type`**: el DAO ignora cambios de type en cuentas existentes. La UI no expone.
- **Archivar una cuenta con saldo cero pero con entries no cancelados**: aceptado por el DAO; los entries se preservan tal cual. El backend tiene el mismo comportamiento.
- **Cancelar movimiento que tenía categoría archivada**: aceptado. El entry mantiene `category_id` apuntando a la archivada.
- **Importar JSON cuando hay datos previos en BD**: el comportamiento esperado es **reemplazo total** (borra todo + inserta lo importado). La UI muestra confirm dialog destructivo antes.
- **Importar el mismo JSON dos veces consecutivas**: idempotente, mismo resultado.
- **Exportar JSON con BD recién seeded (solo Bolsa + 10 categorías)**: produce JSON válido con `journal_entries: []`. Aceptable.
- **Exportar JSON cuando hay 50,000+ entries**: el método produce un string grande en memoria. Aceptable hasta unos cientos de MB. Si en algún futuro hay 100,000+, sprint específico introducirá streaming.
- **Crear gasto con monto = 0**: rechazado por validación del DAO (check constraint `amount > 0`). Verificable.
- **Crear gasto con monto negativo**: idem.
- **Crear gasto con descripción muy larga (> 1000 chars)**: aceptado; SQLite TEXT es ilimitado en la práctica. UI con maxLines + ellipsis.
- **Caracteres especiales y emoji en descripciones, nombres de cuentas, categorías**: aceptado (UTF-8 nativo).
- **Crear cuenta debit y eliminarla inmediatamente sin entries**: aceptado, saldo es 0.
- **Crear categoría con `applies_to` distinto a los 3 valores válidos**: rechazado por validación del DAO + constraint del schema.
- **Insertar entry con `kind` distinto a los 5 valores**: rechazado por validación del DAO.
- **Stream emite valor cuando solo cambian filas archivadas/canceladas**: drift recalcula cuando cualquier fila de la tabla cambia. Esto puede triggear emisiones "innecesarias" del dashboard. Mitigación: aceptable porque el resultado calculado no cambia, drift compara con el valor previo antes de emitir (verificar en test T040).
- **Test que corre en VM Linux sin libsqlite3 system**: sin el override de T037, falla con "DynamicLibrary not found". Test específico verifica que el override está instalado.
- **`pumpAndSettle` se cuelga con streams infinitos**: nunca usar en widget tests. Usar `pump(Duration(milliseconds: N))` con timeout finito.
- **Cerrar la BD entre tests**: si dos tests comparten una instancia no cerrada, el segundo recibe estado contaminado. `tearDown` debe llamar `database.close()` y bombear el Timer interno.
- **Acceder a la BD desde varios isolates**: no aplica en el MVP (todo corre en el main isolate).
- **Migración v1 → v2 (sprint futuro)**: la BD del usuario nunca se recrea. Tests específicos en sprint donde aparezca v2 verifican esto.
- **APK reinstalado conserva la BD**: el `getApplicationDocumentsDirectory()` sobrevive a updates pero se borra en uninstall. Smoke T050 lo verifica indirectamente.

## Pruebas unitarias necesarias

Capa de datos (`mobile/test/data/`):

- **DAOs** (T039): cubren create/update/archive/findById/watchActive para los 3 DAOs con todas las validaciones (RN-004, RN-007, RN-011, RN-013).
- **FinancialStateService** (T040): BO/DE/CR para BD vacía y para cada tipo de movimiento. Saldos por cuenta para los 5 kinds. Streams reactivos verificados con `expectLater(stream, emitsInOrder([...]))`.
- **Backup** (T041): round-trip completo, casos de error, fixture con JSON sample del backend.
- **Invariantes** (T042): OverpayDebt, libreta libre, validaciones de tipo de cuenta por kind, transfer con origin == destination, etc.
- **Seed** (T039 incluido): idempotencia, Bolsa singleton + 10 categorías.
- **Bootstrap** (T039 incluido): `hasBolsa()` con BD vacía vs seeded.

Total estimado: 50+ tests unitarios.

## Pruebas de integración o API necesarias

No aplica. El MVP no consume ni expone APIs.

La única "integración" es el formato JSON v1 compartido con el backend legacy. Test fixture `test/fixtures/backend_export_sample.json` contiene un JSON real del backend (sin datos sensibles — usar un dataset de prueba) y el test T041 verifica que se importa sin errores.

## Pruebas de UI o flujo necesarias si aplica

Capa de pantallas (`mobile/test/screens/`):

- **FirstRunScreen** (T043): render, ambos botones, file picker mockeado, import válido vs corrupto.
- **DashboardScreen** (T044): render, streams reactivos, navegación.
- **EntryFormScreen** (T045): los 5 kinds, edit, cancel, OverpayDebt.

Adicionalmente sería ideal (no listado como tareas separadas para mantener el sprint en alcance razonable):

- **AccountsListScreen, AccountFormScreen, CategoriesListScreen, CategoryFormScreen, EntriesListScreen, SettingsScreen**: tests de smoke por pantalla. Si el alcance permite agregarlos sin alargar mucho, T056+ los suma. Si no, quedan cubiertos por el smoke manual (T050-T051).

Patrones obligatorios documentados en `testApp` helper:

- BD en memoria con `NativeDatabase.memory()`.
- `setUpAll(() => initSqliteOverride())` que carga libsqlite3.so.0.
- `tearDown(() async { await database.close(); await tester.pump(Duration(milliseconds: 600)); })` para drenar Timer interno de drift.
- Usar `select(table).get()` en aserciones; nunca `watch().first` bajo reloj falso.
- Nunca `pumpAndSettle` con streams de drift; usar `pump(Duration)`.

Total estimado: 16+ tests de widget.

## Pruebas de permisos y seguridad si aplica

- **Manifest validado** (T048): `aapt dump permissions` muestra solo `INTERNET` + `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` (autogenerado).
- **Sin red en runtime**: T051 verifica con modo avión que la app funciona sin internet. Adicionalmente `adb shell dumpsys netstats | grep io.github.gregori100.fincore` muestra 0 bytes RX/TX recientes.
- **BD local protegida por el sandbox de Android**: el `getApplicationDocumentsDirectory()` es accesible solo por la app. Heredado del modelo Android, no se testea explícitamente.
- **JSON export no incluye secretos**: el formato v1 solo tiene cuentas + categorías + entries. Sin tokens (no hay), sin emails (no hay), sin passwords (no hay). Sin "user_id" ni nada que identifique al usuario más allá de los datos del libro contable.

## Pruebas de datos, migración o compatibilidad si aplica

- **Migración inicial (schema v1)**: tests T039 verifican que tras `db.openDatabase()` la BD tiene las 3 tablas con sus columnas y los 3 índices.
- **Migración v1 → v2 (futuro)**: no aplica en este sprint. El sprint del v2 introducirá tests específicos. El stub de `onUpgrade` en T016 deja la puerta abierta.
- **Round-trip con datos reales del backend**: test T041 con fixture del JSON real verifica que el contrato compartido funciona.
- **Compatibilidad con cliente online instalado**: T050 implícitamente verifica el upgrade limpio (versionCode 1 → 2) sin requerir desinstalación.

## Pruebas de regresión sobre flujos existentes

No aplica para el código del sprint actual (la base de código de `main` cambia drásticamente).

**Para el código legacy**: la rama `legacy/web-and-online-flutter` queda congelada con las suites previas en verde (backend 394/394, frontend Vue 119/119, mobile online ~50 tests). No se re-corren durante el sprint; cualquier regresión futura sobre ese código requiere checkout explícito.

## Pruebas manuales o smoke tests necesarios

Smoke en Linux desktop (T028 en adelante):

- Por cada pantalla creada, correr `flutter run -d linux` y validar que el flujo funciona contra BD local. Catch temprano de problemas de StreamBuilder, navegación, redirects.

Smoke en Android (T050, T051) — responsabilidad del usuario:

1. `adb install -r mobile/build/app/outputs/flutter-apk/app-release.apk` desde la máquina del agente con el daemon adb ya autorizado.
2. Verificar ícono FinCore en home.
3. Abrir → pantalla "Primer arranque".
4. Tap "Importar respaldo", seleccionar JSON guardado en T001.
5. Verificar Dashboard con BO/DE/CR coincidentes con lo que Diego tenía en el backend antes del pivote.
6. Crear gasto + ingreso + transfer + pago de tarjeta + cargo a tarjeta (los 5 kinds) en MODO AVIÓN. Todos exitosos.
7. Editar uno. Cambiar monto. Guardar. Refrescar dashboard manualmente o vía stream.
8. Cancelar uno. Confirma destructivo. Entry desaparece.
9. Settings → Exportar respaldo → comparte por algún medio (Drive, email a sí mismo).
10. Settings → Importar respaldo → seleccionar el JSON recién exportado → confirmar destructivo → estado idéntico.

Smoke offline obligatorio (T051):

- Modo avión activo durante todo el flujo de smoke (excepto el `adb install` inicial).
- Verificar con `adb shell dumpsys netstats | grep io.github.gregori100.fincore` que el contador de bytes no aumenta.

## Datos de prueba recomendados

- **Sample del JSON del backend**: generar un JSON con 3 cuentas (Bolsa + 1 debit + 1 credit), 5 categorías custom (3 income + 2 expense), 20 movimientos variados de los 5 kinds. Guardar en `mobile/test/fixtures/backend_export_sample.json`. Sin PII real.
- **Factories en `mobile/test/helpers/factories.dart`**: `buildAccount({type, name, balance})`, `buildCategory({appliesTo})`, `buildEntry({kind, amount, origin, destination, occurredAt})` con defaults razonables.
- **Dataset de stress para performance**: en `T040`, generar 10,000 entries random vía loop con `Random(42)` (seed determinístico) y medir tiempo de BO/DE/CR + 10 saldos < 50 ms.

## Comandos o validaciones locales sugeridas

```bash
# Setup (una vez tras flutter create):
export PATH="$HOME/development/flutter/bin:$PATH"
cd mobile
flutter pub get
./scripts/codegen.sh  # dart run build_runner build --delete-conflicting-outputs

# Dev en Linux desktop:
./scripts/run-linux.sh

# Lint + tests:
flutter analyze  # "No issues found!"
flutter test     # ≥ 50 tests verdes

# Codegen tras tocar database.dart:
./scripts/codegen.sh

# Build release:
./scripts/build-apk.sh
# Output: build/app/outputs/flutter-apk/app-release.apk

# Verificar permisos del APK:
aapt dump permissions build/app/outputs/flutter-apk/app-release.apk
# Esperado: INTERNET + DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION solamente.

# Verificar versionName/versionCode:
aapt dump badging build/app/outputs/flutter-apk/app-release.apk | grep package
# Esperado: package: name='io.github.gregori100.fincore' versionCode='2' versionName='0.2.0'

# Install en Android:
$HOME/Android/Sdk/platform-tools/adb devices  # confirma device conectado
$HOME/Android/Sdk/platform-tools/adb install -r build/app/outputs/flutter-apk/app-release.apk

# Verificar offline durante smoke:
adb shell dumpsys netstats | grep io.github.gregori100.fincore  # antes y después; el delta de RX/TX debe ser 0 si solo se usó offline.

# Verificar que la rama legacy preserva todo:
git show origin/legacy/web-and-online-flutter:backend/composer.json | head -5
git show origin/legacy/web-and-online-flutter:mobile/lib/api/auth_api.dart | head -3
```

## Criterios mínimos para aprobar la implementación

1. `flutter test` en verde con ≥ 50 tests (mínimo absoluto; el plan suma >55).
2. `flutter analyze` sin issues.
3. APK release generado y < 50 MB.
4. APK instalado en el Android del usuario y el smoke completo (T050) pasa: el JSON del backend real se importa y los saldos coinciden con los de Postgres antes del pivote.
5. Smoke modo avión (T051) pasa: la app funciona completamente offline.
6. Manifest declara solo `INTERNET` (verificado por `aapt dump permissions`).
7. Versionado: `versionCode = 2`, `versionName = "0.2.0"`.
8. Rama `legacy/web-and-online-flutter` existe en `origin` y `git show` confirma código intacto.
9. `git log -1` en main muestra el commit de borrado masivo + commits subsiguientes del sprint.
10. `README.md`, `CLAUDE.md` raíz, `mobile/README.md` actualizados.
11. `branch-quality-review` ejecutado con 0 bloqueantes.
12. Ningún archivo del cliente online o backend persiste en `main` salvo `engineering/specs/`.

## Validación final recomendada

Tras T054 (último de la lista antes del QR), ejecutar el skill `branch-quality-review` sobre la rama del sprint para revisión exhaustiva. El reporte se genera en `engineering/quality-review/flutter-local-mvp/` con hallazgos clasificados por severidad. Resolver bloqueantes antes del merge a `main`.

Si el skill no está disponible, hacer checklist equivalente manual:

- [ ] Verificar que no quedan referencias a `dio`, `http`, `flutter_secure_storage`, `token`, `bearer`, `login` en `mobile/lib/`.
- [ ] Verificar que `mobile/lib/api/`, `mobile/lib/storage/token_storage.dart`, `LoginScreen`, `VerifyEmailScreen` NO existen en main.
- [ ] Verificar que `widget tests` no usan `pumpAndSettle` con streams infinitos.
- [ ] Verificar que `mobile/test/helpers/test_app.dart` drena el Timer interno de drift en tearDown.
- [ ] Verificar que `mobile/test/helpers/sqlite_override.dart` se importa en todos los tests de datos.
- [ ] Verificar que `mobile/build.yaml` incluye `store_date_time_values_as_text: true`.
- [ ] Verificar que `pubspec.yaml` versión es `0.2.0+2`.
- [ ] Verificar que `mobile/android/app/build.gradle.kts` tiene `versionCode = 2`, `versionName = "0.2.0"`.
- [ ] Verificar `CLAUDE.md` raíz no menciona Laravel/Vue/Tailscale como tecnologías activas (solo como referencia a la rama legacy).
- [ ] Verificar `mobile/README.md` documenta el workflow de codegen.
- [ ] Verificar que no quedan secrets en archivos commiteados.

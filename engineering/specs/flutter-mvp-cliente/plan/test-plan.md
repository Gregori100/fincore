# Plan de pruebas — flutter-mvp-cliente

## Casos borde detectados

Algunos vienen de la spec; otros emergen al modelar la implementación:

- **`FINCORE_API_URL` no definido en build**: `main()` aborta con assert + mensaje claro. Sin ese guard, el dio sin base URL haría requests inválidas silenciosamente.
- **Token guardado pero usuario eliminado en backend**: `me()` al arrancar devuelve 401 → interceptor limpia + Login.
- **Login con cuenta sin verificar**: backend responde 200 con token, pero `me()` o cualquier endpoint protegido devuelve 403 con texto del middleware `verified` → app navega a `/verify-email`.
- **Throttle 6,1 en login + register + verify resend**: respuesta 429. Mensaje "Demasiados intentos, espera 1 minuto."
- **Throttle alcanzado en verify resend**: cooldown visible del botón "Reenviar correo" (10s tras envío exitoso) reduce probabilidad de llegar al 429, pero si llega, mostrar mensaje.
- **401 mientras hay un formulario abierto**: limpia token + redirect a `/login`; el form pierde lo que tenía. Aceptado en spec.
- **403 verificación email mientras la app está abierta**: el interceptor distingue por response body que es de `verified`, no de permisos, y navega a verify.
- **Network error (DioException type = connectionError, timeout)**: snackbar "No se pudo conectar al servidor". El form conserva sus datos.
- **Latencia alta** (Tailscale relay 200-500 ms): botón "Guardar" deshabilitado mientras hay request en vuelo. Loader visible.
- **Doble tap rápido en "Guardar"**: mutex `_saving` en el `State` impide envío duplicado. Test específico (T052).
- **Cancelar movimiento ya cancelado** (race con otra sesión Vue web): backend responde 404 → app trata como "ya estaba cancelado" + refresca lista. Test T048.
- **Cancelar movimiento con FK desde otra entidad**: no aplica acá (soft delete; FK no se rompen).
- **Editar movimiento con cuenta archivada en el medio**: backend responde 422 `invalid_account_type`. App muestra el mensaje y refresca cuentas.
- **Editar movimiento con cuenta eliminada en el medio**: backend 404. App muestra "El movimiento ya no existe" y refresca lista.
- **Crear gasto que dejaría saldo negativo**: libreta libre — backend acepta. App no bloquea. Verificar visualmente que el saldo del dashboard cambia tras refresh.
- **Pagar a tarjeta más de lo debido**: backend 422 `overpay_debt` → app muestra "No podés pagar más de lo que debes a la tarjeta." (RN-003, único bloqueante de creación).
- **Cuenta credit con `closing_day == payment_day`**: backend 422 `invalid_credit_metadata` → app muestra mensaje.
- **Cuenta debit con nombre duplicado**: backend 422 `duplicate_account_name` → app muestra "Ya tenés una cuenta con ese nombre."
- **Categoría con `applies_to=income` seleccionada en form de gasto**: app filtra el picker para no mostrarla; defensivo: si por algún motivo llega al backend, 422 `invalid_category_applies_to`.
- **Slug de color/icono fuera de catálogo**: si una versión futura del backend introduce un slug nuevo, `colorBySlug`/`iconBySlug` retornan fallback (gris + TagIcon genérico) sin crash.
- **Lista vacía en cualquier pantalla**: empty state con CTA al botón crear.
- **Texto largo en descripción** (200+ caracteres): `maxLines: 2 + overflow: ellipsis` en listas; texto expandido en pantalla de detalle/edit.
- **Emoji y UTF-8** en descripciones de movimientos y nombres de categorías: serialización JSON los maneja por default. Test T048 incluye descripción con emoji.
- **Fecha de movimiento futura**: backend acepta; app no bloquea (libreta libre).
- **Movimiento con `occurred_at` en distinta zona horaria**: app envía ISO 8601 con tz local; backend lo persiste como está. Sin manipulación. Documentar.
- **Logout sin red**: app limpia token local incondicionalmente; el POST `/auth/logout` que falla por red no impide el logout local.
- **Tailscale apagado en celular mientras la app está abierta**: siguiente request da `connectionError` → snackbar. Reconectar y refrescar a mano vuelve a operar.
- **APK release sin firma de producción**: usa debug-signing automático. Suficiente para sideload por adb; no para Play Store (spec aparte).
- **`flutter_secure_storage` en Linux desktop sin keyring**: fallback opcional con `LinuxOptions(useSessionKeyring: false)`. Si igual falla, escribir token a archivo cifrado o documentar limitación.
- **Rotación de pantalla / proceso matado** (Android lifecycle): lo guardado persiste (está en el backend); lo en flight en el formulario se pierde. Aceptado.

## Pruebas unitarias necesarias

Capa modelos (`test/models/`):

- Cada `fromJson` y `toJson` round-trip preserva campos. Cubrir `Account` (con metadata de credit), `Category`, `JournalEntry` con relaciones embebidas (account_origin, account_destination, category posiblemente null), `FinanceState`, `Paginated<T>`, `DomainError`.

Capa constants (`test/constants/`):

- `kinds.dart`: el enum mapea correctamente con `apiValue()` y `label()`.
- `account_types.dart`: `canBeOrigin(JournalKind)` y `canBeDestination(JournalKind)` retornan lo esperado para los 5 kinds × 3 tipos = 15 combinaciones.
- `category_catalog.dart`: `colorBySlug('blue')` retorna el color esperado; slug desconocido retorna fallback.

Capa theme (`test/theme/`):

- `fincoreDarkTheme()` retorna un `ThemeData` con `brightness: dark` y `useMaterial3: true`. No hace falta validar cada color; verificar que el ColorScheme tiene los slots esperados.

## Pruebas de integracion o API necesarias

Capa API client (`test/api/`):

- `auth_api_test.dart` (T047): cubre login (200 + 422 + 429), logout (204), me (200 + 401), resend (204 + 429). Mockeando `dio.post`/`dio.get` con `mocktail`.
- `entries_api_test.dart` (T048): cubre los 5 endpoints de creación (income, expense, credit_expense, debt_payment éxito + overpay 422, transfer), patch entry, delete entry, delete 404.
- `accounts_api_test.dart`: cubre create (debit y credit), patch, delete (200 + 422 account_not_empty), list (incluyendo `include_archived=1`).
- `categories_api_test.dart`: cubre create, patch, delete (archivar), list con filtros.
- `state_api_test.dart`: cubre GET /finance/state retorna `FinanceState` con BO/DE/CR y listas.
- `error_interceptor_test.dart` (T049): cubre los 5 tipos de error que el interceptor maneja (401, 403-verified, 422, 429, connectionError). Mockear `dio.interceptors`.

Total: ~30-35 tests unitarios.

## Pruebas de UI o flujo necesarias si aplica

Capa screens (`test/screens/`), montando `testApp(apiClient: mockClient, tokenStorage: mockStorage)`:

- `login_screen_test.dart` (T050): render, login OK, login 422, login 403-verify navegación.
- `dashboard_screen_test.dart` (T051): render con state, pull-to-refresh, navegación a settings.
- `entry_form_screen_test.dart` (T052): form expense (selecciona cuenta + monto + descripción + categoría + guarda), form transfer (origen ≠ destino), debt_payment con overpay (muestra mensaje), edit con kind inmutable, doble tap → un solo submit.
- `verify_email_screen_test.dart` (T053): render, reenviar OK, cooldown 10s, "Ya verifiqué" navega a dashboard.

Patrones aprendidos en dogear que aplican acá (aunque no haya drift):

- Usar `select().get()` y nunca `watch().first` en widget tests (no aplica acá porque no usamos streams de drift; usamos Futures, pero el patrón análogo es: nunca esperar `Future` con `await tester.pump()` indefinido — usar `pumpAndSettle` con timeout corto o `pump(Duration)`).
- `pumpAndSettle` se cuelga con animaciones infinitas; los snackbars tienen duración finita pero verificar.
- En `tearDown`, drenar el `_savingTimer` del helper si existe.
- BD inyectada por constructor — análogo acá: `apiClient` inyectado por constructor a `testApp`.

Total: ~15 tests de widget.

## Pruebas de permisos y seguridad si aplica

- **Manifest validado** (T056): solo `android.permission.INTERNET`. Si algún plugin añade más, suprimir.
- **Token nunca persiste en logs**: revisar que no se imprima en `debugPrint` ni en interceptores cuando hay `kDebugMode`.
- **HTTPS estricto** en producción: el backend tiene cert válido (Tailscale Funnel + Let's Encrypt). No aceptar self-signed; si en algún momento de testing dev sí hace falta, ponerlo solo bajo `kDebugMode`.
- **Sanctum bearer correcto**: tests T047 verifican que el header `Authorization: Bearer <token>` viaja.
- **403-verified vs 403-otro**: el interceptor debe distinguir por response body (texto del middleware `verified`). Test T049 cubre.

## Pruebas de datos, migracion o compatibilidad si aplica

No aplica. Sin migraciones, sin transformaciones de datos.

Compatibilidad: la app consume el mismo backend que la Vue web; movimientos creados en uno aparecen en el otro tras refresh. Smoke T059 lo valida.

## Pruebas de regresion sobre flujos existentes

- **Vue web sigue funcional**: tras el sprint, abrir la Vue web (vía Tailscale desde laptop) y verificar que login + dashboard + reportes + Excel funcionan igual. La Vue no fue tocada, debería ser true por construcción.
- **Backend sin cambios**: corre `cd backend && php artisan test`. Esperado: 394/394 verde (mismo que estado actual de main).
- **Stack docker tailscale sigue arriba**: `docker compose -f compose.tailscale.yml ps` → containers healthy.

## Pruebas manuales o smoke tests necesarios

Smoke en Linux desktop (T021..T045):

- Por cada pantalla creada, correr `flutter run -d linux --dart-define=FINCORE_API_URL=https://loma-latitude-3540.tail285790.ts.net` y validar que el flujo funciona contra el backend real. Catch temprano para problemas de tipos JSON, etc.

Smoke en Android (T059):

1. `flutter build apk --release --dart-define=FINCORE_API_URL=...`.
2. `adb install build/app/outputs/flutter-apk/app-release.apk`.
3. Verificar ícono "FinCore" en home del Redmi Note 13.
4. Abrir → Login con `diego.velez@mgtransportes.mx`.
5. Dashboard muestra BO/DE/CR + cuentas + últimos movimientos.
6. Crear gasto: tap FAB → seleccionar kind "Gasto" → cuenta + monto + categoría + descripción + guardar → vuelve al dashboard con saldo actualizado.
7. Crear pago de tarjeta: kind "Pago de tarjeta" → origen debit + destino credit + monto → guardar.
8. Editar el gasto creado: lista entries → tap → cambiar monto → guardar.
9. Cancelar el pago de tarjeta: lista → tap → menú → cancelar → confirmar.
10. Refrescar dashboard: saldo refleja todos los cambios.
11. Settings → Cerrar sesión → vuelve a Login.

Smoke verify email (T060):

1. Crear usuario de testing desde la Vue web (`diego+verify@mgtransportes.mx`) o por SQL directo: `INSERT INTO users (...) VALUES (...)` sin `email_verified_at`.
2. Login con esas credenciales desde Flutter → pantalla Verify Email aparece (el `me()` devuelve usuario sin verificar, o un endpoint protegido devuelve 403).
3. Tap "Reenviar correo" → verificar en logs del backend `docker compose -f compose.tailscale.yml logs app | grep "Verify Email Address"`.
4. Verificar manualmente seteando `email_verified_at = NOW()` en BD.
5. Tap "Ya verifiqué" → entra a dashboard.

## Datos de prueba recomendados

- Usuario titular: `diego.velez@mgtransportes.mx` (ya en BD, verificado).
- Usuario verify: `diego+verify@mgtransportes.mx` (crear sin verificar para T060). Tras T060 termina verificado.
- Cuentas: la Bolsa por default + al menos 1 debit ("Banamex") y 1 credit ("Visa Banorte") preexistentes.
- Categorías: las 10 default creadas en registro + al menos 1 custom propia para validar CRUD.
- Movimientos: dataset variado de los 5 kinds para validar lista paginada y filtros.

## Comandos o validaciones locales sugeridas

```bash
# Setup (una vez):
export PATH="$HOME/development/flutter/bin:$PATH"
cd mobile && flutter pub get

# Dev en Linux desktop:
export FINCORE_API_URL=https://loma-latitude-3540.tail285790.ts.net
./scripts/run-linux.sh

# Lint + tests:
flutter analyze       # debe quedar en "No issues found!"
flutter test          # debe quedar en "All tests passed!" con ≥30 tests

# Build release:
./scripts/build-apk.sh
# Output: build/app/outputs/flutter-apk/app-release.apk

# Install en Android:
adb devices            # confirma device conectado
adb install build/app/outputs/flutter-apk/app-release.apk

# Verificar permisos del APK:
aapt dump permissions build/app/outputs/flutter-apk/app-release.apk
# Esperado: solo android.permission.INTERNET

# Verify email flow (crear user sin verificar):
docker compose -f compose.tailscale.yml exec app php artisan tinker
# > User::factory()->unverified()->create(['email' => 'diego+verify@mgtransportes.mx', 'password' => Hash::make('test1234')]);
# > exit
```

## Criterios minimos para aprobar la implementacion

1. `flutter test` en verde con ≥30 tests (mínimo declarado en spec ≥10; con tests propuestos se llega cómodamente).
2. `flutter analyze` sin issues.
3. APK release generado y < 30 MB.
4. APK instalado en el Android del usuario y el smoke completo (T059) pasa.
5. Smoke verify email (T060) pasa.
6. Manifest declara solo `INTERNET` (validado por `aapt dump permissions`).
7. Vue web sin regresiones (smoke breve en laptop).
8. Backend sin regresiones (`php artisan test` 394/394).
9. `branch-quality-review` ejecutado con 0 bloqueantes.

## Validacion final recomendada

Tras T063 (último de la lista de tareas), ejecutar el skill `branch-quality-review` sobre la rama del sprint para revisión exhaustiva. El reporte se genera en `engineering/quality-review/flutter-mvp-cliente/` con hallazgos clasificados por severidad. Resolver bloqueantes antes del merge a `main`.

Si el skill no está disponible, hacer checklist equivalente manual:

- [ ] Sin secrets commiteados (revisar `mobile/` por strings que parezcan tokens).
- [ ] Sin URLs hardcodeadas (todo viene de `FINCORE_API_URL`).
- [ ] Sin `print`/`debugPrint` que filtre token o datos sensibles.
- [ ] Sin `await` que pueda quedar pendiente indefinido en widget tests.
- [ ] Sin código muerto ni TODO sin resolver crítico.
- [ ] Versionado `0.1.0+1` consistente entre `pubspec.yaml` y `build.gradle.kts`.
- [ ] README cubre los 6 puntos del T061.
- [ ] `CLAUDE.md` raíz tiene la sección Mobile completa.

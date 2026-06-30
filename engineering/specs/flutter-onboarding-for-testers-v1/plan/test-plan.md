# Test plan — flutter-onboarding-for-testers-v1

## Casos borde detectados

Además de los listados en `spec.md`, esta lista cubre escenarios que pueden romper el flujo o degradar la UX:

- **CB-D01**: `AppPreferencesDao.get` con clave inexistente → retorna `null` sin error.
- **CB-D02**: `AppPreferencesDao.set` invocado dos veces con la misma clave → segunda llamada sobrescribe el valor (idempotencia con `insertOnConflictUpdate`).
- **CB-D03**: tabla `app_preferences` no existe (migración fallida o bug). El DAO debe tratar el error y degradar a "key no existe" sin crashear la app.
- **CB-D04**: `last_export_at` con valor `"not-a-date"` o `""`. `DateTime.tryParse` retorna `null` → tratar como nunca exportado (no mostrar "hace X días" con valores raros).
- **CB-D05**: `last_export_at` con timestamp futuro (clock cambiado). `now.difference(parsed).inDays` da negativo → renderizar como "hace 0 días" sin warning.
- **CB-D06**: `last_export_at` exactamente 14 días — verificar si el umbral es inclusivo (`≥14`) o estricto (`>14`). Spec dice `≥14`, validar con test.
- **CB-D07**: Diego (con Bolsa) actualiza el APK. Arranca → `hasBolsa = true` → router a dashboard SIN pasar por onboarding. Validar tiempo de splash <100ms.
- **CB-D08**: Tester instala APK por primera vez. `hasBolsa = false && onboarding_seen = false` → router a `/onboarding`. Confirmar que no flickea entre rutas.
- **CB-D09**: Tester saltea onboarding desde slide 1 → flag persiste como `'true'` → al volver a abrir la app, va directo a `/first-run`.
- **CB-D10**: Tester sale del onboarding con back hardware → no se marca el flag → próximo arranque vuelve a verlo.
- **CB-D11**: Tester importa respaldo en first-run. Tras import exitoso → `hasBolsa = true` Y `onboarding_seen = true` (SP-06). Próximo arranque va directo a dashboard.
- **CB-D12**: Tester hace "Reiniciar cuenta" desde Settings → `wipeAll` borra `app_preferences` → próximo arranque vuelve a mostrar onboarding.
- **CB-D13**: Export exitoso seguido inmediatamente por otro export. El segundo `last_export_at` sobrescribe al primero. OK.
- **CB-D14**: Export con `ShareResult.unavailable` o `dismissed` (cancelado por usuario). `last_export_at` NO se actualiza (RN-O08).
- **CB-D15**: Pantalla Ayuda con `ExpansionTile` que tienen contenido muy largo. Validar que el scroll funciona y los items se cierran al tappearlos de nuevo.
- **CB-D16**: Onboarding con slides que tienen ilustraciones — si en el futuro agregamos imágenes, validar que se cargan sin parpadeo. En v1 son texto + iconos del Material.
- **CB-D17**: Race del splash: `hasBolsa` resuelve en 5ms, `onboarding_seen` en 50ms. El router debe esperar a que ambos sean no-null antes de redirigir.
- **CB-D18**: Importar respaldo JSON v1 con muchos entries. Tras import, `onboarding_seen = true`. Si la query del DAO falla, NO bloquear el flujo de import (RN-S09 conceptual: degradación silenciosa).

## Pruebas unitarias necesarias

Ubicación: `mobile/test/data/app_preferences_dao_test.dart` (archivo nuevo).

- **UT-01**: `get` con clave inexistente → `null`.
- **UT-02**: `set` + `get` → recupera el valor seteado.
- **UT-03**: `set` con la misma clave dos veces → segunda llamada sobrescribe (idempotente).
- **UT-04**: `set` con valor empty string `""` → recuperable como `""` (no null).
- **UT-05**: Múltiples claves coexisten sin interferencia (`onboarding_seen` + `last_export_at` en la misma BD).

## Pruebas de integración o API necesarias

No aplica (FinCore sin HTTP). Las pruebas de integración aquí son los tests sobre SQLite real con `NativeDatabase.memory()`.

## Pruebas de UI o flujo necesarias

### `mobile/test/screens/onboarding_screen_test.dart` (archivo nuevo)

- **WT-O01**: Monta `OnboardingScreen` → renderiza slide 1 (verifica wordmark + título).
- **WT-O02**: Tap "Siguiente" → renderiza slide 2.
- **WT-O03**: Tap "Siguiente" otra vez → renderiza slide 3 con botón "Empezar" en lugar de "Siguiente".
- **WT-O04**: Tap "Empezar" → llama a `appPreferencesDao.set(kPrefOnboardingSeen, 'true')` + navega a `/first-run`.
- **WT-O05**: Tap "Saltar" desde slide 1 → flag persiste + navega a `/first-run` sin haber visto slides 2 y 3.
- **WT-O06**: Tap en dot del slide 3 → navega directo al slide 3 (PageController.animateToPage).
- **WT-O07**: Swipe horizontal entre slides funciona.

### `mobile/test/screens/help_screen_test.dart` (archivo nuevo)

- **WT-H01**: Monta `HelpScreen` → renderiza 6 `ExpansionTile`.
- **WT-H02**: Tap en primer ExpansionTile → expande contenido visible.
- **WT-H03**: Tap otra vez → colapsa.
- **WT-H04**: Verifica títulos esperados de los 6 temas.

### `mobile/test/screens/settings_screen_test.dart` (extender existente)

- **WT-S-LX01**: `last_export_at` no existe → renderiza "Aún no exportaste un respaldo."
- **WT-S-LX02**: `last_export_at` hace 5 días → renderiza "Último respaldo: hace 5 días."
- **WT-S-LX03**: `last_export_at` hace 20 días → renderiza badge warning + texto con "te recomendamos exportar pronto".
- **WT-S-LX04**: `last_export_at` con valor corrupto → renderiza "Aún no exportaste un respaldo." (CB-D04).
- **WT-S-LX05**: Tap en BaseCard "Ayuda" → navega a `/help`.

### Test de regresión del router (extender o nuevo)

- **WT-R-01**: `hasBolsa=true, onboarding_seen=false` (Diego con BD vieja) → router redirige a `/dashboard` sin pasar por `/onboarding`.
- **WT-R-02**: `hasBolsa=false, onboarding_seen=false` (tester nuevo) → router redirige a `/onboarding`.
- **WT-R-03**: `hasBolsa=false, onboarding_seen=true` (tester que saltó onboarding) → router redirige a `/first-run`.
- **WT-R-04**: `hasBolsa=true, onboarding_seen=true` → router redirige a `/dashboard`.

## Pruebas de permisos y seguridad

No aplica (single-user, BD local).

## Pruebas de datos, migración o compatibilidad

### `mobile/test/data/database_migration_test.dart` (extender existente)

- **MT-01**: Migración v3 → v4. Sembrar BD en estado v3 (con tabla `saved_views` existente), dropear `app_preferences`, llamar `onUpgrade(3, 4)`, verificar que la tabla `app_preferences` queda creada y usable. Confirmar que datos en `accounts`, `categories`, `journal_entries`, `saved_views` sobreviven.
- **MT-02**: Rama defensiva v2 → v4. Sembrar BD v2 (sin `saved_views` ni `app_preferences`), llamar `onUpgrade(2, 4)`, verificar que ambas tablas quedan creadas.
- **MT-03**: Rama defensiva v1 → v4. Sembrar BD v1 (sin índice parcial ni `saved_views` ni `app_preferences`), llamar `onUpgrade(1, 4)`, verificar índice creado + ambas tablas.
- **MT-04**: Guardrail: `onUpgrade(4, 99)` lanza `UnimplementedError` con mensaje informativo.
- **MT-05**: Wipe limpia `app_preferences`. Sembrar entries + setear `last_export_at` → `wipeAll()` → verificar que `app_preferences` queda vacía.

## Pruebas de regresión sobre flujos existentes

- **RG-01**: Suite completa `flutter test` verde. Esperar 344 → ~360 tests (+~16 nuevos).
- **RG-02**: Tests existentes del router/harness siguen verdes. Especialmente `widget_test_harness_test.dart` y los que dependen de `FirstRunState`.
- **RG-03**: Tests de `BackupService` (`backup_test.dart`) siguen verdes. La extensión de `_wipeTablesInternal` para `app_preferences` no debe romper round-trip de export/import.
- **RG-04**: Tests de `SettingsScreen` existentes (cancelar reseteo, exportar, importar) siguen verdes.
- **RG-05**: `flutter analyze` sin nuevos warnings. Los 4 hints `info` pre-existentes siguen tolerados.

## Pruebas manuales o smoke tests necesarios

- **SM-01**: Diego actualiza el APK sobre BD real (con Bolsa). Abre la app → splash → dashboard directo, SIN ver onboarding. Tiempo de transición similar al actual (<300ms percibido).
- **SM-02**: Diego abre Settings → ve la nueva entrada "Ayuda" justo encima de "Acerca de". Tap → `HelpScreen` con 6 ExpansionTile.
- **SM-03**: Diego abre Settings → ve la línea bajo "Exportar respaldo" con texto "Aún no exportaste un respaldo." (porque el timestamp no está retroactivo).
- **SM-04**: Diego exporta respaldo → comparte con éxito (Share success) → vuelve a Settings → ve "Último respaldo: hace 0 días.".
- **SM-05**: (Si Diego puede) probar con un cel limpio (BD vacía) o un emulador: ver onboarding completo → "Empezar" → first-run → arrancar limpio → dashboard.
- **SM-06**: Tester real (un amigo) instala el APK sobre cel limpio. Reportar UX del onboarding: ¿se entiende? ¿hay confusión?

## Datos de prueba recomendados

Para unit tests del DAO:

- BD in-memory con migración corrida hasta v4.
- Sin seed previo necesario.

Para widget tests del `OnboardingScreen` y `HelpScreen`:

- Usar `pumpFincoreApp` con `seedBolsa: false` para que el flujo del onboarding sea consistente.

Para widget tests del `_LastExportInfo`:

- Sembrar `app_preferences` con valores específicos vía `appPreferencesDao.set` antes del pump.

Para migración:

- Reusar el patrón actual de `database_migration_test.dart` (drop + recreate manual + assert).

## Comandos o validaciones locales sugeridas

```bash
cd mobile

# Unit tests DAO
flutter test test/data/app_preferences_dao_test.dart

# Tests de migración (con los nuevos casos)
flutter test test/data/database_migration_test.dart

# Widget tests del Onboarding
flutter test test/screens/onboarding_screen_test.dart

# Widget tests del Help
flutter test test/screens/help_screen_test.dart

# Widget tests del Settings (extendidos)
flutter test test/screens/settings_screen_test.dart

# Suite completa
flutter test

# Lint
flutter analyze

# Build APK
flutter build apk --release --split-per-abi
scripts/verify-apk.sh build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

## Criterios mínimos para aprobar la implementación

- `flutter analyze` con 0 errores nuevos (4 hints `info` pre-existentes tolerados).
- `flutter test` verde con la suite completa.
- Smoke SM-01 + SM-02 + SM-03 + SM-04 confirmados por Diego (Diego sin disrupción + Ayuda visible + recordatorio de backup funcionando).
- Cumple AC-01..AC-11 del spec.
- Migración v3 → v4 documentada en `database.dart` con guardrail preservado.
- Tests de migración cubren las 3 ramas (v3→v4, v2→v4, v1→v4) + guardrail.
- Bump de versión sincronizado entre `pubspec.yaml` y `android/app/build.gradle.kts`.
- `BackupService.wipeAll()` borra `app_preferences` verificado con test.

## Validación final recomendada

Tras implementar, invocar `branch-quality-review` con argumento `flutter-onboarding-for-testers-v1`. El reporte se genera en `engineering/quality-review/flutter-onboarding-for-testers-v1/`.

Si no se invoca, hacer revisión equivalente manual:

- Verificar que la migración no introduce N+1 ni queries adicionales en el flujo crítico (Diego en dashboard).
- Verificar que el `FirstRunState` extendido mantiene compat backward con tests existentes.
- Verificar que el flujo del onboarding no se puede skipear con back hardware silenciosamente sin marcar el flag.
- Verificar que la query del `appPreferencesDao.get` en el splash no agrega latencia perceptible.
- Verificar que el `_wipeTablesInternal` extendido sigue dentro de una transacción atómica.
- Verificar que el bump de versión está sincronizado.

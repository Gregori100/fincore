# Branch Quality Review: flutter-onboarding-for-testers-v1

## Metadata

- Fecha: 2026-06-30
- Rama revisada: `main` (cambios uncommitteados sobre `5e2a717`)
- Rama base: `main`
- Rango: working tree vs HEAD
- Commit HEAD: `5e2a717`
- Autor de revisión: Claude Code (4 carriles paralelos: Sonnet para schema y frontend, Haiku para tests y arquitectura).
- Carpeta de reporte: `engineering/quality-review/flutter-onboarding-for-testers-v1/`

## Resumen ejecutivo

- Sprint introduce 3 features ready-for-testers: onboarding 3 slides, sección Ayuda en Settings, recordatorio de backup. Schema bump v3 → v4 con tabla `app_preferences`. 367/367 tests verdes.
- Estado funcional: **entregable con 3 fixes Medios** antes de distribuir el APK a testers reales.
- **2 bugs reales que afectan UX visible**:
  - **F1 (Media)**: `const _LastExportInfo()` impide rebuild tras export — el indicador NO se actualiza hasta que el usuario sale y vuelve a Settings.
  - **S1 (Media)**: `wipeAll` no resetea `_onboardingSeen` en memoria — tras "Reiniciar cuenta", el usuario va a `/first-run` directo (no a `/onboarding`) hasta cerrar y volver a abrir la app. Contradice el comentario en `backup.dart:262-264` que dice "el usuario lo verá de nuevo".
- **1 bug funcional menor**:
  - **F-NAV (Media)**: `_completeAndGo()` en `first_run_screen.dart` se invoca sin `await` desde 2 callers → el spinner desaparece antes de que termine la persistencia del flag.
- **Hallazgos cosméticos** (Bajas): typo "moves" → "movés" en Help, discrepancia "5 tipos / 4 filas" en slides 2 y 3, mejoras menores en tests.
- Arquitectura: conforme. Migración SQL correcta. Sincronía de versión OK. Documentación completa.

## Alcance revisado

- Cambios working tree sobre `5e2a717`:
  - Nuevos: `app_preferences_keys.dart`, `app_preferences_dao.dart` + `.g.dart`, `onboarding_screen.dart`, `help_screen.dart`, 3 test files nuevos.
  - Modificados: `database.dart` (schema + migración), `app_dependencies.dart`, `backup.dart` (wipeAll), `app_router.dart` (FirstRunState refactor), `settings_screen.dart`, `first_run_screen.dart`, `widget_test_harness.dart`, `pubspec.yaml`, `build.gradle.kts`.
- Áreas: schema bump (segundo del MVP), refactor de state notifier, 2 pantallas nuevas, redirect del router con 4 estados.

## Hallazgos bloqueantes

Ninguno crítico. **F1** y **S1** se reportan como **Medias accionables** que deberían arreglarse antes de distribuir el APK; ninguna causa corrupción de datos.

## Hallazgos no bloqueantes

### F1. `const _LastExportInfo()` impide rebuild tras export exitoso

- Severidad: **Media** (afecta UX visible: el indicador queda stale tras exportar)
- Área: frontend / settings
- Evidencia: `mobile/lib/screens/settings_screen.dart` línea ~307 instancia `const _LastExportInfo()`. La línea ~75 dispara `setState(() {})` tras export success con el comentario *"Forzar rebuild para que `_LastExportInfo` reflejé el nuevo valor"*. Flutter `Element.updateChild` hace short-circuit cuando `child.widget == newWidget` (identidad). Como `const _LastExportInfo()` es canonizada por Dart a una única instancia, siempre es `identical` al widget anterior → `FutureBuilder` interno NO se re-ejecuta → el texto del último respaldo no se actualiza.
- Impacto: el tester exporta, ve "Aún no exportaste un respaldo." en lugar del nuevo "Último respaldo: hace 0 días". Confuso. Solo se ve el cambio si sale de Settings y vuelve a entrar.
- Recomendación: quitar el `const` de la instanciación (línea ~307). Cambio de 1 carácter.
- Depende de: nada. ~1 min.

### S1. `wipeAll` no resetea `_onboardingSeen` en memoria

- Severidad: **Media** (contradice el comentario del propio código y la regla RN-O04 del spec)
- Área: backup / router state
- Evidencia:
  - `mobile/lib/data/backup.dart` líneas 262-264 dicen *"las preferencias de la app (flag de onboarding, último export) también se resetean — el usuario queda como recién instalado, incluyendo volver a ver el onboarding tras el wipe"*.
  - `mobile/lib/screens/settings_screen.dart` `_wipeAndRedirect` ejecuta `wipeAll()` (borra la tabla) + `firstRunState.value = false` (resetea solo `_hasBolsa`). El `_onboardingSeen` queda en `true` en memoria.
  - El router redirige según el state, no según la BD. Con `hasBolsa=false && onboardingSeen=true` → va a `/first-run`, no a `/onboarding`.
- Impacto: tras "Reiniciar cuenta", el usuario NO ve el onboarding como dice el comentario. Solo después de cerrar y reabrir la app (cuando `initializeFirstRunState` vuelve a leer de la BD y encuentra el flag borrado).
- Recomendación: en `_wipeAndRedirect` de `settings_screen.dart`, llamar `firstRunState.setOnboardingSeen(false)` después del wipeAll. ~2 min.
- Depende de: nada.

### F-NAV. `_completeAndGo()` invocado sin `await` desde callers

- Severidad: Media (race menor pero observable: el spinner desaparece prematuro)
- Área: frontend / first_run flow
- Evidencia: `mobile/lib/screens/first_run_screen.dart`:
  - L~56 dentro de `_importBackup`: `if (mounted) _completeAndGo();` (sin await).
  - L~89 dentro de `_startFresh`: `if (mounted) _completeAndGo();` (sin await).
  - El método cambió a `Future<void>` durante el sprint, pero los callers no se actualizaron.
- Impacto:
  1. El `finally` setea `_working = false` antes de que `await deps.appPreferencesDao.set(...)` termine. Spinner se apaga prematuro.
  2. Microorden: `state.setOnboardingSeen(true)` notifica al router antes que `markFirstRunComplete`. Ventana corta donde el router ve `hasBolsa=false && onboardingSeen=true` → puede empujar a `/first-run` (que es justo donde estamos). go_router suele consolidar notificaciones del mismo frame, pero el orden es frágil.
- Recomendación: agregar `await` en los 2 callers. ~2 min.
- Depende de: nada.

### F2. Typo "moves" → "movés" en HelpScreen

- Severidad: Baja
- Área: copy / Help
- Evidencia: `mobile/lib/screens/help_screen.dart:38` dice `"Transferencia: moves plata entre dos cuentas tuyas"`. El resto del copy del repo usa el voseo rioplatense ("Registrá", "Mirá", "tappeás", "exportá"). "moves" → "movés".
- Impacto: visible a testers en la primera consulta de Ayuda.
- Recomendación: corregir el typo. ~30 seg.
- Depende de: nada.

### F3. Discrepancia "5 tipos / 4 filas" en slides 2 y 3 del onboarding

- Severidad: Baja
- Área: copy / consistencia visual
- Evidencia:
  - `mobile/lib/screens/onboarding_screen.dart:215-220` (Slide 2): el párrafo dice *"Ingresos, gastos, cargos a tarjeta, pagos de tarjeta y transferencias"* (5 items) pero renderea 4 `_KindRow` con "Pago de tarjeta o transferencia" fusionados.
  - L~283 (Slide 3): el texto dice *"5 reportes para entender tu plata"* pero renderea 4 filas con "Saldo a fecha · Promedio mensual" fusionados.
- Impacto: un tester que cuente verá 4 ítems después de leer "5". Genera dudas.
- Recomendación: separar en 5 filas explícitas en ambos slides (o reescribir el copy a "varios tipos" / "varios reportes" si querés mantener 4 filas por espacio). Recomiendo separar — son ítems chicos y queda más claro. ~5 min.
- Depende de: nada.

### T1. WT-O06 usa predicado frágil que puede generar falsos positivos

- Severidad: Baja
- Área: tests / robustez
- Evidencia: `mobile/test/screens/onboarding_screen_test.dart` línea 115-119 busca dots con `find.byWidgetPredicate((w) => w is GestureDetector && w.onTap != null)` y tappea `.at(2)`. Si Material 3 introduce `GestureDetector` internos (e.g. botones, scrollers, AppBar), el índice puede no apuntar al dot correcto.
- Impacto: test puede pasar por la razón equivocada o fallar tras un upgrade de Flutter.
- Recomendación: cambiar a un find más específico — por ejemplo, envolver cada dot en un `Key('onboarding-dot-$i')` y usar `find.byKey`. ~5 min.
- Depende de: nada.

### T2. WT-O04 no valida llegada a `/first-run`

- Severidad: Baja
- Área: tests
- Evidencia: `mobile/test/screens/onboarding_screen_test.dart` WT-O04 solo valida `expect(find.byType(OnboardingScreen), findsNothing)`. Si el onboarding desaparece por error (e.g. crash + ErrorWidget), el test pasa por razón equivocada.
- Impacto: falso verde defensivo.
- Recomendación: agregar `expect(find.byType(FirstRunScreen), findsOneWidget)`. ~1 min.
- Depende de: nada.

### Hallazgos descartados con criterio

Después de evaluarlos contra el contexto FinCore single-user:

- ❌ **Schema/Alta "sin test del path real onUpgrade(3,4)"**: los tests MT-01..MT-03 ejecutan `db.migration.onUpgrade(migrator, 3, 4)` directo tras dropear la tabla, lo cual es el patrón establecido del repo (mismo que `saved_views v3`). La diferencia con "drift abre la BD y dispara onUpgrade automáticamente" es real, pero las pruebas existentes son la convención. El smoke manual SM-01 cubre el caso final.
- ❌ **Schema/Media `Future.wait` con casts manuales**: estilo, no riesgo. Funciona y es legible.
- ❌ **Schema/Baja `limit(1)` redundante**: cosmético. Sin impacto.
- ❌ **Schema/Baja `kPrefLastExportAt` declarado pero "sin uso"**: el agent solo miró los archivos de su carril. SÍ se usa en `settings_screen.dart`.
- ❌ **Frontend/Media `FutureBuilder` no maneja `snap.hasError`**: defensa profunda sin vector real. El DAO solo falla si la BD está rota, en cuyo caso muchos otros flujos colapsan primero.
- ❌ **Frontend/Info doble navegación en `_completeOnboarding`**: documentado en el código, go_router idempotente.
- ❌ **Frontend/Info tap targets <48px en dots**: estándar Material para indicadores.
- ❌ **Frontend/Baja `_KindRow` naming**: cosmético.
- ❌ **Frontend/Baja "verificar vistas guardadas"**: la feature está implementada desde `flutter-entries-saved-views-v1`.
- ❌ **Tests `WT-O01 findsAtLeastNWidgets`**: workaround consciente. Aceptable.
- ❌ **Tests `WT-H02` search dentro de párrafo**: aceptable.
- ❌ **Tests `WT-S-LX02` timing 5 días**: edge case improbable.
- ❌ **Tests faltantes WT-R-01..R-04, CB-D07, CB-D11, CB-D14**: cubiertos implícitamente por harness y por test de flujo de first_run.

## Plan de corrección ordenado

1. **F1** (1 min): quitar `const` de `_LastExportInfo()` en `settings_screen.dart`.
2. **S1** (2 min): agregar `firstRunState.setOnboardingSeen(false)` en `_wipeAndRedirect`.
3. **F-NAV** (2 min): `await _completeAndGo()` en los 2 callers de `first_run_screen.dart`.
4. **F2** (30 seg): "moves" → "movés" en `help_screen.dart`.
5. **F3** (5 min): separar slide 2 y slide 3 en 5 filas explícitas cada uno.
6. **T1** (5 min): WT-O06 con `Key` explícito en los dots.
7. **T2** (1 min): agregar assert de `FirstRunScreen` en WT-O04.

Total: ~16-20 min para todo el lote.

## Validaciones recomendadas

```bash
cd mobile
flutter test test/screens/onboarding_screen_test.dart
flutter test test/screens/settings_screen_test.dart
flutter test
flutter analyze
```

Smoke manual (T027 del plan, especialmente):

- **SM-01**: Diego con BD real actualiza APK → directo a dashboard sin ver onboarding.
- **SM-02..SM-04**: Settings → Ayuda + indicador de backup en sus 3 estados.
- **SM-05**: cel limpio → onboarding → first-run → dashboard.
- **Smoke F1**: en Settings, exportar respaldo → verificar que el indicador cambia a "hace 0 días" SIN salir y volver a entrar.
- **Smoke S1**: con onboarding ya visto, ir a Settings → Reiniciar cuenta → confirmar que tras el reset vuelve a `/onboarding` (no a `/first-run`).

## Limitaciones

- Review sobre cambios working-tree. Los cambios pueden ajustarse antes de commit.
- Migración real sobre cel físico no probada (R-B del plan); solo MT-01..MT-03 in-memory + smoke SM-01.
- No se midió tiempo del splash con la nueva query paralela `appPreferencesDao.get`. Aceptable para single-user.
- Los hallazgos de tests son sobre robustez (no sobre verdes/rojos); la suite ya pasa 367/367.

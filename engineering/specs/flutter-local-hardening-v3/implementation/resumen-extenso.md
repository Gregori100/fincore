# Resumen extenso — flutter-local-hardening-v3

## Contexto

Sprint técnico de continuidad sobre la app FinCore Flutter Android local-first. Cierra **4 ítems** del backlog del sprint anterior `flutter-local-hardening-v2` (commit `43b2c0e`, APK `0.3.6+38`):

1. Widget test del `entry_form_screen` para cancel + submit en modo edit.
2. Widget tests T043-T045 del MVP (dashboard, entry_form 5 kinds, listas).
3. Script `scripts/verify-apk.sh` para detectar `INSTALL_FAILED_VERSION_DOWNGRADE`.
4. Cleanup defensivo del cache de streams (`onCancel` en `_ReplayBalanceStream`).

El ítem 5 (registrar `EntriesDao` en `@DriftDatabase(daos: [...])`) quedó **fuera de scope** explícito desde la spec porque implicaba invertir la dependencia con `FinancialStateService` y tocar mucho código por ganancia cosmética.

## Decisiones clave durante el sprint

### Mantener el cache de `_ReplayBalanceStream` vivo (rechazar RF-010/RF-011)

Al releer `mobile/lib/data/financial_state.dart` antes de implementar `onLastListenerCanceled`, encontré que el sprint v2 documentó la decisión opuesta en el docstring:

> "Por diseño NO se cierra al perder el último listener: el cache de FinancialStateService mantiene la entrada viva hasta una invalidación explícita."

Esa decisión fue consecuencia del bug "Skeleton eterno" del smoke del v2 (post-iteración #4). Implementar `onLastListenerCanceled` reintroduce el bug en ciertos escenarios (Dashboard se desmonta vía `context.go` + cancel emite con cero listeners + nuevo subscribe debe ver `_last` cacheado).

Decisión: **NO implementar RF-010/RF-011**. SÍ implementar **RF-012** como test defensivo que blinda la decisión del v2 con `expect(identical(s1, s2), isTrue)`. Si alguien en el futuro reintroduce el callback, el test falla con un mensaje que apunta a esta desviación.

Ver `desviaciones-plan.md` DV-1.

### Harness de widget tests

`AppDependencies.fromDatabase(database)` ya aceptaba inyección desde el M2 del quality review del v2. El harness lo usa directamente, sin constructor `forTesting` nuevo.

Patrón: `await pumpFincoreApp(tester, seed: (db, deps) async { ... })`. Bolsa singleton se siembra por default. `seedBolsa: false` permite testear el redirect a `/first-run`.

Cosas que descubrí durante implementación:

- **`initializeDateFormatting('es_MX')` debe correr antes del primer pump** o `entry_form_screen` crashea con `LocaleDataException` al formatear la fecha del field. El harness lo hace una vez por isolate.
- **`driftRuntimeOptions.dontWarnAboutMultipleDatabases = true`** silencia el WARNING de drift cuando cada test arma su propia BD in-memory. Es intencional, sin race real.
- **El router arranca en `/splash`** y hace redirect según `firstRunState.value`. El harness setea `firstRunState.value = seedBolsa` síncronamente antes del primer pump para que el redirect resuelva sin colgar.
- **`push` vs `go` en los tests del entry_form edit**: para que `Navigator.maybePop()` tenga a dónde volver y la regresión gray screen quede observable, el test hace `GoRouter.of(ctx).push('/entries/$id/edit')` en lugar de `router.go`. Sin push, `maybePop` se queda en la misma ruta y el bug del v2 hubiera pasado desapercibido en el test.

### Verify-apk.sh

Script bash con `set -euo pipefail`. Gotchas:

- **SIGPIPE de aapt2**: `aapt2 dump badging | head -n 1` reventaba exit 141 bajo `pipefail`. Solución: capturar la salida completa primero (`$("$AAPT2" dump badging ...)`) y procesarla con `sed -n '1p'` después.
- **Búsqueda de aapt2**: PATH → `$ANDROID_HOME/build-tools/*/aapt2` → `~/Android/Sdk/build-tools/*/aapt2`. Ordenado con `sort -V | tail -n 1` para agarrar la versión más alta.
- **Prefix arm64 hardcoded como `2000`**: Flutter `--split-per-abi` prepende 1000 a armeabi-v7a y 2000 a arm64-v8a. Si el script se usa para otra ABI, parametrizar. El default arm64 cubre el caso real del cel de Diego.

## Detalles de implementación (cosas no obvias)

### Por qué "Bolsa" aparece 2x en las pantallas

El `_AccountRow` en `dashboard_screen.dart` y `accounts_list_screen.dart` renderea:
- El **nombre** de la cuenta (`account.name`, que para la singleton es "Bolsa").
- El **label del tipo** (`_typeLabel('cash')`, que retorna "Bolsa" como nombre amigable de cash).

Ambos son intencionales (UX consistente). Los tests usan `findsNWidgets(2)`. Documentado en `pendientes.md` para considerar refactor cosmético futuro.

### Por qué los tests del KindPicker tocan el `InkWell` y no el `Text`

`KindPicker` renderea cada kind como un `Material` > `InkWell` > `Container` > `Row(Icon, Column(Text(label), Text(description)))`. El `onTap` está en el `InkWell`. Tocar directamente el `Text` puede no funcionar si Flutter envía el hit-test al ancestro que tiene gesture handler.

Solución: `find.ancestor(of: find.text(label), matching: find.byType(InkWell))`. Y `tester.tap(card.first)` porque `findsWidgets` puede traer múltiples InkWell anidados.

### Por qué los list tests verifican "Comida" y no "Sueldo"

`CategoriesDao.watchActive()` ordena por `name` ASC. Las 10 categorías default del seed alfabéticamente: Comida, Entretenimiento, Freelance, Hogar, Otros gastos, Otros ingresos, Salud, Servicios, Sueldo, Transporte.

`ListView.separated` hace lazy rendering. Con viewport default de 600 px de alto y rows de ~60 px, "Sueldo" en posición 9 (~540 px desde el top) puede no estar montada. `find.text('Sueldo')` retorna 0 widgets aunque la categoría sí esté en la BD.

Los tests verifican las del top alfabético, que sí están garantizadas en el tree sin scroll.

### Por qué `find.byType(Scaffold)` y no `find.text('FinCore')`

El wordmark del AppBar usa `RichText` con `TextSpan(text: 'Fin')` + `TextSpan(text: 'Core')`. `find.text` solo encuentra `Text` widgets simples, no `RichText`. Cuando se busca un context para hacer `GoRouter.of(ctx).push(...)`, `find.byType(Scaffold)` resuelve sin ambigüedad.

## Limpieza oportunista

Durante la Fase 6, `flutter analyze` reportó un warning preexistente: `unused_import` en `lib/data/database.dart:5:8`. Era residuo del v2 (cuando `EntriesDao` salió del `@DriftDatabase(daos: [...])`, el import no se removió). Se limpió. Ahora `flutter analyze` queda sin warnings; solo los 4 hints info cosméticos preexistentes.

## Trazabilidad

Los archivos del sprint:

```
engineering/specs/flutter-local-hardening-v3/
├── spec.md                  # spec original
├── plan/
│   ├── plan.md             # plan por fases
│   ├── tasks.md            # detalle por task
│   └── test-plan.md        # matriz de cobertura
└── implementation/
    ├── progreso.md         # detalle de implementación por fase
    ├── pendientes.md       # backlog post-sprint
    ├── pruebas.md          # resultado final + matriz de tests
    ├── desviaciones-plan.md # 6 desviaciones documentadas
    ├── resumen-ejecutivo.md
    └── resumen-extenso.md   # este archivo
```

Código tocado en el sprint:

```
mobile/
├── pubspec.yaml                                # bump 0.3.7+39
├── android/app/build.gradle.kts                # versionCode 39
├── lib/data/database.dart                      # limpieza unused_import
├── test/
│   ├── data/financial_state_test.dart          # +1 test RF-012 v3
│   ├── helpers/
│   │   ├── widget_test_harness.dart            # nuevo (RF-001, RF-002)
│   │   └── widget_test_harness_test.dart       # nuevo (3 tests)
│   └── screens/                                 # nuevo directorio
│       ├── entry_form_screen_test.dart         # 2 tests (RF-003)
│       ├── dashboard_screen_test.dart          # 2 tests (RF-005)
│       ├── entry_form_kinds_test.dart          # 5 tests (RF-006)
│       └── list_screens_test.dart              # 4 tests (RF-007)
scripts/
└── verify-apk.sh                                # nuevo (RF-008, RF-009)
```

No se tocó:

- `lib/data/financial_state.dart` (DV-1 — preservar decisión v2)
- `lib/data/daos/`
- `lib/screens/` (excepto bump implícito)
- `lib/widgets/`
- `lib/router/`

## Validación final

```
flutter test      → 110/110 verdes (de 93 iniciales)
flutter analyze   → 0 errores, 0 warnings, 4 hints info preexistentes
flutter build apk --release --split-per-abi → 3 APKs generados
scripts/verify-apk.sh app-arm64-v8a-release.apk → exit 0, versionCode=2039
```

## Próximo sprint sugerido

**Reportes** (cashflow mensual, gasto por categoría, top categorías por monto). Pregunta abierta a definir en la spec siguiente: ¿el `FinancialStateService` debería soportar cortes por fecha o agregamos un nuevo `ReportsService` que tome un rango `(from, to)` y haga queries específicas? La decisión impacta la arquitectura de la capa de datos.

Sugerencia: arrancar con un `ReportsService` separado y dejar `FinancialStateService` intocado. Es más mantenible y no obliga a parametrizar todas las queries existentes con filtros de fecha.

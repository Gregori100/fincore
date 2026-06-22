# Branch quality review — flutter-local-hardening-v3

**Fecha:** 2026-06-22 12:33
**Rama:** main (working tree con cambios uncommitted del sprint v3)
**Base de comparación:** HEAD = `43b2c0e` (commit final del v2)
**Slug:** flutter-local-hardening-v3
**Revisores:** 4 subagentes en paralelo (3 Sonnet + 1 Haiku)
- Lane 1 (tests y regresión) — Sonnet
- Lane 2 (cache de streams + decisión DV-1) — Sonnet
- Lane 3 (script bash `verify-apk.sh`) — Sonnet
- Lane 4 (docs y trazabilidad) — Haiku

## Resumen ejecutivo

- **Hallazgos totales:** 18 (0 bloqueantes, 6 Media, 12 Baja).
- **DV-1 validada como correcta** (no implementar `onLastListenerCanceled`).
- **RF-012 v3 valida correctamente la decisión.**
- **Documentación 90 % consistente.** Ajustes menores en CLAUDE.md (números obsoletos de tests).
- **Aplicables in-sprint (cheap & high-value):** 7 (3 script + 1 cache + 2 docs + 1 test).
- **A diferir como pendientes futuros:** 11.

Sin bloqueantes para commit + push del v3.

## Hallazgos por lane

### Lane 1 — Tests y regresión

| ID | Sev | Path:línea | Descripción |
|----|-----|-----------|-------------|
| L1-H1 | Media | `widget_test_harness.dart:14` | `_localeInitialized` global no es concurrency-safe entre tests dentro del mismo isolate. Riesgo solo teórico bajo el scheduler actual. |
| L1-H2 | Media | `widget_test_harness.dart:104-112` | Rama `/first-run` + `seedBolsa=true` produce race de redirect ambigua. Hoy ningún test la ejercita. |
| L1-H3 | Media | `entry_form_kinds_test.dart` | Los 5 tests por kind verifican labels textuales (RF-006 cumplido a nivel UI) pero NO validan el contenido del Dropdown del `AccountPicker`. Gap real: si alguien rompe `allowedTypes` y deja Visa visible en un Ingreso, el test no lo detecta. |
| L1-H4 | Baja | `entry_form_screen_test.dart:95` | `find.widgetWithText(TextFormField, '150.0')` depende de la representación textual del monto. Si `AmountFormatter` cambia el formato, el test falla por el matcher, no por el comportamiento. |
| L1-H5 | Baja | `widget_test_harness.dart:125` | `final dynamic router` desactiva análisis estático del campo. Si `routerConfig` cambia signature en go_router, el error queda en runtime de test. |
| L1-H6 | Baja | `financial_state_test.dart` (varios) | Patrón `listen + Future.delayed + expect` es no determinista. Heredado del v2, no introducido por v3. |
| L1-H7 | Baja | `widget_test_harness.dart:29` | `dispose()` solo cierra DB; no fuerza desmontaje del tree. Si un test falla, el cleanup queda frágil. |

**Validaciones positivas:**
- El test del RF-003 sí blinda la regresión del gray screen (validado por inspección estática del flow `PopScope` → `_buildForm` con `_kind!`).
- RF-012 v3 blinda correctamente la decisión del v2.
- DV-5 (lazy rendering) y DV-6 (`dontWarnAboutMultipleDatabases`) bien documentadas.

### Lane 2 — Cache de streams + DV-1

| ID | Sev | Path:línea | Descripción |
|----|-----|-----------|-------------|
| L2-H1 | Media | `financial_state.dart:112-167` | `watchBo()`, `watchDe()` y `watchCr()` NO usan `_ReplayBalanceStream`. **Mismo bug latente "Skeleton eterno" aplica a las 3 cards superiores del Dashboard** si el stack se resetea con `context.go('/dashboard')`. El v3 corrige solo `watchAccountBalance` pero deja las cards expuestas. |
| L2-H2 | Baja | `financial_state_test.dart:388-391` | El RF-012 v3 usa `Duration(milliseconds: 50)` mientras el resto del archivo usa 100 ms. Riesgo de flake en CI lento. |
| L2-H3 | Baja | `financial_state.dart:229-232` | El forward de `addSync` sobre `_listeners.toList()` no chequea `hasListener`. Bajo race con cierre externo del controller, podría tirar `Bad state`. Riesgo teórico. |
| L2-H4 | Baja | `financial_state.dart:70-77` | `invalidateAccount` asume que `account.type` es inmutable post-creación (la key del cache lo incluye). Esto se cumple hoy pero no está documentado como precondición. |

**Validación de DV-1:** **Correcta.** El razonamiento es sólido: reintroducir `onLastListenerCanceled` reintroduciría el Skeleton eterno bajo `context.go`. Costo del cache vivo es trivial (5-10 streams idle por instalación normal). `invalidateAccount` se llama en `archive` → no hay leak para cuentas archivadas.

**Validación de RF-012:** **Correcta.** `expect(identical(s1, s2), isTrue)` captura exactamente la invariante. Si alguien reintroduce `onLastListenerCanceled`, el test falla con `reason:` explícito que apunta a DV-1.

### Lane 3 — Script `verify-apk.sh`

| ID | Sev | Path:línea | Descripción |
|----|-----|-----------|-------------|
| L3-H1 | Media | `verify-apk.sh:62` | `$((ABI_PREFIX + PUBSPEC_CODE))` muere con `arithmetic syntax error` cripto si `+N` no es numérico (ej. `version: 0.3.7+beta`). |
| L3-H2 | Media | `verify-apk.sh:69-71` | `ls -d "$ANDROID_HOME"/build-tools/*/aapt2` no maneja paths con espacios (ej. macOS `~/Users/Nombre Con Espacios/...`). Linux típico OK. |
| L3-H3 | Media | `verify-apk.sh:85-86` | Asume `versionCode` en línea 1 del `aapt2 dump badging`. Si versión futura mueve la línea `package:`, el script falla silencioso sin diagnóstico claro. |
| L3-H4 | Baja | `verify-apk.sh:48` | Parseo de `version:` no quita comillas si alguien escribe `version: '0.3.7+39'`. |
| L3-H5 | Baja | `verify-apk.sh:86` | Regex asume comillas simples (`versionCode='X'`). Versiones de aapt2 pre-30 emitían dobles. |
| L3-H6 | Baja | `verify-apk.sh:29, 33` | `ABI_PREFIX=2000` hardcoded. Si Diego prueba con armeabi-v7a (prefix 1000) o x86_64 (3000), reporta mismatch sin explicar por qué. |
| L3-H7 | Baja | `verify-apk.sh:84` | `aapt2 dump badging` con exit != 0 (APK corrupto) mata el script vía `set -e` sin mensaje útil. |

### Lane 4 — Documentación y trazabilidad

| ID | Sev | Path | Descripción |
|----|-----|------|-------------|
| L4-H1 | Baja | `CLAUDE.md:40` | Comentario `# 56 tests` en bloque de comandos quedó obsoleto. Hoy son 110. |
| L4-H2 | Baja | `CLAUDE.md:237` | Sección de tests menciona "56 tests verdes en 4 suites". Pre-v3. |
| L4-H3 | Media | `desviaciones-plan.md:DV-1` | DV-1 ocupa 50+ líneas con razonamiento técnico denso. Falta resumen 1-línea al inicio para lectura rápida. |
| L4-H4 | Baja | `test-plan.md` vs `pruebas.md` | Discrepancia menor en conteo de tests (15 vs 17). Causa: harness_test cuenta 3 tests pero el test-plan inicial decía 1. Aclarar. |

**Cumplimiento de criterios de aceptación de `spec.md`:** todos cumplidos. APK 0.3.7+39 validado por verify-apk.sh.

## Decisión: qué se aplica in-sprint vs qué se difiere

### Se aplican in-sprint (cheap & high-value)

| # | Hallazgo | Cambio | Lugar |
|---|----------|--------|-------|
| F1 | L2-H2 | Bumpear `Duration(milliseconds: 50)` → `100` | `financial_state_test.dart` |
| F2 | L3-H1 | Validar `+N` numérico antes de aritmética | `verify-apk.sh` |
| F3 | L3-H3 | Buscar `versionCode` en todo el output, no solo línea 1 | `verify-apk.sh` |
| F4 | L3-H6 | Parametrizar `ABI_PREFIX` por env var con default 2000 | `verify-apk.sh` |
| F5 | L3-H7 | Capturar exit no-zero de `aapt2` con mensaje claro | `verify-apk.sh` |
| F6 | L4-H1 + L4-H2 | Actualizar números de tests obsoletos | `CLAUDE.md` |
| F7 | L4-H3 | Agregar resumen 1-línea a DV-1 | `desviaciones-plan.md` |

### Se difiere a `pendientes.md` (no urgente)

| # | Hallazgo | Razón |
|---|----------|-------|
| D1 | L2-H1 — `watchBo/De/Cr` sin replay | Cambio de scope mayor: requeriría 3 `_ReplayBalanceStream` adicionales y tests. Sprint v3 ya validado; abrirlo por una mejora arquitectónica de medio tamaño rompe el cierre. Levantar como **sprint dedicado** o como primera tarea del sprint de reportes. |
| D2 | L1-H1 — locale no concurrency-safe | Riesgo solo teórico bajo scheduler actual de flutter_test. Si en el futuro se habilita multi-isolate paralelo, atacar. |
| D3 | L1-H2 — race de redirect `/first-run`+`seedBolsa=true` | Ningún test lo ejercita hoy. Bastará con un assert o doc cuando el caller real aparezca. |
| D4 | L1-H3 — gap de cobertura RN-011 en kinds | Gap real pero requiere `tester.tap` + dropdown open + verificación de items. ~30 min por kind. Agregar al backlog de widget tests. |
| D5 | L1-H4, L1-H5, L1-H6, L1-H7 | Robustez incremental. Atacar como `flutter-test-quality-v1` si la suite crece. |
| D6 | L2-H3 — `addSync` sobre controller cerrado | Teórico, sin reporte. |
| D7 | L2-H4 — documentar inmutabilidad de `type` | Comentario 1-línea; va junto con D1 si se ataca el cache de BO/DE/CR. |
| D8 | L3-H2 — paths con espacios | Linux desktop de Diego no aplica. macOS pendiente cuando exista. |
| D9 | L3-H4, L3-H5 | Edge cases improbables del parseo. |
| D10 | L4-H4 — discrepancia 15 vs 17 en docs | Cambiar el `test-plan.md` (el correcto es 17). Lo arreglo junto con F6. |

## Próximos pasos

1. Aplicar F1-F7 in-sprint.
2. Actualizar `pendientes.md` con D1-D10.
3. Re-correr suite (`flutter test`) + analyze.
4. Re-run `scripts/verify-apk.sh` para verificar que F2-F5 no rompen el camino feliz.
5. Commits lógicos + push.

## Limitaciones de esta revisión

- No se ejecutó la suite ni `flutter analyze` desde los subagentes (lectura estática). Verificación final pre-commit.
- No se examinó el código de `AccountsDao.archive` para confirmar todos los call paths de `invalidateAccount` (asumido correcto por documentación).
- Lane 3 no probó el script en macOS ni con `aapt2` antiguo (pre-30). Riesgo aceptable.
- No se invocó `git log` para detectar regresiones cross-sprint; el v3 está aislado al working tree.

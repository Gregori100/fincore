# Desviaciones de plan — flutter-local-hardening-v4

Las decisiones del v4 que difieren del plan original (`plan/plan.md`, `spec.md`).

## DV-1 — RF-019 (Fase 4): gap RN-011 en dropdowns diferido

**Resumen 1-línea:** ampliar los 5 tests del `entry_form_kinds_test.dart` para validar el contenido del DropdownMenu requiere un patrón de interacción más complejo del que es razonable cerrar in-sprint; se difiere a un sprint dedicado de UI testing depth.

**Qué decía el plan:** para cada kind, abrir el `DropdownMenu` del `AccountPicker`, validar que aparecen los items que cumplen `allowedTypes` (RN-011) y NO aparecen los excluidos.

**Qué se hizo:** implementación intentada en in-sprint, **revertida tras causar timeouts de 10+ minutos por test**. Los 5 tests del `entry_form_kinds_test.dart` quedan en su estado del v3 (verifican labels textuales del field, no contenido del Dropdown).

**Por qué se difirió:** el patrón naïve `tester.tap(find.text(fieldLabel))` no logra hit-test sobre el widget tappeable del `DropdownMenu` de Material 3. El `Text(label)` del field vive dentro del `InputDecorator` y `find.text` lo encuentra, pero el offset derivado no toca el área tappeable del field. El log muestra el warning del tester:

```
A call to tap() with finder "Found 1 widget with text "Cuenta destino": ..."
derived an Offset (Offset(143.5, 164.0)) that would not hit test on the specified widget.
```

Adicionalmente, cerrar el dropdown con `tap(find.text('Nuevo movimiento'))` (AppBar title) tampoco funciona limpio porque el dropdown overlay tapa el AppBar.

**Patrón correcto identificado:**
1. `find.byType(DropdownMenu<String>)` filtrado por field específico (con `find.ancestor`).
2. Tap en el ícono expand (`Icons.arrow_drop_down`) que vive dentro del field y SÍ tiene hit-test válido.
3. `tester.sendKeyEvent(LogicalKeyboardKey.escape)` para cerrar el dropdown.
4. Verificar items con `find.descendant(of: find.byType(MenuItemButton), matching: find.text(label))`.

Es mecánico (~30 min por kind × 5 + 2 dropdowns secundarios = ~3 h). Se difiere a sprint dedicado (probablemente `flutter-test-coverage-v1`).

**Cobertura actual aceptable:** los tests verifican que las labels de los fields son las correctas según el kind seleccionado. Eso es la primera línea de defensa contra rupturas del `KindPicker`. La capa siguiente (validar contenido del Dropdown filtrado por `allowedTypes`) queda como mejora aditiva, no como blindaje crítico.

## DV-2 — Fase 5 (RF-020 a RF-023) completa diferida

**Resumen 1-línea:** los 4 grupos de widget tests profundos del CRUD requieren más debugging de UI del que justifica el ROI dentro del v4; se difieren completos a un sprint dedicado.

**Qué decía el plan:** 4 archivos nuevos con ~12 tests totales:
- `account_form_screen_test.dart`: alta + edición + validaciones.
- `entries_list_screen_test.dart`: lista + bottom sheet de filtros.
- `category_form_screen_test.dart`: alta + preview live del badge.
- `settings_screen_test.dart`: confirmaciones destructivas.

**Qué se hizo:** intento de implementación del primer archivo (`account_form_screen_test.dart`) con 3 tests. Los 3 tests colgaron `pumpAndSettle` con timeouts de 10-12 minutos cada uno. Archivo borrado tras debugging insuficiente.

**Por qué se difirió:** después del fix del tearDown (`state.invalidateAll()` que arregló el cuelgue de los widget tests previos del v3), los CRUD tests del `account_form_screen` siguieron colgándose. Hipótesis (sin confirmar):

1. `enterText` en el field "Nombre" puede disparar el rebuild del form completo que entra en un loop con algún `setState` interno.
2. El `AccountTypePicker` interno tiene un `DropdownMenu` que requiere el mismo patrón complejo del RF-019.
3. Algún `addPostFrameCallback` del form queda pendiente y nunca completa.

El debugging adicional requeriría:
- Aislar cada paso (`pumpFincoreApp` solo, push solo, enterText solo, tap solo) midiendo timing.
- Comparar con el `entry_form_screen_test.dart` que sí funciona — entender qué hace diferente.
- Posiblemente refactorizar el `AccountFormScreen` o el `AccountTypePicker` para ser test-friendly (agregar Keys, simplificar didChangeDependencies).

Para v4 cierra-y-sube, **dropear la Fase 5 entera** es más limpio que entregarla parcial y rota. Las 4 áreas quedan documentadas en `pendientes.md` con el detalle suficiente para que un futuro sprint las recoja sin re-investigar.

**Cobertura actual aceptable:** los tests del MVP cubren bootstrap (render + tap → form de edición). Los flujos completos de alta/edición de los CRUD están cubiertos por los tests del data layer (`database_test.dart` tiene 30 tests del DAO, incluyendo todas las validaciones). El gap es la **integración UI → DAO**, que es lo que cubrirían los widget tests profundos.

## DV-3 — RF-010: simplificación del Completer al booleano original

**Qué decía el plan:** reemplazar `bool _localeInitialized` por `Completer<void>?` para serializar inicializaciones concurrentes en el mismo isolate (L1-H1 del quality review v3).

**Qué se hizo:** se implementó con Completer durante Fase 3. Cuando los widget tests empezaron a fallar con timeouts, se revertió a `bool _localeInitialized` simple. **El revert NO arregló el problema** (la causa raíz era el tearDown sin invalidateAll). Pero la simplicidad ganó: el Completer agrega complejidad para defender contra una race teórica que no aplica al scheduler actual de flutter test (es serial dentro del isolate).

**Por qué se simplificó:** el principio "no agregar defensa contra escenarios hipotéticos" gana. Si en el futuro Flutter habilita multi-isolate paralelo en el mismo proceso (no está hoy), reevaluar.

**Impacto:** L1-H1 queda como "documentado pero no implementado". El comentario en el código (`// Si en el futuro se habilita scheduler paralelo en el mismo isolate, reevaluar con un Completer<void> que serialice la carga.`) deja la pista.

## DV-4 — RF-014: hasListener guard descartado in-vivo

**Qué decía el plan:** agregar `if (!controller.hasListener) { _listeners.remove(controller); continue; }` antes del `addSync` en el forward de `_ReplayBalanceStream._ensureUpstream`. Defensa contra controllers cerrados externamente (L2-H3 del quality review v3).

**Qué se hizo:** implementado y revertido tras causar timeouts.

**Por qué se descartó:** `MultiStreamController.hasListener` retorna `false` transitivamente durante la inicialización del controller en `Stream.multi`. El handler `_handleListen(controller)` agrega el controller al `_listeners` set ANTES de que el listener subscribe se complete; entonces si el upstream emite en ese microtask intermedio, el guard skipea el addSync y el listener nunca recibe el evento → Skeleton eterno → pumpAndSettle se cuelga.

**Conclusión:** el L2-H3 era riesgo teórico sin reporte real. La protección queda diferida hasta que aparezca un caso reproducible. Documentado en el código con un comentario en `_ensureUpstream`.

## DV-5 — Hallazgo + falso fix corregido: NO invalidar en tearDown / dispose del harness

**Qué pasó (primera versión, errónea):** durante Fase 3, los widget tests empezaron a colgarse en `pumpAndSettle`. Diagnóstico inicial atribuido a streams del `_ReplayBalanceStream` quedando vivos cuando la BD se cerraba sin invalidar el cache. Fix aplicado: `state.invalidateAll()` antes de `db.close()` en tearDowns + dispose del harness.

**Por qué fue equivocado:** **el `state.invalidateAll()` en el `dispose()` del `FincoreTestHarness` era la causa del cuelgue, no la solución.** Reproducción: con el invalidateAll en dispose, **incluso un test individual del harness se cuelga** (no es interacción entre tests).

**Razón técnica:** cuando el harness dispose() llama `state.invalidateAll()`, el `_ReplayBalanceStream.dispose()` cierra los `MultiStreamController` activos. Pero los `StreamBuilder` del Dashboard (montado en el widget tree del test) AÚN tienen listeners activos a esos streams. Después el `database.close()` cancela el upstream de drift. La secuencia genera microtasks pendientes (`addSync` sobre controllers cerrados, exceptions capturadas internamente) que llenan el queue del isolate. El siguiente test (o el segundo `pumpAndSettle` del mismo test) queda esperando a que se procesen y nunca termina.

**Fix correcto:** quitar `state.invalidateAll()` de los tearDowns y del `dispose()` del harness. `database.close()` por sí solo es suficiente — drift cancela el customSelect upstream limpio y los streams completan.

**Validación:** suite pasa de >40 min (timeout) a **6-12 segundos** verde sin ningún `invalidateAll()` en cleanup.

**Decisión:** `invalidateAll()` queda como API runtime para `BackupService.wipeAll()` (donde el caller controla el ciclo de vida del widget tree). NO se usa como protocolo de cleanup en tests. Documentado en CLAUDE.md como contraconvención explícita para evitar que un futuro mantenedor lo "arregle" agregándolo de nuevo.

**Por qué se documenta como desviación:** el diagnóstico inicial fue incorrecto y costó horas de debug. Dejar el rastro completo de la equivocación + el fix correcto es valioso para no repetir el ciclo.

## DV-6 — Limpieza oportunista durante el refactor

**Qué pasó:** durante Fase 1, eliminar el `_state` del `EntriesDao` dejó variables locales sin uso en algunos tests (`state` en `backup_test.dart`, `stateService` en un grupo de `database_test.dart`). Se eliminaron las declaraciones unused para que `flutter analyze` quede limpio.

**Por qué se documenta:** cero riesgo (no hay lógica afectada), pero el diff es más grande de lo estrictamente necesario para el RF.

## DV-7 — Numerar las desviaciones en orden de impacto

A diferencia del v3 (donde DV-1 era la más estructural), en el v4 DV-1 y DV-2 marcan **scope diferido** (Fase 4 y Fase 5 completas), mientras DV-3 a DV-6 son **decisiones de implementación menores**. El sprint cierra con 19 de 25 RFs entregados; las 6 RFs restantes (RF-019, RF-020 a RF-023, parte de RF-014) van a un sprint dedicado.

# Desviaciones de plan — flutter-local-hardening-v3

Las decisiones del v3 que difieren del plan original (`plan/plan.md`, `spec.md`).

## DV-1 — RF-010 / RF-011: NO implementar `onLastListenerCanceled` en `_ReplayBalanceStream`

**Resumen 1-línea (L4-H3 quality review v3):** se mantiene el cache de streams vivo por diseño (decisión consciente del v2), porque liberarlo al perder el último listener reintroduciría el bug "Skeleton eterno" cuando el Dashboard se desmonta vía `context.go`. El RF-012 v3 blinda esta decisión con un test.

**Qué decía el plan:** agregar parámetro opcional `onLastListenerCanceled` al constructor de `_ReplayBalanceStream`. Cuando `_listeners` queda vacío: cancelar `_upstreamSub`, resetear `_last`, llamar callback. En `FinancialStateService.watchAccountBalance` pasarle un callback que ejecuta `_balanceCache.remove(cacheKey)`. Documentar el patrón en `CLAUDE.md`.

**Qué se hizo:** NO se implementó. El comportamiento actual (cache vivo hasta `invalidateAccount`/`invalidateAll` explícita) se preservó intacto.

**Por qué:** al releer el código actual antes de tocar, encontré que el sprint v2 ya documentó la decisión opuesta y razonada en el docstring del propio `_ReplayBalanceStream` (`mobile/lib/data/financial_state.dart`, líneas 185-194):

> "Ciclo de vida: ... Por diseño NO se cierra al perder el último listener: el cache de `FinancialStateService` mantiene la entrada viva hasta una invalidación explícita, así que reutilizar `watchAccountBalance(...)` después sigue retornando el último valor."

El v2 llegó a esa decisión tras el bug del "Skeleton eterno" detectado en smoke. El comportamiento "no liberar al perder listeners" es lo que **arregla** el bug. Si el v3 introduce `onLastListenerCanceled`, **reintroduce el bug**:

1. Dashboard suscribe `_BalanceLabel` por cada cuenta.
2. Usuario push a `entry_form_screen`. Los `_BalanceLabel` siguen vivos (no se desmontan).
3. Usuario hace pop. Sin tocar nada más, no hay problema.
4. Pero si Dashboard se desmonta (ej. `context.go('/dashboard')` en lugar de `pop`), los listeners cancelan.
5. Si en ese instante un evento upstream llega (drift emite), `_last` lo guarda.
6. Si `onLastListenerCanceled` está activo, `_upstreamSub.cancel()` + `_last = null` + `_balanceCache.remove(key)`.
7. La próxima vez que el Dashboard se monta y suscribe, **se arma un `_ReplayBalanceStream` nuevo desde cero**. El `_last` cacheado se perdió → Skeleton vuelve hasta que llegue otro evento de drift.

**Costo de mantenerlo como está (decisión actual):**
- 1 suscripción a drift por cuenta activa, viva por la vida del proceso. En una app local-first con 5-10 cuentas: trivial (~kB de memoria + 5-10 streams idle).
- Si se archiva una cuenta o se importa un respaldo: el `AccountsDao.archive(id)` y `BackupService.wipeAll()` ya llaman a `invalidateAccount`/`invalidateAll`, así que las entries archivadas SÍ se liberan correctamente.

**Lo que sí se entregó del RF-012:** un test defensivo nuevo (`RF-012 v3: subscribe → unsubscribe → resubscribe preserva el cache del stream`) que valida que:

1. `identical(s1, s2) == true` tras un ciclo subscribe → unsubscribe → resubscribe.
2. El listener resuscrito recibe inmediatamente el último valor por replay-1.

Si alguien en el futuro reintroduce `onLastListenerCanceled` sin leer el comentario, este test falla con un mensaje explícito apuntando a la decisión consciente del v2.

**Impacto en la trazabilidad:** RF-010 y RF-011 marcados como "no implementados" en `progreso.md`. RF-012 cumplido.

**Si en el futuro aparece el problema real que el RF-010 quería resolver** (un `Bad state: Cannot add new events after calling close` en runtime con un caller que hace subscribe agresivo), el path correcto es:
- Reproducir el escenario en un test.
- Decidir entre liberar el cache (rompiendo replay-1 para el caso normal) o agregar protección defensiva al `addSync` que ignore writes a controllers cerrados.
- Documentar la nueva decisión en `CLAUDE.md` y este archivo.

## DV-2 — T002 (constructor `AppDependencies.forTesting`) no fue necesario

**Qué decía el plan:** agregar `AppDependencies.forTesting({required AppDatabase database})` si no existe equivalente.

**Qué se hizo:** verificado al inicio de Fase 1 que `AppDependencies.fromDatabase(database)` ya acepta inyección directa desde el v2 (M2 del quality review del v2). El harness lo usa directamente. NO se agregó constructor nuevo.

**Por qué:** ya estaba. Cero churn.

## DV-3 — Limpieza oportunista de un import preexistente

**Qué pasó:** durante la Fase 6, `flutter analyze` reportó un warning `unused_import` en `lib/data/database.dart:5:8` (`package:fincore/data/daos/entries_dao.dart`).

**Qué se hizo:** se limpió el import. Es residuo del v2: cuando se sacó `EntriesDao` del `@DriftDatabase(daos: [...])` (porque su constructor requiere `FinancialStateService` y drift no sabe inyectarlo), el import dejó de ser necesario pero no se removió.

**Por qué se limpió:** lleva 0 riesgo (`EntriesDao` se importa donde se usa, vía `daos/entries_dao.dart` directamente desde otros archivos) y el sprint v3 ya estaba tocando ese archivo conceptualmente. Sin esto, el warning sigue en cada `flutter analyze` futuro y pierde valor de señal.

**Riesgo:** ninguno. La suite completa pasa después del cambio.

## DV-4 — `find.text('FinCore')` no resuelve por uso de `RichText`

**Qué pasó:** en el primer intento de obtener un `BuildContext` desde los list tests, usé `tester.element(find.text('FinCore').last)`. Falló con `Bad state: No element` porque el wordmark del AppBar usa `RichText` con TextSpans separados ("Fin" + "Core"), no un widget `Text("FinCore")` simple.

**Qué se hizo:** sustituido por `tester.element(find.byType(Scaffold))` que resuelve sin ambigüedad.

**Por qué se documenta:** convención del harness para sprints futuros. Si alguien quiere acceder al context del top widget de la app, **usar `Scaffold`** o agregar un `Key` específico, no buscar por texto del wordmark.

## DV-5 — Categorías "Sueldo"/"Transporte" no se renderean sin scroll en los widget tests

**Qué pasó:** intenté validar la presencia de "Sueldo" en `categories_list_screen_test.dart`. `find.text('Sueldo')` retornó 0 widgets aunque la BD tenía la categoría sembrada.

**Qué se hizo:** los tests verifican categorías que están al top de la lista alfabética del DAO (`orderBy(c.name)`): "Comida", "Entretenimiento", "Hogar".

**Por qué:** `ListView.separated` hace lazy rendering. Las categorías más allá del viewport (alfabéticamente: "Sueldo" en posición 9 de 10) NO se montan en el tree, así que `find.text` no las encuentra. Para validar la cola se necesita `scrollUntilVisible` o equivalente.

**Cobertura aceptable:** los tests del v3 buscan validar que el listado renderea + tap navega al form. Que "Comida" esté visible y "Sueldo" no es comportamiento esperado del lazy rendering. La regresión que importa (lista vacía cuando hay datos, tap no navega) sí queda cubierta.

## DV-6 — Warning de drift "multiple databases" silenciado vía `driftRuntimeOptions`

**Qué pasó:** cada widget test crea su propio `FincoreDatabase(NativeDatabase.memory())`. Drift detecta que hay múltiples instancias de la misma clase `Database` en el isolate y loguea un WARNING ("It looks like you've created the database class FincoreDatabase multiple times. ... race conditions will occur ...").

**Qué se hizo:** el harness setea `driftRuntimeOptions.dontWarnAboutMultipleDatabases = true` la primera vez que se llama. En tests es intencional (BDs independientes en memoria con executors distintos), no hay race real.

**Por qué se documenta:** el flag solo afecta el warning, no el comportamiento real. Está pensado para tests por el equipo de drift. Si en producción alguna vez aparece el warning, es señal de que main está construyendo `FincoreDatabase()` dos veces y debe corregirse en `main.dart`, no silenciarse globalmente.

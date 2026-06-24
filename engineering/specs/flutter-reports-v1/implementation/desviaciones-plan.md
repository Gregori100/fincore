# Desviaciones del plan — flutter-reports-v1

## Desviación-1: sin `fl_chart`, barras nativas con `Container`

**Plan**: T012 + RF-014 agregaban `fl_chart: ^0.69.0` al `pubspec.yaml`. El visual elegido era "Bar chart horizontal".

**Implementación**: NO se agregó `fl_chart`. Las barras horizontales se renderizan con `Stack` + `FractionallySizedBox` + `Container` coloreado nativo de Flutter.

**Razones**:

- El preview que Diego eligió (`████████████ Comida $4,200`) es visualmente idéntico a una barra horizontal `FractionallySizedBox` con `widthFactor = bucket.total / maxTotal`. `fl_chart` agregaba ~300KB al APK sin diferencia visible para este caso de uso.
- `fl_chart` 0.69.x renderiza `BarChart` vertical por default. Para horizontal hay que rotar con `RotatedBox` (labels quedan rotados, requiere ajustes) o renderizar manualmente. La complejidad adicional no compensa.
- Eliminar la dep nueva mantiene la política RF-018 (deps `^` flotantes con riesgo de breaking en `pub upgrade`) sin sumar superficie nueva.
- Sin animaciones internas perpetuas del chart que puedan colgar `pumpAndSettle` en widget tests.

**Impacto**:

- R-01 del spec (`fl_chart` agrega ~300KB) **anulado**: el APK arm64 quedó en **19.6MB** (vs ~20MB esperado).
- RT-04 del plan (forzar `BarTouchData(enabled: false)` para tests) **anulado**: no hay BarChart.
- Sin cambios en pubspec.yaml de deps (sólo bump de versión).

**Reversible**: si Diego en el futuro quiere chart visual avanzado (pie chart, donut, sparklines), agregar `fl_chart` aparte como sprint propio.

## Desviación-2: `schemaVersion = 2` no `1`

**Plan**: el `spec.md` (S-06) y `plan.md` ("Cambios de datos") asumían `schemaVersion = 1` y "sin schema bump".

**Realidad detectada al implementar**: `database.dart:107` ya tiene `schemaVersion = 2` (bumpeado por el sprint `flutter-local-hardening` en RF-011 para el índice parcial `idx_entries_occurred_active`).

**Implementación**: **Sin cambios al schema**. El sprint mantiene `schemaVersion = 2` y NO bumpea a 3. El spec quedaba desfasado del estado del repo al momento de redactarlo. No impacta el resultado: la implementación correcta es "aditivo puro sin schema bump", solo cambia el número de partida.

**Impacto**:

- Documentación corregida sólo acá (no se edita `spec.md` ni `plan.md` siguiendo la regla del skill).
- El próximo sprint que necesite bump deberá ir de `2` a `3` y agregar la rama `if (from == 2 && to == 3)` en `MigrationStrategy.onUpgrade`.

## Desviación-3: tests del DatePicker diferidos (T027 + T028)

**Plan**: T027 valida "cambio de fecha repega query" y T028 valida "SnackBar warning con rango inválido".

**Implementación**: ambos se difirieron como pendientes.

**Razón técnica**: validar interacción con `showDatePicker` en widget test requiere abrir el modal, navegar al mes/año, tappear día, cerrar. Material 3 DatePicker tiene animaciones internas que colgaron `pumpAndSettle` en pruebas exploratorias. El mismo patrón de cuelgue que documentamos para `Skeleton` y `CircularProgressIndicator` (animaciones perpetuas) aplica a varias etapas internas del DatePicker.

**Cobertura compensatoria**:

- La lógica del filtro de rango está validada en los UT-11 a UT-17 del `reports_test.dart` (límites inclusivos, fuera de rango, soft-delete, etc.).
- El SnackBar warning se valida manualmente con SM-04 (cambiar Desde a una fecha posterior a Hasta).

**Re-activación**: si se identifica un patrón confiable para testear DatePicker (ej. mockear `showDatePicker` con `MaterialPageRoute` custom), se atacan en un sprint dedicado de UI testing depth.

## Desviación-4: `initialRoute: '/reports'` del harness cuelga `pumpAndSettle`

**Plan**: los tests usarían `pumpFincoreApp(tester, initialRoute: '/reports')` del harness existente.

**Realidad detectada**: el harness hace `router.go(initialRoute)` que reemplaza el stack. Tras el `go`, el `pumpAndSettle` siguiente no asienta — el flutter_tester quedó colgado por más de 3 minutos en pruebas exploratorias.

**Implementación**: refactorizar los tests para `context.push('/reports')` desde el Dashboard. El patrón push (apilando en el stack) asienta normal. Es el mismo patrón usado por todos los otros widget tests del proyecto (entry_form, accounts, categories).

**Helper introducido**: `Future<void> pushReports(WidgetTester tester)` privado en `reports_screen_test.dart` que encapsula el patrón.

**Generalizable**: si futuros sprints suman pantallas nuevas accesibles desde el Dashboard, usar el mismo patrón push. No usar `initialRoute` del harness para esas pantallas.

## Desviación-5: SkeletonCard y CircularProgressIndicator colgaban `pumpAndSettle`

**Plan**: RF-010 + DT-01 documentaban usar `SkeletonCard` durante el loading state del `FutureBuilder`/`StreamBuilder`.

**Realidad detectada**: `Skeleton` interno tiene `AnimationController.repeat()` perpetuo. `pumpAndSettle` espera que TODAS las animaciones terminen — con un controller que nunca termina, queda colgado. El Dashboard pasaba tests porque sus streams (BO/DE/CR replay-1) emitían rápido y reemplazaban el Skeleton antes del timeout interno. En `/reports` el Stream tardaba más en emitir el primer valor, dejando el Skeleton vivo.

**Implementación**: el loading state usa `SizedBox(height: 1)` (cero animación) en lugar de `SkeletonCard`. Trade-off: UX de loading menos rica, pero la query es tan rápida (BD in-memory + LEFT JOIN + GROUP BY de 1 fila) que el usuario raramente la ve.

**Alternativas evaluadas y descartadas**:

- `CircularProgressIndicator`: también tiene animación perpetua, igual de problemático.
- `FutureBuilder` con `Future<SpendingReport>` armado desde `stream.first`: pierde la reactividad ante cambios en `journal_entries` mientras la pantalla está abierta.
- Stream con replay-1 a la `_ReplayBalanceStream`: complejidad alta sin valor proporcional para una pantalla read-only.

**Mejora futura**: si Diego nota que el loading state es feo, agregar un `BaseCard` con texto estático "Cargando…" (sin animación). Mejor UX visual que `SizedBox(height: 1)`.

**Actualización post-quality-review v1 (M5)**: aplicado. `_LoadingState` con `BaseCard` + texto "Cargando…" reemplaza al `SizedBox(height: 1)`. Sin animación, sin colgar `pumpAndSettle`.

## Desviación-6: default del rango cambió a "mes calendario completo" (post-smoke)

**Plan original (RF-009 + CA-02 del spec)**: el default al abrir `/reports` era `from = primer día del mes corriente 00:00`, `to = hoy 23:59:59`. La intención declarada en S-04 del spec era *"refleje lo registrado hasta ahora, no proyecte vacío hacia adelante"*.

**Implementación real (versión 0.4.1+44)**: el default es `from = primer día del mes corriente`, `to = último día del mes corriente 23:59:59.999`. O sea: mes calendario completo.

**Razón del cambio**: feedback de Diego durante el smoke del 0.4.0+43. La frase "Este mes" → semánticamente debe abarcar todo el mes calendario, no un sub-rango "hasta hoy". Si Diego abre el reporte el 15 de junio y ve "1 jun → 15 jun" se siente extraño; el mes "está vivo" hasta el 30. El sub-rango "hasta hoy" se justificaba en el spec original para evitar proyección de vacío, pero con la UI nueva de chips (Desviación-7) eso ya queda comunicado por el chip seleccionado.

**Impacto**:
- CA-02 quedó desfasado del spec; debe corregirse en revisión futura o leerse junto con esta desviación.
- Para alcanzar el comportamiento del spec original ("hasta hoy"), el usuario hoy tiene que elegir Custom y setear el `to` manualmente. Caso de uso raro.

**Reversible**: si Diego cambia de opinión, en `lib/screens/reports/range_presets.dart` la rama `ReportRangePreset.thisMonth` puede volver a `to = DateTime.now()` end-of-day.

## Desviación-7: chips de presets reemplazan los OutlinedButton

**Plan original (RF-008 + CA-07 del spec)**: el header del reporte tenía dos `OutlinedButton.icon` ("Desde" / "Hasta") con label multilinea que abrían `showDatePicker` al tap. CA-07: *"Tappear 'Cambiar desde' abre DatePicker."*

**Implementación real (versión 0.4.1+44)**: `Wrap` con 4 `ChoiceChip` Material 3 (Este mes / Mes pasado / Año / Custom). Tap en un chip preset calcula el rango automáticamente. Solo cuando el chip activo es `Custom`, debajo aparecen dos `_DateFieldOutlined` (estilo M3 outlined input) que abren `showDatePicker` al tap. Debajo de los chips (en presets no-Custom) hay un texto sutil con el rango efectivo: "1 jun 2026 — 30 jun 2026".

**Razón del cambio**: feedback de Diego durante el smoke del 0.4.0+43. *"No me gusta tanto estos pills como se muestran de las fechas... literal parecen pills. No me agrada del todo."* La elección entre 3 alternativas (Banner inline / Input fields / Chips de presets) la cerró Diego eligiendo Chips. Además observó: *"el de 'Este mes' funciona como un limpiar de los 'Custom'"*, que era exactamente la mecánica intencionada (Este mes → reset al default).

**Impacto**:
- CA-07 quedó parcialmente desfasado: "tappear 'Cambiar desde' abre DatePicker" se cumple solo en modo Custom, vía el `_DateFieldOutlined` (no via OutlinedButton). La cobertura funcional se mantiene.
- El botón "Limpiar" mencionado por Diego después del smoke no fue necesario: tap en "Este mes" lo cumple en 1 tap.

**Cobertura test**: WT del `reports_screen_test.dart` agregó tests del render de 4 chips + transición a Custom mostrando los date pickers.

**Reversible**: revertir a OutlinedButton implica re-implementar el header. Decisión cerrada con Diego — no se anticipa reversión.

# Calendario mensual de movimientos

## Resumen

Nuevo 9no tab en `/reports` llamado "Calendario". Muestra un calendario mensual del proyecto, con marcadores de color por día para indicar la presencia y el tipo de movimientos ocurridos. Tap en un día abre `/entries` con filtro pre-cargado (rango custom de un solo día) y lista los movimientos correspondientes, reusando el patrón de drill-down de los otros tabs por categoría.

El objetivo operativo es responder rápido "¿qué gasté el día 12?" o "¿cuándo fue esa compra?" con contexto visual del mes. Sprint aditivo puro: sin schema bump, sin cambios en reportes existentes, sin filtros nuevos en `/entries`.

## Problema a resolver

Hoy la única vista temporal de movimientos es la lista lineal de `/entries`, filtrable por rango de fecha pero sin contexto visual del mes. Para responder "¿qué día compré X?" o "¿cuándo fue el ingreso?", Diego tiene que scrollear o abrir el sheet de filtros, tickear kinds, aplicar rango, etc.

Usar el patrón calendario de otras apps de finanzas (ej: Money Manager, Wallet) resuelve dos casos:

- Encontrar un movimiento específico por fecha con feedback visual de "hay algo ese día".
- Ver la distribución de actividad del mes de un vistazo (días densos vs vacíos).

## Objetivo

Entregar un tab de calendario mensual dentro de `/reports` que:

- Renderiza el mes actual con navegación mes anterior/siguiente.
- Marca cada día con hasta 3 puntos de color por tipo de movimiento agregado (verde ingreso, rojo gasto, azul movimiento interno).
- Al tapear un día, navega a `/entries` con filtro custom `from=to=día`, mostrando exactamente los movimientos del día.
- Es reactivo: registrar/cancelar/editar un movimiento re-renderiza el calendario sin refresh manual.

## Alcance

- Nuevo archivo `mobile/lib/screens/reports/movements_calendar_tab.dart` con el widget del tab.
- Nuevo método en `ReportsService` (`mobile/lib/data/reports.dart`) o helper local que agregue movimientos por día para un mes calendario. Retorna un `Map<DateTime, DayActivity>` reactivo.
- Modelo compacto `DayActivity` que codifique presencia por kind (bool income, bool expense/credit_expense, bool transfer/debt_payment) y opcionalmente el conteo por kind para tooltips futuros.
- Integración en `mobile/lib/screens/reports_screen.dart`: 8 → 9 tabs.
- Reuso de `EntriesFilters` con factory nueva o construcción inline: `datePreset: custom`, `from = día 00:00:00`, `to = día 23:59:59.999`, sin restricciones de kind ni cuenta.
- Onboarding slide 3: 9ª fila con ícono de calendario.
- Help/FAQ actualizado a "9 pestañas" con bullet del nuevo tab.
- Dependencia externa `table_calendar` (paquete estándar Flutter, ~50 KB, activo con >16k stars). Fijar versión exacta según changelog reciente. Alternativa custom queda descartada por costo vs beneficio.
- Tests: unitarios del servicio + widget tests del tab (render mes, marcadores, tap → deep link) + ajuste de regresión en `ReportsScreen` (7 → 8 → 9 tabs en el test WT-15 de `credit_cards_tab_test.dart`).

## Fuera de alcance

- **Heatmap de gastos**: viene como spec aparte (`flutter-reports-spending-heatmap-v1` o similar). El calendario deja preparado el patrón de agregación diaria que el heatmap puede reusar.
- Vista semanal o de agenda.
- Filtros por kind o por cuenta dentro del tab (v1 muestra todo agregado).
- Recurrencias / patrones (mensualidades detectadas).
- Exportar el calendario o compartir.
- Múltiples meses simultáneos (solo mes en foco a la vez).
- Detección de "días vacíos por hueco de datos vs. días sin actividad": si un día no tiene entries, se ve igual que cualquier día sin actividad (sin distinción visual).
- Localización / temas custom del `table_calendar` más allá del español y la paleta actual.

## Reglas de negocio

- **RN-CAL01 (marcadores por kind)**: cada día muestra hasta 3 marcadores según agregación:
  - Verde (`FincoreColors.positive`) si hay al menos 1 movimiento `kind='income'`.
  - Rojo (`FincoreColors.negative`) si hay al menos 1 movimiento `kind ∈ {expense, credit_expense}`.
  - Azul (`FincoreColors.accent`) si hay al menos 1 movimiento `kind ∈ {transfer, debt_payment}`.
  Un día puede tener 0, 1, 2 o 3 marcadores. El orden siempre es income → expense → interno para consistencia visual.
- **RN-CAL02 (soft delete)**: los movimientos con `deleted_at IS NOT NULL` no cuentan para los marcadores del día.
- **RN-CAL03 (fecha del movimiento)**: la clasificación por día usa `journal_entries.occurred_at` truncado a la fecha local del cel (año-mes-día). Zonas horarias: se preserva el default del proyecto (fecha local).
- **RN-CAL04 (día tapeable)**: tap en cualquier día del calendario (con o sin marcadores) navega al drill-down. Si no hay movimientos, `/entries` se abre con la lista vacía y el filtro visible.
- **RN-CAL05 (rango del drill-down)**: el deep link usa `datePreset: custom`, `from = DateTime(y, m, d, 0, 0, 0)`, `to = DateTime(y, m, d, 23, 59, 59, 999)`. Sin filtro de kinds ni cuenta ni categoría. El sheet queda editable si Diego quiere refinar.
- **RN-CAL06 (día seleccionado default)**: al abrir el tab, el día seleccionado inicial es "hoy" si "hoy" cae dentro del mes en foco; sino, ninguno.
- **RN-CAL07 (navegación mes)**: al cambiar de mes con las flechas del header, no se pierde el filtro seleccionado; solo cambia el rango del calendario visible. La query de agregación se re-dispara con el nuevo rango.
- **RN-CAL08 (reactividad)**: registrar, cancelar o editar un movimiento re-emite el stream de agregación; los marcadores del día afectado cambian sin intervención del usuario.
- **RN-CAL09 (mes visible)**: el calendario muestra el mes calendario completo desde el primer al último día. Los días de "spillover" del mes anterior o siguiente que renderiza `table_calendar` por relleno visual se muestran atenuados y no tapean el drill-down del mes en foco (usan el default del paquete).
- **RN-CAL10 (rango de datos)**: el servicio consulta `journal_entries` con `occurred_at BETWEEN firstDayOfMonth AND lastDayOfMonth (23:59:59.999)`. Solo trae registros del mes en foco, no del año entero. Al cambiar de mes, se re-consulta.

## Requisitos funcionales

- RF-001: `ReportsService` expone `Stream<Map<DateTime, DayActivity>> movementsByDay({required DateTime monthAnchor})` donde la clave es la fecha (`DateTime(y, m, d)` con hora en 0) y `DayActivity` contiene 3 booleanos (`hasIncome`, `hasSpending`, `hasInternal`) + un conteo total del día (`totalCount`) para tooltips futuros.
- RF-002: el stream se declara con `readsFrom: {journalEntries}` para re-emit reactivo.
- RF-003: nuevo archivo `mobile/lib/screens/reports/movements_calendar_tab.dart` con `StatefulWidget` que renderiza `TableCalendar` de `table_calendar`, un empty state opcional para meses sin actividad, y un loading state estático (siguiendo el patrón M5 del quality review de reports).
- RF-004: el widget usa un `StreamBuilder<Map<DateTime, DayActivity>>` alimentado por RF-001.
- RF-005: el builder de marcadores del `TableCalendar` renderiza hasta 3 puntos de color según RN-CAL01. Diámetro sugerido: 4-6 px. Ubicación: debajo del número del día.
- RF-006: `onDaySelected` del `TableCalendar` invoca `context.push('/entries?filter=<json>')` con `EntriesFilters` construido según RN-CAL05.
- RF-007: `ReportsScreen` cambia `length: 8` → `length: 9`; agrega `Tab(text: 'Calendario')` y `MovementsCalendarTab()` al final del `TabBarView`.
- RF-008: `OnboardingScreen` slide 3 agrega la 9ª fila con `Icons.calendar_month` (o similar) + label "Calendario" en color neutral. El párrafo se actualiza de "8 reportes" a "9 reportes".
- RF-009: `HelpScreen` FAQ tile actualiza el prefijo a "9 pestañas" y agrega un bullet nuevo describiendo el calendario.
- RF-010: `mobile/pubspec.yaml` agrega `table_calendar` con versión fija tras revisar el changelog reciente (evitar `^` flotante para minimizar riesgo — RN-018 del CLAUDE.md). Ejecutar `flutter pub get` antes del análisis.
- RF-011: tests unitarios del servicio `movementsByDay` cubriendo: mes sin entries, 1 día con income, 1 día con expense, 1 día con transfer, día con los 3 kinds mezclados, entries de meses distintos filtrados por rango, cancelación reactiva, categoría archivada (irrelevante para agregación), cruce mes anterior/siguiente.
- RF-012: widget tests del tab: render inicial con mes actual, marcadores presentes tras seed, tap en un día dispara navegación con filtros correctos, cambio de mes actualiza los marcadores.
- RF-013: regresión en `credit_cards_tab_test.dart` (o el archivo que tenga el conteo de tabs): actualizar el número de `findsNWidgets(N)` de 8 a 9.
- RF-014: `flutter analyze` limpio y `flutter test` verde con al menos 8 tests nuevos (7 UT servicio + 1 widget test consolidado o desglosado).

## Casos principales

1. Diego abre `/reports` → tab "Calendario" → ve el mes actual con marcadores en los días donde registró movimientos.
2. Diego tapea el día 15 (que tuvo 1 gasto en supermercado) → `/entries` se abre con filtro `from = to = 15`, la lista muestra ese gasto.
3. Diego navega al mes anterior con la flecha del header → el calendario re-carga los marcadores del mes previo.
4. Diego registra un income desde el FAB del `/entries` → vuelve al tab → el día correspondiente ahora tiene un marcador verde nuevo, sin refresh manual.
5. Diego tapea un día sin actividad → `/entries` abre con lista vacía y el filtro visible (patrón consistente con el resto de drill-downs).

## Casos borde

- Mes sin ningún movimiento: calendario se muestra vacío (sin marcadores). Empty state opcional dentro del tab (mensaje sutil "Sin movimientos este mes"). No bloquea navegación.
- Día con >100 movimientos: los 3 marcadores no cambian (booleanos). El drill-down muestra la lista completa (que la paginación de `/entries` ya maneja).
- Movimiento con `occurred_at` en el borde del día (23:59:59.999): cae en el día correcto por RN-CAL03.
- Movimiento con `occurred_at` cercano al cambio de horario (DST): se usa la fecha local del cel; el default de Flutter maneja DST.
- Cambio de mes durante scroll: el `table_calendar` no scrollea sino que navega con las flechas; no hay riesgo.
- Categoría archivada: irrelevante para la agregación (no se joinea `categories`).
- Movimiento cancelado (soft delete): no cuenta para el marcador (RN-CAL02).
- BD con muchos años de historia: la query se limita al mes en foco (RN-CAL10), sin impacto de performance.
- Widget desmontado antes de que el stream emita el primer valor: usar `mounted` check estándar del `StreamBuilder`.
- Locale: el `table_calendar` acepta `Locale('es', 'MX')`. El widget debe recibirlo para mostrar nombres de días/mes en español neutro.
- Idioma con nombres largos (ej: "Septiembre"): el header del `TableCalendar` acomoda por default; validar en cel real.

## Criterios de aceptacion

- Ejecutar `flutter test` con al menos 8 tests nuevos verdes, incluyendo servicio + widget.
- `flutter analyze` en 0 errores nuevos (los 4 hints info pre-existentes se toleran).
- APK release compilado con la nueva versión (`0.16.0+82` o el siguiente disponible) y validado con `scripts/verify-apk.sh`.
- Smoke en cel real: abrir `/reports`, ver 9 tabs, navegar al último, ver el mes actual con marcadores correctos según los movimientos reales de Diego.
- Smoke drill-down: tapear un día con actividad → `/entries` lista los movimientos exactos de ese día.
- Smoke reactivo: registrar un nuevo movimiento desde el FAB → volver al tab → marcador nuevo visible sin recargar.
- Smoke navegación mes: tocar la flecha izquierda del calendario → cambia al mes anterior con marcadores nuevos.
- Regresión: el resto de tabs de `/reports` sigue funcionando (los tests widgets existentes de cada tab siguen verdes).

## Criterios medibles de exito

- 9no tab visible en `/reports` con label "Calendario" y sin overflow horizontal del `TabBar`.
- Delta `hoy tenía X movimientos → calendario muestra X marcadores correctos` en 0 casos observados en la BD real de Diego.
- Reactividad: al registrar un movimiento nuevo, el marcador aparece en < 1 segundo.
- `flutter test` total ≥ 482 tests verdes (474 baseline + 8 nuevos).
- Dependencia `table_calendar` no introduce warnings de deprecación en `flutter analyze`.
- APK release build < 2 MB adicionales por la dependencia.
- Onboarding slide 3 acomoda las 9 filas sin overflow (validar en cel chico).

## Riesgos

- **R1 — Dependencia externa nueva**: `table_calendar` no está en el proyecto hoy. Riesgo de romper `flutter pub get` o de introducir un warning de deprecación. Mitigación: fijar versión exacta, revisar changelog, testear en dev antes de commitear.
- **R2 — Compatibilidad con drift 2.31 y go_router 14**: el paquete es puramente presentacional, no debería tener conflicto, pero el sprint corre en Flutter 3.29 con SDK Dart ≥3.7.2. Validar que la versión elegida soporta.
- **R3 — Performance del stream si Diego tiene muchos años de datos**: la query se limita al mes en foco, pero un mes muy denso podría ralentizar el `re-emit` en cada cambio de `journal_entries`. Mitigación: el rango mensual acota bien; medir con el dataset real.
- **R4 — Visualización con >3 kinds mezclados en 1 día**: si un día tiene income + expense + transfer, se muestran 3 puntos alineados. Riesgo de que el diseño se vea saturado. Mitigación: puntos pequeños (4 px), alineados horizontalmente debajo del número.
- **R5 — Confusión con el heatmap futuro**: si el usuario espera intensidad por monto, los marcadores binarios pueden confundir. Mitigación: FAQ del Help explica "los marcadores indican presencia, no monto". El heatmap será una vista distinta.
- **R6 — Overflow del TabBar con 9 tabs**: hoy `isScrollable: true`; ya tiene 8, agregar 9 no debería overflowear pero validar en cel chico.
- **R7 — Onboarding slide 3 acomoda 9 filas**: desde el sprint budgets el slide usa `SingleChildScrollView + ConstrainedBox + IntrinsicHeight`, así que la 9ª fila debería entrar sin overflow. Validar smoke.
- **R8 — Cambio de mes muy rápido puede colapsar el stream**: si Diego navega prev/next rápido, hay riesgo de que se disparen múltiples queries. Mitigación: el `readsFrom` de drift ya cachea; no requiere debounce.

## Supuestos

- Diego prefiere marcadores de color por kind (income/expense/interno) sobre intensidad por monto o punto binario. El heatmap por monto viene después.
- El drill-down reusa `/entries?filter=...` con rango custom de un día; no se necesita un sheet inline dentro del tab.
- El tab NO filtra por kind ni por cuenta en v1; muestra todo agregado. Si Diego lo pide en smoke, se agrega en patch.
- El widget usa `Locale('es', 'MX')` para nombres de días/meses en español, consistente con el resto del proyecto (registro neutro tras el sprint de i18n).
- El día seleccionado default al abrir el tab es "hoy" si está en el mes en foco; sino, ninguno.
- La versión del `table_calendar` a fijar es la más reciente estable que soporte Flutter 3.29 / Dart 3.7.2. Se decide en la fase de planeación tras revisar el changelog (RF-018 del CLAUDE.md aplica).
- El sprint no requiere schema bump (los datos ya están; solo se agregan lecturas).

## Impacto esperado

- Nueva vista temporal que complementa las 8 vistas por categoría/mes existentes.
- Cierra el caso de uso "encontrar movimiento por fecha" con feedback visual y drill-down directo.
- Prepara la infraestructura de agregación diaria para el próximo sprint de heatmap.
- Cero impacto en datos existentes; feature aditiva pura.
- Ligero aumento de tamaño del APK (~50 KB por `table_calendar`).
- No cambia el flujo operativo actual (registrar/editar movimientos) ni los otros reportes.

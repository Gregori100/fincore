# Branch quality review — flutter-reports-movements-calendar-v1

**Fecha:** 2026-07-08
**Slug del sprint:** `flutter-reports-movements-calendar-v1`
**Rama:** `main` (cambios sin commit sobre HEAD `da970af`)
**Diff bajo revisión:** `git diff HEAD` (11 archivos: 5 código/tests + 4 docs + 2 versionado)

## Alcance

Sprint aditivo puro con dependencia externa nueva (`table_calendar 3.1.2`). Nuevo 9no tab "Calendario" en `/reports` con:

- Modelo `DayActivity` + método `ReportsService.movementsByDay({monthAnchor})` (SQL con `strftime('%Y-%m-%d', 'localtime')` para timezone-safe grouping).
- Factory `EntriesFilters.forDay({day})` para drill-down de un solo día.
- Widget `MovementsCalendarTab` con `TableCalendar` + marcadores por kind + navegación mes.
- 18 tests nuevos (12 UT servicio + 2 UT factory + 4 widget).

Se ejecutaron **3 agentes en paralelo** con asignación por criterio: 2 Haiku para verificaciones estructuradas (SQL correctness + cobertura de tests) y 1 Sonnet para el análisis con criterio (frontend + UX + dep externa).

## Hallazgos por severidad

### Media — `_ErrorState.Reintentar` es un botón muerto

**Archivo:** `mobile/lib/screens/reports/movements_calendar_tab.dart:265-271`

**Descripción:** El `TextButton` "Reintentar" tiene `onPressed: () {}` vacío. El comentario dice "el stream se recrea al reconstruir el widget si el error fue transitorio", pero como `_ErrorState` es `StatelessWidget` y no dispara `setState` en el padre, tapear no reconstruye nada: el `_stream` cacheado en `_MovementsCalendarTabState` sigue siendo el mismo Stream ya fallado.

**Impacto:** UX engañoso. El usuario tapea "Reintentar" ante un error y no pasa nada. La única recuperación real hoy es cambiar de mes (que sí recrea el stream vía `_onPageChanged`) o navegar fuera y volver.

**Recomendación:** Fix real y corto: pasar un `VoidCallback onRetry` desde el padre que ejecute `setState(() { _stream = _buildStream(); })`. Es el patrón que usa el resto de la app (ej: `income_by_category_tab.dart`).

---

### Baja — `firstDay`/`lastDay` deslizantes según `_focusedMonth`

**Archivo:** `mobile/lib/screens/reports/movements_calendar_tab.dart:107-108`

**Descripción:** `firstDay: DateTime(_focusedMonth.year - 10, 1, 1)` y `lastDay: DateTime(_focusedMonth.year + 10, 12, 31)` referencian `_focusedMonth` (que cambia con la navegación), no `DateTime.now()`. Al navegar hacia atrás, la ventana ±10 años se desplaza junto con él, produciendo un rango efectivamente infinito. El comentario "Fijado a ±10 años del mes actual" es engañoso.

**Impacto:** No es un bug funcional (permite navegar sin límite, que puede ser deseable), pero contradice la documentación. Un usuario podría llegar a años absurdos (1990, 2100).

**Recomendación:** Fijar `firstDay`/`lastDay` en `initState` a partir de `DateTime.now()` una única vez y referenciarlos como campos de instancia. Si el comportamiento actual (infinito) es intencional, corregir el comentario.

---

### Baja — Tap en "outside day" desincroniza `_focusedMonth` con `_selectedDay`

**Archivo:** `mobile/lib/screens/reports/movements_calendar_tab.dart:68-82`

**Descripción:** Con `outsideDaysVisible: true`, la grilla muestra días grises del mes previo/siguiente. Al tapear uno, `_onDaySelected` setea `_selectedDay` fuera de `_focusedMonth`, sin normalizar al mes activo ni disparar `_onPageChanged`. El `push` navega inmediatamente, pero al volver a la tab (persiste en `TabBarView`), el `selectedDayPredicate` marca un día "outside" con decoration sólido en la grilla del mes anterior/siguiente mientras el header sigue mostrando `_focusedMonth`.

**Impacto:** Rareza visual al volver a la tab. UX de baja frecuencia (requiere tapear outside day + volver). Es el mismo tipo de divergencia que R9 quiso prevenir.

**Recomendación:** En `_onDaySelected`, si `selectedDay.month != _focusedMonth.month`, actualizar `_focusedMonth = DateTime(selectedDay.year, selectedDay.month, 1)` y regenerar `_stream`.

---

### Baja — Docstring de `movementsByDay` desactualizado

**Archivo:** `mobile/lib/data/reports.dart:1199`

**Descripción:** El docstring dice "Agrupa por día vía `date(occurred_at)`" pero la implementación usa `strftime('%Y-%m-%d', occurred_at, 'localtime')`. El `'localtime'` es crítico para correctness de timezone (cubierto por UT-CAL07/CAL11).

**Recomendación:** Actualizar a "Agrupa por día vía `strftime('%Y-%m-%d', occurred_at, 'localtime')`" para precisión.

---

### Baja — Locale `es_MX` sin `localizationsDelegates` (preexistente)

**Archivo:** `mobile/lib/main.dart:67-72` (referenciado desde `movements_calendar_tab.dart:104`)

**Descripción:** `TableCalendar` recibe `locale: 'es_MX'` que consume `intl` (ya inicializado). Pero tooltips/semantics de widgets Material internos dependen de `GlobalMaterialLocalizations`, no del `intl`. El `MaterialApp.router` actual no declara `localizationsDelegates`, así que TalkBack anuncia en inglés ("Previous month", "Next month").

**Impacto:** Preexistente al sprint (no lo introduce). Impacto A11Y limitado en single-user donde Diego no usa TalkBack, pero registrable.

**Recomendación:** Fuera de scope estricto. Registrar como TD futuro de A11Y global. No accionar.

---

### Baja — WT-CAL03 verifica presencia de texto, no el rango del filter

**Archivo:** `mobile/test/screens/reports/movements_calendar_tab_test.dart:76-126`

**Descripción:** WT-CAL03 verifica el drill-down buscando `find.text('IncomeCAL')` en `/entries`, pero no verifica que `EntriesFilters` pasado tiene `from = to = día`. Desviación D2 documentada.

**Impacto:** UT-CAL14 cubre el roundtrip `forDay → toDeepLink → parse`. El resultado observable está cubierto. Aceptable.

**Recomendación:** Sin acción. La cobertura es suficiente entre UT-CAL14 (unitario) + SM-03 (smoke).

---

### Notas (no accionables)

- **`GROUP BY` con alias vs expresión completa** (`reports.dart:1232`): estilo cosmético. Consistente con otros métodos del ReportsService pero mixto.
- **Genérico `TableCalendar<DayActivity>` no utilizado**: `eventLoader` no se usa; el marker viene por closure. Aceptable, ya documentado inline.
- **Comentario `initState` sugiere condicional inexistente** (`movements_calendar_tab.dart:33-37`): `hoy siempre cae en el mes en foco al init`. Cosmético.
- **Algunos asserts UT sin `reason:`** (`reports_test.dart` UT-CAL03/CAL05): cosmético. UT-CAL04/CAL06 sí lo tienen.
- **Test-plan RT-01 dice `≥ 488` pero real es 492**: inconsistencia de redacción en el plan. No accionable (implementación es correcta con 18 tests).
- **`movements_calendar_tab.dart` untracked en git**: obvio, se resuelve con `git add` antes del commit.
- **Timezone handling asume config OK del dispositivo**: nota preventiva; el proyecto siempre asumió esto.

## Acciones sugeridas

- **A1 (Media, aplicar antes del commit — ~5 min)**: fix del botón "Reintentar" en `_ErrorState` con `VoidCallback onRetry` que dispara `setState(() { _stream = _buildStream(); })`.
- **A2 (Baja, aplicar antes del commit — ~3 min)**: fijar `firstDay`/`lastDay` una vez en `initState` a partir de `DateTime.now()`. Fix corto y consistente con el comentario declarado.
- **A3 (Baja, aplicar antes del commit — ~5 min)**: en `_onDaySelected`, sincronizar `_focusedMonth` cuando el día tapeado cae fuera del mes en foco.
- **A4 (Baja, aplicar antes del commit — ~1 min)**: actualizar docstring de `movementsByDay` a `strftime('%Y-%m-%d', 'localtime')`.
- **A5 (Baja, opcional futuro)**: agregar `flutter_localizations` + delegates. Sprint dedicado de A11Y.

## Riesgos residuales

- **Cero cambios en otros tabs, Dashboard, /entries, forms**: sin riesgo de regresión.
- **Timezone-safe grouping cubierto por UT-CAL07/CAL11**: robusto.
- **Reactividad cubierta por UT-CAL12 con `emitsThrough`**: sin `Future.delayed` flaky.

## Pruebas ejecutadas por el sprint

- `flutter analyze` limpio (4 hints info pre-existentes tolerados).
- `flutter test` → **492/492 verdes** (474 baseline + 18 nuevos).
- Build APK release `--split-per-abi` OK; `verify-apk.sh` OK con versionCode 2082 / versionName 0.16.0.
- Smokes SM-01..07 confirmados por Diego en cel real ("Excelente! ya probé el calendario").

## Recomendación de merge

**Con acciones A1-A4 aplicadas (~15 min), apto para commit.** El único hallazgo Media es un bug UX real (botón muerto) que amerita el fix. Las 3 Bajas accionables (firstDay deslizante, outside-day tap, docstring) son fixes cortos que blindan el sprint. La 5ª Baja (A11Y global) queda como TD futuro.

## Pendientes sugeridos para sprints futuros

- **Sprint dedicado de A11Y**: agregar `flutter_localizations` global (afecta más allá del calendario).
- **Refactor de tabs con selector de mes**: 4 tabs ya tienen mecanismos propios de navegación mensual. Extraer un `MonthSelector` común. Prioridad baja.
- **Heatmap de gastos** (siguiente feature del backlog): puede reusar `movementsByDay` extendiéndolo con `totalAmount` por kind.

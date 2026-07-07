# Plan técnico — flutter-reports-movements-calendar-v1

## Enfoque tecnico

Sprint aditivo puro con una dependencia externa nueva (`table_calendar`). Cinco cambios ortogonales:

1. **Modelo `DayActivity`** en `mobile/lib/data/reports.dart`: constructor con 3 bools (`hasIncome`, `hasSpending`, `hasInternal`) + `totalCount`. Compacto porque puede ir en un `Map<DateTime, DayActivity>` de 31 entradas por mes; sin `equatable` custom (dos instancias con mismos bools son iguales por semántica del reporte).

2. **`ReportsService.movementsByDay({required DateTime monthAnchor})`** en `mobile/lib/data/reports.dart`. Query SQL con `GROUP BY date(occurred_at), kind` acotada al rango `[firstDayOfMonth, lastDayOfMonth 23:59:59.999]`. `readsFrom: {journalEntries}` para reactividad. El caller pasa el mes como `DateTime` (día 1 del mes) y el servicio normaliza. Retorna `Stream<Map<DateTime, DayActivity>>` con las fechas del mes como claves normalizadas a `DateTime(y, m, d)`.

3. **`EntriesFilters.forDay({required DateTime day})`** en `mobile/lib/data/entries_filters.dart`. Factory que arma `datePreset: custom`, `from = DateTime(y, m, d, 0, 0, 0)`, `to = DateTime(y, m, d, 23, 59, 59, 999)`. Sin restricciones de kind/cuenta/categoría. Simétrica a `forCategoryBucket` y `forIncomeBucket` para consistencia del patrón de drill-down.

4. **`MovementsCalendarTab`** en `mobile/lib/screens/reports/movements_calendar_tab.dart` (~250 líneas estimadas). StatefulWidget con:
   - `DateTime _focusedMonth` inicializado en el primer día del mes actual.
   - `DateTime? _selectedDay` inicializado en `DateTime.now()` si cae en el mes actual, sino `null` (RN-CAL06).
   - Stream de agregación diaria recreado al cambiar `_focusedMonth` (patrón de recreación por filtro, ya usado en los otros tabs).
   - Widget principal: `Column` con `TableCalendar` arriba + `Card` con resumen del día seleccionado (opcional en v1, decidir en implementación si aporta o inflara).
   - `calendarBuilders.markerBuilder`: renderiza hasta 3 puntos de 5 px según `DayActivity`, alineados horizontalmente debajo del número del día.
   - `onDaySelected`: `setState(_selectedDay = day)` + `context.push(EntriesFilters.forDay(day: day).toDeepLink())`.
   - `onPageChanged`: `setState(_focusedMonth = firstDayOf(newFocusedMonth))`.
   - Locale `Locale('es', 'MX')`.

5. **Integración**: `mobile/lib/screens/reports_screen.dart` sube de 8 a 9 tabs (label "Calendario" al final, `MovementsCalendarTab()` en el `TabBarView`). Onboarding slide 3 agrega 9ª fila. Help/FAQ actualiza el prefacio y agrega un bullet.

Dependencia externa: se agrega `table_calendar` con versión exacta (no `^`) al `pubspec.yaml`, tras revisar el changelog reciente para confirmar compatibilidad con Flutter 3.29 / Dart ≥3.7.2 y con drift 2.31 / go_router 14 (paquete puramente presentacional; sin conflicto esperado, verificar). RF-018 del `CLAUDE.md` aplica: preferir versión pineada para releases estables. Bump del proyecto a `0.16.0+82` (minor por feature nueva con dep externa).

## Requisitos funcionales cubiertos

- **RF-001** (`movementsByDay` stream): T003 — método del servicio.
- **RF-002** (`readsFrom: {journalEntries}`): T003 — declaración de reactividad.
- **RF-003** (widget `MovementsCalendarTab` con estados render/empty/loading): T005 — implementación del tab.
- **RF-004** (`StreamBuilder<Map>` alimentado por RF-001): T005 — cuerpo del build.
- **RF-005** (`markerBuilder` con 3 puntos por kind): T005 — sub-builder.
- **RF-006** (`onDaySelected` → deep link): T005 + T004 — usa el factory.
- **RF-007** (9no tab en `ReportsScreen`): T006.
- **RF-008** (onboarding slide 3 con 9ª fila): T007.
- **RF-009** (FAQ Help con "9 pestañas" + bullet): T008.
- **RF-010** (`pubspec.yaml` con `table_calendar` fijado): T001.
- **RF-011** (UT servicio): T009 (9 tests cubiertos por test-plan.md).
- **RF-012** (widget tests del tab): T011 (4 tests principales).
- **RF-013** (regresión `credit_cards_tab_test.dart` conteo 8→9): T012.
- **RF-014** (`flutter analyze` limpio + suite verde): T013 (correr suite completa post cambios).

## Archivos o modulos probablemente afectados

Confirmados por inspección previa del repo:

- `mobile/pubspec.yaml` — agrega `table_calendar` con versión exacta.
- `mobile/lib/data/reports.dart` — modelo `DayActivity` + método `movementsByDay`.
- `mobile/lib/data/entries_filters.dart` — factory `forDay`.
- `mobile/lib/screens/reports/movements_calendar_tab.dart` (nuevo).
- `mobile/lib/screens/reports_screen.dart` — 8 → 9 tabs.
- `mobile/lib/screens/onboarding_screen.dart` — 9ª fila slide 3 + "9 reportes".
- `mobile/lib/screens/help_screen.dart` — "9 pestañas" + bullet.
- `mobile/test/data/reports_test.dart` — grupo nuevo `movementsByDay`.
- `mobile/test/data/entries_filters_test.dart` — grupo nuevo `forDay`.
- `mobile/test/screens/reports/movements_calendar_tab_test.dart` (nuevo).
- `mobile/test/screens/reports/credit_cards_tab_test.dart` — WT-15 count 8 → 9.
- `mobile/android/app/build.gradle.kts` — bump `versionCode` y `versionName`.

Sin cambios en:

- Schema (`database.dart`, migraciones): sin bump.
- DAOs: sin nuevos métodos.
- CLAUDE.md: sin nueva convención (calendar es puro reporte, no cambia patrones del DAO).

## Entidades y estados afectados

- **JournalEntry**: solo lectura. Se consultan `id, kind, occurred_at, deleted_at`. Cero mutaciones desde el tab.
- **`DayActivity`** (nuevo, en memoria): estructura inmutable con 4 campos (`hasIncome`, `hasSpending`, `hasInternal`, `totalCount`). Vive solo dentro del stream del `ReportsService` y del `StreamBuilder` del tab.
- **Estado de UI del tab**:
  - `_focusedMonth` (invariante: siempre día 1 del mes, hora 0).
  - `_selectedDay` (invariante: si no-null, cae dentro del `_focusedMonth`).
  - Cambio de mes: recrea stream con nuevo rango.

## Compatibilidad con datos y procesos existentes

- **Datos históricos**: la query lee `journal_entries` sin filtro de rango histórico (más allá del rango del mes en foco). Compatible con cualquier BD existente.
- **Reportes vecinos**: `spendingByCategory`, `incomeByCategory`, `cashflowByMonth`, etc. no se tocan. Cero riesgo de regresión.
- **Drill-down**: reusa `EntriesFilters.parse` en `entries_list_screen.dart` (que ya interpreta el `datePreset: custom + from/to`). Sin cambios en el screen del drill-down.
- **`EntriesFilters` legacy**: el nuevo factory `forDay` es aditivo. `forCategoryBucket` y `forIncomeBucket` no se modifican.
- **Onboarding y Help**: cambios de texto puros. Tests existentes de esos screens siguen verdes (no verifican el número exacto de filas ni el texto completo del bullet).
- **Import/export de backup**: sin impacto (calendar es lectura pura, no toca formato).
- **Dependencia `table_calendar`**: paquete estable (>16k stars, activo). Sin conflicto esperado con drift/go_router (paquete puramente presentacional). Validar en T001 leyendo el changelog.

## Cambios de datos si aplica

No aplica. Sprint puramente de lectura; no se modifica schema ni contenido de tablas existentes.

## Cambios de API si aplica

No aplica. App local-first sin API expuesta.

## Cambios de integraciones si aplica

Integración externa nueva: `table_calendar`. Sin conexión a red ni backend. Solo widget presentacional.

## Cambios de UI si aplica

- Nuevo tab "Calendario" al final del TabBar de `/reports`.
- Onboarding slide 3: 9ª fila con `Icons.calendar_month` (o alternativa como `Icons.event`) en color neutral.
- Help FAQ: prefacio "9 pestañas" + bullet nuevo describiendo el calendario.
- Sin cambios en Dashboard, `/entries`, `/settings`, ni forms de cuenta/categoría/movimiento.

## Cambios de permisos si aplica

No aplica. App single-user.

## Riesgos tecnicos

- **R1 — Dependencia externa nueva**: `table_calendar` puede introducir warnings de deprecación en Dart 3.7.2 o incompatibilidad con Flutter 3.29. Mitigación: T001 revisa el changelog, fija versión exacta, corre `flutter pub get` + `flutter analyze` antes de continuar. Si falla, evaluar alternativa custom (más costoso, agrega tarea).
- **R2 — Locale es_MX en `table_calendar`**: el paquete usa `intl` para localizar; hay que asegurarse que `Locale('es', 'MX')` esté inicializado (probablemente lo está por `intl_util` que ya usan otros tabs). Verificar en el primer smoke que días/meses aparecen en español neutro.
- **R3 — Overflow del TabBar con 9 tabs en cel chico**: el `TabBar` tiene `isScrollable: true` desde varios sprints atrás; 9 tabs con label "Calendario" (10 chars) no debería overflowear el ancho útil. Validar smoke en cel real.
- **R4 — Performance de `movementsByDay`**: query mensual sobre `journal_entries` con `GROUP BY date(occurred_at), kind`. Con datasets típicos (<200 entries/mes) es sub-10 ms. Con datasets patológicos (>1000 entries/mes) sigue siendo aceptable en SQLite. Mitigar solo si Diego reporta lag real.
- **R5 — Marcadores en día con 3 kinds mezclados**: hasta 3 puntos de 5 px + espaciado horizontal caben en el ancho de la celda del `table_calendar`. Validar smoke; si se ve saturado, reducir a 4 px o alinear vertical.
- **R6 — Cambio rápido de mes con las flechas**: puede disparar múltiples streams. drift internamente cachea el resultado de la query anterior si aún no completó; no debería colapsar. Sin debounce en v1.
- **R7 — Confusión con el heatmap futuro**: el usuario puede esperar que el punto refleje monto. Mitigación: bullet del FAQ dice "los marcadores indican qué tipos de movimiento hubo, no el monto".
- **R8 — Duplicación de código con otros tabs por navegación mes**: no crítico. Cada tab tiene su propio manejo del rango (budgets, average, cashflow). Si en el futuro se decide extraer un `MonthSelector` común, es TD de otro sprint.
- **R9 — El día seleccionado inicial y el `TableCalendar` no sincronizados**: bug conocido de `TableCalendar` cuando `selectedDayPredicate` y `focusedDay` divergen. Solución: usar el mismo `DateTime` para ambos y no permitir divergencia por default.
- **R10 — Reactividad al eliminar todos los movimientos de un día**: el stream re-emite con `Map` sin esa clave. El `markerBuilder` debe devolver `null` (no widget) cuando no hay actividad. Verificar test de reactividad.

## Estrategia de pruebas

Ver `test-plan.md` para el detalle completo.

Foco: unitarios del servicio (9 tests), UT del factory (2 tests), widget tests del tab (4 tests). Regresión del conteo de tabs en 1 archivo. Smoke manual en cel real para validar `table_calendar` + `es_MX` + marcadores visualmente.

## Estrategia de rollback

- Revert del commit es limpio: los 5 archivos productivos + 3 test files están en el mismo commit y son ortogonales al resto.
- Dependencia `table_calendar`: revert quita la línea del pubspec. Nuevo `flutter pub get` la elimina del lock. Sin efecto en runtime.
- Cero cambio de datos; revert no deja BD en estado intermedio.
- APK release: si el bump `0.16.0+82` genera problema en cel, `adb uninstall` + reinstalar el APK previo (`0.15.4+81`). Downgrade no permitido por Android, así que hay que desinstalar primero.
- Si se detecta un edge no cubierto post-merge, hotfix aplicable en un mini-sprint corto sin rollback total.

## Orden sugerido de implementacion

1. **T001**: verificar `table_calendar` (changelog + versión estable) → agregar al pubspec + `flutter pub get` → `flutter analyze` limpio.
2. **T002**: modelo `DayActivity` en `reports.dart`.
3. **T003**: método `movementsByDay` con SQL + `readsFrom`.
4. **T004**: factory `EntriesFilters.forDay`.
5. **T005**: widget `MovementsCalendarTab` con TableCalendar + markerBuilder + onDaySelected + onPageChanged.
6. **T006**: integración en `ReportsScreen` (9no tab).
7. **T007-T008**: docs UI (onboarding + FAQ).
8. **T009-T011**: tests (UT servicio + UT factory + widget tests del tab).
9. **T012**: ajuste regresión tabs count 8 → 9.
10. **T013**: `flutter analyze` limpio + `flutter test` completo verde ≥ 482.
11. **T014**: bump versión 0.16.0+82 + APK release + verify-apk.sh.
12. **T015**: smokes SM-01..07 con Diego.
13. **T016**: `branch-quality-review`.
14. **T017**: commit final.

## Casos borde que condicionan la solucion

- Mes sin ningún movimiento: el stream emite `Map` vacío. El widget renderiza el calendario sin marcadores; sin empty state agresivo (los marcadores ausentes ya comunican).
- Día con >100 movimientos: los 3 booleans no cambian; drill-down muestra la lista completa (paginación de `/entries` la maneja).
- Movimiento en el borde del día (23:59:59.999): cae en el día correcto por `date(occurred_at)` en SQLite (usa hora local).
- DST / cambio de horario: el default de Flutter usa hora local del dispositivo; `date(occurred_at)` en SQLite también. Consistente.
- Categoría archivada: irrelevante (no se joinea `categories`).
- Movimiento cancelado (soft delete): excluido por `deleted_at IS NULL`.
- Widget desmontado antes del primer emit: `StreamBuilder` maneja con `snapshot.hasData` check.
- Cambio muy rápido de mes: drift cachea; sin race condition observable.
- BD con muchos años: la query se limita al mes; sin impacto.
- Locale por defecto vs es_MX: hardcodear `Locale('es', 'MX')` en el widget del `TableCalendar` (no depende del locale global de la app).
- Día seleccionado default fuera del mes en foco: RN-CAL06 lo previene inicializando en `null`.
- Tap en día del mes anterior/siguiente (spillover del `TableCalendar`): comportamiento default del paquete (cambia el mes en foco). Aceptable.

## Preguntas o supuestos que siguen afectando la implementacion

Sin preguntas bloqueantes.

Supuestos operativos que se mantienen desde la spec:

- Marcadores binarios por kind (no intensidad por monto — eso viene con el heatmap).
- Sin filtros de kind ni cuenta en v1.
- Drill-down reusa `/entries?filter=...` con `datePreset: custom`.
- Selector de mes = header nativo del `TableCalendar` con flechas prev/next.
- Locale `Locale('es', 'MX')` hardcodeado en el widget.
- Día seleccionado inicial = hoy si cae en el mes actual, sino ninguno.
- Bump a `0.16.0+82` (minor por feature nueva con dep externa).

Si en implementación se detecta que `table_calendar` no soporta Flutter 3.29 / Dart 3.7.2, la decisión escala a un patch de la spec: evaluar alternativa custom (~1 día extra) o downgrade de la versión (riesgo de bugs).

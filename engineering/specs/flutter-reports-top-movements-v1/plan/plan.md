# Plan técnico — flutter-reports-top-movements-v1

## Enfoque técnico

Estrategia incremental clónica del sprint cashflow:

1. **Capa de datos**: extender `ReportsService` con `topMovements(from,
   to, kinds, limit)` que retorna `Stream<TopMovementsReport>` via
   `customSelect.watch()`. Modelos inmutables `TopMovementsReport` y
   `TopMovementEntry`. Atajo defensivo: si `kinds.isEmpty` retorna
   reporte vacío sin tocar BD.
2. **Capa de presentación**: nuevo widget `TopMovementsTab` con misma
   estructura del `CashflowTab` (chips de presets + StreamBuilder +
   estados loading/error/empty). Header agrega chips de **kinds**
   multi-select (decisión P-001). Body lista los hasta N entries
   ordenados por monto desc con tap → `/entries/:id/edit`.
3. **Integración**: `ReportsScreen` cambia `length: 2 → 3` + agrega
   tercer `Tab` + tercer `TabBarView`. Arranca en tab 0 (compatibilidad).
4. **Tests**: 10 tests data + 4 widget tests. Validar que
   `reports_screen_test.dart` sigue verde tras el bump a 3 tabs.

Sin migración de schema. Sin deps externas. Sin tocar productivo del
spending o cashflow tabs.

## Requisitos funcionales cubiertos

- **RF-001**: `topMovements(from, to, kinds, limit=20)` en F1.
- **RF-002**: `TopMovementsReport` en F1.
- **RF-003**: `TopMovementEntry` en F1.
- **RF-004**: query SQL con `LEFT JOIN categories` filtrando
  archivadas + `kind IN (...)` + soft delete + rango + orden + limit
  en F1.
- **RF-005**: `TopMovementsTab` con misma estructura del cashflow tab
  en F3.
- **RF-006**: 4 chips de presets de fecha en F3.
- **RF-006b**: 5 chips de kinds multi-select en el header en F3.
- **RF-007**: `_Row` con descripción + fecha + kind label + badge +
  monto con signo en F3.
- **RF-008**: tap row → `context.push('/entries/:id/edit')` en F3.
- **RF-009**: 2 empty states (sin kinds / rango vacío) en F3.
- **RF-010**: `ReportsScreen` con TabBar de 3 tabs en F4.
- **RF-011**: estados loading / error estáticos en F3.

## Archivos o módulos probablemente afectados

Nuevos:

- `mobile/lib/screens/reports/top_movements_tab.dart` (~280 líneas
  estimadas).
- `mobile/test/screens/top_movements_tab_test.dart` (~150 líneas
  estimadas).

Modificados:

- `mobile/lib/data/reports.dart` (+~110 líneas: modelos + método +
  builder + atajo defensivo).
- `mobile/lib/screens/reports_screen.dart` (+~6 líneas: 3 tabs).
- `mobile/test/data/reports_test.dart` (+~280 líneas: grupos
  `topMovements` con 10 tests).
- `mobile/test/screens/reports_screen_test.dart` (probable ajuste
  por bump a 3 tabs).
- `mobile/pubspec.yaml` (bump 0.8.0+60 + nota).
- `mobile/android/app/build.gradle.kts` (versionCode 60 / versionName
  0.8.0).

No tocados intencionalmente:

- `cashflow_tab.dart` y `spending_by_category_tab.dart` (sin
  regresión).
- `entries_filters.dart` y `entries_dao.dart` (top usa su propio
  servicio).

## Entidades y estados afectados

- **Lectura** sobre `journal_entries` (kind, amount, occurred_at,
  description, deleted_at, created_at, category_id).
- **Lectura** sobre `categories` para resolver el badge via
  `LEFT JOIN categories ON ... AND deleted_at IS NULL`.
- Sin escritura. Sin transiciones. Sin invariantes nuevos.
- Sin auditoría adicional (single-user local).

## Compatibilidad con datos y procesos existentes

- **Backward compatible**: `spendingByCategory` y `cashflowByMonth`
  intactos.
- **TabBar de 3 tabs**: `DefaultTabController(length: 3)`. Tests
  existentes del `reports_screen_test.dart` (5 tests verdes hoy) podrían
  romperse si asumen length=2. Validar en T025.
- **Sin migración** de schema (solo lectura).
- **Sin afecto a `/dashboard`**: BO/DE/CR calculados por
  `FinancialStateService`, independientes del reports service.
- **Reactividad coherente**: `customSelect.watch(readsFrom:
  {journal_entries, categories})` re-emite al cambiar entries o al
  archivar categorías.

## Cambios de datos

No aplica (sólo lectura).

## Cambios de API

No aplica (app local sin red).

## Cambios de integraciones

- Navegación: el tap en row dispara `context.push('/entries/:id/edit')`.
  La ruta ya existe en el router (sprint MVP), no requiere cambio.

## Cambios de UI

- `ReportsScreen` pasa de 2 tabs a 3 tabs en la AppBar.
- Header del tab tiene una sección extra (chips de kinds) que el
  cashflow no tiene. Esto **diferencia** visualmente este tab — Diego
  ve claro que puede acotar el tipo.

## Cambios de permisos

No aplica (single-user local).

## Riesgos técnicos

- **R-T01** (medio): bump de `DefaultTabController.length: 2 → 3`
  podría romper tests del `reports_screen_test.dart` si alguno asume
  length=2. Sprint cashflow validó que el bump 1→2 no rompió nada —
  estimar lo mismo, pero verificar.
- **R-T02** (bajo): el `_Row` del tab clona el patrón del `_Row` de
  `EntriesPaginatedList`. Si el patrón evoluciona en otro sprint, hay
  que sincronizar manualmente. Decisión: clonar (independencia visual
  acepta divergencia futura).
- **R-T03** (bajo): la query con `LEFT JOIN categories` + filtros +
  `ORDER BY amount DESC` + `LIMIT 20` no usa índice específico en
  `amount`. En BDs con >10k entries puede degradar. Para el caso de
  Diego (BD chica) no aplica. Si en uso real se vuelve lento, sprint
  dedicado para índice.
- **R-T04** (bajo): el atajo defensivo `kinds.isEmpty` evita SQL con
  `IN ()` ambiguo. Sin esto, drift puede emitir SQL inválido o
  retornar todo. Documentar.
- **R-T05** (bajo): el tap en row navega vía `context.push`. Si el
  context no está dentro del Navigator de go_router, falla. Validar
  con test.

## Estrategia de pruebas

3 niveles:

1. **Tests data** (10 tests): cubren todas las RN-T01..T08 + casos
   borde CB-T01..T10.
2. **Widget tests** (4 tests): render con datos / empty state vacío /
   empty state sin kinds / tap navega.
3. **Smoke manual** (post-APK): validar en cel real flujo completo,
   especialmente la navegación al edit.

Ver `test-plan.md` para detalle.

## Estrategia de rollback

- **Sin migración** → rollback es trivial: revert del commit.
- Si el tab causa bugs visuales, hot-fix puede entregarse revirtiendo
  `length: 3` a `length: 2` + comentar la entrada del TabBarView.
- No hay state persistente nuevo (los chips de kinds viven solo en
  memoria del tab; al cambiar de tab y volver, vuelven a default).

## Orden sugerido de implementación

Fases en serie:

- **F0**: baseline 251 verdes.
- **F1**: modelos + servicio + builder + atajo defensivo.
- **F2**: tests data (10 tests).
- **F3**: UI del tab nuevo (esqueleto + chips de presets + chips de
  kinds + StreamBuilder + Row + empty states).
- **F4**: integración a `ReportsScreen` (TabBar 2→3).
- **F5**: widget tests (4).
- **F6**: release (analyze + test + APK + verify + docs).

Tareas dentro de cada fase paralelizables documentadas en `tasks.md`.

## Casos borde que condicionan la solución

Los siguientes condicionan decisiones del plan, además de los listados
en spec.md (CB-1 a CB-10):

- **CB-T01** (kinds default al cambiar de tab): el state del tab se
  pierde al cambiar a otro y volver (los chips vuelven a default 5
  seleccionados). Aceptable. Si Diego pide persistir, sprint
  dedicado.
- **CB-T02** (concurrencia con archive de categoría): si una categoría
  del top se archiva desde `/categories/:id/edit` mientras el tab está
  visible, el stream re-emite y el badge desaparece. Cubierto por el
  `readsFrom: {categories}` del customSelect.
- **CB-T03** (rango con 1000 entries): la query con `LIMIT 20` carga
  solo 20 filas. Sin paginación (no aplica — el top siempre es N
  fijo).
- **CB-T04** (entry con monto exactamente igual a otro): el tiebreak
  `occurred_at DESC, created_at DESC` lo posiciona después del más
  reciente. Determinístico.

## Preguntas o supuestos que siguen afectando la implementación

Sin preguntas abiertas. P-001 (kinds configurables con chips) y P-002
(N = 20) respondidas y reflejadas en spec.md y RFs.

Supuestos asumidos del plan vale dejar trazados:

- El widget `TopMovementsTab` clona el patrón del cashflow. Si el
  patrón cambia en otro sprint, mantener sincronización manual.
- Sin extracción de un base widget compartido entre los 3 tabs —
  abstracción prematura mientras los bodies divergen.
- Implementación serial sin worktrees ni subagentes (single-user
  brownfield local).

# Top movimientos — tercer tab del `/reports`

## Resumen

Agregar el tab **"Top movimientos"** a `/reports`, completando la
trifecta analítica junto a "Gasto por categoría" y "Cashflow mensual".
El tab muestra los **N movimientos más grandes** del rango ordenados
por monto descendente. Tap en cada row navega a `/entries/:id/edit`
para auditar o editar. Reusa la infraestructura de presets de fecha de
los otros tabs (`DateRangePreset` + `dateRangeForPreset`). Default
`thisMonth` por coherencia.

## Problema a resolver

Hoy `/reports` responde "dónde gasté" (categorías) y "cómo cambia mes a
mes" (cashflow). NO responde **"cuáles fueron los movimientos
puntuales más grandes"**. Para encontrar el gasto de $5.000 del mes
pasado o el ingreso atípico de la semana, Diego tiene que ir a
`/entries`, aplicar filtros y scrollear.

El uso clave es **auditoría**: identificar outliers (gastos atípicos,
ingresos extraordinarios, transfers grandes que requieren memoria) sin
fricción.

## Objetivo

Que Diego pueda abrir `/reports` → tab "Top movimientos" y ver de un
vistazo los N entries más grandes del período con su descripción,
categoría, fecha y monto. Tap en cualquier row navega al edit del
entry para revisar o cambiar.

## Alcance

- Nuevo tab "Top movimientos" en `/reports` (TabBar 2 → 3 tabs).
- Nuevo widget `TopMovementsTab` en
  `lib/screens/reports/top_movements_tab.dart`.
- Nuevo método `ReportsService.topMovements(from, to, limit)` en
  `lib/data/reports.dart`.
- Nuevos modelos `TopMovementsReport` y `TopMovementEntry`
  (inmutables).
- Header con chips de presets de fecha (reusa `DateRangePreset`
  existente).
- Lista de N rows con descripción, kind label, fecha, categoría
  (badge), monto formateado con signo.
- Tap en row → `context.push('/entries/:id/edit')`.
- Empty state cuando el rango no tiene movimientos.
- Reactividad via `customSelect.watch()` (mismo patrón que el spending
  tab).
- Tests data + widget tests.

## Fuera de alcance

- Configuración de N por el usuario (cambiar 10 a 50). Si surge en uso
  real, sprint dedicado.
- Configuración de qué kinds mostrar (filtro por kind dentro del tab).
- Desglose por cuenta dentro del top.
- Promedio / mediana del período (es un resumen de outliers, no
  estadística descriptiva).
- Comparativo top mes anterior vs actual.
- Export del top a CSV/PDF (sprint F9 separado).
- Animaciones del orden cuando cambia el preset.

## Reglas de negocio

- **RN-T01**: el top se calcula sobre `journal_entries.amount` crudo
  positivo (RN-A01 del sprint anterior). El signo del valor mostrado
  deriva del kind (RN-T05).
- **RN-T02**: `kind` aceptados en el top: **configurable por el
  usuario** (decisión P-001). El header del tab muestra los 5 chips
  de kinds (multi-select). Default: **todos los 5 seleccionados** al
  abrir el tab (auditoría completa). Sin selección = empty state
  forzado. La query SQL aplica `WHERE kind IN (<seleccionados>)`.
- **RN-T03**: rango inclusivo en ambos extremos (`[from, to]`).
  Coherente con los otros tabs.
- **RN-T04**: `journal_entries.deleted_at IS NULL`. Soft-deleted no
  aparecen.
- **RN-T05**: el monto mostrado en la row usa el formateo con signo
  según kind:
  - `income`: `+$X`.
  - `expense` / `credit_expense`: `-$X`.
  - `debt_payment` / `transfer`: `$X` sin signo.
- **RN-T06**: orden **monto descendente**. Tiebreak: `occurred_at`
  descendente (más reciente primero), luego `created_at` descendente
  (M1 del review v1 estilo entries list).
- **RN-T07**: categoría archivada con entry activo: el badge
  desaparece (mismo comportamiento que `_Row` de
  `EntriesPaginatedList` — el JOIN filtra archivadas).
- **RN-T08**: `N = 20` rows (decisión P-002). Constante interna,
  no configurable por el usuario en este sprint. Si en uso real
  Diego pide ajustarlo, sprint dedicado.

## Requisitos funcionales

- **RF-001**: `ReportsService` expone
  `topMovements({DateTime from, DateTime to, required List<String> kinds,
  int limit = 20})` que retorna `Stream<TopMovementsReport>` reactivo
  a cambios en `journal_entries`. Si `kinds.isEmpty`, el servicio
  retorna `TopMovementsReport` vacío directamente sin tocar BD
  (atajo defensivo para no emitir SQL con `IN ()` ambiguo).
- **RF-002**: `TopMovementsReport` contiene: `from`, `to`,
  `List<TopMovementEntry> entries`. Getter `isEmpty` = true si la lista
  está vacía.
- **RF-003**: `TopMovementEntry` contiene: `id`, `kind`, `amount`,
  `occurredAt`, `description` (opcional), `category` (modelo opcional
  con name + color + icon).
- **RF-004**: la query SQL filtra por kind permitido (RN-T02),
  `deleted_at IS NULL`, rango temporal inclusivo, ordena por `amount
  DESC, occurred_at DESC, created_at DESC` y limita a `N`. Usa
  `LEFT JOIN categories ON ... AND deleted_at IS NULL` para resolver
  el badge (RN-T07).
- **RF-005**: `TopMovementsTab` widget con misma estructura visual del
  cashflow tab: header con chips de presets + body con lista o empty
  state.
- **RF-006**: el header acepta los 4 presets existentes
  (`thisMonth`/`lastMonth`/`thisYear`/`custom`). Default `thisMonth`.

- **RF-006b**: el header también muestra los **5 chips de kinds**
  (multi-select) debajo de los presets de fecha. Default: los 5
  seleccionados (RN-T02). Tap en un chip toggla. Mismo patrón visual
  que el `_SelectableChip` del panel de filtros de `/entries`. Sin
  selección → empty state forzado con copy "Seleccioná al menos un
  tipo de movimiento.".
- **RF-007**: cada row muestra: descripción (o kind.label si vacía) +
  fecha + kind.label + badge de categoría (si presente) + monto con
  signo. Layout análogo al `_Row` de `EntriesPaginatedList` para
  coherencia visual.
- **RF-008**: tap en una row → `context.push('/entries/${entry.id}/edit')`.
- **RF-009**: 2 empty states diferenciados:
  - Sin kinds seleccionados: "Seleccioná al menos un tipo de
    movimiento." con icono neutro.
  - Con kinds seleccionados pero rango vacío: "No hay movimientos en
    este rango." con icono neutro.
- **RF-010**: `ReportsScreen` actualizado a `DefaultTabController.length:
  3` + tercer `Tab` + tercer entry en `TabBarView`. `initialIndex`
  default = 0 (no romper hábito).
- **RF-011**: estados loading / error igual que cashflow y spending
  tabs (estáticos sin animación para no colgar `pumpAndSettle`).

## Casos principales

- **CP-1 — Mes con varios movimientos**: thisMonth con 30+ entries.
  Lista muestra los N más grandes ordenados.
- **CP-2 — Tap en un gasto grande**: row de expense → navega a edit con
  los datos pre-cargados.
- **CP-3 — Cambio de preset**: tap "Año" → reporte recalcula con todo
  el año.
- **CP-4 — Empty state**: rango sin movimientos → mensaje + icono.
- **CP-5 — Custom range**: tap "Custom" → 2 date pickers → reporte
  refresca.
- **CP-6 — Reactividad**: cancelar entry desde edit + volver →
  desaparece del top.

## Casos borde

- **CB-1 — Rango con menos de N entries**: muestra todos los que hay
  sin completar a N. Sin warning.
- **CB-2 — `from == to`**: rango de 1 día. Entries de ese día.
- **CB-3 — Empate de monto entre 2+ entries**: tiebreak por
  `occurred_at` desc + `created_at` desc (RN-T06). Determinístico.
- **CB-4 — Entry con `description = null`**: muestra `kind.label` como
  fallback (ej. "Gasto", "Ingreso"). Mismo patrón que la lista de
  `/entries`.
- **CB-5 — Entry con categoría archivada**: badge no aparece (RN-T07).
  Entry sigue en el top con su monto.
- **CB-6 — `transfer` o `debt_payment` seleccionado por chip**: SÍ
  aparecen en el top (auditoría de movimientos internos grandes).
  Diego destildea el chip para excluirlos.
- **CB-6b — Diego destilda todos los chips**: empty state forzado con
  copy "Seleccioná al menos un tipo de movimiento." (RF-009).
- **CB-7 — Concurrencia**: registrar entry grande desde otra pestaña
  con el tab visible → el stream re-emite y el entry sube al top.
- **CB-8 — Cancelar el entry top desde edit**: tras pop, el top
  refresca sin él.
- **CB-9 — Decimales en amount**: ej. `1499.50`. Se respeta. Tiebreak
  ordena `1500.00` antes que `1499.50`.
- **CB-10 — Rango cruzando año**: ordena correctamente sin agrupar
  por año.

## Criterios de aceptacion

- Tap "Reportes" desde dashboard → TabBar con **3 tabs visibles**.
- Tap tab "Top movimientos" → ver chips de presets + lista de hasta
  N entries ordenados por monto desc.
- Cada row muestra descripción/kind + fecha + kind label + badge
  (si aplica) + monto con signo coherente con la lista de `/entries`.
- Tap en una row navega a `/entries/:id/edit` con los datos pre-cargados.
- Cambio de preset refresca el reporte.
- Registrar un entry nuevo desde `/entries/new` y volver al tab → el
  reporte refleja el nuevo dato (reactividad via `customSelect.watch`).
- BD sin movimientos en el rango → empty state visible.
- `flutter test` sigue verde tras los tests data + widget tests
  nuevos.

## Criterios medibles de exito

- **CM-01**: 9+ tests data del `topMovements`:
  - 1 test empty (BD sin entries).
  - 1 test orden por monto desc.
  - 1 test tiebreak por occurred_at desc.
  - 1 test soft-deleted excluido.
  - 1 test limit respetado (30 sembrados, limit 20 → 20).
  - 1 test rango inclusivo en `from`.
  - 1 test rango inclusivo en `to`.
  - 1 test categoría archivada → badge null.
  - 1 test filtro de kinds: solo entries de los kinds seleccionados
    aparecen.
  - 1 test `kinds: []` → atajo defensivo retorna lista vacía sin
    tocar BD.
- **CM-02**: 4+ widget tests del `TopMovementsTab`:
  - render con datos.
  - empty state cuando rango vacío.
  - empty state cuando sin kinds seleccionados.
  - tap en row navega a `/entries/:id/edit`.
- **CM-03**: 0 errores `flutter analyze`.
- **CM-04**: APK release `0.8.0+60` (bump menor por feature visible)
  validado por `verify-apk.sh`.

## Riesgos

- **R-01** (bajo): `ReportsScreen.length: 2 → 3` puede romper tests del
  `reports_screen_test.dart` si alguno asume length=2. El sprint
  anterior validó que los tests no asumían length=1; estimar lo mismo
  ahora.
- **R-02** (medio): el patrón `_Row` del tab clona el `_Row` de
  `EntriesPaginatedList`. Si el patrón cambia en el otro lado, hay que
  sincronizar manualmente. Decisión: clonar para mantener
  independencia visual (los layouts pueden divergir si el feedback
  pide minor changes en uno y no en el otro).
- **R-03** (bajo): el `LEFT JOIN categories` con filtro `deleted_at IS
  NULL` es idéntico al `EntriesDao.watchPage`. Reusable.
- **R-04** (bajo): tap en row → `context.push('/entries/:id/edit')`
  requiere que el router siga registrando esa ruta. Verificar.

## Supuestos

- **N = 20 rows** (decisión P-002). Constante interna no
  configurable por el usuario en este sprint.
- **Kinds configurable con chips** (decisión P-001). Default: los 5
  seleccionados al abrir el tab. Sin selección → empty state forzado.
- **Tap navega a edit, no a una vista detail dedicada**: coherente con
  la lista de `/entries`.
- **Sin filtros adicionales dentro del tab**: el header solo tiene
  presets de fecha. Si Diego pide filtros (cuenta, categoría) en uso
  real, sprint dedicado.
- **Reusa estilos del `_Row` de `EntriesPaginatedList` para coherencia
  visual**. Sin nueva paleta.
- **Sin animaciones del reordenamiento** cuando cambia el preset (el
  primer release no las trae).
- **TabBar arranca en tab 0** (gasto por categoría) por compatibilidad
  con tests existentes y hábito del usuario.
- **El servicio no asume backend remoto**: pura lectura SQLite con
  `customSelect.watch`.

## Impacto esperado

- **Producto**: cierra el set analítico de `/reports` (3 dimensiones:
  categorías, tendencia, outliers).
- **Código**: `reports.dart` crece ~60 líneas (servicio + modelos).
  `reports_screen.dart` +6 líneas (tab + entry). Nuevo
  `top_movements_tab.dart` ~250 líneas.
- **Tests**: +8 data + 3 widget = ~262 verdes post.
- **APK size**: cero impacto (sin deps nuevas).
- **Sin migración de BD**: solo lectura.
- **Sin regresión** esperada en spending o cashflow (sin tocar sus
  archivos).

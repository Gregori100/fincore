# Presupuestos mensuales por categoría

## Resumen

Séptimo tab "Presupuestos" en `/reports` que muestra el progreso del mes en curso por categoría con presupuesto seteado: gastado vs `monthly_limit`, ring de %, estado OK/warning/excedido. El CRUD del presupuesto se hace directamente en el form de edición de categoría (input nuevo "Presupuesto mensual"). **No hay schema bump**: la columna `categories.monthly_limit` ya existe desde el legacy (heredada del backend, con soporte de backup) pero nunca se expuso en la UI de Flutter.

## Problema a resolver

Diego (y testers) no tienen una forma de setear cuánto quieren gastar por mes por categoría ni de ver progreso contra ese límite. El campo `monthly_limit` existe en la BD desde el pivote pero está huérfano: el backup lo serializa pero la UI Flutter nunca dio manera de asignar un valor ni de visualizarlo. Sin este reporte, el usuario tiene que hacer mental math contra el gasto mensual (o mirarlo por reporte de "Gasto por categoría") para saber si va por buen camino o se pasó.

## Objetivo

1. Input UI "Presupuesto mensual" en `CategoryFormScreen` (visible solo cuando `applies_to ∈ {expense, both}`; no aplica a categorías `income`).
2. Nuevo tab "Presupuestos" en `/reports` — séptimo — con card por categoría con presupuesto seteado, gastado del mes en curso, % usado, disponible y estado visual.
3. Reactivo: cambios de presupuesto o registro de gastos actualizan el reporte sin refresh manual.

## Alcance

- Exponer `monthly_limit` como input opcional en `CategoryFormScreen` (visible solo si `applies_to != 'income'`).
- Validación en `CategoriesDao.create/updateCategory`: `monthly_limit != null` requiere `applies_to != 'income'`; rechazar `< 0` con `invalid_monthly_limit`.
- Servicio nuevo: `ReportsService.watchBudgetsProgress()` con stream reactivo.
- Modelo nuevo: `BudgetProgress` inmutable.
- Widget nuevo: `BudgetsTab` en `mobile/lib/screens/reports/budgets_tab.dart`.
- Integrar el tab al `TabBar` de `ReportsScreen` (pasa de 6 a 7 tabs).
- Empty state con CTA "Ir a categorías" (naviga a `/categories`).
- Actualizar slide 3 del `OnboardingScreen` a "7 reportes" con fila "Presupuestos".
- Actualizar FAQ de `HelpScreen`: nuevo tab + explicación de "cómo defino un presupuesto".
- Tests: DAO validación, servicio, widget del tab, widget del form input.

## Fuera de alcance

- Schema bump — la columna `monthly_limit` ya existe (heredada del legacy).
- Presupuestos por rango custom (semanal, trimestral, anual). Solo mensual calendario.
- Presupuestos con fecha de inicio custom (ej: "budget desde el 15 al 15"). El mes calendario natural es la única opción.
- Presupuestos por cuenta o por combinación categoría+cuenta.
- Notificaciones push cuando se llega al 80% o se excede.
- Historial: consultar presupuestos pasados vs gasto real. Solo mes en curso.
- Auto-rollover: si sobró de un mes, no se acumula al siguiente. El presupuesto es plano cada mes.
- Presupuestos con periodicidad no-mensual (semanal, quincenal).
- Auto-sugerencia del monto del presupuesto basado en el promedio histórico.
- Import/export separado de presupuestos: viajan en el JSON v1 dentro de `categories[i].monthly_limit` como ya hace hoy.

## Reglas de negocio

- **RN-B01**: `monthly_limit` es opcional y solo aplica a categorías con `applies_to ∈ {expense, both}`. Para `income` debe permanecer `null`.
- **RN-B02**: `monthly_limit >= 0`. El valor 0 es válido y significa "no quiero gastar en esta categoría" (progreso: cualquier gasto es "excedido").
- **RN-B03**: `monthly_limit == null` significa "sin presupuesto". La categoría NO aparece en el reporte de Presupuestos.
- **RN-B04**: El "mes en curso" es el mes calendario absoluto: del día 1 a las 00:00 al último día del mes 23:59:59.999 del huso horario local.
- **RN-B05**: El "gastado del mes" es la suma de `journal_entries` con `kind ∈ {expense, credit_expense}` para esa categoría, `deleted_at IS NULL`, `occurred_at` dentro del mes en curso.
- **RN-B06**: Solo se muestran categorías activas (`categories.deleted_at IS NULL`) con `monthly_limit != null`.
- **RN-B07**: Categorías `income` con `monthly_limit != null` (edge histórico o error): filtrar en el DAO al guardar; si ya existen en BD (import legacy), no aparecen en el reporte (filtro en la query).
- **RN-B08**: `% usado = (gastado / monthly_limit) × 100` con clamp visual a 100% en el ring. Si `monthly_limit == 0`, `% = null` (no calculable); si hay gastos > 0, se marca como excedido con badge "$X gastado".
- **RN-B09**: Estados por umbral:
  - `OK`: 0-79% usado. Color accent.
  - `Warning`: 80-100%. Color warning.
  - `Excedido`: > 100%. Color negative + badge "Excedido por $X".
  - `Sin gasto`: `gastado == 0`. Badge sutil, ring vacío.
- **RN-B10**: Cascade al archivar categoría: al archivar (soft-delete) una categoría con presupuesto, el presupuesto queda archivado también (por ser un campo de la misma fila). No aparece en el reporte. No hay "budget huérfano".
- **RN-B11**: Orden en el reporte:
  1. Excedidas primero (mayor % primero).
  2. Warning (mayor % primero).
  3. OK con gasto > 0 (por % desc).
  4. Sin gasto al final (alfabético por nombre).
- **RN-B12**: Sin selector de fecha. El tab siempre muestra el mes en curso. Simplifica la UX (a diferencia de otros reportes con rango).
- **RN-B13**: El reporte es reactivo. `customSelect(sql, readsFrom: {categories, journalEntries}).watch()` re-emite al editar presupuesto o al registrar/cancelar gastos del mes.
- **RN-B14**: "Gasto disponible" = `max(monthly_limit - gastado, 0)`. Nunca negativo (para tarjetas excedidas se muestra en 0 y el badge "Excedido por $X" comunica el sobregiro).

## Requisitos funcionales

- **RF-001**: `CategoryFormScreen` muestra `TextFormField` "Presupuesto mensual" con `prefixText: '$ '`, keyboard `numberWithOptions(decimal: true)`, `_parseDecimalInput` (acepta `,` o `.`). Visible solo cuando `_appliesTo != AppliesTo.income`. Vacío = null en BD.
- **RF-002**: Al cambiar `applies_to` a `income` desde el form, si había un valor en el input de presupuesto, se limpia (visualmente y en el submit).
- **RF-003**: `CategoriesDao.create` y `updateCategory` reciben `monthlyLimit: double?`. Validación: si `monthlyLimit != null` y `appliesTo == 'income'` → `AppliesTo` es `both` o `expense`, si no error `invalid_monthly_limit_for_income`. Si `monthlyLimit != null && monthlyLimit < 0` → `invalid_monthly_limit`.
- **RF-004**: Nuevo modelo inmutable `BudgetProgress` en `lib/data/reports.dart` con campos: `categoryId`, `categoryName`, `colorSlug`, `iconSlug`, `monthlyLimit`, `spent`, `available`, `usedPct` (nullable), `isOverBudget`, `isWarning`, `isNoSpend`. Constructor factory `compute` que aplica RN-B08/B09.
- **RF-005**: Nuevo método `ReportsService.watchBudgetsProgress({DateTime? monthAnchor})` retorna `Stream<List<BudgetProgress>>`. `monthAnchor` default `DateTime.now()`. Ordena por RN-B11.
- **RF-006**: Nuevo widget `BudgetsTab` en `lib/screens/reports/budgets_tab.dart`:
  - Loading state: 2 `SkeletonCard`.
  - Empty state (no hay categorías con presupuesto): icono + texto "No definiste presupuestos aún" + `FilledButton.icon("Ir a Categorías")` que navega a `/categories`.
  - Data: `ListView.separated` de `_BudgetTile`.
- **RF-007**: `_BudgetTile` con `BaseCard`: `CategoryBadge` (color+icon del catálogo), nombre, ring circular del % con `_UsedRing` (reusar patrón del sprint credit-cards o duplicar simple), fila gastado/límite/disponible, badge "Excedido por $X" si `isOverBudget`, badge "Sin gasto" si `isNoSpend`.
- **RF-008**: `ReportsScreen` agrega séptimo `Tab(text: 'Presupuestos')` al `TabBar` y `BudgetsTab()` al `TabBarView`. Mantener `isScrollable: true`.
- **RF-009**: Actualizar slide 3 del `OnboardingScreen`: agregar fila `_KindRow(icon: Icons.savings_outlined, color: FincoreColors.positive, label: 'Presupuestos')`. Actualizar párrafo a "7 reportes".
- **RF-010**: Actualizar FAQ de `HelpScreen` — bullet nuevo en "¿Cómo se calculan los reportes?" para "Presupuestos". Nuevo FAQ tile: "¿Cómo defino un presupuesto?" explicando el flujo (editar categoría → llenar campo → guardar).
- **RF-011**: Bump versión `pubspec.yaml` + `android/app/build.gradle.kts` a `0.14.0+72`.

## Casos principales

1. Diego edita categoría "Comida" con `applies_to=expense` y setea `monthly_limit=5000` → guarda → aparece en el reporte con 0% usado el día 1 del mes.
2. Diego registra un `expense` de $1500 en "Comida" el día 10 → el reporte muestra `gastado=1500, disponible=3500, %=30, estado=OK`.
3. Diego registra otro gasto de $3000 en "Comida" el día 20 → `gastado=4500, disponible=500, %=90, estado=Warning`.
4. Diego registra un gasto de $1000 más el día 25 → `gastado=5500, disponible=0, %=110 (visual 100), estado=Excedido, badge "Excedido por $500"`.
5. Tester nuevo abre el reporte sin haber definido ningún presupuesto → empty state con CTA "Ir a Categorías".
6. Diego cambia de mes (llega el 1 del siguiente mes) → reset visual: gastado vuelve a 0 (los gastos anteriores ya no cuentan porque están fuera del mes en curso).

## Casos borde

- **CB-01**: Categoría con `applies_to=both` puede recibir presupuesto (aplica a gastos del mes; los ingresos con esa categoría no afectan el `gastado`).
- **CB-02**: `monthly_limit=0` y `gastado=0` → `% = null`, badge "Sin gasto".
- **CB-03**: `monthly_limit=0` y `gastado > 0` → `% = null` (no calculable), badge "Excedido por $X" con la cantidad total.
- **CB-04**: Categoría archivada con presupuesto → NO aparece en el reporte (RN-B06). Al importar backup con categorías archivadas + presupuesto, ni se muestran.
- **CB-05**: Import backup v1 con categoría `applies_to=income` + `monthly_limit=5000` → el DAO NO valida en el import (queda como está), pero el filtro del reporte NO la incluye (RN-B07).
- **CB-06**: Diego setea presupuesto el día 20 del mes → el `gastado` incluye TODOS los gastos del mes en curso (desde el día 1), no solo desde el día 20. Consistente con la semántica "mes calendario".
- **CB-07**: Gasto con `category_id = null` (sin categoría) → NO contribuye a ningún presupuesto.
- **CB-08**: Gasto con categoría archivada — como se ve en `entries_dao.dart:updateEntry`, esos gastos quedan con `category_id` referenciando una fila archivada; el `LEFT JOIN` del SQL trata `deleted_at IS NOT NULL` como sin categoría — NO cuenta en ningún presupuesto.
- **CB-09**: `kind = credit_expense` cuenta como gasto (mismo tratamiento que `expense` en el reporte "Gasto por categoría"). `debt_payment` y `transfer` no cuentan.
- **CB-10**: Zona horaria: `occurred_at` se compara contra el rango del mes local. El "primer día del mes" es `DateTime(year, month, 1, 0, 0, 0)`, el último es `DateTime(year, month + 1, 0, 23, 59, 59, 999)` (día 0 del mes siguiente).
- **CB-11**: Fin de mes al momento del render: si el usuario abre el tab exactamente cuando cambia el mes (23:59:59 → 00:00:00), el stream aún no se re-emite porque `DateTime.now()` se evaluó al construir la query. Trade-off aceptado (documentado en supuestos): el reporte refresca al re-abrir el tab o al registrar cualquier movimiento.
- **CB-12**: Categoría con `monthly_limit` decimal alto (ej: 999999.99) → sin overflow, `AmountFormatter` maneja.
- **CB-13**: Cambio de mes-año (diciembre → enero) → `month + 1` con clamp del día 0.
- **CB-14**: Backup export con categoría con `monthly_limit=5000` — el JSON ya lo serializa desde antes del sprint (el campo existía). Post-sprint export es idéntico. Import legacy con `monthly_limit=5000` también funciona.

## Criterios de aceptacion

- Editar categoría "Comida" (expense) → agregar `monthly_limit=5000` → guardar → OK, sin error.
- Editar categoría "Sueldo" (income) → el input "Presupuesto mensual" NO está visible.
- Cambiar `applies_to` de `expense` a `income` con `monthly_limit` seteado → el input desaparece; al guardar, el valor se persiste como null.
- Abrir `/reports` → sexto tab "Presupuestos" visible.
- Con 0 presupuestos definidos: empty state con CTA a `/categories`.
- Con 1+ presupuestos: card por categoría con nombre, badge (color+icon del catálogo), ring del %, gastado formateado en MXN, límite, disponible.
- Registrar `credit_expense` o `expense` en la categoría → card actualiza `gastado` en tiempo real.
- Cambiar `monthly_limit` desde el form de categoría → card refleja el nuevo % al volver.
- `flutter test` verde con nuevos tests + los existentes.
- `flutter analyze` en 0 errores.
- Backup round-trip preserva `monthly_limit`.

## Criterios medibles de exito

- 7 tabs en `/reports` (pasa de 6 a 7).
- `CategoryFormScreen` con 1 input nuevo visible según `applies_to`.
- ≥6 tests nuevos data-layer (DAO validaciones, servicio watchBudgetsProgress con múltiples escenarios, cálculo del rango de mes).
- ≥4 widget tests (empty state, con datos, cambio dinámico de applies_to, reactividad).
- Version `0.14.0+72` visible en Settings → Acerca de.
- `verify-apk.sh` OK.

## Riesgos

- **R1 — Filtro de categorías archivadas y sin categoría en el SQL**: el `LEFT JOIN` con `AND c.deleted_at IS NULL` filtra ambos casos a `null`, y `WHERE c.monthly_limit IS NOT NULL` los excluye del reporte. Riesgo bajo si se sigue el patrón de `spendingByCategory` que ya usa este idiom.
- **R2 — Semántica de `applies_to=both`**: el input aparece pero la categoría puede recibir tanto `income` como `expense`. La sumatoria del reporte solo cuenta `expense`+`credit_expense`. Documentado en CB-01. Diego podría interpretar mal si asume que "los ingresos de esa categoría reducen el gastado". Mitigación: helper text en el input y FAQ.
- **R3 — Backup legacy con `applies_to=income` + `monthly_limit`**: el importador NO rechaza este combo (compat). El reporte lo filtra. Diego no ve el "residuo" pero sí lo tiene en BD. Mitigación: no filtrar en el importador; opcionalmente agregar helper en el DAO "cleanBudgets()" en sprint futuro.
- **R4 — Cambio de mes al medianoche**: el stream no refresca hasta que ocurra un evento (RN-B04 + CB-11). Trade-off aceptado.
- **R5 — `monthly_limit=0` semántica ambigua**: 0 = "no quiero gastar en esto" vs "no seteé nada". Actualmente `null` = "no seteé", `0` = "meta 0". Documentado en RN-B02 pero puede confundir. Helper text "$0 = meta de no gastar en esta categoría".
- **R6 — Performance del SQL de agregación mensual**: agrupa gastos del mes por categoría. Con 10K entries y 20 categorías activas, ~5-10ms por emit. No es hot path.
- **R7 — Nombre del tab "Presupuestos"**: 12 caracteres, más largo que "Tarjetas" (8). Con `isScrollable: true` del TabBar, no rompe. Cosmético.

## Supuestos

- El campo `categories.monthly_limit` ya existe desde el legacy (verificado en `database.dart:60`) y el backup ya lo serializa (`backup.dart:308`, `:432`).
- Diego edita categorías esporádicamente (no varias veces al día); la fricción de "editar categoría para setear presupuesto" es aceptable.
- No hay historial de presupuestos: si Diego cambia el `monthly_limit` de $5000 a $6000 el día 15, el reporte usa $6000 desde ese momento (no hace hindsight).
- El "mes en curso" es el mes calendario local. No hay zonas horarias exóticas — Diego usa es_MX (UTC-6).
- El input "Presupuesto mensual" se muestra en el form justo debajo de `applies_to` para asociarlo visualmente con la restricción.
- La categoría archivada con presupuesto no aparece en el reporte incluso si tiene gastos históricos del mes en curso (RN-B06). Si Diego archiva "Comida" a mitad de mes, el presupuesto desaparece del reporte.
- Los presupuestos NO se pausan por vacaciones ni se prorratean por fecha de setup — el `monthly_limit` es siempre para el mes calendario completo.

## Impacto esperado

- Diego (y testers con datos suficientes) obtienen visibilidad clara de si están gastando por encima de lo que se propusieron. Complementa "Gasto por categoría" con una referencia proactiva ("cuánto me falta") en vez de retrospectiva ("cuánto gasté").
- Cierra el hueco del campo `monthly_limit` huérfano post-pivote.
- Sin schema bump: cero riesgo de migración destructiva.
- Backup JSON compatible bidireccional sin cambios adicionales.
- Base para features futuras del backlog: forecast con badges (que ya se solapa con "Promedio mensual"), notificaciones push cuando se llega al 80%, o auto-sugerencia de presupuesto basado en histórico.

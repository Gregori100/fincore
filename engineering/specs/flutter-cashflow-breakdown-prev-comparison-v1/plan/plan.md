# Plan técnico — flutter-cashflow-breakdown-prev-comparison-v1

## Enfoque tecnico

Extensión aditiva sobre el sprint padre `flutter-cashflow-monthly-breakdown-v1`. Cero cambio de schema. 4 puntos de cambio ortogonales:

1. **Query única extendida** (`ReportsService.cashflowMonthBreakdown`):
   - El SQL se mantiene idéntico pero cambia el filtro de `strftime(...) = ?` a `strftime(...) IN (?, ?)` con `currentKey` y `previousKey`.
   - Agrega `strftime('%Y-%m', j.occurred_at, 'localtime') AS month_key` al SELECT + GROUP BY.
   - `readsFrom: {journalEntries, categories}` sin cambios.

2. **Helper `_buildMonthBreakdown`**:
   - Separa filas por `month_key` en 2 acumuladores por lado (4 total: current-income, current-expense, prev-income, prev-expense).
   - Al construir los `CategoryFlow` del mes actual, busca el bucket previo con el mismo `categoryId` (o `null` para "Sin categoría") y calcula `delta`.
   - Los 3 totales (income/expense/net) del `MonthBreakdown` también calculan delta.
   - RN-CP09 (previo=0 y actual>0 → delta null) implementado con guard.

3. **Modelos nuevos + extensión de existentes** (mismo archivo `reports.dart`):
   - `enum DeltaDirection { up, down, flat }`.
   - `class DeltaPercent { final double percent; final DeltaDirection direction; ... }` const-inmutable. `percent` siempre ≥ 0 (magnitud); signo via `direction`.
   - `CategoryFlow` gana `final DeltaPercent? delta`.
   - `MonthBreakdown` gana `final DeltaPercent? deltaIncome, deltaExpense, deltaNet`.

4. **UI** (`cashflow_tab.dart`):
   - `_CategoryFlowRow` gana un `_DeltaChip` al final del row (después del percent). Chip pequeño con `padding` mínimo y `fontSize 11`.
   - `_BreakdownSummary` gana 3 chips debajo de cada monto (Ingresos/Gastos/Neto), del mismo widget `_DeltaChip`.
   - Helper `_deltaColor({direction, isExpenseSide})` con la semántica "impacto bolsillo" RN-CP07.
   - Chip null → `—` en `textMuted` sin ícono.
   - Chip up/down/flat → ícono (`arrow_upward`/`arrow_downward`/`remove`) + percent con 1 decimal.

**FAQ** (`help_screen.dart`): bullet del cashflow extendido.

**Bump**: `0.17.1+89` → `0.18.0+90`.

## Requisitos funcionales cubiertos

- **RF-001** (compute mes previo con `DateTime(y, m-1, 1)`): T002. Dart normaliza `month=0` a mes 12 del año anterior — verificar con UT-CP07.
- **RF-002** (SQL con `IN (?, ?)` + `month_key`): T002.
- **RF-003** (helper con 4 acumuladores + match por categoryId): T003.
- **RF-004** (modelos `DeltaPercent` + `DeltaDirection`): T004.
- **RF-005** (extensión de `CategoryFlow` + `MonthBreakdown` con deltas): T004.
- **RF-006** (`_CategoryFlowRow` con chip): T007.
- **RF-007** (`_BreakdownSummary` con 3 chips): T008.
- **RF-008** (helper `_deltaColor`): T007.
- **RF-009** (FAQ Help): T009.
- **RF-010** (10-12 tests nuevos): T010-T012.
- **RF-011** (bump 0.18.0+90): T013.

## Archivos o modulos probablemente afectados

Confirmados por inspección:

- `mobile/lib/data/reports.dart` — extender `cashflowMonthBreakdown` (líneas ~467-500), extender `_buildMonthBreakdown` (~500-575), agregar `DeltaPercent` + `DeltaDirection` y extender `MonthBreakdown` + `CategoryFlow` (~1792-1840).
- `mobile/lib/screens/reports/cashflow_tab.dart` — extender `_CategoryFlowRow` (~904), extender `_BreakdownSummary` (~785), agregar `_DeltaChip` y helper `_deltaColor`.
- `mobile/lib/screens/help_screen.dart` — bullet cashflow.
- `mobile/pubspec.yaml` + `mobile/android/app/build.gradle.kts` — bump `0.18.0+90`.

Tests:

- `mobile/test/data/reports_test.dart` — grupo nuevo `cashflowMonthBreakdown — comparación vs mes previo` con UT-CP01..09.
- `mobile/test/screens/cashflow_tab_test.dart` — WT-CP01..02 widget tests con chip visible + `—` fallback.

Sin cambios:

- Schema, migraciones, DAOs, backup, `FinancialStateService`, router, otros tabs.
- Modelos `MonthCashflow`, `CashflowReport` del cashflow base.
- Sprint padre (`cashflowMonthBreakdown` extendida es 100% compatible hacia atrás: los deltas son opcionales, callers existentes reciben `null`).

## Entidades y estados afectados

- **`DeltaPercent`** (nuevo, memoria): `percent >= 0`, `direction ∈ {up, down, flat}`.
- **`DeltaDirection`** (nuevo enum): 3 valores.
- **`CategoryFlow`** (extensión aditiva): campo nuevo `delta` (nullable). Callers existentes no se rompen.
- **`MonthBreakdown`** (extensión aditiva): 3 campos nuevos `deltaIncome`, `deltaExpense`, `deltaNet` (nullable). Callers existentes no se rompen.
- Sin cambios en `Account`, `Category`, `JournalEntry`, `MonthCashflow`.

## Compatibilidad con datos y procesos existentes

- **Sprint padre**: los 21 tests siguen verdes. El helper extendido devuelve el mismo `MonthBreakdown` con campos adicionales, `null` cuando no aplica.
- **Query performance**: `strftime IN (?, ?)` sobre `journal_entries` con datasets típicos single-user < 500 mov/mes es negligible (< 30 ms).
- **Reactividad**: `readsFrom: {journalEntries, categories}` intacto. Cambio en cualquiera de los 2 meses dispara re-emit del sheet completo.
- **Backup JSON**: sin cambios. Ningún campo nuevo persiste.
- **Divergencia timezone (R6 del sprint padre)**: sigue vigente para la comparación con el tab base. Dentro del sheet (actual vs previo) ambos usan `localtime` — coherente internamente.

## Cambios de datos si aplica

No aplica.

## Cambios de API si aplica

No aplica (app local-first).

## Cambios de integraciones si aplica

No aplica.

## Cambios de UI si aplica

- `_CategoryFlowRow` extendido con chip delta al final (~40-50 px de ancho).
- `_BreakdownSummary` extendido con chip debajo de cada monto.
- FAQ actualizado.
- Sin cambios en Dashboard, `/entries`, forms, otros tabs.

## Cambios de permisos si aplica

No aplica.

## Riesgos tecnicos

- **R1 — Layout en cel angosto**: chip agrega ~40-50 px. Con label largo + ellipsis puede quedar apretado. Mitigación: `Flexible` en el label, chip después del percent con espacio fijo. Verificar en SM-01.
- **R2 — Signo del neto que cambia**: R3 de la spec. Ejemplo: mes previo `net = +100`, mes actual `net = -50`. El cálculo `(actual - previo) / |previo| = -150%` → magnitud 150%, direction `down`. Documentado en RN-CP08 y test explícito UT-CP09.
- **R3 — División por cero**: RN-CP09. Previo = 0 → delta null. Cubierto en UT-CP04.
- **R4 — Flat con floating-point**: monto idéntico entre meses puede tener drift de `1e-9`. Usar `abs(diff) < 0.01` para clasificar como `flat` en el helper.
- **R5 — Match por categoryId con `null`**: el bucket "Sin categoría" del actual (categoryId=null) matchea con el mismo del previo. Verificar que `Map<String?, ...>` acepta null como key (Dart lo permite).
- **R6 — Divergencia sprint padre R6**: la query interna del sheet ahora usa `localtime` para 2 meses. El tab base sigue en UTC. Delta calculado 100% localtime, coherente internamente. Documentado.
- **R7 — Reactividad ruidosa**: cambiar categoría no visible (ej. archivar categoría del año pasado) dispara re-emit del sheet aunque no afecte los 2 meses actuales. Overhead negligible single-user.

## Estrategia de pruebas

Ver `test-plan.md`. Foco:

- **UT servicio** (9 tests): cálculo del delta, dirección, `flat` con tolerancia, match por categoryId, "Sin categoría" matcheado, previo=0 → null, categoría solo en actual → null, categoría solo en previo → NO aparece, rollover enero → diciembre año anterior, neto que salta signo, reactividad (`emitsThrough`).
- **Widget tests** (2-3): chip visible con dirección correcta según semántica bolsillo; chip `—` para bucket sin previo.
- **Smokes SM-01..05** con Diego en cel real.

## Estrategia de rollback

Feature 100% aditiva. `git revert` del commit elimina la funcionalidad sin residuo:

- Zero schema/data.
- Modelos nuevos no persisten.
- La query extendida vuelve a filtro simple.
- Los callers existentes del servicio no se rompen (los deltas siempre fueron opcionales).

Si aparece bug bloqueante post-deploy, patch `0.18.1+91` con fix específico.

## Orden sugerido de implementacion

1. **T001**: leer código actual detallado — bloque `cashflowMonthBreakdown` + `_buildMonthBreakdown` (`reports.dart:467-575`), modelos `MonthBreakdown` + `CategoryFlow` (`reports.dart:1792-1840`), `_CategoryFlowRow` + `_BreakdownSummary` (`cashflow_tab.dart:785-970`). Verificar patrón de `Padding + Row` interno del row.
2. **T002-T003** (servicio + helper): extender query + helper. Mantener signature del método stream.
3. **T004** (modelos): `DeltaPercent`, `DeltaDirection`, campos nuevos en `CategoryFlow` + `MonthBreakdown`.
4. **T005** (`_deltaColor`): helper visual con semántica bolsillo.
5. **T006** (`_DeltaChip`): widget interno reusable.
6. **T007** (`_CategoryFlowRow` extendido): agregar chip al row.
7. **T008** (`_BreakdownSummary` extendido): 3 chips debajo de cada monto.
8. **T009** (FAQ Help).
9. **T010** (UT-CP01..09 servicio).
10. **T011** (WT-CP01..02 widget).
11. **T012** (suite completa verde + analyze).
12. **T013** (bump + APK + verify).
13. **T014** (smokes SM-01..05 con Diego — batch con los pendientes).
14. **T015** (`branch-quality-review`).
15. **T016** (commit final).

## Casos borde que condicionan la solucion

Ver `test-plan.md` para el listado completo. Nuevos que el plan detecta (además de CB-01..15 spec):

- **CB-P01**: Categoría con `applies_to='both'` que aparece en gasto en mes previo y en ingreso en mes actual → los 2 buckets son de lados distintos → NO se matchean → ambos sin delta. Consistente con RN-CP02 que dice "mismo categoryId + mismo lado" implícito.
- **CB-P02**: Movimiento cambiado de fecha (mes previo → mes actual) con sheet abierto → 2 re-emits (uno por cada watch trigger de journal_entries) → estado final correcto.
- **CB-P03**: Sheet abierto para junio; usuario cambia el rango del tab base a "Año pasado" (que NO incluye junio 2026 pero sí junio 2025). El `monthAnchor` del sheet sigue siendo junio 2026 (cachea). El delta compara junio 2026 vs mayo 2026, no toca el rango del tab base. Consistente con CB-17 del sprint padre.

## Preguntas o supuestos que siguen afectando la implementacion

Sin preguntas bloqueantes.

Supuestos operativos que se mantienen desde la spec:

- El `DateTime(monthAnchor.year, monthAnchor.month - 1, 1)` normaliza correctamente enero → diciembre año anterior (verificar en UT-CP07).
- El chip visual cabe en el layout del row aún con categorías de nombres típicos (< 15 chars). Si aparece regresión, se ajusta con `Flexible` + `overflow.ellipsis`.
- Diego prefiere `—` explícito sobre chip oculto cuando no hay data previa (RN-CP05).
- El match por `categoryId` sobrevive rename porque el ID es estable (no cambia con `updateCategory`).
- `flat` con `Icons.remove` es visualmente distinto de `—` textual — no requiere test específico visual (widget test valida presencia del ícono).

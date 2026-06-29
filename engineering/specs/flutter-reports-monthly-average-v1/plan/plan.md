# Plan técnico — flutter-reports-monthly-average-v1

## Enfoque técnico

- **Sin schema bump, sin migración**: toda la información se deriva de `journal_entries` + `categories` ya existentes.
- **Una sola query agregada** que devuelve gasto por `(mes, categoría)` combinando histórico prorrateado al día D y mes en curso completo. La query se filtra en SQL con `strftime('%Y-%m', ...)` para agrupar por mes y `CAST(strftime('%d', ...) AS INTEGER) <= D` para el prorrateo. Las filas resultantes se procesan en Dart para calcular promedios y deltas. Patrón idéntico al de `cashflowByMonth`.
- **Stream reactivo** con `customSelect(...).watch(readsFrom: {journalEntries, categories})`. Joineamos `categories` porque el desglose por categoría necesita nombre/slugs, y un archive de categoría DEBE re-emitir el reporte (RN-A09).
- **2 modelos inmutables nuevos**: `MonthlyAverageReport` (raíz) y `CategoryAverageDelta` (filas del breakdown).
- **UI siguiendo patrón `cashflow_tab.dart`**: `StatefulWidget` con state `_monthsBack` + `_reportStream` cacheado, chips de presets en el header, `StreamBuilder` con loading/empty/data states, body con `_GlobalCard` + `_CategoryBreakdown`.
- **Inyección de `now`**: `DateTime? now` opcional en el método del service, default `DateTime.now()`. Permite widget tests determinísticos.
- **Helpers reutilizables**: `_proratedHistoricalForMonth(rows, monthKey, D)` y `_iterateClosedMonths(now, monthsBack)` quedan como private del service.

## Requisitos funcionales cubiertos

- **RF-001** (5° tab): se añade `MonthlyAverageTab` a `ReportsScreen.tabs` después de `BalanceAtDateTab`. `length: 4 → 5`.
- **RF-002** (chips presets `[1, 3, 6, 12, 24]`, default 3): header del tab con `Wrap` + `ChoiceChip` reusando el styling de `cashflow_tab.dart`.
- **RF-003** (3 métricas globales): `_GlobalCard` con `Row` de `_HeaderMetric` x3 (Promedio prorrateado, Mes en curso, Delta).
- **RF-004** (subtítulo): debajo del card global, texto "Comparación al día D del mes (basado en M meses cerrados)".
- **RF-005** (semáforo global): color del delta + chip "Por debajo / En línea / Por encima" según RN-A10.
- **RF-006** (sección desglose): `_CategoryBreakdown` con `Column` de filas tipo `BaseCard`. Cada fila: badge color+icon, nombre, promedio prorrateado, gasto actual, delta (abs + %).
- **RF-007** (empty state): `_EmptyState` cuando `report.isEmpty` (monthsAvailable == 0).
- **RF-008** (método del service): `Stream<MonthlyAverageReport> monthlyAverage({required int monthsBack, DateTime? now})` en `ReportsService`.
- **RF-009 / RF-010** (modelos): `MonthlyAverageReport` y `CategoryAverageDelta` definidos en `lib/data/reports.dart` junto al resto de modelos del archivo.
- **RF-011** (stream cacheado en state): patrón `late Stream<MonthlyAverageReport>? _reportStream` + `didChangeDependencies` que lo arma una sola vez.
- **RF-012** (re-stream al cambiar N): `_selectMonthsBack(n)` hace `setState(() { _monthsBack = n; _reportStream = _buildStream(); })`.

## Archivos o módulos probablemente afectados

- `mobile/lib/data/reports.dart` — agrega 2 modelos + método nuevo + helpers privados.
- `mobile/lib/screens/reports/monthly_average_tab.dart` — **archivo nuevo**.
- `mobile/lib/screens/reports_screen.dart` — agrega imports, sube `length` a 5, agrega `Tab` + `MonthlyAverageTab`.
- `mobile/pubspec.yaml` — bump `0.10.0+62` → `0.11.0+63` (nuevo feature, minor bump).
- `mobile/android/app/build.gradle.kts` — `versionCode = 63`, `versionName = "0.11.0"` (RF-016 + verify-apk.sh).
- `mobile/test/data/reports_test.dart` — agrega tests del método (~14 unit tests).
- `mobile/test/screens/monthly_average_tab_test.dart` — **archivo nuevo** con widget tests (~4 tests).

## Entidades y estados afectados

- **`JournalEntry`**: solo lectura. Filtros: `kind ∈ {expense, credit_expense}`, `deleted_at IS NULL`, rango temporal `[firstDayOfWindow, now]` con condición compuesta para histórico vs actual.
- **`Category`**: solo lectura para `name`, `color_slug`, `icon_slug`. Categorías con `deleted_at IS NOT NULL` se agregan al bucket "Sin categoría" (consistente con `spendingByCategory`).
- **Sin entidades nuevas**. Sin transiciones de estado nuevas. Sin invariantes nuevas en BD.

## Compatibilidad con datos y procesos existentes

- **Backward compatible al 100%**: solo lee del journal, no muta datos. Funciona sobre cualquier BD existente.
- **Reactividad consistente**: el `watch` re-emite cuando cambian `journal_entries` o `categories` — coherente con cómo lo hacen `spendingByCategory` (re-emite con ambas tablas) y `topMovements`.
- **Sin impacto en backup JSON v1**: no introduce campos nuevos, no toca el formato.
- **Sin impacto en otros tabs de `/reports`**: el `DefaultTabController` solo cambia `length` y agrega un widget hijo.
- **Sin impacto en widget tests existentes**: los tests de los otros tabs verifican comportamiento por tipo (`find.byType(SpendingByCategoryTab)`, etc.), no posición en el TabBar. Solo hay que validar que el tab nuevo no rompe la suite.

## Cambios de datos

No aplica. No hay migración. No hay tablas/columnas nuevas. No hay seeds nuevos.

## Cambios de API

No aplica (no es ERP con HTTP). El cambio es la API pública de `ReportsService`:

```dart
Stream<MonthlyAverageReport> monthlyAverage({
  required int monthsBack,
  DateTime? now,
});
```

Y los 2 modelos públicos nuevos exportados desde el mismo archivo.

## Cambios de integraciones

No aplica.

## Cambios de UI

- Tab nuevo "Promedio" en `/reports`.
- Reusa: `BaseCard`, `formatAmount`, `FincoreColors.{positive, warning, negative, textSubtle, textMuted, textPrimary, accent, surface, border}`, `colorBySlug`, `iconBySlug`.
- Layout: header chips + card global (3 columnas) + subtítulo + sección "Desglose por categoría" con filas.
- Empty state: icono + texto en `Center`.

## Cambios de permisos

No aplica (single-user).

## Riesgos técnicos

- **R-01** (complejidad SQL del prorrateo): la condición compuesta `(histórico con day <= D) OR (mes actual)` es legible pero hay que validarla con tests del filtro temporal. Mitigación: tests UT-03, UT-04, UT-05 cubren explícitamente el límite por día.
- **R-02** (RN-A08, día inexistente en mes histórico): el filtro `day(occurred_at) <= D` ya cubre correctamente este caso porque febrero solo tiene entries hasta el 28-29 — el filtro no excluye nada que no exista. Tests UT-05 + UT-15 validan.
- **R-03** (zona horaria): coherente con el resto del repo, todo en local del dispositivo. `DateTime(y, m, d)` para construir bordes de mes/día. Sin tocar UTC.
- **R-04** (performance con journal grande): la query usa los índices existentes (`idx_entries_occurred_active`, `idx_entries_kind`). Sin nuevos índices necesarios para BD <10k entries. Si Diego escala a 100k+, evaluar índice compuesto en sprint futuro.
- **R-05** (drift `customSelect` reactividad): joinear con `categories` y declarar `readsFrom: {journalEntries, categories}` puede emitir un evento extra cuando se crea/edita una categoría que no tiene movimientos en el rango. Aceptable — el reporte se recomputa pero retorna el mismo resultado.
- **R-06** (precisión de los cálculos): doubles de Dart tienen 64 bits IEEE — suficiente para montos típicos de pesos mexicanos sin precisión decimal crítica. Coherente con el resto de reportes.
- **R-07** (BD recien instalada con 1 mes cerrado vs N=24): RN-A04 dice usar M=1 y reflejarlo en UI. Tests UT-09 + WT-03 cubren.

## Estrategia de pruebas

- **Unit tests** (`test/data/reports_test.dart`): nuevo grupo `monthlyAverage` con ~14 casos cubriendo agregación, prorrateo, RN-A08, kinds, soft delete, categorías archivadas, breakdown, orden, degradación, cero promedio.
- **Widget tests** (`test/screens/monthly_average_tab_test.dart`): nuevo archivo con 4 tests (carga, cambio de preset, empty state, render de breakdown).
- **Sin tests de integración** (no hay HTTP/E2E).
- **Sin tests de migración** (no hay schema bump).
- **Smoke manual** post-implementación.

Detalles completos en `test-plan.md`.

## Estrategia de rollback

- **Revert simple**: el sprint solo agrega archivos nuevos y modifica 3 (`reports.dart`, `reports_screen.dart`, `pubspec.yaml` + `build.gradle.kts`). Un `git revert` deja la app exactamente como antes.
- **Sin schema bump**: no hay migración que deshacer. La BD del usuario no se toca.
- **Sin deps nuevas**: `pubspec.lock` solo cambia por el version bump del propio paquete `fincore`.

## Orden sugerido de implementación

1. **Backend (data layer)** primero: modelos + método del service + tests unit. Le da al frontend un contrato firme.
2. **Frontend** después: tab nuevo + integración en reports_screen + widget tests.
3. **Version bump + smoke** al final.

Detalle en `tasks.md`.

## Casos borde que condicionan la solución

Los casos borde críticos están detallados en `test-plan.md`. Los que **condicionan el diseño** (no solo el testing) son:

- **`now` = primer día del mes** (CB-T01): el filtro `day <= 1` aplica a los meses históricos. Es matemáticamente correcto pero produce números chicos. Validar en UI que no quede mensaje engañoso ("vas 100% abajo" puede ser cierto al día 1).
- **Día D=31 + meses de 28-30 días** (CB-T03 + CB-T12 + RN-A08): el filtro `day <= 31` ya incluye los 28 días de febrero correctamente. No requiere lógica adicional en SQL ni Dart.
- **Categoría archivada con histórico** (CB-T11): el `LEFT JOIN ... AND deleted_at IS NULL` deja `category_id` resuelto como NULL → el bucket "Sin categoría" puede aparecer con histórico grande. Validar en UI que el label es claro y consistente con `spendingByCategory`.
- **Categoría nueva sin histórico pero con gasto actual** (CB-T10): aparece en breakdown con `historicalAverage == 0` y `deltaPercent == null`. La UI debe manejar el delta% null con "—" (RN-A11).
- **Mes cerrado intermedio con 0 entries** (CB-T04): cuenta como mes con gasto = 0 prorrateado. La query devuelve 0 filas para ese mes; el helper de Dart suma 0 al promedio. Validar test que cubre este caso.

## Preguntas o supuestos que siguen afectando la implementación

Todas las preguntas blocking (P-001, P-002, P-003) están **respondidas** y reflejadas en spec.md. No hay bloqueos pendientes.

Supuestos del plan:

- **SP-01**: la query single-shot con `(histórico OR actual)` es preferible a 2 streams combinados. Razón: simplicidad + atomicidad del watch reactivo. Si la query resulta lenta en perf-test futuro, se separa en 2.
- **SP-02**: el helper `_iterateClosedMonths` construye la lista de meses de la ventana en Dart, no en SQL. Razón: SQLite no tiene `generate_series`. Coherente con el patrón de `_iterateMonthsBetween` que ya existe en `reports.dart`.
- **SP-03**: el chip semáforo ("Por debajo / En línea / Por encima") usa los mismos umbrales para global y por categoría (RN-A10). Si en el futuro Diego pide thresholds diferentes por categoría, se agrega como override del modelo `CategoryAverageDelta`.
- **SP-04**: el desglose se ordena en Dart después de procesar las filas SQL. Razón: orden por delta absoluto (no por monto bruto) requiere computar `current - historical / monthsAvailable` antes de ordenar.
- **SP-05**: el version bump es `0.10.0+62 → 0.11.0+63` (minor + 1, build +1). Razón: feature nuevo visible, sin breaking en BD. Si Diego prefiere `0.10.1+63` por ser sprint contenido, ajustar antes de bumpear el gradle.

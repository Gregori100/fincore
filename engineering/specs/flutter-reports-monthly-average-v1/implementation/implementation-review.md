# Implementation Review: flutter-reports-monthly-average-v1

## Resumen de lo implementado

- 5° tab "Promedio mensual" en `/reports` que muestra el gasto promedio mensual prorrateado al mismo día del mes que `now` sobre los últimos N meses cerrados (presets `[1, 3, 6, 12, 24]`, default 3).
- Comparativa contra el gasto del mes en curso con delta absoluto + porcentual + semáforo (verde ≤95%, amarillo 95–110%, rojo >110%) — RN-A10.
- Desglose por categoría con la misma comparación, ordenado por delta absoluto descendente y tiebreak alfabético — RN-A12.
- Modelo `MonthlyAverageReport` + `CategoryAverageDelta` agregados a `lib/data/reports.dart`.
- Método `ReportsService.monthlyAverage({ required int monthsBack, DateTime? now })` con una sola query agregada que combina histórico prorrateado (filtro `day(occurred_at) <= D`) + mes en curso. Stream reactivo sobre `journal_entries` + `categories`.
- Sin schema bump, sin deps nuevas, sin breaking changes.
- Versión bumped a `0.11.0+63`.

## Archivos principales modificados

- `mobile/lib/data/reports.dart` — modelos nuevos + método `monthlyAverage` + helpers privados `_iterateClosedMonths`, `_buildMonthlyAverageReport`, `_monthKey`. ~290 líneas nuevas.
- `mobile/lib/screens/reports/monthly_average_tab.dart` — **archivo nuevo**, 470+ líneas. Tab + 8 widgets internos + 3 helpers de UI.
- `mobile/lib/screens/reports_screen.dart` — agrega 1 import, sube `length: 4 → 5`, agrega `Tab(text: 'Promedio mensual')` + `MonthlyAverageTab()`.
- `mobile/pubspec.yaml` — `version: 0.10.0+62 → 0.11.0+63` + nota del sprint.
- `mobile/android/app/build.gradle.kts` — `versionCode = 63`, `versionName = "0.11.0"`.
- `mobile/test/data/reports_test.dart` — 15 unit tests nuevos en grupo `monthlyAverage`.
- `mobile/test/screens/monthly_average_tab_test.dart` — **archivo nuevo**, 4 widget tests.

## Tareas completadas

- **T001..T004**: modelos + método + helpers en `reports.dart`. ✅
- **T005, T006**: tab + widgets internos. ✅
- **T007**: integración en `reports_screen.dart`. ✅
- **T008..T011**: 15 unit tests del DAO (UT-01..UT-15). ✅
- **T012**: 4 widget tests del tab (WT-01..WT-04). ✅
- **T013, T014**: `flutter analyze` y `flutter test` verdes (321/321). ✅
- **T015**: bump `0.11.0+63`. ✅

## Tareas pendientes

- **T016**: `branch-quality-review` — no lo lancé en este turno (Diego puede dispararlo manualmente desde el chat antes del commit).
- **T017**: smoke manual SM-01..SM-05 — Diego confirma post-instalación del APK.
- **T018**: `resumen-ejecutivo.md` y `resumen-extenso.md` — generados en este mismo cierre.

## Riesgos residuales

- **R-A** (cobertura del modo prorrateado con `day == 31`): UT-05 valida que entries del 28 de febrero cuentan correctamente bajo D=31. La query confía en que el filtro `day <= 31` no excluye nada existente (el día 31 no existe en febrero). Smoke recomendado con datos reales que tengan entries del 31 de algún mes.
- **R-B** (categoría con histórico positivo pero sin movimiento del mes actual aparece en el breakdown — RN-A14 / CB-T11): UT-11 cubre el caso. Visualmente puede sorprender al usuario ("¿por qué aparece una categoría que no usé este mes?"); en uso real puede confirmarse si el copy es claro. Sin cambio en v1.
- **R-C** (performance con journal >10k entries): no medido. La query usa los índices existentes y trabaja sobre un rango acotado a `[windowFrom, now]`. Aceptable para uso típico single-user; si Diego escala, evaluar índice compuesto.
- **R-D** (zona horaria): todo en local del device, coherente con el resto del repo. Si Diego viaja entre zonas horarias mientras tiene la app abierta, podría haber un caso borde teórico, no esperable en uso real.

## Pruebas realizadas

### Unit tests (`mobile/test/data/reports_test.dart`)

- **UT-01**: BD sin entries → `isEmpty == true`. ✅
- **UT-02**: N=1, mes histórico + mes actual completos. ✅
- **UT-03**: prorrateo D=15, entries 14 y 15 cuentan, 16 no. ✅
- **UT-04**: mes en curso suma todos los días [1, now]. ✅
- **UT-05** (RN-A08): D=31 sobre febrero (28 días) — incluye días que existen. ✅
- **UT-06**: categoría archivada → bucket "Sin categoría". ✅
- **UT-07**: soft delete excluye entry. ✅
- **UT-08**: kinds `income`, `transfer`, `debt_payment` NO cuentan; `expense` + `credit_expense` sí. ✅
- **UT-09**: degradación M=3 < N=12. ✅
- **UT-10**: `historicalAverage == 0` → `deltaPercent == null`. ✅
- **UT-11**: categoría con histórico positivo, mes actual = 0 → delta negativo. ✅
- **UT-12**: categoría sin histórico pero con gasto actual. ✅
- **UT-13**: orden del breakdown delta abs DESC + tiebreak alfabético. ✅
- **UT-14**: stream reactivo — cancelar entry re-emite con nuevo total. ✅
- **UT-15**: D=10 sobre 3 meses con 1 entry día 10 cada uno. ✅

### Widget tests (`mobile/test/screens/monthly_average_tab_test.dart`)

- **WT-01**: render con datos: card global + subtítulo + breakdown. ✅
- **WT-02**: cambiar preset 3 → 6 sin error. ✅
- **WT-03**: empty state con BD sin entries. ✅
- **WT-04**: orden del breakdown por delta absoluto desc visible en pantalla. ✅

### Suite completa

- `flutter test`: **321 tests verdes** (antes 302; +19 nuevos).
- `flutter analyze`: 0 errores. 4 hints `info prefer_const_constructors` pre-existentes (tolerados según CLAUDE.md).

## Pruebas recomendadas

- **Smoke SM-01**: instalar el APK `0.11.0+63` sobre BD real y validar que el tab carga sin error con histórico real de Diego.
- **Smoke SM-02**: cambiar entre todos los presets (1, 3, 6, 12, 24) — confirmar que el subtítulo refleja "M meses cerrados" cuando M < N.
- **Smoke SM-03**: crear un gasto grande del mes actual y volver al tab → confirmar reactividad del semáforo.
- **Smoke SM-04**: archivar una categoría con histórico y volver al tab → confirmar que su monto pasa a bucket "Sin categoría".
- **Smoke SM-05**: cancelar un entry histórico desde `/entries` y volver al tab → confirmar que el promedio bajó.

## Posibles regresiones

- **PR-01**: Los otros 4 tabs de `/reports` no fueron modificados. Tests existentes de `cashflow_tab_test.dart`, `top_movements_tab_test.dart`, `balance_at_date_tab_test.dart` siguen verdes — sin regresión detectada.
- **PR-02**: El tab nuevo es el 5° y último, no afecta posición de los anteriores. `reports_deeplink_test.dart` (cierre del primer tab por deep link) sigue verde.
- **PR-03**: `length: 4 → 5` del `DefaultTabController`. Si algún test (interno o futuro) asume length = 4 explícitamente, se rompería. La búsqueda interna no encontró tests con esa dependencia explícita.

## Recomendaciones para code review humano

- Revisar la query SQL del método `monthlyAverage` en `reports.dart`: la condición compuesta `(occurred_at < firstDayOfCurrentMonth AND day(occurred_at) <= D) OR occurred_at >= firstDayOfCurrentMonth` es legible pero merece atención. Tests UT-03, UT-04 y UT-05 la blindan.
- El método `_buildMonthlyAverageReport` divide el histórico por `monthsAvailable` global (no por meses con gasto de cada categoría) — decisión documentada para mantener consistencia entre delta global y delta por categoría. Si Diego prefiere "promedio condicional al uso", se cambia y se actualizan tests.
- La regla RN-A10 del semáforo se aplica idénticamente al delta global y por fila. Si en uso real se sienten distintos thresholds para "delta personal" vs "delta por categoría", se parametriza.
- El label del tab es "Promedio mensual" (no "Promedio") para evitar colisión con la métrica "Promedio" del header. Diego puede cambiarlo en `reports_screen.dart` línea ~36 si prefiere otro texto.
- No se invocó `branch-quality-review`; Diego puede dispararlo manualmente antes del commit final si quiere una auditoría adversarial.

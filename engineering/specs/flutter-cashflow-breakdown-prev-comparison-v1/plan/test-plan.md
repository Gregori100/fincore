# Plan de pruebas — flutter-cashflow-breakdown-prev-comparison-v1

## Casos borde detectados

Consolidación de CB-01..15 de la spec + CB-P01..P03 nuevos del plan:

- **CB-01**: mes previo vacío → todos los chips `—` (buckets y summary).
- **CB-02**: bucket actual con categoría nueva (sin match previo) → chip `—`.
- **CB-03**: bucket solo en previo → NO aparece en la lista (RN-CP06).
- **CB-04**: "Sin categoría" en ambos meses → match por `null` → delta calculado.
- **CB-05**: bucket idéntico → `direction=flat, percent=0`.
- **CB-06**: `up` con `+100%` (actual = 2× previo).
- **CB-07**: `down` con `-50%` (actual = 0.5× previo).
- **CB-08**: previo = 0 y actual > 0 → delta null (RN-CP09).
- **CB-09**: neto salta signo (previo positivo, actual negativo) → delta correcto sobre magnitudes.
- **CB-10**: rollover enero → diciembre año anterior.
- **CB-11**: timezone borderline (mismo edge sprint padre R6). Documentado.
- **CB-12**: reactividad — registrar en mes previo → re-emit.
- **CB-13**: reactividad — cancelar único movimiento del bucket previo → chip del bucket actual pasa de número a `—`.
- **CB-14**: categoría archivada en actual pero activa en previo → LEFT JOIN vacío colapsa a "Sin categoría"; si hay bucket "Sin categoría" en previo, matchea.
- **CB-15**: muchos buckets (20+ categorías) → verificar layout no rompe en cel angosto (SM).
- **CB-P01** (plan): `applies_to='both'` que aparece en gasto previo + ingreso actual → NO matchea, ambos sin delta.
- **CB-P02** (plan): movimiento cambiado de fecha entre meses con sheet abierto → estado final correcto tras re-emit.
- **CB-P03** (plan): cambiar rango del tab base con sheet abierto → sheet cachea `monthAnchor` y no se re-computa (consistente con CB-17 padre).

## Pruebas unitarias necesarias

Sobre `mobile/test/data/reports_test.dart` (grupo nuevo `cashflowMonthBreakdown — comparación vs mes previo`):

- **UT-CP01**: seed mes actual (junio 2024) con 1 expense $2000 en Comida + mes previo (mayo 2024) con 1 expense $1000 en Comida → `expenseBuckets[0].delta.direction == up, percent == 100.0`. Cubre CB-06.
- **UT-CP02**: seed actual $500 vs previo $1000 en la misma categoría → `direction == down, percent == 50.0`. Cubre CB-07.
- **UT-CP03**: seed idéntico $1000 en ambos meses → `direction == flat, percent close to 0` (con `abs(diff) < 0.01`). Cubre CB-05.
- **UT-CP04**: seed actual $500, previo sin ese bucket → `delta == null`. Cubre CB-02, CB-08.
- **UT-CP05**: seed bucket "Sin categoría" en ambos meses (movimientos sin categoryId) → matcheado por null. Cubre CB-04.
- **UT-CP06**: bucket solo en el mes previo (aparece en mayo pero no en junio) → NO aparece en `expenseBuckets` del breakdown de junio. Cubre CB-03.
- **UT-CP07**: `monthAnchor = DateTime(2026, 1, 15)` → mes previo debe ser `DateTime(2025, 12, 1)`. Sembrar movimiento en diciembre 2025 → aparece como base de comparación en enero 2026. Cubre CB-10.
- **UT-CP08**: reactividad — `emitsThrough` con `predicate<MonthBreakdown>` tras registrar un movimiento en el mes previo → el delta del bucket actual se actualiza. Cubre CB-12.
- **UT-CP09**: neto salta signo — seed mes previo `net = +500` (ingreso solo), mes actual `net = -300` (solo gasto) → `deltaNet.direction == down`, `percent == 160.0` (`|(-300) - 500| / |500| * 100`). Cubre CB-09.

Total UT servicio: 9. Cobertura de 15/18 casos borde explícitamente. CB-11 (timezone) heredado del sprint padre; CB-13 y CB-14 (reactividad archive + rename) cubiertos lógicamente por `readsFrom: categories` del sprint padre + guard de `applies_to == null`. CB-15 en smoke.

## Pruebas de integracion o API necesarias

No aplica.

## Pruebas de UI o flujo necesarias si aplica

Sobre `mobile/test/screens/cashflow_tab_test.dart` (agregar al final del archivo):

- **WT-CP01**: seed 2 meses con overlap en Comida (previo $1000, actual $2000) → tap fila mes actual → sheet abre → verificar por `find.byIcon(Icons.arrow_upward)` que el chip up está presente + verificar el texto `+100.0%`. Verificar color rojo (bolsillo bolsillo perjudicado por más gasto) buscando `Icon(color: FincoreColors.negative)`.
- **WT-CP02**: seed solo mes actual sin previo → tap fila → sheet abre → verificar `find.text('—')` en el chip.

Total WT: 2. Los tests widget del sprint padre (WT-CB01..05) siguen verdes con la extensión aditiva.

## Pruebas de permisos y seguridad si aplica

No aplica.

## Pruebas de datos, migracion o compatibilidad si aplica

No aplica. Cero schema, cero migración.

Blindaje de compat:

- **RT-01**: los 21 tests del sprint padre siguen verdes.
- **RT-02**: suite completa ≥ 570 verdes (560 baseline + ~10 nuevos).
- **RT-03**: `flutter analyze` sin errores nuevos.

## Pruebas de regresion sobre flujos existentes

- **RT-04**: otros 10 tabs de `/reports` sin cambios.
- **RT-05**: `cashflowByMonth` base sin cambios; sus tests siguen verdes.
- **RT-06**: `EntriesFilters.forMonth` sin cambios; el drill-down del sprint padre sigue funcionando.
- **RT-07**: Dashboard, `/entries`, form de movimiento, backup — sin cambios.

## Pruebas manuales o smoke tests necesarios

- **SM-01**: `/reports` → Cashflow → tap fila junio con datos → sheet abre. Verificar chips en filas con delta calculado + `—` en filas sin previo.
- **SM-02**: seed BD nueva con solo el mes actual → todos los chips (filas + summary) muestran `—`.
- **SM-03**: verificar semántica de color: gastos con `+%` en rojo, `-%` en verde; ingresos al revés. Neto sube = verde.
- **SM-04**: con sheet abierto, registrar un expense en el mes previo desde `/entries` → volver al sheet (o dejarlo abierto) → chip del bucket recalcula.
- **SM-05**: renombrar categoría del mes visible con sheet abierto → chip no se rompe (match por `categoryId`, no nombre).

## Datos de prueba recomendados

Setup UT (in-memory BD):

- Bolsa (seed default) + debit `Banamex` + credit `Visa`.
- Categorías `catComida` (expense), `catRenta` (expense), `catSueldo` (income).
- `monthAnchor = DateTime(2024, 6, 15)`. Mes previo = mayo 2024 (`DateTime(2024, 5, 1)`).
- Sembrar movimientos con `occurredAt = DateTime(2024, m, d, 12)` para evitar edge timezone.

Setup widget test (`pumpFincoreApp` con `seed`):

- Similar al UT pero con anchor = mes calendario actual (`DateTime.now()`).
- 1 expense en el mes actual + 1 expense en el mes previo con la misma categoría.

## Comandos o validaciones locales sugeridas

```bash
cd mobile
flutter analyze
flutter test test/data/reports_test.dart --plain-name 'comparación vs mes previo'
flutter test test/screens/cashflow_tab_test.dart --plain-name 'WT-CP'
flutter test
flutter build apk --release --split-per-abi
../scripts/verify-apk.sh
```

## Criterios minimos para aprobar la implementacion

- 11 tests nuevos verdes (9 UT servicio + 2 widget).
- `flutter test` completo ≥ 571 verdes.
- `flutter analyze` limpio.
- APK release build OK; `verify-apk.sh` OK con `versionCode 2090 / versionName 0.18.0`.
- SM-01..05 confirmados por Diego en cel real (batch con los 12 pendientes documentados en memoria).

## Validacion final recomendada

Ejecutar `branch-quality-review` con slug `flutter-cashflow-breakdown-prev-comparison-v1` antes del commit final. Foco:

- Correctness del cálculo del delta (magnitud + direction).
- Semántica de color `_deltaColor` (matriz income/expense × up/down/flat).
- Match por `categoryId` con null para "Sin categoría".
- Guard de división por cero (RN-CP09).
- Rollover de enero → diciembre año anterior.
- Signo del neto que salta.
- Layout del chip en cel angosto (verificar en SM-01).
- Regresión de los 21 tests del sprint padre.

Si no está disponible, checklist manual:

1. `git diff HEAD` limpio y acotado.
2. `flutter analyze` limpio.
3. `flutter test` verde ≥ 571.
4. UT-CP08 usa `emitsThrough` (no `Future.delayed`).
5. `DateTime(y, m-1, 1)` maneja el rollover.
6. `Map<String?, ...>` acepta null como key.
7. Version bump coincide en `pubspec.yaml` y `build.gradle.kts`.

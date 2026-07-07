# Plan de pruebas — flutter-reports-spending-heatmap-v1

## Casos borde detectados

- **CB-01**: año sin gastos → Map vacío + `total=0` + `daysWithSpending=0` + cuartiles=0.
- **CB-02**: año con 1 solo gasto → fallback RN-HM05: `p25=p50=p75=monto`, día se pinta `veryHigh`.
- **CB-03**: año con 2 gastos distintos → fallback: ambos `veryHigh`.
- **CB-04**: año con 3 gastos distintos → fallback: los 3 `veryHigh`.
- **CB-05**: año con 4 gastos ordenables → cuartiles calculados; el gasto menor es `low`, el mayor es `veryHigh`.
- **CB-06**: año con 100 gastos → cuartiles distribuidos; cada `IntensityLevel` tiene entries.
- **CB-07**: día con múltiples gastos (5 expense el mismo día) → un solo entry en el `Map` con `total = SUM`.
- **CB-08**: gastos de otros kinds (`income`, `transfer`, `debt_payment`) NO cuentan aunque estén en el rango.
- **CB-09**: `credit_expense` sí cuenta como gasto (RN-HM01).
- **CB-10**: entry soft-deleted no cuenta (RN-HM03).
- **CB-11**: entry en el borde `firstDayOfYear 00:00:00` → cae en día 1 de enero.
- **CB-12**: entry en el borde `lastDayOfYear 23:59:59.999` → cae en 31 de diciembre (blindado por `'localtime'`).
- **CB-13**: entries del año anterior/siguiente NO cuentan.
- **CB-14**: registrar/cancelar gasto con el tab abierto → re-emit reactivo (RN-HM12).
- **CB-15**: año bisiesto (ej: 2028, 2032) → grid acomoda 366 días.
- **CB-16**: 1 de enero en jueves (ej: 2026) → primera columna del grid tiene solo 4 celdas visibles.
- **CB-17**: tap en día → deep link con `datePreset=custom + from=to=día + kinds=['expense','credit_expense']`.
- **CB-18**: tap en celda de spillover (fuera del año en el grid) → ignorado (verificación `day.year == _focusedYear`).
- **CB-19**: cambio de año con las flechas → stream se recrea, marcadores del nuevo año visibles.
- **CB-20**: categoría archivada asociada a gastos → irrelevante (query no joinea categories).
- **CB-21**: entries con `amount = 0` (edge legacy) → `SUM(amount)` puede quedar 0, día NO entra al `Map`.
- **CB-22**: `SUM(amount)` con floats grandes (>$1M) → precisión doble suficiente para totales de año.
- **CB-23**: cuartiles con ties (varios días con el mismo monto) → interpolación estándar los maneja; no requiere lógica especial.

## Pruebas unitarias necesarias

Sobre `mobile/test/data/reports_test.dart` (grupo nuevo `spendingHeatmap (sprint spending-heatmap)`):

- **UT-HM01**: año sin gastos → `SpendingHeatmap.total==0`, `daySpending.isEmpty`, `daysWithSpending==0`. Cubre CB-01.
- **UT-HM02**: 1 expense de $100 el día 15/06 → `daySpending` con 1 entrada, `total==100`, `daysWithSpending==1`, cuartiles = 100 (fallback). El día se pinta `veryHigh`. Cubre CB-02.
- **UT-HM03**: 3 expenses de montos distintos → todos `veryHigh` (fallback RN-HM05). Cubre CB-04.
- **UT-HM04**: 4 expenses de 100/200/300/400 → cuartiles calculados; 100=`low`, 200=`medium`, 300=`high`, 400=`veryHigh`. Cubre CB-05.
- **UT-HM05**: `credit_expense` cuenta como gasto (RN-HM01). Cubre CB-09.
- **UT-HM06**: `income`, `transfer`, `debt_payment` NO cuentan aunque estén en el rango. Cubre CB-08.
- **UT-HM07**: entry soft-deleted no cuenta. Cubre CB-10.
- **UT-HM08**: día con 3 gastos → 1 entrada en el `Map` con `total = SUM`. Cubre CB-07.
- **UT-HM09**: entry en el borde `2026-12-31 23:59:59.999` → cae en 31/12 (por `'localtime'`). Cubre CB-12.
- **UT-HM10**: entries del año anterior/siguiente NO cuentan. Cubre CB-13.
- **UT-HM11**: reactividad — registrar expense con el stream escuchando → re-emit con nueva entrada. Usar `emitsThrough` (NO `Future.delayed`). Cubre CB-14.

Sobre `mobile/test/data/reports_test.dart` (grupo nuevo `SpendingHeatmap.intensityFor (unit tests del modelo)`):

- **UT-HM12**: `intensityFor` con día ausente del Map → `IntensityLevel.none`. Cubre RN-HM06 caso "clave ausente".
- **UT-HM13**: `intensityFor` con `total(day) == 0` → `IntensityLevel.none` (defensivo). No debería ocurrir en la práctica (el helper omite valores 0 del `Map`).
- **UT-HM14**: `intensityFor` con `0 < total <= p25` → `low`.
- **UT-HM15**: `intensityFor` con `p25 < total <= p50` → `medium`; con `p50 < total <= p75` → `high`; con `total > p75` → `veryHigh`.
- **UT-HM16**: fallback `p25=p50=p75=max` → todos los días con gasto son `veryHigh`.

## Pruebas de integracion o API necesarias

No aplica. App local-first.

## Pruebas de UI o flujo necesarias si aplica

Sobre `mobile/test/screens/reports/spending_heatmap_tab_test.dart` (nuevo):

- **WT-HM01**: render inicial monta `SpendingHeatmapTab` con año actual. Verifica `find.byType(CustomPaint)` presente (el painter del heatmap).
- **WT-HM02**: seed con 1 expense el 15/06 del año actual → el widget monta con datos. Difícil verificar el color por celda (pintor no expone widgets hijos); verificamos que el `SpendingHeatmap` se recibió en el `StreamBuilder` inspeccionando presencia del `CustomPaint`. Detalle visual se valida en smoke.
- **WT-HM03**: tap en la flecha derecha del header → año cambia; `CustomPaint` sigue montado.
- **WT-HM04**: seed con 1 expense + tap en la coordenada aproximada del día → navega a `/entries` filtrado (verificar por `find.text('DescripciónSembrada')`).

## Pruebas de permisos y seguridad si aplica

No aplica.

## Pruebas de datos, migracion o compatibilidad si aplica

No aplica. Sin schema bump.

## Pruebas de regresion sobre flujos existentes

- **RT-01**: `flutter test` completo verde. Baseline 492 + 20 nuevos aprox = ≥ 512 esperados. Ajustar según distribución final.
- **RT-02**: los 9 tabs anteriores de `/reports` siguen verdes en sus widget tests.
- **RT-03**: `credit_cards_tab_test.dart` WT-15 conteo `findsNWidgets(9)` → `findsNWidgets(10)`.
- **RT-04**: onboarding tests siguen verdes (no verifican conteo de filas ni texto exacto).
- **RT-05**: help tests siguen verdes (no verifican texto completo del bullet).
- **RT-06**: el `movementsByDay` del sprint calendar (9no tab) sigue funcionando (no se modificó).

## Pruebas manuales o smoke tests necesarios

- **SM-01**: Diego abre `/reports` → ve 10 tabs y "Heatmap" al final. TabBar scrollea sin overflow horizontal.
- **SM-02**: entra al tab → ve el año actual con celdas coloreadas según los gastos reales de Diego. Etiquetas de mes visibles en español; etiquetas de día de semana (Lun/Mié/Vie) legibles.
- **SM-03**: tapea una celda con gasto → `/entries` abre con filtro pre-cargado (`Este día` visible en el header + solo `Gasto` y `Gasto a tarjeta` en kinds). Verificar visualmente que los ingresos y transfers del mismo día NO aparecen.
- **SM-04**: tapea la flecha izquierda del header → año anterior visible; grid se recarga con los gastos históricos.
- **SM-05**: registra un gasto nuevo desde el FAB → vuelve al tab → celda del día nuevo aparece o intensifica sin recargar (reactividad).
- **SM-06**: onboarding "Ver tour de bienvenida" desde Ayuda → slide 3 muestra 10 filas legibles (scroll interno si es necesario); la 10ma es "Heatmap".
- **SM-07**: Ayuda → tile "¿Cómo se calculan los reportes?" menciona "10 pestañas" + bullet del heatmap.
- **SM-08 (opcional)**: cel de ancho chico (360 px o menos) → grid renderiza sin scroll horizontal; celdas legibles aunque estrechas.

## Datos de prueba recomendados

Setup para tests unitarios (in-memory BD):

- Bolsa (seed default) + 1 cuenta debit "BBVA_HM" + 1 cuenta credit "Visa_HM".
- Año `2026` como año determinista (no bisiesto).
- Categoría `catComida_HM` (applies_to='expense').
- Entries:
  - 4 expenses de $100/$200/$300/$400 en distintos días de junio → cuartiles calculables.
  - 1 credit_expense de $500 → cuenta como gasto.
  - 1 income + 1 transfer + 1 debt_payment el mismo día → NO cuentan.
  - 1 expense soft-deleted → NO cuenta.
  - 1 expense en el borde `2026-12-31 23:59:59.999` → cae en último día.
  - 1 expense en `2025-12-31 23:59:59.999` → NO cuenta (año anterior).

## Comandos o validaciones locales sugeridas

```bash
cd mobile
flutter analyze
flutter test test/data/reports_test.dart --plain-name 'spendingHeatmap'
flutter test test/data/reports_test.dart --plain-name 'intensityFor'
flutter test test/screens/reports/spending_heatmap_tab_test.dart
flutter test
flutter build apk --release --split-per-abi
../scripts/verify-apk.sh
~/Android/Sdk/platform-tools/adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

## Criterios minimos para aprobar la implementacion

- 20 tests nuevos verdes (11 UT servicio + 5 UT modelo + 4 widget; ajustar según distribución final).
- `flutter test` completo ≥ 512 tests verdes.
- `flutter analyze` sin errores nuevos.
- APK release build OK; `verify-apk.sh` OK con `versionCode 2083 / versionName 0.16.1`.
- SM-01..07 confirmados por Diego en cel real.
- Delta `heatmap día X reporta $Y → drill-down suma exactamente $Y` en 0 casos observados en la BD real.

## Validacion final recomendada

Ejecutar la skill `branch-quality-review` con slug `flutter-reports-spending-heatmap-v1` antes del commit final. La skill genera su propio reporte en `engineering/quality-review/<slug>/`.

Si no está disponible, checklist manual:

1. `git diff HEAD` — solo archivos listados en `plan.md`.
2. `flutter analyze` limpio.
3. `flutter test` verde ≥ 512.
4. UT-HM11 usa `emitsThrough` (NO `Future.delayed`).
5. `RN-HM05` (fallback `n<4`) verificado por UT-HM02, UT-HM03, UT-HM16.
6. `RN-HM01` (kinds excluidos) verificado por UT-HM06, UT-HM09.
7. `RN-HM12` (reactividad) verificado por UT-HM11.
8. Version bump coincide en `pubspec.yaml` y `build.gradle.kts`.

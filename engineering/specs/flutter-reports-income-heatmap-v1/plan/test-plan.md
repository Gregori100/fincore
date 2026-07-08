# Plan de pruebas — flutter-reports-income-heatmap-v1

## Casos borde detectados

- **CB-01**: año sin ingresos → `dayIncome` vacío + cuartiles=0 + banner
  visible + leyenda oculta.
- **CB-02**: año con 1 solo income → fallback RN-IHM05, día pintado
  `veryHigh`.
- **CB-03**: año con 2-3 incomes → fallback, todos `veryHigh`.
- **CB-04**: año con 4 incomes ordenables → cuartiles calculados;
  niveles distintos.
- **CB-05**: `expense` NO cuenta (RN-IHM01).
- **CB-06**: `credit_expense` NO cuenta.
- **CB-07**: `transfer` NO cuenta.
- **CB-08**: `debt_payment` NO cuenta.
- **CB-09**: income soft-deleted no cuenta (RN-IHM03).
- **CB-10**: día con múltiples incomes (ej: 2 sueldos + 1 freelance el
  mismo día) → 1 entrada con `total = SUM`.
- **CB-11**: income en el borde `firstDayOfYear 00:00:00` → cae en día
  1 (blindaje `localtime`).
- **CB-12**: income en el borde `lastDayOfYear 23:59:59.999` → cae en
  31/12.
- **CB-13**: entries de otros años NO cuentan.
- **CB-14**: cancelar income con el tab abierto → re-emit reactivo
  (RN-IHM12).
- **CB-15**: registrar nuevo income con stream escuchando → re-emit con
  celda del día actualizada.
- **CB-16**: año bisiesto (2028) → grid del mes de febrero con 29 días.
- **CB-17**: tap en día del sheet → deep link con `datePreset=custom +
  from=to=día + kinds=['income']` (blindaje del filter). Sembrar 1
  income + 1 expense el mismo día; verificar solo income visible.
- **CB-18**: tap en spillover del sheet: ignorado (`SizedBox.shrink()`
  sin `InkWell`).
- **CB-19**: cambio de año con las flechas → stream se recrea, celdas
  del nuevo año visibles.
- **CB-20**: categoría archivada asociada a incomes → irrelevante
  (query no joinea `categories`).
- **CB-21**: income con `amount = 0` (edge legacy) → `SUM(amount)` puede
  quedar 0, día NO entra al `Map`.
- **CB-22**: cambio de `applies_to` de una categoría income (nunca
  afecta al heatmap; el kind del entry es fijo desde el registro).

## Pruebas unitarias necesarias

Sobre `mobile/test/data/reports_test.dart` (grupo nuevo `incomeHeatmap
(sprint income-heatmap)`):

- **UT-IHM01**: año sin incomes → `IncomeHeatmap.total==0`,
  `dayIncome.isEmpty`, `daysWithIncome==0`. Cubre CB-01.
- **UT-IHM02**: 1 income de $5000 el día 15/06 → fallback, cuartiles=0,
  `veryHigh`. Cubre CB-02.
- **UT-IHM03**: 4 incomes de 1000/2000/3000/4000 → cuartiles calculados;
  niveles distintos. Cubre CB-04.
- **UT-IHM04**: `expense` NO cuenta (RN-IHM01). Cubre CB-05.
- **UT-IHM05**: `credit_expense` NO cuenta. Cubre CB-06.
- **UT-IHM06**: `transfer` NO cuenta. Cubre CB-07.
- **UT-IHM07**: `debt_payment` NO cuenta. Cubre CB-08.
- **UT-IHM08**: income soft-deleted no cuenta. Cubre CB-09.
- **UT-IHM09**: día con 3 incomes → 1 entrada con total = SUM. Cubre
  CB-10.
- **UT-IHM10**: income en borde `2026-12-31 23:59:59.999` → cae en
  31/12 (por `'localtime'`). Cubre CB-12.
- **UT-IHM11**: entries de otros años NO cuentan. Cubre CB-13.
- **UT-IHM12**: reactividad — registrar income con `emitsThrough` (no
  `Future.delayed`). Cubre CB-15.

Sobre `mobile/test/data/reports_test.dart` (grupo nuevo
`IncomeHeatmap.intensityFor (unit tests del modelo)`):

- **UT-IHM13**: día ausente del Map → `IntensityLevel.none`.
- **UT-IHM14**: día con total 0 (defensivo) → `none`.
- **UT-IHM15**: `0 < total ≤ p25` → `low`.
- **UT-IHM16**: `intensityFor` con los 3 niveles medium/high/veryHigh.
- **UT-IHM17**: fallback `p25=p50=p75=0` → todos veryHigh (RN-IHM05).

## Pruebas de integracion o API necesarias

No aplica.

## Pruebas de UI o flujo necesarias si aplica

Sobre `mobile/test/screens/reports/income_heatmap_tab_test.dart`
(nuevo):

- **WT-IHM01**: BD vacía → tab monta con banner "Sin ingresos
  registrados en este año" (leyenda oculta por consolidación).
- **WT-IHM02**: seed con 1 income → tab monta con subtexto "1 día con
  ingreso" + leyenda visible (Menos/Más).
- **WT-IHM03**: tap en flecha izquierda del header cambia el año.
- **WT-IHM04**: tap en mini abre bottom sheet + tap en día → drill-down
  con `kinds=['income']`. Sembrar 1 income + 1 expense el mismo día;
  verificar que solo el income aparece en `/entries` (blindaje del
  filter). Cubre CB-17.

## Pruebas de permisos y seguridad si aplica

No aplica.

## Pruebas de datos, migracion o compatibilidad si aplica

No aplica. Sin schema bump.

## Pruebas de regresion sobre flujos existentes

- **RT-01**: `flutter test` completo verde. Baseline 519 + 22 nuevos
  aprox (12 UT servicio + 5 UT modelo + 4-5 widget) = ≥ 541 esperados.
- **RT-02**: los 10 tabs anteriores de `/reports` siguen verdes.
- **RT-03**: `credit_cards_tab_test.dart` WT-15 conteo
  `findsNWidgets(10)` → `findsNWidgets(11)`.
- **RT-04**: onboarding tests siguen verdes (no verifican conteo ni
  texto exacto).
- **RT-05**: help tests siguen verdes.
- **RT-06**: `spendingHeatmap` del 10º tab sigue funcionando (no se
  modificó).

## Pruebas manuales o smoke tests necesarios

- **SM-01**: Diego abre `/reports` → ve 11 tabs y "Heatmap ingresos"
  al final. TabBar scrollea sin overflow horizontal (validar cel chico).
- **SM-02**: entra al tab → mini-heatmaps del año actual con celdas
  verdes en los días donde registró ingresos reales (sueldo,
  freelance, etc.).
- **SM-03**: tapea un mini → sheet expandido con nombre del mes en
  español + celdas grandes con números.
- **SM-04**: tapea un día con ingreso → `/entries` abre filtrado a ese
  día + solo ingresos (verificar visualmente que gastos y transfers del
  mismo día NO aparecen).
- **SM-05**: cambia al año anterior con la flecha izquierda → grid
  recarga.
- **SM-06**: registra un income nuevo desde el FAB → vuelve al tab →
  celda del día aparece o intensifica sin recargar.
- **SM-07**: onboarding "Ver tour de bienvenida" desde Ayuda → slide 3
  muestra 11 filas legibles; la 11ª es "Heatmap ingresos" en verde.
- **SM-08**: FAQ del Help menciona "11 pestañas" + bullet nuevo.

## Datos de prueba recomendados

Setup para tests unitarios (in-memory BD):

- Bolsa + 1 cuenta debit + 1 cuenta credit.
- Año `2026` como año determinista.
- Categoría `catSueldo` (`applies_to='income'`), `catComida`
  (`applies_to='expense'`).
- Entries:
  - 4 incomes de $1000/$2000/$3000/$4000 en distintos días → cuartiles
    calculables.
  - 1 income soft-deleted → NO cuenta.
  - 1 expense el mismo día que un income → verifica que expense NO
    cuenta.
  - 1 transfer + 1 debt_payment → NO cuentan.
  - 1 income en el borde `2026-12-31 23:59:59.999`.
  - 1 income en `2025-12-31` → NO cuenta (año anterior).

## Comandos o validaciones locales sugeridas

```bash
cd mobile
flutter analyze
flutter test test/data/reports_test.dart --plain-name 'income-heatmap'
flutter test test/data/reports_test.dart --plain-name 'IncomeHeatmap.intensityFor'
flutter test test/screens/reports/income_heatmap_tab_test.dart
flutter test
flutter build apk --release --split-per-abi
../scripts/verify-apk.sh
~/Android/Sdk/platform-tools/adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

## Criterios minimos para aprobar la implementacion

- 17 tests nuevos aprox (12 UT servicio + 5 UT modelo + 4 widget;
  ajustar según distribución final).
- `flutter test` completo ≥ 534 verdes (519 baseline + ~17 nuevos;
  ajustar).
- `flutter analyze` sin errores nuevos.
- APK release build OK; `verify-apk.sh` OK con
  `versionCode 2086 / versionName 0.16.4`.
- SM-01..08 confirmados por Diego en cel real.
- Delta `heatmap ingresos día X reporta $Y → drill-down suma
  exactamente $Y` en 0 casos observados en la BD real.

## Validacion final recomendada

Ejecutar la skill `branch-quality-review` con slug
`flutter-reports-income-heatmap-v1` antes del commit final. La skill
genera su propio reporte en
`engineering/quality-review/<slug>/`.

Si no está disponible, checklist manual:

1. `git diff HEAD` — solo archivos listados en `plan.md`.
2. `flutter analyze` limpio.
3. `flutter test` verde ≥ 534.
4. UT-IHM12 usa `emitsThrough` (NO `Future.delayed`).
5. RN-IHM01 (kinds excluidos) verificado por UT-IHM04..07.
6. RN-IHM05 (fallback n<4) verificado por UT-IHM02 y UT-IHM17.
7. WT-IHM04 valida el filter `kinds=['income']` explícitamente.
8. Version bump coincide en `pubspec.yaml` y `build.gradle.kts`.

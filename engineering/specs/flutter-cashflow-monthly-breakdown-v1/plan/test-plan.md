# Plan de pruebas — flutter-cashflow-monthly-breakdown-v1

## Casos borde detectados

Consolidación de CB-01..CB17 de la spec + CB-P01..CB-P05 nuevos del
plan:

- **CB-01**: Mes sin movimientos (o todo transfers/debt_payments) →
  ambos buckets vacíos → sheet muestra fallback "Sin movimientos en
  este mes."
- **CB-02**: Mes con solo ingresos → sección de gastos oculta.
- **CB-03**: Mes con solo gastos → sección de ingresos oculta.
- **CB-04**: Todos los movimientos con `category_id IS NULL` →
  bucket único "Sin categoría" con percent 100%.
- **CB-05**: Categoría archivada con movimientos en el mes → migra a
  "Sin categoría" (LEFT JOIN filtra `deleted_at IS NULL`).
- **CB-06**: Categoría `applies_to='income'` con `credit_expense` →
  bucket "Sin categoría" de gastos (RN-CB03).
- **CB-07**: Categoría `applies_to='expense'` con `income` → bucket
  "Sin categoría" de ingresos (RN-CB04).
- **CB-08**: Múltiples movimientos misma categoría → `SUM(amount)`
  correcto.
- **CB-09**: Movimiento cancelado (`deleted_at IS NOT NULL`) → no
  cuenta.
- **CB-10**: Registrar movimiento con sheet abierto → re-emite.
- **CB-11**: Cancelar movimiento con sheet abierto → re-emite; si era
  el único de su categoría desaparece esa entrada.
- **CB-12**: Renombrar categoría con sheet abierto → re-emite con
  nueva label.
- **CB-13**: Archivar categoría con movimientos del mes visible →
  re-emite; los buckets afectados migran a "Sin categoría".
- **CB-14**: Timezone borderline — movimiento `31/mayo 23:30 UTC` que
  localmente cae en `1/junio 00:30` → cuenta en junio con
  `'localtime'`.
- **CB-15**: Muchos buckets (30+ categorías en un mes) → scroll
  interno del sheet sin overflow.
- **CB-16**: Drill-down "Ver movimientos" al último día del mes con
  hora 23:59:59.999 → filtro `to` inclusivo con subsegundo.
- **CB-17**: Cambiar rango del tab base con sheet abierto → sheet
  sigue mostrando el mes original (cachea `monthAnchor`).
- **CB-P01**: `applies_to='both'` NO cae a "Sin categoría". Se cuenta
  en el bucket que corresponde al kind del movimiento.
- **CB-P02**: `category_id` con FK huérfana (backup legacy) → LEFT
  JOIN devuelve category null → "Sin categoría".
- **CB-P03**: `amount = 0` → filtrado en el helper, no aparece en la
  lista.
- **CB-P04**: `amount < 0` (imposible en el schema pero defensivo) →
  filtrado igual.
- **CB-P05**: Categoría con `applies_to='both'` y 2 movimientos del
  mes (uno income + uno expense) → aparece 2 veces, una en cada
  sección con su monto respectivo.

## Pruebas unitarias necesarias

Sobre `mobile/test/data/reports_test.dart` (grupo nuevo
`cashflowMonthBreakdown (sprint monthly-breakdown)`):

- **UT-CB01**: mes sin movimientos → ambos buckets vacíos, totales
  0. Cubre CB-01.
- **UT-CB02**: mes con solo ingresos → `expenseBuckets` vacía,
  `incomeBuckets` con 1+ entradas. Cubre CB-02.
- **UT-CB03**: mes con solo gastos → simétrico. Cubre CB-03.
- **UT-CB04**: agregación básica — 3 categorías de gasto con
  distintos montos → orden desc por amount + percents correctos
  (suman 100). Cubre CB-08.
- **UT-CB05**: uncategorized — `category_id IS NULL` cae al bucket
  "Sin categoría" con `categoryId=null`, `label='Sin categoría'`.
  Cubre CB-04.
- **UT-CB06**: categoría archivada con gastos → migra a "Sin
  categoría". Cubre CB-05.
- **UT-CB07**: categoría con `applies_to='income'` que tiene un
  `credit_expense` → bucket "Sin categoría" de gastos. Cubre CB-06.
- **UT-CB08**: categoría con `applies_to='expense'` que tiene un
  `income` → bucket "Sin categoría" de ingresos. Cubre CB-07.
- **UT-CB09**: categoría con `applies_to='both'` + income + expense
  del mismo mes → aparece 2 veces, una en cada sección. Cubre CB-P05.
- **UT-CB10**: movimiento cancelado (`deleted_at`) no cuenta. Cubre
  CB-09.
- **UT-CB11**: `transfer` y `debt_payment` no cuentan (RN-CB02).
- **UT-CB12**: reactividad — registrar movimiento nuevo re-emite el
  stream. Usa `emitsThrough` con `predicate`. Cubre CB-10.
- **UT-CB13**: reactividad — renombrar categoría del mes visible
  re-emite con nueva label. Usa `emitsThrough`. Cubre CB-12.

Sobre `mobile/test/data/entries_filters_test.dart` (o inline en un
archivo existente, confirmar en T001):

- **UT-CB14**: `EntriesFilters.forMonth` para junio 2026 → `from =
  2026-06-01 00:00`, `to = 2026-06-30 23:59:59.999`.
- **UT-CB15**: `EntriesFilters.forMonth` para febrero 2024 (bisiesto)
  → `to = 2024-02-29 23:59:59.999`.

## Pruebas de integracion o API necesarias

No aplica.

## Pruebas de UI o flujo necesarias si aplica

Sobre `mobile/test/screens/cashflow_tab_test.dart` (agregar al final
del archivo):

- **WT-CB01**: seed con 1 expense en un mes específico → abrir tab
  cashflow → tap en la fila del mes → sheet abre con la sección de
  gastos (encabezado del mes + entrada de la categoría).
- **WT-CB02**: seed con 1 income + 1 expense en el mismo mes → tap →
  sheet muestra ambas secciones con los buckets correctos.
- **WT-CB03**: seed sin movimientos en el mes → tap en la fila (que
  aparece por RN-C06 relleno con ceros) → sheet muestra fallback
  "Sin movimientos en este mes."
- **WT-CB04**: seed con 1 expense en junio → tap fila → sheet
  abierto → tap "Ver movimientos →" → sheet cierra + navegación a
  `/entries` con filtro custom del mes. Verificar por presencia del
  chip del filtro o por la lista.

## Pruebas de permisos y seguridad si aplica

No aplica.

## Pruebas de datos, migracion o compatibilidad si aplica

No aplica. Feature 100% aditiva sin schema bump.

Blindaje de compat:

- **RT-01**: `flutter test` completo verde. Baseline 539 + ~15
  nuevos = ~554 esperados.
- **RT-02**: los tests existentes de `cashflowByMonth` en
  `reports_test.dart` siguen verdes (nueva query no toca la vieja).
- **RT-03**: los tests existentes de `cashflow_tab_test.dart` siguen
  verdes (el `onTap` es aditivo, no cambia el render base).

## Pruebas de regresion sobre flujos existentes

- **RT-04**: los otros 10 tabs de `/reports` siguen funcionando.
- **RT-05**: `/entries` con `EntriesFilters.forMonth` (nuevo factory)
  no rompe otros factories existentes (`thisMonth`, `forDay`,
  `forCategoryBucket`).
- **RT-06**: Dashboard y form de movimiento sin cambios.
- **RT-07**: Backup export/import round-trip sin cambios.

## Pruebas manuales o smoke tests necesarios

- **SM-01**: `/reports` → tab "Cashflow mensual" → ver lista con
  presets y bar chart intactos → tap en una fila del mes con datos
  → sheet abre con ambas secciones.
- **SM-02**: tap en fila de mes con solo gastos → sheet sin sección
  de ingresos.
- **SM-03**: tap "Ver movimientos →" → sheet cierra + `/entries`
  abre con el filtro del mes correcto (verificable por el badge del
  chip de fecha).
- **SM-04**: con el sheet abierto, ir a `/entries` (desde otra parte
  o el drill-down + registrar movimiento) → volver al sheet →
  verificar que la lista se actualizó (reactividad).
- **SM-05**: renombrar una categoría con el sheet abierto (requiere
  navegar aparte) → volver → el sheet debería reflejar el nuevo
  nombre.
- **SM-06**: cerrar el sheet arrastrando abajo → volver al tab base
  sin errores. Reabrirlo desde otra fila.
- **SM-07**: mes sin movimientos → sheet con fallback textual
  consistente en estilo.

## Datos de prueba recomendados

Setup para UT del servicio (in-memory BD):

- Bolsa (seed default).
- 1 cuenta debit `Banamex_MB`.
- 1 cuenta credit `Visa_MB` con limits.
- Categorías:
  - `catComida` (`applies_to='expense'`).
  - `catRenta` (`applies_to='expense'`).
  - `catSueldo` (`applies_to='income'`).
  - `catBoth` (`applies_to='both'`).
- Sembrar movimientos con `occurredAt` en un mes específico
  (`DateTime(2024, 6, 15, 12)` etc.).

Setup para widget tests (`pumpFincoreApp`):

- Similar al UT pero usando el helper del proyecto y el `seed`
  callback.
- Anchor de fecha `DateTime.now()` para que el mes actual tenga
  movimientos (o mockear vía preset custom).

## Comandos o validaciones locales sugeridas

```bash
cd mobile
flutter analyze
flutter test test/data/reports_test.dart --plain-name 'cashflowMonthBreakdown'
flutter test test/data/entries_filters_test.dart --plain-name 'forMonth'
flutter test test/screens/cashflow_tab_test.dart --plain-name 'sheet'
flutter test
flutter build apk --release --split-per-abi
../scripts/verify-apk.sh
~/Android/Sdk/platform-tools/adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

## Criterios minimos para aprobar la implementacion

- 15 tests nuevos aprox (13 UT servicio + 2 UT filtro + 4 widget).
- `flutter test` completo ≥ 554 verdes.
- `flutter analyze` sin errores nuevos.
- APK release build OK + `verify-apk.sh` OK con `versionCode 2088 /
  versionName 0.17.0`.
- SM-01..07 confirmados por Diego en cel real.
- El sheet abre en < 300 ms.
- Percent suma 100 (± error de redondeo) dentro de cada sección
  (validado en UT-CB04).

## Validacion final recomendada

Ejecutar la skill `branch-quality-review` con slug
`flutter-cashflow-monthly-breakdown-v1` antes del commit final. Foco:

- Correctness del helper `_buildMonthBreakdown` (simetrías
  `applies_to`, orden, percent).
- Reactividad del stream (`readsFrom` correcto).
- Navegación pop+push del drill-down (mounted check).
- Regresión del tab base del cashflow.
- Consistencia visual del sheet con el resto del proyecto
  (colores, tipografía, spacing).

Si no está disponible, checklist manual:

1. `git diff HEAD` — solo archivos listados en `plan.md`.
2. `flutter analyze` limpio.
3. `flutter test` verde ≥ 554.
4. UT-CB12/13 usan `emitsThrough` (no `Future.delayed`).
5. `_MonthBreakdownSheet` respeta `mounted` en el pop+push.
6. `strftime('%Y-%m', occurred_at, 'localtime')` presente en la
   query.
7. `LEFT JOIN categories` filtra `c.deleted_at IS NULL`.
8. Version bump coincide en `pubspec.yaml` y `build.gradle.kts`.

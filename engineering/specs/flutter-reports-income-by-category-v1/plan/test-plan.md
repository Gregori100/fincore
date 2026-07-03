# Plan de pruebas — flutter-reports-income-by-category-v1

## Casos borde detectados

- **CB-D01**: BD sin ningún income en el rango (aunque tenga expenses) → `report.isEmpty=true`.
- **CB-D02**: 1 income sin `category_id` → 1 bucket "Sin categoría" con `categoryId=null`, `categoryName='Sin categoría'`.
- **CB-D03**: 1 income con categoría cuyo `deleted_at != null` → mismo bucket "Sin categoría" (LEFT JOIN filtra por `deleted_at IS NULL`).
- **CB-D04**: 1 income con categoría `applies_to='expense'` → mismo bucket "Sin categoría" (LEFT JOIN filtra por `applies_to != 'expense'`).
- **CB-D05**: Mix — 2 incomes con `category_id NULL` + 1 con categoría archivada + 1 con categoría expense → **1 solo bucket** "Sin categoría" con `count=4` y total suma de los 4.
- **CB-D06**: 2 buckets con mismo total → orden por nombre alfabético asc.
- **CB-D07**: 1 bucket con total=100 y otro con total=300 → orden por total desc (300, 100). Percent: 25%, 75%.
- **CB-D08**: Rango que excluye el único income (todos fuera del `[from, to]`) → `isEmpty=true`.
- **CB-D09**: Reactividad — registrar un income nuevo mientras el stream está activo → nuevo bucket o suma al existente en el próximo emit.
- **CB-D10**: Cancelar (soft delete) el único income del bucket → bucket desaparece en el próximo emit. Si era el único, `isEmpty=true`.
- **CB-D11**: Editar un income cambiando `occurred_at` a fuera del rango → bucket baja o desaparece.
- **CB-D12**: Editar un income cambiando `category_id` de A a B → bucket A baja, bucket B sube.
- **CB-D13**: Kind `expense`, `credit_expense`, `debt_payment`, `transfer` con `category_id` que aplica → **NO cuentan** (filtro `kind='income'`).
- **CB-D14**: Categoría `applies_to='both'` con ingresos → **SÍ aparece** en el reporte (RN-I05 solo excluye `expense`).
- **CB-D15**: Backup legacy con categoría `applies_to='income'` y `monthly_limit != null` → **SÍ aparece** en el reporte (a diferencia de Presupuestos, aquí `monthly_limit` es irrelevante).
- **CB-D16**: 100 categorías con incomes → performance <20ms típico (sin degradar el `pumpAndSettle` de tests).
- **CB-D17**: Rango `from > to` en modo custom → snackbar warning + no aplica el cambio (validación en `_pickFrom` / `_pickTo` del widget).
- **CB-D18**: Deep link a `/entries` con `categoryId=null` → filtro incluye `kUncategorizedFilterToken` en `categoryIds`.
- **CB-D19**: `total_general = 0` con al menos 1 bucket vacío (edge muy raro por incomes con amount=0) → percent = 0 sin divide-by-zero.
- **CB-D20**: Cambio del preset "Este mes" a "Este año" mientras el stream está activo → `_reportStream` se re-construye y `StreamBuilder` re-suscribe sin fugas.

## Pruebas unitarias necesarias

- **UT-I01** Servicio — BD sin incomes en el rango: emite `isEmpty=true`, `total=0`, `count=0`, `buckets=[]`.
- **UT-I02** Servicio — 1 income con categoría OK (applies_to='income'): 1 bucket con `total`, `count=1`, `percent=100.0`.
- **UT-I03** Servicio — Mix con "Sin categoría" (los 3 casos: null + archivada + expense): 1 solo bucket con `categoryId=null` y `count` acumulado.
- **UT-I04** Servicio — Categoría `applies_to='both'` con income: sí aparece con badge propio.
- **UT-I05** Servicio — 2 buckets con mismo total: orden alfabético asc.
- **UT-I06** Servicio — 3 buckets con totales distintos: orden por total desc.
- **UT-I07** Servicio — Kind `expense`/`credit_expense`/`debt_payment`/`transfer` **NO** cuentan aunque tengan `category_id`.
- **UT-I08** Servicio — Reactividad: dentro de `Stream.first` posterior a `registerIncome`, el reporte refleja el nuevo income.
- **UT-I09** Servicio — Percent: bucket A=1000, B=3000 → percent 25.0 y 75.0.
- **UT-I10** Servicio — Cálculo defensivo: si `total_general=0` (edge), percent=0 y `isEmpty=true`.
- **UT-I11** Filtro — `EntriesFilters.forIncomeBucket(categoryId: 'abc', from, to)`: `kinds == ['income']`, `datePreset == custom`, `categoryIds == ['abc']`, `from`/`to` propagados.
- **UT-I12** Filtro — `forIncomeBucket(categoryId: null, ...)`: `categoryIds == [kUncategorizedFilterToken]`.

## Pruebas de integracion o API necesarias

No aplica. App local single-user sin API.

## Pruebas de UI o flujo necesarias si aplica

- **WT-I01** Tab — empty state visible con 0 incomes en el rango. Texto contextual "No se registraron ingresos en el período." presente. Ícono `trending_up` visible.
- **WT-I02** Tab — con 3 buckets sembrados: renderea 3 filas con nombre, monto formateado en MXN, barra proporcional, percent (1 decimal), count.
- **WT-I03** Tab — cambio de chip "Este mes" → "Este año" dispara re-stream. El widget muestra el nuevo rango.
- **WT-I04** Tab — tap en un bucket navega a `/entries` con el filtro pre-cargado. Verificable con `find.byType(EntriesListScreen)` post-tap y estado de filtros del pushed screen.
- **WT-I05** Tab — modo custom: `_pickTo` con fecha anterior a `_from` dispara `showWarningSnackbar` y no aplica el cambio.
- **WT-I06** ReportsScreen — TabBar renderea 8 tabs.
- **WT-I07** Onboarding slide 3 — 8 filas + párrafo "8 reportes".
- **WT-I08** HelpScreen FAQ — el tile "¿Cómo se calculan los reportes?" contiene "Ingreso por categoría".

## Pruebas de permisos y seguridad si aplica

No aplica.

## Pruebas de datos, migracion o compatibilidad si aplica

No hay migración. Sin tests específicos requeridos. Cubierto indirectamente por los tests existentes de backup (round-trip preserva `journal_entries.kind`).

## Pruebas de regresion sobre flujos existentes

- **RT-I01** El tab "Gasto por categoría" sigue funcionando idéntico (mismo servicio `spendingByCategory`, sin refactor compartido).
- **RT-I02** Los otros 6 reportes (Cashflow, Top movimientos, Saldo a fecha, Promedio mensual, Tarjetas, Presupuestos) no regresan.
- **RT-I03** El deep link desde el tab de gastos sigue funcionando con `forCategoryBucket`.
- **RT-I04** Onboarding slide 3 tests existentes (WT-O01..O06) siguen verdes con 8 filas.
- **RT-I05** HelpScreen tests existentes (WT-H01..H04) siguen verdes.
- **RT-I06** Backup round-trip preserva `kind='income'` sin cambios.

## Pruebas manuales o smoke tests necesarios

- **SM-01**: Diego abre `/reports` → ve 8 tabs y "Ingreso por categoría" al final.
- **SM-02**: Sin haber registrado ingresos aún → empty state con texto contextual.
- **SM-03**: Con los ingresos reales de Diego (sueldo + freelance + …) → ve buckets con montos correctos, ordenados por total desc.
- **SM-04**: Registra un income nuevo desde el FAB → vuelve al tab → aparece o suma al bucket existente en tiempo real.
- **SM-05**: Toca un bucket → navega a `/entries` con filtro pre-cargado (`kind=income`, categoría del bucket, rango del reporte). Los movimientos listados coinciden con la categoría.
- **SM-06**: Cambia el preset a "Este año" → ve todos los ingresos del año.
- **SM-07**: Ingresa a modo "Custom", selecciona un rango custom → ve el reporte para ese rango.
- **SM-08**: Tester en cel limpio: onboarding slide 3 muestra 8 filas legibles con scroll si es necesario.
- **SM-09**: FAQ Ayuda: el tile de reportes menciona el nuevo tab.

## Datos de prueba recomendados

Seed base para tests unitarios (usar helpers del harness existente):
- Bolsa (cash) + Banamex (debit) + Visa (credit) del seed default.
- Categorías sembradas por `seedDefaults`: 10 categorías default (mix income/expense/both).
- Sembrar en tests específicos:
  - **Seed A** (empty): sin incomes.
  - **Seed B** (bucket único): 1 income $30000 con categoría "Sueldo" (applies_to='income').
  - **Seed C** (mix estados): 3 categorías con incomes (Sueldo $30000, Freelance $8000, Renta $5000) + 2 sin categoría + 1 con categoría archivada + 1 con categoría de gasto (edge).
  - **Seed D** (kinds excluidos): 1 income + 1 expense + 1 credit_expense + 1 debt_payment + 1 transfer, todos con la misma `category_id`. Solo el income debe contar.

## Comandos o validaciones locales sugeridas

```bash
cd mobile

# 1. Analyzer
flutter analyze

# 2. Tests completos
flutter test

# 3. Tests específicos del sprint (rápido durante desarrollo)
flutter test test/data/reports_test.dart --plain-name "incomeByCategory"
flutter test test/screens/reports/income_by_category_tab_test.dart

# 4. Build APK release y verify
flutter build apk --release --split-per-abi
bash ../scripts/verify-apk.sh

# 5. Install en cel de Diego para smokes
~/Android/Sdk/platform-tools/adb install -r \
  build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

## Criterios minimos para aprobar la implementacion

- `flutter analyze` en 0 errores (los 4 hints info pre-existentes tolerados).
- `flutter test` verde. Objetivo ≥ 452 tests (437 previos + ≥ 15 nuevos entre UT y WT).
- `verify-apk.sh` OK con versionCode 2077 / versionName 0.15.0.
- SM-01, SM-03 y SM-05 confirmados por Diego en cel real antes de cerrar.
- El tab "Gasto por categoría" NO tiene regresión (RT-I01).

## Validacion final recomendada

Invocar `branch-quality-review` con slug `flutter-reports-income-by-category-v1` antes del commit final. Reporte irá a `engineering/quality-review/flutter-reports-income-by-category-v1/YYYY-MM-DD-HHMM-branch-quality-review.md`. Aplicar hallazgos verificados 1 por 1 con Diego (patrón ya establecido en sprints previos).

Si el skill no está disponible, checklist equivalente:
- Sin `TODO` sin resolver en los archivos tocados.
- Sin `print()` / `debugPrint()` de debug olvidados.
- Sin dependencies nuevas fuera de lo declarado.
- Sin regresión en los 7 reportes existentes (correr los tests de sus `_test.dart` explícitamente).
- Sin cambios accidentales en archivos de assets (íconos, splash, colores).
- Filtro `applies_to != 'expense'` verificado en la posición correcta del SQL (LEFT JOIN, no WHERE).

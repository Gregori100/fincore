# Plan de pruebas — flutter-budgets-v1

## Casos borde detectados

- **CB-D01**: Categoría con `applies_to=income` intenta guardarse con `monthly_limit=5000` → DAO rechaza con `invalid_monthly_limit_for_income`.
- **CB-D02**: Categoría con `applies_to=expense` intenta guardarse con `monthly_limit=-100` → DAO rechaza con `invalid_monthly_limit`.
- **CB-D03**: Categoría con `applies_to=both + monthly_limit=0` → OK; `spent=0` muestra badge "Sin gasto".
- **CB-D04**: Categoría con `monthly_limit=0 + spent=100` → `usedPct=null`, badge "Excedido por $100".
- **CB-D05**: Backup legacy con categoría `applies_to=income + monthly_limit=5000` → import acepta (compat, sin cambio de comportamiento previo del backup). El reporte filtra la fila fantasma en la query.
- **CB-D06**: Categoría con `applies_to=expense + monthly_limit=1000 + spent=800` → estado Warning (80%). `usedPct=80`.
- **CB-D07**: Categoría con `spent=1200` sobre límite 1000 → estado Overdue, `usedPct=100` (clamp visual). `overBy=200`.
- **CB-D08**: Categoría archivada con presupuesto → NO aparece en el reporte.
- **CB-D09**: `expense` con categoría archivada — el `LEFT JOIN` la trata como sin categoría → no cuenta a ningún presupuesto.
- **CB-D10**: `expense` con `category_id=null` → no cuenta a ningún presupuesto.
- **CB-D11**: `credit_expense` con categoría con presupuesto → cuenta como gasto (RN-B05).
- **CB-D12**: `debt_payment` o `transfer` con `category_id` seteado → NO cuentan como gasto.
- **CB-D13**: Cambio de mes: `monthAnchor` de julio → agosto. Los gastos de julio no aparecen; los de agosto sí.
- **CB-D14**: Orden RN-B11: 4 categorías (Overdue 150%, Warning 90%, OK 40% con gastos, Sin gasto) → orden `Overdue > Warning > OK > NoSpend`.
- **CB-D15**: Empate en `%` dentro del mismo estado → orden estable con tiebreak alfabético.
- **CB-D16**: Editar categoría "Comida" (expense, budget=5000) → cambiar `applies_to` a `income` → el input se limpia; submit persiste `null`.
- **CB-D17**: Editar categoría con budget seteado, dejar el input en blanco → submit persiste `null`.
- **CB-D18**: `monthly_limit` con valor decimal (ej: 5000.50) → persiste OK; reporte muestra sin overflow.
- **CB-D19**: Reactividad: registrar un `expense` con categoría con presupuesto mientras el tab está abierto → card se actualiza sin refresh.
- **CB-D20**: Zona horaria borderline: `expense` con `occurred_at = 31 de julio 23:59:59.999` cae en julio, no en agosto. La query lo incluye si `monthAnchor` es julio.
- **CB-D21**: `expense` cancelado (soft delete) durante el mes → NO cuenta.

## Pruebas unitarias necesarias

- **UT-01** DAO — `create(appliesTo='income', monthlyLimit: 100)` lanza `invalid_monthly_limit_for_income`.
- **UT-02** DAO — `create(appliesTo='expense', monthlyLimit: -50)` lanza `invalid_monthly_limit`.
- **UT-03** DAO — `updateCategory(id, monthlyLimit: -1)` sobre expense lanza `invalid_monthly_limit`.
- **UT-04** DAO — `create(appliesTo='both', monthlyLimit: 0)` OK.
- **UT-05** Servicio — BD sin presupuestos: `watchBudgetsProgress` emite lista vacía.
- **UT-06** Servicio — BD con 3 categorías (2 con presupuesto, 1 sin) → emite 2 entradas.
- **UT-07** Servicio — Categoría archivada con presupuesto → NO aparece.
- **UT-08** Servicio — Categoría `applies_to=income + monthly_limit=100` (legacy) → filtrada en query.
- **UT-09** Servicio — Cálculo correcto de `spent`: 3 expenses en la categoría en el mes + 1 fuera del mes → `spent` solo incluye los 3.
- **UT-10** Servicio — `credit_expense` cuenta como spent.
- **UT-11** Servicio — `debt_payment` y `transfer` NO cuentan.
- **UT-12** Servicio — Reactividad: dentro de `Stream.first` posterior a `registerExpense`, la card refleja la nueva deuda.
- **UT-13** Modelo — `BudgetProgress.compute(limit=1000, spent=800)` → `usedPct=80, isWarning=true`.
- **UT-14** Modelo — `compute(limit=1000, spent=1200)` → `usedPct=100 (clamp), isOverBudget=true, overBy=200`.
- **UT-15** Modelo — `compute(limit=0, spent=0)` → `usedPct=null, isNoSpend=true`.
- **UT-16** Modelo — `compute(limit=0, spent=50)` → `usedPct=null, isOverBudget=true, overBy=50`.
- **UT-17** Servicio — Orden RN-B11 con 4 categorías cubriendo los 4 estados → orden verificado.

## Pruebas de integracion o API necesarias

No aplica — app local sin API HTTP.

## Pruebas de UI o flujo necesarias si aplica

- **WT-01** `BudgetsTab` — con 0 presupuestos → empty state con CTA "Ir a Categorías" que navega a `/categories`.
- **WT-02** `BudgetsTab` — con 1 categoría con presupuesto + gastos → renderea card con badge, ring, filas.
- **WT-03** `BudgetsTab` — con `spent > limit` → badge "Excedido por $X" visible.
- **WT-04** `BudgetsTab` — con `spent == 0` → badge "Sin gasto".
- **WT-05** `CategoryFormScreen` — `applies_to=expense`: input "Presupuesto mensual" visible.
- **WT-06** `CategoryFormScreen` — `applies_to=income`: input NO visible.
- **WT-07** `CategoryFormScreen` — editar categoría con `monthly_limit=1500` → input inicializa con "1500".
- **WT-08** `CategoryFormScreen` — cambiar `applies_to` de expense a income con budget seteado → el input desaparece y al guardar persiste null.
- **WT-09** `ReportsScreen` — TabBar renderea 7 tabs.

## Pruebas de permisos y seguridad si aplica

No aplica.

## Pruebas de datos, migracion o compatibilidad si aplica

- **DT-01** Backup round-trip: crear categoría con `monthly_limit=3000` → exportar → wipeAll → importar → la categoría vuelve con el presupuesto intacto.
- **DT-02** Backup legacy con `applies_to=income + monthly_limit=5000` → import acepta; reporte de Presupuestos NO la muestra.

## Pruebas de regresion sobre flujos existentes

- **RT-01** Los 6 reportes anteriores (`by-category`, `cashflow`, `top-movements`, `saldo`, `promedio`, `tarjetas`) siguen sin regresión.
- **RT-02** `CategoriesDao.create` sin `monthlyLimit` (default null) sigue funcionando.
- **RT-03** Onboarding slide 3 sigue renderizando y su widget test (WT-O01..06) sigue pasando.
- **RT-04** Backup round-trip sin categorías con presupuesto no regresiona.

## Pruebas manuales o smoke tests necesarios

- **SM-01**: Diego abre `/reports` → ve el 7º tab "Presupuestos". Sin haber definido ninguno, empty state con CTA visible.
- **SM-02**: Diego edita "Comida" (expense) → aparece input "Presupuesto mensual" → llena "5000" → guarda → OK.
- **SM-03**: Diego abre `/reports/Presupuestos` → ve card "Comida" con `spent` correcto (los gastos que YA registró este mes en Comida aparecen).
- **SM-04**: Diego registra un nuevo `expense` en Comida desde el FAB → vuelve al tab → card actualizada.
- **SM-05**: Diego archiva "Comida" → vuelve al tab → la card desaparece.
- **SM-06**: Diego cambia `applies_to` de "Comida" a "income" (edge test) → el input desaparece del form → guarda → OK → tab de Presupuestos ya no la muestra.
- **SM-07**: Diego intenta editar "Sueldo" (income) → el input NO aparece.
- **SM-08**: Onboarding en cel limpio: slide 3 muestra 7 filas y menciona "Presupuestos".
- **SM-09**: FAQ de Ayuda: nuevo tile "¿Cómo defino un presupuesto?" con instrucciones claras.

## Datos de prueba recomendados

- **Seed A** (empty state): solo Bolsa + 10 categorías del seed default, ninguna con presupuesto.
- **Seed B** (mix estados): 4 categorías con presupuestos configurados así:
  - "Comida" (expense, budget=5000, spent=4500 = 90% → Warning).
  - "Transporte" (both, budget=2000, spent=1000 = 50% → OK).
  - "Salud" (expense, budget=3000, spent=3600 = 120% → Overdue, overBy=600).
  - "Regalos" (expense, budget=1500, spent=0 → NoSpend).
- **Seed C** (edge legacy): categoría "Sueldo" con `applies_to=income + monthly_limit=15000` (importada de backup legacy simulada con customStatement).

## Comandos o validaciones locales sugeridas

```bash
cd mobile
flutter analyze
flutter test
flutter build apk --release --split-per-abi
bash ../scripts/verify-apk.sh
~/Android/Sdk/platform-tools/adb install -r \
  build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

## Criterios minimos para aprobar la implementacion

- `flutter analyze` en 0 errores (los 4 hints info pre-existentes tolerados).
- `flutter test` verde. Objetivo ≥ 434 tests (412 previos + ≥ 22 nuevos).
- Backup round-trip preserva `monthly_limit`.
- `verify-apk.sh` OK con versionCode 2072 / versionName 0.14.0.
- SM-01 y SM-03 confirmados por Diego en cel real.

## Validacion final recomendada

Invocar `branch-quality-review` con slug `flutter-budgets-v1` antes del commit final. Reporte irá a `engineering/quality-review/flutter-budgets-v1/YYYY-MM-DD-HHMM-branch-quality-review.md`. Aplicar hallazgos verificados 1 por 1 con Diego (patrón ya establecido en sprints previos).

Si el skill no está disponible, checklist equivalente:
- Sin `TODO` sin resolver en los archivos tocados.
- Sin `print()` / `debugPrint()` de debug olvidados.
- Sin dependencies nuevas fuera de lo declarado.
- Sin regresión en los 6 reportes existentes.
- Sin cambios accidentales en archivos de assets (íconos, splash).

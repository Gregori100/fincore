# Tareas — flutter-cashflow-monthly-breakdown-v1

## Backend

- [ ] T001 Backend: leer código actual detallado — `reports.dart`
  bloque `cashflowByMonth` (~340-450) + `spendingByCategory` (patrón
  de agrupación con `LEFT JOIN categories`); `entries_filters.dart`
  factory `forDay` (~108-116) para el patrón `forMonth`;
  `cashflow_tab.dart` clase `_BreakdownRow` (~434-498) para el punto
  de tap; `spending_heatmap_tab.dart` bloque `showModalBottomSheet`
  y `_MonthDetailSheet` (patrón sheet); `category_badge.dart` para
  confirmar el fallback "Sin categoría"; confirmar si existe
  `mobile/test/data/entries_filters_test.dart` o dónde ir el
  UT-CB14/15.
  RF: —
  Depende de: ninguna
  Paralelizable: no
  Criterio de terminado: identificados los puntos de entrada exactos
  para cada cambio + confirmado el archivo destino de los UT del
  factory.

- [ ] T002 Backend: en `mobile/lib/data/reports.dart`, agregar el
  método `ReportsService.cashflowMonthBreakdown({required DateTime
  monthAnchor})` que retorna `Stream<MonthBreakdown>`. SQL:
  ```sql
  SELECT
    j.kind AS kind,
    j.category_id AS category_id,
    c.name AS category_name,
    c.color_slug AS color_slug,
    c.icon_slug AS icon_slug,
    c.applies_to AS applies_to,
    SUM(j.amount) AS total
  FROM journal_entries j
  LEFT JOIN categories c
    ON c.id = j.category_id AND c.deleted_at IS NULL
  WHERE j.deleted_at IS NULL
    AND j.kind IN ('income', 'expense', 'credit_expense')
    AND strftime('%Y-%m', j.occurred_at, 'localtime') = ?
  GROUP BY j.kind, j.category_id, c.name, c.color_slug, c.icon_slug, c.applies_to
  ```
  con `readsFrom: {_db.journalEntries, _db.categories}` y variable
  `Variable.withString('${year}-${month.toString().padLeft(2, '0')}')`.
  RF: RF-001, RF-003, RF-004, RF-005, RF-007
  Depende de: T001
  Paralelizable: no
  Criterio de terminado: método compila; SQL ejecutable en la BD
  in-memory.

- [ ] T003 Backend: agregar helper Dart `_buildMonthBreakdown(rows,
  monthAnchor)` que:
  - Itera rows y separa por `kind` en 2 estructuras temporales
    (`Map<String?, double> incomeByCategoryId`, `Map<String?, double>
    expenseByCategoryId`).
  - Aplica simetría RN-CB03/CB04: para cada row, si `applies_to='income'`
    y kind ∈ {expense, credit_expense} → colapsar categoryId a null
    (bucket "Sin categoría" de gastos); si `applies_to='expense'` y
    kind='income' → colapsar a null.
  - Filtra buckets con `amount <= 0` (CB-P03/CB-P04) antes de exponer.
  - Calcula `totalIncome`, `totalExpense`, `net`.
  - Construye `List<CategoryFlow>` para cada lado con `label` = nombre
    de categoría o "Sin categoría", `percent = total > 0 ? amount /
    total × 100 : 0.0`.
  - Ordena descendente por `amount`.
  - Retorna `MonthBreakdown` inmutable.
  RF: RF-006, RF-008, RF-009, RF-010
  Depende de: T002
  Paralelizable: no
  Criterio de terminado: helper compila; `flutter analyze` limpio.

- [ ] T004 Backend: definir modelos `MonthBreakdown` y `CategoryFlow`
  en `reports.dart` al final del archivo con los otros modelos del
  cashflow. Ambos const-inmutables. `MonthBreakdown` tiene `firstDay:
  DateTime`, `totalIncome`, `totalExpense`, `net`, `incomeBuckets:
  List<CategoryFlow>`, `expenseBuckets: List<CategoryFlow>`.
  `CategoryFlow` tiene `categoryId: String?`, `label: String`,
  `colorSlug: String?`, `iconSlug: String?`, `amount: double`,
  `percent: double`. Docstrings breves apuntando al sprint.
  RF: RF-002
  Depende de: T001
  Paralelizable: si (con T002/T003 mientras se termina la lectura)
  Criterio de terminado: modelos compilables; sin lint warnings.

- [ ] T005 Backend: en
  `mobile/lib/data/entries_filters.dart`, agregar factory `factory
  EntriesFilters.forMonth({required DateTime firstDay})` que arma
  ```dart
  final from = DateTime(firstDay.year, firstDay.month, 1);
  final to = DateTime(firstDay.year, firstDay.month + 1, 0, 23, 59, 59, 999);
  return EntriesFilters(
    datePreset: DateRangePreset.custom,
    from: from,
    to: to,
  );
  ```
  `month + 1, day: 0` produce el último día del mes anterior +
  overflow. Patrón `forDay` extendido.
  RF: RF-014
  Depende de: T001
  Paralelizable: si (con T002/T003/T004)
  Criterio de terminado: factory compila; UT-CB14/15 esperan
  `to.day` correcto.

## Frontend

- [ ] T006 Frontend: en `mobile/lib/screens/reports/cashflow_tab.dart`,
  envolver `_BreakdownRow.build` (o extraer la Row a un widget
  intermedio) con `InkWell` con `borderRadius: BorderRadius.circular(4)`
  y `onTap` que invoca `showModalBottomSheet<void>(context: context,
  isScrollControlled: true, backgroundColor: Colors.transparent,
  useSafeArea: true, builder: (_) => _MonthBreakdownSheet(monthAnchor:
  month.firstDay))`. Mantener el visual actual (sin cambios de
  spacing).
  RF: RF-011
  Depende de: T004 (por `MonthBreakdown` visible en el StreamBuilder
  del sheet), T005 (para el drill-down)
  Paralelizable: no
  Criterio de terminado: tap en la fila del mes abre el sheet
  vacío/loading.

- [ ] T007 Frontend: crear `_MonthBreakdownSheet` (StatefulWidget) en
  `cashflow_tab.dart` que:
  - Recibe `monthAnchor: DateTime`.
  - Cachea `Stream<MonthBreakdown>? _stream` en
    `didChangeDependencies`.
  - `build` retorna un `Container` con `decoration:
    BoxDecoration(color: FincoreColors.surface, borderRadius:
    BorderRadius.vertical(top: Radius.circular(16)))` +
    `SafeArea(child: SingleChildScrollView(...))` con:
    - Drag handle (patrón heatmap).
    - Encabezado: mes formateado con
      `DateFormat('MMMM y', 'es_MX').format(monthAnchor)` capitalizado
      + Row con "Ingresos: $X" (positive) + "Gastos: $Y" (negative) +
      "Neto: $Z" (color según signo).
    - StreamBuilder con loading/error/data/empty:
      - Loading: 2-3 skeleton rows.
      - Error: banner `_ErrorState` con retry (patrón heatmap).
      - Data.empty: fallback "Sin movimientos en este mes." con
        icon `Icons.event_busy` en `textSubtle`.
      - Data no empty: sección "Ingresos por categoría" si
        `incomeBuckets.isNotEmpty` + sección "Gastos por categoría"
        si `expenseBuckets.isNotEmpty` con `_CategoryFlowRow` por
        entrada.
    - Botón "Ver movimientos →" al final con
      `Icons.arrow_forward`.
  RF: RF-012
  Depende de: T006
  Paralelizable: no
  Criterio de terminado: sheet renderea completo con todos los
  estados.

- [ ] T008 Frontend: en `_MonthBreakdownSheet`, el botón "Ver
  movimientos →" ejecuta:
  ```dart
  final navigator = Navigator.of(context);
  final router = GoRouter.of(context);
  await navigator.maybePop();
  if (!mounted) return;
  router.push('/entries',
    extra: EntriesFilters.forMonth(firstDay: monthAnchor));
  ```
  Guardar los handlers antes del await por si el context se
  desmonta.
  RF: RF-013
  Depende de: T007
  Paralelizable: no
  Criterio de terminado: tap en "Ver movimientos" cierra el sheet y
  abre `/entries` con el filtro correcto.

- [ ] T009 Frontend: agregar el widget `_CategoryFlowRow` (interno
  al archivo o a `cashflow_tab.dart`) que recibe `CategoryFlow` y
  renderea:
  - Fila con `Row`: `_Chip` (usar `_Chip` custom con `colorBySlug` /
    `iconBySlug` si `colorSlug != null` o "Sin categoría" con
    `Icons.label_off_outlined` en `textSubtle`) + spacer + amount
    formateado (`formatAmount`) + percent
    (`percent.toStringAsFixed(1)` + '%').
  - Sin usar `CategoryBadge` directamente (que espera `Category`
    completo del schema).
  RF: RF-012
  Depende de: T007
  Paralelizable: si (con T008)
  Criterio de terminado: cada bucket se renderea consistente con el
  resto del proyecto.

## Documentación

- [ ] T010 Documentación: en
  `mobile/lib/screens/help_screen.dart`, dentro del tema "¿Cómo se
  calculan los reportes?", agregar una línea al bullet del cashflow:
  "• Cashflow mensual: … Al tapear una fila abre el desglose por
  categoría del mes (ingresos y gastos) con acceso directo a los
  movimientos."
  RF: RF-015
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: nueva línea visible en el FAQ.

## Pruebas

- [ ] T011 Pruebas: agregar grupo `cashflowMonthBreakdown (sprint
  monthly-breakdown)` en `mobile/test/data/reports_test.dart` con
  UT-CB01..13 según `test-plan.md`. UT-CB12/13 usan `emitsThrough`
  con `predicate<MonthBreakdown>(...)`. `setUp` reusa el patrón del
  archivo (in-memory BD + seedDefaults + accountsDao/categoriesDao/
  entriesDao/reports).
  RF: RF-016
  Depende de: T003
  Paralelizable: si (con T012/T013/T010)
  Criterio de terminado: 13 tests verdes.

- [ ] T012 Pruebas: agregar UT-CB14/CB15 del factory
  `EntriesFilters.forMonth` en el archivo confirmado en T001 (probable
  `test/data/entries_filters_test.dart` o inline en otro).
  RF: RF-016
  Depende de: T005
  Paralelizable: si (con T011/T013/T010)
  Criterio de terminado: 2 tests verdes.

- [ ] T013 Pruebas: en `mobile/test/screens/cashflow_tab_test.dart`,
  agregar WT-CB01..04 según `test-plan.md`. Usar `pumpFincoreApp`
  con `seed` callback para sembrar. Para el WT-CB03 (mes vacío) el
  tab llena meses con ceros (RN-C06), aún así la fila se puede
  tapear y el sheet muestra fallback.
  RF: RF-016
  Depende de: T008
  Paralelizable: si (con T011/T012/T010)
  Criterio de terminado: 4 widget tests verdes.

- [ ] T014 Pruebas: correr `flutter analyze` (0 errores nuevos) +
  `flutter test` completo. Suite ≥ 554 verdes (539 baseline + ~15
  nuevos).
  RF: RF-016
  Depende de: T011, T012, T013
  Paralelizable: no
  Criterio de terminado: suite completa verde + analyze limpio.

## Validación de calidad

- [ ] T015 Validación: bump de versión en `mobile/pubspec.yaml`
  (`0.17.0+88`) + `mobile/android/app/build.gradle.kts` (`versionCode
  = 88`, `versionName = "0.17.0"`). Correr `flutter build apk
  --release --split-per-abi` + `scripts/verify-apk.sh`.
  RF: RF-017
  Depende de: T014
  Paralelizable: no
  Criterio de terminado: APK release compilado + `verify-apk.sh` OK
  con versionCode 2088.

- [ ] T016 Validación: smoke manual con Diego en cel real. Ejecutar
  SM-01..07 del `test-plan.md`. Documentar hallazgos en
  `implementation/pendientes.md` si aparecen.
  RF: —
  Depende de: T015
  Paralelizable: no
  Criterio de terminado: Diego confirma los 7 smokes.

- [ ] T017 Validación: ejecutar la skill `branch-quality-review` con
  slug `flutter-cashflow-monthly-breakdown-v1`. Consolidar hallazgos
  en `engineering/quality-review/flutter-cashflow-monthly-breakdown-v1/`.
  Aplicar los bloqueantes antes del commit.
  RF: —
  Depende de: T016
  Paralelizable: no
  Criterio de terminado: reporte generado; hallazgos bloqueantes
  resueltos.

- [ ] T018 Validación: commit final con mensaje que resuma el
  sprint. NO pushear.
  RF: —
  Depende de: T017
  Paralelizable: no
  Criterio de terminado: `git status` limpio.

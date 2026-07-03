# Plan técnico — flutter-budgets-v1

## Enfoque tecnico

Sprint pequeño de tres capas superficiales sobre infraestructura existente:

1. **DAO reforzado (mínimo)**: `CategoriesDao.create/updateCategory` ya reciben `double? monthlyLimit` en la firma (verificado en `mobile/lib/data/daos/categories_dao.dart:59,87`). Falta agregar validaciones: rechazar `< 0` (`invalid_monthly_limit`) y rechazar `monthlyLimit != null` cuando `appliesTo == 'income'` (`invalid_monthly_limit_for_income`).

2. **Input UI en `CategoryFormScreen`**: agregar `TextFormField` "Presupuesto mensual" con `prefixText: '$ '`, visible solo cuando `_appliesTo != 'income'`. Al cambiar `_appliesTo` a `'income'`, limpiar el controller para que el submit persista `null`.

3. **Reporte "Presupuestos"**: nuevo modelo `BudgetProgress` en `lib/data/reports.dart`, método `ReportsService.watchBudgetsProgress({DateTime? monthAnchor})`, widget `BudgetsTab` en `lib/screens/reports/budgets_tab.dart`, integrar como séptimo tab en `ReportsScreen`.

4. **Doc en app**: onboarding slide 3 pasa a 7 filas; FAQ de HelpScreen menciona el nuevo tab + nuevo tile "¿Cómo defino un presupuesto?".

**Sin schema bump**: `categories.monthly_limit` existe desde el legacy (`database.dart:60`) y el backup ya lo serializa (`backup.dart:308,432`). Sprint puramente aditivo.

## Requisitos funcionales cubiertos

- **RF-001** (input UI): TextFormField en `CategoryFormScreen` bajo el AppliesToPicker (línea ~197 del archivo). Prefix `$ `, keyboard numeric, helper text "$ 0 = meta de no gastar en esta categoría". Visible con `if (_appliesTo != 'income')`.
- **RF-002** (reset al cambiar applies_to a income): en el callback `onChanged` del picker, si el nuevo valor es `'income'`, `_monthlyLimitCtrl.clear()`. El submit pasa `null` si el campo está vacío.
- **RF-003** (validación DAO): `_validateMonthlyLimit({required String? appliesTo, required double? monthlyLimit})` en `CategoriesDao`. Errores `invalid_monthly_limit` y `invalid_monthly_limit_for_income`.
- **RF-004** (modelo `BudgetProgress`): campos inmutables + factory `compute` que aplica RN-B08 (`usedPct`) y RN-B09 (`isOverBudget`, `isWarning`, `isNoSpend`).
- **RF-005** (`watchBudgetsProgress`): `customSelect` con LEFT JOIN entre `categories` y `journal_entries` filtrado por mes + kind. Orden RN-B11 en Dart post-fetch.
- **RF-006** (BudgetsTab): loading/empty/data. Empty con FilledButton "Ir a Categorías" → `context.push('/categories')`.
- **RF-007** (BudgetTile): BaseCard con CategoryBadge + ring + filas de dinero + badges Excedido/SinGasto.
- **RF-008** (7º tab): actualizar `ReportsScreen` — length: 6→7, agregar `Tab(text: 'Presupuestos')` + `BudgetsTab()`.
- **RF-009** (onboarding): agregar fila `_KindRow(icon: Icons.savings_outlined, color: FincoreColors.positive, label: 'Presupuestos')` y párrafo "7 reportes".
- **RF-010** (help FAQ): bullet nuevo + tile nuevo con instrucciones.
- **RF-011** (version bump): pubspec + gradle a `0.14.0+72`.

## Archivos o modulos probablemente afectados

- `mobile/lib/data/daos/categories_dao.dart` — agregar `_validateMonthlyLimit` + llamarlo en `create` y `updateCategory`. Sin cambio de firma.
- `mobile/lib/data/reports.dart` — nuevo modelo `BudgetProgress` + método `watchBudgetsProgress` en `ReportsService`.
- `mobile/lib/screens/category_form_screen.dart` — controller nuevo `_monthlyLimitCtrl`, cargar valor existente en `_loadCategory`, submit en `_save`, TextFormField condicional. Callback del picker que limpia el ctrl si va a income.
- `mobile/lib/screens/reports/budgets_tab.dart` — archivo nuevo. StatefulWidget con `_stream` cacheado.
- `mobile/lib/screens/reports_screen.dart` — sexto tab pasa a séptimo. Actualizar comentario doc.
- `mobile/lib/screens/onboarding_screen.dart` — slide 3 con fila nueva, párrafo "7 reportes".
- `mobile/lib/screens/help_screen.dart` — bullet en FAQ existente + tile nuevo.
- `mobile/pubspec.yaml` — bump + comentario del sprint.
- `mobile/android/app/build.gradle.kts` — versionCode 72 / versionName 0.14.0.
- Tests nuevos: `mobile/test/data/reports_budgets_test.dart` (o extender `reports_test.dart`), extender `mobile/test/data/database_test.dart` con validaciones DAO, extender `mobile/test/screens/category_form_screen_test.dart` con input, `mobile/test/screens/reports/budgets_tab_test.dart` nuevo.

## Entidades y estados afectados

- **`Category`**: la fila ya tiene `monthly_limit` (opcional). Nuevas invariantes de dominio:
  - `monthly_limit != null → applies_to != 'income'`.
  - `monthly_limit != null → monthly_limit >= 0`.
- **`BudgetProgress`** (modelo derivado, no persistido): DTO inmutable computado en Dart en cada evento del stream.
- **`JournalEntry`**: no cambia. La agregación del reporte usa `kind ∈ {expense, credit_expense}` filtrado por `occurred_at` dentro del mes.

Transiciones que afectan al reporte:
- Setear/editar `monthly_limit` de una categoría → aparece o cambia en el reporte reactivamente.
- Registrar `expense` o `credit_expense` con `category_id` seteado → `spent` de esa categoría sube.
- Cancelar movimiento (soft delete) → `spent` baja.
- Cambio de mes calendario → el `spent` "reset" implícito (los movimientos anteriores quedan fuera del rango de la query).

## Compatibilidad con datos y procesos existentes

- **Datos existentes**: usuarios (Diego incluido) pueden tener categorías con `monthly_limit != null` importadas del backend legacy. El reporte funcionará "gratis" para ellos si existen — pero por RN-B07 se filtran las combinaciones inválidas (`applies_to=income + monthly_limit != null`).
- **Backup JSON v1**: `monthly_limit` se serializa desde antes del sprint (`backup.dart:308`). Post-sprint export/import es bidireccional sin cambios.
- **Otros reportes**: no se tocan.
- **Formulario existente**: `CategoryFormScreen` gana un input opcional visible según `applies_to`. El orden visual sigue: Nombre → Applies To → **Presupuesto (nuevo)** → Color → Icon → Preview.
- **`categoriesDao.create/updateCategory`**: firma sin cambios. Solo se refuerza validación interna. Los tests existentes que llamaban sin `monthlyLimit` siguen pasando (default null).

## Cambios de datos si aplica

No hay schema bump. La columna `monthly_limit` ya existe con la forma `RealColumn get monthlyLimit => real().nullable()()`. Ningún ALTER ni UPDATE.

## Cambios de API si aplica

No aplica. App local single-user.

## Cambios de integraciones si aplica

No aplica.

## Cambios de UI si aplica

- **`CategoryFormScreen`**: input "Presupuesto mensual" con visibilidad condicional según `_appliesTo`. Ubicación: debajo del `AppliesToPicker` (aproximadamente línea 201 en el estado actual).
- **`ReportsScreen`**: séptimo tab "Presupuestos". El `TabBar` ya es `isScrollable: true` — no rompe.
- **`BudgetsTab` (nuevo)**: card por categoría con presupuesto:
  - `CategoryBadge` (reusar del catálogo).
  - Ring circular del `%` (patrón similar al de credit_cards_tab).
  - Filas: gastado, límite, disponible.
  - Badge "Excedido por $X" si `isOverBudget`; badge "Sin gasto" si `isNoSpend`.
- **`OnboardingScreen`** slide 3: 7 filas, párrafo "7 reportes".
- **`HelpScreen`** FAQ: bullet nuevo en "¿Cómo se calculan los reportes?" + tile nuevo "¿Cómo defino un presupuesto?".

## Cambios de permisos si aplica

No aplica.

## Riesgos tecnicos

- **R1 — Filtro en el SQL para excluir `income + monthly_limit`**: si un backup legacy trajo la combinación inválida, la query DEBE filtrarla con `WHERE c.applies_to != 'income'`. Falta esto y aparecen categorías fantasma. Test explícito: sembrar el edge, verificar que no aparece.
- **R2 — Rango del mes en curso ↔ zona horaria**: `DateTime(year, month, 1)` y `DateTime(year, month + 1, 0, 23, 59, 59, 999)` para el rango. La query usa `Variable.withDateTime` que serializa a texto ISO8601 gracias a `build.yaml`. Consistente con otros reportes.
- **R3 — `_monthlyLimitCtrl` no se resetea al reciclar el form**: si el mismo widget se reutiliza para editar categorías distintas (raro con go_router pero posible), verificar que `_loadCategory` limpia y setea. Mitigación: patrón idéntico al `_creditLimitCtrl` en `AccountFormScreen`.
- **R4 — Semántica de `monthly_limit=0` confusa**: helper text explica; badge diferenciado ("Excedido por $X" cuando `spent > 0` y límite 0).
- **R5 — Reactividad del reporte con la anchor de mes**: `monthAnchor: DateTime.now()` se evalúa al abrir el tab; si el usuario cruza medianoche del último día del mes, el reporte no se refresca hasta el próximo evento. Mismo trade-off del sprint credit-cards (M1 diferido). Aceptado.
- **R6 — SQL con `LEFT JOIN` sobre journal_entries filtrado por mes + kind**: performance <10ms con volumen típico. No es hot path.
- **R7 — Backup con datos históricos**: importar un JSON legacy con 5 categorías con `monthly_limit` → aparecen automáticamente en el reporte. Si Diego no esperaba esto, es sorpresa positiva o neutra. Sin fix.
- **R8 — Cambio de applies_to en edit con presupuesto seteado**: si Diego edita "Comida" y cambia `applies_to` de `expense` a `income`, el input desaparece y el submit debe persistir `monthly_limit=null`. Test explícito.

## Estrategia de pruebas

- Unitarias:
  - DAO: validaciones nuevas (`create` y `updateCategory` rechazan `< 0` y rechazan combinación income + budget).
  - Servicio: `watchBudgetsProgress` con múltiples escenarios (empty, con presupuestos + gastos, categorías archivadas filtradas, income+budget filtradas por seguridad, cambio de mes en `monthAnchor`, reactividad al insertar gasto).
  - Modelo: `BudgetProgress.compute` cubre RN-B08/B09 (OK/Warning/Overdue/NoSpend, `usedPct=null` cuando límite es 0).
- Widget:
  - `CategoryFormScreen`: input visible con applies_to=expense/both; oculto con income; cambio de applies_to limpia el valor; save persiste correctamente.
  - `BudgetsTab`: empty con CTA, con datos, badges "Excedido"/"Sin gasto", reactividad post-registro de gasto.
- Compatibilidad: backup round-trip con presupuestos preservados.

## Estrategia de rollback

- Sin schema bump: el rollback es limpio. Revertir el commit y el APK previo (0.13.0+71) sigue funcionando.
- `categories.monthly_limit` en BD queda con los valores que se hayan seteado, pero como el form legacy no lo expone, el usuario no vería ni podría editarlos. Datos preservados sin exponer.
- Backup exportado desde 0.14.0+72 incluye `monthly_limit`; el importador de 0.13.0+71 también lo acepta (compat legacy) — round-trip cross-versión sin pérdida.
- APK previo `0.13.0+71` disponible en `build/app/outputs/flutter-apk/`.

## Orden sugerido de implementacion

1. **DAO validaciones** — refuerzo mínimo de `_validateMonthlyLimit` en `CategoriesDao`. Tests UT-01..04 pasan.
2. **Modelo + servicio** — `BudgetProgress` + `watchBudgetsProgress` en `reports.dart`. Tests UT-05..12 pasan.
3. **BudgetsTab** — widget nuevo con loading/empty/data + BudgetTile.
4. **Sexto tab → séptimo** — integrar en `ReportsScreen`.
5. **Input UI** — conectar controller al form y agregar el TextFormField condicional.
6. **Documentación en app** — slide 3 del onboarding + FAQ de Help.
7. **Version bump + build + verify-apk.sh** — 0.14.0+72.
8. **Tests** — cubrir DAO + servicio + widget + form según test-plan.
9. **Smokes SM-01..09**.
10. **branch-quality-review**.

## Casos borde que condicionan la solucion

- Backup legacy con `applies_to=income + monthly_limit != null`: el reporte debe filtrarlas (RN-B07). Test explícito.
- Categoría con `monthly_limit=0` y `spent > 0` → `usedPct=null` + badge "Excedido por $X".
- Cambio `applies_to` de expense → income en edit: el input desaparece; submit persiste null aunque el usuario haya tipeado algo previamente.
- Gasto de kind `debt_payment` o `transfer`: no cuentan al `spent` (solo `expense` + `credit_expense`).
- Gasto con `category_id = null`: no cuenta.
- Gasto con categoría archivada: no cuenta (LEFT JOIN + `deleted_at IS NULL`).
- Cambio de mes (`monthAnchor` cae en día 1) → gastos del mes anterior no aparecen.

## Preguntas o supuestos que siguen afectando la implementacion

- **S1**: el "mes en curso" es el mes calendario del huso horario local. Diego usa es_MX (UTC-6). Sin adaptación multi-timezone.
- **S2**: No hay historial de presupuestos. Si Diego edita el `monthly_limit`, el nuevo valor rige inmediatamente sin snapshot histórico.
- **S3**: El reporte NO se muestra a categorías con `applies_to=income + monthly_limit != null` (edge legacy). Se filtra en la query; no se limpia automáticamente en BD (evita side effect al abrir el tab).
- **S4**: El input UI se limpia visualmente al cambiar `applies_to` a income, y el submit persiste null. No hay confirmación "estás seguro de perder el presupuesto".

Sin preguntas bloqueantes.

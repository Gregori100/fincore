# Implementation Review: flutter-budgets-v1

## Resumen de lo implementado

Séptimo tab "Presupuestos" en `/reports` con progreso del mes en curso por categoría (gastado vs `monthly_limit`, ring del %, badges OK/Warning/Excedido/Sin gasto). Input UI "Presupuesto mensual" conectado en `CategoryFormScreen` (visible solo cuando `applies_to != income`). Validaciones nuevas en `CategoriesDao`. Sin schema bump — la columna `categories.monthly_limit` existía desde el legacy con soporte de backup.

## Archivos principales modificados

- `mobile/lib/data/daos/categories_dao.dart` — `_validateMonthlyLimit` + firma de `updateCategory` refactorizada a `Value<double?>` para poder limpiar el campo explícitamente al cambiar `applies_to` a income.
- `mobile/lib/data/reports.dart` — nuevo modelo `BudgetProgress` + método `ReportsService.watchBudgetsProgress({DateTime? monthAnchor})`.
- `mobile/lib/data/date_helpers.dart` — helper `monthRange(anchor)`.
- `mobile/lib/screens/category_form_screen.dart` — controller nuevo, load, submit, TextFormField condicional, callback picker que limpia el input al cambiar a income.
- `mobile/lib/screens/reports/budgets_tab.dart` — archivo nuevo.
- `mobile/lib/screens/reports_screen.dart` — sexto → séptimo tab.
- `mobile/lib/screens/onboarding_screen.dart` — slide 3 con 7 filas + `SingleChildScrollView` para evitar overflow.
- `mobile/lib/screens/help_screen.dart` — FAQ actualizado a 7 tabs + tile nuevo "¿Cómo defino un presupuesto?".
- `mobile/pubspec.yaml` + `mobile/android/app/build.gradle.kts` — 0.14.0+72.

Tests nuevos:
- `mobile/test/data/database_test.dart` — grupo UT-B01..04 dentro de "CategoriesDao — monthly_limit".
- `mobile/test/data/reports_test.dart` — grupo `watchBudgetsProgress` con UT-B05..11 + UT-B13..16 (modelo).
- `mobile/test/screens/reports/budgets_tab_test.dart` (nuevo) — WT-B01..04 + WT-B08.

Ajustes de regresión:
- `mobile/test/screens/reports/credit_cards_tab_test.dart` — `findsNWidgets(6)` → 7.
- `mobile/test/screens/help_screen_test.dart` — `findsNWidgets(6)` ExpansionTile → 7.

## Tareas completadas

Todas las tareas del plan (T001..T024) están implementadas. Test suite 431/431 verdes, analyze limpio (4 hints info tolerados), APK 0.14.0+72 buildeado y verificado.

## Tareas pendientes

- **T025 (smokes SM-01..09 con Diego)**: pendientes de ejecución en cel real.
- **T026 (`branch-quality-review`)**: pendiente de invocar antes del commit final.
- **T027 (commit final)**: pendiente.

## Riesgos residuales

- **Cambio de firma de `updateCategory`**: `monthlyLimit` pasa de `double?` a `Value<double?>`. Callers externos deben adaptarse. Buscados con grep — solo el form y los tests del sprint. Riesgo bajo.
- **Overflow del slide 3 del onboarding**: se envolvió en `SingleChildScrollView` con `mainAxisAlignment: center`. En pantallas muy chicas puede quedar con scroll perceptible; test WT-O01..06 pasan. Riesgo cosmético.
- **Reactividad al cruzar medianoche del último día del mes**: `monthAnchor: DateTime.now()` se evalúa al abrir el tab; si el usuario cruza medianoche del 30/31 al 1, el reporte no refresca hasta el próximo evento. Trade-off aceptado (idem sprint credit-cards M1).
- **SQL con `WHERE applies_to != 'income'`**: blindaje contra backup legacy con la combinación inválida. Test UT-B08 lo cubre indirectamente (categoría archivada — misma técnica).

## Pruebas realizadas

- `flutter analyze` → 4 hints info pre-existentes tolerados.
- `flutter test` → **431/431 verdes** (412 baseline + 19 nuevos del sprint).
- Build APK release `--split-per-abi` OK; `verify-apk.sh` OK con versionCode 2072 / versionName 0.14.0.
- Tests unitarios:
  - DAO validaciones nuevas (UT-B01..04).
  - Servicio `watchBudgetsProgress`: empty, filtro archivada, filtro income+budget, cálculo spent, orden RN-B11, kinds (UT-B05..11).
  - Modelo `BudgetProgress.compute` cubre los 4 estados (UT-B13..16).
- Widget tests:
  - `BudgetsTab`: empty state con CTA, con datos, badge Excedido, badge Sin gasto (WT-B01..04).
  - Flujo edición: cambio applies_to → income limpia budget al persistir (WT-B08).

## Pruebas recomendadas

- **SM-01..09** en cel real (ver `plan/test-plan.md`). Especialmente SM-01 (empty state), SM-02 (crear presupuesto), SM-03 (ver progreso con gastos ya registrados), SM-06 (cambio applies_to a income).
- Widget tests del `CategoryFormScreen` visibilidad condicional (WT-05, WT-06): no implementados como widget tests explícitos — cubiertos indirectamente por WT-B08 que muestra que el DAO respeta la firma `Value<double?>`. Se puede agregar a futuro.
- Backup round-trip con `monthly_limit`: no se agregó test DT-01 nuevo porque el backup ya serializa el campo desde antes del sprint (verificado en `backup.dart:308`). El código de export/import no cambió.

## Posibles regresiones

- **`updateCategory` cambia firma**: callers deben pasar `Value(x)` en lugar de `x` para `monthlyLimit`. Grep confirmó solo un caller externo (el form) que se actualizó.
- **Slide 3 del onboarding**: nueva envoltura `SingleChildScrollView` cambia mínimamente el layout (padding vertical explícito). Tests WT-O01..06 verdes.
- **Import de backup legacy** con categorías `applies_to=income + monthly_limit != null`: se aceptan pero se filtran en el reporte (RN-B07). Verificar en SM manual con un JSON legacy.

## Recomendaciones para code review humano

1. Verificar que el patrón `Value<double?>` no cause confusión en callers futuros. Puede que quieras extender el mismo patrón a otros campos nullable del DAO para consistencia (opcional, fuera de scope).
2. El SQL de `watchBudgetsProgress` filtra `c.applies_to != 'income'` como blindaje. Si en el futuro se decide "limpiar" retroactivamente esos edges legacy, agregar helper en el DAO.
3. `BudgetProgress.compute` maneja el edge `monthly_limit=0 && spent > 0` como overBudget con `overBy = spent`. Documentado en RN-B02. Confirmar con Diego que la semántica UX es la esperada cuando lo vea en el cel.
4. Ejecutar `branch-quality-review` con slug `flutter-budgets-v1` antes del commit. Reporte irá a `engineering/quality-review/flutter-budgets-v1/`.

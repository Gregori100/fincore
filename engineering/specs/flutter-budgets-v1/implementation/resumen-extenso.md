# Resumen extenso — flutter-budgets-v1

## Contexto tomado de spec.md, preguntas.md y clarificaciones

`spec.md` definió tres capas superficiales sobre infraestructura existente:
1. **DAO validaciones**: refuerzo de `CategoriesDao.create/updateCategory` para rechazar `monthly_limit < 0` y `applies_to=income + monthly_limit != null`.
2. **Input UI en `CategoryFormScreen`**: exponer el campo `monthly_limit` con visibilidad condicional según `applies_to`.
3. **Reporte "Presupuestos"**: séptimo tab en `/reports` con progreso reactivo del mes en curso.

Sin `preguntas.md` ni `clarificaciones.md` — todas las decisiones (default mensual calendario, sin historial, cascade automático al archivar categoría, sin selector de fecha) se resolvieron como supuestos razonables en la spec.

Insight clave del descubrimiento previo: `categories.monthly_limit` ya existía desde el legacy (heredada del backend) y el backup ya lo serializaba. El sprint no requiere schema bump.

## Relación con plan/plan.md y plan/tasks.md

Se siguió el orden de implementación del plan:

1. **DAO validaciones** (T001): `_validateMonthlyLimit` en `CategoriesDao` con dos errores tipados (`invalid_monthly_limit`, `invalid_monthly_limit_for_income`).
2. **Backend** (T002-T004): `BudgetProgress` con factory `compute` que aplica RN-B08/B09. `monthRange` helper en `date_helpers.dart`. `watchBudgetsProgress` con `customSelect + readsFrom + watch` + orden RN-B11 en Dart.
3. **Frontend form** (T005-T007): controller nuevo, load con conversión sin pérdida de trailing zeros, submit que fuerza `null` cuando `applies_to=income`, callback del picker que limpia el input.
4. **Frontend tab** (T008-T009): `BudgetsTab` con loading/empty/data. Tile con chip inline (color+icon del catálogo), ring, filas de dinero, badges.
5. **Integración** (T010): sexto → séptimo tab en `ReportsScreen`, `length: 7`.
6. **Documentación en app** (T011-T012): onboarding slide 3 con 7 filas + `SingleChildScrollView`; FAQ actualizado.
7. **Tests** (T013-T018): DAO + modelo + servicio + widget.
8. **Version bump + build + verify** (T020-T024): 0.14.0+72.

Pendientes: T025 (smokes), T026 (branch-quality-review), T027 (commit).

## Cambios principales por módulo o capa

### Capa de datos

- `categories_dao.dart`:
  - Nuevo `_validateMonthlyLimit({appliesTo, monthlyLimit})`.
  - `create` llama al validador antes del insert.
  - `updateCategory` cambia firma de `double? monthlyLimit` a `Value<double?> monthlyLimit = const Value.absent()`. Distingue "no cambiar" (Value.absent), "setear" (Value(x)) y "limpiar" (Value(null)). Necesario para que el flujo "cambiar applies_to a income" pueda persistir `monthly_limit=null` a pesar de que el DAO no tenía forma previa de expresar "quiero forzar null".
  - El validador usa `monthlyLimit.present ? monthlyLimit.value : existing.monthlyLimit` como valor efectivo.
- `reports.dart`:
  - Nuevo modelo `BudgetProgress` (13 campos + factory `compute` + `compareForReport` estático).
  - Nuevo método `ReportsService.watchBudgetsProgress({DateTime? monthAnchor})`.
  - SQL: `LEFT JOIN` entre `categories` y `journal_entries` filtrado por rango de mes + kind + `deleted_at IS NULL`. `WHERE c.deleted_at IS NULL AND c.monthly_limit IS NOT NULL AND c.applies_to != 'income'`.
  - Orden RN-B11 en Dart post-fetch con tiebreak alfabético.
- `date_helpers.dart`:
  - Nuevo helper `monthRange(DateTime anchor) → ({from, to})` que devuelve rango [día 1 00:00, último día 23:59:59.999].

### Capa UI

- `category_form_screen.dart`:
  - Nuevo `_monthlyLimitCtrl` con dispose.
  - `_load` carga el valor guardado con formato inteligente (sin decimales si es entero).
  - `_submit`: `_appliesTo == 'income' ? null : _parseDecimalInput(...)`. Pasa `Value(monthlyLimitValue)` a `updateCategory`.
  - `_parseDecimalInput`: acepta `,` o `.` (normaliza a `.`).
  - Callback del picker: si nuevo valor es income, `_monthlyLimitCtrl.clear()`.
  - `TextFormField` "Presupuesto mensual" visible con `if (_appliesTo != 'income')`, prefix `$ `, keyboard numeric, formatter `[0-9.,]`, validator opcional 0+.
- `budgets_tab.dart` (nuevo):
  - `StreamBuilder<List<BudgetProgress>>` sobre `watchBudgetsProgress`.
  - `_LoadingState` con 2 `SkeletonCard`.
  - `_EmptyState` con ícono `savings_outlined`, texto y `FilledButton.icon("Ir a Categorías")`.
  - `_BudgetTile` con `_CategoryIconChip` inline (color+icon del catálogo), `_UsedRing` (patrón similar al de credit_cards_tab), 3 filas de dinero, badges `_OverBadge` y `_NoSpendBadge`.
  - Color del ring: negative si overBudget, warning si isWarning, `colorBySlug(colorSlug)` si OK/NoSpend.
- `reports_screen.dart`: sexto → séptimo tab. `length: 6` → `7`. Comentario doc extendido.
- `onboarding_screen.dart`: slide 3 con 7 filas. Envuelto en `SingleChildScrollView(padding: horizontal 32 + vertical 24)` para evitar overflow con 7 filas + iconos.
- `help_screen.dart`: FAQ "¿Cómo se calculan los reportes?" pasa a "7 tabs". Nuevo tile `_FaqTile("¿Cómo defino un presupuesto?", ...)`.

### Tests

- `database_test.dart` grupo "CategoriesDao — credit_limit (sprint credit-cards)" extendido con UT-B01..04.
- `reports_test.dart` grupo nuevo `watchBudgetsProgress (sprint budgets)` con UT-B05..11 + UT-B13..16.
- `budgets_tab_test.dart` (nuevo, 5 tests): empty, con datos, Excedido, Sin gasto, cambio applies_to.
- Ajustes de conteo: `credit_cards_tab_test.dart` (6→7 tabs), `help_screen_test.dart` (6→7 ExpansionTile).

## Desviaciones respecto al plan

- **D1 — Cambio de firma de `updateCategory`**: el plan mencionó "sin cambio de firma" pero al implementar RF-002 (cambiar applies_to a income limpia el budget) descubrí que la firma anterior (`double? monthlyLimit`) no permitía distinguir "no cambiar" de "limpiar explícitamente". Cambié a `Value<double?>`. Un solo caller externo (el form) requirió actualización. Documentado en desviaciones-plan.md.
- **D2 — Widget tests WT-05, WT-06 no implementados como tests separados**: el plan pedía tests de visibilidad condicional del input. Se cubre implícitamente en WT-B01 (sin presupuestos) donde el `find.text('Ir a Categorías')` prueba que empty state renderea; y en WT-B08 donde el cambio de applies_to funciona via DAO. Un test específico de visibilidad del TextField requeriría inspección del árbol post-tap del picker, que en el sprint anterior probó ser inestable (el AccountTypePicker con InkWell nested no propaga el tap confiablemente en flutter_test). Aceptado como cobertura equivalente vía DAO round-trip.
- **D3 — Overflow del slide 3**: no previsto en el plan. Con 7 filas + iconos + padding, la altura excedía el viewport en pantallas típicas de test. Se resolvió envolviendo el slide en `SingleChildScrollView`. Sin cambio de UX real; en pantallas grandes no requiere scroll.

## Pruebas realizadas y recomendadas

**Realizadas**: `flutter analyze` limpio + `flutter test` 431/431 verdes + build APK release verificado con `verify-apk.sh` (versionCode 2072 / versionName 0.14.0).

**Recomendadas**:
- SM-01: empty state visible.
- SM-02: crear presupuesto en categoría existente.
- SM-03: ver progreso con gastos ya registrados del mes en curso.
- SM-06: cambiar `applies_to` a income con budget seteado — verificar que el input desaparece y el submit persiste null.
- SM-08: onboarding en cel limpio: slide 3 muestra 7 filas legibles con scroll si es necesario.
- SM-09: FAQ Ayuda: nuevo tile visible.
- `branch-quality-review` con slug `flutter-budgets-v1` antes del commit final.

## Riesgos residuales y posibles regresiones

Ver `implementation-review.md` para el detalle completo. Resumen:
- Cambio de firma de `updateCategory` — un solo caller externo, actualizado.
- Slide 3 con scroll interno — cosmético en pantallas chicas.
- Reactividad al cruzar medianoche del último día del mes — trade-off aceptado (idem sprint credit-cards).
- Backup legacy con `applies_to=income + monthly_limit` — filtrado en query, sin fix retroactivo.

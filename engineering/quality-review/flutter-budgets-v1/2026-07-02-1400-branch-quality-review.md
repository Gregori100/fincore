# Quality Review — flutter-budgets-v1

**Fecha**: 2026-07-02 · **Rama**: `main` (sin commit) vs. `43fd501` · **Slug**: `flutter-budgets-v1`

## Alcance revisado

Diff local (uncommitted) sobre `main` posterior al commit `43fd501` (sprint credit-cards). 8 archivos productivos modificados + 3 nuevos + 4 docs. ~600 líneas netas de código productivo + tests.

Áreas revisadas por 3 agentes en paralelo:
- **Data + streams + SQL correctness**
- **Frontend UX + form validation**
- **Cobertura de tests + regresión**

## Bloqueantes

Ninguno.

## Hallazgos Altos

### A1 — Filtro `applies_to != 'income'` sin test explícito

- **Archivo**: `mobile/test/data/reports_test.dart` (grupo `watchBudgetsProgress`).
- **Descripción**: El SQL de `watchBudgetsProgress` incluye `AND c.applies_to != 'income'` como blindaje contra backup legacy con la combinación inválida. El DAO impide crear esa combinación (UT-B01 lo prueba), pero eso no garantiza que el filtro del SQL siga vigente en refactors futuros.
- **Impacto**: Si alguien borra el filtro (por ej. alineándolo con `spendingByCategory`), la regresión pasa desapercibida. Usuarios con backups legacy verían "categorías fantasma".
- **Recomendación**: Test que use `db.customStatement("INSERT INTO categories(...)")` con `applies_to='income' + monthly_limit=5000` (bypaseando el DAO), y verifique `list.isEmpty`. 10-15 líneas, alto retorno defensivo.

### A2 — Orden `compareForReport` sin test integración (UT-17)

- **Archivo**: `mobile/test/data/reports_test.dart` (grupo `watchBudgetsProgress`).
- **Descripción**: UT-B13..B16 cubren cada estado del modelo por separado, pero no se ejercita el `compareForReport` con dataset mixto (Overdue+Warning+OK+NoSpend). RN-B11 es una decisión de UX y no está protegida contra regresión.
- **Impacto**: Cambio silencioso al comparador rompe la jerarquía visual del tab sin fallar tests.
- **Recomendación**: Test con las 4 categorías del "Seed B" del test-plan que valide el orden esperado. Combina con hallazgo M1 abajo (empate en `usedPct=100` post-clamp).

## Hallazgos Medios

### M1 — Docstring vs. comportamiento en el orden intra-`isOverBudget`

- **Archivo**: `mobile/lib/data/reports.dart:1521-1546`
- **Descripción**: Docstring dice "Excedidas primero (mayor porcentaje de exceso desc)". Pero `usedPct` se clampa a 100 en `compute` (línea 1484-1488). Todas las categorías excedidas terminan con `usedPct=100.0`, la rama del comparador devuelve 0 y caen al tiebreak alfabético.
- **Evidencia**: Escenario: A gastó 200% ($2000/$1000), B gastó 110% ($1100/$1000). Ambas `usedPct=100`. Se ordenan alfabéticamente, no por exceso.
- **Impacto**: Divergencia doc ↔ comportamiento. Si Diego espera "la más excedida primero", el reporte no cumple.
- **Recomendación**: Dos opciones:
  1. **Cosmético**: ajustar docstring a "excedidas primero; tiebreak alfabético".
  2. **Funcional**: ordenar `isOverBudget` por `overBy` desc antes del tiebreak. Es lo que uno esperaría (a Diego se le muestra primero la que peor va).
  Recomiendo la opción 2 — es 2 líneas más y correcto UX.

### M2 — Reactividad `watchBudgetsProgress` sin test (UT-12)

- **Archivo**: `mobile/test/data/reports_test.dart`
- **Descripción**: El sprint credit-cards agregó UT-12 con `listen(events.add)`. Para budgets no se agregó equivalente.
- **Impacto**: Si un refactor cambia `readsFrom: {categories, journalEntries}` por solo `{categories}`, un `registerExpense` no re-emite y la UI queda desincronizada sin señal en CI.
- **Recomendación**: Test análogo a UT-12 de credit-cards. Preferir `stream.take(2).toList()` sobre `Future.delayed` (más determinístico).

### M3 — Slide 3 del onboarding pierde centrado vertical

- **Archivo**: `mobile/lib/screens/onboarding_screen.dart:393-467`
- **Descripción**: Cambio de `Center(Padding(Column))` a `SingleChildScrollView(padding, Column)` rompe el centrado: dentro de un `SingleChildScrollView` el `Column` recibe altura no acotada, `mainAxisAlignment.center` no tiene efecto y el contenido queda pegado arriba en pantallas grandes.
- **Impacto**: Al swipear entre slides 1→2→3 se ve un salto visual (contenido se corre hacia arriba). Regresión estética.
- **Recomendación**: Patrón canónico `SingleChildScrollView(child: ConstrainedBox(minHeight: viewport, child: IntrinsicHeight(child: Column(mainAxisAlignment: center, ...))))` con `LayoutBuilder`.

### M4 — Ring vacío rojo con "—" cuando `monthlyLimit == 0` y `spent > 0`

- **Archivo**: `mobile/lib/screens/reports/budgets_tab.dart:277-283`
- **Descripción**: Caso "meta de no gastar" con cualquier gasto: `isOverBudget=true` pero `usedPct=null` → el ring renderiza `value: 0` (círculo vacío) en negativo + texto "—%". Parece "sin datos" pero es el estado más crítico.
- **Impacto**: El elemento visual más prominente del tile no refleja la gravedad. El usuario ve "—" y podría no notar el exceso hasta leer el badge inferior.
- **Recomendación**: Cuando `isOverBudget && usedPct == null`, forzar `value: 1.0` para que el ring se llene todo en rojo.

## Hallazgos Bajos

### L1 — UT-B11 no ejercita realmente debt_payment/transfer

- **Archivo**: `mobile/test/data/reports_test.dart` (UT-B11).
- **Descripción**: El título dice "NO cuentan" pero el cuerpo solo prueba el caso positivo (registerExpense=100, spent=100). Nunca siembra `debt_payment` o `transfer`.
- **Recomendación**: Ampliar con `registerTransfer(categoryId: catComida)` o `registerDebtPayment` sembrado vía `customStatement`, aseverar `spent` no los incluye.

### L2 — Slide 2 también puede overflow con text scaling alto

- **Archivo**: `mobile/lib/screens/onboarding_screen.dart:311-383`
- **Descripción**: Slide 2 tiene el mismo patrón "Icon 80 + título + descripción + 5 filas" que motivó el patch en slide 3. Con `textScale` alto (accesibilidad) puede reventar.
- **Recomendación**: Aplicar el mismo `SingleChildScrollView` por simetría, o extraer un `_OnboardingSlide` compartido. Diferible: no hay reporte de overflow en slide 2 hoy.

### L3 — "Disponible" siempre en verde aunque el límite esté excedido

- **Archivo**: `mobile/lib/screens/reports/budgets_tab.dart:213-217`
- **Descripción**: `amountColor: FincoreColors.positive` es incondicional. Cuando `isOverBudget`, `available=0` se muestra "$ 0" en verde brillante. Rompe coherencia semántica.
- **Recomendación**: `progress.isOverBudget ? FincoreColors.textSubtle : FincoreColors.positive` (o `warning` si `isWarning`).

### L4 — `CategoriesDaoError` no mapeado en `error_snackbar`

- **Archivo**: `mobile/lib/widgets/error_snackbar.dart` (falta rama).
- **Descripción**: Los nuevos códigos `invalid_monthly_limit` e `invalid_monthly_limit_for_income` no tienen mapeo amigable. Fallback muestra `"CategoriesDaoError(invalid_monthly_limit): ..."` crudo al usuario. Preexistente en toda la clase — el sprint amplía la superficie.
- **Recomendación**: Branch específica `case CategoriesDaoError()` con helper que mapee los códigos. El form ya bloquea con validators, así que es defensivo.

### L5 — Docstring `watchBudgetsProgress` no menciona trade-off de fecha

- **Archivo**: `mobile/lib/data/reports.dart:926-929`
- **Descripción**: `monthAnchor: DateTime.now()` se evalúa al abrir el tab. Si el usuario deja el tab abierto y cruza medianoche del último día del mes, el rango sigue apuntando al mes cerrado hasta re-abrir. Trade-off idéntico al de credit-cards. No documentado.
- **Recomendación**: Añadir párrafo en docstring explicitando el trade-off. Sin cambio de comportamiento.

### L6 — Cobertura numérica bajo del objetivo del test-plan

- **Archivo**: N/A.
- **Descripción**: Objetivo test-plan `≥ 434 tests` (412 + ≥22 nuevos). Actual: 431 (412 + 19 nuevos). Gap coincide con UT-08/12/17 no cubiertos.
- **Recomendación**: Al agregar A1+A2+M2 se llega a ~434 y se cierran los gaps de mayor riesgo.

## Notas informativas

- **N1** — Sin regresión externa por cambio de firma `updateCategory(monthlyLimit: Value<double?>)`. Único caller externo (form) actualizado.
- **N2** — `_validateMonthlyLimit`: orden null → <0 → income cubre las 4 combinaciones correctamente. Sin edge case.
- **N3** — Falta índice en `journal_entries(category_id)` para la query nueva. No es hot path con volumen single-user; documentar como nota, no bumpear schema.
- **N4** — Precisión temporal `.999` ms: nulo en la operación cotidiana. Solo teórico si backups traen microsegundos.
- **N5** — `_load` con formato "5000.00 → 5000" es correcto para casos comunes; frágil con `4999.999...` post-import de backup. Cosmético.

## Tareas de corrección en orden de dependencia

### Prioridad 1 — antes del commit

1. **[A1]** Test del filtro `applies_to != 'income'` con `customStatement` bypaseando DAO.
2. **[A2 + M1]** Test del orden `compareForReport` con dataset mixto (4 estados) + fix del orden intra-overBudget (ordenar por `overBy` desc antes del tiebreak alfabético). Ajustar docstring de `compareForReport`.
3. **[M2]** Test de reactividad con `stream.take(2)`.
4. **[M3]** Fix del centrado vertical del slide 3 con `LayoutBuilder + ConstrainedBox + IntrinsicHeight`.
5. **[M4]** Ring lleno en rojo cuando `isOverBudget && usedPct == null`.

### Prioridad 2 — recomendado antes del commit

6. **[L1]** UT-B11 ampliado con `transfer` y `debt_payment` explícitos.
7. **[L3]** Color condicional del "Disponible" según estado.
8. **[L4]** Mapeo de `CategoriesDaoError` en `error_snackbar`.
9. **[L5]** Docstring de `watchBudgetsProgress` con nota del trade-off.

### Prioridad 3 — diferibles

10. **[L2]** Slide 2 con `SingleChildScrollView` por simetría — diferir hasta que aparezca reporte de overflow.
11. **[L6]** Meta numérica de tests cubierta al aplicar A1/A2/M2.
12. **[N3]** Índice `category_id` — evaluar con telemetría.
13. **[N5]** Redondeo `4999.999...` — solo si aparece en QA.

## Limitaciones y validaciones no ejecutadas

- Los agentes no ejecutaron los tests propuestos ni verificaron en cel real.
- Slide 3 con `SingleChildScrollView` no fue probado visualmente en device físico; el hallazgo M3 es basado en análisis del patrón Flutter estándar.

## Estado final

- Confirmado: rama `main`, sin commit pendiente.
- Reporte generado: `engineering/quality-review/flutter-budgets-v1/2026-07-02-1400-branch-quality-review.md`.
- 0 bloqueantes, 2 altos, 4 medios, 6 bajos, 5 notas.
- Sin agentes ni procesos pendientes.

# Resumen extenso — flutter-entry-form-redesign-v1

## Contexto

Sprint 3 del roadmap definido en `engineering/design-audit-2026-07-14/consolidado.md`. Ataca las 4 fricciones diarias de mayor impacto del flujo más frecuente de la app (entry form), identificadas como P1.2, P1.3, P1.4 y P2.7 en la auditoría de Entries.

Cero preguntas bloqueantes. Ejecutado en modo autónomo (goal de Diego: terminar todos los sprints faltantes).

## Relación con `plan.md` y `tasks.md`

Ejecución alineada al plan. T001-T017 completadas (T012/T013/T018 son smoke/commit que se hacen fuera del ciclo de tests).

Estrategia: 2 subagentes Sonnet en paralelo para refactor de `KindPicker` y `CategoryPicker` (archivos aislados) + Claude directo para `AmountInputFormatter` + refactor del `entry_form_screen.dart`. Los subagentes preservaron la API pública (verificado con call site de `weekly_budgets/widgets/budget_item_form_sheet.dart` que sigue funcionando).

## Cambios principales por módulo o capa

### Capa de widgets

**Nuevo**:
- `mobile/lib/widgets/amount_input_formatter.dart` — `AmountInputFormatter extends TextInputFormatter` con lógica robusta de formato de miles en vivo + normalización de decimales + rechazo de estados inválidos (múltiples separadores decimales).

**Refactorizados** (subagentes Sonnet):
- `mobile/lib/widgets/kind_picker.dart` — de column full-width a `GridView.count(crossAxisCount: 2, childAspectRatio: 1.6)`. Helpers `kindColor`, `kindIcon`, `kindDescription` expuestos como `static` públicos (usados por el chip header del entry form).
- `mobile/lib/widgets/category_picker.dart` — de `DropdownMenu<String?>` a `CategoryPicker` compacto (chip + chevron) + `_CategoryPickerSheet` privado con search-first, "Sin categoría" fija arriba, MRU en memoria (static list, 5 items max, LRU), agrupación por `appliesTo` cuando `validAppliesTo` incluye tanto income como expense.

### Capa de screens

**Modificado**: `mobile/lib/screens/entry_form_screen.dart` (refactor mayor):

- **Estructura del `_buildForm()` reordenada**: chip header → amount hero → date chips → account pickers → descripción → category picker → footer buttons.
- **`_AmountHero` (widget privado)**: `TextFormField` con `key: ValueKey('amount_hero_field')`, `fontSize: 36` (token-exception documentada), color según `_amountColor(kind)`, `fontFeatures: [FontFeature.tabularFigures()]`, prefix `$` en 28sp textMuted, autofocus en alta, validator usando `parseFormattedAmount`.
- **`_DateQuickPicker` (widget privado)**: 4 chips M3-style con selección exclusiva; setean `_occurredAt` normalizado a 12:00; label debajo con fecha formateada en es_MX.
- **`_KindChipHeader` (widget privado)**: chip prominente al top del form. En alta muestra chip + label + botón "Cambiar" que dispara `_promptChangeKind` (con `showConfirmDialog` si el form tiene datos). En edit muestra pill informativo "(no editable)".
- **AppBar action Guardar**: `TextButton` accent siempre visible cuando `_kind != null`. Bindea `_saving` para deshabilitar.
- **`_pickDate()`**: `lastDate: DateTime.now()` (sin fechas futuras).
- **`_bootstrap()` hydration**: `_amountCtrl.text = formatAmountForInput(item.entry.amount)` (`1500.5` → `"1,500.50"`).
- **`_submit()`**: `parseFormattedAmount(_amountCtrl.text)` + `showWarningSnackbar` si es inválido.
- **`_cancel()` copy**: "Cancelar movimiento" → "Eliminar movimiento" (voz consistente).

### Documentación y versión

- `mobile/pubspec.yaml` — bump `0.22.0+99` con comentario changelog.
- `mobile/android/app/build.gradle.kts` — bump.
- `engineering/specs/flutter-entry-form-redesign-v1/` — spec, plan, tasks, test-plan e implementation completos.

## Desviaciones respecto al plan

### DP-01 — surfaceSize agrandado en tests de kinds

**Origen**: el nuevo KindPicker grid (aspect 1.6, 3 filas × ~250dp = 750dp de altura en 800dp width) NO cabe en el window default de widget tests (800×600). Los tiles de filas 2-3 quedan offscreen; el `tester.tap()` derivaba coordenadas fuera del render tree y el `onTap` no se disparaba.

**Detección**: 5 tests del `entry_form_kinds_test.dart` fallando con warning "would not hit test on the specified widget".

**Resolución**: en el helper `selectKind()` del test, `tester.binding.setSurfaceSize(const Size(1080, 1920))` + `addTearDown(() => tester.binding.setSurfaceSize(null))`. Simula un cel real donde el grid completo cabe sin scroll.

**Impacto**: solo tests; código productivo no cambia.

### DP-02 — matcher del CategoryPicker en suggestion test

**Origen**: `entry_form_suggestion_test.dart:132` buscaba `DropdownMenu<String?>` ancestor de "Categoría (opcional)". El nuevo `CategoryPicker` no usa `DropdownMenu`; es un `InkWell + Container` con el label como widget hermano (fuera del InkWell).

**Resolución**: cambiar el finder a `find.descendant(of: find.byType(CategoryPicker), matching: find.byType(InkWell))`. Import de `category_picker.dart` agregado al test.

### DP-03 — cambio de copy Cancelar → Eliminar en dialogs

**Origen**: el OutlinedButton del `_cancel` estaba con label "Eliminar movimiento" (Sprint 2 cambió esto) pero el `title` y `confirmLabel` del `showConfirmDialog` seguían con "Cancelar movimiento" (inconsistencia).

**Resolución**: alinear los 3 sitios a "Eliminar" (label, title, confirmLabel).

## Pruebas realizadas y recomendadas

### Realizadas
- `flutter analyze --no-fatal-infos`: verde. 3 hints info pre-existentes de `entry_form_screen.dart` + 2 hints nuevos por los widgets `_DateQuickPicker` (tolerables).
- `flutter test`: **707/707 verdes**. Timing: ~1 min.
  - 681 previos (Sprint 2) + 26 nuevos del `AmountInputFormatter`.
  - 8 tests widget actualizados por el refactor (documentado en desviaciones DP-01 a DP-03).

### Recomendadas / pendientes
- Smoke desktop (`flutter run -d linux`): 7 flujos del test-plan.
- Smoke Android (`adb install -r` del APK release): validar layout en 360dp.

## Riesgos residuales y posibles regresiones

- **RT-A** (formato en vivo): tests unitarios cubren; sin regresión.
- **RT-B** (compat weekly_budgets): API pública de CategoryPicker preservada.
- **Excepción `fontSize: 36`**: documentada; se evaluará crear `displayS` si aparecen más usos.
- **Cambios visuales grandes**: esperados, cero regresión funcional.

## Trazabilidad final

- **13 RF** definidos en `spec.md` → 18 tasks planificadas → 17 ejecutadas + T018 (commit) pendiente.
- **Cero preguntas bloqueantes**.
- **3 desviaciones documentadas** (surfaceSize tests, matcher suggestion, copy Eliminar).
- **707 tests verdes**; **8 tests actualizados** en el sprint.
- **1 excepción token** (`fontSize: 36`).

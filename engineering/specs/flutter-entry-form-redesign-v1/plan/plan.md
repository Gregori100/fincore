# Plan técnico — flutter-entry-form-redesign-v1

## Enfoque tecnico

Sprint de rediseño de UI de un solo screen crítico (`entry_form_screen.dart`) + refactor de 2 widgets asociados (`kind_picker.dart`, `category_picker.dart`) + creación de 1 nuevo `TextInputFormatter` reutilizable. 6 áreas de trabajo:

1. **`_AmountInputFormatter`** — nueva clase que reemplaza `FilteringTextInputFormatter.allow`. Formatea con separadores de miles en vivo, acepta `,` como decimal, rechaza `1.2.3`.
2. **`_AmountHero`** — widget privado (o inline) al top del form. `TextStyle(fontSize: 36)` con `// token-exception`.
3. **`_DateQuickPicker`** — nuevo widget privado con 4 chips (Hoy/Ayer/Anteayer/Otro).
4. **KindPicker refactor** — de column vertical a `GridView.count(crossAxisCount: 2)` con 5 tiles + descripción dinámica debajo.
5. **CategoryPicker refactor** — de `DropdownMenu` a `CategoryPickerField` (compact) + `_CategoryPickerSheet` con search-first + MRU en memoria.
6. **Chip "Cambiar tipo"** + AppBar action "Guardar" — cambios puntuales en `entry_form_screen.dart`.

Cero cambios de dominio. Los DAOs, servicios y modelos permanecen intocados. Los tokens del Sprint 1 son la única fuente de estilos (salvo `fontSize: 36` del hero).

## Requisitos funcionales cubiertos

- **RF-001** (Amount hero al top con 36sp + color por kind) → T001-T003.
- **RF-002** (`_AmountInputFormatter` rechaza `1.2.3`) → T001.
- **RF-003** (autofoco en alta) → T003.
- **RF-004** (edit hydration formateada) → T003.
- **RF-005** (snackbar warning si amount inválido en submit) → T004.
- **RF-006/007** (`_DateQuickPicker` con 4 chips + label de fecha) → T005-T006.
- **RF-008** (AppBar action Guardar) → T007.
- **RF-009** (KindPicker grid 2×3) → T008.
- **RF-010** (CategoryPicker como sheet con search + MRU) → T009-T010.
- **RF-011** (Chip "Cambiar tipo" al top con confirm) → T011.
- **RF-012** (bump versión) → T012.
- **RF-013** (analyze + tests) → T013-T015.

## Archivos o modulos probablemente afectados

**Modificados**:
- `mobile/lib/screens/entry_form_screen.dart` (mayor refactor; ~800 líneas actualmente, esperado ~900-1000 post-sprint).
- `mobile/lib/widgets/kind_picker.dart` (refactor grid).
- `mobile/lib/widgets/category_picker.dart` (refactor sheet).
- `mobile/pubspec.yaml` (bump).
- `mobile/android/app/build.gradle.kts` (bump).

**Posibles afectados** (por consumo indirecto):
- `mobile/lib/screens/weekly_budgets/widgets/budget_item_form_sheet.dart` (consume `CategoryPicker`). El refactor debe mantener el API compatible o adaptar el caller — verificar en implementación.
- Tests que matcheaban el layout viejo: `mobile/test/screens/entry_form_screen_test.dart`, `mobile/test/screens/entry_form_kinds_test.dart`, `mobile/test/screens/entry_form_suggestion_test.dart`. Actualizar matchers post-implementación.

**No tocados**:
- `mobile/lib/data/**` (dominio intocado).
- `mobile/lib/widgets/amount_formatter.dart` (helper de string, distinto del nuevo `_AmountInputFormatter`).
- Otros screens (dashboard, entries list, reports, settings, categories, accounts).

## Entidades y estados afectados

- **JournalEntry**: sin cambios. Sigue con los mismos 5 kinds y reglas RN-011.
- **Category**: sin cambios. El picker consume y presenta, no muta.
- **`_kind` (form state)**: en alta, mutable con `KindPicker`; en edit, inmutable por RN-011 (comportamiento existente preservado).
- **`_occurredAt` (form state)**: default `DateTime.now()` normalizado a 12:00; los quick-chips setean con misma normalización.

## Compatibilidad con datos y procesos existentes

- **BD SQLite**: sin cambios.
- **Backup JSON v1**: sin cambios.
- **Tests existentes** (681): los widget tests del entry form necesitan actualización de matchers. Los tests de dominio (DAOs, financial_state, reports, backup) NO se tocan.
- **API pública de widgets**: `KindPicker` mantiene `value`/`onChanged`/`enabled`. `CategoryPicker` mantiene `label`/`selectedId`/`validAppliesTo`/`onChanged`/`categories` — el widget nuevo es `CategoryPickerField` con la misma firma. Los call sites (entry_form + budget_item_form_sheet) no cambian.

## Cambios de datos si aplica

No aplica.

## Cambios de API si aplica

No aplica (single-user local, sin HTTP).

## Cambios de integraciones si aplica

No aplica.

## Cambios de UI si aplica

Sí — sprint de UI completo. Documentados en spec:
- Amount hero grande (32-40sp).
- Fecha con quick-chips.
- Guardar en AppBar.
- KindPicker en grid 2×3.
- CategoryPicker como sheet.
- Chip prominente "Cambiar tipo".

**Cambios sub-perceptibles adicionales** por consumir tokens:
- Widgets modificados heredan los tokens (fontSize/spacing/radii/alphas del Sprint 1). Sin sorpresas — Sprint 1 ya validó que los tokens dan look coherente.

## Cambios de permisos si aplica

No aplica.

## Riesgos tecnicos

Heredados de spec (R-01 a R-08) + adicionales:

- **RT-A** (formateo en vivo del amount): `TextInputFormatter` custom con cursor position es fuente clásica de bugs (undo/redo, IME behavior). Mitigación: usar `TextEditingValue` con cálculo explícito del `selection` post-format. Testear con casos borde (delete en medio de miles, paste, etc.). Si aparecen bugs raros, fallback conservador: sin separadores en vivo (solo al submit).
- **RT-B** (compatibilidad de CategoryPicker con weekly_budgets): el widget `CategoryPicker` actual se usa en `budget_item_form_sheet.dart`. El refactor debe preservar la firma pública o ajustar el caller. Chequear en implementación.
- **RT-C** (tests de entry form): 3 archivos de test tocarán con matchers desactualizados. Documentar cada cambio en `decisiones-implementacion.md`.
- **RT-D** (excepción `fontSize: 36`): si aparece un `bodyL`/`displayS` como token global en un sprint futuro, el hero puede consumirlo. Por ahora `// token-exception:` documenta la deuda.

## Estrategia de pruebas

1. **`flutter analyze`** — cero errores nuevos.
2. **`flutter test`** — 681 previos actualizados donde matchee, más nuevos tests si aplica (guardrail del amount formatter, chips de fecha).
3. **Test unitario del `_AmountInputFormatter`** — casos: string vacío, entero, decimal, `1.2.3`, paste sucio, backspace en medio de miles. ~10 casos.
4. **Smoke desktop** (`flutter run -d linux`): flujos SM-01 a SM-05.
5. **Smoke Android** (build APK + `adb install -r`): mismos flujos en cel real.
6. **Revisión equivalente** manual al final (no hay `branch-quality-review` expuesta).

## Estrategia de rollback

Trivial: `git revert` del commit del sprint. Cero side effects (sin schema, sin migración).

## Orden sugerido de implementacion

1. **T001** — `_AmountInputFormatter` como widget nuevo + tests unitarios.
2. **T002-T004** — `_AmountHero` + integración en `entry_form_screen`.
3. **T005-T006** — `_DateQuickPicker` + integración.
4. **T007** — AppBar Guardar action.
5. **T008** — refactor `KindPicker`.
6. **T009-T010** — refactor `CategoryPicker` (widget + sheet).
7. **T011** — chip "Cambiar tipo" + confirm dialog.
8. **T012** — bump versión.
9. **T013** — `flutter analyze` + fix.
10. **T014** — `flutter test` + update matchers.
11. **T015** — docs de cierre + commit.

Los pasos 1-7 se pueden paralelizar parcialmente con subagentes Sonnet (cada uno con su archivo aislado), pero dado que la mayoría toca el mismo `entry_form_screen.dart`, hacer secuencial es más seguro.

## Casos borde que condicionan la solucion

Los 15 bordes de la spec están cubiertos. Adicional del planeamiento:

- **PB-01**: `NumberFormat.decimalPattern('es_MX')` — confirmar el patrón en runtime durante T001. Puede ser `#,##0.##` (miles=coma, decimal=punto). Si no, ajustar la lógica.
- **PB-02**: `AmountFormatter` string helper (existente) usa `NumberFormat.currency`. El nuevo `_AmountInputFormatter` NO usa `NumberFormat.currency` porque no quiere el símbolo `$` en el string interno (el prefix lo pinta aparte). Usar `NumberFormat('#,##0.##', 'es_MX')` o similar.
- **PB-03**: en edit, si el amount es `1234.5`, el hydration formateado es `"1,234.50"` (2 decimales fijos) o `"1,234.5"` (1 decimal)? Decisión: **2 decimales siempre en edit hydration** (aliena visualmente con display); luego el usuario puede editar.
- **PB-04**: `KindPicker` grid 2×3 con 5 tiles — decidir en implementación: (a) 2+2+1 con tile 5 en col 1 fila 3, (b) 2+2+1 centrado con Row extra, (c) 3+2 con crossAxisCount=3. **Preferencia**: (a) más simple; (c) más balanceado. Elegir en implementación por vista visual.

## Preguntas o supuestos que siguen afectando la implementacion

Sin bloqueos. Supuestos activos:

- `NumberFormat.decimalPattern('es_MX')` produce el patrón esperado. Verificar en T001.
- Los tests del entry form solo tienen matchers de layout, no de comportamiento crítico. Ajuste trivial.
- El bump minor `0.22.0` es apropiado.

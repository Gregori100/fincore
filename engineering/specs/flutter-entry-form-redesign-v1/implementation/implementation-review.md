# Implementation Review: flutter-entry-form-redesign-v1

## Resumen de lo implementado

Sprint 3 del roadmap. Rediseño del flujo más frecuente (registro de movimientos). 6 áreas ejecutadas:

1. **Amount input como hero** — 36sp, color por kind, `AmountInputFormatter` custom (miles en vivo, acepta `,` como decimal, rechaza `1.2.3`), autofoco en alta, hydration edit formateada.
2. **`_DateQuickPicker`** — 4 chips Hoy/Ayer/Anteayer/Otro; setean `_occurredAt` normalizado a mediodía; "Otro..." abre showDatePicker con `lastDate: DateTime.now()`.
3. **AppBar action Guardar** — TextButton accent siempre visible.
4. **KindPicker refactor** — de column vertical a `GridView.count(crossAxisCount: 2, childAspectRatio: 1.6)` con 5 tiles + descripción del kind seleccionado debajo.
5. **CategoryPicker refactor** — de `DropdownMenu` a widget compacto (chip + chevron) que abre `showModalBottomSheet` con search + MRU en memoria + agrupación por appliesTo. API pública preservada.
6. **Chip `_KindChipHeader`** — reemplaza el TextButton.icon "Cambiar tipo (Gasto)"; muestra chip prominente con `_kindColor.withValues(alpha: alphaTint)` + label + botón "Cambiar"; `showConfirmDialog` si el form tiene datos.

Copy "Cancelar movimiento" → "Eliminar movimiento" (voz consistente).

## Archivos principales modificados

- `mobile/lib/screens/entry_form_screen.dart` — refactor mayor del `_buildForm()` + `_amountColor()` + `_promptChangeKind()` + widgets privados `_KindChipHeader`, `_AmountHero`, `_DateQuickPicker`, `_DateChip`. AppBar con action Guardar.
- `mobile/lib/widgets/kind_picker.dart` — refactor completo (subagente Sonnet). Grid 2 columnas. Helpers públicos `kindColor`, `kindIcon`, `kindDescription`.
- `mobile/lib/widgets/category_picker.dart` — refactor completo (subagente Sonnet). `CategoryPicker` compact + `_CategoryPickerSheet` con search + MRU + agrupación.
- `mobile/lib/widgets/amount_input_formatter.dart` — NUEVO. `AmountInputFormatter` + `parseFormattedAmount` + `formatAmountForInput`.
- `mobile/test/widgets/amount_input_formatter_test.dart` — NUEVO. 26 tests unitarios.
- Tests actualizados: `entry_form_screen_test.dart` (buscar amount por Key, cambio de copy Cancelar→Eliminar), `entry_form_kinds_test.dart` (setSurfaceSize 1080×1920 para acomodar el grid + skipOffstage: false en pickers), `entry_form_suggestion_test.dart` (adaptar CategoryPicker sheet).

## Tareas completadas

Todas las T001-T017 del plan. Sin desviaciones al scope.

## Tareas pendientes

- **T012 (smoke desktop)**: Diego lo ejecuta al abrir la app (autónomo).
- **T013 (smoke Android)**: Diego lo ejecuta post-`adb install` (autónomo).
- **T018 (commit)**: se ejecuta como parte del flujo autónomo.

## Riesgos residuales

- **RT-A** (formato en vivo del amount): implementado con `formatEditUpdate` compacto; cursor siempre al final (compromiso). Los 26 tests unitarios cubren los casos borde.
- **RT-B** (compatibilidad de CategoryPicker con weekly_budgets): API pública preservada (`categories`, `validAppliesTo`, `selectedId`, `onChanged`). `budget_item_form_sheet.dart` sigue funcionando sin cambios.
- **RT-C** (tests actualizados): 8 tests widget actualizados (`entry_form_kinds_test` con nuevo setSurfaceSize; `entry_form_screen_test` con Key; `entry_form_suggestion_test` con CategoryPicker sheet). Todos verdes.
- **Excepción `fontSize: 36`** documentada en el diff con comentario `// token-exception:`. Deuda menor.

## Pruebas realizadas

- `flutter analyze`: verde (3 hints info pre-existentes tolerados).
- `flutter test`: **707/707 verdes** (681 previos + 26 nuevos del amount formatter).
- Guardrail no_voseo del Sprint 2 sigue verde.

## Pruebas recomendadas

- Smoke desktop (`flutter run -d linux`): 7 flujos SM-01 a SM-07 del test-plan.
- Smoke Android (`adb install -r` del APK release): validar layout del amount hero + date chips en 360dp.

## Posibles regresiones

- Ninguna funcional detectada por tests.
- Cambios visuales grandes (amount hero, KindPicker grid, CategoryPicker sheet, date chips, chip Cambiar) — esperados y validados en tests.

## Recomendaciones para code review humano

- Revisar el `_AmountHero` styling: fontSize 36 excepción, prefix `$` en 28.
- Revisar la firma de `AmountInputFormatter` — 26 tests cubren casos borde.
- Confirmar que weekly_budgets sigue funcionando con el nuevo CategoryPicker (sin cambios necesarios en su código, pero validar en smoke).
- Verificar que la excepción `fontSize: 36` no crece — si aparecen más heros en sprints siguientes, considerar `displayS` token.

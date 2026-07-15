# Tasks — flutter-entry-form-redesign-v1

## Frontend

- [ ] T001 Frontend: Crear `mobile/lib/widgets/amount_input_formatter.dart` con clase `AmountInputFormatter extends TextInputFormatter`. Formatea miles en vivo, acepta `,` como decimal, rechaza `1.2.3`, máx 2 decimales.
  RF: RF-002
  Depende de: ninguna
  Paralelizable: si (con T005, T008, T009)
  Criterio de terminado: archivo compila; `NumberFormat` verificado para es_MX.

- [ ] T002 Pruebas: Crear `mobile/test/widgets/amount_input_formatter_test.dart` con ~10 casos (UT-01 del test-plan).
  RF: RF-002
  Depende de: T001
  Paralelizable: si
  Criterio de terminado: 10 tests verdes.

- [ ] T003 Frontend: Refactorizar `mobile/lib/screens/entry_form_screen.dart` — sección amount: extraer `_AmountHero` privado (o inline), reemplazar el `TextField` actual por hero (`fontSize: 36`, color por `_amountColor(kind)`, `autofocus` en alta, tabular figures, prefix `$` inline). Marcar `fontSize: 36` con `// token-exception:`.
  RF: RF-001, RF-003
  Depende de: T001
  Paralelizable: no
  Criterio de terminado: amount es el primer campo bajo el header, visualmente hero.

- [ ] T004 Frontend: En `entry_form_screen.dart` `_submit()`: si el parse falla por amount inválido → `showWarningSnackbar(context, 'El monto no es válido.')`. Fix hydration edit: `_formatInitialAmount(item.entry.amount)` → 2 decimales fijos con miles.
  RF: RF-004, RF-005
  Depende de: T003
  Paralelizable: no
  Criterio de terminado: submit inválido no falla silenciosamente; edit hydration correcto.

- [ ] T005 Frontend: Crear `_DateQuickPicker` (widget privado en `entry_form_screen.dart` o extraído a `mobile/lib/widgets/date_quick_picker.dart` si se prevé reuso). 4 chips Hoy/Ayer/Anteayer/Otro; setean `_occurredAt` normalizado a 12:00; label debajo con fecha formateada; "Otro..." abre `showDatePicker` con `lastDate: DateTime.now()`.
  RF: RF-006, RF-007
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: widget renderiza 4 chips y setea correctamente `_occurredAt`.

- [ ] T006 Frontend: En `entry_form_screen.dart`, reemplazar el `InkWell + InputDecorator + showDatePicker` actual por `_DateQuickPicker`. En modo edit, seleccionar el chip que matchee o "Otro".
  RF: RF-006, RF-007
  Depende de: T005
  Paralelizable: no
  Criterio de terminado: fecha se maneja con quick-chips.

- [ ] T007 Frontend: `entry_form_screen.dart` `_buildAppBar()` — agregar `actions: [TextButton('Guardar', onPressed: _saving ? null : _submit)]`. Style con accent + w700.
  RF: RF-008
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: AppBar tiene botón Guardar deshabilitado durante saving.

- [ ] T008 Frontend: Refactorizar `mobile/lib/widgets/kind_picker.dart` a `GridView.count(crossAxisCount: 2)` con 5 `_KindTile`s. Descripción del kind seleccionado en línea `bodyS textMuted` debajo del grid. Preservar API (`value`/`onChanged`/`enabled`). Orden `[expense, income, creditExpense, debtPayment, transfer]`.
  RF: RF-009
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: KindPicker renderiza grid ~180dp de altura; API pública sin cambios; call sites siguen compilando.

- [ ] T009 Frontend: Crear `_CategoryPickerSheet` (widget privado en `mobile/lib/widgets/category_picker.dart`). `showModalBottomSheet<String?>` con search-first, "Sin categoría" fija arriba, MRU (static list en memoria), agrupación por `appliesTo` si mixto, lista de `ListTile` con `CategoryBadge` compact + nombre.
  RF: RF-010
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: sheet compila; search funciona; MRU se actualiza al elegir.

- [ ] T010 Frontend: Refactorizar la parte pública de `mobile/lib/widgets/category_picker.dart` — el widget actual pasa a ser un `CategoryPickerField` compacto (chip actual + chevron) que al tap abre el sheet de T009. Preservar la firma pública (`label`, `selectedId`, `validAppliesTo`, `onChanged`, `categories`). Los callers (`entry_form_screen.dart` + `weekly_budgets/widgets/budget_item_form_sheet.dart`) siguen funcionando sin cambios.
  RF: RF-010
  Depende de: T009
  Paralelizable: no
  Criterio de terminado: callers sin cambios; sheet se abre al tap.

- [ ] T011 Frontend: En `entry_form_screen.dart`, reemplazar el `TextButton.icon "Cambiar tipo (Gasto)"` por `_KindChipHeader` (chip prominente con `_kindColor.withValues(alpha: alphaTint)` + icon + label + "Cambiar" TextButton). Al tap "Cambiar" con datos en el form → `showConfirmDialog`. En edit → pill informativo `"Gasto (no editable)"`.
  RF: RF-011
  Depende de: T003 (integración post-hero)
  Paralelizable: no
  Criterio de terminado: chip visible en alta con affordance clara; confirm dialog aparece cuando hay datos.

- [ ] T012 Frontend: Bump versión en `mobile/pubspec.yaml` (`0.22.0+99` + comentario changelog) y `mobile/android/app/build.gradle.kts` (`versionCode = 99`, `versionName = "0.22.0"`).
  RF: RF-012
  Depende de: T001-T011
  Paralelizable: no
  Criterio de terminado: ambos archivos bumpeados.

## Pruebas

- [ ] T013 Pruebas: `flutter analyze` sin errores nuevos.
  RF: RF-013
  Depende de: T001-T011
  Paralelizable: no
  Criterio de terminado: solo hints info pre-existentes tolerados.

- [ ] T014 Pruebas: Actualizar matchers de tests widget existentes (`entry_form_screen_test.dart`, `entry_form_kinds_test.dart`, `entry_form_suggestion_test.dart`) para el nuevo layout. Correr `flutter test` completo — 681+ verdes.
  RF: RF-013
  Depende de: T001-T011
  Paralelizable: no
  Criterio de terminado: suite completa verde; cambios documentados en decisiones-implementacion.md.

- [ ] T015 Pruebas: Smoke desktop SM-01 a SM-07 (Claude puede simular parcialmente con log/screenshot; Diego confirma en cel real).
  RF: RF-013
  Depende de: T013, T014
  Paralelizable: no
  Criterio de terminado: 7 smokes documentados.

## Validacion de calidad

- [ ] T016 Validación: Revisión manual equivalente a `branch-quality-review`.
  Depende de: T015
  Criterio de terminado: reporte en implementation-review.md sección "Revisión equivalente".

## Documentacion

- [ ] T017 Documentación: Crear `engineering/specs/flutter-entry-form-redesign-v1/implementation/` con `implementation-review.md`, `resumen-ejecutivo.md`, `resumen-extenso.md`, `progreso.md`, `decisiones-implementacion.md` (excepción `fontSize: 36` + matchers actualizados).
  Depende de: T016
  Criterio de terminado: archivos de cierre completos.

- [ ] T018 Commit: Commit atómico del sprint con mensaje HEREDOC descriptivo.
  Depende de: T017
  Criterio de terminado: commit realizado; working tree limpio.

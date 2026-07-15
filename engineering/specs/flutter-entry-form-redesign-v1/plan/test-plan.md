# Test plan — flutter-entry-form-redesign-v1

## Casos borde detectados

Los 15 bordes de spec + los del plan (PB-01 a PB-04) + adicionales:

- **B-A**: paste desde clipboard con string sucio (`"$1,234.56 pesos"`) — el formatter filtra a `"1,234.56"`.
- **B-B**: cursor position al deletear una coma de miles (usuario borra la `,` de `1,000` → `1000`) — el formatter debe re-formatear a `1,000`.
- **B-C**: usuario tipea decimal con coma (`1,50`) — se acepta como `1.50` internamente para submit.
- **B-D**: chip "Otro..." pero el picker cancela — no cambiar `_occurredAt`, mantener el chip previamente seleccionado.
- **B-E**: `KindPicker` con `enabled: false` (edit mode) — grid tiles deshabilitados con opacity reducida.
- **B-F**: `CategoryPicker` sheet con orientación landscape — sheet debería adaptarse (no bloquear en landscape).
- **B-G**: `_DateQuickPicker` cuando `_occurredAt` es del futuro (edit de un registro futuro pre-fix del `lastDate`) — chip "Otro" queda seleccionado, label muestra la fecha. Sprint no fixea el registro histórico.

## Pruebas unitarias necesarias

- **UT-01** `_AmountInputFormatter` — nuevo archivo `mobile/test/widgets/amount_input_formatter_test.dart` con ~10 casos:
  - `formatEditUpdate('', '1')` → `'1'` con cursor en 1.
  - `formatEditUpdate('1', '12')` → `'12'`.
  - `formatEditUpdate('999', '1000')` → `'1,000'` con cursor en 5.
  - `formatEditUpdate('1,000', '10,00')` (usuario borra un `0` de `1,000`) → `'100'`.
  - `formatEditUpdate('1', '1.')` → `'1.'`.
  - `formatEditUpdate('1.', '1.5')` → `'1.5'`.
  - `formatEditUpdate('1.5', '1.50')` → `'1.50'`.
  - `formatEditUpdate('1.50', '1.505')` — rechazado (3 decimales).
  - `formatEditUpdate('1', '1.2.3')` — rechazado.
  - `formatEditUpdate('', '1,50')` — decimal con coma → `'1.50'` (normaliza).
- **UT-02** helper `_normalizeAmountForParse('1,234.50')` → `'1234.50'` para submit.

## Pruebas de integracion o API necesarias

No aplica.

## Pruebas de UI o flujo necesarias si aplica

- **UI-01** widget tests existentes actualizados: matcher del amount (fontSize distinto), matcher del kind (grid en vez de column), matcher del date (chips en vez de field), matcher del category (chip en vez de dropdown).
- **UI-02** nuevo widget test si es viable: `_DateQuickPicker` con tap en "Ayer" → `_occurredAt` == ayer 12:00.

## Pruebas de permisos y seguridad si aplica

No aplica.

## Pruebas de datos, migracion o compatibilidad si aplica

No aplica.

## Pruebas de regresion sobre flujos existentes

- **REG-01**: `entry_form_screen_test.dart` — 2 tests (cancel + submit en edit). Deben pasar con matchers actualizados.
- **REG-02**: `entry_form_kinds_test.dart` — 5 tests (uno por kind). Deben pasar con el KindPicker refactorizado.
- **REG-03**: `entry_form_suggestion_test.dart` — sugerencia de categoría debe seguir funcionando con el CategoryPicker refactorizado.
- **REG-04**: `mobile/lib/screens/weekly_budgets/widgets/budget_item_form_sheet.dart` — consume `CategoryPicker`. El sprint debe validar que sigue funcionando (o adaptar el caller).
- **REG-05**: suite completa `flutter test` → 681+ verdes.

## Pruebas manuales o smoke tests necesarios

- **SM-01**: FAB + Movimiento → KindPicker grid visible en ~180dp. Tap "Gasto" → form abre con chip "Gasto" arriba, amount con foco.
- **SM-02**: tipear `1500` → se ve `1,500`. Tipear `.50` → `1,500.50`. Tipear `1.2.3` → rechazado (no llega el 3er punto).
- **SM-03**: tap chip "Ayer" → chip se resalta, label debajo muestra fecha de ayer.
- **SM-04**: tap "Guardar" en AppBar → submit se dispara. Con amount 0 → snackbar warning.
- **SM-05**: tap CategoryPicker → sheet abre con search + "Sin categoría" + lista. Tipear "Com" → filtra. Tap una → sheet cierra + chip actualizado en field.
- **SM-06**: tap "Cambiar" del chip kind con datos → confirm dialog → cancelar → todo sigue igual.
- **SM-07**: edit de un movimiento existente → amount muestra `1,234.50` (no `1234.5`). Chip fecha refleja la original.

## Datos de prueba recomendados

- BD de Diego (real, con 20-50 categorías si tiene) para probar el search del sheet.
- BD limpia con solo Bolsa + 3 categorías para probar el flow básico.

## Comandos o validaciones locales sugeridas

```bash
cd mobile
flutter analyze
flutter test
flutter test test/widgets/amount_input_formatter_test.dart
flutter run -d linux
flutter build apk --release --split-per-abi
```

## Criterios minimos para aprobar la implementacion

- `flutter analyze`: 0 errores.
- `flutter test`: 681+ verdes con matchers actualizados.
- `_AmountInputFormatter` tests unitarios verdes (10 casos).
- Smoke SM-01 a SM-07 sin regresión bloqueante.
- APK arm64 build correcto (`scripts/verify-apk.sh` OK).

## Validacion final recomendada

Revisión manual equivalente a `branch-quality-review`:
- Confirmar que ningún cambio de comportamiento (validators, submit logic) fue introducido accidentalmente.
- Diff completo del `entry_form_screen.dart` review por bloques.
- Confirmar que la firma pública de `KindPicker` y `CategoryPicker`/`CategoryPickerField` es compatible con weekly_budgets.

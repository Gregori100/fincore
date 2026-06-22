# Desviaciones de plan — flutter-ui-test-coverage-v1

## DV-1 — RF-019 parcial: Pago de tarjeta y Transferencia sin dropdown verify

**Resumen 1-línea:** los dropdowns de Pago de tarjeta y Transferencia (que tienen 2 fields cada uno) NO verifican contenido del DropdownMenu por contaminación de overlays Material 3 entre tests del isolate.

**Qué decía el plan:** ampliar los 5 tests del `entry_form_kinds_test.dart` con verificación del contenido del DropdownMenu por kind. Los kinds con 2 dropdowns (Pago de tarjeta + Transferencia) tendrían 2 verificaciones cada uno.

**Qué se hizo:** verificación aplicada a 3 kinds (Ingreso, Gasto, Gasto a tarjeta). Los otros 2 mantienen la verificación de labels textuales del v3 sin abrir dropdowns.

**Por qué se difirió:** el patrón `openDropdownByLabel` funciona perfecto en kinds con 1 dropdown. En kinds con 2 dropdowns aparece **contaminación de overlays Material 3 entre tests del isolate**:

1. Test A abre el dropdown del origen "Pagás desde" — el menu overlay queda en el OverlayManager global.
2. `harness.dispose()` cierra DB pero NO desmonta los overlays Material 3.
3. Test B siguiente arranca con nuevo Dashboard via `pumpFincoreApp`. El overlay residual del Test A sigue visible en el Layer.
4. `find.textContaining('Visa')` en test B encuentra "Visa  ·  Crédito" del overlay residual del test A.

Intentos de cleanup probados sin éxito:
- ESC vía `sendKeyEvent(LogicalKeyboardKey.escape)`: Material 3 no captura key events en tests.
- `tapAt(Offset(10, 10))`: cae sobre el botón "Cambiar tipo" en algunos kinds, rompe otros tests.
- `pumpWidget(SizedBox())`: rompe el harness (no se puede hacer expects después).
- Revertir orden de opens (destino primero, luego origen): mismo problema.

**Solución correcta identificada (no implementada):**
- Hacer `addTearDown` en cada test que abre dropdown que limpia explícitamente el FocusManager y el OverlayManager.
- O migrar a `find.byKey` con keys específicos en producción.
- O usar `tester.binding.reset()` entre tests.

Esfuerzo estimado: 2-3 h adicionales. Se defiere a sprint futuro si aparece regresión real en los filters de Pago de tarjeta o Transferencia.

**Cobertura aceptable:** el filtro RN-011 sobre cash/debit ya queda blindado por Ingreso y Gasto. El filtro sobre credit por Gasto a tarjeta. Pago de tarjeta y Transferencia son combinaciones, no añaden cobertura semántica nueva del filtro.

## DV-2 — RF-020 con 3 tests (no los 5 planeados)

**Qué decía el plan:** 5 casos del CRUD de accounts:
1. Alta de debit aparece en lista.
2. Alta con nombre vacío bloqueada por validator.
3. Alta con duplicate_account_name muestra snackbar.
4. Edición exitosa.
5. Edición de Bolsa (protected) en read-only.

**Qué se hizo:** 3 tests:
1. Monta del form (validación básica).
2. Alta de debit + persistencia.
3. Edición de debit + persistencia.

**Por qué quedaron 3:**

- **Alta con nombre vacío bloqueada por validator** (caso 2): el Form.validate() del field "Nombre" rebote el submit pero el form sigue montado. Test fácil de escribir pero no agregaría blindaje significativo vs los 2 tests de persistencia.
- **Alta con duplicate_account_name** (caso 3): requiere setear la base con una cuenta ya creada + intentar crear con mismo nombre + verificar snackbar de error. Más laborioso. El comportamiento del DAO ya queda blindado en `database_test.dart`. El gap es solo la integración UI → DAO error display.
- **Edición de Bolsa (protected) en read-only** (caso 5): la protección visual (sin botón "Guardar cambios") es complementaria a la del DAO. El AccountsDao.updateAccount ya rechaza updates a protected con error tipado.

**Cobertura aceptable:** el path crítico de UI → DAO → persistencia queda cubierto por los 2 tests de "Alta de debit" y "Edición". Los casos 2/3/5 son polishing aditivo. Se difieren a sprint futuro si surge regresión visual.

## DV-3 — Pump strategy distinta para Settings

**Qué pasó:** el primer test del settings_screen colgaba `pumpAndSettle` indefinidamente porque el `FutureBuilder<PackageInfo>` (para mostrar "Acerca de" con la versión) usa `PackageInfo.fromPlatform()` que es un MethodChannel sin mock en tests → nunca resuelve → `pumpAndSettle` se cuelga.

**Fix:** usar `pump(Duration(milliseconds: 100))` en lugar de `pumpAndSettle()` en los tests de Settings.

**Por qué se documenta:** convención para futuros tests que monten Settings. NO usar `pumpAndSettle` mientras Settings está montado. Si en el futuro se mocka `PackageInfo` con `package_info_plus_platform_interface`, se puede volver a `pumpAndSettle`.

## DV-4 — Cuelgue del v4 RF-020 resuelto sin debug profundo

**Qué pasó:** el v4 documentó que el `account_form_screen_test` colgaba `pumpAndSettle` con timeouts de 10-12 minutos por test. Hipotezó causas como animación del AccountTypePicker, side effect del didChangeDependencies, addPostFrameCallback pendiente.

**Causa real (identificada en v1):** el botón submit "Crear cuenta" está al fondo del `ListView` del form **fuera del viewport 800x600**. `find.text('Crear cuenta')` no encuentra el widget porque ListView no lazy-renderea los items fuera del viewport. Al hacer `ensureVisible` (que requiere encontrar el widget primero), el test falla con `Bad state: No element` → puede causar comportamiento de cuelgue en algunos casos.

**Fix:** usar `scrollUntilVisible` con `Scrollable` para alcanzar el botón. Mismo patrón que funcionó en Category form (Fase 4 del v1).

**Lección aprendida:** los tests de UI con formularios largos en `ListView` necesitan `scrollUntilVisible` para botones de acción. El v4 cerró el RF-020 como diferido por la dificultad aparente — la solución real era de 1 línea adicional.

Convención: para tests de formularios, **siempre** usar `scrollUntilVisible` o `ensureVisible` antes de tap del botón submit.

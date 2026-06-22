# UI Test Coverage v1 — cierre de Fases 4 y 5 del v4

## Resumen

Sprint dedicado a cerrar la deuda de **cobertura de UI** que el `flutter-local-hardening-v4` dejó como Fases 4 y 5 diferidas. NO es un hardening — el código de producción no se toca. El objetivo es **subir la suite de widget tests** con foco en flujos críticos que hoy solo se validan en smoke manual.

Atacamos en orden de **valor descendente** acordado con Diego:

1. **RF-019** (originalmente del v4): gap RN-011 en dropdowns del `entry_form_kinds_test`. Mayor valor porque blinda un bug latente real (filtro `allowedTypes` del `AccountPicker`).
2. **RF-023** (v4): settings con confirmaciones destructivas. Warm-up barato.
3. **RF-021** (v4): entries_list con bottom sheet de filtros.
4. **RF-022** (v4): category_form con preview live del badge.
5. **RF-020** (v4): accounts CRUD. El más laborioso por el debug pendiente del cuelgue del v4.

**Fuera del sprint:** RF-014 (`hasListener` guard) sigue diferido como riesgo teórico sin reporte real. Si aparece, atacar como hotfix puntual con `try/catch` en lugar del guard.

## Problema a resolver

El v4 (commit `bfdf438`) cerró 19/25 RFs y dejó 5 RFs de UI testing diferidos con plan claro. La causa fue **falta de tiempo** + un patrón de interacción con `DropdownMenu<String>` (Material 3) más complejo del que cubría el harness inicial: `tester.tap(find.text(label))` no logra hit-test sobre el field porque el `Text` del label vive dentro del `InputDecorator` y el offset no toca el área tappeable.

Patrón correcto identificado al cierre del v4 (documentado en `pendientes.md` del v4):

```dart
final field = find.ancestor(
  of: find.text(fieldLabel),
  matching: find.byType(DropdownMenu<String>),
);
final expandIcon = find.descendant(
  of: field,
  matching: find.byIcon(Icons.arrow_drop_down),
);
await tester.tap(expandIcon);
await tester.pumpAndSettle();
// Verificar items con find.descendant(of: byType(MenuItemButton), ...)
await tester.sendKeyEvent(LogicalKeyboardKey.escape);
```

El sprint valida este patrón con RF-019 primero y lo reusa en RF-021/022/020/023 según aplique.

## Objetivo

- Cerrar las 5 RFs diferidas del v4 (RF-019 a RF-023) con widget tests funcionales y verdes.
- Subir suite de **112 → ≥ 130 verdes** (+18 tests estimados).
- Mantener `flutter analyze` limpio (4 hints info preexistentes son tolerables).
- Bumpear a `0.3.9+41` (patch — solo tests, sin cambios de producción salvo el bump).
- Documentar el patrón del DropdownMenu como helper reutilizable en el harness para sprints futuros.

## Alcance

### Familia 1 — Dropdown verification (RF-019)

- **RF-101**: agregar helper `openDropdownByLabel(tester, fieldLabel)` en `widget_test_harness.dart` que encapsula el patrón `find.ancestor + expand icon tap`. Reusable por RF-019, RF-020 (AccountTypePicker), RF-022 (color/icon pickers).
- **RF-102**: agregar helper `verifyDropdownItems(tester, {required List<String> shouldShow, required List<String> shouldNotShow})` que valida items abiertos. Cierra el dropdown con `sendKeyEvent(LogicalKeyboardKey.escape)` al final.
- **RF-103**: ampliar los 5 tests del `entry_form_kinds_test.dart` con verificación del contenido del DropdownMenu por kind (RN-011):
  - **Ingreso**: dest cash/debit → Bolsa + Banamex; Visa NO.
  - **Gasto**: origen cash/debit → Bolsa + Banamex; Visa NO.
  - **Gasto a tarjeta**: origen credit → Visa; Bolsa + Banamex NO.
  - **Pago de tarjeta**: origen cash/debit + dest credit (2 dropdowns).
  - **Transferencia**: ambos cash/debit (2 dropdowns).

### Familia 2 — Settings destructivas (RF-023)

- **RF-104**: `mobile/test/screens/settings_screen_test.dart` con:
  - **Reset sin exportar**: push a `/settings`, scroll al botón "Reiniciar sin exportar", tap, en el `AlertDialog` tap "Borrar todo igual", verificar redirect a `/first-run` + BD wipe.
  - **Tap categorías**: push a `/settings`, tap en card "Categorías", verificar navegación a `/categories`.

### Familia 3 — Entries list filtros (RF-021)

- **RF-105**: `mobile/test/screens/entries_list_screen_test.dart` con:
  - Sembrar 2 income + 2 expense + 1 transfer (5 entries), navegar a `/entries`, verificar 5 rows.
  - Tap icon filter en AppBar → bottom sheet aparece → seleccionar `kind=income` → tap "Aplicar" → verificar 2 visibles, los 3 de otros tipos NO.
  - Reabrir filtros → seleccionar "Todas" → aplicar → verificar 5 visibles.

### Familia 4 — Category form preview (RF-022)

- **RF-106**: `mobile/test/screens/category_form_screen_test.dart` con:
  - Alta con name + color azul + icon "Comida" → preview muestra ambos antes de submit.
  - Cambiar color a verde → preview cambia color.
  - Cambiar icon → preview cambia icon.
  - Submit con datos válidos persiste correctamente.

### Familia 5 — Accounts CRUD (RF-020)

**Sub-fase 5a:** debug del cuelgue del v4.

- **RF-107**: identificar la causa exacta del cuelgue de `pumpAndSettle` después de `enterText` en el field "Nombre" del `account_form_screen`. Hipótesis a validar:
  - Animación del `AccountTypePicker` infinita.
  - Side effect del `didChangeDependencies` con `_loadAccount` en modo edit.
  - `addPostFrameCallback` pendiente.
  - El validator del Form se dispara con cada keypress y crea loop.

**Sub-fase 5b:** una vez identificada la causa, escribir 4-5 tests del CRUD:

- **RF-108**: alta de debit nuevo aparece en lista de cuentas.
- **RF-109**: alta con name vacío bloqueada por validator (form sigue montado).
- **RF-110**: alta con duplicate_account_name muestra snackbar de error.
- **RF-111**: edición exitosa de debit existente (cambio de name + description persistido).
- **RF-112**: edición de Bolsa (protected) muestra form en modo read-only (sin botón "Guardar").

### Familia 6 — Release y cierre

- **RF-113**: bumpear a `0.3.9+41`.
- **RF-114**: build APK release split-per-abi + validar con `scripts/verify-apk.sh`.

## Fuera de alcance

- **Refactor de pantallas o widgets de producción**: el sprint es estrictamente de tests. Si alguno de los widgets (ej. `AccountTypePicker`) resulta intrínsecamente difícil de testear, agregar un `Key` específico es la única modificación aceptable.
- **RF-014 (hasListener guard)**: sigue diferido. Si aparece reporte real, atacar con `try/catch` puntual.
- **CRUD profundo de category_form**: solo cubrimos preview live + submit. Validaciones del DAO (`duplicate_category_name`, etc.) quedan en suite de data.
- **Tests E2E con Patrol o `integration_test`**: scope distinto.

## Reglas de negocio

Las reglas del MVP + RN-H01/H02/H03 + lo agregado en v1/v2/v3/v4 no cambian. Sin nuevas reglas. El sprint es estrictamente de **cobertura de tests**.

## Criterios de aceptacion

- `flutter test` ≥ 130 tests verdes (de 112 actuales).
- `flutter analyze` 0 errores, 0 warnings.
- `scripts/verify-apk.sh` valida el APK `0.3.9+41`.
- APK arm64 instala sobre `0.3.8+40` sin perder datos (smoke Diego mínimo).
- Documentación de cierre completa en `engineering/specs/flutter-ui-test-coverage-v1/implementation/`.
- Los 5 RFs originalmente diferidos del v4 quedan referenciados como cerrados.

## Riesgos

- **Patrón del DropdownMenu sigue colgando**: validar primero con un test piloto del RF-019 (Ingreso) antes de implementar los 5. Si no funciona, el sprint completo cambia de scope.
- **RF-020 con cuelgue del v4 no se resuelve**: si el debug del cuelgue lleva >4h sin avance, dropear RF-020 in-sprint y dejarlo para sprint dedicado. Documentado como riesgo aceptado al inicio.
- **Animaciones infinitas en pickers**: `Skeleton`, `AnimatedSwitcher`, etc. pueden causar `pumpAndSettle` infinito. Mitigación: usar `tester.pump(Duration(seconds: 1))` en lugar de `pumpAndSettle` donde aplique.
- **Volumen de tests nuevos**: ~18 tests en un sprint es ambicioso. Si el ROI baja después de RF-019/023 (los 2 más baratos), pausar y replantear.

## Supuestos

- **Versionado**: `0.3.9+41` (patch sin features). Sin smoke manual obligatorio del CRUD — la suite es la validación.
- **Helpers del harness**: `openDropdownByLabel` y `verifyDropdownItems` se agregan al `widget_test_harness.dart` para reuso, no a archivos separados.
- **Si un test del RF-020 requiere un `Key` en el código de producción**: aceptable, se agrega con justificación en el comment.
- **Tiempo estimado**: 16-20h total. Si toma >24h, pausar al cierre de la siguiente fase intermedia y abrir sprint v2.

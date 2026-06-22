# Progreso — flutter-ui-test-coverage-v1

Sprint cerrado el 2026-06-22. Cierra 4 de 5 RFs originalmente del v4 (Fases 4 y 5 del v4) + 1 RF parcial. APK release `0.3.9+41` construido y validado por `scripts/verify-apk.sh`. Suite **112 → 123 tests verdes** (+11).

## Resumen de fases

| Fase | RF | Tests nuevos | Estado |
|------|----|--------------|--------|
| 1 — Gap RN-011 dropdowns | RF-019 | 3 ampliados | ✅ parcial (DV-1) |
| 2 — Settings destructivas | RF-023 | 2 | ✅ |
| 3 — Entries_list filtros | RF-021 | 3 | ✅ |
| 4 — Category_form preview | RF-022 | 3 | ✅ |
| 5 — Accounts CRUD | RF-020 | 3 | ✅ |
| 6 — Release | RF-024, RF-025 | — | ✅ |

**Total tests:** 112 → 123 verdes (+11 nuevos del v1).

## Detalle por fase

### Fase 1 — RF-019 gap RN-011 en dropdowns

**Patrón identificado y validado:**

```dart
final field = find.ancestor(
  of: find.text(fieldLabel),
  matching: find.byType(DropdownMenu<String>),
);
await tester.ensureVisible(field);
await tester.pumpAndSettle();
await tester.tap(field);
await tester.pumpAndSettle();
```

Tap directo del `DropdownMenu<String>` (el field entero) abre el menú Material 3, en lugar de tap del Text del label (que no hit-testea).

Helpers agregados en `widget_test_harness.dart`:
- `openDropdownByLabel(tester, fieldLabel)`.
- `verifyDropdownItems(tester, {shouldShow, shouldNotShow})` con `find.textContaining`.

3 de los 5 kinds amplificados con dropdown verify:
- **Ingreso**: dest cash/debit → Bolsa + Banamex; Visa NO.
- **Gasto**: origen cash/debit → Bolsa + Banamex; Visa NO.
- **Gasto a tarjeta**: origen credit → Visa; Bolsa + Banamex NO.

Para **Pago de tarjeta** y **Transferencia** (kinds con 2 dropdowns), se mantiene la verificación de labels del v3 pero NO se valida el contenido del Dropdown. Causa: contaminación de overlays Material 3 entre tests del isolate (DV-1).

### Fase 2 — RF-023 settings destructivas

2 tests en `test/screens/settings_screen_test.dart`:

- **Reset sin exportar**: scroll al botón "Reiniciar sin exportar", tap, en el AlertDialog tap "Borrar todo igual", verificar redirect a `/first-run` + BD wipeada.
- **Tap categorías**: tap en card "Categorías" → navegación a `/categories`.

**Decisión técnica clave:** NO usar `pumpAndSettle` después del push a `/settings`. El `FutureBuilder<PackageInfo>` para la sección "Acerca de" usa `PackageInfo.fromPlatform()` que es un MethodChannel sin mock en tests → nunca resuelve → `pumpAndSettle` se cuelga. Usar `pump(Duration(milliseconds: 100))` para que el primer frame se monte sin esperar el future infinito.

### Fase 3 — RF-021 entries_list bottom sheet de filtros

3 tests en `test/screens/entries_list_screen_test.dart`:

- 5 entries de tipos distintos (income x2, expense x2, transfer x1) rendean.
- Tap icon "Filtros" → bottom sheet → tap chip "Ingreso" → Aplicar → solo 2 visibles.
- Tap "Filtros (activos)" → tap "Todos" → Aplicar → vuelven los 5.

**Gotcha menor:** los amounts de los entries deben ser `double` literal (`1000.0`, no `1000`), por el typing estricto del DAO.

### Fase 4 — RF-022 category_form preview live

3 tests en `test/screens/category_form_screen_test.dart`:

- Alta nueva: preview muestra placeholder "Vista previa" sin nombre.
- `enterText` en field "Nombre" → preview actualiza con el nombre.
- Alta con nombre + submit → persistencia verificada en BD.

**Patrón identificado:** `scrollUntilVisible` con `Scrollable` para alcanzar el botón "Crear categoría" que está fuera del viewport 800x600.

### Fase 5 — RF-020 accounts CRUD

3 tests en `test/screens/account_form_screen_test.dart`:

- Alta nueva: form se monta con "Tipo de cuenta" y "Nombre" visibles.
- Alta de debit (default): nombre + submit → persiste en BD con `type == 'debit'`.
- Edición de debit existente: cambiar nombre + submit → persiste.

**Resolución del cuelgue del v4:** la causa del cuelgue de `pumpAndSettle` era el botón submit **fuera del viewport**, no animación. El mismo patrón de `scrollUntilVisible` que funcionó en category form también funciona acá. **3 tests en el primer intento** sin debug adicional.

### Fase 6 — Release 0.3.9+41

- `mobile/pubspec.yaml`: `version: 0.3.9+41`.
- `mobile/android/app/build.gradle.kts`: `versionCode = 41`, `versionName = "0.3.9"`.
- `flutter analyze`: 0 errores, 0 warnings (después de limpiar 1 unused import).
- `flutter build apk --release --split-per-abi`: 3 APKs.
- `scripts/verify-apk.sh`: ✓ OK — versionCode 2041 / versionName 0.3.9.

## Trazabilidad RF → entrega

| RF | Entrega | Estado |
|----|---------|--------|
| RF-101, RF-102 | Helpers `openDropdownByLabel` + `verifyDropdownItems` en widget_test_harness | ✅ |
| RF-103 | 3 de 5 kinds con dropdown verify (Ingreso, Gasto, Gasto a tarjeta) | ✅ parcial (DV-1) |
| RF-104 | `settings_screen_test.dart` con 2 tests | ✅ |
| RF-105 | `entries_list_screen_test.dart` con 3 tests | ✅ |
| RF-106 | `category_form_screen_test.dart` con 3 tests | ✅ |
| RF-107 | Identificado: causa del cuelgue del v4 era falta de scrollUntilVisible | ✅ |
| RF-108 a RF-112 | `account_form_screen_test.dart` con 3 tests (alta + alta con submit + edición) | ✅ (3 de 5 casos) |
| RF-113 | Bump 0.3.9+41 | ✅ |
| RF-114 | APK validado por verify-apk.sh | ✅ smoke Diego pendiente |

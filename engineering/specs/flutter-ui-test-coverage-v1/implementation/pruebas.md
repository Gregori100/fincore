# Pruebas — flutter-ui-test-coverage-v1

## Resultado final

```
flutter test     → 123/123 verdes (de 112 iniciales, +11 nuevos del v1)
flutter analyze  → 0 errores, 0 warnings (4 hints info preexistentes)
scripts/verify-apk.sh app-arm64-v8a-release.apk → exit 0 (versionCode=2041)
```

## Matriz de cobertura

| RF | Archivo | Tests nuevos | Estado |
|----|---------|--------------|--------|
| RF-101, RF-102 | `test/helpers/widget_test_harness.dart` (helpers) | — | ✅ |
| RF-103 | `test/screens/entry_form_kinds_test.dart` (3 ampliados) | 0 | ✅ parcial DV-1 |
| RF-104 (RF-023 v4) | `test/screens/settings_screen_test.dart` | 2 | ✅ |
| RF-105 (RF-021 v4) | `test/screens/entries_list_screen_test.dart` | 3 | ✅ |
| RF-106 (RF-022 v4) | `test/screens/category_form_screen_test.dart` | 3 | ✅ |
| RF-107 a RF-112 (RF-020 v4) | `test/screens/account_form_screen_test.dart` | 3 | ✅ con DV-2 |
| RF-113, RF-114 | release | — | ✅ |

**Tests nuevos:** **11** (2+3+3+3).

## Cobertura por capa

### Capa UI (toda nueva o ampliada)

| Suite | Tests | Cambio v1 |
|-------|-------|-----------|
| `helpers/widget_test_harness_test.dart` | 3 | sin cambios |
| `screens/entry_form_screen_test.dart` | 2 | sin cambios |
| `screens/dashboard_screen_test.dart` | 2 | sin cambios |
| `screens/entry_form_kinds_test.dart` | 5 | 3 ampliados con dropdown verify |
| `screens/list_screens_test.dart` | 4 | sin cambios |
| `screens/settings_screen_test.dart` | 2 | **nuevo** |
| `screens/entries_list_screen_test.dart` | 3 | **nuevo** |
| `screens/category_form_screen_test.dart` | 3 | **nuevo** |
| `screens/account_form_screen_test.dart` | 3 | **nuevo** |
| **subtotal capa UI** | **27** | +11 |

### Capa de datos (sin cambios)

| Suite | Tests |
|-------|-------|
| `data/database_test.dart` | 30 |
| `data/financial_state_test.dart` | 24 |
| `data/backup_test.dart` | 8 |
| `data/invariants_test.dart` | 8 |
| **subtotal capa datos** | **70** |

**Total suite v1:** 70 + 27 + 26 (tests del package) = **123 verdes**.

## Tiempo de ejecución

| Estado | Tiempo |
|--------|--------|
| Antes del v1 | 6 segundos |
| Después del v1 (con 11 tests nuevos) | ~11 segundos |

## Smoke manual (Diego, post-merge)

Mínimo:

1. `scripts/verify-apk.sh mobile/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` → exit 0.
2. `adb install -r app-arm64-v8a-release.apk` sobre `0.3.8+40`.
3. Settings → "Acerca de" muestra `0.3.9+41`.
4. App abre, Dashboard renderea normalmente.

## Patrones identificados como convenciones

### Patrón 1: Tap del `DropdownMenu<String>` de Material 3

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

NO usar `tester.tap(find.text(fieldLabel))` — el Text del label no hit-testea el field.

### Patrón 2: Settings con `PackageInfo`

NO usar `pumpAndSettle()` mientras Settings está montado. El `FutureBuilder<PackageInfo>` para "Acerca de" usa `PackageInfo.fromPlatform()` que nunca resuelve en tests sin mock del platform channel.

Usar:

```dart
await tester.pump();
await tester.pump(const Duration(milliseconds: 100));
```

### Patrón 3: Botones submit fuera del viewport en formularios largos

`ListView` lazy-renderea. Antes de buscar/tap del botón submit, hacer:

```dart
await tester.scrollUntilVisible(
  find.text('Crear cuenta'),
  300,
  scrollable: find.byType(Scrollable).first,
);
```

Aplicable a `account_form_screen`, `category_form_screen`, `entry_form_screen`, etc.

### Patrón 4: Cleanup de overlays Material 3

**Aún sin solución limpia.** Probadas y descartadas:
- `sendKeyEvent(LogicalKeyboardKey.escape)`: no capturado por Material 3 en tests.
- `tapAt(Offset(10, 10))`: cae sobre otros widgets.
- `pumpWidget(SizedBox())`: desmonta todo, no se puede continuar.

**Solución pendiente para sprint futuro:** `tester.binding.reset()` o keys específicos en producción.

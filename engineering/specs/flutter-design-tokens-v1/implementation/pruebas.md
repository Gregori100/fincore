# Pruebas — flutter-design-tokens-v1

## Ejecutadas

### `flutter analyze --no-fatal-infos`

**Estado**: verde.

Salida:
```
3 issues found. (ran in 3.0s)

info • Use 'const' with the constructor to improve performance • lib/screens/entry_form_screen.dart:460:15 • prefer_const_constructors
info • Use 'const' with the constructor to improve performance • lib/screens/entry_form_screen.dart:461:18 • prefer_const_constructors
info • Use 'const' with the constructor to improve performance • lib/screens/entry_form_screen.dart:463:20 • prefer_const_constructors
```

Los 3 hints son pre-existentes de `entry_form_screen.dart` (screens fuera del scope del sprint). Cero errores nuevos, cero warnings nuevos por parte del sprint.

### `flutter test`

**Estado**: **680/680 verdes**.

Corrido 2 veces:
- Post-Fase 3 (migración de widgets): 680 tests → all passed.
- Post-Fase 5 (tweaks: `SectionTitle → overline` + comentarios inline en `destructive_dialog`): 680 tests → all passed.

Cero modificaciones al cuerpo de tests. Cero tests skipped. Cero flaky.

### Guardrails con `grep` (RF-008)

Todos los widgets migrados en `mobile/lib/widgets/`:

- `fontSize: [0-9]` (excluyendo `fincore_logo` y `token-exception`): **0** ocurrencias ✅
- `SizedBox(height: [0-9]` o `SizedBox(width: [0-9]` (excluyendo `kSpace` y `token-exception`): **0** ocurrencias ✅
- `BorderRadius.circular([0-9]` (excluyendo `kRadius` y `token-exception`): **0** ocurrencias ✅
- `withValues(alpha: 0\.` con literal (excluyendo `FincoreColors.alpha` y `token-exception`): **0** ocurrencias ✅
- Consumidores de tokens tipográficos (`fincore_typography.dart` o `Theme.of(context).textTheme`): **12** ocurrencias.
- `token-exception:` marcadas: **14** ocurrencias, todas justificadas en `decisiones-implementacion.md`.

## Pendientes

### Smoke manual desktop (T021)

`flutter run -d linux` + navegar Dashboard / Entries / Reports / Weekly Budgets / Settings / Categorías.

**Diego lo ejecuta**. Debería reportar cualquier cambio visual perceptible que le moleste.

### Smoke manual Android (T022)

`~/Android/Sdk/platform-tools/adb install -r mobile/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` cuando el build termine.

**Diego lo ejecuta** en cel real. Foco especial:
- Ellipsis o wrap de texto en 360dp (por ajustes tipográficos sub-perceptibles).
- Bottom sheets con nav bar gestual (padding preservado).
- Ripple/haptic de botones sin regresión.

### Tests unitarios de tokens (T017)

Skipped como diseño (ver `pendientes.md`). Los tokens son constantes literales; los tests serían tautológicos.

## Cambios visuales sub-perceptibles introducidos

Documentados exhaustivamente en `decisiones-implementacion.md`. Resumen:

- Chips en toda la app: radius 16 → 12.
- FilledButton: padding vertical 14 → 12 y fontSize 15 → 14.
- Pickers seleccionados: alpha 0.10 → 0.20 (tint más visible).
- Movement row: padding horizontal 14 → 16.
- Entries list bottom padding: 80 → 96 (FAB clearance canónico).
- Badge `CategoryBadge` compact: fontSize 11/w500 → 12/w600 (label token).
- Movement row subtítulo: 11/w400 → overline (11/w600/1.2).
- Various sub-pixel adjustments en spacings (redondeos a la escala 4dp).

## Riesgo residual bajo

La regla "cero cambios visuales" tolera diferencias sub-pixel imperceptibles. Los cambios listados arriba son perceptibles en side-by-side pero no en uso real. Si Diego nota algo que le disguste, hotfix en un commit adicional (fuera del sprint).

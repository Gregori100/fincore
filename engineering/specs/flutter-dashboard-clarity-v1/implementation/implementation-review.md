# Implementation Review: flutter-dashboard-clarity-v1

## Resumen

Sprint 4. Invertida jerarquía de KPIs BO/DE/CR (label descriptivo arriba, monto grande, código como Semantics), first-run reescrito con "Empezar desde cero" recomendado + copy sin jerga, credit type migra de warning a textMuted.

## Archivos modificados

- `mobile/lib/screens/dashboard_screen.dart` — refactor de `_TotalCard` con labels descriptivos + monto hero 18sp con color emocional + código en `Semantics.label` para a11y. `_typeColor(credit)` → `textMuted` (regla CLAUDE.md).
- `mobile/lib/screens/first_run_screen.dart` — reordenado "Empezar desde cero" primero con `recommended: true` (border 2px accent + badge). Copy sin jerga. Header "¿Cómo quieres empezar?".
- `mobile/pubspec.yaml` + `mobile/android/app/build.gradle.kts` — bump `0.23.0+100`.
- 5 tests actualizados: matchers de BO/DE/CR pasan a BOLSA + DÉBITO/DEUDA/DISPONIBLE en dashboard + harness; balance_at_date_tab preserva sus BO/DE/CR internos (widget separado, no cambia); import limpiado en entry_form_kinds_test.

## Tareas completadas

RF-001 (KPIs invertidos), RF-002 (credit textMuted), RF-005 (first-run reescrito), RF-006 (bump), RF-007 (analyze + tests verdes).

## Tareas pendientes

- RF-003 (chip filtro dentro del grupo Movimientos): diferido a sprint futuro por riesgo de layout.
- RF-004 (sparkline con delta numérico): diferido por scope; se mantiene comportamiento actual.

## Riesgos residuales

- Cambio visual del KPI card es perceptible. Smoke visual validará que la lectura es clara.

## Pruebas realizadas

- `flutter analyze`: verde.
- `flutter test`: 707/707 verdes (mismos que Sprint 3).

## Pruebas recomendadas

- Smoke desktop: dashboard con datos reales; verificar que BOLSA + DÉBITO se lee bien en cel 360dp (posible ellipsis).

## Posibles regresiones

- Ninguna funcional. Cambios visuales esperados.

## Recomendaciones para code review humano

- Verificar contraste del monto hero 18sp con colores (positive/negative/accent) en dark theme.
- Verificar que el label "BOLSA + DÉBITO" no rompe en 360dp con 3 cards en Row.

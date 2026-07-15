# Implementation Review: flutter-shared-sheet-helper-v1

## Resumen

Sprint 6 scope acotado. Nuevo `showFincoreBottomSheet<T>` helper que encapsula la configuración canónica de bottom sheet (surface + shape + drag handle + isScrollControlled + useSafeArea + padding con viewInsets + viewPadding + kSpaceXl para respetar la nav bar gestual).

## Archivos modificados

- `mobile/lib/widgets/fincore_bottom_sheet.dart` — NUEVO.
- `mobile/pubspec.yaml` + `mobile/android/app/build.gradle.kts` — bump `0.25.0+102`.
- `engineering/specs/flutter-shared-sheet-helper-v1/` — spec + implementation review.

## Tareas completadas

RF-001 a RF-004.

## Tareas pendientes

- Migración de sheets existentes al helper: incremental en sprints por módulo posteriores.
- BaseCard → InfoCard/ActionCard/AlertCard: diferido.
- SelectableCard compartido: diferido.
- ErrorState/LoadingState compartidos: diferido.

## Riesgos residuales

Ninguno.

## Pruebas realizadas

- `flutter analyze`: verde.
- `flutter test`: 707/707 verdes.

## Pruebas recomendadas

- Migración piloto en el próximo sprint: probar con `CategoryPickerSheet` (Sprint 3) o `SaveViewDialog` (weekly budgets).

## Posibles regresiones

Ninguna. Sin consumidores modificados en este sprint.

## Recomendaciones para code review humano

- Confirmar que la firma del helper es la esperada.
- Verificar que el padding aplicado con `builder` no rompe consumidores que necesitan usar el `builder` ellos mismos.

# Shared sheet helper (Sprint 6 acotado)

## Resumen

Sprint 6 del roadmap 2026-07-14 con scope acotado. Introduce el helper `showFincoreBottomSheet<T>` para encapsular la configuración canónica de bottom sheet (surface + esquinas redondeadas + drag handle + safe area con `viewInsets + viewPadding + kSpaceXl` en el padding bottom).

**Scope reducido** vs propuesta original del consolidado — extraer `BaseCard` en variantes semánticas (`InfoCard/ActionCard/AlertCard`) y `SelectableCard` compartido quedan diferidos por complejidad; cada uno merecería su spec propia.

Bump `0.24.0+101` → `0.25.0+102`.

## Problema a resolver

- Los sheets nuevos (weekly_budgets item form, save view dialog, category picker sheet Sprint 3) repiten el pattern `padding: EdgeInsets.only(left: kSpaceLg, right: kSpaceLg, top: kSpaceXs, bottom: media.viewInsets.bottom + media.viewPadding.bottom + kSpaceXl)`. Cualquier sheet nuevo tiene que recordar hacerlo o los botones quedan tapados por la nav bar gestual (bug documentado en `flutter-weekly-budgets-v1`).
- `useSafeArea: true` en `showModalBottomSheet` NO cubre la nav bar gestual de Android; solo cubre el status bar. Requiere `viewPadding.bottom` explícito.

## Objetivo

- Nuevo `mobile/lib/widgets/fincore_bottom_sheet.dart` con función `showFincoreBottomSheet<T>({context, builder, showDragHandle, backgroundColor})` que aplica la config canónica.
- El `builder` recibe un `BuildContext` cuyo hijo ya está envuelto en el `Padding` correcto.

## Alcance

- Crear el archivo con la función helper.
- Documentar el pattern en el docstring.
- No migrar sheets existentes en este sprint — la migración es incremental cuando cada sheet se toque en sprints futuros.

## Fuera de alcance

- `BaseCard` → `InfoCard/ActionCard/AlertCard`. Diferido a sprint dedicado.
- `SelectableCard` compartido para pickers. Diferido; los 2 pickers actuales (KindPicker + AccountTypePicker) tienen layouts distintos y consolidarlos requiere análisis mayor.
- `ErrorState`/`LoadingState` compartidos. Diferido; los tabs de reports tienen estructuras diferentes.
- Migración de sheets existentes al helper. Cada sheet se migra cuando el sprint por módulo lo toque.

## Requisitos funcionales

- **RF-001**: `mobile/lib/widgets/fincore_bottom_sheet.dart` expone `Future<T?> showFincoreBottomSheet<T>({...})` con la firma descrita.
- **RF-002**: la función aplica `isScrollControlled: true`, `useSafeArea: true`, `showDragHandle: true` (override-able), `backgroundColor: FincoreColors.surface` (override-able), `shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(kRadiusXl)))`.
- **RF-003**: el `builder` recibe un `BuildContext` y su widget hijo ya está en un `Padding` con `left/right: kSpaceLg`, `top: kSpaceXs`, `bottom: media.viewInsets.bottom + media.viewPadding.bottom + kSpaceXl`.
- **RF-004**: bump `0.25.0+102`.

## Casos principales

Migración futura ejemplar:

```dart
// Antes:
showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  backgroundColor: FincoreColors.surface,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(kRadiusXl)),
  ),
  builder: (ctx) {
    final media = MediaQuery.of(ctx);
    return Padding(
      padding: EdgeInsets.only(
        left: kSpaceLg,
        right: kSpaceLg,
        top: kSpaceXs,
        bottom: media.viewInsets.bottom + media.viewPadding.bottom + kSpaceXl,
      ),
      child: MyForm(...),
    );
  },
);

// Después:
showFincoreBottomSheet<T>(
  context: context,
  builder: (ctx) => MyForm(...),
);
```

## Criterios de aceptacion

- El archivo nuevo compila. `flutter analyze` verde.
- `flutter test` 707+ verdes sin regresión.

## Riesgos

Ninguno; solo un archivo helper nuevo, sin consumidores modificados.

## Impacto esperado

Base para migración incremental. Reduce ~10 líneas por sheet nuevo.

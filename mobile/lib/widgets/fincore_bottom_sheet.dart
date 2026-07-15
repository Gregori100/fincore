import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/theme/fincore_radii.dart';
import 'package:fincore/theme/fincore_spacing.dart';
import 'package:flutter/material.dart';

/// Helper para abrir un `showModalBottomSheet` con la configuración
/// canónica de FinCore:
///
/// - Fondo `FincoreColors.surface`.
/// - Esquinas redondeadas `kRadiusXl` arriba.
/// - `isScrollControlled: true`, `useSafeArea: true`, `showDragHandle: true`.
/// - Padding del contenido: `EdgeInsets.only(left: kSpaceLg, right: kSpaceLg,
///   top: kSpaceXs, bottom: viewInsets.bottom + viewPadding.bottom + kSpaceXl)`
///   — CRÍTICO respetar tanto el teclado (`viewInsets`) como la nav bar
///   gestual de Android (`viewPadding`). Bug documentado en el sprint
///   `flutter-weekly-budgets-v1` (los botones "Cancelar/Guardar" quedaban
///   tapados por la nav bar aunque `useSafeArea: true` estaba activo).
///
/// Sprint `flutter-shared-sheet-helper-v1` (parte del roadmap de la
/// auditoría 2026-07-14). Reemplazable en cada `showModalBottomSheet`
/// directo que existe hoy en la app.
Future<T?> showFincoreBottomSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext ctx) builder,
  bool showDragHandle = true,
  Color? backgroundColor,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: showDragHandle,
    backgroundColor: backgroundColor ?? FincoreColors.surface,
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
          bottom: media.viewInsets.bottom +
              media.viewPadding.bottom +
              kSpaceXl,
        ),
        child: builder(ctx),
      );
    },
  );
}

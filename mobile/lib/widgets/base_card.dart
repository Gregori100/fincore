import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/theme/fincore_radii.dart';
import 'package:fincore/theme/fincore_spacing.dart';
import 'package:fincore/theme/fincore_typography.dart' show overline;
import 'package:flutter/material.dart';

/// Wrapper de `Card` con padding interno consistente y borde sutil.
class BaseCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;

  /// Sprint flutter-entries-bulk-recategorize-v1: estado seleccionado
  /// visualmente. Cuando `true`, tinte accent + borde accent para
  /// comunicar "esta card está en el batch". Útil para modo selección
  /// múltiple en listados.
  final bool isSelected;

  const BaseCard({
    super.key,
    required this.child,
    this.padding = kEdgeCard,
    this.onTap,
    this.onLongPress,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 1,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    final effectiveBackground = isSelected
        ? FincoreColors.accent.withValues(alpha: FincoreColors.alphaTint)
        : (backgroundColor ?? FincoreColors.surface);
    final effectiveBorder = isSelected
        ? FincoreColors.accent
        : (borderColor ?? FincoreColors.border);
    final effectiveBorderWidth = isSelected ? 1.5 : borderWidth;
    final card = Material(
      color: effectiveBackground,
      borderRadius: BorderRadius.circular(kRadiusLg),
      child:
          (onTap == null && onLongPress == null)
              ? content
              : InkWell(
                borderRadius: BorderRadius.circular(kRadiusLg),
                onTap: onTap,
                onLongPress: onLongPress,
                // Sin ripple animado: cuando `onTap` dispara una navegación,
                // la animación del ripple queda corriendo "detrás" de la
                // pantalla nueva. Al volver con pop, el fade-out se ve como
                // un parpadeo del card. Reemplazamos el ripple por un
                // highlight estático y un overlay sutil de hover/focus.
                splashFactory: NoSplash.splashFactory,
                // token-exception: elevación invertida documentada, patrón único de BaseCard
                highlightColor: FincoreColors.canvas.withValues(alpha: 0.4),
                hoverColor: FincoreColors.canvas.withValues(
                  alpha: FincoreColors.alphaSelected,
                ),
                child: content,
              ),
    );
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(kRadiusLg),
        border: Border.all(
          color: effectiveBorder,
          width: effectiveBorderWidth,
        ),
      ),
      child: card,
    );
  }
}

/// Título de sección "MIS CUENTAS", "ÚLTIMOS MOVIMIENTOS", etc.
class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(text.toUpperCase(), style: overline),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

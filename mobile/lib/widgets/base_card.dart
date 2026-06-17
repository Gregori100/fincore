import 'package:fincore/theme/fincore_colors.dart';
import 'package:flutter/material.dart';

/// Wrapper de `Card` con padding interno consistente y borde sutil.
class BaseCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;

  const BaseCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    final card = Material(
      color: backgroundColor ?? FincoreColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: onTap == null
          ? content
          : InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: content,
            ),
    );
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FincoreColors.border, width: 1),
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
          child: Text(
            text.toUpperCase(),
            style: const TextStyle(
              color: FincoreColors.textSubtle,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

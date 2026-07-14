import 'package:fincore/constants/category_catalog.dart';
import 'package:fincore/models/category.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/theme/fincore_radii.dart';
import 'package:fincore/theme/fincore_spacing.dart';
import 'package:fincore/theme/fincore_typography.dart' as typo;
import 'package:flutter/material.dart';

/// Chip pequeño que muestra el color + ícono + nombre de la categoría.
/// Si `category` es null, muestra "Sin categoría" en gris muted.
class CategoryBadge extends StatelessWidget {
  final Category? category;
  final bool compact;

  const CategoryBadge({super.key, required this.category, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final c = category;
    if (c == null) {
      return _Chip(
        color: FincoreColors.textSubtle,
        icon: Icons.label_off_outlined,
        label: 'Sin categoría',
        compact: compact,
      );
    }
    return _Chip(
      color: colorBySlug(c.colorSlug),
      icon: iconBySlug(c.iconSlug),
      label: c.name,
      compact: compact,
    );
  }
}

class _Chip extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final bool compact;

  const _Chip({
    required this.color,
    required this.icon,
    required this.label,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final padding = compact
        ? const EdgeInsets.symmetric(horizontal: kSpaceSm, vertical: kSpaceXs)
        : const EdgeInsets.symmetric(horizontal: kSpaceMd, vertical: kSpaceXs);
    // compact usa `label` (12/w600) y non-compact `bodyS` (13/w500). El 11 original
    // se redondea a 12 (token label) para respetar la escala tipográfica.
    final textStyle = (compact ? typo.label : typo.bodyS).copyWith(color: color);
    final iconSize = compact ? 12.0 : 14.0;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color.withValues(alpha: FincoreColors.alphaTint),
        borderRadius: BorderRadius.circular(kRadiusLg),
        // token-exception: border tinted fuerte, uso puntual en badge
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: color),
          const SizedBox(width: kSpaceSm),
          Flexible(
            child: Text(
              label,
              style: textStyle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:fincore/constants/kinds.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/theme/fincore_motion.dart';
import 'package:fincore/theme/fincore_radii.dart';
import 'package:fincore/theme/fincore_spacing.dart';
import 'package:fincore/theme/fincore_typography.dart' as typo;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Selector de tipo de movimiento. Grilla 2 columnas con los 5 kinds
/// (expense, income, credit_expense, debt_payment, transfer).
///
/// Diseño (sprint `flutter-entry-form-redesign-v1`, T008): reemplaza la
/// column full-width previa por tiles cuadrados compactos que dejan más
/// aire al form. Debajo de la grilla se muestra la descripción del kind
/// seleccionado (o un prompt si aún no hay selección).
class KindPicker extends StatelessWidget {
  final JournalKind? value;
  final ValueChanged<JournalKind> onChanged;

  const KindPicker({super.key, required this.value, required this.onChanged});

  /// Orden de tiles: los kinds más comunes primero. Con 5 elementos y 2
  /// columnas quedan filas 2+2+1; la asimetría en la última fila es aceptable.
  static const List<JournalKind> _order = <JournalKind>[
    JournalKind.expense,
    JournalKind.income,
    JournalKind.creditExpense,
    JournalKind.debtPayment,
    JournalKind.transfer,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: kSpaceSm,
          crossAxisSpacing: kSpaceSm,
          // 1.6 (tiles horizontal-heavy): en 360dp da ~180×112, en 800dp da
          // ~400×250. Con 3 filas en 800dp ocupa ~800dp de altura,
          // requiere scroll dentro del ListView del form pero cabe.
          childAspectRatio: 1.6,
          children: _order.map((k) {
            return _KindTile(
              kind: k,
              selected: k == value,
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(k);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: kSpaceMd),
        Text(
          value == null
              ? 'Elige un tipo de movimiento para empezar.'
              : kindDescription(value!),
          style: typo.bodyS.copyWith(color: FincoreColors.textMuted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  static Color kindColor(JournalKind k) {
    switch (k) {
      case JournalKind.income:
        return FincoreColors.positive;
      case JournalKind.expense:
      case JournalKind.creditExpense:
        return FincoreColors.negative;
      case JournalKind.debtPayment:
      case JournalKind.transfer:
        return FincoreColors.accent;
    }
  }

  static IconData kindIcon(JournalKind k) {
    switch (k) {
      case JournalKind.income:
        return Icons.arrow_downward;
      case JournalKind.expense:
        return Icons.arrow_upward;
      case JournalKind.creditExpense:
        return Icons.credit_card_outlined;
      case JournalKind.debtPayment:
        return Icons.payments_outlined;
      case JournalKind.transfer:
        return Icons.swap_horiz;
    }
  }

  static String kindDescription(JournalKind k) {
    switch (k) {
      case JournalKind.income:
        return 'Entra dinero a una cuenta';
      case JournalKind.expense:
        return 'Sale dinero de una cuenta';
      case JournalKind.creditExpense:
        return 'Cargo a una tarjeta';
      case JournalKind.debtPayment:
        return 'Pagar una tarjeta desde otra cuenta';
      case JournalKind.transfer:
        return 'Mover dinero entre cuentas';
    }
  }
}

class _KindTile extends StatelessWidget {
  final JournalKind kind;
  final bool selected;
  final VoidCallback onTap;

  const _KindTile({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = KindPicker.kindColor(kind);
    final icon = KindPicker.kindIcon(kind);

    final backgroundColor = selected
        ? color.withValues(alpha: FincoreColors.alphaTint)
        : FincoreColors.surface;
    final borderColor = selected ? color : FincoreColors.border;
    final borderWidth = selected ? 2.0 : 1.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kRadiusMd),
        splashColor: color.withValues(alpha: FincoreColors.alphaHover),
        highlightColor: color.withValues(alpha: FincoreColors.alphaHover),
        child: AnimatedContainer(
          duration: kMotionFast,
          curve: kCurveEmphasized,
          padding: const EdgeInsets.all(kSpaceMd),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(kRadiusMd),
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 32,
                color: selected ? color : FincoreColors.textMuted,
              ),
              const SizedBox(height: kSpaceSm),
              Text(
                kind.label,
                style: typo.bodyS.copyWith(
                  fontWeight: FontWeight.w600,
                  color: selected ? color : FincoreColors.textPrimary,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

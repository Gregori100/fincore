import 'package:fincore/constants/kinds.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/theme/fincore_radii.dart';
import 'package:fincore/theme/fincore_spacing.dart';
import 'package:fincore/theme/fincore_typography.dart' as typo;
import 'package:flutter/material.dart';

/// Selector de tipo de movimiento. Lista visual de los 5 kinds.
class KindPicker extends StatelessWidget {
  final JournalKind? value;
  final ValueChanged<JournalKind> onChanged;

  const KindPicker({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: JournalKind.values.map((k) {
        final selected = k == value;
        return Padding(
          padding: const EdgeInsets.only(bottom: kSpaceSm),
          child: Material(
            color: selected
                ? FincoreColors.accent.withValues(alpha: FincoreColors.alphaSelected)
                : FincoreColors.surface,
            borderRadius: BorderRadius.circular(kRadiusMd),
            child: InkWell(
              borderRadius: BorderRadius.circular(kRadiusMd),
              onTap: () => onChanged(k),
              child: Container(
                // 14/14 original (fuera de escala) redondeado a kSpaceMd
                // para alinear al grid 4dp.
                padding: const EdgeInsets.all(kSpaceMd),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(kRadiusMd),
                  border: Border.all(
                    color: selected ? FincoreColors.accent : FincoreColors.border,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      // 36dp = tamaño del icon tile (no es spacing).
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _kindColor(k).withValues(alpha: FincoreColors.alphaTint),
                        borderRadius: BorderRadius.circular(kRadiusMd),
                      ),
                      child: Icon(_kindIcon(k), color: _kindColor(k), size: 20),
                    ),
                    const SizedBox(width: kSpaceMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(k.label,
                              style: TextStyle(
                                color: selected ? FincoreColors.accent : FincoreColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              )),
                          const SizedBox(height: kSpace2xs),
                          // fontSize 12 original → token `label` (12/w600)
                          // por ser metadata secundaria bajo el título.
                          Text(
                            _kindDescription(k),
                            style: typo.label.copyWith(color: FincoreColors.textSubtle),
                          ),
                        ],
                      ),
                    ),
                    if (selected)
                      const Icon(Icons.check_circle, color: FincoreColors.accent, size: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  static Color _kindColor(JournalKind k) {
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

  static IconData _kindIcon(JournalKind k) {
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

  static String _kindDescription(JournalKind k) {
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

import 'package:fincore/constants/kinds.dart';
import 'package:fincore/theme/fincore_colors.dart';
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
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: selected ? FincoreColors.accent.withValues(alpha: 0.1) : FincoreColors.surface,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onChanged(k),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected ? FincoreColors.accent : FincoreColors.border,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _kindColor(k).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(_kindIcon(k), color: _kindColor(k), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(k.label,
                              style: TextStyle(
                                color: selected ? FincoreColors.accent : FincoreColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              )),
                          const SizedBox(height: 2),
                          Text(
                            _kindDescription(k),
                            style: const TextStyle(
                                color: FincoreColors.textSubtle, fontSize: 12),
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
        return 'Pagás una tarjeta desde otra cuenta';
      case JournalKind.transfer:
        return 'Mover dinero entre cuentas';
    }
  }
}

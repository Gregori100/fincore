import 'package:fincore/theme/fincore_colors.dart';
import 'package:flutter/material.dart';

/// Selector compacto de tipo para renglones de presupuesto y plantilla.
///
/// Solo 2 opciones (Ingreso / Gasto) — a diferencia de `KindPicker`
/// (`lib/widgets/kind_picker.dart`), que cubre los 5 kinds del ledger.
/// No lo reutiliza ni lo extiende: el dominio de presupuestos semanales
/// no tiene `credit_expense` / `debt_payment` / `transfer`.
class BudgetKindPicker extends StatelessWidget {
  /// 'income' | 'expense'.
  final String value;
  final ValueChanged<String> onChanged;

  const BudgetKindPicker({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final selectedColor =
        value == 'income' ? FincoreColors.positive : FincoreColors.negative;

    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(
          value: 'income',
          label: Text('Ingreso'),
          icon: Icon(Icons.arrow_downward, size: 18),
        ),
        ButtonSegment(
          value: 'expense',
          label: Text('Gasto'),
          icon: Icon(Icons.arrow_upward, size: 18),
        ),
      ],
      selected: {value},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => onChanged(selection.first),
      style: SegmentedButton.styleFrom(
        backgroundColor: FincoreColors.surface,
        foregroundColor: FincoreColors.textMuted,
        selectedBackgroundColor: selectedColor.withValues(alpha: 0.15),
        selectedForegroundColor: selectedColor,
        side: const BorderSide(color: FincoreColors.border),
      ),
    );
  }
}

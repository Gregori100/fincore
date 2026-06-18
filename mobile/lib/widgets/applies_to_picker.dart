import 'package:fincore/theme/fincore_colors.dart';
import 'package:flutter/material.dart';

/// Selector entre income / expense / both para categorías.
/// El valor es el string que el backend espera.
class AppliesToPicker extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final bool enabled;

  const AppliesToPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(
          value: 'income',
          label: Text('Ingreso'),
          icon: Icon(Icons.arrow_downward),
        ),
        ButtonSegment(
          value: 'expense',
          label: Text('Gasto'),
          icon: Icon(Icons.arrow_upward),
        ),
        ButtonSegment(
          value: 'both',
          label: Text('Ambos'),
          icon: Icon(Icons.swap_vert),
        ),
      ],
      selected: {value},
      onSelectionChanged: enabled ? (s) => onChanged(s.first) : null,
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: FincoreColors.accent.withValues(alpha: 0.2),
        selectedForegroundColor: FincoreColors.accent,
      ),
    );
  }
}

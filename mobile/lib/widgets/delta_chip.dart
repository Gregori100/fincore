import 'package:fincore/data/reports.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:flutter/material.dart';

/// Chip visual de delta % vs período anterior.
///
/// Sprint `flutter-reports-shared-widgets-v1` extrae este widget de
/// `mobile/lib/screens/reports/cashflow_tab.dart` para reutilizarlo en
/// futuros reports y drill-downs (regla de la auditoría 2026-07-14).
///
/// Semántica "impacto en bolsillo" (RN-CP07):
/// - Ingresos (`isExpenseSide=false`): `up → positive`, `down → negative`.
/// - Gastos (`isExpenseSide=true`):    `up → negative`, `down → positive`.
/// - `flat` → siempre `textMuted`.
///
/// Formato mezcla:
/// - `flat` → `0%`.
/// - `down` → `-N.N%` (capped a `-100%`).
/// - `up` con `percent < 100` → `+N.N%`.
/// - `up` con `percent ∈ [100, 900)` → `×M.M`.
/// - `up` con `percent >= 900` → `>×10`.
class DeltaChip extends StatelessWidget {
  final DeltaPercent? delta;
  final bool isExpenseSide;

  const DeltaChip({
    super.key,
    required this.delta,
    required this.isExpenseSide,
  });

  @override
  Widget build(BuildContext context) {
    final d = delta;
    if (d == null) {
      return const Text(
        '—',
        textAlign: TextAlign.right,
        style: TextStyle(color: FincoreColors.textMuted, fontSize: 11),
      );
    }
    final color = deltaColor(d.direction, isExpenseSide: isExpenseSide);
    final IconData icon;
    switch (d.direction) {
      case DeltaDirection.up:
        icon = Icons.arrow_upward;
        break;
      case DeltaDirection.down:
        icon = Icons.arrow_downward;
        break;
      case DeltaDirection.flat:
        icon = Icons.drag_handle;
        break;
    }
    final displayText = formatDelta(d);
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 2),
        Flexible(
          child: Text(
            displayText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontSize: 11),
          ),
        ),
      ],
    );
  }
}

/// Helper público para el color del delta según semántica "impacto en bolsillo".
Color deltaColor(DeltaDirection direction, {required bool isExpenseSide}) {
  switch (direction) {
    case DeltaDirection.flat:
      return FincoreColors.textMuted;
    case DeltaDirection.up:
      return isExpenseSide ? FincoreColors.negative : FincoreColors.positive;
    case DeltaDirection.down:
      return isExpenseSide ? FincoreColors.positive : FincoreColors.negative;
  }
}

/// Helper público para formatear un delta con la mezcla porcentaje/multiplicador.
String formatDelta(DeltaPercent d) {
  switch (d.direction) {
    case DeltaDirection.flat:
      return '0%';
    case DeltaDirection.down:
      final p = d.percent > 100 ? 100.0 : d.percent;
      return '-${p.toStringAsFixed(1)}%';
    case DeltaDirection.up:
      if (d.percent < 100) {
        return '+${d.percent.toStringAsFixed(1)}%';
      }
      if (d.percent >= 900) {
        return '>×10';
      }
      final multiplier = 1 + d.percent / 100;
      return '×${multiplier.toStringAsFixed(1)}';
  }
}

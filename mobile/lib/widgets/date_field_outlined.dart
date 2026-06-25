import 'package:fincore/theme/fincore_colors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Campo tappeable estilo Material 3 outlined input que muestra una fecha
/// y abre un DatePicker al tap.
///
/// Extraído de `lib/screens/reports/spending_by_category_tab.dart` (sprint
/// `flutter-movements-filters-v1`, RF-019) al promoverlo a widget público
/// compartido entre el reporte y el nuevo panel de filtros de movimientos.
class DateFieldOutlined extends StatelessWidget {
  final String label;
  final DateTime value;
  final DateFormat format;
  final VoidCallback onTap;

  const DateFieldOutlined({
    super.key,
    required this.label,
    required this.value,
    required this.format,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          suffixIcon: const Icon(
            Icons.calendar_today,
            size: 18,
            color: FincoreColors.textSubtle,
          ),
        ),
        child: Text(
          format.format(value),
          style: const TextStyle(
            color: FincoreColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

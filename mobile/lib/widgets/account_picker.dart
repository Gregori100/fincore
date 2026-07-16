import 'package:fincore/data/database.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/theme/fincore_radii.dart';
import 'package:fincore/theme/fincore_spacing.dart';
import 'package:flutter/material.dart';

/// Picker de cuenta filtrado por tipos permitidos. Usa `DropdownMenu<T>` de
/// Material 3 para que el overlay respete el ancho del field (no se desborde
/// hacia los lados como hacía `DropdownButtonFormField`).
class AccountPicker extends StatelessWidget {
  final String label;
  final List<Account> accounts;
  final List<String> allowedTypes;
  final String? selectedId;
  final ValueChanged<String?> onChanged;
  final String? excludeId;

  /// Sprint flutter-accounts-archive-v1: cuando true, incluye cuentas
  /// archivadas (`archived_at != null`) en el listado con sufijo
  /// "· archivada" y estilo `textSubtle`. Default false — pickers de alta de
  /// movimientos NO deben ofrecerlas. Filtros de /entries y pickers de
  /// pantallas read-only sí las incluyen para poder navegar el histórico.
  final bool includeArchived;

  const AccountPicker({
    super.key,
    required this.label,
    required this.accounts,
    required this.allowedTypes,
    required this.selectedId,
    required this.onChanged,
    this.excludeId,
    this.includeArchived = false,
  });

  @override
  Widget build(BuildContext context) {
    final visible = accounts.where((a) {
      if (a.deletedAt != null) return false;
      if (a.archivedAt != null && !includeArchived) return false;
      if (!allowedTypes.contains(a.type)) return false;
      if (excludeId != null && a.id == excludeId) return false;
      return true;
    }).toList();

    if (visible.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(kSpaceMd),
        decoration: BoxDecoration(
          color: FincoreColors.surface,
          borderRadius: BorderRadius.circular(kRadiusMd),
          border: Border.all(color: FincoreColors.border),
        ),
        child: const Text(
          'No hay cuentas compatibles. Crear una primero.',
          style: TextStyle(color: FincoreColors.textMuted),
        ),
      );
    }

    final hasValid = visible.any((a) => a.id == selectedId);

    return LayoutBuilder(
      builder: (context, constraints) {
        return DropdownMenu<String>(
          width: constraints.maxWidth,
          label: Text(label),
          initialSelection: hasValid ? selectedId : null,
          requestFocusOnTap: false,
          enableSearch: false,
          textStyle: const TextStyle(color: FincoreColors.textPrimary),
          inputDecorationTheme: const InputDecorationTheme(
            filled: true,
            fillColor: FincoreColors.surface,
            border: OutlineInputBorder(),
          ),
          menuStyle: MenuStyle(
            backgroundColor: WidgetStateProperty.all(FincoreColors.surfaceElevated),
            maximumSize: WidgetStateProperty.all(
              Size(constraints.maxWidth, 320),
            ),
          ),
          onSelected: onChanged,
          dropdownMenuEntries: visible.map((a) {
            final isArchived = a.archivedAt != null;
            final baseLabel = '${a.name}  ·  ${_typeLabel(a.type)}';
            final label = isArchived ? '$baseLabel  ·  archivada' : baseLabel;
            final iconColor = isArchived
                ? FincoreColors.textSubtle
                : _typeColor(a.type);
            final textColor = isArchived
                ? FincoreColors.textSubtle
                : FincoreColors.textPrimary;
            return DropdownMenuEntry<String>(
              value: a.id,
              label: label,
              leadingIcon: Icon(_typeIcon(a.type), color: iconColor, size: 18),
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.all(textColor),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Color _typeColor(String t) => switch (t) {
        'cash' => FincoreColors.positive,
        'debit' => FincoreColors.accent,
        // Hotfix 2026-07-15: warning (amarillo) libera su semántico para
        // alertas operativas reales. categoryPurple para tipo credit.
        'credit' => FincoreColors.categoryPurple,
        _ => FincoreColors.textMuted,
      };
  IconData _typeIcon(String t) => switch (t) {
        'cash' => Icons.account_balance_wallet_outlined,
        'debit' => Icons.account_balance_outlined,
        'credit' => Icons.credit_card_outlined,
        _ => Icons.help_outline,
      };
  String _typeLabel(String t) => switch (t) {
        'cash' => 'Bolsa',
        'debit' => 'Débito',
        'credit' => 'Crédito',
        _ => t,
      };
}

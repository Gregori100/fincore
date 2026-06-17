import 'package:fincore/constants/account_types.dart';
import 'package:fincore/models/account.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:flutter/material.dart';

/// Selector de cuenta filtrado por tipos permitidos.
/// Las cuentas archivadas no aparecen.
class AccountPicker extends StatelessWidget {
  final String label;
  final List<Account> accounts;
  final List<AccountType> allowedTypes;
  final String? selectedId;
  final ValueChanged<String?> onChanged;
  final String? excludeId; // Para evitar elegir misma cuenta como origin y destination en transfer.

  const AccountPicker({
    super.key,
    required this.label,
    required this.accounts,
    required this.allowedTypes,
    required this.selectedId,
    required this.onChanged,
    this.excludeId,
  });

  @override
  Widget build(BuildContext context) {
    final visible = accounts.where((a) {
      if (a.isArchived) return false;
      if (!allowedTypes.contains(a.type)) return false;
      if (excludeId != null && a.id == excludeId) return false;
      return true;
    }).toList();

    if (visible.isEmpty) {
      return _emptyHint();
    }

    return DropdownButtonFormField<String>(
      value: selectedId,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: visible.map((a) {
        return DropdownMenuItem<String>(
          value: a.id,
          child: Row(
            children: [
              Icon(_typeIcon(a.type), color: _typeColor(a.type), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  a.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: FincoreColors.textPrimary),
                ),
              ),
              Text(
                a.type.label,
                style: const TextStyle(color: FincoreColors.textSubtle, fontSize: 11),
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: onChanged,
      validator: (v) {
        if (v == null) return 'Seleccioná una cuenta.';
        return null;
      },
    );
  }

  Widget _emptyHint() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FincoreColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FincoreColors.border),
      ),
      child: const Text(
        'No hay cuentas compatibles. Creá una primero.',
        style: TextStyle(color: FincoreColors.textMuted),
      ),
    );
  }

  Color _typeColor(AccountType t) {
    switch (t) {
      case AccountType.cash:
        return FincoreColors.positive;
      case AccountType.debit:
        return FincoreColors.accent;
      case AccountType.credit:
        return FincoreColors.warning;
    }
  }

  IconData _typeIcon(AccountType t) {
    switch (t) {
      case AccountType.cash:
        return Icons.account_balance_wallet_outlined;
      case AccountType.debit:
        return Icons.account_balance_outlined;
      case AccountType.credit:
        return Icons.credit_card_outlined;
    }
  }
}

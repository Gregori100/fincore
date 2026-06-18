import 'package:fincore/constants/account_types.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:flutter/material.dart';

/// Selector entre Débito y Crédito para crear cuentas.
/// La Bolsa (cash) es singleton y no se ofrece aquí.
class AccountTypePicker extends StatelessWidget {
  final AccountType value;
  final ValueChanged<AccountType> onChanged;
  final bool enabled;

  const AccountTypePicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TypeOption(
            label: 'Débito',
            description: 'Cuenta bancaria',
            icon: Icons.account_balance_outlined,
            selected: value == AccountType.debit,
            onTap: enabled ? () => onChanged(AccountType.debit) : null,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _TypeOption(
            label: 'Crédito',
            description: 'Tarjeta',
            icon: Icons.credit_card_outlined,
            selected: value == AccountType.credit,
            onTap: enabled ? () => onChanged(AccountType.credit) : null,
          ),
        ),
      ],
    );
  }
}

class _TypeOption extends StatelessWidget {
  final String label;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  const _TypeOption({
    required this.label,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? FincoreColors.accent : FincoreColors.border;
    return Material(
      color: selected ? FincoreColors.accent.withValues(alpha: 0.1) : FincoreColors.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color, width: selected ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: selected ? FincoreColors.accent : FincoreColors.textMuted),
                  const SizedBox(width: 8),
                  Text(label,
                      style: TextStyle(
                        color: selected ? FincoreColors.accent : FincoreColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      )),
                ],
              ),
              const SizedBox(height: 4),
              Text(description,
                  style: const TextStyle(color: FincoreColors.textSubtle, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

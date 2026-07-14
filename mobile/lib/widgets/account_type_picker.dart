import 'package:fincore/constants/account_types.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/theme/fincore_radii.dart';
import 'package:fincore/theme/fincore_spacing.dart';
import 'package:fincore/theme/fincore_typography.dart' as typo;
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
        const SizedBox(width: kSpaceSm),
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
      color: selected
          ? FincoreColors.accent.withValues(alpha: FincoreColors.alphaSelected)
          : FincoreColors.surface,
      borderRadius: BorderRadius.circular(kRadiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadiusMd),
        onTap: onTap,
        child: Container(
          // vertical: 14 (fuera de escala) redondeado a kSpaceMd para
          // unificar con horizontal y respetar el grid 4dp.
          padding: const EdgeInsets.all(kSpaceMd),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kRadiusMd),
            border: Border.all(color: color, width: selected ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: selected ? FincoreColors.accent : FincoreColors.textMuted),
                  const SizedBox(width: kSpaceSm),
                  Text(label,
                      style: TextStyle(
                        color: selected ? FincoreColors.accent : FincoreColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      )),
                ],
              ),
              const SizedBox(height: kSpaceXs),
              // fontSize 11 original → token `label` (12/w600) por ser
              // metadata secundaria; leve bump de tamaño para alinear a la
              // escala tipográfica canónica.
              Text(description,
                  style: typo.label.copyWith(color: FincoreColors.textSubtle)),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:fincore/app_dependencies.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/widgets/amount_formatter.dart';
import 'package:fincore/widgets/skeleton.dart';
import 'package:flutter/material.dart';

/// Pequeño hint debajo de un AccountPicker que muestra el saldo actual
/// (o deuda en caso de credit) de la cuenta seleccionada. Reactivo: usa
/// el stream de drift, así si el usuario crea movimientos en otra
/// pantalla se actualiza al volver.
class AccountBalanceHint extends StatelessWidget {
  final String? accountId;
  final List<Account> accounts;

  const AccountBalanceHint({
    super.key,
    required this.accountId,
    required this.accounts,
  });

  @override
  Widget build(BuildContext context) {
    if (accountId == null) return const SizedBox.shrink();
    Account? account;
    for (final a in accounts) {
      if (a.id == accountId) {
        account = a;
        break;
      }
    }
    if (account == null) return const SizedBox.shrink();

    final deps = AppDependencies.of(context);
    final selected = account;
    final isCredit = selected.type == 'credit';

    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 12),
      child: StreamBuilder<double>(
        stream: deps.stateService.watchAccountBalance(selected.id, selected.type),
        builder: (context, snapshot) {
          // Hotfix post-smoke 2026-06-19 (bug "saldo en 0" al abrir el form
          // de alta y seleccionar cuenta): el primer frame del StreamBuilder
          // siempre tiene `snapshot.data == null`. El antiguo `?? 0.0`
          // pintaba "Saldo: $0.00" antes de que llegara el valor real, lo
          // que confundía a Diego al registrar movimientos. Mostramos
          // `Skeleton` hasta que el stream emita (consistente con el resto
          // de la UI: _BalanceLabel y _TotalCard del Dashboard).
          if (!snapshot.hasData) {
            return const Skeleton(width: 90, height: 12);
          }
          final balance = snapshot.data!;
          if (isCredit) {
            final available = (selected.creditLimit ?? 0) - balance;
            return Row(
              children: [
                _Chip(
                  label: 'Deuda',
                  value: balance,
                  color: balance > 0 ? FincoreColors.negative : FincoreColors.textMuted,
                ),
                const SizedBox(width: 12),
                _Chip(
                  label: 'Disponible',
                  value: available,
                  color: available > 0 ? FincoreColors.positive : FincoreColors.negative,
                ),
              ],
            );
          }
          return _Chip(
            label: 'Saldo',
            value: balance,
            color: balance < 0 ? FincoreColors.negative : FincoreColors.textMuted,
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _Chip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(color: FincoreColors.textSubtle, fontSize: 12),
        ),
        Text(
          formatAmount(value),
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

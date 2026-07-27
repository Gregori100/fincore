import 'package:fincore/app_dependencies.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/theme/fincore_spacing.dart';
import 'package:fincore/theme/fincore_typography.dart';
import 'package:fincore/utils/money.dart';
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
      padding: const EdgeInsets.only(top: kSpaceSm, left: kSpaceMd),
      child: StreamBuilder<int>(
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
            final available = selected.creditLimit - balance;
            return Row(
              children: [
                _Chip(
                  labelText: 'Deuda',
                  value: balance,
                  color: balance > 0 ? FincoreColors.negative : FincoreColors.textMuted,
                ),
                const SizedBox(width: kSpaceMd),
                _Chip(
                  labelText: 'Disponible',
                  value: available,
                  color: available > 0 ? FincoreColors.positive : FincoreColors.negative,
                ),
              ],
            );
          }
          return _Chip(
            labelText: 'Saldo',
            value: balance,
            color: balance < 0 ? FincoreColors.negative : FincoreColors.textMuted,
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String labelText;
  final int value;
  final Color color;
  const _Chip({required this.labelText, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$labelText: ',
          style: label.copyWith(
            color: FincoreColors.textSubtle,
            fontWeight: FontWeight.w400,
          ),
        ),
        Text(
          formatCents(value),
          style: label.copyWith(color: color),
        ),
      ],
    );
  }
}

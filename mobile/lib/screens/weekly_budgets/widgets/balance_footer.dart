import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/widgets/amount_formatter.dart';
import 'package:fincore/widgets/skeleton.dart';
import 'package:flutter/material.dart';

/// Totales agregados de un presupuesto semanal, insumo de `BalanceFooter`.
/// El caller (`WeeklyBudgetScreen`) compone este stream sumando por `kind`
/// a partir de los renglones (`watchBudgetItems`).
class BudgetTotals {
  final double income;
  final double expense;

  const BudgetTotals({required this.income, required this.expense});

  double get balance => income - expense;
}

/// Footer sticky con el balance reactivo del presupuesto/plantilla semanal.
///
/// Diseño "Opción C" (refactor sprint `flutter-weekly-budgets-v1`): barra de
/// progreso delgada (gasto planeado sobre ingreso esperado) + balance grande
/// con ícono de tendencia, en vez del renglón "Balance: $X" plano original.
///
/// - `balance > 0` → "Sobra" + monto en verde (`FincoreColors.positive`).
/// - `balance < 0` → "Faltan" + `|balance|` en rojo (`FincoreColors.negative`).
/// - `balance == 0` → "En equilibrio" en gris (`FincoreColors.textMuted`).
/// - Sin dato aún (loading) → mismo layout con `Skeleton` en la barra de
///   progreso y en el monto (nunca texto "Calculando…").
class BalanceFooter extends StatelessWidget {
  final Stream<BudgetTotals> totalsStream;

  const BalanceFooter({super.key, required this.totalsStream});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      color: FincoreColors.surfaceElevated,
      child: StreamBuilder<BudgetTotals>(
        stream: totalsStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            // `mainAxisSize: MainAxisSize.min` es OBLIGATORIO en ambos
            // `Column` de este builder: este widget vive directo en
            // `Scaffold.bottomNavigationBar` (constraints verticales
            // sueltas). El default `MainAxisSize.max` hace que el `Column`
            // intente ocupar TODO el alto disponible, lo que revienta el
            // layout del `Scaffold` completo (detectado porque corrompía el
            // hit-test del AppBar en los widget tests — un bug real de
            // layout, no solo un artefacto de test).
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: const Skeleton(
                    width: double.infinity,
                    height: 5,
                    radius: 3,
                  ),
                ),
                const SizedBox(height: 6),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'GASTOS PLANEADOS',
                      style: TextStyle(
                        color: FincoreColors.textSubtle,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Skeleton(width: 28, height: 10),
                  ],
                ),
                const SizedBox(height: 8),
                const Row(
                  children: [
                    Icon(
                      Icons.remove,
                      size: 24,
                      color: FincoreColors.textMuted,
                    ),
                    SizedBox(width: 8),
                    Expanded(child: SizedBox()),
                    Skeleton(width: 90, height: 26),
                  ],
                ),
              ],
            );
          }

          final totals = snapshot.data!;
          final income = totals.income;
          final expense = totals.expense;
          final balance = totals.balance;

          final progress = income > 0
              ? (expense / income).clamp(0.0, 1.0)
              : (expense > 0 ? 1.0 : 0.0);
          final percentLabel = '${(progress * 100).round()}%';

          final String label;
          final String amountText;
          final Color color;
          final IconData icon;
          if (balance > 0) {
            label = 'Sobra';
            amountText = formatAmount(balance);
            color = FincoreColors.positive;
            icon = Icons.trending_up;
          } else if (balance < 0) {
            label = 'Faltan';
            amountText = formatAmount(balance.abs());
            color = FincoreColors.negative;
            icon = Icons.trending_down;
          } else {
            label = 'En equilibrio';
            amountText = formatAmount(0);
            color = FincoreColors.textMuted;
            icon = Icons.remove;
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: FincoreColors.surface,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    balance >= 0
                        ? FincoreColors.positive
                        : FincoreColors.negative,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'GASTOS PLANEADOS',
                    style: TextStyle(
                      color: FincoreColors.textSubtle,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                    ),
                  ),
                  Text(
                    percentLabel,
                    style: const TextStyle(
                      color: FincoreColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(icon, size: 24, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: FincoreColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    amountText,
                    style: TextStyle(
                      color: color,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

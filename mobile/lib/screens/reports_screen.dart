import 'package:fincore/screens/reports/balance_at_date_tab.dart';
import 'package:fincore/screens/reports/budgets_tab.dart';
import 'package:fincore/screens/reports/cashflow_tab.dart';
import 'package:fincore/screens/reports/credit_cards_tab.dart';
import 'package:fincore/screens/reports/income_by_category_tab.dart';
import 'package:fincore/screens/reports/monthly_average_tab.dart';
import 'package:fincore/screens/reports/movements_calendar_tab.dart';
import 'package:fincore/screens/reports/spending_by_category_tab.dart';
import 'package:fincore/screens/reports/top_movements_tab.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:flutter/material.dart';

/// Pantalla de reportes con `TabBar`. Tabs vigentes:
/// 1. "Gasto por categoría" (sprint `flutter-reports-v1`).
/// 2. "Cashflow mensual" (sprint `flutter-reports-cashflow-v1`).
/// 3. "Top movimientos" (sprint `flutter-reports-top-movements-v1`).
/// 4. "Saldo a fecha" (sprint `flutter-reports-balance-at-date-v1`).
/// 5. "Promedio mensual" (sprint `flutter-reports-monthly-average-v1`).
/// 6. "Tarjetas" (sprint `flutter-reports-credit-cards-v1`).
/// 7. "Presupuestos" (sprint `flutter-budgets-v1`).
/// 8. "Ingreso por categoría" (sprint `flutter-reports-income-by-category-v1`).
///
/// `initialIndex` default = 0 para mantener hábito y para no romper tests
/// del primer sprint.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 9,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Reportes'),
          bottom: const TabBar(
            indicatorColor: FincoreColors.accent,
            labelColor: FincoreColors.textPrimary,
            unselectedLabelColor: FincoreColors.textMuted,
            isScrollable: true,
            tabs: [
              Tab(text: 'Gasto por categoría'),
              Tab(text: 'Cashflow mensual'),
              Tab(text: 'Top movimientos'),
              Tab(text: 'Saldo a fecha'),
              Tab(text: 'Promedio mensual'),
              Tab(text: 'Tarjetas'),
              Tab(text: 'Presupuestos'),
              Tab(text: 'Ingreso por categoría'),
              Tab(text: 'Calendario'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            SpendingByCategoryTab(),
            CashflowTab(),
            TopMovementsTab(),
            BalanceAtDateTab(),
            MonthlyAverageTab(),
            CreditCardsTab(),
            BudgetsTab(),
            IncomeByCategoryTab(),
            MovementsCalendarTab(),
          ],
        ),
      ),
    );
  }
}

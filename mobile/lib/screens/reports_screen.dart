import 'package:fincore/screens/reports/cashflow_tab.dart';
import 'package:fincore/screens/reports/spending_by_category_tab.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:flutter/material.dart';

/// Pantalla de reportes con `TabBar`. Tabs vigentes:
/// 1. "Gasto por categoría" (sprint `flutter-reports-v1`).
/// 2. "Cashflow mensual" (sprint `flutter-reports-cashflow-v1`).
///
/// `initialIndex` default = 0 para mantener hábito y para no romper tests
/// del primer sprint.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Reportes'),
          bottom: const TabBar(
            indicatorColor: FincoreColors.accent,
            labelColor: FincoreColors.textPrimary,
            unselectedLabelColor: FincoreColors.textMuted,
            tabs: [
              Tab(text: 'Gasto por categoría'),
              Tab(text: 'Cashflow mensual'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            SpendingByCategoryTab(),
            CashflowTab(),
          ],
        ),
      ),
    );
  }
}

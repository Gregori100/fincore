import 'package:fincore/screens/reports/spending_by_category_tab.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:flutter/material.dart';

/// Pantalla de reportes con `TabBar` extensible. V1 incluye una sola tab:
/// "Gasto por categoría". El shell queda armado para que futuros sprints
/// agreguen tabs adicionales (cashflow mensual, saldo a fecha, top
/// movimientos) sin tocar la navegación.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Reportes'),
          bottom: const TabBar(
            indicatorColor: FincoreColors.accent,
            labelColor: FincoreColors.textPrimary,
            unselectedLabelColor: FincoreColors.textMuted,
            tabs: [
              Tab(text: 'Gasto por categoría'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            SpendingByCategoryTab(),
          ],
        ),
      ),
    );
  }
}

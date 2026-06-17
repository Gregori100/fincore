import 'package:fincore/app_dependencies.dart';
import 'package:fincore/constants/account_types.dart';
import 'package:fincore/constants/kinds.dart';
import 'package:fincore/models/account.dart';
import 'package:fincore/models/domain_error.dart';
import 'package:fincore/models/finance_state.dart';
import 'package:fincore/models/journal_entry.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/widgets/amount_formatter.dart';
import 'package:fincore/widgets/base_card.dart';
import 'package:fincore/widgets/category_badge.dart';
import 'package:fincore/widgets/error_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Future<FinanceState>? _stateFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stateFuture ??= _load();
  }

  Future<FinanceState> _load() {
    final deps = AppDependencies.of(context);
    return deps.stateApi.fetch();
  }

  Future<void> _refresh() async {
    final newFuture = _load();
    setState(() => _stateFuture = newFuture);
    try {
      await newFuture;
    } on DomainError catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FinCore'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Configuración',
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/entries/new'),
        icon: const Icon(Icons.add),
        label: const Text('Movimiento'),
        backgroundColor: FincoreColors.accent,
        foregroundColor: FincoreColors.canvas,
      ),
      body: FutureBuilder<FinanceState>(
        future: _stateFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _ErrorState(error: snap.error!, onRetry: _refresh);
          }
          final state = snap.data!;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                _TotalsRow(bo: state.bo, de: state.de, cr: state.cr),
                const SizedBox(height: 24),
                SectionTitle(
                  'Mis cuentas',
                  trailing: TextButton.icon(
                    onPressed: () => context.go('/accounts'),
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text('Ver todas'),
                  ),
                ),
                const SizedBox(height: 8),
                ..._buildAccounts(state.accounts),
                const SizedBox(height: 24),
                SectionTitle(
                  'Últimos movimientos',
                  trailing: TextButton.icon(
                    onPressed: () => context.go('/entries'),
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text('Ver todos'),
                  ),
                ),
                const SizedBox(height: 8),
                ..._buildEntries(state.recentEntries),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildAccounts(List<Account> accounts) {
    final visible = accounts.where((a) => !a.isArchived).toList();
    if (visible.isEmpty) {
      return [
        const BaseCard(
          child: Text(
            'Aún no tenés cuentas. Creá una desde "Cuentas".',
            style: TextStyle(color: FincoreColors.textMuted),
          ),
        ),
      ];
    }
    final widgets = <Widget>[];
    for (var i = 0; i < visible.length; i++) {
      if (i > 0) widgets.add(const SizedBox(height: 8));
      widgets.add(_AccountTile(account: visible[i]));
    }
    return widgets;
  }

  List<Widget> _buildEntries(List<JournalEntry> entries) {
    if (entries.isEmpty) {
      return [
        const BaseCard(
          child: Text(
            'Aún no hay movimientos. Tocá "Movimiento" para registrar uno.',
            style: TextStyle(color: FincoreColors.textMuted),
          ),
        ),
      ];
    }
    final widgets = <Widget>[];
    for (var i = 0; i < entries.length; i++) {
      if (i > 0) widgets.add(const SizedBox(height: 8));
      widgets.add(_EntryTile(entry: entries[i]));
    }
    return widgets;
  }
}

class _TotalsRow extends StatelessWidget {
  final num bo;
  final num de;
  final num cr;
  const _TotalsRow({required this.bo, required this.de, required this.cr});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _TotalCard(label: 'BO', value: bo, color: FincoreColors.positive, hint: 'Bolsa + Débito')),
        const SizedBox(width: 8),
        Expanded(child: _TotalCard(label: 'DE', value: de, color: FincoreColors.negative, hint: 'Deuda Crédito')),
        const SizedBox(width: 8),
        Expanded(child: _TotalCard(label: 'CR', value: cr, color: FincoreColors.accent, hint: 'Crédito Disponible')),
      ],
    );
  }
}

class _TotalCard extends StatelessWidget {
  final String label;
  final num value;
  final Color color;
  final String hint;

  const _TotalCard({
    required this.label,
    required this.value,
    required this.color,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.5),
          ),
          const SizedBox(height: 6),
          Text(
            formatAmount(value),
            style: const TextStyle(
              color: FincoreColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            hint,
            style: const TextStyle(color: FincoreColors.textSubtle, fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  final Account account;
  const _AccountTile({required this.account});

  @override
  Widget build(BuildContext context) {
    final balance = account.balance ?? 0;
    final isCredit = account.isCredit;
    final balanceColor = isCredit
        ? (balance > 0 ? FincoreColors.negative : FincoreColors.textPrimary)
        : (balance < 0 ? FincoreColors.negative : FincoreColors.textPrimary);

    return BaseCard(
      onTap: () => context.go('/accounts/${account.id}/edit'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _typeColor(account.type).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_typeIcon(account.type), size: 18, color: _typeColor(account.type)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(account.name,
                    style: const TextStyle(color: FincoreColors.textPrimary, fontWeight: FontWeight.w600)),
                Text(
                  account.type.label + (account.isProtected ? ' · protegida' : ''),
                  style: const TextStyle(color: FincoreColors.textSubtle, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            formatAmount(balance),
            style: TextStyle(color: balanceColor, fontWeight: FontWeight.w700),
          ),
        ],
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

class _EntryTile extends StatelessWidget {
  final JournalEntry entry;
  const _EntryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final amount = entry.amount;
    final color = _amountColor(entry.kind);
    final signedAmount = _signedAmount(entry.kind, amount);
    final dateStr = DateFormat('d MMM', 'es_MX').format(entry.occurredAt);

    return BaseCard(
      onTap: () => context.go('/entries/${entry.id}/edit'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_kindIcon(entry.kind), size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.description?.isNotEmpty == true
                      ? entry.description!
                      : entry.kind.label,
                  style: const TextStyle(color: FincoreColors.textPrimary, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '$dateStr · ${entry.kind.label}',
                      style: const TextStyle(color: FincoreColors.textSubtle, fontSize: 11),
                    ),
                    if (entry.category != null)
                      CategoryBadge(category: entry.category, compact: true),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            signedAmount,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Color _amountColor(JournalKind k) {
    switch (k) {
      case JournalKind.income:
        return FincoreColors.positive;
      case JournalKind.expense:
      case JournalKind.creditExpense:
        return FincoreColors.negative;
      case JournalKind.debtPayment:
      case JournalKind.transfer:
        return FincoreColors.accent;
    }
  }

  IconData _kindIcon(JournalKind k) {
    switch (k) {
      case JournalKind.income:
        return Icons.arrow_downward;
      case JournalKind.expense:
        return Icons.arrow_upward;
      case JournalKind.creditExpense:
        return Icons.credit_card_outlined;
      case JournalKind.debtPayment:
        return Icons.payments_outlined;
      case JournalKind.transfer:
        return Icons.swap_horiz;
    }
  }

  String _signedAmount(JournalKind k, num amount) {
    switch (k) {
      case JournalKind.income:
        return formatAmount(amount, showSign: true);
      case JournalKind.expense:
      case JournalKind.creditExpense:
        return '-${formatAmount(amount)}';
      case JournalKind.debtPayment:
      case JournalKind.transfer:
        return formatAmount(amount);
    }
  }
}

class _ErrorState extends StatelessWidget {
  final Object error;
  final Future<void> Function() onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final msg = error is DomainError
        ? (error as DomainError).message
        : 'No se pudo conectar al servidor.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: FincoreColors.negative),
            const SizedBox(height: 12),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: const TextStyle(color: FincoreColors.textMuted),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => onRetry(), child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}

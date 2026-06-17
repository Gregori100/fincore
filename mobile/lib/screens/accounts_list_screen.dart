import 'package:fincore/app_dependencies.dart';
import 'package:fincore/constants/account_types.dart';
import 'package:fincore/models/account.dart';
import 'package:fincore/models/domain_error.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/widgets/amount_formatter.dart';
import 'package:fincore/widgets/base_card.dart';
import 'package:fincore/widgets/error_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AccountsListScreen extends StatefulWidget {
  const AccountsListScreen({super.key});

  @override
  State<AccountsListScreen> createState() => _AccountsListScreenState();
}

class _AccountsListScreenState extends State<AccountsListScreen> {
  Future<List<Account>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<List<Account>> _load() {
    final deps = AppDependencies.of(context);
    return deps.accountsApi.list();
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    try {
      await next;
    } on DomainError catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuentas'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/accounts/new'),
        backgroundColor: FincoreColors.accent,
        foregroundColor: FincoreColors.canvas,
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<Account>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _ErrorState(error: snap.error!, onRetry: _refresh);
          }
          final accounts = snap.data!;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: accounts.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 80),
                      Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Aún no hay cuentas.',
                            style: TextStyle(color: FincoreColors.textMuted),
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: accounts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _AccountRow(account: accounts[i]),
                  ),
          );
        },
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  final Account account;
  const _AccountRow({required this.account});

  @override
  Widget build(BuildContext context) {
    final balance = account.balance ?? 0;
    final balanceColor = account.isCredit
        ? (balance > 0 ? FincoreColors.negative : FincoreColors.textPrimary)
        : (balance < 0 ? FincoreColors.negative : FincoreColors.textPrimary);

    return BaseCard(
      onTap: () => context.go('/accounts/${account.id}/edit'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _typeColor(account.type).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_typeIcon(account.type), color: _typeColor(account.type)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(account.name,
                          style: const TextStyle(
                              color: FincoreColors.textPrimary, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (account.isProtected) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.lock_outline, size: 14, color: FincoreColors.textSubtle),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  account.type.label +
                      (account.description?.isNotEmpty == true ? ' · ${account.description}' : ''),
                  style: const TextStyle(color: FincoreColors.textSubtle, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
                if (account.isCredit && account.creditLimit != null) ...[
                  const SizedBox(height: 4),
                  _CreditUsageBar(balance: balance, limit: account.creditLimit!),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatAmount(balance),
                style: TextStyle(color: balanceColor, fontWeight: FontWeight.w700),
              ),
              if (account.isCredit && account.creditLimit != null)
                Text(
                  'de ${formatAmount(account.creditLimit!)}',
                  style: const TextStyle(color: FincoreColors.textSubtle, fontSize: 11),
                ),
            ],
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

class _CreditUsageBar extends StatelessWidget {
  final num balance;
  final num limit;
  const _CreditUsageBar({required this.balance, required this.limit});

  @override
  Widget build(BuildContext context) {
    final ratio = (limit == 0) ? 0.0 : (balance / limit).clamp(0.0, 1.0).toDouble();
    final color = ratio > 0.9
        ? FincoreColors.negative
        : ratio > 0.7
            ? FincoreColors.warning
            : FincoreColors.accent;
    return SizedBox(
      width: 120,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: ratio,
          minHeight: 4,
          backgroundColor: FincoreColors.surfaceElevated,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ),
    );
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
        : 'No se pudo cargar las cuentas.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: FincoreColors.negative),
            const SizedBox(height: 12),
            Text(msg,
                textAlign: TextAlign.center,
                style: const TextStyle(color: FincoreColors.textMuted)),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => onRetry(), child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}

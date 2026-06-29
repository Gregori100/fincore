import 'package:fincore/app_dependencies.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/widgets/amount_formatter.dart';
import 'package:fincore/widgets/base_card.dart';
import 'package:fincore/widgets/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AccountsListScreen extends StatefulWidget {
  const AccountsListScreen({super.key});

  @override
  State<AccountsListScreen> createState() => _AccountsListScreenState();
}

class _AccountsListScreenState extends State<AccountsListScreen> {
  Stream<List<Account>>? _stream;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stream ??= AppDependencies.of(context).accountsDao.watchActive();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuentas'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/accounts/new'),
        backgroundColor: FincoreColors.accent,
        foregroundColor: FincoreColors.canvas,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Account>>(
        stream: _stream,
        builder: (context, snap) {
          if (!snap.hasData) {
            return ListView.separated(
              // Bottom 96 para que el FAB no tape la última fila.
              // Convención del repo (dashboard, settings, tabs de
              // reports usan el mismo valor).
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: 4,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, __) => const SkeletonCard(),
            );
          }
          final accounts = snap.data!;
          if (accounts.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Aún no hay cuentas.',
                    style: TextStyle(color: FincoreColors.textMuted)),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: accounts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _AccountRow(account: accounts[i]),
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
    final deps = AppDependencies.of(context);
    return BaseCard(
      onTap: account.isProtected
          ? null
          : () => context.push('/accounts/${account.id}/edit'),
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
                      child: Text(
                        account.name,
                        style: const TextStyle(
                            color: FincoreColors.textPrimary,
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (account.isProtected) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.lock_outline,
                          size: 14, color: FincoreColors.textSubtle),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _typeLabel(account.type) +
                      (account.description?.isNotEmpty == true
                          ? ' · ${account.description}'
                          : ''),
                  style: const TextStyle(color: FincoreColors.textSubtle, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StreamBuilder<double>(
            stream: deps.stateService.watchAccountBalance(account.id, account.type),
            builder: (context, snap) {
              if (!snap.hasData) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Skeleton(width: 70, height: 16),
                    if (account.type == 'credit' && account.creditLimit != null) ...[
                      const SizedBox(height: 4),
                      const Skeleton(width: 50, height: 11),
                    ],
                  ],
                );
              }
              final balance = snap.data!;
              final color = account.type == 'credit'
                  ? (balance > 0 ? FincoreColors.negative : FincoreColors.textPrimary)
                  : (balance < 0 ? FincoreColors.negative : FincoreColors.textPrimary);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatAmount(balance),
                    style: TextStyle(color: color, fontWeight: FontWeight.w700),
                  ),
                  if (account.type == 'credit' && account.creditLimit != null)
                    Text(
                      'de ${formatAmount(account.creditLimit!)}',
                      style: const TextStyle(
                          color: FincoreColors.textSubtle, fontSize: 11),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Color _typeColor(String t) => switch (t) {
        'cash' => FincoreColors.positive,
        'debit' => FincoreColors.accent,
        'credit' => FincoreColors.warning,
        _ => FincoreColors.textMuted,
      };
  IconData _typeIcon(String t) => switch (t) {
        'cash' => Icons.account_balance_wallet_outlined,
        'debit' => Icons.account_balance_outlined,
        'credit' => Icons.credit_card_outlined,
        _ => Icons.help_outline,
      };
  String _typeLabel(String t) => switch (t) {
        'cash' => 'Bolsa',
        'debit' => 'Débito',
        'credit' => 'Crédito',
        _ => t,
      };
}

import 'package:fincore/app_dependencies.dart';
import 'package:fincore/constants/kinds.dart';
import 'package:fincore/data/daos/entries_dao.dart';
import 'package:fincore/data/database.dart' as db;
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/widgets/amount_formatter.dart';
import 'package:fincore/widgets/base_card.dart';
import 'package:fincore/widgets/category_badge.dart' as cb;
import 'package:fincore/widgets/skeleton.dart';
import 'package:fincore/models/category.dart' as model;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Stream<double>? _boStream;
  Stream<double>? _deStream;
  Stream<double>? _crStream;
  Stream<List<db.Account>>? _accountsStream;
  Stream<List<EntryWithRelations>>? _recentEntriesStream;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_boStream != null) return;
    final deps = AppDependencies.of(context);
    _boStream = deps.stateService.watchBo();
    _deStream = deps.stateService.watchDe();
    _crStream = deps.stateService.watchCr();
    _accountsStream = deps.accountsDao.watchActive();
    _recentEntriesStream = deps.entriesDao.watchPage(limit: 10);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: RichText(
          text: const TextSpan(
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
            children: [
              TextSpan(text: 'Fin', style: TextStyle(color: FincoreColors.accent)),
              TextSpan(text: 'Core', style: TextStyle(color: FincoreColors.textPrimary)),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.label_outline),
            tooltip: 'Categorías',
            onPressed: () => context.push('/categories'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Configuración',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/entries/new'),
        icon: const Icon(Icons.add),
        label: const Text('Movimiento'),
        backgroundColor: FincoreColors.accent,
        foregroundColor: FincoreColors.canvas,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Row(
            children: [
              Expanded(
                child: _TotalCard(
                  label: 'BO',
                  stream: _boStream!,
                  color: FincoreColors.positive,
                  hint: 'Bolsa + Débito',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TotalCard(
                  label: 'DE',
                  stream: _deStream!,
                  color: FincoreColors.negative,
                  hint: 'Deuda Crédito',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TotalCard(
                  label: 'CR',
                  stream: _crStream!,
                  color: FincoreColors.accent,
                  hint: 'Crédito disponible',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SectionTitle(
            'Mis cuentas',
            trailing: TextButton.icon(
              onPressed: () => context.push('/accounts'),
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('Ver todas'),
            ),
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<db.Account>>(
            stream: _accountsStream,
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Column(
                  children: [
                    SkeletonCard(),
                    SizedBox(height: 8),
                    SkeletonCard(),
                    SizedBox(height: 8),
                    SkeletonCard(),
                  ],
                );
              }
              final accounts = snap.data!;
              if (accounts.isEmpty) {
                return const BaseCard(
                  child: Text(
                    'Aún no tenés cuentas. Creá una desde "Cuentas".',
                    style: TextStyle(color: FincoreColors.textMuted),
                  ),
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < accounts.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _AccountTile(account: accounts[i]),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          SectionTitle(
            'Últimos movimientos',
            trailing: TextButton.icon(
              onPressed: () => context.push('/entries'),
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('Ver todos'),
            ),
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<EntryWithRelations>>(
            stream: _recentEntriesStream,
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Column(
                  children: [
                    SkeletonCard(),
                    SizedBox(height: 8),
                    SkeletonCard(),
                    SizedBox(height: 8),
                    SkeletonCard(),
                  ],
                );
              }
              final entries = snap.data!;
              if (entries.isEmpty) {
                return const BaseCard(
                  child: Text(
                    'Aún no hay movimientos. Tocá "Movimiento" para registrar uno.',
                    style: TextStyle(color: FincoreColors.textMuted),
                  ),
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < entries.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _EntryTile(item: entries[i]),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  final String label;
  final Stream<double> stream;
  final Color color;
  final String hint;

  const _TotalCard({
    required this.label,
    required this.stream,
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
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          StreamBuilder<double>(
            stream: stream,
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 2),
                  child: Skeleton(width: 80, height: 16),
                );
              }
              return Text(
                formatAmount(snap.data!),
                style: const TextStyle(
                  color: FincoreColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              );
            },
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
  final db.Account account;
  const _AccountTile({required this.account});

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      onTap: account.isProtected
          ? null
          : () => context.push('/accounts/${account.id}/edit'),
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
                    style: const TextStyle(
                        color: FincoreColors.textPrimary, fontWeight: FontWeight.w600)),
                Text(
                  _typeLabel(account.type),
                  style: const TextStyle(color: FincoreColors.textSubtle, fontSize: 12),
                ),
              ],
            ),
          ),
          _BalanceLabel(accountId: account.id, accountType: account.type),
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

class _BalanceLabel extends StatelessWidget {
  final String accountId;
  final String accountType;
  const _BalanceLabel({required this.accountId, required this.accountType});

  @override
  Widget build(BuildContext context) {
    final deps = AppDependencies.of(context);
    return StreamBuilder<double>(
      stream: deps.stateService.watchAccountBalance(accountId, accountType),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Skeleton(width: 60, height: 14);
        }
        final balance = snap.data!;
        final isCredit = accountType == 'credit';
        final color = isCredit
            ? (balance > 0 ? FincoreColors.negative : FincoreColors.textPrimary)
            : (balance < 0 ? FincoreColors.negative : FincoreColors.textPrimary);
        return Text(
          formatAmount(balance),
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        );
      },
    );
  }
}

class _EntryTile extends StatelessWidget {
  final EntryWithRelations item;
  const _EntryTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final entry = item.entry;
    final kind = parseJournalKind(entry.kind);
    final color = _amountColor(kind);
    final signedAmount = _signedAmount(kind, entry.amount);
    final dateStr = DateFormat('d MMM', 'es_MX').format(entry.occurredAt);

    return BaseCard(
      onTap: () => context.push('/entries/${entry.id}/edit'),
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
            child: Icon(_kindIcon(kind), size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.description?.isNotEmpty == true ? entry.description! : kind.label,
                  style: const TextStyle(
                      color: FincoreColors.textPrimary, fontWeight: FontWeight.w500),
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
                      '$dateStr · ${kind.label}',
                      style: const TextStyle(color: FincoreColors.textSubtle, fontSize: 11),
                    ),
                    if (item.category != null)
                      cb.CategoryBadge(category: _toModelCategory(item.category!), compact: true),
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

  /// Convierte el row de drift `Category` al modelo legacy `model.Category` que
  /// `CategoryBadge` consume. Compatibilidad temporal hasta que CategoryBadge se
  /// adapte directamente al row.
  model.Category _toModelCategory(db.Category c) {
    return model.Category(
      id: c.id,
      name: c.name,
      appliesTo: c.appliesTo,
      colorSlug: c.colorSlug,
      iconSlug: c.iconSlug,
      monthlyLimit: c.monthlyLimit,
      deletedAt: c.deletedAt,
    );
  }

  Color _amountColor(JournalKind k) => switch (k) {
        JournalKind.income => FincoreColors.positive,
        JournalKind.expense || JournalKind.creditExpense => FincoreColors.negative,
        JournalKind.debtPayment || JournalKind.transfer => FincoreColors.accent,
      };

  IconData _kindIcon(JournalKind k) => switch (k) {
        JournalKind.income => Icons.arrow_downward,
        JournalKind.expense => Icons.arrow_upward,
        JournalKind.creditExpense => Icons.credit_card_outlined,
        JournalKind.debtPayment => Icons.payments_outlined,
        JournalKind.transfer => Icons.swap_horiz,
      };

  String _signedAmount(JournalKind k, double amount) => switch (k) {
        JournalKind.income => formatAmount(amount, showSign: true),
        JournalKind.expense || JournalKind.creditExpense => '-${formatAmount(amount)}',
        JournalKind.debtPayment || JournalKind.transfer => formatAmount(amount),
      };
}

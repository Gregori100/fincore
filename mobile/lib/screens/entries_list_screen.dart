import 'package:fincore/app_dependencies.dart';
import 'package:fincore/constants/kinds.dart';
import 'package:fincore/data/daos/entries_dao.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/widgets/amount_formatter.dart';
import 'package:fincore/widgets/base_card.dart';
import 'package:fincore/widgets/category_badge.dart' as cb;
import 'package:fincore/widgets/skeleton.dart';
import 'package:fincore/models/category.dart' as model;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class EntriesListScreen extends StatefulWidget {
  const EntriesListScreen({super.key});

  @override
  State<EntriesListScreen> createState() => _EntriesListScreenState();
}

class _EntriesListScreenState extends State<EntriesListScreen> {
  Stream<List<EntryWithRelations>>? _stream;
  Stream<List<Account>>? _accountsStream;
  String? _kindFilter;
  String? _accountFilter;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_stream != null) return;
    final deps = AppDependencies.of(context);
    _stream = deps.entriesDao.watchPage(limit: 200);
    _accountsStream = deps.accountsDao.watchActive();
  }

  void _rebuildStream() {
    final deps = AppDependencies.of(context);
    setState(() {
      _stream = deps.entriesDao.watchPage(
        kind: _kindFilter,
        accountId: _accountFilter,
        limit: 200,
      );
    });
  }

  void _openFilters() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: FincoreColors.canvas,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return StreamBuilder<List<Account>>(
          stream: _accountsStream,
          builder: (context, snap) {
            final accounts = snap.data ?? const <Account>[];
            return _FiltersSheet(
              kind: _kindFilter,
              accountId: _accountFilter,
              accounts: accounts,
              onApply: (kind, accountId) {
                _kindFilter = kind;
                _accountFilter = accountId;
                Navigator.of(context).pop();
                _rebuildStream();
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasFilters = _kindFilter != null || _accountFilter != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Movimientos'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          IconButton(
            tooltip: hasFilters ? 'Filtros (activos)' : 'Filtros',
            icon: Stack(
              children: [
                const Icon(Icons.filter_list),
                if (hasFilters)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: FincoreColors.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: _openFilters,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/entries/new'),
        tooltip: 'Nuevo movimiento',
        backgroundColor: FincoreColors.accent,
        foregroundColor: FincoreColors.canvas,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<EntryWithRelations>>(
        stream: _stream,
        builder: (context, snap) {
          if (!snap.hasData) {
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
              itemCount: 5,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, __) => const SkeletonCard(),
            );
          }
          final entries = snap.data!;
          if (entries.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No hay movimientos.',
                    style: TextStyle(color: FincoreColors.textMuted)),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _Row(item: entries[i]),
          );
        },
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final EntryWithRelations item;
  const _Row({required this.item});

  @override
  Widget build(BuildContext context) {
    final entry = item.entry;
    final kind = parseJournalKind(entry.kind);
    final color = switch (kind) {
      JournalKind.income => FincoreColors.positive,
      JournalKind.expense || JournalKind.creditExpense => FincoreColors.negative,
      JournalKind.debtPayment || JournalKind.transfer => FincoreColors.accent,
    };
    final dateStr = DateFormat('d MMM y', 'es_MX').format(entry.occurredAt);

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
                    Text('$dateStr · ${kind.label}',
                        style: const TextStyle(
                            color: FincoreColors.textSubtle, fontSize: 11)),
                    if (item.category != null)
                      cb.CategoryBadge(
                        category: model.Category(
                          id: item.category!.id,
                          name: item.category!.name,
                          appliesTo: item.category!.appliesTo,
                          colorSlug: item.category!.colorSlug,
                          iconSlug: item.category!.iconSlug,
                          monthlyLimit: item.category!.monthlyLimit,
                          deletedAt: item.category!.deletedAt,
                        ),
                        compact: true,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(_signed(kind, entry.amount),
              style: TextStyle(color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  IconData _kindIcon(JournalKind k) => switch (k) {
        JournalKind.income => Icons.arrow_downward,
        JournalKind.expense => Icons.arrow_upward,
        JournalKind.creditExpense => Icons.credit_card_outlined,
        JournalKind.debtPayment => Icons.payments_outlined,
        JournalKind.transfer => Icons.swap_horiz,
      };

  String _signed(JournalKind k, double amount) => switch (k) {
        JournalKind.income => formatAmount(amount, showSign: true),
        JournalKind.expense || JournalKind.creditExpense => '-${formatAmount(amount)}',
        JournalKind.debtPayment || JournalKind.transfer => formatAmount(amount),
      };
}

class _FiltersSheet extends StatefulWidget {
  final String? kind;
  final String? accountId;
  final List<Account> accounts;
  final void Function(String? kind, String? accountId) onApply;

  const _FiltersSheet({
    required this.kind,
    required this.accountId,
    required this.accounts,
    required this.onApply,
  });

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late String? _kind = widget.kind;
  late String? _accountId = widget.accountId;

  @override
  Widget build(BuildContext context) {
    final hasFilters = _kind != null || _accountId != null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Filtros',
                        style: TextStyle(
                            color: FincoreColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w600)),
                  ),
                  // Reserva siempre el alto del botón para que el header
                  // no cambie de tamaño al aparecer/desaparecer "Limpiar".
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: hasFilters ? 1 : 0,
                    child: IgnorePointer(
                      ignoring: !hasFilters,
                      child: TextButton.icon(
                        onPressed: () => setState(() {
                          _kind = null;
                          _accountId = null;
                        }),
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Limpiar'),
                        style: TextButton.styleFrom(
                          foregroundColor: FincoreColors.textMuted,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Tipo', style: TextStyle(color: FincoreColors.textMuted, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Chip(label: 'Todos', selected: _kind == null, onTap: () => setState(() => _kind = null)),
                  ...JournalKind.values.map((k) => _Chip(
                        label: k.label,
                        selected: _kind == k.apiValue,
                        onTap: () => setState(() => _kind = k.apiValue),
                      )),
                ],
              ),
              const SizedBox(height: 28),
              DropdownButtonFormField<String?>(
                value: _accountId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Cuenta'),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('Todas')),
                  ...widget.accounts.map((a) => DropdownMenuItem<String?>(
                        value: a.id,
                        child: Text(a.name),
                      )),
                ],
                onChanged: (v) => setState(() => _accountId = v),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => widget.onApply(_kind, _accountId),
                      child: const Text('Aplicar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? FincoreColors.accent.withValues(alpha: 0.2) : FincoreColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? FincoreColors.accent : FincoreColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
              color: selected ? FincoreColors.accent : FincoreColors.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

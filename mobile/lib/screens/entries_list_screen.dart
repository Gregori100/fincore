import 'package:fincore/api/entries_api.dart';
import 'package:fincore/app_dependencies.dart';
import 'package:fincore/constants/kinds.dart';
import 'package:fincore/models/account.dart';
import 'package:fincore/models/domain_error.dart';
import 'package:fincore/models/journal_entry.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/widgets/amount_formatter.dart';
import 'package:fincore/widgets/base_card.dart';
import 'package:fincore/widgets/category_badge.dart';
import 'package:fincore/widgets/error_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class EntriesListScreen extends StatefulWidget {
  const EntriesListScreen({super.key});

  @override
  State<EntriesListScreen> createState() => _EntriesListScreenState();
}

class _EntriesListScreenState extends State<EntriesListScreen> {
  final ScrollController _scroll = ScrollController();
  final List<JournalEntry> _entries = [];
  List<Account> _accounts = const [];

  bool _loading = false;
  bool _hasNext = true;
  int _page = 1;

  // Filtros activos.
  JournalKind? _kindFilter;
  String? _accountIdFilter;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entries.isEmpty && _hasNext) {
      _loadAccounts();
      _loadNext();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    final deps = AppDependencies.of(context);
    try {
      final list = await deps.accountsApi.list();
      if (mounted) setState(() => _accounts = list);
    } on DomainError catch (_) {
      // No bloqueante para mostrar entries; silenciamos.
    }
  }

  Future<void> _loadNext() async {
    if (_loading || !_hasNext) return;
    final deps = AppDependencies.of(context);
    setState(() => _loading = true);
    try {
      final filter = EntriesFilter(
        kind: _kindFilter,
        accountId: _accountIdFilter,
        page: _page,
      );
      final result = await deps.entriesApi.list(filter);
      setState(() {
        _entries.addAll(result.data);
        _hasNext = result.hasNext;
        _page = result.currentPage + 1;
      });
    } on DomainError catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _entries.clear();
      _hasNext = true;
      _page = 1;
    });
    await _loadNext();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      _loadNext();
    }
  }

  void _openFilters() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: FincoreColors.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _FiltersSheet(
        kind: _kindFilter,
        accountId: _accountIdFilter,
        accounts: _accounts,
        onChanged: (kind, accountId) {
          setState(() {
            _kindFilter = kind;
            _accountIdFilter = accountId;
          });
          _refresh();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasFilters = _kindFilter != null || _accountIdFilter != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Movimientos'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
        actions: [
          IconButton(
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
        onPressed: () => context.go('/entries/new'),
        backgroundColor: FincoreColors.accent,
        foregroundColor: FincoreColors.canvas,
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _entries.isEmpty && !_loading
            ? ListView(
                children: const [
                  SizedBox(height: 80),
                  Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No hay movimientos con esos filtros.',
                        style: TextStyle(color: FincoreColors.textMuted),
                      ),
                    ),
                  ),
                ],
              )
            : ListView.separated(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                itemCount: _entries.length + (_hasNext ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  if (i >= _entries.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return _EntryRow(entry: _entries[i]);
                },
              ),
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  final JournalEntry entry;
  const _EntryRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final color = _amountColor(entry.kind);
    final dateStr = DateFormat('d MMM y', 'es_MX').format(entry.occurredAt);
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
            child: Icon(_kindIcon(entry.kind), color: color, size: 16),
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
                    Text('$dateStr · ${entry.kind.label}',
                        style: const TextStyle(color: FincoreColors.textSubtle, fontSize: 11)),
                    if (entry.category != null)
                      CategoryBadge(category: entry.category, compact: true),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(_signedAmount(entry.kind, entry.amount),
              style: TextStyle(color: color, fontWeight: FontWeight.w700)),
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

class _FiltersSheet extends StatefulWidget {
  final JournalKind? kind;
  final String? accountId;
  final List<Account> accounts;
  final void Function(JournalKind? kind, String? accountId) onChanged;

  const _FiltersSheet({
    required this.kind,
    required this.accountId,
    required this.accounts,
    required this.onChanged,
  });

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late JournalKind? _kind = widget.kind;
  late String? _accountId = widget.accountId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Filtros',
              style: TextStyle(
                color: FincoreColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(height: 16),
          const Text('Tipo', style: TextStyle(color: FincoreColors.textMuted, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterChip(label: 'Todos', selected: _kind == null, onTap: () => setState(() => _kind = null)),
              ...JournalKind.values.map((k) => _FilterChip(
                    label: k.label,
                    selected: _kind == k,
                    onTap: () => setState(() => _kind = k),
                  )),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Cuenta', style: TextStyle(color: FincoreColors.textMuted, fontSize: 13)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            value: _accountId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Todas las cuentas'),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('Todas')),
              ...widget.accounts.where((a) => !a.isArchived).map((a) {
                return DropdownMenuItem<String?>(value: a.id, child: Text(a.name));
              }),
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
                  onPressed: () {
                    widget.onChanged(_kind, _accountId);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Aplicar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

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
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

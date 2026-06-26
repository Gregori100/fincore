import 'package:fincore/app_dependencies.dart';
import 'package:fincore/constants/date_range_presets.dart';
import 'package:fincore/constants/kinds.dart';
import 'package:fincore/data/reports.dart';
import 'package:fincore/models/category.dart' as model;
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/widgets/amount_formatter.dart';
import 'package:fincore/widgets/base_card.dart';
import 'package:fincore/widgets/category_badge.dart' as cb;
import 'package:fincore/widgets/date_field_outlined.dart';
import 'package:fincore/widgets/error_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Tab "Top movimientos" del reporte. Sprint
/// `flutter-reports-top-movements-v1`.
///
/// Lista los hasta N movimientos más grandes del rango ordenados por monto
/// descendente (RN-T06). Header con chips de presets de fecha + chips de
/// kinds multi-select (decisión P-001). Tap en row navega a
/// `/entries/:id/edit` (RF-008).
class TopMovementsTab extends StatefulWidget {
  const TopMovementsTab({super.key});

  @override
  State<TopMovementsTab> createState() => _TopMovementsTabState();
}

/// N por default — sprint `flutter-reports-top-movements-v1` (RN-T08).
const int _kTopLimit = 20;

class _TopMovementsTabState extends State<TopMovementsTab> {
  late DateTime _from;
  late DateTime _to;
  DateRangePreset _preset = DateRangePreset.thisMonth;
  late Set<String> _selectedKinds;
  Stream<TopMovementsReport>? _reportStream;

  @override
  void initState() {
    super.initState();
    final r = dateRangeForPreset(DateRangePreset.thisMonth, DateTime.now());
    _from = r.$1;
    _to = r.$2;
    // Default: los 5 kinds seleccionados (auditoría completa).
    _selectedKinds = {
      for (final k in JournalKind.values) k.apiValue,
    };
  }

  void _selectPreset(DateRangePreset preset) {
    final r = dateRangeForPreset(
      preset,
      DateTime.now(),
      currentFrom: _from,
      currentTo: _to,
    );
    setState(() {
      _preset = preset;
      _from = r.$1;
      _to = r.$2;
      _reportStream = _buildStream();
    });
  }

  void _toggleKind(String kindApiValue) {
    setState(() {
      if (_selectedKinds.contains(kindApiValue)) {
        _selectedKinds.remove(kindApiValue);
      } else {
        _selectedKinds.add(kindApiValue);
      }
      _reportStream = _buildStream();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reportStream ??= _buildStream();
  }

  Stream<TopMovementsReport> _buildStream() {
    final deps = AppDependencies.of(context);
    return deps.reportsService.topMovements(
      from: _from,
      to: _to,
      kinds: _selectedKinds.toList(growable: false),
      limit: _kTopLimit,
    );
  }

  void _updateRange({DateTime? from, DateTime? to}) {
    setState(() {
      if (from != null) _from = from;
      if (to != null) _to = to;
      _reportStream = _buildStream();
    });
  }

  Future<void> _pickFrom(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Desde',
    );
    if (picked == null) return;
    if (!context.mounted) return;
    final newFrom = DateTime(picked.year, picked.month, picked.day);
    if (newFrom.isAfter(_to)) {
      showWarningSnackbar(
        context,
        'El rango no es válido. Revisá las fechas.',
      );
      return;
    }
    _updateRange(from: newFrom);
  }

  Future<void> _pickTo(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _to,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Hasta',
    );
    if (picked == null) return;
    if (!context.mounted) return;
    final newTo =
        DateTime(picked.year, picked.month, picked.day, 23, 59, 59, 999);
    if (newTo.isBefore(_from)) {
      showWarningSnackbar(
        context,
        'El rango no es válido. Revisá las fechas.',
      );
      return;
    }
    _updateRange(to: newTo);
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMM y', 'es_MX');
    final isCustom = _preset == DateRangePreset.custom;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        // Chips de presets de fecha.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in DateRangePreset.values)
              ChoiceChip(
                label: Text(p.label),
                selected: _preset == p,
                onSelected: (_) => _selectPreset(p),
                showCheckmark: false,
                selectedColor: FincoreColors.accent.withValues(alpha: 0.18),
                backgroundColor: FincoreColors.surface,
                side: BorderSide(
                  color: _preset == p
                      ? FincoreColors.accent
                      : FincoreColors.border,
                ),
                labelStyle: TextStyle(
                  color: _preset == p
                      ? FincoreColors.accent
                      : FincoreColors.textPrimary,
                  fontWeight: _preset == p ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (!isCustom)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              '${dateFormat.format(_from)} — ${dateFormat.format(_to)}',
              style: const TextStyle(
                color: FincoreColors.textSubtle,
                fontSize: 12,
              ),
            ),
          ),
        if (isCustom) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: DateFieldOutlined(
                  label: 'Desde',
                  value: _from,
                  format: dateFormat,
                  onTap: () => _pickFrom(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DateFieldOutlined(
                  label: 'Hasta',
                  value: _to,
                  format: dateFormat,
                  onTap: () => _pickTo(context),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        // Chips de kinds multi-select (RF-006b).
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final k in JournalKind.values)
              _KindChip(
                label: k.label,
                selected: _selectedKinds.contains(k.apiValue),
                onTap: () => _toggleKind(k.apiValue),
              ),
          ],
        ),
        const SizedBox(height: 16),
        // Body: si no hay kinds seleccionados → empty state forzado.
        if (_selectedKinds.isEmpty)
          const _EmptyState(
            title: 'Seleccioná al menos un tipo de movimiento.',
            subtitle: 'Tocá los chips de arriba para activar tipos.',
            icon: Icons.filter_list_off,
          )
        else
          StreamBuilder<TopMovementsReport>(
            stream: _reportStream,
            builder: (context, snap) {
              if (snap.hasError) {
                return _ErrorState(
                  error: snap.error,
                  onRetry: () => setState(() {
                    _reportStream = _buildStream();
                  }),
                );
              }
              if (!snap.hasData) {
                return const _LoadingState();
              }
              final report = snap.data!;
              if (report.isEmpty) {
                return const _EmptyState(
                  title: 'No hay movimientos en este rango.',
                  subtitle: 'Ajustá las fechas o registrá un movimiento.',
                  icon: Icons.list_alt_outlined,
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < report.entries.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _TopMovementRow(entry: report.entries[i]),
                  ],
                ],
              );
            },
          ),
      ],
    );
  }
}

class _KindChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _KindChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      selectedColor: FincoreColors.accent.withValues(alpha: 0.18),
      backgroundColor: FincoreColors.surface,
      side: BorderSide(
        color: selected ? FincoreColors.accent : FincoreColors.border,
      ),
      labelStyle: TextStyle(
        color: selected ? FincoreColors.accent : FincoreColors.textPrimary,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }
}

class _TopMovementRow extends StatelessWidget {
  final TopMovementEntry entry;
  const _TopMovementRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final kind = parseJournalKind(entry.kind);
    final color = switch (kind) {
      JournalKind.income => FincoreColors.positive,
      JournalKind.expense ||
      JournalKind.creditExpense =>
        FincoreColors.negative,
      JournalKind.debtPayment || JournalKind.transfer => FincoreColors.accent,
    };
    final dateStr = DateFormat('d MMM y', 'es_MX').format(entry.occurredAt);
    final description = entry.description?.isNotEmpty == true
        ? entry.description!
        : kind.label;
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
                  description,
                  style: const TextStyle(
                    color: FincoreColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
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
                      style: const TextStyle(
                        color: FincoreColors.textSubtle,
                        fontSize: 11,
                      ),
                    ),
                    if (entry.category != null)
                      cb.CategoryBadge(
                        category: model.Category(
                          id: entry.category!.id,
                          name: entry.category!.name,
                          appliesTo: 'expense',
                          colorSlug: entry.category!.colorSlug ?? 'gray',
                          iconSlug: entry.category!.iconSlug ?? 'tag',
                          monthlyLimit: null,
                          deletedAt: null,
                        ),
                        compact: true,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _signed(kind, entry.amount),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
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
        JournalKind.expense ||
        JournalKind.creditExpense =>
          '-${formatAmount(amount)}',
        JournalKind.debtPayment ||
        JournalKind.transfer =>
          formatAmount(amount),
      };
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _EmptyState({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: FincoreColors.textMuted),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: FincoreColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: FincoreColors.textSubtle,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const BaseCard(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Center(
        child: Text(
          'Cargando…',
          style: TextStyle(
            color: FincoreColors.textSubtle,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: FincoreColors.warning,
          ),
          const SizedBox(height: 12),
          const Text(
            'No pude armar el reporte.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: FincoreColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            error?.toString() ?? 'Error desconocido',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: FincoreColors.textSubtle,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Reintentar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: FincoreColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

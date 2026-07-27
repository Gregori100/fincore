import 'package:fincore/app_dependencies.dart';
import 'package:fincore/constants/category_catalog.dart';
import 'package:fincore/constants/date_range_presets.dart';
import 'package:fincore/data/entries_filters.dart';
import 'package:fincore/data/reports.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/utils/money.dart';
import 'package:fincore/widgets/base_card.dart';
import 'package:fincore/widgets/date_field_outlined.dart';
import 'package:fincore/widgets/error_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Tab "Ingreso por categoría" del reporte. Sprint
/// `flutter-reports-income-by-category-v1`.
///
/// Análogo al tab "Gasto por categoría" pero para `kind='income'` y con
/// filtro `applies_to != 'expense'` en el LEFT JOIN. Header con chips de
/// presets (Este mes / Mes pasado / Año / Custom); default `thisMonth`.
/// En modo custom se habilitan dos DatePicker manuales. Reactivo:
/// cualquier cambio en `journal_entries` o `categories` rehydrata la
/// vista.
class IncomeByCategoryTab extends StatefulWidget {
  const IncomeByCategoryTab({super.key});

  @override
  State<IncomeByCategoryTab> createState() => _IncomeByCategoryTabState();
}

class _IncomeByCategoryTabState extends State<IncomeByCategoryTab> {
  late DateTime _from;
  late DateTime _to;
  DateRangePreset _preset = DateRangePreset.thisMonth;
  Stream<IncomeReport>? _reportStream;

  @override
  void initState() {
    super.initState();
    final r = dateRangeForPreset(DateRangePreset.thisMonth, DateTime.now());
    _from = r.$1;
    _to = r.$2;
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Cachear el Stream para no recrearlo en cada `build`; sin este cache
    // los widget tests con `pumpAndSettle` no asientan (cada build crea
    // un Stream nuevo via customSelect). Mismo patrón que el tab de
    // gastos y otros reportes.
    _reportStream ??= _buildStream();
  }

  Stream<IncomeReport> _buildStream() {
    final deps = AppDependencies.of(context);
    return deps.reportsService.incomeByCategory(from: _from, to: _to);
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
        'El rango no es válido. Verificar las fechas.',
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
        'El rango no es válido. Verificar las fechas.',
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
        StreamBuilder<IncomeReport>(
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
              return const _EmptyState();
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TotalCard(report: report),
                const SizedBox(height: 16),
                for (var i = 0; i < report.buckets.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _IncomeBucketRow(
                    bucket: report.buckets[i],
                    maxTotal: report.buckets.first.total,
                    from: report.from,
                    to: report.to,
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _TotalCard extends StatelessWidget {
  final IncomeReport report;
  const _TotalCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final movimientos =
        report.count == 1 ? '1 movimiento' : '${report.count} movimientos';
    return BaseCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total del período',
            style: TextStyle(
              color: FincoreColors.textSubtle,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            formatCents(report.total),
            style: const TextStyle(
              color: FincoreColors.positive,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            movimientos,
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

class _IncomeBucketRow extends StatelessWidget {
  final IncomeBucket bucket;
  final int maxTotal;
  final DateTime from;
  final DateTime to;

  const _IncomeBucketRow({
    required this.bucket,
    required this.maxTotal,
    required this.from,
    required this.to,
  });

  /// Deep link a `/entries` con `EntriesFilters.forIncomeBucket(...)`
  /// = kinds:['income'] + categoryId del bucket + rango del reporte.
  String _buildDeepLink() {
    return EntriesFilters.forIncomeBucket(
      categoryId: bucket.categoryId,
      from: from,
      to: to,
    ).toDeepLink();
  }

  @override
  Widget build(BuildContext context) {
    final color = colorBySlug(bucket.colorSlug);
    final icon = iconBySlug(bucket.iconSlug);
    final widthFactor =
        maxTotal > 0 ? (bucket.total / maxTotal).clamp(0.0, 1.0) : 0.0;
    final percentLabel = '${(bucket.percent * 100).toStringAsFixed(0)}%';
    return BaseCard(
      onTap: () => context.push(_buildDeepLink()),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  bucket.name,
                  style: const TextStyle(
                    color: FincoreColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatCents(bucket.total),
                    style: const TextStyle(
                      color: FincoreColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    percentLabel,
                    style: const TextStyle(
                      color: FincoreColors.textSubtle,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: Stack(
                children: [
                  Container(color: FincoreColors.surfaceElevated),
                  FractionallySizedBox(
                    widthFactor: widthFactor,
                    child: Container(color: color),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const BaseCard(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.trending_up,
            size: 56,
            color: FincoreColors.textMuted,
          ),
          SizedBox(height: 12),
          Text(
            'No se registraron ingresos en el período',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: FincoreColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Ajustar las fechas o registrar un movimiento.',
            textAlign: TextAlign.center,
            style: TextStyle(
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
            color: FincoreColors.negative,
          ),
          const SizedBox(height: 12),
          const Text(
            'No se pudo cargar el reporte',
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
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: FincoreColors.textSubtle,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
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

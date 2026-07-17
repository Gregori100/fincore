import 'package:fincore/app_dependencies.dart';
import 'package:fincore/constants/category_catalog.dart';
import 'package:fincore/constants/date_range_presets.dart';
import 'package:fincore/constants/reports_tokens.dart';
import 'package:fincore/data/entries_filters.dart';
import 'package:fincore/data/reports.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/theme/fincore_radii.dart';
import 'package:fincore/theme/fincore_spacing.dart';
import 'package:fincore/widgets/amount_formatter.dart';
import 'package:fincore/widgets/base_card.dart';
import 'package:fincore/widgets/date_field_outlined.dart';
import 'package:fincore/widgets/error_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Tab "Gasto por categoría" del reporte. Header con chips de presets
/// (Este mes / Mes pasado / Año / Custom). Default al abrir: "Este mes" =
/// día 1 al último día del mes calendario corriente. En modo `custom` se
/// habilitan dos DatePicker manuales. Reactivo: cualquier cambio en
/// `journal_entries` o `categories` rehydrata la vista.
class SpendingByCategoryTab extends StatefulWidget {
  const SpendingByCategoryTab({super.key});

  @override
  State<SpendingByCategoryTab> createState() => _SpendingByCategoryTabState();
}

class _SpendingByCategoryTabState extends State<SpendingByCategoryTab> {
  late DateTime _from;
  late DateTime _to;
  DateRangePreset _preset = DateRangePreset.thisMonth;
  Stream<SpendingReport>? _reportStream;

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
    // Cachear el Stream del reporte para no recrearlo en cada `build`. Sin
    // este cache, `pumpAndSettle` en widget tests nunca asienta (cada build
    // crea un Stream nuevo via customSelect, dejando un evento pendiente
    // perpetuamente). Patrón idéntico al usado en `DashboardScreen` para
    // los streams BO/DE/CR.
    _reportStream ??= _buildStream();
  }

  Stream<SpendingReport> _buildStream() {
    final deps = AppDependencies.of(context);
    return deps.reportsService.spendingByCategory(from: _from, to: _to);
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
        // Chips de presets. Wrap permite que en pantallas angostas se ajusten
        // a dos filas sin overflow.
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
        // Resumen del rango efectivo. En Custom se reemplaza por los dos
        // input fields de fecha más abajo.
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
        const SizedBox(height: kSpaceLg),
        // Stream del reporte (cacheado en `_reportStream`).
        StreamBuilder<SpendingReport>(
          stream: _reportStream,
          builder: (context, snap) {
            // Error state: defensiva contra falla de la query (M3 quality
            // review v1). En local-first sin red es raro, pero protege
            // contra bugs internos de drift o schema mismatch tras un
            // downgrade futuro.
            if (snap.hasError) {
              return _ErrorState(
                error: snap.error,
                onRetry: () => setState(() {
                  _reportStream = _buildStream();
                }),
              );
            }
            // Loading state: card estático sin animación (M5 quality
            // review v1). `SkeletonCard` y `CircularProgressIndicator`
            // tienen AnimationController perpetuo que cuelga
            // `pumpAndSettle` en widget tests. La query suele ser tan
            // rápida que el usuario raramente lo ve, pero al menos da
            // feedback visual.
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
                const SizedBox(height: kSpaceLg),
                for (var i = 0; i < report.buckets.length; i++) ...[
                  if (i > 0) const SizedBox(height: kSpaceSm),
                  _SpendingBucketRow(
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
  final SpendingReport report;
  const _TotalCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final movimientos = report.count == 1 ? '1 movimiento' : '${report.count} movimientos';
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
            formatAmount(report.total),
            style: const TextStyle(
              color: FincoreColors.negative,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: kSpaceXs),
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

/// Una fila por bucket. Combina visual de "barra horizontal" (ancho
/// proporcional al monto del bucket sobre el bucket top) + icono + nombre +
/// monto + porcentaje. Modela el preview elegido por Diego en spec-definir:
///
/// ```
/// ████████████ Comida    $4,200
/// ████████ Transporte $2,800
/// ```
class _SpendingBucketRow extends StatelessWidget {
  final SpendingBucket bucket;
  final double maxTotal;
  final DateTime from;
  final DateTime to;

  const _SpendingBucketRow({
    required this.bucket,
    required this.maxTotal,
    required this.from,
    required this.to,
  });

  /// Construye el deep link a `/entries` con el filtro equivalente al bucket
  /// (sprint flutter-movements-filters-v1, RF-016 + RN-M08). M8 del quality
  /// review v1: la composición y la serialización se encapsulan en
  /// `EntriesFilters.forCategoryBucket` + `.toDeepLink()` para desacoplar al
  /// reporte del formato interno de filtros.
  String _buildDeepLink() {
    return EntriesFilters.forCategoryBucket(
      categoryId: bucket.categoryId,
      from: from,
      to: to,
    ).toDeepLink();
  }

  @override
  Widget build(BuildContext context) {
    final color = colorBySlug(bucket.colorSlug);
    final icon = iconBySlug(bucket.iconSlug);
    // `maxTotal` viene siempre del bucket top (orden desc), por construcción
    // > 0 cuando hay buckets. Defensa contra edge case por si en el futuro
    // se invoca esta clase con maxTotal=0.
    final widthFactor = maxTotal > 0 ? (bucket.total / maxTotal).clamp(0.0, 1.0) : 0.0;
    final percentLabel = '${(bucket.percent * 100).toStringAsFixed(0)}%';
    // Hotfix branch-quality-review (F-ARCH-01 / B2) + refined smoke Diego:
    // renglones sintéticos "Intereses de préstamos" (v1) y "Pago a capital
    // de préstamos" (v4). Ambos comparten drill-down: filtro
    // `kind='loan_payment'` + rango temporal del reporte para que Diego
    // vea los pagos con su split.
    final isSyntheticLoan =
        bucket.categoryId == kLoanInterestSyntheticId ||
            bucket.categoryId == kLoanCapitalSyntheticId;
    return BaseCard(
      onTap: () => isSyntheticLoan
          ? context.push(EntriesFilters.forLoanInterestBucket(
              from: from,
              to: to,
            ).toDeepLink())
          : context.push(_buildDeepLink()),
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
                  color: color.withValues(alpha: FincoreColors.alphaTint),
                  borderRadius: BorderRadius.circular(kRadiusMd),
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
                    formatAmount(bucket.total),
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
          // Barra horizontal proporcional. Stack + FractionallySizedBox
          // dibuja la barra coloreada sobre el fondo neutro de la card.
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
            Icons.bar_chart_outlined,
            size: 56,
            color: FincoreColors.textMuted,
          ),
          SizedBox(height: kSpaceMd),
          Text(
            'No hay gastos en el rango seleccionado',
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

/// Card estático mostrado mientras el Stream del reporte arma el primer
/// evento. Sin animación: usar `SkeletonCard` o `CircularProgressIndicator`
/// cuelga `pumpAndSettle` en widget tests por su AnimationController
/// perpetuo. M5 del quality review v1.
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

/// Card de error con botón "Reintentar" que re-arma el Stream del reporte.
/// Defensiva contra falla de la query (M3 del quality review v1). El
/// callback `onRetry` reasigna `_reportStream` en el State del padre.
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
          const SizedBox(height: kSpaceMd),
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
          const SizedBox(height: kSpaceMd),
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


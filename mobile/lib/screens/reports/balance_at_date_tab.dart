import 'package:fincore/app_dependencies.dart';
import 'package:fincore/data/reports.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/widgets/amount_formatter.dart';
import 'package:fincore/widgets/base_card.dart';
import 'package:fincore/widgets/date_field_outlined.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Tab "Saldo a fecha" del reporte. Sprint
/// `flutter-reports-balance-at-date-v1`.
///
/// Replay del journal hasta `_asOf` para mostrar BO/DE/CR a esa fecha + lista
/// de cuentas con saldo individual. Default `_asOf = fin del mes anterior`
/// (decisión P-001), apuntando al uso típico de reconciliación bancaria.
class BalanceAtDateTab extends StatefulWidget {
  const BalanceAtDateTab({super.key});

  @override
  State<BalanceAtDateTab> createState() => _BalanceAtDateTabState();
}

class _BalanceAtDateTabState extends State<BalanceAtDateTab> {
  late DateTime _asOf;
  Stream<BalanceAtDateReport>? _reportStream;

  @override
  void initState() {
    super.initState();
    // Truco día 0 = último día del mes anterior. Default P-001.
    final now = DateTime.now();
    _asOf = DateTime(now.year, now.month, 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reportStream ??= _buildStream();
  }

  Stream<BalanceAtDateReport> _buildStream() {
    final deps = AppDependencies.of(context);
    return deps.reportsService.balanceAtDate(asOf: _asOf);
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _asOf,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now(),
      helpText: 'Saldo al',
    );
    if (picked == null) return;
    if (!context.mounted) return;
    setState(() {
      _asOf = DateTime(picked.year, picked.month, picked.day);
      _reportStream = _buildStream();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMM y', 'es_MX');
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        DateFieldOutlined(
          label: 'Saldo al',
          value: _asOf,
          format: dateFormat,
          onTap: () => _pickDate(context),
        ),
        const SizedBox(height: 16),
        StreamBuilder<BalanceAtDateReport>(
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
                _BalanceCards(report: report),
                const SizedBox(height: 16),
                _AccountsList(
                  accounts: report.accounts,
                  asOf: report.asOf,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _BalanceCards extends StatelessWidget {
  final BalanceAtDateReport report;
  const _BalanceCards({required this.report});

  @override
  Widget build(BuildContext context) {
    final asOfLabel = DateFormat('d MMM', 'es_MX').format(report.asOf);
    return Row(
      children: [
        Expanded(
          child: _BalanceCard(
            label: 'BO',
            amountNow: report.boNow,
            amountAtDate: report.bo,
            delta: report.boDelta,
            color: FincoreColors.positive,
            asOfLabel: asOfLabel,
            // Para BO: subir es bueno (positive), bajar es malo (negative).
            deltaUpIsGood: true,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _BalanceCard(
            label: 'DE',
            amountNow: report.deNow,
            amountAtDate: report.de,
            delta: report.deDelta,
            color: FincoreColors.negative,
            asOfLabel: asOfLabel,
            // Para DE: subir es malo, bajar es bueno.
            deltaUpIsGood: false,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _BalanceCard(
            label: 'CR',
            amountNow: report.crNow,
            amountAtDate: report.cr,
            delta: report.crDelta,
            color: FincoreColors.accent,
            asOfLabel: asOfLabel,
            // Para CR: subir es bueno (más disponible).
            deltaUpIsGood: true,
          ),
        ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final String label;
  final double amountNow;
  final double amountAtDate;
  final double delta;
  final Color color;
  final String asOfLabel;
  final bool deltaUpIsGood;

  const _BalanceCard({
    required this.label,
    required this.amountNow,
    required this.amountAtDate,
    required this.delta,
    required this.color,
    required this.asOfLabel,
    required this.deltaUpIsGood,
  });

  @override
  Widget build(BuildContext context) {
    final isFlat = delta.abs() < 0.005;
    final isUp = delta > 0;
    final deltaColor = isFlat
        ? FincoreColors.textSubtle
        : ((isUp == deltaUpIsGood)
            ? FincoreColors.positive
            : FincoreColors.negative);
    final deltaArrow = isFlat ? '' : (isUp ? '↑ ' : '↓ ');
    final deltaSign = isFlat
        ? '0'
        : (isUp
            ? '+${formatAmount(delta)}'
            : '-${formatAmount(delta.abs())}');
    return BaseCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          // A fecha: tamaño principal (el tab pide "saldo a fecha").
          Text(
            formatAmount(amountAtDate),
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            asOfLabel,
            style: const TextStyle(
              color: FincoreColors.textSubtle,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 6),
          // Hoy: contexto comparativo.
          Text(
            formatAmount(amountNow),
            style: const TextStyle(
              color: FincoreColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Text(
            'hoy',
            style: TextStyle(
              color: FincoreColors.textSubtle,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 6),
          // Delta con color semántico — la conclusión.
          Text(
            '$deltaArrow$deltaSign',
            style: TextStyle(
              color: deltaColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _AccountsList extends StatelessWidget {
  final List<AccountBalanceAtDate> accounts;
  final DateTime asOf;
  const _AccountsList({required this.accounts, required this.asOf});

  @override
  Widget build(BuildContext context) {
    final asOfLabel = DateFormat('d MMM', 'es_MX').format(asOf);
    return BaseCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        children: [
          for (var i = 0; i < accounts.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, color: FincoreColors.border),
            _AccountRow(account: accounts[i], asOfLabel: asOfLabel),
          ],
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  final AccountBalanceAtDate account;
  final String asOfLabel;
  const _AccountRow({required this.account, required this.asOfLabel});

  @override
  Widget build(BuildContext context) {
    final typeLabel = switch (account.type) {
      'cash' => 'Efectivo',
      'debit' => 'Débito',
      'credit' => 'Crédito',
      _ => account.type,
    };
    final isCredit = account.type == 'credit';
    // Para credit, balance es la deuda (positivo = debe). Convertimos a
    // valor visible (negativo si debe) para que el signo sea natural.
    final displayNow = isCredit ? -account.balanceNow : account.balanceNow;
    final displayAtDate = isCredit ? -account.balance : account.balance;
    final atDateColor = displayAtDate >= 0
        ? FincoreColors.textPrimary
        : FincoreColors.negative;

    // Delta del saldo visible.
    final visualDelta = displayNow - displayAtDate;
    final isFlat = visualDelta.abs() < 0.005;
    final isUp = visualDelta > 0;
    final deltaColor = isFlat
        ? FincoreColors.textSubtle
        : (isUp ? FincoreColors.positive : FincoreColors.negative);
    final deltaArrow = isFlat ? '' : (isUp ? '↑ ' : '↓ ');
    final deltaSign = isFlat
        ? '0'
        : (isUp
            ? '+${formatAmount(visualDelta)}'
            : '-${formatAmount(visualDelta.abs())}');

    String formatVisible(double v, {String suffix = ''}) {
      return '${v < 0 ? '-' : ''}${formatAmount(v.abs())}$suffix';
    }

    final suffixAtDate =
        isCredit && account.balance > 0 ? ' deuda' : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.name,
                  style: const TextStyle(
                    color: FincoreColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  typeLabel,
                  style: const TextStyle(
                    color: FincoreColors.textSubtle,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Saldo a fecha (principal — coherente con el tab "Saldo a
              // fecha"). El saldo de hoy ya está en las cards globales
              // arriba; no se repite por cuenta para evitar densidad.
              Text(
                formatVisible(displayAtDate, suffix: suffixAtDate),
                style: TextStyle(
                  color: atDateColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                asOfLabel,
                style: const TextStyle(
                  color: FincoreColors.textSubtle,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 4),
              // Delta destacado — la conclusión por cuenta.
              Text(
                '$deltaArrow$deltaSign',
                style: TextStyle(
                  color: deltaColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
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
          Icon(Icons.account_balance_wallet_outlined,
              size: 56, color: FincoreColors.textMuted),
          SizedBox(height: 12),
          Text(
            'No hay cuentas activas.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: FincoreColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Creá una cuenta para empezar.',
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

import 'package:fincore/app_dependencies.dart';
import 'package:fincore/data/reports.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/widgets/amount_formatter.dart';
import 'package:fincore/widgets/base_card.dart';
import 'package:fincore/widgets/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Tab "Tarjetas" del reporte. Sprint
/// `flutter-reports-credit-cards-v1`.
///
/// Muestra estado actual de tarjetas de crédito activas: deuda, % usado,
/// disponible, próximo corte, próximo pago, pago mínimo estimado.
/// Reactivo: usa `ReportsService.watchCreditCards()` para actualizarse
/// cuando cambian `accounts` o `journal_entries`.
class CreditCardsTab extends StatefulWidget {
  const CreditCardsTab({super.key});

  @override
  State<CreditCardsTab> createState() => _CreditCardsTabState();
}

class _CreditCardsTabState extends State<CreditCardsTab> {
  Stream<List<CreditCardStatus>>? _stream;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stream ??= AppDependencies.of(context).reportsService.watchCreditCards();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CreditCardStatus>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return _ErrorState(error: snap.error);
        }
        if (!snap.hasData) {
          return const _LoadingState();
        }
        final cards = snap.data!;
        if (cards.isEmpty) {
          return const _EmptyState();
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          itemCount: cards.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) => _CreditCardTile(status: cards[i]),
        );
      },
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: const [
        SkeletonCard(),
        SizedBox(height: 12),
        SkeletonCard(),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.credit_card_outlined,
              size: 64,
              color: FincoreColors.textMuted,
            ),
            const SizedBox(height: 16),
            const Text(
              'No hay tarjetas de crédito todavía',
              style: TextStyle(
                color: FincoreColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Crear una desde el ícono + para verla aquí con su deuda, '
              'límite disponible y próximas fechas de corte y pago.',
              style: TextStyle(
                color: FincoreColors.textSubtle,
                fontSize: 13,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => context.push('/accounts/new'),
              icon: const Icon(Icons.add),
              label: const Text('Agregar tarjeta'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Object? error;
  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: FincoreColors.negative),
            const SizedBox(height: 16),
            Text(
              'No se pudo cargar el estado de tarjetas.\n${error ?? ''}',
              style: const TextStyle(color: FincoreColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _CreditCardTile extends StatelessWidget {
  final CreditCardStatus status;
  const _CreditCardTile({required this.status});

  @override
  Widget build(BuildContext context) {
    final ringColor = _ringColorForStatus(status);
    return BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(status: status),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _UsedRing(
                usedPct: status.usedPct,
                color: ringColor,
                isOverdue: status.isOverdue,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MoneyRow(
                      label: 'Deuda',
                      amount: status.debt,
                      amountColor: status.isOverdue
                          ? FincoreColors.negative
                          : FincoreColors.textPrimary,
                    ),
                    const SizedBox(height: 4),
                    _MoneyRow(
                      label: 'Límite',
                      amount: status.creditLimit,
                      amountColor: FincoreColors.textSubtle,
                    ),
                    const SizedBox(height: 4),
                    _MoneyRow(
                      label: 'Disponible',
                      amount: status.availableCredit,
                      amountColor: FincoreColors.positive,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (status.isOverdue) ...[
            const SizedBox(height: 12),
            _OverdueBadge(exceededBy: status.debt - status.creditLimit),
          ],
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          _DateRow(
            label: 'Próximo corte',
            date: status.nextClosingDate,
            daysTo: status.daysToClosing,
          ),
          const SizedBox(height: 8),
          _DateRow(
            label: 'Próximo pago',
            date: status.nextPaymentDate,
            daysTo: status.daysToPayment,
          ),
        ],
      ),
    );
  }

  Color _ringColorForStatus(CreditCardStatus s) {
    if (s.isOverdue) return FincoreColors.negative;
    if (s.usedPct != null && s.usedPct! >= 80) return FincoreColors.warning;
    return FincoreColors.accent;
  }
}

class _Header extends StatelessWidget {
  final CreditCardStatus status;
  const _Header({required this.status});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                status.name,
                style: const TextStyle(
                  color: FincoreColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (status.description != null &&
                  status.description!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  status.description!,
                  style: const TextStyle(
                    color: FincoreColors.textSubtle,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (status.isDebtFree) const _DebtFreeBadge(),
      ],
    );
  }
}

class _UsedRing extends StatelessWidget {
  final double? usedPct;
  final Color color;
  final bool isOverdue;
  const _UsedRing({
    required this.usedPct,
    required this.color,
    required this.isOverdue,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: usedPct == null ? 0 : (usedPct! / 100).clamp(0.0, 1.0),
              strokeWidth: 6,
              backgroundColor: FincoreColors.border,
              color: color,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                usedPct == null ? '—' : '${usedPct!.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Text(
                'usado',
                style: TextStyle(
                  color: FincoreColors.textSubtle,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MoneyRow extends StatelessWidget {
  final String label;
  final double amount;
  final Color amountColor;
  const _MoneyRow({
    required this.label,
    required this.amount,
    required this.amountColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: FincoreColors.textMuted,
            fontSize: 13,
          ),
        ),
        Text(
          formatAmount(amount),
          style: TextStyle(
            color: amountColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _DateRow extends StatelessWidget {
  final String label;
  final DateTime? date;
  final int? daysTo;
  const _DateRow({
    required this.label,
    required this.date,
    required this.daysTo,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMM', 'es_MX');
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: FincoreColors.textMuted,
            fontSize: 13,
          ),
        ),
        Row(
          children: [
            Text(
              date == null ? '—' : dateFormat.format(date!),
              style: const TextStyle(
                color: FincoreColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (daysTo != null) ...[
              const SizedBox(width: 8),
              _ProximityBadge(daysTo: daysTo!),
            ],
          ],
        ),
      ],
    );
  }
}

class _ProximityBadge extends StatelessWidget {
  final int daysTo;
  const _ProximityBadge({required this.daysTo});

  @override
  Widget build(BuildContext context) {
    final String label;
    if (daysTo <= 0) {
      label = 'Hoy';
    } else if (daysTo == 1) {
      label = 'Mañana';
    } else {
      label = 'en $daysTo días';
    }
    final Color color;
    if (daysTo <= 0) {
      color = FincoreColors.negative;
    } else if (daysTo <= 7) {
      color = FincoreColors.warning;
    } else {
      color = FincoreColors.textSubtle;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DebtFreeBadge extends StatelessWidget {
  const _DebtFreeBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: FincoreColors.positive.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'Sin deuda',
        style: TextStyle(
          color: FincoreColors.positive,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _OverdueBadge extends StatelessWidget {
  final double exceededBy;
  const _OverdueBadge({required this.exceededBy});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: FincoreColors.negative.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: FincoreColors.negative.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: FincoreColors.negative, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Excedido por ${formatAmount(exceededBy)}',
              style: const TextStyle(
                color: FincoreColors.negative,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


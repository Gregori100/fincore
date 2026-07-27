import 'package:fincore/app_dependencies.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/theme/fincore_radii.dart';
import 'package:fincore/theme/fincore_spacing.dart';
import 'package:fincore/utils/money.dart';
import 'package:fincore/widgets/base_card.dart';
import 'package:fincore/widgets/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Segmentos del listado de préstamos. Sprint flutter-loans-v1: paralelo al
/// segmentado de /accounts (activos vs archivados). Los eliminados nunca
/// aparecen en ningún segmento.
enum LoansSegment { active, closed }

class LoansListScreen extends StatefulWidget {
  const LoansListScreen({super.key});

  @override
  State<LoansListScreen> createState() => _LoansListScreenState();
}

class _LoansListScreenState extends State<LoansListScreen> {
  LoansSegment _segment = LoansSegment.active;
  Stream<List<Loan>>? _activeStream;
  Stream<List<Loan>>? _closedStream;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dao = AppDependencies.of(context).loansDao;
    _activeStream ??= dao.watchActive();
    _closedStream ??= dao.watchClosed();
  }

  @override
  Widget build(BuildContext context) {
    final stream =
        _segment == LoansSegment.active ? _activeStream : _closedStream;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Préstamos'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      floatingActionButton: _segment == LoansSegment.active
          ? FloatingActionButton(
              onPressed: () => context.push('/loans/new'),
              backgroundColor: FincoreColors.accent,
              foregroundColor: FincoreColors.canvas,
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                kSpaceLg, kSpaceMd, kSpaceLg, kSpaceSm),
            child: SegmentedButton<LoansSegment>(
              segments: const [
                ButtonSegment(
                  value: LoansSegment.active,
                  label: Text('Activos'),
                  icon: Icon(Icons.request_quote_outlined),
                ),
                ButtonSegment(
                  value: LoansSegment.closed,
                  label: Text('Cerrados'),
                  icon: Icon(Icons.inventory_2_outlined),
                ),
              ],
              selected: {_segment},
              onSelectionChanged: (selection) {
                setState(() => _segment = selection.first);
              },
              showSelectedIcon: false,
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Loan>>(
              stream: stream,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                        kSpaceLg, kSpaceLg, kSpaceLg, kFabClearance),
                    itemCount: 3,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: kSpaceSm),
                    itemBuilder: (_, __) => const SkeletonCard(),
                  );
                }
                final list = snap.data!;
                if (list.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(kSpaceXl),
                      child: Text(
                        _segment == LoansSegment.active
                            ? 'Aún no tienes préstamos activos.\n\nUsa el botón + para registrar uno.'
                            : 'No tienes préstamos cerrados.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: FincoreColors.textMuted),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                      kSpaceLg, kSpaceLg, kSpaceLg, kFabClearance),
                  itemCount: list.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: kSpaceSm),
                  itemBuilder: (_, i) => _LoanRow(
                    loan: list[i],
                    isClosed: _segment == LoansSegment.closed,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LoanRow extends StatelessWidget {
  final Loan loan;
  final bool isClosed;
  const _LoanRow({required this.loan, required this.isClosed});

  @override
  Widget build(BuildContext context) {
    final deps = AppDependencies.of(context);
    return BaseCard(
      onTap: () => context.push('/loans/${loan.id}'),
      padding: const EdgeInsets.symmetric(
          horizontal: kSpaceLg - kSpace2xs, vertical: kSpaceMd),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              // F-DES-2: identidad del módulo con categoryOrange, no warning.
              color: FincoreColors.categoryOrange.withValues(
                alpha: isClosed
                    ? FincoreColors.alphaHover
                    : FincoreColors.alphaTint,
              ),
              borderRadius: BorderRadius.circular(kRadiusMd),
            ),
            child: Icon(
              Icons.request_quote_outlined,
              color: isClosed
                  ? FincoreColors.textSubtle
                  : FincoreColors.categoryOrange,
            ),
          ),
          const SizedBox(width: kSpaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        loan.name,
                        style: TextStyle(
                          color: isClosed
                              ? FincoreColors.textSubtle
                              : FincoreColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontStyle: isClosed
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isClosed) ...[
                      const SizedBox(width: kSpaceSm),
                      _StatusBadge(reason: loan.closeReason),
                    ],
                  ],
                ),
                const SizedBox(height: kSpace2xs),
                Text(
                  '${formatCents(loan.monthlyPayment)} · día ${loan.paymentDay}',
                  style: const TextStyle(
                      color: FincoreColors.textSubtle, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: kSpaceSm),
          StreamBuilder<int>(
            stream: deps.loansDao.watchBalance(loan.id),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Skeleton(width: 80, height: 16);
              }
              final balance = snap.data!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatCents(balance),
                    style: TextStyle(
                      color: isClosed
                          ? FincoreColors.textSubtle
                          : FincoreColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'de ${formatCents(loan.principalAmount)}',
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
}

class _StatusBadge extends StatelessWidget {
  final String? reason;
  const _StatusBadge({required this.reason});

  @override
  Widget build(BuildContext context) {
    final isPaid = reason == 'paid';
    // F-DES-2: badge "Cerrado" con categoryOrange (estado, no alerta).
    final color =
        isPaid ? FincoreColors.positive : FincoreColors.categoryOrange;
    final label = isPaid ? 'Pagado' : 'Cerrado';
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: kSpaceSm, vertical: kSpace2xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: FincoreColors.alphaTint),
        borderRadius: BorderRadius.circular(kRadiusSm),
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

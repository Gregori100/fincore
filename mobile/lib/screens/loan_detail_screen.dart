import 'package:fincore/app_dependencies.dart';
import 'package:fincore/data/daos/entries_dao.dart';
import 'package:fincore/data/daos/loans_dao.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/theme/fincore_radii.dart';
import 'package:fincore/theme/fincore_spacing.dart';
import 'package:fincore/theme/fincore_typography.dart';
import 'package:fincore/utils/money.dart';
import 'package:fincore/widgets/base_card.dart';
import 'package:fincore/widgets/confirm_dialog.dart';
import 'package:fincore/widgets/error_snackbar.dart';
import 'package:fincore/widgets/loan_actions_menu.dart';
import 'package:fincore/widgets/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class LoanDetailScreen extends StatefulWidget {
  final String loanId;
  const LoanDetailScreen({super.key, required this.loanId});

  @override
  State<LoanDetailScreen> createState() => _LoanDetailScreenState();
}

class _LoanDetailScreenState extends State<LoanDetailScreen> {
  // Hotfix smoke Diego: `_loanStream` reactivo (antes era Loan? cacheado
  // en state). El detalle no refrescaba tras editar el contrato — el
  // `updateLoan` desde el form guardaba en BD pero el detail seguía
  // mostrando el snapshot viejo hasta salir y volver a entrar.
  Stream<Loan?>? _loanStream;
  Stream<int>? _balanceStream;
  Stream<List<JournalEntry>>? _paymentsStream;
  // Sprint flutter-loans-flexible-payments-v1.
  Stream<List<LoanAdjustment>>? _adjustmentsStream;
  Stream<int>? _adjustmentsTotalStream;
  List<Account> _accounts = const [];
  bool _loading = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    if (!mounted || _loaded) return;
    _loaded = true;
    setState(() => _loading = true);
    final deps = AppDependencies.of(context);
    try {
      _accounts = await deps.accountsDao.listAll();
      _loanStream = deps.loansDao.watchById(widget.loanId);
      _balanceStream = deps.loansDao.watchBalance(widget.loanId);
      _paymentsStream = deps.loansDao.watchPayments(widget.loanId);
      _adjustmentsStream = deps.loansDao.watchAdjustments(widget.loanId);
      _adjustmentsTotalStream =
          deps.loansDao.watchAdjustmentsTotal(widget.loanId);
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _viewInitialIncome() async {
    final deps = AppDependencies.of(context);
    final id = await deps.loansDao.findIncomeEntryId(widget.loanId);
    if (id == null || !mounted) return;
    context.push('/entries/$id/edit');
  }

  Future<void> _confirmDeletePayment(JournalEntry payment) async {
    final deps = AppDependencies.of(context);
    // Sprint flutter-loans-flexible-payments-v1: aquí vivía un
    // `DestructiveDialog` que advertía sobre el borrado en cascada de los
    // abonos a capital del mismo mes. La cascada existía sólo para sostener
    // el invariante `capital_before_monthly`; sin ese candado, cada pago se
    // elimina de forma independiente (RN-LF-04) y no hay impacto sobre
    // otros registros que advertir.
    final ok = await showConfirmDialog(
      context,
      title: 'Eliminar pago',
      message:
          'Eliminar el pago del ${DateFormat("d MMM y", "es_MX").format(payment.occurredAt)} '
          'por ${formatCents(payment.amount)}. Si el préstamo estaba pagado se reabrirá '
          'automáticamente.',
      confirmLabel: 'Eliminar pago',
    );
    if (!ok || !mounted) return;
    try {
      await deps.entriesDao.deleteLoanPayment(payment.id);
      if (mounted) showSuccessSnackbar(context, 'Pago eliminado.');
    } on EntriesDaoError catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    }
  }

  Future<void> _confirmDeleteAdjustment(LoanAdjustment adj) async {
    final deps = AppDependencies.of(context);
    final ok = await showConfirmDialog(
      context,
      title: 'Eliminar ajuste',
      message:
          'Eliminar el ajuste de ${formatCents(adj.amount, showSign: true)} '
          'del ${DateFormat("d MMM y", "es_MX").format(adj.occurredAt)}. El '
          'saldo del préstamo se recalcula y puede cambiar su estado.',
      confirmLabel: 'Eliminar ajuste',
    );
    if (!ok || !mounted) return;
    try {
      await deps.loansDao.deleteAdjustment(adj.id);
      if (mounted) showSuccessSnackbar(context, 'Ajuste eliminado.');
    } on LoansDaoError catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _loanStream == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cargando...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return StreamBuilder<Loan?>(
      stream: _loanStream,
      builder: (context, snap) {
        // Hotfix quality-review M10: distinguir cargando / no-existe /
        // error. Antes cualquier `null` mostraba spinner eterno (bug post
        // delete y deep-link a préstamo inexistente).
        if (snap.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Préstamo'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(kSpaceLg),
                child: Text(
                  'No se pudo cargar el préstamo.\n${snap.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: FincoreColors.textMuted),
                ),
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Préstamo'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final loan = snap.data;
        if (loan == null) {
          // El préstamo fue eliminado o el id no existe.
          return Scaffold(
            appBar: AppBar(
              title: const Text('Préstamo'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(kSpaceLg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.help_outline,
                        color: FincoreColors.textMuted, size: 48),
                    const SizedBox(height: kSpaceMd),
                    const Text(
                      'Este préstamo ya no existe.',
                      style: TextStyle(color: FincoreColors.textMuted),
                    ),
                    const SizedBox(height: kSpaceLg),
                    FilledButton.tonal(
                      onPressed: () => context.go('/dashboard'),
                      child: const Text('Volver al inicio'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        final isClosed = loan.closedAt != null;
        final isPaid = loan.closeReason == 'paid';
        final destAccount = _accounts.firstWhereOrNull(
            (a) => a.id == loan.destinationAccountId);

        return Scaffold(
          appBar: AppBar(
            title: Text(loan.name),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            actions: [
              LoanActionsMenu(
                loan: loan,
                accounts: _accounts,
                onEdit: () => context.push('/loans/${widget.loanId}/edit'),
              ),
            ],
          ),
          floatingActionButton: isClosed
              ? null
              : _PaymentFabRow(loanId: widget.loanId),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  kSpaceLg, kSpaceLg, kSpaceLg, kFabClearance),
              children: [
                _Header(
                  loan: loan,
                  balanceStream: _balanceStream!,
                  paymentsStream: _paymentsStream!,
                  adjustmentsTotalStream: _adjustmentsTotalStream!,
                  destAccount: destAccount,
                  onViewInitialIncome: _viewInitialIncome,
                ),
                if (isPaid) ...[
                  const SizedBox(height: kSpaceLg),
                  const _StateChipRow(
                    icon: Icons.check_circle_outline,
                    color: FincoreColors.positive,
                    label: 'Préstamo pagado en su totalidad',
                  ),
                ] else if (isClosed) ...[
                  const SizedBox(height: kSpaceLg),
                  const _StateChipRow(
                    icon: Icons.lock_outline,
                    // F-DES-2: estado, no alerta activa.
                    color: FincoreColors.categoryOrange,
                    label: 'Cerrado manualmente · sin pagos permitidos',
                  ),
                ],
                const SizedBox(height: kSpaceXl),
                const Text(
                  'Pagos registrados',
                  style: TextStyle(
                    color: FincoreColors.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: kSpaceSm),
                StreamBuilder<List<JournalEntry>>(
                  stream: _paymentsStream,
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return Column(
                        children: List.generate(
                          3,
                          (_) => const Padding(
                            padding: EdgeInsets.only(bottom: kSpaceSm),
                            child: SkeletonCard(),
                          ),
                        ),
                      );
                    }
                    final payments = snap.data!;
                    if (payments.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(kSpaceLg),
                        child: Text(
                          isClosed
                              ? 'No hay pagos registrados.'
                              : 'Aún no registras pagos.\nUsa el FAB inferior.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: FincoreColors.textMuted),
                        ),
                      );
                    }
                    return Column(
                      children: [
                        for (final p in payments) ...[
                          _PaymentRow(
                            payment: p,
                            loanId: widget.loanId,
                            // Hotfix smoke Diego v4: solo el cierre manual
                            // bloquea edición/borrado. Un préstamo 'paid'
                            // sigue permitiendo eliminar el último pago
                            // (con auto-reapertura) para corregir errores.
                            readOnly: isClosed && !isPaid,
                            onDeleteRequested: () =>
                                _confirmDeletePayment(p),
                          ),
                          const SizedBox(height: kSpaceSm),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: kSpaceXl),
                // Sprint flutter-loans-flexible-payments-v1: los ajustes van
                // en su propia sección y no mezclados con los pagos. Son
                // eventos de naturaleza distinta — no movieron dinero — y
                // fundirlos en una sola línea de tiempo invitaba a leerlos
                // como pagos.
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Ajustes de saldo',
                        style: TextStyle(
                          color: FincoreColors.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      // Disponible incluso con el préstamo cerrado: ese es
                      // justamente el caso de uso (RN-LF-10).
                      onPressed: () => context
                          .push('/loans/${widget.loanId}/adjustments/new'),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Ajustar'),
                    ),
                  ],
                ),
                const SizedBox(height: kSpaceXs),
                StreamBuilder<List<LoanAdjustment>>(
                  stream: _adjustmentsStream,
                  builder: (context, snap) {
                    final adjustments = snap.data ?? const <LoanAdjustment>[];
                    if (adjustments.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: kSpaceSm),
                        child: Text(
                          'Sin ajustes. Úsalos si el banco cambia tu saldo '
                          'sin que medie un pago.',
                          style: TextStyle(
                              color: FincoreColors.textSubtle, fontSize: 12),
                        ),
                      );
                    }
                    return Column(
                      children: [
                        for (final a in adjustments) ...[
                          _AdjustmentRow(
                            adjustment: a,
                            loanId: widget.loanId,
                            onDeleteRequested: () =>
                                _confirmDeleteAdjustment(a),
                          ),
                          const SizedBox(height: kSpaceSm),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}


class _Header extends StatelessWidget {
  final Loan loan;
  final Stream<int> balanceStream;
  final Stream<List<JournalEntry>> paymentsStream;
  final Stream<int> adjustmentsTotalStream;
  final Account? destAccount;
  final VoidCallback onViewInitialIncome;
  const _Header({
    required this.loan,
    required this.balanceStream,
    required this.paymentsStream,
    required this.adjustmentsTotalStream,
    required this.destAccount,
    required this.onViewInitialIncome,
  });

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      padding: const EdgeInsets.all(kSpaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Saldo pendiente',
            style: TextStyle(color: FincoreColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: kSpaceXs),
          StreamBuilder<int>(
            stream: balanceStream,
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Skeleton(width: 160, height: 32);
              }
              return Text(
                formatCents(snap.data!),
                style: displayL,
              );
            },
          ),
          const SizedBox(height: kSpaceXs),
          Text(
            'de ${formatCents(loan.principalAmount)} originales',
            style: const TextStyle(
                color: FincoreColors.textSubtle, fontSize: 12),
          ),
          // Sprint flutter-loans-flexible-payments-v1: cuando hay ajustes, el
          // saldo deja de ser explicable sólo con "prestado − pagado". La
          // línea existe para que quede claro que el monto original no se
          // tocó y la diferencia viene de ajustes manuales.
          StreamBuilder<int>(
            stream: adjustmentsTotalStream,
            builder: (context, snap) {
              final total = snap.data ?? 0;
              if (total == 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: kSpace2xs),
                child: Text(
                  'incluye ${formatCents(total, showSign: true)} de ajustes',
                  style: TextStyle(
                    color: total > 0
                        ? FincoreColors.negative
                        : FincoreColors.positive,
                    fontSize: 12,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: kSpaceLg),
          StreamBuilder<List<JournalEntry>>(
            stream: paymentsStream,
            builder: (context, snap) {
              final payments = snap.data ?? const [];
              final paidPrincipal = payments.fold<int>(
                  0, (sum, p) => sum + (p.principalAmount ?? 0));
              final paidInterest = payments.fold<int>(
                  0, (sum, p) => sum + (p.interestAmount ?? 0));
              return Row(
                children: [
                  Expanded(
                    child: _AcumMetric(
                      // F-DES-2+3: capital=categoryBlue, interés=categoryOrange
                      // como par de taxonomía consistente con el drill-down
                      // en reports. accent queda reservado para affordance
                      // (FAB, links) y warning para alertas reales (chip
                      // "cerrado manualmente", chip "próximo pago").
                      color: FincoreColors.categoryBlue,
                      label: 'Capital pagado',
                      value: formatCents(paidPrincipal),
                    ),
                  ),
                  const SizedBox(width: kSpaceSm),
                  Expanded(
                    child: _AcumMetric(
                      color: FincoreColors.categoryOrange,
                      label: 'Intereses pagados',
                      value: formatCents(paidInterest),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: kSpaceLg),
          // Hotfix smoke Diego: label del chip meses ahora refleja el
          // avance real: "N pagos del mes / M meses previstos" — usando
          // el conteo real de loan_payments con interés > 0 en la vida
          // del préstamo, contra el `currentDurationMonths` del contrato.
          // El `initialDurationMonths` se omite del chip (queda en el
          // form de edición para trazabilidad).
          _MonthsChipStream(loanId: loan.id, total: loan.currentDurationMonths),
          const SizedBox(height: kSpaceSm),
          Wrap(
            spacing: kSpaceSm,
            runSpacing: kSpaceSm,
            children: [
              _Chip(
                icon: Icons.payments_outlined,
                label: 'Pago ${formatCents(loan.monthlyPayment)}',
              ),
              _Chip(
                icon: Icons.calendar_today_outlined,
                label: 'Día ${loan.paymentDay}',
              ),
            ],
          ),
          const SizedBox(height: kSpaceLg),
          // F-DES-10: minHeight 44dp (mismo patrón que _ChipShell del
          // dashboard). Antes ~32dp; touch fallaba en mano en movimiento.
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: InkWell(
              onTap: onViewInitialIncome,
              borderRadius: BorderRadius.circular(kRadiusMd),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: kSpaceSm),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long_outlined,
                        size: 16, color: FincoreColors.accent),
                    const SizedBox(width: kSpaceSm),
                    // Sprint flutter-loans-flexible-payments-v1: el texto era
                    // un `Text` suelto y desbordaba el Row en anchos de
                    // teléfono reales (~360dp) cuando el nombre de la cuenta
                    // destino es largo. Lo tapaba el viewport de 800dp que
                    // usan los widget tests por defecto.
                    Expanded(
                      child: Text(
                        destAccount != null
                            ? 'Ver ingreso inicial en ${destAccount!.name}'
                            : 'Ver ingreso inicial',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: FincoreColors.accent,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AcumMetric extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  const _AcumMetric({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: kSpaceMd, vertical: kSpaceSm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: FincoreColors.alphaTint),
        borderRadius: BorderRadius.circular(kRadiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: kSpace2xs),
          Text(
            value,
            style: const TextStyle(
              color: FincoreColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip de "X / Y meses pagados" reactivo. Consulta el conteo de
/// loan_payments con interest > 0 del préstamo y lo divide por la
/// duración actual del contrato.
class _MonthsChipStream extends StatelessWidget {
  final String loanId;
  final int total;
  const _MonthsChipStream({required this.loanId, required this.total});

  @override
  Widget build(BuildContext context) {
    final deps = AppDependencies.of(context);
    return StreamBuilder<int>(
      stream: deps.loansDao.watchCountMonthlyPayments(loanId),
      builder: (context, snap) {
        final paid = snap.data ?? 0;
        return _Chip(
          icon: Icons.timelapse_outlined,
          label: '$paid / $total meses pagados',
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Chip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: kSpaceMd, vertical: kSpaceSm),
      decoration: BoxDecoration(
        color: FincoreColors.surfaceElevated,
        borderRadius: BorderRadius.circular(kRadiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: FincoreColors.textSubtle),
          const SizedBox(width: kSpaceXs),
          Text(
            label,
            style: const TextStyle(
                color: FincoreColors.textPrimary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _StateChipRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _StateChipRow({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: kSpaceLg, vertical: kSpaceMd),
      decoration: BoxDecoration(
        color: color.withValues(alpha: FincoreColors.alphaTint),
        borderRadius: BorderRadius.circular(kRadiusMd),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: kSpaceMd),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                  color: FincoreColors.textPrimary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// Row de pago con split visualmente destacado. Hotfix smoke Diego: antes
/// el split se mostraba como texto plano gris "Capital $X · Intereses $Y".
/// Ahora son dos pill-badges de color contra fondo tint — más rápido de
/// leer y coherentes con los acumulados del header y con el slider del
/// payment form (mismos colores: accent capital / warning intereses).
/// Fila de un ajuste de saldo (sprint flutter-loans-flexible-payments-v1).
///
/// El color sigue el EFECTO sobre el usuario, no el signo aritmético: un
/// ajuste positivo sube la deuda, así que se pinta en rojo aunque el número
/// lleve `+`. Es consistente con la semántica de color declarada en
/// CLAUDE.md, donde `negative` significa "peor para tu bolsillo".
class _AdjustmentRow extends StatelessWidget {
  final LoanAdjustment adjustment;
  final String loanId;
  final VoidCallback onDeleteRequested;
  const _AdjustmentRow({
    required this.adjustment,
    required this.loanId,
    required this.onDeleteRequested,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat("d MMM y", "es_MX");
    final raisesDebt = adjustment.amount > 0;
    final color =
        raisesDebt ? FincoreColors.negative : FincoreColors.positive;
    return BaseCard(
      onTap: () => context
          .push('/loans/$loanId/adjustments/${adjustment.id}/edit'),
      padding: const EdgeInsets.symmetric(
          horizontal: kSpaceMd, vertical: kSpaceMd),
      child: Row(
        children: [
          Icon(Icons.tune_outlined, size: 18, color: color),
          const SizedBox(width: kSpaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fmt.format(adjustment.occurredAt),
                  style: const TextStyle(
                    color: FincoreColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: kSpace2xs),
                Text(
                  adjustment.reason?.isNotEmpty == true
                      ? adjustment.reason!
                      : (raisesDebt
                          ? 'Aumento de saldo'
                          : 'Disminución de saldo'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: FincoreColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: kSpaceSm),
          Text(
            formatCents(adjustment.amount, showSign: true),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                size: 18, color: FincoreColors.textMuted),
            tooltip: 'Eliminar ajuste',
            onPressed: onDeleteRequested,
          ),
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  final JournalEntry payment;
  final String loanId;
  final bool readOnly;
  final VoidCallback onDeleteRequested;
  const _PaymentRow({
    required this.payment,
    required this.loanId,
    required this.readOnly,
    required this.onDeleteRequested,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat("d MMM y", "es_MX");
    final principal = payment.principalAmount ?? 0;
    final interest = payment.interestAmount ?? 0;
    // Hotfix smoke Diego v2: usar la columna `isMonthlyPayment` persistida
    // en vez del proxy `interest > 0`. Un pago del mes puede legítimamente
    // tener interés = 0 (mes de gracia) y sigue siendo del mes.
    final isMonthly = payment.isMonthlyPayment;
    // F-DES-9: en read-only usamos colores explícitos (textSubtle/muted)
    // en vez de `Opacity(0.6)` global. La opacidad atenuaba texto+fondo
    // por igual y bajaba el contraste efectivo de forma no controlada —
    // mal para datos contables históricos que el usuario quiere seguir
    // leyendo con precisión. Ahora el ícono lock + los colores muted
    // comunican "solo lectura" sin dilucionar la legibilidad del monto.
    final textPrimary = readOnly
        ? FincoreColors.textMuted
        : FincoreColors.textPrimary;
    final textSecondary = readOnly
        ? FincoreColors.textSubtle
        : FincoreColors.textPrimary;
    return BaseCard(
      onTap: readOnly
          ? null
          : () {
              final variant = isMonthly ? 'monthly' : 'capital';
              context.push(
                  '/loans/$loanId/payments/${payment.id}/edit/$variant');
            },
      padding: const EdgeInsets.symmetric(
          horizontal: kSpaceMd, vertical: kSpaceMd),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (readOnly) ...[
                      const Icon(Icons.lock_outline,
                          size: 12, color: FincoreColors.textMuted),
                      const SizedBox(width: kSpaceXs),
                    ],
                    // Flexible + ellipsis: con `Spacer` y dos `Text` rígidos,
                    // la fila desbordaba ~30px en anchos de teléfono reales
                    // cuando la fecha y el monto son largos.
                    Flexible(
                      child: Text(
                        fmt.format(payment.occurredAt),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      formatCents(payment.amount),
                      style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: kSpaceSm),
                Wrap(
                  spacing: kSpaceSm,
                  runSpacing: kSpaceXs,
                  children: [
                    // Badge del tipo real (persistido en BD).
                    _TypeBadge(isMonthly: isMonthly),
                    _SplitPill(
                      // F-DES-3: par capital/interés unificado a categoryX.
                      color: FincoreColors.categoryBlue,
                      label: 'Capital',
                      value: formatCents(principal),
                    ),
                    // Pill de intereses siempre visible en pagos del mes
                    // (incluso $0 si es mes de gracia). En abonos capital
                    // se omite (por definición no llevan intereses).
                    if (isMonthly)
                      _SplitPill(
                        color: FincoreColors.categoryOrange,
                        label: 'Intereses',
                        value: formatCents(interest),
                      ),
                  ],
                ),
                if (payment.description != null &&
                    payment.description!.isNotEmpty) ...[
                  const SizedBox(height: kSpaceXs),
                  Text(
                    payment.description!,
                    style: const TextStyle(
                        color: FincoreColors.textSubtle, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          if (!readOnly)
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: FincoreColors.negative, size: 20),
              onPressed: onDeleteRequested,
            ),
        ],
      ),
    );
  }
}

/// Badge que identifica el tipo del pago (Pago del mes / Abono a capital)
/// leyendo la columna persistida `is_monthly_payment` — no depende del
/// proxy `interest > 0`, que falla cuando el pago del mes es sin intereses.
class _TypeBadge extends StatelessWidget {
  final bool isMonthly;
  const _TypeBadge({required this.isMonthly});

  @override
  Widget build(BuildContext context) {
    // F-DES-2: badge de taxonomía; categoryOrange en vez de warning para
    // no competir con las alertas reales (chip próximo pago / atrasado).
    final color = isMonthly
        ? FincoreColors.categoryOrange
        : FincoreColors.textSubtle;
    final label = isMonthly ? 'Pago del mes' : 'Abono a capital';
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: kSpaceSm, vertical: kSpace2xs),
      decoration: BoxDecoration(
        color: color.withValues(
            alpha: isMonthly
                ? FincoreColors.alphaTint
                : FincoreColors.alphaHover),
        borderRadius: BorderRadius.circular(kRadiusSm),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SplitPill extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  const _SplitPill({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: kSpaceSm, vertical: kSpace2xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: FincoreColors.alphaTint),
        borderRadius: BorderRadius.circular(kRadiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: kSpaceXs),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: kSpace2xs + 1),
          Text(
            value,
            style: const TextStyle(
              color: FincoreColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// F-DES-1: FAB dividido apilado verticalmente (mini "Abono a capital"
/// arriba + extended "Pago del mes" abajo). Antes eran dos extended en
/// fila que sumaban ~360dp de ancho y se salían del borde en teléfonos
/// de 360dp lógicos (gama media MX, muy común). La disposición vertical
/// funciona en cualquier ancho sin `MediaQuery` condicional y refuerza
/// que "Pago del mes" es la acción primaria (más cerca del pulgar).
class _PaymentFabRow extends StatelessWidget {
  final String loanId;
  const _PaymentFabRow({required this.loanId});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FloatingActionButton.small(
          heroTag: 'loan-capital',
          onPressed: () =>
              context.push('/loans/$loanId/payments/new/capital'),
          backgroundColor: FincoreColors.surfaceElevated,
          foregroundColor: FincoreColors.accent,
          tooltip: 'Abono a capital',
          child: const Icon(Icons.savings_outlined),
        ),
        const SizedBox(height: kSpaceMd),
        FloatingActionButton.extended(
          heroTag: 'loan-monthly',
          onPressed: () =>
              context.push('/loans/$loanId/payments/new/monthly'),
          backgroundColor: FincoreColors.accent,
          foregroundColor: FincoreColors.canvas,
          icon: const Icon(Icons.payments_outlined),
          label: const Text('Pago del mes'),
        ),
      ],
    );
  }
}

extension _FirstWhereOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}

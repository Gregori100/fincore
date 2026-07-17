import 'package:fincore/app_dependencies.dart';
import 'package:fincore/data/daos/entries_dao.dart';
import 'package:fincore/data/daos/loans_dao.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/theme/fincore_radii.dart';
import 'package:fincore/theme/fincore_spacing.dart';
import 'package:fincore/theme/fincore_typography.dart';
import 'package:fincore/widgets/amount_formatter.dart';
import 'package:fincore/widgets/base_card.dart';
import 'package:fincore/widgets/confirm_dialog.dart';
import 'package:fincore/widgets/destructive_dialog.dart';
import 'package:fincore/widgets/error_snackbar.dart';
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
  Stream<double>? _balanceStream;
  Stream<List<JournalEntry>>? _paymentsStream;
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
    // Hotfix smoke Diego v3: si el pago es "Pago del mes" y hay abonos a
    // capital del mismo mes, advertir con `DestructiveDialog` explicando
    // la cascada. Sin monthly, los abonos del mismo mes quedan huérfanos
    // rompiendo el invariante capital_before_monthly.
    if (payment.isMonthlyPayment) {
      final capitalCount =
          await deps.entriesDao.countCapitalPaymentsInSameMonth(payment.id);
      if (!mounted) return;
      if (capitalCount > 0) {
        final impacts = <DestructiveImpact>[
          DestructiveImpact(
            icon: Icons.savings_outlined,
            label:
                '$capitalCount ${capitalCount == 1 ? "abono" : "abonos"} a capital '
                '${capitalCount == 1 ? "se cancelará" : "se cancelarán"} en cascada',
          ),
          const DestructiveImpact(
            icon: Icons.info_outline,
            label: 'Los abonos requieren un pago del mes previo',
          ),
        ];
        final confirmed = await showDestructiveDialog(
          context,
          title: 'Eliminar pago del mes',
          objectName:
              DateFormat("MMMM 'de' y", "es_MX").format(payment.occurredAt),
          icon: Icons.delete_forever_outlined,
          impacts: impacts,
          description:
              'Al eliminar el pago del mes se cancelan también los abonos a '
              'capital de ese mismo mes calendario. Esta acción no se puede '
              'deshacer.',
          confirmLabel: 'Eliminar todo',
        );
        if (!confirmed || !mounted) return;
        try {
          await deps.entriesDao
              .deleteLoanPayment(payment.id, cascadeCapitalInMonth: true);
          if (mounted) {
            showSuccessSnackbar(context,
                'Pago del mes y $capitalCount abono(s) capital eliminados.');
          }
        } on EntriesDaoError catch (e) {
          if (mounted) showErrorSnackbar(context, e);
        } catch (e) {
          // Hotfix smoke Diego v4: atrapar cualquier excepción no tipada
          // para evitar el fallo silencioso ("cerró el modal y no pasó
          // nada"). Cualquier error del DAO llega a Diego como snackbar.
          if (mounted) showErrorSnackbar(context, e);
        }
        return;
      }
    }
    // Sin cascada: confirmDialog normal.
    final ok = await showConfirmDialog(
      context,
      title: 'Eliminar pago',
      message:
          'Eliminar el pago del ${DateFormat("d MMM y", "es_MX").format(payment.occurredAt)} '
          'por ${formatAmount(payment.amount)}. Si el préstamo estaba pagado se reabrirá '
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

  Future<void> _confirmCloseManual(Loan loan) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Cerrar préstamo manualmente',
      message:
          'Marca "${loan.name}" como cerrado. Úsalo si el banco te lo condonó, '
          'si es un registro de prueba o si ya no vas a llevar más su seguimiento. '
          'Puedes reabrirlo cuando quieras.',
      confirmLabel: 'Cerrar préstamo',
      destructive: false,
    );
    if (!ok || !mounted) return;
    try {
      await AppDependencies.of(context)
          .loansDao
          .closeManual(widget.loanId);
      if (mounted) showSuccessSnackbar(context, 'Préstamo cerrado.');
    } on LoansDaoError catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    }
  }

  Future<void> _confirmReopen(Loan loan) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Reabrir préstamo',
      message:
          '"${loan.name}" vuelve a estar activo y acepta nuevos pagos.',
      confirmLabel: 'Reabrir',
      destructive: false,
    );
    if (!ok || !mounted) return;
    try {
      await AppDependencies.of(context).loansDao.reopen(widget.loanId);
      if (mounted) showSuccessSnackbar(context, 'Préstamo reabierto.');
    } on LoansDaoError catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    }
  }

  Future<void> _confirmDelete(Loan loan) async {
    final deps = AppDependencies.of(context);
    final int payments;
    try {
      payments =
          await deps.loansDao.countActivePayments(widget.loanId);
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
      return;
    }
    if (!mounted) return;
    final destAccount = _accounts.firstWhere(
      (a) => a.id == loan.destinationAccountId,
      orElse: () => _accounts.first,
    );
    final impacts = <DestructiveImpact>[
      DestructiveImpact(
        icon: Icons.receipt_long_outlined,
        label: payments == 0
            ? 'Sin pagos registrados'
            : '$payments ${payments == 1 ? "pago" : "pagos"} '
                '${payments == 1 ? "se cancelará" : "se cancelarán"}',
      ),
      DestructiveImpact(
        icon: Icons.account_balance_wallet_outlined,
        label:
            'El ingreso inicial de ${loan.principalAmount.toStringAsFixed(0)} '
            'en ${destAccount.name} se cancela',
      ),
      const DestructiveImpact(
        icon: Icons.history_toggle_off,
        label: 'No se puede deshacer',
      ),
    ];
    final confirmed = await showDestructiveDialog(
      context,
      title: 'Eliminar préstamo',
      objectName: loan.name,
      icon: Icons.delete_forever_outlined,
      impacts: impacts,
      description:
          'Se borran el contrato, el ingreso inicial y todos los pagos registrados. '
          'El balance de la cuenta destino se ajusta.',
      confirmLabel: 'Eliminar préstamo',
    );
    if (!confirmed || !mounted) return;
    try {
      await deps.loansDao.deleteLoan(widget.loanId);
      if (mounted) {
        showSuccessSnackbar(context, 'Préstamo eliminado.');
        // Hotfix smoke Diego v3: nav a /dashboard (raíz) para evitar el
        // bug de "back sale de la app" que ocurría al dejar /loans como
        // única entrada del stack tras eliminar.
        context.go('/dashboard');
      }
    } on LoansDaoError catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    }
  }

  List<PopupMenuEntry<_LoanDetailAction>> _buildMenuItems(Loan loan) {
    final isPaid = loan.closeReason == 'paid';
    final isClosed = loan.closedAt != null;
    if (isPaid) {
      return const [
        PopupMenuItem(
          value: _LoanDetailAction.delete,
          child: ListTile(
            leading:
                Icon(Icons.delete_outline, color: FincoreColors.negative),
            title: Text('Eliminar',
                style: TextStyle(color: FincoreColors.negative)),
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ),
      ];
    }
    if (isClosed) {
      // manual
      return const [
        PopupMenuItem(
          value: _LoanDetailAction.edit,
          child: ListTile(
            leading: Icon(Icons.edit_outlined,
                color: FincoreColors.textPrimary),
            title: Text('Editar contrato'),
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ),
        PopupMenuItem(
          value: _LoanDetailAction.reopen,
          child: ListTile(
            leading:
                Icon(Icons.lock_open_outlined, color: FincoreColors.accent),
            title: Text('Reabrir'),
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: _LoanDetailAction.delete,
          child: ListTile(
            leading:
                Icon(Icons.delete_outline, color: FincoreColors.negative),
            title: Text('Eliminar',
                style: TextStyle(color: FincoreColors.negative)),
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ),
      ];
    }
    // Activo.
    return const [
      PopupMenuItem(
        value: _LoanDetailAction.edit,
        child: ListTile(
          leading:
              Icon(Icons.edit_outlined, color: FincoreColors.textPrimary),
          title: Text('Editar contrato'),
          contentPadding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
      ),
      PopupMenuItem(
        value: _LoanDetailAction.closeManual,
        child: ListTile(
          leading:
              Icon(Icons.lock_outline, color: FincoreColors.textPrimary),
          title: Text('Cerrar manualmente'),
          contentPadding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
      ),
      PopupMenuDivider(),
      PopupMenuItem(
        value: _LoanDetailAction.delete,
        child: ListTile(
          leading:
              Icon(Icons.delete_outline, color: FincoreColors.negative),
          title: Text('Eliminar',
              style: TextStyle(color: FincoreColors.negative)),
          contentPadding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
      ),
    ];
  }

  void _handleMenuAction(_LoanDetailAction action, Loan loan) {
    switch (action) {
      case _LoanDetailAction.edit:
        context.push('/loans/${widget.loanId}/edit');
        return;
      case _LoanDetailAction.closeManual:
        _confirmCloseManual(loan);
        return;
      case _LoanDetailAction.reopen:
        _confirmReopen(loan);
        return;
      case _LoanDetailAction.delete:
        _confirmDelete(loan);
        return;
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
        final loan = snap.data;
        if (loan == null) {
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
              PopupMenuButton<_LoanDetailAction>(
                icon: const Icon(Icons.more_vert),
                color: FincoreColors.surfaceElevated,
                onSelected: (a) => _handleMenuAction(a, loan),
                itemBuilder: (_) => _buildMenuItems(loan),
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
                    color: FincoreColors.warning,
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
              ],
            ),
          ),
        );
      },
    );
  }
}

enum _LoanDetailAction { edit, closeManual, reopen, delete }

class _Header extends StatelessWidget {
  final Loan loan;
  final Stream<double> balanceStream;
  final Stream<List<JournalEntry>> paymentsStream;
  final Account? destAccount;
  final VoidCallback onViewInitialIncome;
  const _Header({
    required this.loan,
    required this.balanceStream,
    required this.paymentsStream,
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
          StreamBuilder<double>(
            stream: balanceStream,
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Skeleton(width: 160, height: 32);
              }
              return Text(
                formatAmount(snap.data!),
                style: displayXL.copyWith(fontSize: 32),
              );
            },
          ),
          const SizedBox(height: kSpaceXs),
          Text(
            'de ${formatAmount(loan.principalAmount)} originales',
            style: const TextStyle(
                color: FincoreColors.textSubtle, fontSize: 12),
          ),
          const SizedBox(height: kSpaceLg),
          StreamBuilder<List<JournalEntry>>(
            stream: paymentsStream,
            builder: (context, snap) {
              final payments = snap.data ?? const [];
              final paidPrincipal = payments.fold<double>(
                  0, (sum, p) => sum + (p.principalAmount ?? 0));
              final paidInterest = payments.fold<double>(
                  0, (sum, p) => sum + (p.interestAmount ?? 0));
              return Row(
                children: [
                  Expanded(
                    child: _AcumMetric(
                      color: FincoreColors.accent,
                      label: 'Capital pagado',
                      value: formatAmount(paidPrincipal),
                    ),
                  ),
                  const SizedBox(width: kSpaceSm),
                  Expanded(
                    child: _AcumMetric(
                      color: FincoreColors.warning,
                      label: 'Intereses pagados',
                      value: formatAmount(paidInterest),
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
                label: 'Pago ${formatAmount(loan.monthlyPayment)}',
              ),
              _Chip(
                icon: Icons.calendar_today_outlined,
                label: 'Día ${loan.paymentDay}',
              ),
            ],
          ),
          const SizedBox(height: kSpaceLg),
          InkWell(
            onTap: onViewInitialIncome,
            borderRadius: BorderRadius.circular(kRadiusMd),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: kSpaceSm),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long_outlined,
                      size: 16, color: FincoreColors.accent),
                  const SizedBox(width: kSpaceSm),
                  Text(
                    destAccount != null
                        ? 'Ver ingreso inicial en ${destAccount!.name}'
                        : 'Ver ingreso inicial',
                    style: const TextStyle(
                      color: FincoreColors.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
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
    return BaseCard(
      // Tap abre el form de edición correspondiente al tipo real —
      // salvo en préstamos cerrados (read-only).
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
                    Text(
                      fmt.format(payment.occurredAt),
                      style: const TextStyle(
                        color: FincoreColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      formatAmount(payment.amount),
                      style: const TextStyle(
                        color: FincoreColors.textPrimary,
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
                      color: FincoreColors.accent,
                      label: 'Capital',
                      value: formatAmount(principal),
                    ),
                    // Pill de intereses siempre visible en pagos del mes
                    // (incluso $0 si es mes de gracia). En abonos capital
                    // se omite (por definición no llevan intereses).
                    if (isMonthly)
                      _SplitPill(
                        color: FincoreColors.warning,
                        label: 'Intereses',
                        value: formatAmount(interest),
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
    final color =
        isMonthly ? FincoreColors.warning : FincoreColors.textSubtle;
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

class _PaymentFabRow extends StatelessWidget {
  final String loanId;
  const _PaymentFabRow({required this.loanId});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FloatingActionButton.extended(
          heroTag: 'loan-capital',
          onPressed: () =>
              context.push('/loans/$loanId/payments/new/capital'),
          backgroundColor: FincoreColors.surfaceElevated,
          foregroundColor: FincoreColors.accent,
          icon: const Icon(Icons.savings_outlined),
          label: const Text('Abono a capital'),
        ),
        const SizedBox(width: kSpaceMd),
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

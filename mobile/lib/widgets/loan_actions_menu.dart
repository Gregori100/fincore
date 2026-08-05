import 'package:fincore/app_dependencies.dart';
import 'package:fincore/data/daos/loans_dao.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/utils/money.dart';
import 'package:fincore/widgets/confirm_dialog.dart';
import 'package:fincore/widgets/destructive_dialog.dart';
import 'package:fincore/widgets/error_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Hotfix quality-review M3: menú de acciones sobre un préstamo (Cerrar
/// manual / Reabrir / Eliminar). Reemplaza ~200 líneas duplicadas entre
/// `loan_form_screen.dart` y `loan_detail_screen.dart`. El widget decide
/// los items según el estado del préstamo (activo, paid, cerrado manual).
///
/// Post-delete navega a `/dashboard` (reset de stack) — fix del bug donde
/// quedar en `/loans` hacía que el back del cel saliera de la app.
class LoanActionsMenu extends StatefulWidget {
  final Loan loan;
  final List<Account> accounts;

  /// Callback opcional que abre la pantalla de edición del contrato. Cuando
  /// se pasa, el menú incluye "Editar contrato" (usado desde el detalle;
  /// el propio form no lo necesita porque YA es esa pantalla).
  final VoidCallback? onEdit;

  const LoanActionsMenu({
    super.key,
    required this.loan,
    required this.accounts,
    this.onEdit,
  });

  @override
  State<LoanActionsMenu> createState() => _LoanActionsMenuState();
}

class _LoanActionsMenuState extends State<LoanActionsMenu> {
  bool _busy = false;

  bool get _isPaid => widget.loan.closeReason == 'paid';
  bool get _isClosed => widget.loan.closedAt != null;

  Future<void> _closeManual() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Cerrar préstamo manualmente',
      message:
          'Marca "${widget.loan.name}" como cerrado. Úsalo si el banco te lo condonó, '
          'si es un registro de prueba o si ya no vas a llevar más su seguimiento. '
          'Puedes reabrirlo cuando quieras.',
      confirmLabel: 'Cerrar préstamo',
      destructive: false,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await AppDependencies.of(context).loansDao.closeManual(widget.loan.id);
      if (mounted) showSuccessSnackbar(context, 'Préstamo cerrado.');
    } on LoansDaoError catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reopen() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Reabrir préstamo',
      message:
          '"${widget.loan.name}" vuelve a estar activo y acepta nuevos pagos.',
      confirmLabel: 'Reabrir',
      destructive: false,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await AppDependencies.of(context).loansDao.reopen(widget.loan.id);
      if (mounted) showSuccessSnackbar(context, 'Préstamo reabierto.');
    } on LoansDaoError catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final deps = AppDependencies.of(context);
    setState(() => _busy = true);
    final int payments;
    final int adjustments;
    try {
      payments = await deps.loansDao.countActivePayments(widget.loan.id);
      adjustments =
          await deps.loansDao.countActiveAdjustments(widget.loan.id);
    } catch (e) {
      if (mounted) {
        showErrorSnackbar(context, e);
        setState(() => _busy = false);
      }
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);

    final destAccount = widget.accounts.firstWhere(
      (a) => a.id == widget.loan.destinationAccountId,
      orElse: () => widget.accounts.first,
    );
    // Hotfix quality-review M7: formatCents() en vez de toStringAsFixed(0),
    // que pintaba "150000" sin identidad de moneda ni miles justo en el
    // dialog más crítico del flujo.
    final impacts = <DestructiveImpact>[
      DestructiveImpact(
        icon: Icons.receipt_long_outlined,
        label: payments == 0
            ? 'Sin pagos registrados'
            : '$payments ${payments == 1 ? "pago" : "pagos"} '
                '${payments == 1 ? "se cancelará" : "se cancelarán"}',
      ),
      // Hallazgo M2 de la revisión de rama: los ajustes también se cancelan
      // en cascada desde la corrección de B1, así que el diálogo debe
      // declararlo. Se omite la línea cuando no hay ajustes para no añadir
      // ruido al caso común.
      if (adjustments > 0)
        DestructiveImpact(
          icon: Icons.tune_outlined,
          label: '$adjustments ${adjustments == 1 ? "ajuste" : "ajustes"} '
              'de saldo ${adjustments == 1 ? "se cancelará" : "se cancelarán"}',
        ),
      DestructiveImpact(
        icon: Icons.account_balance_wallet_outlined,
        label:
            'El ingreso inicial de ${formatCents(widget.loan.principalAmount)} '
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
      objectName: widget.loan.name,
      icon: Icons.delete_forever_outlined,
      impacts: impacts,
      description:
          'Se borran el contrato, el ingreso inicial y todos los pagos registrados. '
          'El balance de la cuenta destino se ajusta.',
      confirmLabel: 'Eliminar préstamo',
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await deps.loansDao.deleteLoan(widget.loan.id);
      if (mounted) {
        showSuccessSnackbar(context, 'Préstamo eliminado.');
        // Reset a raíz — antes quedaba /loans como única entrada del stack
        // y el back nativo del cel salía de la app.
        context.go('/dashboard');
      }
    } on LoansDaoError catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_LoanAction>(
      icon: _busy
          ? const SizedBox(
              width: 24,
              height: 24,
              child: Padding(
                padding: EdgeInsets.all(4),
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: FincoreColors.textMuted),
              ),
            )
          : const Icon(Icons.more_vert),
      color: FincoreColors.surfaceElevated,
      enabled: !_busy,
      onSelected: (a) {
        switch (a) {
          case _LoanAction.edit:
            widget.onEdit?.call();
            return;
          case _LoanAction.closeManual:
            _closeManual();
            return;
          case _LoanAction.reopen:
            _reopen();
            return;
          case _LoanAction.delete:
            _delete();
            return;
        }
      },
      itemBuilder: (_) {
        final items = <PopupMenuEntry<_LoanAction>>[];
        if (_isPaid) {
          items.add(_deleteItem);
          return items;
        }
        if (_isClosed) {
          if (widget.onEdit != null) items.add(_editItem);
          items.add(_reopenItem);
          items.add(const PopupMenuDivider());
          items.add(_deleteItem);
          return items;
        }
        // Activo.
        if (widget.onEdit != null) items.add(_editItem);
        items.add(_closeManualItem);
        items.add(const PopupMenuDivider());
        items.add(_deleteItem);
        return items;
      },
    );
  }

  static const _editItem = PopupMenuItem(
    value: _LoanAction.edit,
    child: ListTile(
      leading: Icon(Icons.edit_outlined, color: FincoreColors.textPrimary),
      title: Text('Editar contrato'),
      contentPadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    ),
  );

  static const _closeManualItem = PopupMenuItem(
    value: _LoanAction.closeManual,
    child: ListTile(
      leading: Icon(Icons.lock_outline, color: FincoreColors.textPrimary),
      title: Text('Cerrar manualmente'),
      contentPadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    ),
  );

  static const _reopenItem = PopupMenuItem(
    value: _LoanAction.reopen,
    child: ListTile(
      leading: Icon(Icons.lock_open_outlined, color: FincoreColors.accent),
      title: Text('Reabrir'),
      contentPadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    ),
  );

  static const _deleteItem = PopupMenuItem(
    value: _LoanAction.delete,
    child: ListTile(
      leading: Icon(Icons.delete_outline, color: FincoreColors.negative),
      title: Text('Eliminar',
          style: TextStyle(color: FincoreColors.negative)),
      contentPadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    ),
  );
}

enum _LoanAction { edit, closeManual, reopen, delete }

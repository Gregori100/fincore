import 'package:fincore/app_dependencies.dart';
import 'package:fincore/data/daos/loans_dao.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/theme/fincore_radii.dart';
import 'package:fincore/theme/fincore_spacing.dart';
import 'package:fincore/widgets/account_picker.dart';
import 'package:fincore/widgets/confirm_dialog.dart';
import 'package:fincore/widgets/destructive_dialog.dart';
import 'package:fincore/widgets/error_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class LoanFormScreen extends StatefulWidget {
  final String? loanId;
  const LoanFormScreen({super.key, this.loanId});

  @override
  State<LoanFormScreen> createState() => _LoanFormScreenState();
}

class _LoanFormScreenState extends State<LoanFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _principalCtrl = TextEditingController();
  final _monthlyCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  final _paymentDayCtrl = TextEditingController();

  DateTime _contractDate = DateTime.now();
  String? _destinationAccountId;
  List<Account> _accounts = const [];

  bool _loading = false;
  bool _saving = false;
  bool _loaded = false;
  Loan? _existing;

  bool get _isEdit => widget.loanId != null;
  bool get _isClosed => _existing?.closedAt != null;
  bool get _isPaid => _existing?.closeReason == 'paid';

  @override
  void initState() {
    super.initState();
    // Cargar en post-frame para tener acceso a InheritedWidget.
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _principalCtrl.dispose();
    _monthlyCtrl.dispose();
    _durationCtrl.dispose();
    _paymentDayCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (!mounted || _loaded) return;
    _loaded = true;
    setState(() => _loading = true);
    final deps = AppDependencies.of(context);
    try {
      _accounts = await deps.accountsDao.listAll();
      if (_isEdit) {
        final loan = await deps.loansDao.findById(widget.loanId!);
        if (loan == null) {
          throw const LoansDaoError('not_found', 'Préstamo no encontrado.');
        }
        _existing = loan;
        _nameCtrl.text = loan.name;
        _principalCtrl.text = loan.principalAmount.toStringAsFixed(2);
        _monthlyCtrl.text = loan.monthlyPayment.toStringAsFixed(2);
        _durationCtrl.text = loan.currentDurationMonths.toString();
        _paymentDayCtrl.text = loan.paymentDay.toString();
        _contractDate = loan.contractDate;
        _destinationAccountId = loan.destinationAccountId;
      }
    } on LoansDaoError catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double? _parseDecimal(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _contractDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _contractDate = picked);
    }
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    if (_destinationAccountId == null) {
      showErrorSnackbar(
          context, 'Selecciona la cuenta destino del préstamo.');
      return;
    }
    final deps = AppDependencies.of(context);
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await deps.loansDao.updateLoan(
          id: widget.loanId!,
          name: _nameCtrl.text.trim(),
          monthlyPayment: _parseDecimal(_monthlyCtrl.text),
          currentDurationMonths: int.tryParse(_durationCtrl.text),
          paymentDay: int.tryParse(_paymentDayCtrl.text),
          contractDate: _contractDate,
        );
      } else {
        await deps.loansDao.create(
          name: _nameCtrl.text.trim(),
          principalAmount: _parseDecimal(_principalCtrl.text) ?? 0,
          monthlyPayment: _parseDecimal(_monthlyCtrl.text) ?? 0,
          initialDurationMonths: int.tryParse(_durationCtrl.text) ?? 0,
          paymentDay: int.tryParse(_paymentDayCtrl.text) ?? 0,
          contractDate: _contractDate,
          destinationAccountId: _destinationAccountId!,
        );
      }
      if (mounted) {
        showSuccessSnackbar(context,
            _isEdit ? 'Préstamo actualizado.' : 'Préstamo creado.');
        Navigator.of(context).maybePop();
      }
    } on LoansDaoError catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmCloseManual() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Cerrar préstamo manualmente',
      message:
          'Marca "${_existing!.name}" como cerrado. Úsalo si el banco te lo condonó, '
          'si es un registro de prueba o si ya no vas a llevar más su seguimiento. '
          'Puedes reabrirlo cuando quieras.',
      confirmLabel: 'Cerrar préstamo',
      destructive: false,
    );
    if (!ok || !mounted) return;
    setState(() => _saving = true);
    try {
      await AppDependencies.of(context)
          .loansDao
          .closeManual(widget.loanId!);
      if (mounted) {
        showSuccessSnackbar(context, 'Préstamo cerrado.');
        Navigator.of(context).maybePop();
      }
    } on LoansDaoError catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmReopen() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Reabrir préstamo',
      message:
          '"${_existing!.name}" vuelve a estar activo y acepta nuevos pagos.',
      confirmLabel: 'Reabrir',
      destructive: false,
    );
    if (!ok || !mounted) return;
    setState(() => _saving = true);
    try {
      await AppDependencies.of(context).loansDao.reopen(widget.loanId!);
      if (mounted) {
        showSuccessSnackbar(context, 'Préstamo reabierto.');
        Navigator.of(context).maybePop();
      }
    } on LoansDaoError catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete() async {
    final deps = AppDependencies.of(context);
    setState(() => _saving = true);
    final int payments;
    try {
      payments = await deps.loansDao.countActivePayments(widget.loanId!);
    } catch (e) {
      if (mounted) {
        showErrorSnackbar(context, e);
        setState(() => _saving = false);
      }
      return;
    }
    if (!mounted) return;
    setState(() => _saving = false);

    final destAccount = _accounts.firstWhere(
      (a) => a.id == _existing!.destinationAccountId,
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
            'El ingreso inicial de ${_existing!.principalAmount.toStringAsFixed(0)} '
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
      objectName: _existing!.name,
      icon: Icons.delete_forever_outlined,
      impacts: impacts,
      description:
          'Se borran el contrato, el ingreso inicial y todos los pagos registrados. '
          'El balance de la cuenta destino se ajusta.',
      confirmLabel: 'Eliminar préstamo',
    );
    if (!confirmed || !mounted) return;
    setState(() => _saving = true);
    try {
      await deps.loansDao.deleteLoan(widget.loanId!);
      if (mounted) {
        showSuccessSnackbar(context, 'Préstamo eliminado.');
        // Hotfix smoke Diego v3: nav a /dashboard (raíz) — dejaba /loans
        // como única entrada del stack y el back del teléfono sacaba de
        // la app en vez de volver al dashboard.
        context.go('/dashboard');
      }
    } on LoansDaoError catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<PopupMenuEntry<_LoanFormAction>> _buildMenuItems() {
    if (_isPaid) {
      return const [
        PopupMenuItem(
          value: _LoanFormAction.delete,
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
    if (_isClosed) {
      // manual
      return const [
        PopupMenuItem(
          value: _LoanFormAction.reopen,
          child: ListTile(
            leading: Icon(Icons.lock_open_outlined,
                color: FincoreColors.accent),
            title: Text('Reabrir'),
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: _LoanFormAction.delete,
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
    return const [
      PopupMenuItem(
        value: _LoanFormAction.closeManual,
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
        value: _LoanFormAction.delete,
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

  void _handleMenuAction(_LoanFormAction action) {
    switch (action) {
      case _LoanFormAction.closeManual:
        _confirmCloseManual();
        return;
      case _LoanFormAction.reopen:
        _confirmReopen();
        return;
      case _LoanFormAction.delete:
        _confirmDelete();
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cargando...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit
            ? (_isPaid
                ? 'Préstamo pagado'
                : (_isClosed ? 'Préstamo cerrado' : 'Editar préstamo'))
            : 'Nuevo préstamo'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          if (_isEdit)
            PopupMenuButton<_LoanFormAction>(
              icon: const Icon(Icons.more_vert),
              color: FincoreColors.surfaceElevated,
              onSelected: _handleMenuAction,
              itemBuilder: (_) => _buildMenuItems(),
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(kSpaceLg),
            children: [
              if (_isPaid) ...[
                const _PaidBanner(),
                const SizedBox(height: kSpaceLg),
              ] else if (_isClosed) ...[
                const _ClosedManualBanner(),
                const SizedBox(height: kSpaceLg),
              ],
              TextFormField(
                controller: _nameCtrl,
                enabled: !_isClosed,
                decoration: const InputDecoration(
                  labelText: 'Nombre del préstamo',
                  helperText: 'Ej: BBVA Personal, Casa CDMX, Auto Nissan',
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Ingresa un nombre.'
                    : null,
              ),
              const SizedBox(height: kSpaceLg),
              TextFormField(
                controller: _principalCtrl,
                enabled: !_isEdit,
                decoration: InputDecoration(
                  labelText: 'Monto del préstamo (capital original)',
                  prefixText: r'$ ',
                  helperText: _isEdit
                      ? 'No editable · atado al ingreso inicial'
                      : ' ',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                validator: (v) {
                  if (_isEdit) return null;
                  if (v == null || v.trim().isEmpty) return 'Requerido.';
                  final n = _parseDecimal(v);
                  if (n == null || n <= 0) return 'Debe ser mayor a 0.';
                  return null;
                },
              ),
              const SizedBox(height: kSpaceLg),
              TextFormField(
                controller: _monthlyCtrl,
                enabled: !_isClosed,
                decoration: const InputDecoration(
                  labelText: 'Pago mensual (referencial)',
                  prefixText: r'$ ',
                  helperText: 'Puedes editarlo cuando el banco te lo cambie',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Requerido.';
                  final n = _parseDecimal(v);
                  if (n == null || n <= 0) return 'Debe ser mayor a 0.';
                  return null;
                },
              ),
              const SizedBox(height: kSpaceLg),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _durationCtrl,
                      enabled: !_isClosed,
                      decoration: InputDecoration(
                        labelText:
                            _isEdit ? 'Meses restantes' : 'Duración (meses)',
                        helperText: ' ',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Requerido.';
                        }
                        final n = int.tryParse(v);
                        if (n == null || n < 0) return 'No puede ser negativo.';
                        if (!_isEdit && n == 0) return 'Debe ser mayor a 0.';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: kSpaceMd),
                  Expanded(
                    child: TextFormField(
                      controller: _paymentDayCtrl,
                      enabled: !_isClosed,
                      decoration: const InputDecoration(
                        labelText: 'Día de pago',
                        helperText: '1 a 28',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Requerido.';
                        }
                        final n = int.tryParse(v);
                        if (n == null || n < 1 || n > 28) {
                          return 'Debe estar entre 1 y 28.';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: kSpaceLg),
              _DateField(
                label: 'Fecha del contrato',
                value: _contractDate,
                enabled: !_isClosed,
                onTap: _pickDate,
              ),
              const SizedBox(height: kSpaceLg),
              AbsorbPointer(
                absorbing: _isEdit,
                child: Opacity(
                  opacity: _isEdit ? 0.6 : 1.0,
                  child: AccountPicker(
                    label: _isEdit
                        ? 'Cuenta destino (no editable)'
                        : 'Cuenta destino del préstamo',
                    accounts: _accounts,
                    allowedTypes: const ['cash', 'debit'],
                    selectedId: _destinationAccountId,
                    onChanged: (v) =>
                        setState(() => _destinationAccountId = v),
                    includeArchived: _isEdit,
                  ),
                ),
              ),
              const SizedBox(height: kSpace2xl),
              if (!_isClosed)
                FilledButton(
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: FincoreColors.canvas),
                        )
                      : Text(_isEdit
                          ? 'Guardar cambios'
                          : 'Crear préstamo'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _LoanFormAction { closeManual, reopen, delete }

class _DateField extends StatelessWidget {
  final String label;
  final DateTime value;
  final bool enabled;
  final VoidCallback onTap;
  const _DateField({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM y', 'es_MX');
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(kRadiusMd),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          enabled: enabled,
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(
          fmt.format(value),
          style: TextStyle(
            color: enabled
                ? FincoreColors.textPrimary
                : FincoreColors.textSubtle,
          ),
        ),
      ),
    );
  }
}

class _PaidBanner extends StatelessWidget {
  const _PaidBanner();

  @override
  Widget build(BuildContext context) {
    return const _StatusBanner(
      color: FincoreColors.positive,
      icon: Icons.check_circle_outline,
      title: 'Préstamo pagado',
      body:
          'Este préstamo se cerró automáticamente al llegar el saldo a cero. '
          'Sólo se puede eliminar.',
    );
  }
}

class _ClosedManualBanner extends StatelessWidget {
  const _ClosedManualBanner();

  @override
  Widget build(BuildContext context) {
    return const _StatusBanner(
      color: FincoreColors.warning,
      icon: Icons.lock_outline,
      title: 'Préstamo cerrado manualmente',
      body:
          'Cerrado por acción tuya. Puedes reabrirlo desde el menú o eliminarlo definitivamente.',
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String body;
  const _StatusBanner({
    required this.color,
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: kSpaceLg, vertical: kSpaceMd),
      decoration: BoxDecoration(
        color: color.withValues(alpha: FincoreColors.alphaTint),
        borderRadius: BorderRadius.circular(kRadiusMd),
        border: Border.all(
          color: color.withValues(alpha: FincoreColors.alphaHairline),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: kSpaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: FincoreColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: kSpace2xs),
                Text(
                  body,
                  style: const TextStyle(
                    color: FincoreColors.textSubtle,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

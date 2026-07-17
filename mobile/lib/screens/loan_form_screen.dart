import 'package:fincore/app_dependencies.dart';
import 'package:fincore/data/daos/loans_dao.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/theme/fincore_radii.dart';
import 'package:fincore/theme/fincore_spacing.dart';
import 'package:fincore/widgets/account_picker.dart';
import 'package:fincore/widgets/error_snackbar.dart';
import 'package:fincore/widgets/loan_actions_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  // Hotfix quality-review B14: flag para señalar el picker como inválido
  // cuando el submit intenta correr sin destino seleccionado.
  bool _destinationInvalid = false;
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
    final formOk = _formKey.currentState!.validate();
    final destOk = _destinationAccountId != null;
    if (!destOk) {
      setState(() => _destinationInvalid = true);
    }
    if (!formOk || !destOk) {
      if (!destOk && formOk) {
        showErrorSnackbar(
            context, 'Selecciona la cuenta destino del préstamo.');
      }
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
            LoanActionsMenu(loan: _existing!, accounts: _accounts),
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
              const SizedBox(height: kSpaceXl),
              // F-DES-11: subtítulos overline entre grupos (mismo patrón que
              // account_form_screen). Identidad — Términos — Vínculo.
              const _FormGroupHeader(label: 'Términos del contrato'),
              const SizedBox(height: kSpaceMd),
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
              const SizedBox(height: kSpaceXl),
              const _FormGroupHeader(label: 'Vínculo financiero'),
              const SizedBox(height: kSpaceMd),
              AbsorbPointer(
                absorbing: _isEdit,
                child: Opacity(
                  opacity: _isEdit ? 0.6 : 1.0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AccountPicker(
                        label: _isEdit
                            ? 'Cuenta destino (no editable)'
                            : 'Cuenta destino del préstamo',
                        accounts: _accounts,
                        allowedTypes: const ['cash', 'debit'],
                        selectedId: _destinationAccountId,
                        onChanged: (v) => setState(() {
                          _destinationAccountId = v;
                          _destinationInvalid = false;
                        }),
                        includeArchived: _isEdit,
                      ),
                      // Hotfix quality-review B14: mensaje de error visible
                      // bajo el picker (patrón de TextFormField.validator)
                      // en vez de sólo un snackbar transitorio.
                      if (_destinationInvalid && !_isEdit)
                        const Padding(
                          padding: EdgeInsets.only(top: kSpaceXs, left: 12),
                          child: Text(
                            'Selecciona la cuenta destino del préstamo.',
                            style: TextStyle(
                              color: FincoreColors.negative,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
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
      // F-DES-2: estado del préstamo con categoryOrange (marca del módulo).
      color: FincoreColors.categoryOrange,
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

/// F-DES-11: subtítulo overline para agrupar campos del form. Sigue el
/// mismo patrón de `account_form_screen` (Divider + label uppercase +
/// letterSpacing). Los grupos actuales:
///  1. Identidad (nombre + monto original) — sin header, arranque del form.
///  2. Términos del contrato (pago mensual, duración, día pago, fecha).
///  3. Vínculo financiero (cuenta destino).
class _FormGroupHeader extends StatelessWidget {
  final String label;
  const _FormGroupHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(
          height: 1,
          color: FincoreColors.surfaceElevated,
        ),
        const SizedBox(height: kSpaceMd),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: FincoreColors.textSubtle,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

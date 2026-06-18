import 'package:fincore/app_dependencies.dart';
import 'package:fincore/constants/account_types.dart';
import 'package:fincore/data/daos/accounts_dao.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/widgets/account_type_picker.dart';
import 'package:fincore/widgets/confirm_dialog.dart';
import 'package:fincore/widgets/error_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AccountFormScreen extends StatefulWidget {
  final String? accountId;
  const AccountFormScreen({super.key, this.accountId});

  @override
  State<AccountFormScreen> createState() => _AccountFormScreenState();
}

class _AccountFormScreenState extends State<AccountFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _creditLimitCtrl = TextEditingController();
  final _closingDayCtrl = TextEditingController();
  final _paymentDayCtrl = TextEditingController();
  final _interestRateCtrl = TextEditingController();
  final _minPaymentPctCtrl = TextEditingController();

  AccountType _type = AccountType.debit;
  bool _saving = false;
  bool _loading = false;
  bool _loaded = false;
  Account? _existing;

  bool get _isEdit => widget.accountId != null;
  bool get _isProtected => _existing?.isProtected ?? false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    if (_isEdit) _loadAccount();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _creditLimitCtrl.dispose();
    _closingDayCtrl.dispose();
    _paymentDayCtrl.dispose();
    _interestRateCtrl.dispose();
    _minPaymentPctCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAccount() async {
    final deps = AppDependencies.of(context);
    setState(() => _loading = true);
    try {
      final account = await deps.accountsDao.findById(widget.accountId!);
      if (account == null) {
        throw const AccountsDaoError('not_found', 'Cuenta no encontrada.');
      }
      setState(() {
        _existing = account;
        _type = parseAccountType(account.type);
        _nameCtrl.text = account.name;
        _descCtrl.text = account.description ?? '';
        if (account.type == 'credit') {
          _creditLimitCtrl.text = account.creditLimit?.toString() ?? '';
          _closingDayCtrl.text = account.closingDay?.toString() ?? '';
          _paymentDayCtrl.text = account.paymentDay?.toString() ?? '';
          _interestRateCtrl.text = account.interestRate?.toString() ?? '';
          _minPaymentPctCtrl.text = account.minimumPaymentPct?.toString() ?? '';
        }
      });
    } on AccountsDaoError catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    final deps = AppDependencies.of(context);
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await deps.accountsDao.updateAccount(
          id: widget.accountId!,
          name: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          creditLimit: _type == AccountType.credit
              ? double.tryParse(_creditLimitCtrl.text)
              : null,
          closingDay: _type == AccountType.credit
              ? int.tryParse(_closingDayCtrl.text)
              : null,
          paymentDay: _type == AccountType.credit
              ? int.tryParse(_paymentDayCtrl.text)
              : null,
          interestRate: _type == AccountType.credit && _interestRateCtrl.text.isNotEmpty
              ? double.tryParse(_interestRateCtrl.text)
              : null,
          minimumPaymentPct: _type == AccountType.credit && _minPaymentPctCtrl.text.isNotEmpty
              ? double.tryParse(_minPaymentPctCtrl.text)
              : null,
        );
      } else {
        await deps.accountsDao.create(
          name: _nameCtrl.text.trim(),
          type: _type.apiValue,
          description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          creditLimit: _type == AccountType.credit
              ? double.tryParse(_creditLimitCtrl.text)
              : null,
          closingDay: _type == AccountType.credit
              ? int.tryParse(_closingDayCtrl.text)
              : null,
          paymentDay: _type == AccountType.credit
              ? int.tryParse(_paymentDayCtrl.text)
              : null,
          interestRate: _type == AccountType.credit && _interestRateCtrl.text.isNotEmpty
              ? double.tryParse(_interestRateCtrl.text)
              : null,
          minimumPaymentPct: _type == AccountType.credit && _minPaymentPctCtrl.text.isNotEmpty
              ? double.tryParse(_minPaymentPctCtrl.text)
              : null,
        );
      }
      if (mounted) {
        showSuccessSnackbar(context, _isEdit ? 'Cuenta actualizada.' : 'Cuenta creada.');
        Navigator.of(context).maybePop();
      }
    } on AccountsDaoError catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _archive() async {
    final deps = AppDependencies.of(context);
    // Conteo de movimientos asociados ANTES de mostrar la confirmación, para
    // que el usuario entienda exactamente qué se va a borrar en cascada.
    setState(() => _saving = true);
    final int affected;
    try {
      affected = await deps.accountsDao.countAssociatedEntries(widget.accountId!);
    } catch (e) {
      if (mounted) {
        showErrorSnackbar(context, e);
        setState(() => _saving = false);
      }
      return;
    }
    if (!mounted) return;
    setState(() => _saving = false);

    final message = affected == 0
        ? '¿Archivar "${_existing!.name}"? Esta cuenta no tiene movimientos asociados. '
            'La acción es definitiva: no podrás reactivarla.'
        : '¿Archivar "${_existing!.name}"?\n\n'
            'Se cancelarán también los $affected movimientos donde esta cuenta '
            'aparece como origen o destino (incluyendo pagos a tarjetas y '
            'transferencias). El saldo de las otras cuentas que reciban estos '
            'movimientos también se ajustará.\n\n'
            'Esta acción es definitiva: no podrás reactivar la cuenta ni recuperar '
            'los movimientos cancelados.';

    final confirmed = await showConfirmDialog(
      context,
      title: 'Archivar cuenta',
      message: message,
      confirmLabel: 'Archivar y cancelar movimientos',
      destructive: true,
    );
    if (!confirmed) return;
    if (!mounted) return;

    setState(() => _saving = true);
    try {
      await deps.accountsDao.archive(widget.accountId!);
      if (mounted) {
        showSuccessSnackbar(
          context,
          affected == 0
              ? 'Cuenta archivada.'
              : 'Cuenta archivada. $affected movimientos cancelados.',
        );
        Navigator.of(context).maybePop();
      }
    } on AccountsDaoError catch (e) {
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
    if (_isProtected) {
      return _ProtectedView(name: _existing!.name);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Editar cuenta' : 'Nueva cuenta'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!_isEdit) ...[
                const Text('Tipo de cuenta',
                    style: TextStyle(color: FincoreColors.textMuted, fontSize: 13)),
                const SizedBox(height: 8),
                AccountTypePicker(
                  value: _type,
                  onChanged: (t) => setState(() => _type = t),
                  enabled: !_saving,
                ),
                const SizedBox(height: 24),
              ],
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  helperText: ' ',
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Ingresá un nombre.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                  helperText: 'Alias, banco, últimos 4 dígitos…',
                ),
                maxLength: 200,
                maxLines: 2,
              ),
              if (_type == AccountType.credit) ...[
                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 16),
                const Text('Metadata de la tarjeta',
                    style: TextStyle(
                      color: FincoreColors.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    )),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _creditLimitCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Límite de crédito',
                    prefixText: r'$ ',
                    helperText: ' ',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Requerido.';
                    final n = double.tryParse(v);
                    if (n == null || n <= 0) return 'Debe ser mayor a 0.';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _closingDayCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Día de corte',
                          helperText: ' ',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Requerido.';
                          final n = int.tryParse(v);
                          if (n == null || n < 1 || n > 31) return '1-31';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _paymentDayCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Día de pago',
                          helperText: ' ',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Requerido.';
                          final n = int.tryParse(v);
                          if (n == null || n < 1 || n > 31) return '1-31';
                          if (_closingDayCtrl.text.isNotEmpty &&
                              n == int.tryParse(_closingDayCtrl.text)) {
                            return 'Distinto al corte';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: FincoreColors.canvas),
                      )
                    : Text(_isEdit ? 'Guardar cambios' : 'Crear cuenta'),
              ),
              if (_isEdit) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _archive,
                  icon: const Icon(Icons.archive_outlined),
                  label: const Text('Archivar cuenta'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: FincoreColors.negative,
                    side: const BorderSide(color: FincoreColors.negative),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProtectedView extends StatelessWidget {
  final String name;
  const _ProtectedView({required this.name});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 48, color: FincoreColors.textMuted),
              SizedBox(height: 16),
              Text(
                'Esta es tu Bolsa, no se puede editar ni eliminar.',
                textAlign: TextAlign.center,
                style: TextStyle(color: FincoreColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

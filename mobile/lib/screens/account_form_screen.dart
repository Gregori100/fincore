import 'package:fincore/app_dependencies.dart';
import 'package:fincore/constants/account_types.dart';
import 'package:fincore/models/account.dart';
import 'package:fincore/models/domain_error.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/widgets/account_type_picker.dart';
import 'package:fincore/widgets/confirm_dialog.dart';
import 'package:fincore/widgets/error_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class AccountFormScreen extends StatefulWidget {
  /// Si null → modo crear. Si presente → modo editar.
  final String? accountId;

  const AccountFormScreen({super.key, this.accountId});

  @override
  State<AccountFormScreen> createState() => _AccountFormScreenState();
}

class _AccountFormScreenState extends State<AccountFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _creditLimitCtrl = TextEditingController();
  final _closingDayCtrl = TextEditingController();
  final _paymentDayCtrl = TextEditingController();
  final _interestRateCtrl = TextEditingController();
  final _minPaymentPctCtrl = TextEditingController();

  AccountType _type = AccountType.debit;
  bool _saving = false;
  bool _loading = false;
  Account? _existing; // null = modo crear
  bool _loaded = false;

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
    _descriptionCtrl.dispose();
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
      final accounts = await deps.accountsApi.list(includeArchived: true);
      final account = accounts.firstWhere(
        (a) => a.id == widget.accountId,
        orElse: () => throw Exception('Cuenta no encontrada.'),
      );
      setState(() {
        _existing = account;
        _type = account.type;
        _nameCtrl.text = account.name;
        _descriptionCtrl.text = account.description ?? '';
        if (account.isCredit) {
          _creditLimitCtrl.text = account.creditLimit?.toString() ?? '';
          _closingDayCtrl.text = account.closingDay?.toString() ?? '';
          _paymentDayCtrl.text = account.paymentDay?.toString() ?? '';
          _interestRateCtrl.text = account.interestRate?.toString() ?? '';
          _minPaymentPctCtrl.text = account.minimumPaymentPct?.toString() ?? '';
        }
      });
    } on DomainError catch (e) {
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
        final fields = <String, dynamic>{
          'name': _nameCtrl.text.trim(),
          'description': _descriptionCtrl.text.trim().isEmpty
              ? null
              : _descriptionCtrl.text.trim(),
        };
        if (_existing!.isCredit) {
          fields.addAll(_creditFields());
        }
        await deps.accountsApi.update(widget.accountId!, fields);
      } else {
        await deps.accountsApi.create(
          name: _nameCtrl.text.trim(),
          type: _type.apiValue,
          description: _descriptionCtrl.text.trim().isEmpty ? null : _descriptionCtrl.text.trim(),
          creditLimit: _type == AccountType.credit ? num.tryParse(_creditLimitCtrl.text) : null,
          closingDay: _type == AccountType.credit ? int.tryParse(_closingDayCtrl.text) : null,
          paymentDay: _type == AccountType.credit ? int.tryParse(_paymentDayCtrl.text) : null,
          interestRate: _type == AccountType.credit && _interestRateCtrl.text.isNotEmpty
              ? num.tryParse(_interestRateCtrl.text)
              : null,
          minimumPaymentPct: _type == AccountType.credit && _minPaymentPctCtrl.text.isNotEmpty
              ? num.tryParse(_minPaymentPctCtrl.text)
              : null,
        );
      }
      if (mounted) {
        showSuccessSnackbar(context, _isEdit ? 'Cuenta actualizada.' : 'Cuenta creada.');
        context.go('/accounts');
      }
    } on DomainError catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Map<String, dynamic> _creditFields() {
    return <String, dynamic>{
      if (_creditLimitCtrl.text.isNotEmpty) 'credit_limit': num.tryParse(_creditLimitCtrl.text),
      if (_closingDayCtrl.text.isNotEmpty) 'closing_day': int.tryParse(_closingDayCtrl.text),
      if (_paymentDayCtrl.text.isNotEmpty) 'payment_day': int.tryParse(_paymentDayCtrl.text),
      if (_interestRateCtrl.text.isNotEmpty) 'interest_rate': num.tryParse(_interestRateCtrl.text),
      if (_minPaymentPctCtrl.text.isNotEmpty)
        'minimum_payment_pct': num.tryParse(_minPaymentPctCtrl.text),
    };
  }

  Future<void> _delete() async {
    final deps = AppDependencies.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: 'Eliminar cuenta',
      message: '¿Seguro que querés eliminar "${_existing!.name}"? '
          'Solo se puede eliminar si tiene saldo cero.',
      confirmLabel: 'Eliminar',
    );
    if (!confirmed) return;
    if (!mounted) return;

    setState(() => _saving = true);
    try {
      await deps.accountsApi.delete(widget.accountId!);
      if (mounted) {
        showSuccessSnackbar(context, 'Cuenta eliminada.');
        context.go('/accounts');
      }
    } on DomainError catch (e) {
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
      return _ProtectedView(account: _existing!);
    }

    final title = _isEdit ? 'Editar cuenta' : 'Nueva cuenta';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/accounts'),
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
                decoration: const InputDecoration(labelText: 'Nombre'),
                textCapitalization: TextCapitalization.sentences,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Ingresá un nombre.';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                  helperText: 'Alias, banco, últimos 4 dígitos…',
                ),
                maxLength: 200,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
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
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Requerido.';
                    final n = num.tryParse(v);
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
                        decoration: const InputDecoration(labelText: 'Día de corte'),
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
                        decoration: const InputDecoration(labelText: 'Día de pago'),
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
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _interestRateCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Tasa (opcional)',
                          suffixText: '%',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _minPaymentPctCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Pago mínimo (opcional)',
                          suffixText: '%',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
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
                        child: CircularProgressIndicator(strokeWidth: 2, color: FincoreColors.canvas),
                      )
                    : Text(_isEdit ? 'Guardar cambios' : 'Crear cuenta'),
              ),
              if (_isEdit) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _delete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Eliminar cuenta'),
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
  final Account account;
  const _ProtectedView({required this.account});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(account.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/accounts'),
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

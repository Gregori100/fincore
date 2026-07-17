import 'package:fincore/app_dependencies.dart';
import 'package:fincore/data/daos/entries_dao.dart';
import 'package:fincore/data/daos/loans_dao.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/theme/fincore_radii.dart';
import 'package:fincore/theme/fincore_spacing.dart';
import 'package:fincore/widgets/account_balance_hint.dart';
import 'package:fincore/widgets/account_picker.dart';
import 'package:fincore/widgets/amount_formatter.dart';
import 'package:fincore/widgets/error_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class LoanCapitalPaymentForm extends StatefulWidget {
  final String loanId;
  // Hotfix smoke Diego: modo edit — si `paymentId` viene, precarga los
  // valores del abono capital existente y usa `updateLoanPayment` con
  // `interest=0`. Si es null, arma nuevo abono con
  // `registerLoanPayment(isMonthlyPayment: false)`.
  final String? paymentId;
  const LoanCapitalPaymentForm({
    super.key,
    required this.loanId,
    this.paymentId,
  });

  bool get _isEdit => paymentId != null;

  @override
  State<LoanCapitalPaymentForm> createState() =>
      _LoanCapitalPaymentFormState();
}

class _LoanCapitalPaymentFormState extends State<LoanCapitalPaymentForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  // Hotfix branch-quality-review (L7 / F-UX-09): no pre-llenar el
  // controller. Todos los abonos guardados sin editar terminaban con la
  // misma descripción literal en la timeline de /entries. Movido a
  // `hintText` de la InputDecoration para inspirar sin pre-poblar.
  final _descCtrl = TextEditingController();

  DateTime _occurredAt = DateTime.now();
  String? _originId;
  List<Account> _accounts = const [];
  Loan? _loan;
  double _balance = 0;

  bool _loading = false;
  bool _saving = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (!mounted || _loaded) return;
    _loaded = true;
    setState(() => _loading = true);
    final deps = AppDependencies.of(context);
    try {
      _accounts = await deps.accountsDao.listAll();
      final loan = await deps.loansDao.findById(widget.loanId);
      if (loan == null) {
        throw const LoansDaoError('not_found', 'Préstamo no encontrado.');
      }
      _loan = loan;
      _balance = await deps.loansDao.balanceOf(widget.loanId);
      if (widget._isEdit) {
        final entry = await deps.entriesDao.findById(widget.paymentId!);
        if (entry == null) {
          throw const EntriesDaoError('not_found', 'Pago no encontrado.');
        }
        _amountCtrl.text = entry.entry.amount.toStringAsFixed(2);
        _occurredAt = entry.entry.occurredAt;
        _originId = entry.entry.accountOriginId;
        _descCtrl.text = entry.entry.description ?? '';
        _balance += entry.entry.principalAmount ?? entry.entry.amount;
      }
    } on LoansDaoError catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } on EntriesDaoError catch (e) {
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
    // Hotfix smoke Diego: firstDate = contract_date del préstamo.
    final loan = _loan;
    if (loan == null) return;
    final contract = DateTime(
        loan.contractDate.year, loan.contractDate.month, loan.contractDate.day);
    final initialDate =
        _occurredAt.isBefore(contract) ? contract : _occurredAt;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: contract,
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _occurredAt = picked);
    }
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    if (_originId == null) {
      showErrorSnackbar(context, 'Selecciona la cuenta origen.');
      return;
    }
    final amount = _parseDecimal(_amountCtrl.text) ?? 0;
    final deps = AppDependencies.of(context);
    setState(() => _saving = true);
    try {
      if (widget._isEdit) {
        await deps.entriesDao.updateLoanPayment(
          entryId: widget.paymentId!,
          amount: amount,
          principalAmount: amount,
          interestAmount: 0,
          occurredAt: _occurredAt,
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
        );
      } else {
        await deps.entriesDao.registerLoanPayment(
          loanId: widget.loanId,
          accountOriginId: _originId!,
          amount: amount,
          principalAmount: amount,
          interestAmount: 0,
          occurredAt: _occurredAt,
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          // isMonthlyPayment: false por default (abono capital).
        );
      }
      if (mounted) {
        final balance = await deps.loansDao.balanceOf(widget.loanId);
        if (mounted) {
          if (balance <= 0.005) {
            showSuccessSnackbar(context, 'Préstamo pagado en su totalidad.');
          } else {
            showSuccessSnackbar(context,
                widget._isEdit ? 'Abono actualizado.' : 'Abono registrado.');
          }
          Navigator.of(context).maybePop();
        }
      }
    } on EntriesDaoError catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _loan == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cargando...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final fmt = DateFormat("d MMM y", "es_MX");

    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget._isEdit ? 'Editar abono a capital' : 'Abono a capital'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(kSpaceLg),
            children: [
              Text(
                _loan!.name,
                style: const TextStyle(
                  color: FincoreColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: kSpaceXs),
              const Text(
                '100% del monto va a reducir el saldo del préstamo. Sin intereses.',
                style: TextStyle(color: FincoreColors.textSubtle, fontSize: 12),
              ),
              const SizedBox(height: kSpaceMd),
              _CapitalBalanceBanner(
                balance: _balance,
                onSaldar: _balance > 0
                    ? () {
                        setState(() {
                          _amountCtrl.text = _balance.toStringAsFixed(2);
                        });
                      }
                    : null,
              ),
              const SizedBox(height: kSpaceLg),
              AbsorbPointer(
                absorbing: widget._isEdit,
                child: Opacity(
                  opacity: widget._isEdit ? 0.6 : 1.0,
                  child: AccountPicker(
                    label: widget._isEdit
                        ? 'Cuenta origen (no editable)'
                        : 'Cuenta origen',
                    accounts: _accounts,
                    allowedTypes: const ['cash', 'debit'],
                    selectedId: _originId,
                    onChanged: (v) => setState(() => _originId = v),
                    includeArchived: widget._isEdit,
                  ),
                ),
              ),
              AccountBalanceHint(
                  accountId: _originId, accounts: _accounts),
              const SizedBox(height: kSpaceLg),
              TextFormField(
                controller: _amountCtrl,
                // F-DES-8: autofocus solo en alta, nunca al editar. Antes
                // tapaba el banner de saldo pendiente y el picker de cuenta.
                autofocus: !widget._isEdit,
                decoration: const InputDecoration(
                  labelText: 'Monto',
                  prefixText: r'$ ',
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
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(kRadiusMd),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Fecha del abono',
                    suffixIcon: Icon(Icons.calendar_today, size: 18),
                  ),
                  child: Text(fmt.format(_occurredAt)),
                ),
              ),
              const SizedBox(height: kSpaceLg),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                  hintText: 'Ej: Abono extra a capital',
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
                maxLength: 200,
              ),
              const SizedBox(height: kSpace2xl),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: FincoreColors.canvas),
                      )
                    : Text(widget._isEdit
                        ? 'Guardar cambios'
                        : 'Registrar abono'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Banner del saldo pendiente con botón "Saldar" para abono a capital.
/// Más simple que el del monthly form (no muestra "tras este pago" porque
/// el capital form no tiene split — el monto == principal).
class _CapitalBalanceBanner extends StatelessWidget {
  final double balance;
  final VoidCallback? onSaldar;
  const _CapitalBalanceBanner({
    required this.balance,
    required this.onSaldar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: kSpaceLg, vertical: kSpaceMd),
      decoration: BoxDecoration(
        color:
            FincoreColors.accent.withValues(alpha: FincoreColors.alphaTint),
        borderRadius: BorderRadius.circular(kRadiusMd),
        border: Border.all(
          color: FincoreColors.accent
              .withValues(alpha: FincoreColors.alphaHairline),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Saldo pendiente',
                  style: TextStyle(
                    color: FincoreColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: kSpace2xs),
                Text(
                  formatAmount(balance),
                  style: const TextStyle(
                    color: FincoreColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),
          // F-DES-6: chip pasivo "✓ Saldado" cuando el préstamo no tiene
          // saldo pendiente. Tooltip solo cuando el botón es actuable.
          if (onSaldar == null)
            const _SaldadoChip()
          else
            Tooltip(
              message: 'Autocompleta monto = saldo pendiente',
              child: OutlinedButton.icon(
                onPressed: onSaldar,
                icon: const Icon(Icons.done_all, size: 16),
                label: const Text('Saldar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: FincoreColors.accent,
                  side: const BorderSide(color: FincoreColors.accent),
                  padding: const EdgeInsets.symmetric(
                      horizontal: kSpaceMd, vertical: kSpaceSm),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// F-DES-6: chip pasivo para el estado "saldado" del banner de saldo.
/// Duplicado local del que vive en loan_monthly_payment_form; una
/// abstracción compartida es sobre-ingeniería para 2 sitios idénticos y
/// pequeños.
class _SaldadoChip extends StatelessWidget {
  const _SaldadoChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: kSpaceMd, vertical: kSpaceSm),
      decoration: BoxDecoration(
        color: FincoreColors.positive
            .withValues(alpha: FincoreColors.alphaTint),
        borderRadius: BorderRadius.circular(kRadiusMd),
        border: Border.all(
          color: FincoreColors.positive
              .withValues(alpha: FincoreColors.alphaHairline),
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline,
              size: 16, color: FincoreColors.positive),
          SizedBox(width: kSpaceXs),
          Text('Saldado',
              style: TextStyle(
                color: FincoreColors.positive,
                fontWeight: FontWeight.w600,
              )),
        ],
      ),
    );
  }
}

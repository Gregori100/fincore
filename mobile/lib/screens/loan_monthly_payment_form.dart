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

class LoanMonthlyPaymentForm extends StatefulWidget {
  final String loanId;
  // Hotfix smoke Diego: modo edit — si `paymentId` viene, precarga los
  // valores del pago existente y usa `updateLoanPayment`. Si es null,
  // arma un nuevo pago con `registerLoanPayment(isMonthlyPayment: true)`.
  final String? paymentId;
  const LoanMonthlyPaymentForm({
    super.key,
    required this.loanId,
    this.paymentId,
  });

  bool get _isEdit => paymentId != null;

  @override
  State<LoanMonthlyPaymentForm> createState() =>
      _LoanMonthlyPaymentFormState();
}

class _LoanMonthlyPaymentFormState extends State<LoanMonthlyPaymentForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _principalCtrl = TextEditingController();
  final _interestCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  DateTime _occurredAt = DateTime.now();
  String? _originId;
  List<Account> _accounts = const [];
  Loan? _loan;

  // Estado interno sincronizado del split. Guardamos los valores como
  // double y los reflejamos en los controllers cuando cambia el slider o
  // uno de los TextFields (sin disparar loops recursivos gracias a `_syncing`).
  double _amount = 0;
  double _principal = 0;
  double _interest = 0;
  bool _syncing = false;
  // Hotfix smoke Diego v3: saldo pendiente actual del préstamo (para
  // indicador visual y botón "Saldar"). En modo edit, se preserva el
  // capital del propio entry (para que Diego pueda editarlo sin que su
  // propio principal reste al balance disponible).
  double _balance = 0;

  bool _loading = false;
  bool _saving = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
    _amountCtrl.addListener(_onAmountFieldChanged);
    _principalCtrl.addListener(_onPrincipalFieldChanged);
    _interestCtrl.addListener(_onInterestFieldChanged);
  }

  @override
  void dispose() {
    _amountCtrl.removeListener(_onAmountFieldChanged);
    _principalCtrl.removeListener(_onPrincipalFieldChanged);
    _interestCtrl.removeListener(_onInterestFieldChanged);
    _amountCtrl.dispose();
    _principalCtrl.dispose();
    _interestCtrl.dispose();
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
      // Saldo pendiente actual (para indicador + botón Saldar).
      _balance = await deps.loansDao.balanceOf(widget.loanId);
      if (widget._isEdit) {
        // Precargar valores del pago existente.
        final entry = await deps.entriesDao.findById(widget.paymentId!);
        if (entry == null) {
          throw const EntriesDaoError('not_found', 'Pago no encontrado.');
        }
        _amount = entry.entry.amount;
        _principal = entry.entry.principalAmount ?? 0;
        _interest = entry.entry.interestAmount ?? 0;
        _occurredAt = entry.entry.occurredAt;
        _originId = entry.entry.accountOriginId;
        _descCtrl.text = entry.entry.description ?? '';
        // En edit el saldo pendiente disponible = balance actual +
        // principal del propio entry (porque al guardar el propio principal
        // se restará del saldo, pero el propio ya estaba restado antes).
        _balance += _principal;
      } else {
        // Pre-fill: monto = monthly_payment del contrato, split 100%
        // capital por default (Diego sobrescribe con el split del banco).
        _amount = loan.monthlyPayment;
        _principal = loan.monthlyPayment;
        _interest = 0;
      }
      _writeControllers();
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

  String _fmt(double v) => v.toStringAsFixed(2);

  /// Escribe los 3 controllers desde el estado interno. Marca `_syncing`
  /// para que los listeners no disparen re-entradas.
  void _writeControllers() {
    _syncing = true;
    _amountCtrl.text = _fmt(_amount);
    _principalCtrl.text = _fmt(_principal);
    _interestCtrl.text = _fmt(_interest);
    _syncing = false;
  }

  /// Escribe sólo los 2 del split, preservando el amount actual del ctrl.
  void _writeSplitControllers() {
    _syncing = true;
    _principalCtrl.text = _fmt(_principal);
    _interestCtrl.text = _fmt(_interest);
    _syncing = false;
  }

  void _onAmountFieldChanged() {
    if (_syncing) return;
    final v = _parseDecimal(_amountCtrl.text);
    if (v == null || v < 0) return;
    final oldAmount = _amount;
    _amount = v;
    // Reajuste proporcional del split preservando la ratio previa. Si el
    // split anterior era 0/0 o el amount previo era 0, defaulteamos a
    // 100% capital.
    if (oldAmount <= 0 || (_principal + _interest) <= 0) {
      _principal = v;
      _interest = 0;
    } else {
      final ratio = _principal / (_principal + _interest);
      _principal = (v * ratio).clamp(0, v);
      _interest = (v - _principal).clamp(0, v);
    }
    _writeSplitControllers();
    setState(() {});
  }

  void _onPrincipalFieldChanged() {
    if (_syncing) return;
    final v = _parseDecimal(_principalCtrl.text);
    if (v == null || v < 0) return;
    final clamped = v.clamp(0.0, _amount);
    _principal = clamped;
    _interest = (_amount - _principal).clamp(0, _amount);
    _syncing = true;
    _interestCtrl.text = _fmt(_interest);
    _syncing = false;
    setState(() {});
  }

  void _onInterestFieldChanged() {
    if (_syncing) return;
    final v = _parseDecimal(_interestCtrl.text);
    if (v == null || v < 0) return;
    final clamped = v.clamp(0.0, _amount);
    _interest = clamped;
    _principal = (_amount - _interest).clamp(0, _amount);
    _syncing = true;
    _principalCtrl.text = _fmt(_principal);
    _syncing = false;
    setState(() {});
  }

  void _onSliderChanged(double value) {
    _principal = value;
    _interest = (_amount - value).clamp(0, _amount);
    _writeSplitControllers();
    setState(() {});
  }

  /// Hotfix smoke Diego v3: botón "Saldar" — pone `principal = saldo
  /// pendiente disponible` para que el capital del pago sea exactamente
  /// el necesario para llegar a 0. El monto total sube al balance +
  /// interés actual (o el interés se preserva si ya estaba). Si el amount
  /// era mayor, se ajusta hacia abajo.
  void _onSaldarPressed() {
    if (_balance <= 0) return;
    _principal = _balance;
    // Preservar el interés que Diego ya declaró; ajustar amount.
    _amount = _principal + _interest;
    _writeControllers();
    setState(() {});
  }

  Future<void> _pickDate() async {
    // Hotfix smoke Diego: `firstDate` = contract_date del préstamo — el
    // usuario no puede siquiera seleccionar fechas anteriores (bloqueo
    // preventivo en la UI, no sólo en el DAO al submit). `lastDate` en
    // 2100 permite pagos anticipados.
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
    if (_amount <= 0) {
      showErrorSnackbar(context, 'El monto debe ser mayor a 0.');
      return;
    }
    // El slider + auto-sync garantizan `principal + interest = amount`, pero
    // por defensa validamos igual antes de mandar al DAO.
    if ((_principal + _interest - _amount).abs() >= 0.005) {
      showErrorSnackbar(context,
          'La suma de capital + intereses debe ser igual al monto.');
      return;
    }
    final deps = AppDependencies.of(context);
    setState(() => _saving = true);
    try {
      if (widget._isEdit) {
        // Modo edición: `updateLoanPayment` re-valida reglas de unicidad
        // + fecha excluyendo el propio entry.
        await deps.entriesDao.updateLoanPayment(
          entryId: widget.paymentId!,
          amount: _amount,
          principalAmount: _principal,
          interestAmount: _interest,
          occurredAt: _occurredAt,
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
        );
      } else {
        await deps.entriesDao.registerLoanPayment(
          loanId: widget.loanId,
          accountOriginId: _originId!,
          amount: _amount,
          principalAmount: _principal,
          interestAmount: _interest,
          occurredAt: _occurredAt,
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          // Hotfix smoke Diego: marca como pago del mes → el DAO valida
          // que no exista otro en el mismo mes calendario.
          isMonthlyPayment: true,
        );
      }
      if (mounted) {
        final balance = await deps.loansDao.balanceOf(widget.loanId);
        if (mounted) {
          if (balance <= 0.005) {
            showSuccessSnackbar(context, 'Préstamo pagado en su totalidad.');
          } else {
            showSuccessSnackbar(context,
                widget._isEdit ? 'Pago actualizado.' : 'Pago registrado.');
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
    final sliderMax = _amount > 0 ? _amount : 1.0;

    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget._isEdit ? 'Editar pago del mes' : 'Pago del mes'),
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
                'Copia del estado de cuenta cuánto va a capital y cuánto a intereses. '
                'Puedes editar los montos o mover la barra.',
                style: TextStyle(color: FincoreColors.textSubtle, fontSize: 12),
              ),
              const SizedBox(height: kSpaceMd),
              _BalanceBanner(
                balance: _balance,
                principal: _principal,
                // Hotfix quality-review B12: siempre mostramos el botón
                // Saldar; con balance=0 lo dejamos disabled + tooltip.
                onSaldar: _balance > 0 ? _onSaldarPressed : null,
                balanceZero: _balance <= 0.005,
              ),
              const SizedBox(height: kSpaceLg),
              // En modo edit, la cuenta origen es inmutable (preservada
              // por trazabilidad). Bloqueamos con AbsorbPointer + opacity.
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
                // F-DES-8: alineado con la convención del resto de la app
                // (entry_form, budget_item_sheet, capital_payment_form).
                autofocus: !widget._isEdit,
                decoration: InputDecoration(
                  labelText: 'Monto total pagado',
                  prefixText: r'$ ',
                  helperText: 'Default: pago mensual del contrato',
                  suffixIcon: _amount != _loan!.monthlyPayment
                      ? IconButton(
                          icon: const Icon(Icons.restart_alt, size: 20),
                          tooltip: 'Volver al pago mensual del contrato',
                          onPressed: () {
                            _amount = _loan!.monthlyPayment;
                            _principal = _loan!.monthlyPayment;
                            _interest = 0;
                            _writeControllers();
                            setState(() {});
                          },
                        )
                      : null,
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
              _SplitSlider(
                total: _amount,
                principal: _principal,
                max: sliderMax,
                onChanged: _onSliderChanged,
              ),
              const SizedBox(height: kSpaceMd),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _principalCtrl,
                      decoration: InputDecoration(
                        labelText: 'Capital',
                        prefixText: r'$ ',
                        labelStyle: const TextStyle(
                            color: FincoreColors.accent),
                        border: const OutlineInputBorder(
                          borderSide: BorderSide(color: FincoreColors.accent),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: FincoreColors.accent.withValues(
                                alpha: FincoreColors.alphaTint),
                          ),
                        ),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Requerido.';
                        final n = _parseDecimal(v);
                        if (n == null || n < 0) {
                          return 'No puede ser negativo.';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: kSpaceMd),
                  Expanded(
                    child: TextFormField(
                      controller: _interestCtrl,
                      decoration: InputDecoration(
                        labelText: 'Intereses',
                        prefixText: r'$ ',
                        labelStyle: const TextStyle(
                            color: FincoreColors.warning),
                        border: const OutlineInputBorder(
                          borderSide: BorderSide(color: FincoreColors.warning),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: FincoreColors.warning.withValues(
                                alpha: FincoreColors.alphaTint),
                          ),
                        ),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Requerido.';
                        final n = _parseDecimal(v);
                        if (n == null || n < 0) {
                          return 'No puede ser negativo.';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: kSpaceSm),
              const Text(
                'Capital + Intereses = Monto total. Auto-ajuste al mover la '
                'barra o editar un campo.',
                style: TextStyle(color: FincoreColors.textSubtle, fontSize: 11),
              ),
              const SizedBox(height: kSpaceLg),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(kRadiusMd),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Fecha del pago',
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
                        : 'Registrar pago'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Slider ajustable que reparte el monto total entre capital (izquierda,
/// accent azul) e intereses (derecha, warning amarillo). Al mover, el
/// caller recibe el nuevo `principal` — el interés se computa como
/// `total − principal`. El track está pintado en 2 colores para reflejar
/// visualmente la proporción.
class _SplitSlider extends StatelessWidget {
  final double total;
  final double principal;
  final double max;
  final ValueChanged<double> onChanged;
  const _SplitSlider({
    required this.total,
    required this.principal,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Hotfix branch-quality-review (L5 / F-UX-03): con `total <= 0`, la
    // leyenda mostraba "Capital 50% · Intereses 50%" pero ambos valores
    // están en 0 y el slider está disabled — mentira visual. Marcamos como
    // "no aplica" para que el usuario entienda que primero debe ingresar
    // un monto total.
    final noAmount = total <= 0;
    final ratio = noAmount ? 0.0 : (principal / total).clamp(0.0, 1.0);
    final capitalLabel =
        noAmount ? 'Capital —' : 'Capital ${(ratio * 100).toStringAsFixed(0)}%';
    final interestLabel = noAmount
        ? 'Intereses —'
        : 'Intereses ${((1 - ratio) * 100).toStringAsFixed(0)}%';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: FincoreColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: kSpaceXs),
                Text(
                  capitalLabel,
                  style: const TextStyle(
                    color: FincoreColors.textSubtle,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  interestLabel,
                  style: const TextStyle(
                    color: FincoreColors.textSubtle,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: kSpaceXs),
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: FincoreColors.warning,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: kSpaceSm),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: FincoreColors.accent,
            inactiveTrackColor: FincoreColors.warning,
            thumbColor: FincoreColors.textPrimary,
            overlayColor: FincoreColors.accent
                .withValues(alpha: FincoreColors.alphaHover),
            trackHeight: 6,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
          ),
          child: Slider(
            value: principal.clamp(0.0, max),
            min: 0,
            max: max,
            onChanged: total > 0 ? onChanged : null,
          ),
        ),
      ],
    );
  }
}

/// Banner del saldo pendiente del préstamo. Muestra cuánto queda por pagar
/// y cuánto quedaría tras aplicar el capital actual del pago. Botón
/// "Saldar" para llegar exacto al balance.
// ignore: unused_element
class _BalanceBanner extends StatelessWidget {
  final double balance;
  final double principal;
  final VoidCallback? onSaldar;
  final bool balanceZero;
  const _BalanceBanner({
    required this.balance,
    required this.principal,
    required this.onSaldar,
    this.balanceZero = false,
  });

  @override
  Widget build(BuildContext context) {
    final remainingAfter = (balance - principal).clamp(0.0, double.infinity);
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
                if (principal > 0) ...[
                  const SizedBox(height: kSpace2xs),
                  Text(
                    'Tras este pago: ${formatAmount(remainingAfter)}',
                    style: const TextStyle(
                      color: FincoreColors.textSubtle,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // F-DES-6: si el préstamo ya está saldado mostramos un chip pasivo
          // "✓ Saldado" en vez de un botón disabled con Tooltip. En Android
          // Tooltip solo se revela con long-press y sobre un botón deshabilitado
          // no siempre propaga el gesto — quedaba invisible el motivo.
          if (balanceZero)
            const _SaldadoChip()
          else
            Tooltip(
              message: 'Autocompleta capital = saldo pendiente',
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

/// F-DES-6: chip pasivo "✓ Saldado" que ocupa el mismo hueco que el botón
/// "Saldar" cuando el préstamo ya no tiene saldo pendiente. Sin acción,
/// solo señalización visual explícita.
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

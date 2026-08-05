import 'package:fincore/app_dependencies.dart';
import 'package:fincore/data/daos/loans_dao.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/theme/fincore_radii.dart';
import 'package:fincore/theme/fincore_spacing.dart';
import 'package:fincore/theme/fincore_typography.dart' as typo;
import 'package:fincore/utils/money.dart';
import 'package:fincore/widgets/amount_input_formatter.dart';
import 'package:fincore/widgets/confirm_dialog.dart';
import 'package:fincore/widgets/error_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Alta y edición de un ajuste de saldo de préstamo (sprint
/// `flutter-loans-flexible-payments-v1`).
///
/// Un ajuste corrige el saldo pendiente sin tocar `principal_amount`, que es
/// el monto originalmente prestado y dato histórico. Caso real: el banco de
/// Diego subió el saldo sin explicación y sin movimiento de dinero.
///
/// Decisión de UX (RT-06 del plan): el signo se elige con un toggle
/// **"Aumenta" / "Disminuye"** en vez de pedir un número negativo. El riesgo
/// mayor de esta pantalla es que el usuario mueva el saldo en dirección
/// contraria a la que quiere, y un `-` tecleado es fácil de perder de vista.
/// El preview del saldo resultante cierra el bucle de retroalimentación.
class LoanAdjustmentForm extends StatefulWidget {
  final String loanId;

  /// Si viene, la pantalla edita ese ajuste en vez de crear uno nuevo.
  final String? adjustmentId;

  const LoanAdjustmentForm({
    super.key,
    required this.loanId,
    this.adjustmentId,
  });

  bool get _isEdit => adjustmentId != null;

  @override
  State<LoanAdjustmentForm> createState() => _LoanAdjustmentFormState();
}

class _LoanAdjustmentFormState extends State<LoanAdjustmentForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();

  DateTime _occurredAt = DateTime.now();

  /// `true` → el ajuste sube la deuda (monto positivo en BD).
  bool _increases = true;

  Loan? _loan;

  /// Saldo del préstamo **sin** contar el ajuste que se está editando. Es la
  /// base contra la que se calcula el preview y se valida el mínimo.
  int _baseBalance = 0;

  bool _loading = false;
  bool _saving = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl.addListener(_onAmountChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _amountCtrl.removeListener(_onAmountChanged);
    _amountCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  void _onAmountChanged() => setState(() {});

  Future<void> _bootstrap() async {
    if (!mounted || _loaded) return;
    _loaded = true;
    setState(() => _loading = true);
    final deps = AppDependencies.of(context);
    try {
      final loan = await deps.loansDao.findById(widget.loanId);
      if (loan == null) {
        throw const LoansDaoError('not_found', 'Préstamo no encontrado.');
      }
      _loan = loan;
      _baseBalance = await deps.loansDao.balanceOf(widget.loanId);
      if (widget._isEdit) {
        final adj =
            await deps.loansDao.findAdjustmentById(widget.adjustmentId!);
        if (adj == null) {
          throw const LoansDaoError('not_found', 'Ajuste no encontrado.');
        }
        _increases = adj.amount > 0;
        _amountCtrl.text = formatAmountForInput(adj.amount.abs());
        _reasonCtrl.text = adj.reason ?? '';
        _occurredAt = adj.occurredAt;
        // El saldo actual YA incluye este ajuste; para el preview hay que
        // partir del saldo sin él (misma lógica que `_validateAdjustment`
        // con `excludeAdjustmentId`).
        _baseBalance -= adj.amount;
      }
    } on LoansDaoError catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Monto tecleado en centavos, siempre positivo. `null` si el texto no es
  /// un monto válido.
  int? get _magnitude {
    try {
      return parseCents(_amountCtrl.text);
    } on FormatException {
      return null;
    }
  }

  /// Monto con signo tal como se guardaría en BD.
  int? get _signedAmount {
    final m = _magnitude;
    if (m == null) return null;
    return _increases ? m : -m;
  }

  /// Saldo que quedaría de confirmarse el ajuste. `null` si el monto todavía
  /// no es válido.
  int? get _projectedBalance {
    final signed = _signedAmount;
    if (signed == null) return null;
    return _baseBalance + signed;
  }

  /// El préstamo está cerrado como `paid` y el ajuste lo devolvería a saldo
  /// positivo: la confirmación debe advertirlo (RN-LF-10).
  bool get _wouldReopen {
    final loan = _loan;
    final projected = _projectedBalance;
    if (loan == null || projected == null) return false;
    return loan.closeReason == 'paid' && projected > 0;
  }

  Future<void> _pickDate() async {
    // A diferencia de los pagos, un ajuste NO tiene `firstDate` atado al
    // contrato: puede estar corrigiendo un error en la captura del monto
    // original, que por definición es anterior.
    final picked = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('es', 'MX'),
    );
    if (picked != null && mounted) {
      setState(() => _occurredAt = picked);
    }
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    final signed = _signedAmount;
    if (signed == null) return;

    if (_wouldReopen) {
      final ok = await showConfirmDialog(
        context,
        title: 'Reabrir el préstamo',
        message:
            'Este ajuste deja el saldo en ${formatCents(_projectedBalance!)}, '
            'así que el préstamo dejará de estar marcado como pagado y '
            'volverá a aparecer como activo.',
        confirmLabel: 'Ajustar y reabrir',
      );
      if (!ok || !mounted) return;
    }

    setState(() => _saving = true);
    final deps = AppDependencies.of(context);
    final reason = _reasonCtrl.text.trim();
    try {
      if (widget._isEdit) {
        await deps.loansDao.updateAdjustment(
          id: widget.adjustmentId!,
          amount: signed,
          occurredAt: _occurredAt,
          reason: reason.isEmpty ? null : reason,
        );
      } else {
        await deps.loansDao.registerAdjustment(
          loanId: widget.loanId,
          amount: signed,
          occurredAt: _occurredAt,
          reason: reason.isEmpty ? null : reason,
        );
      }
    } catch (e) {
      // El `setState` de recuperación va SÓLO en la rama de error. En la
      // rama feliz la pantalla se desmonta con el `pop`, y un `setState`
      // posterior busca ancestros de un widget ya desactivado ("Looking up a
      // deactivated widget's ancestor is unsafe").
      if (mounted) {
        showErrorSnackbar(context, e);
        setState(() => _saving = false);
      }
      return;
    }
    if (!mounted) return;
    showSuccessSnackbar(
      context,
      widget._isEdit ? 'Ajuste actualizado.' : 'Ajuste registrado.',
    );
    Navigator.of(context).maybePop();
  }

  String? _validateAmount(String? raw) {
    final text = (raw ?? '').trim();
    if (text.isEmpty) return 'Ingresa un monto.';
    final m = _magnitude;
    if (m == null) return 'Monto inválido.';
    if (m == 0) return 'El ajuste no puede ser de cero.';
    final projected = _projectedBalance;
    if (projected != null && projected < 0) {
      return 'El saldo quedaría en negativo (disponible: '
          '${formatCents(_baseBalance)}).';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _loan == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ajustar saldo')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final projected = _projectedBalance;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget._isEdit ? 'Editar ajuste' : 'Ajustar saldo'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: kEdgeScreen,
            children: [
              _ExplainerCard(loan: _loan!, baseBalance: _baseBalance),
              const SizedBox(height: kSpaceLg),
              const Text('¿Qué hace este ajuste?', style: typo.label),
              const SizedBox(height: kSpaceSm),
              _DirectionToggle(
                increases: _increases,
                onChanged: (v) => setState(() => _increases = v),
              ),
              const SizedBox(height: kSpaceLg),
              TextFormField(
                controller: _amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [AmountInputFormatter()],
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: _validateAmount,
                decoration: const InputDecoration(
                  labelText: 'Monto del ajuste',
                  prefixText: '\$ ',
                  helperText: 'Sólo la cantidad; el sentido lo decide el '
                      'selector de arriba.',
                ),
              ),
              const SizedBox(height: kSpaceLg),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(kRadiusMd),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Fecha del ajuste',
                    suffixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(
                    DateFormat("d 'de' MMMM 'de' y", 'es_MX')
                        .format(_occurredAt),
                    style: typo.bodyM,
                  ),
                ),
              ),
              const SizedBox(height: kSpaceLg),
              TextFormField(
                controller: _reasonCtrl,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Motivo (opcional)',
                  hintText: 'Ej. ajuste del banco sin explicación',
                ),
              ),
              const SizedBox(height: kSpaceSm),
              if (projected != null)
                _ProjectionCard(
                  before: _baseBalance,
                  after: projected,
                  wouldReopen: _wouldReopen,
                ),
              const SizedBox(height: kSpaceXl),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: Text(_saving
                    ? 'Guardando...'
                    : (widget._isEdit ? 'Guardar cambios' : 'Registrar ajuste')),
              ),
              const SizedBox(height: kSpaceSm),
              TextButton(
                onPressed:
                    _saving ? null : () => Navigator.of(context).maybePop(),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Explica qué NO hace un ajuste. Es la parte fácil de malinterpretar: no
/// mueve dinero de ninguna cuenta y no toca el monto original prestado.
class _ExplainerCard extends StatelessWidget {
  final Loan loan;
  final int baseBalance;
  const _ExplainerCard({required this.loan, required this.baseBalance});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: kEdgeCard,
      decoration: BoxDecoration(
        color: FincoreColors.surfaceElevated,
        borderRadius: BorderRadius.circular(kRadiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_outlined,
                  size: 18, color: FincoreColors.textMuted),
              const SizedBox(width: kSpaceSm),
              Expanded(
                child: Text(loan.name, style: typo.headingM),
              ),
            ],
          ),
          const SizedBox(height: kSpaceMd),
          _Row(label: 'Monto prestado', value: formatCents(loan.principalAmount)),
          const SizedBox(height: kSpaceXs),
          _Row(label: 'Saldo actual', value: formatCents(baseBalance)),
          const SizedBox(height: kSpaceMd),
          const Text(
            'Un ajuste corrige el saldo pendiente. No mueve dinero de ninguna '
            'cuenta y no cambia el monto que te prestaron.',
            style: typo.label,
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: typo.label),
        Text(value, style: typo.bodyS),
      ],
    );
  }
}

/// Toggle de sentido del ajuste. Deliberadamente verboso: "Aumenta el saldo"
/// / "Disminuye el saldo" en vez de `+` / `−`.
class _DirectionToggle extends StatelessWidget {
  final bool increases;
  final ValueChanged<bool> onChanged;
  const _DirectionToggle({required this.increases, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _DirectionOption(
            selected: increases,
            // Subir la deuda es malo para el usuario → color negativo, aunque
            // el signo aritmético sea positivo.
            color: FincoreColors.negative,
            icon: Icons.trending_up,
            label: 'Aumenta el saldo',
            onTap: () => onChanged(true),
          ),
        ),
        const SizedBox(width: kSpaceSm),
        Expanded(
          child: _DirectionOption(
            selected: !increases,
            color: FincoreColors.positive,
            icon: Icons.trending_down,
            label: 'Disminuye el saldo',
            onTap: () => onChanged(false),
          ),
        ),
      ],
    );
  }
}

class _DirectionOption extends StatelessWidget {
  final bool selected;
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _DirectionOption({
    required this.selected,
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(kRadiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: kSpaceMd,
          horizontal: kSpaceSm,
        ),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: FincoreColors.alphaTint)
              : FincoreColors.surfaceElevated,
          borderRadius: BorderRadius.circular(kRadiusMd),
          border: Border.all(
            color: selected
                ? color
                : FincoreColors.textMuted
                    .withValues(alpha: FincoreColors.alphaHairline),
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 20,
                color: selected ? color : FincoreColors.textMuted),
            const SizedBox(height: kSpaceXs),
            Text(
              label,
              textAlign: TextAlign.center,
              style: typo.bodyS.copyWith(
                color: selected ? color : FincoreColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Preview del efecto. Sin esto el usuario confirma a ciegas.
class _ProjectionCard extends StatelessWidget {
  final int before;
  final int after;
  final bool wouldReopen;
  const _ProjectionCard({
    required this.before,
    required this.after,
    required this.wouldReopen,
  });

  @override
  Widget build(BuildContext context) {
    final worse = after > before;
    final color = worse ? FincoreColors.negative : FincoreColors.positive;
    return Container(
      padding: kEdgeCard,
      decoration: BoxDecoration(
        color: color.withValues(alpha: FincoreColors.alphaTint),
        borderRadius: BorderRadius.circular(kRadiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SALDO RESULTANTE', style: typo.overline),
          const SizedBox(height: kSpaceXs),
          // Flexible en ambos montos: dos cifras largas más el icono
          // desbordan el ancho de un teléfono angosto.
          Row(
            children: [
              Flexible(
                child: Text(
                  formatCents(before),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typo.bodyM,
                ),
              ),
              const SizedBox(width: kSpaceSm),
              const Icon(Icons.arrow_forward,
                  size: 16, color: FincoreColors.textMuted),
              const SizedBox(width: kSpaceSm),
              Flexible(
                child: Text(
                  formatCents(after),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typo.headingM.copyWith(color: color),
                ),
              ),
            ],
          ),
          if (wouldReopen) ...[
            const SizedBox(height: kSpaceSm),
            const Row(
              children: [
                Icon(Icons.lock_open_outlined,
                    size: 16, color: FincoreColors.warning),
                SizedBox(width: kSpaceXs),
                Expanded(
                  child: Text(
                    'El préstamo dejará de estar marcado como pagado.',
                    style: typo.label,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

import 'package:fincore/app_dependencies.dart';
import 'package:fincore/constants/kinds.dart';
import 'package:fincore/data/daos/entries_dao.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/widgets/account_balance_hint.dart';
import 'package:fincore/widgets/account_picker.dart';
import 'package:fincore/widgets/category_picker.dart';
import 'package:fincore/widgets/confirm_dialog.dart';
import 'package:fincore/widgets/error_snackbar.dart';
import 'package:fincore/widgets/kind_picker.dart';
import 'package:fincore/widgets/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class EntryFormScreen extends StatefulWidget {
  final String? entryId;
  const EntryFormScreen({super.key, this.entryId});

  @override
  State<EntryFormScreen> createState() => _EntryFormScreenState();
}

class _EntryFormScreenState extends State<EntryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  JournalKind? _kind;
  String? _originId;
  String? _destId;
  String? _categoryId;
  DateTime _occurredAt = DateTime.now();

  List<Account> _accounts = const [];
  List<Category> _categories = const [];

  bool _loading = true;
  bool _saving = false;
  String? _bootstrapError;

  bool get _isEdit => widget.entryId != null;

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
    if (!mounted) return;
    final deps = AppDependencies.of(context);
    try {
      final accounts = await deps.accountsDao.listAll();
      final categories = await deps.categoriesDao.listAll();
      if (!mounted) return;
      _accounts = accounts;
      _categories = categories;

      if (_isEdit) {
        final item = await deps.entriesDao.findById(widget.entryId!);
        if (!mounted) return;
        if (item == null) {
          throw const EntriesDaoError('not_found', 'Movimiento no encontrado.');
        }
        _kind = parseJournalKind(item.entry.kind);
        _originId = item.entry.accountOriginId;
        _destId = item.entry.accountDestinationId;
        // B2 (quality review 2026-06-19): si la categoría heredada está
        // archivada, resetear _categoryId a null. Sin esto, el form pasaba
        // categoryId del entry como "explícito" al DAO y el updateEntry
        // lanzaba invalid_category_applies_to al guardar, rompiendo la
        // promesa de RN-H03 (limpieza silenciosa de categoría archivada).
        if (item.entry.categoryId != null) {
          final activeCat =
              await deps.categoriesDao.findActiveById(item.entry.categoryId!);
          _categoryId = activeCat == null ? null : item.entry.categoryId;
        } else {
          _categoryId = null;
        }
        _occurredAt = item.entry.occurredAt;
        _amountCtrl.text = item.entry.amount.toString();
        _descCtrl.text = item.entry.description ?? '';
      }
    } on EntriesDaoError catch (e) {
      if (mounted) setState(() => _bootstrapError = e.message);
      return;
    } catch (e) {
      if (mounted) setState(() => _bootstrapError = e.toString());
      return;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectKind(JournalKind k) {
    setState(() {
      _kind = k;
      _originId = null;
      _destId = null;
      _categoryId = null;
      _occurredAt = DateTime.now();
      _amountCtrl.clear();
      _descCtrl.clear();
      _formKey.currentState?.reset();
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _occurredAt = DateTime(picked.year, picked.month, picked.day,
          _occurredAt.hour, _occurredAt.minute));
    }
  }

  Future<void> _submit() async {
    if (_saving || _kind == null) return;
    if (!_formKey.currentState!.validate()) return;
    final deps = AppDependencies.of(context);

    // Los pickers de cuenta usan DropdownMenu (M3) y no validan por Form.
    // Cubrimos a mano que origin/destination requeridos por el kind estén.
    final k = _kind!;
    if (_needsOrigin(k) && _originId == null) {
      _showFieldError('Seleccioná la cuenta origen.');
      return;
    }
    if (_needsDestination(k) && _destId == null) {
      _showFieldError('Seleccioná la cuenta destino.');
      return;
    }

    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) return;
    final description = _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim();

    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await deps.entriesDao.updateEntry(
          id: widget.entryId!,
          amount: amount,
          description: _descCtrl.text.trim().isEmpty ? '' : _descCtrl.text.trim(),
          occurredAt: _occurredAt,
          accountOriginId: _originId,
          accountDestinationId: _destId,
          categoryId: _kind!.acceptsCategory ? _categoryId : null,
          clearCategory: _kind!.acceptsCategory && _categoryId == null,
        );
      } else {
        switch (_kind!) {
          case JournalKind.income:
            await deps.entriesDao.registerIncome(
              accountDestinationId: _destId!,
              amount: amount,
              occurredAt: _occurredAt,
              description: description,
              categoryId: _categoryId,
            );
            break;
          case JournalKind.expense:
            await deps.entriesDao.registerExpense(
              accountOriginId: _originId!,
              amount: amount,
              occurredAt: _occurredAt,
              description: description,
              categoryId: _categoryId,
            );
            break;
          case JournalKind.creditExpense:
            await deps.entriesDao.registerCreditExpense(
              accountOriginId: _originId!,
              amount: amount,
              occurredAt: _occurredAt,
              description: description,
              categoryId: _categoryId,
            );
            break;
          case JournalKind.debtPayment:
            await deps.entriesDao.registerDebtPayment(
              accountOriginId: _originId!,
              accountDestinationId: _destId!,
              amount: amount,
              occurredAt: _occurredAt,
              description: description,
            );
            break;
          case JournalKind.transfer:
            await deps.entriesDao.registerTransfer(
              accountOriginId: _originId!,
              accountDestinationId: _destId!,
              amount: amount,
              occurredAt: _occurredAt,
              description: description,
            );
            break;
        }
      }
      if (mounted) {
        showSuccessSnackbar(
            context, _isEdit ? 'Movimiento actualizado.' : 'Movimiento creado.');
        // Resetear _saving ANTES del pop para que PopScope.canPop pase a
        // true. `setState` marca el state dirty pero el rebuild ocurre en
        // el próximo frame; por eso el `maybePop` se agenda con
        // `addPostFrameCallback` para que el PopScope ya esté con
        // `canPop=true` cuando el pop se intente. El `finally` re-pone
        // `_saving=false` de forma idempotente si seguimos montados.
        setState(() => _saving = false);
        if (_isEdit) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).maybePop();
          });
        } else {
          // Alta: resetea el stack al Dashboard. Predecible y simple.
          context.go('/dashboard');
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

  void _showFieldError(String msg) {
    showWarningSnackbar(context, msg);
  }

  Future<void> _cancel() async {
    final deps = AppDependencies.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: 'Cancelar movimiento',
      message: '¿Cancelar este movimiento? Esta acción es definitiva.',
      confirmLabel: 'Cancelar movimiento',
    );
    if (!confirmed) return;
    if (!mounted) return;
    setState(() => _saving = true);
    try {
      await deps.entriesDao.cancel(widget.entryId!);
      if (mounted) {
        showSuccessSnackbar(context, 'Movimiento cancelado.');
        // Resetear _saving ANTES del pop (ver comentario en `build()`).
        // El `maybePop` se agenda con `addPostFrameCallback` para que el
        // PopScope ya esté reconstruido con `canPop=true`.
        setState(() => _saving = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).maybePop();
        });
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
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_isEdit ? 'Editar movimiento' : 'Nuevo movimiento'),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: const [
                Skeleton(width: double.infinity, height: 56, radius: 8),
                SizedBox(height: 16),
                Skeleton(width: double.infinity, height: 56, radius: 8),
                SizedBox(height: 16),
                Skeleton(width: double.infinity, height: 56, radius: 8),
                SizedBox(height: 16),
                Skeleton(width: double.infinity, height: 56, radius: 8),
                SizedBox(height: 16),
                Skeleton(width: double.infinity, height: 56, radius: 8),
              ],
            ),
          ),
        ),
      );
    }

    if (_bootstrapError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: FincoreColors.negative),
                const SizedBox(height: 16),
                Text(_bootstrapError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: FincoreColors.textPrimary)),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Volver'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return PopScope(
      // Mientras hay save en curso, NO permitir back: evita race entre el
      // DAO escribiendo y el reset del form (o el pop desde otro lugar).
      //
      // Hotfix post-smoke 2026-06-19 (bug "pantalla gris muerto"): cuando
      // el back lo dispara `_cancel`/`_submit` programáticamente vía
      // `Navigator.maybePop()`, el flujo previo cancelaba el pop (canPop
      // false por `_saving=true`) y `onPopInvokedWithResult` reseteaba
      // `_kind = null` en plena edición. En el siguiente rebuild,
      // `_buildForm()` crasheaba en `final k = _kind!;` y Flutter
      // renderizaba `ErrorWidget` gris pleno sin AppBar. Solución:
      //   1) `_cancel`/`_submit` ahora hacen `setState(_saving = false)`
      //      antes del `maybePop`, así canPop pasa a true y el pop ocurre.
      //   2) El callback de PopScope solo resetea el form en alta con kind
      //      ya elegido (caso "back desde KindPicker → todo limpio").
      //      Nunca toca `_kind` cuando `_isEdit`.
      canPop: (_isEdit || _kind == null) && !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_isEdit) return; // no resetear nada en edit
        if (_kind == null) return; // ya estamos en KindPicker
        // Back desde el form alta: vuelve al KindPicker con todo limpio.
        setState(() {
          _kind = null;
          _originId = null;
          _destId = null;
          _categoryId = null;
          _occurredAt = DateTime.now();
          _amountCtrl.clear();
          _descCtrl.clear();
          _formKey.currentState?.reset();
        });
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEdit ? 'Editar movimiento' : 'Nuevo movimiento'),
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (!_isEdit && _kind == null)
                  KindPicker(value: _kind, onChanged: _selectKind)
                else
                  _buildForm(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    final k = _kind!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_isEdit)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: FincoreColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: FincoreColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: FincoreColors.textMuted),
                const SizedBox(width: 8),
                Text(k.label,
                    style: const TextStyle(color: FincoreColors.textMuted, fontSize: 12)),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Tooltip(
              message: 'Cambiar tipo de movimiento',
              child: TextButton.icon(
                icon: const Icon(Icons.swap_horiz, size: 16),
                label: Text('Cambiar tipo (${k.label})'),
                onPressed: _saving ? null : () => setState(() => _kind = null),
              ),
            ),
          ),
        if (_needsOrigin(k)) ...[
          AccountPicker(
            label: _originLabel(k),
            accounts: _accounts,
            allowedTypes: _originTypes(k),
            selectedId: _originId,
            onChanged: (v) => setState(() => _originId = v),
            excludeId: k == JournalKind.transfer ? _destId : null,
          ),
          AccountBalanceHint(accountId: _originId, accounts: _accounts),
          const SizedBox(height: 24),
        ],
        if (_needsDestination(k)) ...[
          AccountPicker(
            label: _destLabel(k),
            accounts: _accounts,
            allowedTypes: _destTypes(k),
            selectedId: _destId,
            onChanged: (v) => setState(() => _destId = v),
            excludeId: k == JournalKind.transfer ? _originId : null,
          ),
          AccountBalanceHint(accountId: _destId, accounts: _accounts),
          const SizedBox(height: 24),
        ],
        TextFormField(
          controller: _amountCtrl,
          decoration: const InputDecoration(
            labelText: 'Monto',
            prefixText: r'$ ',
            helperText: ' ',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Ingresá el monto.';
            final n = double.tryParse(v);
            if (n == null || n <= 0) return 'Debe ser mayor a 0.';
            return null;
          },
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(8),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Fecha',
              suffixIcon: Icon(Icons.calendar_today_outlined),
            ),
            child: Text(
              DateFormat('EEEE d MMM y', 'es_MX').format(_occurredAt),
              style: const TextStyle(color: FincoreColors.textPrimary),
            ),
          ),
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _descCtrl,
          decoration: const InputDecoration(labelText: 'Descripción (opcional)'),
          textCapitalization: TextCapitalization.sentences,
          maxLines: 2,
          maxLength: 200,
        ),
        if (k.acceptsCategory) ...[
          const SizedBox(height: 8),
          CategoryPicker(
            categories: _categories,
            validAppliesTo: k.validCategoryAppliesTo,
            selectedId: _categoryId,
            onChanged: (v) => setState(() => _categoryId = v),
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
              : Text(_isEdit ? 'Guardar cambios' : 'Registrar movimiento'),
        ),
        if (_isEdit) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _saving ? null : _cancel,
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Cancelar movimiento'),
            style: OutlinedButton.styleFrom(
              foregroundColor: FincoreColors.negative,
              side: const BorderSide(color: FincoreColors.negative),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ],
    );
  }

  bool _needsOrigin(JournalKind k) => k != JournalKind.income;
  bool _needsDestination(JournalKind k) =>
      k == JournalKind.income || k == JournalKind.debtPayment || k == JournalKind.transfer;

  String _originLabel(JournalKind k) => switch (k) {
        JournalKind.expense => 'Cuenta origen',
        JournalKind.creditExpense => 'Tarjeta',
        JournalKind.debtPayment => 'Pagás desde',
        JournalKind.transfer => 'Cuenta origen',
        JournalKind.income => '',
      };
  String _destLabel(JournalKind k) => switch (k) {
        JournalKind.income => 'Cuenta destino',
        JournalKind.debtPayment => 'Tarjeta a pagar',
        JournalKind.transfer => 'Cuenta destino',
        JournalKind.expense || JournalKind.creditExpense => '',
      };
  List<String> _originTypes(JournalKind k) => switch (k) {
        JournalKind.expense || JournalKind.debtPayment || JournalKind.transfer =>
          const ['cash', 'debit'],
        JournalKind.creditExpense => const ['credit'],
        JournalKind.income => const [],
      };
  List<String> _destTypes(JournalKind k) => switch (k) {
        JournalKind.income || JournalKind.transfer => const ['cash', 'debit'],
        JournalKind.debtPayment => const ['credit'],
        JournalKind.expense || JournalKind.creditExpense => const [],
      };
}

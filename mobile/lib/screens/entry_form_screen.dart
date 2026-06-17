import 'package:fincore/api/entries_api.dart';
import 'package:fincore/app_dependencies.dart';
import 'package:fincore/constants/account_types.dart';
import 'package:fincore/constants/kinds.dart';
import 'package:fincore/models/account.dart';
import 'package:fincore/models/category.dart';
import 'package:fincore/models/domain_error.dart';
import 'package:fincore/models/journal_entry.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/widgets/account_picker.dart';
import 'package:fincore/widgets/category_picker.dart';
import 'package:fincore/widgets/confirm_dialog.dart';
import 'package:fincore/widgets/error_snackbar.dart';
import 'package:fincore/widgets/kind_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class EntryFormScreen extends StatefulWidget {
  /// Si null → crear. Si presente → editar.
  final String? entryId;
  const EntryFormScreen({super.key, this.entryId});

  @override
  State<EntryFormScreen> createState() => _EntryFormScreenState();
}

class _EntryFormScreenState extends State<EntryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  JournalKind? _kind;
  String? _accountOriginId;
  String? _accountDestinationId;
  String? _categoryId;
  DateTime _occurredAt = DateTime.now();

  List<Account> _accounts = const [];
  List<Category> _categories = const [];

  bool _loading = true;
  bool _saving = false;

  bool get _isEdit => widget.entryId != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_accounts.isEmpty && _loading) _bootstrap();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final deps = AppDependencies.of(context);
    try {
      final accountsFuture = deps.accountsApi.list();
      final categoriesFuture = deps.categoriesApi.list();
      final results = await Future.wait([accountsFuture, categoriesFuture]);
      _accounts = results[0] as List<Account>;
      _categories = results[1] as List<Category>;

      if (_isEdit) {
        final entries = await deps.entriesApi.list(const EntriesFilter());
        final entry = entries.data.firstWhere(
          (e) => e.id == widget.entryId,
          orElse: () => throw Exception('Movimiento no encontrado en la página actual.'),
        );
        _kind = entry.kind;
        _accountOriginId = entry.accountOriginId;
        _accountDestinationId = entry.accountDestinationId;
        _categoryId = entry.categoryId;
        _occurredAt = entry.occurredAt;
        _amountCtrl.text = entry.amount.toString();
        _descriptionCtrl.text = entry.description ?? '';
      }
    } on DomainError catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectKind(JournalKind k) {
    setState(() {
      _kind = k;
      // Reset selectores que pueden volverse incompatibles.
      _accountOriginId = null;
      _accountDestinationId = null;
      _categoryId = null;
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
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    if (_kind == null) return;
    final deps = AppDependencies.of(context);

    final amount = num.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) return;
    final description = _descriptionCtrl.text.trim().isEmpty ? null : _descriptionCtrl.text.trim();

    setState(() => _saving = true);
    try {
      if (_isEdit) {
        final fields = <String, dynamic>{
          'amount': amount,
          'description': description,
          'occurred_at': _occurredAt.toIso8601String(),
          'category_id': _kind!.acceptsCategory ? _categoryId : null,
          if (_accountOriginId != null) 'account_origin_id': _accountOriginId,
          if (_accountDestinationId != null) 'account_destination_id': _accountDestinationId,
        };
        await deps.entriesApi.update(widget.entryId!, fields);
      } else {
        await _createByKind(deps, amount, description);
      }
      if (mounted) {
        showSuccessSnackbar(context, _isEdit ? 'Movimiento actualizado.' : 'Movimiento creado.');
        context.go('/dashboard');
      }
    } on DomainError catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<JournalEntry> _createByKind(AppDependencies deps, num amount, String? description) {
    switch (_kind!) {
      case JournalKind.income:
        return deps.entriesApi.registerIncome(
          accountDestinationId: _accountDestinationId!,
          amount: amount,
          occurredAt: _occurredAt,
          description: description,
          categoryId: _categoryId,
        );
      case JournalKind.expense:
        return deps.entriesApi.registerExpense(
          accountOriginId: _accountOriginId!,
          amount: amount,
          occurredAt: _occurredAt,
          description: description,
          categoryId: _categoryId,
        );
      case JournalKind.creditExpense:
        return deps.entriesApi.registerCreditExpense(
          accountOriginId: _accountOriginId!,
          amount: amount,
          occurredAt: _occurredAt,
          description: description,
          categoryId: _categoryId,
        );
      case JournalKind.debtPayment:
        return deps.entriesApi.registerDebtPayment(
          accountOriginId: _accountOriginId!,
          accountDestinationId: _accountDestinationId!,
          amount: amount,
          occurredAt: _occurredAt,
          description: description,
        );
      case JournalKind.transfer:
        return deps.entriesApi.registerTransfer(
          accountOriginId: _accountOriginId!,
          accountDestinationId: _accountDestinationId!,
          amount: amount,
          occurredAt: _occurredAt,
          description: description,
        );
    }
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
      await deps.entriesApi.cancel(widget.entryId!);
      if (mounted) {
        showSuccessSnackbar(context, 'Movimiento cancelado.');
        context.go('/entries');
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

    final title = _isEdit ? 'Editar movimiento' : 'Nuevo movimiento';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(_isEdit ? '/entries' : '/dashboard'),
        ),
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
                _buildFormForKind(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormForKind() {
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
                Text('Tipo: ${k.label} (no editable)',
                    style: const TextStyle(color: FincoreColors.textMuted, fontSize: 12)),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: TextButton.icon(
              icon: const Icon(Icons.swap_horiz, size: 16),
              label: Text('Cambiar tipo (${k.label})'),
              onPressed: () => setState(() => _kind = null),
            ),
          ),

        // Origin
        if (_needsOrigin(k)) ...[
          AccountPicker(
            label: _originLabel(k),
            accounts: _accounts,
            allowedTypes: _originTypes(k),
            selectedId: _accountOriginId,
            onChanged: (v) => setState(() => _accountOriginId = v),
            excludeId: k == JournalKind.transfer ? _accountDestinationId : null,
          ),
          const SizedBox(height: 12),
        ],

        // Destination
        if (_needsDestination(k)) ...[
          AccountPicker(
            label: _destinationLabel(k),
            accounts: _accounts,
            allowedTypes: _destinationTypes(k),
            selectedId: _accountDestinationId,
            onChanged: (v) => setState(() => _accountDestinationId = v),
            excludeId: k == JournalKind.transfer ? _accountOriginId : null,
          ),
          const SizedBox(height: 12),
        ],

        // Amount
        TextFormField(
          controller: _amountCtrl,
          decoration: const InputDecoration(labelText: 'Monto', prefixText: r'$ '),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Ingresá el monto.';
            final n = num.tryParse(v);
            if (n == null || n <= 0) return 'Debe ser mayor a 0.';
            return null;
          },
        ),
        const SizedBox(height: 12),

        // Date
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
        const SizedBox(height: 12),

        // Description
        TextFormField(
          controller: _descriptionCtrl,
          decoration: const InputDecoration(
            labelText: 'Descripción (opcional)',
          ),
          textCapitalization: TextCapitalization.sentences,
          maxLines: 2,
          maxLength: 200,
        ),

        // Category
        if (k.acceptsCategory) ...[
          const SizedBox(height: 12),
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
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: FincoreColors.canvas,
                  ),
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

  String _originLabel(JournalKind k) {
    switch (k) {
      case JournalKind.expense:
        return 'Cuenta origen';
      case JournalKind.creditExpense:
        return 'Tarjeta';
      case JournalKind.debtPayment:
        return 'Pagás desde';
      case JournalKind.transfer:
        return 'Cuenta origen';
      case JournalKind.income:
        return '';
    }
  }

  String _destinationLabel(JournalKind k) {
    switch (k) {
      case JournalKind.income:
        return 'Cuenta destino';
      case JournalKind.debtPayment:
        return 'Tarjeta a pagar';
      case JournalKind.transfer:
        return 'Cuenta destino';
      case JournalKind.expense:
      case JournalKind.creditExpense:
        return '';
    }
  }

  List<AccountType> _originTypes(JournalKind k) {
    switch (k) {
      case JournalKind.expense:
        return const [AccountType.cash, AccountType.debit];
      case JournalKind.creditExpense:
        return const [AccountType.credit];
      case JournalKind.debtPayment:
        return const [AccountType.cash, AccountType.debit];
      case JournalKind.transfer:
        return const [AccountType.cash, AccountType.debit];
      case JournalKind.income:
        return const [];
    }
  }

  List<AccountType> _destinationTypes(JournalKind k) {
    switch (k) {
      case JournalKind.income:
        return const [AccountType.cash, AccountType.debit];
      case JournalKind.debtPayment:
        return const [AccountType.credit];
      case JournalKind.transfer:
        return const [AccountType.cash, AccountType.debit];
      case JournalKind.expense:
      case JournalKind.creditExpense:
        return const [];
    }
  }
}


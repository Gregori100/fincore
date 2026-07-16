import 'package:fincore/app_dependencies.dart';
import 'package:fincore/constants/account_types.dart';
import 'package:fincore/data/daos/accounts_dao.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/theme/fincore_radii.dart';
import 'package:fincore/theme/fincore_spacing.dart';
import 'package:fincore/widgets/account_type_picker.dart';
import 'package:fincore/widgets/confirm_dialog.dart';
import 'package:fincore/widgets/destructive_dialog.dart';
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

  AccountType _type = AccountType.debit;
  bool _saving = false;
  bool _loading = false;
  bool _loaded = false;
  Account? _existing;

  bool get _isEdit => widget.accountId != null;
  bool get _isProtected => _existing?.isProtected ?? false;
  bool get _isArchived => _existing?.archivedAt != null;

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
    super.dispose();
  }

  Future<void> _loadAccount() async {
    final deps = AppDependencies.of(context);
    setState(() => _loading = true);
    try {
      // Sprint flutter-accounts-archive-v1: findActiveOrArchivedById para que
      // deep-link a /accounts/{id}/edit con cuenta archivada resuelva y muestre
      // el modo read-only, en vez de fallar con `not_found`.
      final account =
          await deps.accountsDao.findActiveOrArchivedById(widget.accountId!);
      if (account == null) {
        throw const AccountsDaoError('not_found', 'Cuenta no encontrada.');
      }
      setState(() {
        _existing = account;
        _type = parseAccountType(account.type);
        _nameCtrl.text = account.name;
        _descCtrl.text = account.description ?? '';
        if (account.type == 'credit') {
          _creditLimitCtrl.text = account.creditLimit.toStringAsFixed(2);
          _closingDayCtrl.text = account.closingDay?.toString() ?? '';
          _paymentDayCtrl.text = account.paymentDay?.toString() ?? '';
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
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          creditLimit: _type == AccountType.credit
              ? _parseDecimalInput(_creditLimitCtrl.text)
              : null,
          closingDay: _type == AccountType.credit
              ? int.tryParse(_closingDayCtrl.text)
              : null,
          paymentDay: _type == AccountType.credit
              ? int.tryParse(_paymentDayCtrl.text)
              : null,
        );
      } else {
        await deps.accountsDao.create(
          name: _nameCtrl.text.trim(),
          type: _type.apiValue,
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          creditLimit: _type == AccountType.credit
              ? _parseDecimalInput(_creditLimitCtrl.text)
              : null,
          closingDay: _type == AccountType.credit
              ? int.tryParse(_closingDayCtrl.text)
              : null,
          paymentDay: _type == AccountType.credit
              ? int.tryParse(_paymentDayCtrl.text)
              : null,
        );
      }
      if (mounted) {
        showSuccessSnackbar(
            context, _isEdit ? 'Cuenta actualizada.' : 'Cuenta creada.');
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

  double? _parseDecimalInput(String text) {
    return double.tryParse(text.trim().replaceAll(',', '.'));
  }

  Future<void> _confirmArchive() async {
    final deps = AppDependencies.of(context);
    final ok = await showConfirmDialog(
      context,
      title: 'Archivar cuenta',
      message:
          '"${_existing!.name}" ya no aparecerá al registrar movimientos, '
          'pero sigue en tu histórico y en reportes. Puedes desarchivarla '
          'cuando quieras.',
      confirmLabel: 'Archivar',
      destructive: false,
    );
    if (!ok || !mounted) return;
    setState(() => _saving = true);
    try {
      await deps.accountsDao.archive(widget.accountId!);
      if (mounted) {
        showSuccessSnackbar(context, 'Cuenta archivada.');
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

  Future<void> _confirmUnarchive() async {
    final deps = AppDependencies.of(context);
    final ok = await showConfirmDialog(
      context,
      title: 'Desarchivar cuenta',
      message:
          '"${_existing!.name}" vuelve a estar disponible para registrar '
          'movimientos.',
      confirmLabel: 'Desarchivar',
      destructive: false,
    );
    if (!ok || !mounted) return;
    setState(() => _saving = true);
    try {
      await deps.accountsDao.unarchive(widget.accountId!);
      if (mounted) {
        showSuccessSnackbar(context, 'Cuenta desarchivada.');
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

  Future<void> _confirmDelete() async {
    final deps = AppDependencies.of(context);
    setState(() => _saving = true);
    final int affected;
    try {
      affected =
          await deps.accountsDao.countAssociatedEntries(widget.accountId!);
    } catch (e) {
      if (mounted) {
        showErrorSnackbar(context, e);
        setState(() => _saving = false);
      }
      return;
    }
    if (!mounted) return;
    setState(() => _saving = false);

    final impacts = <DestructiveImpact>[
      DestructiveImpact(
        icon: Icons.receipt_long_outlined,
        label: affected == 0
            ? 'Sin movimientos'
            : '$affected ${affected == 1 ? "movimiento" : "movimientos"} '
                '${affected == 1 ? "se cancelará" : "se cancelarán"}',
      ),
      const DestructiveImpact(
        icon: Icons.history_toggle_off,
        label: 'No se puede deshacer',
      ),
    ];
    final description = affected == 0
        ? 'La cuenta no tiene movimientos activos. Se elimina permanentemente.'
        : 'Se cancelarán todos los movimientos donde esta cuenta figura como '
            'origen o destino (incluidos pagos a tarjetas y transferencias).';

    final confirmed = await showDestructiveDialog(
      context,
      title: 'Eliminar cuenta',
      objectName: _existing!.name,
      icon: Icons.delete_forever_outlined,
      impacts: impacts,
      description: description,
      confirmLabel:
          affected == 0 ? 'Eliminar' : 'Eliminar y cancelar movimientos',
    );
    if (!confirmed || !mounted) return;

    setState(() => _saving = true);
    try {
      await deps.accountsDao
          .deleteAccount(widget.accountId!, deps.stateService);
      if (mounted) {
        showSuccessSnackbar(
          context,
          affected == 0
              ? 'Cuenta eliminada.'
              : 'Cuenta eliminada. $affected movimientos cancelados.',
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

  List<PopupMenuEntry<_AccountFormAction>> _buildMenuItems() {
    if (_isArchived) {
      return const [
        PopupMenuItem(
          value: _AccountFormAction.unarchive,
          child: ListTile(
            leading: Icon(Icons.unarchive_outlined,
                color: FincoreColors.accent),
            title: Text('Desarchivar'),
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: _AccountFormAction.delete,
          child: ListTile(
            leading: Icon(Icons.delete_outline,
                color: FincoreColors.negative),
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
        value: _AccountFormAction.archive,
        child: ListTile(
          leading: Icon(Icons.archive_outlined,
              color: FincoreColors.textPrimary),
          title: Text('Archivar'),
          contentPadding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
      ),
      PopupMenuDivider(),
      PopupMenuItem(
        value: _AccountFormAction.delete,
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

  void _handleMenuAction(_AccountFormAction action) {
    switch (action) {
      case _AccountFormAction.archive:
        _confirmArchive();
        return;
      case _AccountFormAction.unarchive:
        _confirmUnarchive();
        return;
      case _AccountFormAction.delete:
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
    if (_isProtected) {
      return _ProtectedView(name: _existing!.name);
    }

    final readOnly = _isArchived;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit
            ? (readOnly ? 'Cuenta archivada' : 'Editar cuenta')
            : 'Nueva cuenta'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          if (_isEdit)
            PopupMenuButton<_AccountFormAction>(
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
              if (readOnly) ...[
                _ArchivedBanner(name: _existing!.name),
                const SizedBox(height: kSpaceLg),
              ],
              if (!_isEdit) ...[
                const Text('Tipo de cuenta',
                    style: TextStyle(
                        color: FincoreColors.textMuted, fontSize: 13)),
                const SizedBox(height: kSpaceSm),
                AccountTypePicker(
                  value: _type,
                  onChanged: (t) => setState(() => _type = t),
                  enabled: !_saving,
                ),
                const SizedBox(height: kSpaceXl),
              ],
              TextFormField(
                controller: _nameCtrl,
                enabled: !readOnly,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  helperText: ' ',
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Ingresar un nombre.'
                    : null,
              ),
              const SizedBox(height: kSpaceLg),
              TextFormField(
                controller: _descCtrl,
                enabled: !readOnly,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                  helperText: 'Alias, banco, últimos 4 dígitos…',
                ),
                maxLength: 200,
                maxLines: 2,
              ),
              if (_type == AccountType.credit) ...[
                const SizedBox(height: kSpaceSm),
                const Divider(),
                const SizedBox(height: kSpaceLg),
                const Text('Datos de la tarjeta',
                    style: TextStyle(
                      color: FincoreColors.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    )),
                const SizedBox(height: kSpaceMd),
                TextFormField(
                  controller: _creditLimitCtrl,
                  enabled: !readOnly,
                  decoration: const InputDecoration(
                    labelText: 'Límite de crédito',
                    prefixText: r'$ ',
                    helperText: ' ',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Requerido.';
                    final n = _parseDecimalInput(v);
                    if (n == null || n < 0) return 'No puede ser negativo.';
                    return null;
                  },
                ),
                const SizedBox(height: kSpaceMd),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _closingDayCtrl,
                        enabled: !readOnly,
                        decoration: const InputDecoration(
                          labelText: 'Día de corte',
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
                          if (n == null || n < 1 || n > 31) {
                            return 'Debe estar entre 1 y 31.';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: kSpaceMd),
                    Expanded(
                      child: TextFormField(
                        controller: _paymentDayCtrl,
                        enabled: !readOnly,
                        decoration: const InputDecoration(
                          labelText: 'Día de pago',
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
                          if (n == null || n < 1 || n > 31) {
                            return 'Debe estar entre 1 y 31.';
                          }
                          if (_closingDayCtrl.text.isNotEmpty &&
                              n == int.tryParse(_closingDayCtrl.text)) {
                            return 'Debe ser un día distinto al corte.';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: kSpace2xl),
              if (!readOnly)
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
                      : Text(_isEdit ? 'Guardar cambios' : 'Crear cuenta'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _AccountFormAction { archive, unarchive, delete }

/// Banner que se muestra arriba del form cuando la cuenta está archivada.
/// Alterna el título de la pantalla y bloquea la edición: los campos siguen
/// visibles para consulta pero deshabilitados; el botón Guardar desaparece.
class _ArchivedBanner extends StatelessWidget {
  final String name;
  const _ArchivedBanner({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: kSpaceLg, vertical: kSpaceMd),
      decoration: BoxDecoration(
        color: FincoreColors.categoryPurple
            .withValues(alpha: FincoreColors.alphaTint),
        borderRadius: BorderRadius.circular(kRadiusMd),
        border: Border.all(
          color: FincoreColors.categoryPurple
              .withValues(alpha: FincoreColors.alphaHairline),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.archive_outlined,
              color: FincoreColors.categoryPurple, size: 20),
          SizedBox(width: kSpaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cuenta archivada',
                  style: TextStyle(
                    color: FincoreColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: kSpace2xs),
                Text(
                  'No se puede editar. Sigue apareciendo en /entries y en '
                  'reportes. Desde el menú puedes desarchivarla o '
                  'eliminarla.',
                  style: TextStyle(
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
              Icon(Icons.lock_outline,
                  size: 48, color: FincoreColors.textMuted),
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

import 'package:drift/drift.dart' show Value;
import 'package:fincore/app_dependencies.dart';
import 'package:fincore/constants/category_catalog.dart';
import 'package:fincore/data/daos/categories_dao.dart';
import 'package:fincore/data/database.dart' as db;
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/widgets/applies_to_picker.dart';
import 'package:fincore/widgets/color_picker.dart';
import 'package:fincore/widgets/destructive_dialog.dart';
import 'package:fincore/widgets/error_snackbar.dart';
import 'package:fincore/widgets/icon_picker.dart';
import 'package:fincore/utils/money.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CategoryFormScreen extends StatefulWidget {
  final String? categoryId;
  const CategoryFormScreen({super.key, this.categoryId});

  @override
  State<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends State<CategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  // Sprint flutter-budgets-v1: input opcional del presupuesto mensual.
  // El usuario tipea en pesos; la BD guarda como double directo.
  final _monthlyLimitCtrl = TextEditingController();
  String _appliesTo = 'expense';
  String _colorSlug = 'blue';
  String _iconSlug = 'tag';
  bool _saving = false;
  bool _loading = false;
  bool _loaded = false;
  db.Category? _existing;

  bool get _isEdit => widget.categoryId != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    if (_isEdit) _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _monthlyLimitCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final deps = AppDependencies.of(context);
    setState(() => _loading = true);
    try {
      final c = await deps.categoriesDao.findById(widget.categoryId!);
      if (c == null) {
        throw const CategoriesDaoError('not_found', 'Categoría no encontrada.');
      }
      setState(() {
        _existing = c;
        _nameCtrl.text = c.name;
        _appliesTo = c.appliesTo;
        _colorSlug = c.colorSlug;
        _iconSlug = c.iconSlug;
        // Sprint flutter-budgets-v1: cargar el presupuesto guardado; si es
        // null, dejar el input vacío. Se formatea sin decimales cuando el
        // valor es entero para que no se vea "5000.00" cuando el usuario
        // escribió "5000".
        if (c.monthlyLimit != null) {
          final v = c.monthlyLimit!;
          _monthlyLimitCtrl.text = v == v.truncateToDouble()
              ? v.toInt().toString()
              : v.toStringAsFixed(2);
        }
      });
    } on CategoriesDaoError catch (e) {
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
      // Sprint flutter-budgets-v1: applies_to=income fuerza monthlyLimit=null
      // en el submit (defensivo contra edición del picker con budget previo).
      final monthlyLimitValue = _appliesTo == 'income'
          ? null
          : _parseDecimalInput(_monthlyLimitCtrl.text);
      if (_isEdit) {
        await deps.categoriesDao.updateCategory(
          id: widget.categoryId!,
          name: _nameCtrl.text.trim(),
          appliesTo: _appliesTo,
          colorSlug: _colorSlug,
          iconSlug: _iconSlug,
          // Value<double?> distingue "no cambiar" (Value.absent) de
          // "setear a null" (Value(null)) para permitir limpiar el budget
          // al cambiar applies_to a income.
          monthlyLimit: Value(monthlyLimitValue),
        );
      } else {
        await deps.categoriesDao.create(
          name: _nameCtrl.text.trim(),
          appliesTo: _appliesTo,
          colorSlug: _colorSlug,
          iconSlug: _iconSlug,
          monthlyLimit: monthlyLimitValue,
        );
      }
      if (mounted) {
        showSuccessSnackbar(context, _isEdit ? 'Categoría actualizada.' : 'Categoría creada.');
        Navigator.of(context).maybePop();
      }
    } on CategoriesDaoError catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Parsea el input del usuario a **centavos**. `null` si no es un monto
  /// válido — el validador del form muestra el error correspondiente.
  int? _parseDecimalInput(String text) {
    try {
      return parseCents(text);
    } on FormatException {
      return null;
    }
  }

  Future<void> _archive() async {
    final deps = AppDependencies.of(context);
    // Conteo de movimientos que quedarán huérfanos ANTES de mostrar la
    // confirmación, para que el usuario dimensione el impacto real.
    setState(() => _saving = true);
    final int affected;
    try {
      affected =
          await deps.categoriesDao.countAssociatedEntries(widget.categoryId!);
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
      if (affected > 0)
        DestructiveImpact(
          icon: Icons.receipt_long_outlined,
          label: '$affected ${affected == 1 ? "movimiento" : "movimientos"} '
              '${affected == 1 ? "quedará" : "quedarán"} huérfanos '
              '(aparecerán como "Sin categoría").',
        ),
      if (affected > 0)
        const DestructiveImpact(
          icon: Icons.account_balance_wallet_outlined,
          label: 'Los saldos y montos no se modifican.',
        ),
      if (affected == 0)
        const DestructiveImpact(
          icon: Icons.check_circle_outline,
          label: 'Ningún movimiento activo usa esta categoría.',
        ),
    ];
    final description = affected == 0
        ? 'La categoría dejará de aparecer en pickers y reportes.'
        : 'La categoría dejará de aparecer en pickers y reportes. Los '
            'movimientos existentes conservan la referencia interna pero '
            'el badge de color ya no se mostrará.';

    final confirmed = await showDestructiveDialog(
      context,
      title: 'Archivar categoría',
      objectName: _existing!.name,
      icon: Icons.archive_outlined,
      impacts: impacts,
      description: description,
      confirmLabel:
          affected == 0 ? 'Archivar' : 'Archivar y dejar huérfanos',
    );
    if (!confirmed) return;
    if (!mounted) return;
    setState(() => _saving = true);
    try {
      await deps.categoriesDao.archive(widget.categoryId!);
      if (mounted) {
        showSuccessSnackbar(context, 'Categoría archivada.');
        Navigator.of(context).maybePop();
      }
    } on CategoriesDaoError catch (e) {
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
        title: Text(_isEdit ? 'Editar categoría' : 'Nueva categoría'),
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
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: colorBySlug(_colorSlug).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colorBySlug(_colorSlug).withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(iconBySlug(_iconSlug), color: colorBySlug(_colorSlug), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        _nameCtrl.text.trim().isEmpty
                            ? 'Vista previa'
                            : _nameCtrl.text.trim(),
                        style: TextStyle(
                            color: colorBySlug(_colorSlug),
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  helperText: ' ',
                ),
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Ingresar un nombre.' : null,
              ),
              const SizedBox(height: 16),
              const Text('Aplica a', style: TextStyle(color: FincoreColors.textMuted, fontSize: 13)),
              const SizedBox(height: 8),
              AppliesToPicker(
                value: _appliesTo,
                onChanged: (v) => setState(() {
                  _appliesTo = v;
                  // Sprint flutter-budgets-v1: limpiar el input de presupuesto
                  // si el usuario cambia a income (los ingresos no reciben
                  // presupuesto de gasto).
                  if (v == 'income') _monthlyLimitCtrl.clear();
                }),
                enabled: !_saving,
              ),
              if (_appliesTo != 'income') ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _monthlyLimitCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Presupuesto mensual',
                    prefixText: r'$ ',
                    helperText:
                        'Opcional. \$ 0 = meta de no gastar en esta categoría.',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final n = _parseDecimalInput(v);
                    if (n == null) return 'Debe ser numérico.';
                    if (n < 0) return 'No puede ser negativo.';
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 24),
              const Text('Color', style: TextStyle(color: FincoreColors.textMuted, fontSize: 13)),
              const SizedBox(height: 8),
              ColorPicker(
                selectedSlug: _colorSlug,
                onChanged: (s) => setState(() => _colorSlug = s),
              ),
              const SizedBox(height: 24),
              const Text('Ícono', style: TextStyle(color: FincoreColors.textMuted, fontSize: 13)),
              const SizedBox(height: 8),
              IconPicker(
                selectedSlug: _iconSlug,
                selectionColor: colorBySlug(_colorSlug),
                onChanged: (s) => setState(() => _iconSlug = s),
              ),
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
                    : Text(_isEdit ? 'Guardar cambios' : 'Crear categoría'),
              ),
              if (_isEdit) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _archive,
                  icon: const Icon(Icons.archive_outlined),
                  label: const Text('Archivar categoría'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: FincoreColors.warning,
                    side: const BorderSide(color: FincoreColors.border),
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

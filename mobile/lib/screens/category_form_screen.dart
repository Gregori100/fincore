import 'package:fincore/app_dependencies.dart';
import 'package:fincore/constants/category_catalog.dart';
import 'package:fincore/data/daos/categories_dao.dart';
import 'package:fincore/data/database.dart' as db;
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/widgets/applies_to_picker.dart';
import 'package:fincore/widgets/color_picker.dart';
import 'package:fincore/widgets/confirm_dialog.dart';
import 'package:fincore/widgets/error_snackbar.dart';
import 'package:fincore/widgets/icon_picker.dart';
import 'package:flutter/material.dart';

class CategoryFormScreen extends StatefulWidget {
  final String? categoryId;
  const CategoryFormScreen({super.key, this.categoryId});

  @override
  State<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends State<CategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
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
      if (_isEdit) {
        await deps.categoriesDao.updateCategory(
          id: widget.categoryId!,
          name: _nameCtrl.text.trim(),
          appliesTo: _appliesTo,
          colorSlug: _colorSlug,
          iconSlug: _iconSlug,
        );
      } else {
        await deps.categoriesDao.create(
          name: _nameCtrl.text.trim(),
          appliesTo: _appliesTo,
          colorSlug: _colorSlug,
          iconSlug: _iconSlug,
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

  Future<void> _archive() async {
    final deps = AppDependencies.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: 'Archivar categoría',
      message: '¿Archivar "${_existing!.name}"? Los movimientos existentes la conservan en la base, '
          'pero el badge no aparecerá más.',
      confirmLabel: 'Archivar',
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
                    (v == null || v.trim().isEmpty) ? 'Ingresá un nombre.' : null,
              ),
              const SizedBox(height: 16),
              const Text('Aplica a', style: TextStyle(color: FincoreColors.textMuted, fontSize: 13)),
              const SizedBox(height: 8),
              AppliesToPicker(
                value: _appliesTo,
                onChanged: (v) => setState(() => _appliesTo = v),
                enabled: !_saving,
              ),
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

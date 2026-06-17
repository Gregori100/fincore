import 'package:fincore/app_dependencies.dart';
import 'package:fincore/constants/category_catalog.dart';
import 'package:fincore/models/category.dart';
import 'package:fincore/models/domain_error.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/widgets/applies_to_picker.dart';
import 'package:fincore/widgets/category_badge.dart';
import 'package:fincore/widgets/color_picker.dart';
import 'package:fincore/widgets/confirm_dialog.dart';
import 'package:fincore/widgets/error_snackbar.dart';
import 'package:fincore/widgets/icon_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
  Category? _existing;
  bool _loaded = false;

  bool get _isEdit => widget.categoryId != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    if (_isEdit) _loadCategory();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategory() async {
    final deps = AppDependencies.of(context);
    setState(() => _loading = true);
    try {
      final categories = await deps.categoriesApi.list(includeArchived: true);
      final category = categories.firstWhere(
        (c) => c.id == widget.categoryId,
        orElse: () => throw Exception('Categoría no encontrada.'),
      );
      setState(() {
        _existing = category;
        _nameCtrl.text = category.name;
        _appliesTo = category.appliesTo;
        _colorSlug = category.colorSlug;
        _iconSlug = category.iconSlug;
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
        await deps.categoriesApi.update(widget.categoryId!, <String, dynamic>{
          'name': _nameCtrl.text.trim(),
          'applies_to': _appliesTo,
          'color_slug': _colorSlug,
          'icon_slug': _iconSlug,
        });
      } else {
        await deps.categoriesApi.create(
          name: _nameCtrl.text.trim(),
          appliesTo: _appliesTo,
          colorSlug: _colorSlug,
          iconSlug: _iconSlug,
        );
      }
      if (mounted) {
        showSuccessSnackbar(context, _isEdit ? 'Categoría actualizada.' : 'Categoría creada.');
        context.go('/categories');
      }
    } on DomainError catch (e) {
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
          'pero el badge no aparecerá más en la UI.',
      confirmLabel: 'Archivar',
    );
    if (!confirmed) return;
    if (!mounted) return;

    setState(() => _saving = true);
    try {
      await deps.categoriesApi.archive(widget.categoryId!);
      if (mounted) {
        showSuccessSnackbar(context, 'Categoría archivada.');
        context.go('/categories');
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

    final title = _isEdit ? 'Editar categoría' : 'Nueva categoría';
    final previewCategory = Category(
      id: 'preview',
      name: _nameCtrl.text.trim().isEmpty ? 'Vista previa' : _nameCtrl.text.trim(),
      appliesTo: _appliesTo,
      colorSlug: _colorSlug,
      iconSlug: _iconSlug,
      monthlyLimit: null,
      deletedAt: null,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/categories'),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(child: CategoryBadge(category: previewCategory)),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Nombre'),
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Ingresá un nombre.';
                  return null;
                },
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
                onChanged: (slug) => setState(() => _colorSlug = slug),
              ),
              const SizedBox(height: 24),
              const Text('Ícono', style: TextStyle(color: FincoreColors.textMuted, fontSize: 13)),
              const SizedBox(height: 8),
              IconPicker(
                selectedSlug: _iconSlug,
                selectionColor: colorBySlug(_colorSlug),
                onChanged: (slug) => setState(() => _iconSlug = slug),
              ),
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

import 'package:fincore/app_dependencies.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/screens/weekly_budgets/widgets/budget_kind_picker.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/widgets/category_picker.dart';
import 'package:fincore/widgets/error_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// DTO de un renglón (línea) de presupuesto. El caller (pantalla de detalle
/// del presupuesto) mapea este dato al DAO dentro de `onSubmit` — este
/// widget nunca llama DAOs.
class BudgetItemFormData {
  final String name;
  final String? categoryId;
  final double amount;

  /// 'income' | 'expense'.
  final String kind;

  const BudgetItemFormData({
    required this.name,
    this.categoryId,
    required this.amount,
    required this.kind,
  });
}

/// Bottom sheet reutilizable para crear/editar un renglón de presupuesto
/// semanal o de plantilla (sprint `flutter-weekly-budgets-v1`, T016).
///
/// Reutiliza el patrón visual de `lib/widgets/save_view_dialog.dart`
/// (`showModalBottomSheet` + `isScrollControlled` + `Padding` que sube con
/// el teclado vía `MediaQuery.viewInsets.bottom`).
///
/// - `initial == null` → modo alta. `initialKind` sugiere el kind inicial
///   (viene de qué sección tapeó el usuario: "+ Ingreso" o "+ Gasto").
/// - `initial != null` → modo edición: todos los campos se precargan y
///   `initialKind` se ignora. El kind sigue siendo editable (a diferencia
///   del ledger, aquí no es inmutable).
class BudgetItemFormSheet extends StatefulWidget {
  final BudgetItemFormData? initial;
  final String? initialKind;
  final Future<void> Function(BudgetItemFormData data) onSubmit;

  const BudgetItemFormSheet({
    super.key,
    this.initial,
    this.initialKind,
    required this.onSubmit,
  });

  /// Wrapper de conveniencia: monta el sheet con el styling estándar de la
  /// app (surface + drag handle + esquinas redondeadas + safe area).
  static Future<void> show({
    required BuildContext context,
    BudgetItemFormData? initial,
    String? initialKind,
    required Future<void> Function(BudgetItemFormData) onSubmit,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: FincoreColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => BudgetItemFormSheet(
        initial: initial,
        initialKind: initialKind,
        onSubmit: onSubmit,
      ),
    );
  }

  @override
  State<BudgetItemFormSheet> createState() => _BudgetItemFormSheetState();
}

class _BudgetItemFormSheetState extends State<BudgetItemFormSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _amountCtrl;
  late String _kind;
  String? _categoryId;

  String? _nameError;
  String? _amountError;
  bool _saving = false;

  // Carga propia de categorías (mismo patrón de lectura que
  // `EntryFormScreen._bootstrap`): el widget no recibe la lista por
  // constructor porque el caller solo conoce el modelo de dominio
  // (WeeklyBudgetItemRow), no las categorías. Esto es una lectura de
  // catálogo para la UI, no una acción de dominio — el criterio "no llames
  // DAOs directamente" aplica a los writes (create/update del renglón), que
  // quedan 100% en el `onSubmit` del caller.
  List<Category> _categories = const [];

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameCtrl = TextEditingController(text: initial?.name ?? '');
    _amountCtrl = TextEditingController(
      text: initial != null ? _formatInitialAmount(initial.amount) : '',
    );
    _kind = initial?.kind ?? widget.initialKind ?? 'expense';
    _categoryId = initial?.categoryId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCategories());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  /// Evita ceros de más al precargar en edición: `150.0` → `"150"`,
  /// `150.5` → `"150.5"`.
  String _formatInitialAmount(double amount) {
    if (amount == amount.truncateToDouble()) {
      return amount.toStringAsFixed(0);
    }
    return amount.toString();
  }

  Future<void> _loadCategories() async {
    if (!mounted) return;
    final deps = AppDependencies.of(context);
    final categories = await deps.categoriesDao.listAll();
    if (!mounted) return;
    setState(() => _categories = categories);
  }

  Future<void> _submit() async {
    if (_saving) return;

    final name = _nameCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.trim());

    setState(() {
      _nameError = name.isEmpty ? 'Ingresar un nombre.' : null;
      _amountError =
          (amount == null || amount <= 0) ? 'Debe ser mayor a 0.' : null;
    });
    if (_nameError != null || _amountError != null) return;

    final data = BudgetItemFormData(
      name: name,
      categoryId: _categoryId,
      amount: amount!,
      kind: _kind,
    );

    setState(() => _saving = true);
    try {
      await widget.onSubmit(data);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // `useSafeArea: true` en showModalBottomSheet NO cubre la nav bar
    // gestual de Android (solo el status bar). Sumamos viewPadding
    // (nav bar) + viewInsets (teclado) al padding inferior para que
    // los botones "Cancelar/Guardar" no queden tapados por el sistema.
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 4,
        bottom: media.viewInsets.bottom + media.viewPadding.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEdit ? 'Editar renglón' : 'Nuevo renglón',
              style: const TextStyle(
                color: FincoreColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              autofocus: !_isEdit,
              maxLength: 60,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(color: FincoreColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Nombre',
                errorText: _nameError,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
            ),
            const SizedBox(height: 8),
            BudgetKindPicker(
              value: _kind,
              onChanged: (v) => setState(() => _kind = v),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              style: const TextStyle(color: FincoreColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Monto',
                prefixText: r'$ ',
                errorText: _amountError,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) {
                if (_amountError != null) setState(() => _amountError = null);
              },
            ),
            const SizedBox(height: 16),
            // P-003 laxa: no filtramos por `applies_to` del kind elegido —
            // cualquier categoría activa (income/expense/both) es
            // seleccionable sin importar si el renglón es ingreso o gasto.
            CategoryPicker(
              categories: _categories,
              validAppliesTo: const ['income', 'expense', 'both'],
              selectedId: _categoryId,
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _saving ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: FincoreColors.textSubtle,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: FincoreColors.border),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: FincoreColors.accent,
                      foregroundColor: FincoreColors.canvas,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: FincoreColors.canvas,
                            ),
                          )
                        : const Text('Guardar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

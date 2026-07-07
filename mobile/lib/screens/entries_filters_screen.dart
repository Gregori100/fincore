import 'package:fincore/app_dependencies.dart';
import 'package:fincore/constants/category_catalog.dart';
import 'package:fincore/constants/date_range_presets.dart';
import 'package:fincore/constants/filter_tokens.dart';
import 'package:fincore/constants/kinds.dart';
import 'package:fincore/data/daos/saved_views_dao.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/data/entries_filters.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/widgets/date_field_outlined.dart';
import 'package:fincore/widgets/error_snackbar.dart';
import 'package:fincore/widgets/save_view_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Panel full-screen de filtros de movimientos (sprint
/// `flutter-movements-filters-v1`).
///
/// 4 dimensiones, todas multi-select donde aplica:
/// - **Fecha**: chips de presets (single, semánticamente exclusivos).
/// - **Tipo**: chips multi-select de los 5 kinds.
/// - **Cuenta**: chips multi-select.
/// - **Categorías**: chips multi-select con badge color + icon.
///
/// El preset "Gastos" combinado del primer release se eliminó tras feedback
/// de Diego: los kinds deben ser todos individuales y combinables, no
/// agrupados arbitrariamente.
class EntriesFiltersScreen extends StatefulWidget {
  final EntriesFilters initial;
  final List<Account> accounts;
  final List<Category> categories;

  const EntriesFiltersScreen({
    super.key,
    required this.initial,
    required this.accounts,
    required this.categories,
  });

  @override
  State<EntriesFiltersScreen> createState() => _EntriesFiltersScreenState();
}

class _EntriesFiltersScreenState extends State<EntriesFiltersScreen> {
  late EntriesFilters _editing;
  late final TextEditingController _minAmountCtrl;
  late final TextEditingController _maxAmountCtrl;

  @override
  void initState() {
    super.initState();
    _editing = widget.initial;
    _minAmountCtrl = TextEditingController(
      text: widget.initial.minAmount?.toString() ?? '',
    );
    _maxAmountCtrl = TextEditingController(
      text: widget.initial.maxAmount?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _minAmountCtrl.dispose();
    _maxAmountCtrl.dispose();
    super.dispose();
  }

  void _selectDatePreset(DateRangePreset preset) {
    setState(() {
      _editing = _editing.withPreset(preset);
    });
  }

  Future<void> _pickFrom(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _editing.from,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Desde',
    );
    if (picked == null) return;
    if (!context.mounted) return;
    final newFrom = DateTime(picked.year, picked.month, picked.day);
    if (newFrom.isAfter(_editing.to)) {
      showWarningSnackbar(context, 'El rango no es válido. Verificar las fechas.');
      return;
    }
    setState(() {
      _editing = _editing.copyWith(
        datePreset: DateRangePreset.custom,
        from: newFrom,
      );
    });
  }

  Future<void> _pickTo(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _editing.to,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Hasta',
    );
    if (picked == null) return;
    if (!context.mounted) return;
    final newTo = DateTime(picked.year, picked.month, picked.day, 23, 59, 59, 999);
    if (newTo.isBefore(_editing.from)) {
      showWarningSnackbar(context, 'El rango no es válido. Verificar las fechas.');
      return;
    }
    setState(() {
      _editing = _editing.copyWith(
        datePreset: DateRangePreset.custom,
        to: newTo,
      );
    });
  }

  void _toggleKind(String kind) {
    final current = _editing.kinds.toList();
    if (current.contains(kind)) {
      current.remove(kind);
    } else {
      current.add(kind);
    }
    setState(() => _editing = _editing.copyWith(kinds: current));
  }

  void _toggleAccount(String accountId) {
    final current = _editing.accountIds.toList();
    if (current.contains(accountId)) {
      current.remove(accountId);
    } else {
      current.add(accountId);
    }
    setState(() => _editing = _editing.copyWith(accountIds: current));
  }

  void _toggleCategory(String categoryId) {
    final current = _editing.categoryIds.toList();
    if (current.contains(categoryId)) {
      current.remove(categoryId);
    } else {
      current.add(categoryId);
    }
    setState(() {
      _editing = _editing.copyWith(categoryIds: current);
    });
  }

  void _clearAll() {
    setState(() {
      _editing = EntriesFilters.thisMonth();
      _minAmountCtrl.text = '';
      _maxAmountCtrl.text = '';
    });
  }

  // Sprint `flutter-reports-drilldown-parity-v1`: cuando el usuario
  // combina "Sin categoría" con kinds puramente `income` o puramente
  // gastos, el DAO amplía la definición del bucket para incluir el edge
  // de categorías cuyo `applies_to` fue editado al opuesto (RN-P01/P02).
  // Este hint anticipa el comportamiento para evitar sorpresa al abrir
  // la lista y ver entries con categoría visible pero clasificados como
  // "Sin categoría". La condición replica la del helper
  // `EntriesDao._uncategorizedCondition`.
  bool get _shouldShowUncategorizedHint {
    if (!_editing.categoryIds.contains(kUncategorizedFilterToken)) return false;
    if (_editing.kinds.isEmpty) return false;
    final kindSet = _editing.kinds.toSet();
    if (kindSet.length == 1 && kindSet.contains('income')) return true;
    const spendingKinds = {'expense', 'credit_expense'};
    if (kindSet.every(spendingKinds.contains)) return true;
    return false;
  }

  /// Parsea ambos controllers, valida `min <= max` cuando ambos están
  /// presentes (RN-A05), y emite el resultado al caller. Si la validación
  /// falla, muestra snackbar warning y NO emite — el panel queda abierto
  /// para que Diego corrija (mismo patrón del date picker custom).
  void _apply() {
    final minText = _minAmountCtrl.text.trim();
    final maxText = _maxAmountCtrl.text.trim();
    final min = minText.isEmpty ? null : double.tryParse(minText);
    final max = maxText.isEmpty ? null : double.tryParse(maxText);

    if (min != null && max != null && min > max) {
      showWarningSnackbar(
        context,
        'El rango de monto no es válido. Verificar los montos.',
      );
      return;
    }

    final withAmount = _editing.copyWith(
      minAmount: min,
      maxAmount: max,
      clearMinAmount: minText.isEmpty,
      clearMaxAmount: maxText.isEmpty,
    );
    Navigator.of(context).pop<EntriesFilters>(withAmount);
  }

  void _cancel() {
    Navigator.of(context).maybePop();
  }

  /// Sprint `flutter-entries-saved-views-v1` (RF-008): guarda los
  /// filtros actuales como vista nueva tras pedir el nombre.
  Future<void> _saveView() async {
    final name = await showSaveViewDialog(
      context,
      title: 'Guardar vista',
    );
    if (name == null) return;
    if (!mounted) return;
    // Antes de guardar, computar `_editing` con los amounts actuales
    // (parsea controllers). Reutilizamos la misma lógica de `_apply`.
    final minText = _minAmountCtrl.text.trim();
    final maxText = _maxAmountCtrl.text.trim();
    final min = minText.isEmpty ? null : double.tryParse(minText);
    final max = maxText.isEmpty ? null : double.tryParse(maxText);
    if (min != null && max != null && min > max) {
      showWarningSnackbar(
        context,
        'El rango de monto no es válido. Verificar los montos.',
      );
      return;
    }
    final filtersToSave = _editing.copyWith(
      minAmount: min,
      maxAmount: max,
      clearMinAmount: minText.isEmpty,
      clearMaxAmount: maxText.isEmpty,
    );
    final deps = AppDependencies.of(context);
    try {
      await deps.savedViewsDao
          .create(name: name, filters: filtersToSave);
      if (mounted) {
        showSuccessSnackbar(context, 'Vista guardada.');
      }
    } on SavedViewsDaoError catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMM y', 'es_MX');
    final isCustom = _editing.datePreset == DateRangePreset.custom;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Cerrar',
          onPressed: _cancel,
        ),
        title: const Text('Filtros'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        children: [
          // ===========================================================
          // Sección Fecha (single-select preset)
          // ===========================================================
          const _SectionTitle('Fecha'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in DateRangePreset.values)
                _SelectableChip(
                  label: p.label,
                  selected: _editing.datePreset == p,
                  onTap: () => _selectDatePreset(p),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (!isCustom)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                '${dateFormat.format(_editing.from)} — ${dateFormat.format(_editing.to)}',
                style: const TextStyle(
                  color: FincoreColors.textSubtle,
                  fontSize: 12,
                ),
              ),
            ),
          if (isCustom)
            Row(
              children: [
                Expanded(
                  child: DateFieldOutlined(
                    label: 'Desde',
                    value: _editing.from,
                    format: dateFormat,
                    onTap: () => _pickFrom(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DateFieldOutlined(
                    label: 'Hasta',
                    value: _editing.to,
                    format: dateFormat,
                    onTap: () => _pickTo(context),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 24),

          // ===========================================================
          // Sección Tipo (multi-select)
          // ===========================================================
          const _SectionTitle('Tipo'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final k in JournalKind.values)
                _SelectableChip(
                  label: k.label,
                  selected: _editing.kinds.contains(k.apiValue),
                  onTap: () => _toggleKind(k.apiValue),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // ===========================================================
          // Sección Cuenta (multi-select)
          // ===========================================================
          const _SectionTitle('Cuenta'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in widget.accounts)
                _SelectableChip(
                  label: a.name,
                  selected: _editing.accountIds.contains(a.id),
                  onTap: () => _toggleAccount(a.id),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // ===========================================================
          // Sección Monto (sprint flutter-movements-amount-filter-v1)
          // ===========================================================
          const _SectionTitle('Monto'),
          // Patch UX post-smoke: inputs más compactos (isDense + padding
          // ajustado) para que se vean alineados con la altura visual de
          // los chips del resto del panel.
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _minAmountCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Mínimo',
                    prefixText: r'$ ',
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                  ),
                  style: const TextStyle(fontSize: 13),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _maxAmountCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Máximo',
                    prefixText: r'$ ',
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                  ),
                  style: const TextStyle(fontSize: 13),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ===========================================================
          // Sección Categorías (multi-select con badge)
          // ===========================================================
          const _SectionTitle('Categorías'),
          Builder(builder: (context) {
            final sorted = widget.categories.toList()
              ..sort((a, b) => a.name.compareTo(b.name));
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _CategoryChip(
                  label: 'Sin categoría',
                  color: FincoreColors.textSubtle,
                  icon: Icons.label_off_outlined,
                  selected: _editing.categoryIds
                      .contains(kUncategorizedFilterToken),
                  onTap: () => _toggleCategory(kUncategorizedFilterToken),
                ),
                for (final c in sorted)
                  _CategoryChip(
                    label: c.name,
                    color: colorBySlug(c.colorSlug),
                    icon: iconBySlug(c.iconSlug),
                    selected: _editing.categoryIds.contains(c.id),
                    onTap: () => _toggleCategory(c.id),
                  ),
              ],
            );
          }),
          if (_shouldShowUncategorizedHint) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FincoreColors.accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: FincoreColors.accent.withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: FincoreColors.accent,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '"Sin categoría" también incluye entries con categorías '
                      'cuyo tipo fue editado a otro flujo.',
                      style: TextStyle(
                        color: FincoreColors.accent,
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),

          // ===========================================================
          // Sección Vistas guardadas (sprint
          // `flutter-entries-saved-views-v1` + H7 quality review polish)
          // ===========================================================
          const _SectionTitle('Vistas guardadas'),
          // H7 quality review v1: disabled cuando no hay filtros activos.
          // Sin esto el usuario puede guardar el estado default ("Este mes")
          // como vista, que es equivalente a no tener vista. El tooltip
          // explica el bloqueo.
          Tooltip(
            message: _editing.activeCount == 0
                ? 'Configurá al menos un filtro antes de guardar.'
                : '',
            child: OutlinedButton.icon(
              onPressed: _editing.activeCount == 0 ? null : _saveView,
              icon: const Icon(Icons.bookmark_outline, size: 18),
              label: const Text('Guardar como vista'),
              style: OutlinedButton.styleFrom(
                foregroundColor: FincoreColors.accent,
                side: const BorderSide(color: FincoreColors.accent),
                disabledForegroundColor: FincoreColors.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _clearAll,
                  child: const Text('Limpiar todo'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _apply,
                  child: const Text('Aplicar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          color: FincoreColors.textMuted,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _SelectableChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SelectableChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      selectedColor: FincoreColors.accent.withValues(alpha: 0.18),
      backgroundColor: FincoreColors.surface,
      side: BorderSide(
        color: selected ? FincoreColors.accent : FincoreColors.border,
      ),
      labelStyle: TextStyle(
        color: selected ? FincoreColors.accent : FincoreColors.textPrimary,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.color,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      avatar: Icon(icon, size: 16, color: selected ? color : color.withValues(alpha: 0.7)),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      selectedColor: color.withValues(alpha: 0.18),
      backgroundColor: FincoreColors.surface,
      side: BorderSide(
        color: selected ? color : FincoreColors.border,
      ),
      labelStyle: TextStyle(
        color: selected ? color : FincoreColors.textPrimary,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }
}

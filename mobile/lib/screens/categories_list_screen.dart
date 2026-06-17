import 'package:fincore/app_dependencies.dart';
import 'package:fincore/models/category.dart';
import 'package:fincore/models/domain_error.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/widgets/base_card.dart';
import 'package:fincore/widgets/category_badge.dart';
import 'package:fincore/widgets/error_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CategoriesListScreen extends StatefulWidget {
  const CategoriesListScreen({super.key});

  @override
  State<CategoriesListScreen> createState() => _CategoriesListScreenState();
}

class _CategoriesListScreenState extends State<CategoriesListScreen> {
  Future<List<Category>>? _future;
  String? _appliesToFilter; // null = todas

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<List<Category>> _load() {
    final deps = AppDependencies.of(context);
    return deps.categoriesApi.list(appliesTo: _appliesToFilter);
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    try {
      await next;
    } on DomainError catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    }
  }

  void _setFilter(String? value) {
    setState(() {
      _appliesToFilter = value;
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categorías'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/categories/new'),
        backgroundColor: FincoreColors.accent,
        foregroundColor: FincoreColors.canvas,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                _FilterChip(label: 'Todas', selected: _appliesToFilter == null, onTap: () => _setFilter(null)),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Ingreso',
                  selected: _appliesToFilter == 'income',
                  onTap: () => _setFilter('income'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Gasto',
                  selected: _appliesToFilter == 'expense',
                  onTap: () => _setFilter('expense'),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Category>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return _ErrorState(error: snap.error!, onRetry: _refresh);
                }
                final categories = snap.data!;
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: categories.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 80),
                            Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                  'No hay categorías que coincidan.',
                                  style: TextStyle(color: FincoreColors.textMuted),
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          itemCount: categories.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) => _CategoryRow(category: categories[i]),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? FincoreColors.accent.withValues(alpha: 0.2) : FincoreColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? FincoreColors.accent : FincoreColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? FincoreColors.accent : FincoreColors.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final Category category;
  const _CategoryRow({required this.category});

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      onTap: () => context.go('/categories/${category.id}/edit'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(child: CategoryBadge(category: category)),
          const SizedBox(width: 8),
          Text(
            _appliesToLabel(category.appliesTo),
            style: const TextStyle(color: FincoreColors.textSubtle, fontSize: 11),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: FincoreColors.textSubtle, size: 18),
        ],
      ),
    );
  }

  String _appliesToLabel(String v) {
    switch (v) {
      case 'income':
        return 'Ingreso';
      case 'expense':
        return 'Gasto';
      case 'both':
        return 'Ambos';
      default:
        return v;
    }
  }
}

class _ErrorState extends StatelessWidget {
  final Object error;
  final Future<void> Function() onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final msg = error is DomainError
        ? (error as DomainError).message
        : 'No se pudo cargar las categorías.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: FincoreColors.negative),
            const SizedBox(height: 12),
            Text(msg, textAlign: TextAlign.center, style: const TextStyle(color: FincoreColors.textMuted)),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => onRetry(), child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}

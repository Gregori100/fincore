import 'package:fincore/app_dependencies.dart';
import 'package:fincore/constants/category_catalog.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/widgets/base_card.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CategoriesListScreen extends StatefulWidget {
  const CategoriesListScreen({super.key});

  @override
  State<CategoriesListScreen> createState() => _CategoriesListScreenState();
}

class _CategoriesListScreenState extends State<CategoriesListScreen> {
  String? _filter;
  Stream<List<Category>>? _stream;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stream ??= AppDependencies.of(context).categoriesDao.watchActive();
  }

  void _setFilter(String? value) {
    setState(() {
      _filter = value;
      _stream = AppDependencies.of(context).categoriesDao.watchActive(appliesTo: value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categorías'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/categories/new'),
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
                _Chip(label: 'Todas', selected: _filter == null, onTap: () => _setFilter(null)),
                const SizedBox(width: 8),
                _Chip(label: 'Ingreso', selected: _filter == 'income', onTap: () => _setFilter('income')),
                const SizedBox(width: 8),
                _Chip(label: 'Gasto', selected: _filter == 'expense', onTap: () => _setFilter('expense')),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Category>>(
              stream: _stream,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final cats = snap.data!;
                if (cats.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No hay categorías.',
                          style: TextStyle(color: FincoreColors.textMuted)),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  itemCount: cats.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _Row(category: cats[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.onTap});

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
          border: Border.all(color: selected ? FincoreColors.accent : FincoreColors.border),
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

class _Row extends StatelessWidget {
  final Category category;
  const _Row({required this.category});

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      onTap: () => context.push('/categories/${category.id}/edit'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: colorBySlug(category.colorSlug).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorBySlug(category.colorSlug).withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(iconBySlug(category.iconSlug),
                    color: colorBySlug(category.colorSlug), size: 14),
                const SizedBox(width: 6),
                Text(
                  category.name,
                  style: TextStyle(color: colorBySlug(category.colorSlug), fontSize: 13),
                ),
              ],
            ),
          ),
          const Spacer(),
          Text(
            switch (category.appliesTo) {
              'income' => 'Ingreso',
              'expense' => 'Gasto',
              'both' => 'Ambos',
              _ => category.appliesTo,
            },
            style: const TextStyle(color: FincoreColors.textSubtle, fontSize: 11),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: FincoreColors.textSubtle, size: 18),
        ],
      ),
    );
  }
}

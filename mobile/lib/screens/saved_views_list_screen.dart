import 'package:fincore/app_dependencies.dart';
import 'package:fincore/data/daos/saved_views_dao.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/widgets/confirm_dialog.dart';
import 'package:fincore/widgets/error_snackbar.dart';
import 'package:fincore/widgets/save_view_dialog.dart';
import 'package:fincore/widgets/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Pantalla full-screen con la lista de vistas guardadas (patch UX v4
/// post-smoke). Reemplaza el `SavedViewPickerSheet` por una `Material
/// PageRoute` con AppBar.
///
/// Razón del cambio: cuando la lista era un `showModalBottomSheet`,
/// abrir un sheet hijo (Renombrar/Eliminar) causaba shrink visual y
/// bugs de teclado pegado. Con la lista como pantalla full-screen, los
/// sheets hijos no interactúan con su propio `viewInsets`.
///
/// Convención de navegación:
/// ```dart
/// final filters = await Navigator.of(context).push<EntriesFilters>(
///   MaterialPageRoute(
///     builder: (_) => const SavedViewsListScreen(),
///     fullscreenDialog: true,
///   ),
/// );
/// if (filters != null) setState(() => _filters = filters);
/// ```
///
/// Tap en una vista hace pop con los filtros deserializados.
class SavedViewsListScreen extends StatelessWidget {
  const SavedViewsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final deps = AppDependencies.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Cerrar',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Mis vistas'),
      ),
      body: StreamBuilder<List<SavedView>>(
        stream: deps.savedViewsDao.watchAll(),
        builder: (context, snap) {
          if (!snap.hasData) {
            // H5 quality review v1: alinear loading state con el patrón
            // canónico del repo (accounts_list_screen, etc.). Skeleton
            // evita layout shift al pintar la lista real.
            return ListView.separated(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              itemCount: 4,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, __) => const SkeletonCard(),
            );
          }
          final views = snap.data!;
          if (views.isEmpty) {
            return const _EmptyState();
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: views.length,
            separatorBuilder: (_, __) => const Divider(
              height: 1,
              color: FincoreColors.border,
            ),
            itemBuilder: (_, i) => _SavedViewRow(view: views[i]),
          );
        },
      ),
    );
  }
}

class _SavedViewRow extends StatelessWidget {
  final SavedView view;
  const _SavedViewRow({required this.view});

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('d MMM y', 'es_MX').format(view.createdAt);
    return ListTile(
      title: Text(
        view.name,
        style: const TextStyle(
          color: FincoreColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        'Creada el $dateLabel',
        style: const TextStyle(
          color: FincoreColors.textSubtle,
          fontSize: 11,
        ),
      ),
      trailing: PopupMenuButton<String>(
        tooltip: 'Más acciones',
        icon: const Icon(
          Icons.more_vert,
          color: FincoreColors.textSubtle,
        ),
        onSelected: (action) {
          if (action == 'rename') {
            _onRename(context);
          } else if (action == 'delete') {
            _onDelete(context);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: 'rename',
            child: Row(
              children: [
                Icon(Icons.edit_outlined, size: 18),
                SizedBox(width: 12),
                Text('Renombrar'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: FincoreColors.negative,
                ),
                SizedBox(width: 12),
                Text(
                  'Eliminar',
                  style: TextStyle(color: FincoreColors.negative),
                ),
              ],
            ),
          ),
        ],
      ),
      onTap: () => Navigator.of(context).pop(view.filters),
    );
  }

  Future<void> _onRename(BuildContext context) async {
    final deps = AppDependencies.of(context);
    final newName = await showSaveViewDialog(
      context,
      title: 'Renombrar vista',
      initialName: view.name,
    );
    if (newName == null) return;
    if (newName == view.name) return;
    try {
      await deps.savedViewsDao.rename(id: view.id, name: newName);
      if (context.mounted) {
        showSuccessSnackbar(context, 'Vista renombrada.');
      }
    } on SavedViewsDaoError catch (e) {
      if (context.mounted) showErrorSnackbar(context, e);
    }
  }

  Future<void> _onDelete(BuildContext context) async {
    final deps = AppDependencies.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: 'Eliminar vista',
      message: '¿Eliminar la vista "${view.name}"? '
          'No hay vuelta atrás.',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (!confirmed) return;
    if (!context.mounted) return;
    try {
      await deps.savedViewsDao.removeById(id: view.id);
      if (context.mounted) {
        showSuccessSnackbar(context, 'Vista eliminada.');
      }
    } on SavedViewsDaoError catch (e) {
      if (context.mounted) showErrorSnackbar(context, e);
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bookmark_border,
              size: 48,
              color: FincoreColors.textMuted,
            ),
            SizedBox(height: 12),
            Text(
              'No tenés vistas guardadas todavía.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: FincoreColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Configurá filtros y tap "Guardar como vista" '
              'desde el panel de filtros.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: FincoreColors.textSubtle,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

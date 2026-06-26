import 'package:fincore/theme/fincore_colors.dart';
import 'package:flutter/material.dart';

/// Estado vacío de la lista de movimientos.
///
/// Si hay filtros activos (`hasFilters=true`), muestra un botón directo
/// "Limpiar filtros" (M12 del quality review v1). Si no, solo el copy
/// neutro "No hay movimientos.".
class EntriesEmptyState extends StatelessWidget {
  final bool hasFilters;
  final VoidCallback onClearFilters;

  const EntriesEmptyState({
    super.key,
    required this.hasFilters,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              hasFilters
                  ? 'No hay movimientos con esos filtros.\nProbá ajustarlos.'
                  : 'No hay movimientos.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: FincoreColors.textMuted),
            ),
            if (hasFilters) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onClearFilters,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Limpiar filtros'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: FincoreColors.accent,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

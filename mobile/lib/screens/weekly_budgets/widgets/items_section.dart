import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/theme/fincore_motion.dart';
import 'package:fincore/widgets/amount_formatter.dart';
import 'package:fincore/widgets/base_card.dart';
import 'package:flutter/material.dart';

/// Vista agnóstica de un renglón de presupuesto (ingreso o gasto esperado).
///
/// No es el modelo drift (`BudgetIncomeItem` / `BudgetExpenseItem`): el
/// caller mapea a esta forma para que `ItemsSection` no conozca tablas.
///
/// Sprint flutter-budgets-item-completion-v1: `isDone` refleja el flag
/// manual del usuario ("ya pasó / ya cumplí"). Nace en `false` y el toggle
/// del checkbox lo invierte.
class BudgetItemDisplay {
  final String id;
  final String name;
  final String? categoryId;
  final double amount;
  final bool isDone;

  const BudgetItemDisplay({
    required this.id,
    required this.name,
    this.categoryId,
    required this.amount,
    this.isDone = false,
  });
}

/// Sección editable con lista reordenable de renglones de un presupuesto
/// semanal (ingresos esperados o gastos planeados, según `kind`).
///
/// RN-B20: solo el handle (`Icons.drag_indicator`) inicia el drag; el resto
/// del row abre edición al tap. RN-B11: el `sort_order` real (bloques de
/// 100) vive en el DAO — este widget solo reporta la nueva lista de ids vía
/// `onReorder` y no mantiene estado propio: al ser un widget puramente
/// derivado de `items`, confía en que el stream reactivo del caller (DAO +
/// drift, ver `financial_state.dart` / `entries_dao.dart` para el patrón)
/// reconstruya con el nuevo orden apenas el `sort_order` se persiste. En
/// SQLite in-memory/local ese round-trip es virtualmente instantáneo, así
/// que no hay parpadeo perceptible por no optimista-actualizar localmente.
class ItemsSection extends StatelessWidget {
  /// "Ingresos esperados" | "Gastos planeados".
  final String title;

  /// 'income' | 'expense' — solo para colorear el monto (positive/negative).
  final String kind;

  final List<BudgetItemDisplay> items;

  /// Tap en el resto del row (fuera del handle) → abre edit.
  final void Function(String itemId) onTapItem;

  /// Tap en el botón de borrar. El caller muestra el `ConfirmDialog`.
  final void Function(String itemId) onDeleteItem;

  /// Se dispara con la lista completa de ids en el nuevo orden tras un
  /// drag & drop. El caller la persiste con `reorderItems` del DAO.
  final Future<void> Function(List<String> orderedIds) onReorder;

  /// Abre el form sheet en modo crear con `kind` pre-seteado.
  final VoidCallback onAddItem;

  /// Tap en el checkbox del row → invierte `is_done` en el DAO. Si es null,
  /// el checkbox no se renderiza (caller que no quiere el marcado manual).
  final void Function(String itemId)? onToggleDone;

  /// Opcional: si se pasa, renderiza el `CategoryBadge` bajo el nombre.
  final Widget Function(String? categoryId)? categoryBadgeBuilder;

  const ItemsSection({
    super.key,
    required this.title,
    required this.kind,
    required this.items,
    required this.onTapItem,
    required this.onDeleteItem,
    required this.onReorder,
    required this.onAddItem,
    this.onToggleDone,
    this.categoryBadgeBuilder,
  });

  bool get _isIncome => kind == 'income';

  void _handleReorder(int oldIndex, int newIndex) {
    // Caveat documentado de ReorderableListView.onReorder: cuando el item se
    // mueve hacia abajo (newIndex > oldIndex) el índice reportado ya cuenta
    // al propio item que se está moviendo (fue "removido" conceptualmente
    // de la lista de destino), así que hay que restar 1 antes de insertar o
    // el item termina un lugar más abajo de lo esperado.
    if (newIndex > oldIndex) newIndex -= 1;
    final ids = items.map((i) => i.id).toList();
    final movedId = ids.removeAt(oldIndex);
    ids.insert(newIndex, movedId);
    onReorder(ids);
  }

  @override
  Widget build(BuildContext context) {
    final amountColor = _isIncome ? FincoreColors.positive : FincoreColors.negative;
    final emptyLabel = _isIncome ? 'Sin ingresos planeados' : 'Sin gastos planeados';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          title,
          // QW3: el header ya dice "Ingresos esperados" / "Gastos
          // planeados" — solo ícono tintado según kind, sin label
          // redundante.
          trailing: IconButton.filledTonal(
            onPressed: onAddItem,
            icon: const Icon(Icons.add, size: 20),
            tooltip: _isIncome ? 'Agregar ingreso' : 'Agregar gasto',
            style: IconButton.styleFrom(
              backgroundColor: amountColor.withValues(alpha: 0.12),
              foregroundColor: amountColor,
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          BaseCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emptyLabel, style: const TextStyle(color: FincoreColors.textMuted)),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: onAddItem,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Agregar'),
                  style: OutlinedButton.styleFrom(foregroundColor: FincoreColors.accent),
                ),
              ],
            ),
          )
        else
          ReorderableListView(
            buildDefaultDragHandles: false,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            onReorder: _handleReorder,
            children: [
              for (var i = 0; i < items.length; i++)
                _ItemRow(
                  key: ValueKey(items[i].id),
                  index: i,
                  item: items[i],
                  amountColor: amountColor,
                  onTap: () => onTapItem(items[i].id),
                  onDelete: () => onDeleteItem(items[i].id),
                  onToggleDone: onToggleDone == null
                      ? null
                      : () => onToggleDone!(items[i].id),
                  categoryBadgeBuilder: categoryBadgeBuilder,
                ),
            ],
          ),
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  final int index;
  final BudgetItemDisplay item;
  final Color amountColor;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onToggleDone;
  final Widget Function(String? categoryId)? categoryBadgeBuilder;

  const _ItemRow({
    required super.key,
    required this.index,
    required this.item,
    required this.amountColor,
    required this.onTap,
    required this.onDelete,
    required this.onToggleDone,
    required this.categoryBadgeBuilder,
  });

  @override
  Widget build(BuildContext context) {
    // Sprint flutter-budgets-item-completion-v1: cuando `is_done`, el
    // stripe lateral y el monto se atenúan y el nombre queda tachado.
    // El drag handle y el checkbox mantienen contraste completo — siguen
    // siendo affordances tapables.
    final done = item.isDone;
    final effectiveAmountColor = done
        ? amountColor.withValues(alpha: 0.45)
        : amountColor;
    final nameColor = done ? FincoreColors.textMuted : FincoreColors.textPrimary;
    final stripeColor = done ? amountColor.withValues(alpha: 0.35) : amountColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        // QW6: el borde acento de 3px (primer hijo del Row más abajo) queda
        // pegado al borde izquierdo del card. El `ClipRRect` recorta sus
        // esquinas superior/inferior izquierda para que sigan la curva de
        // 12px del card en vez de asomar como esquinas cuadradas.
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: FincoreColors.border, width: 1),
          ),
          child: Material(
            color: FincoreColors.surface,
            borderRadius: BorderRadius.circular(12),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AnimatedContainer(
                    duration: kMotionFast,
                    curve: kCurveStandard,
                    width: 3,
                    color: stripeColor,
                  ),
                  // Único punto de la fila que inicia el reorder (RN-B20):
                  // el resto del row responde solo a tap (edit), nunca a
                  // drag. Área tapable 44x44 real (mínimo WCAG 2.5.5 /
                  // Material touch target) aunque el ícono visual sea de
                  // 24px: el `SizedBox` por sí solo NO fuerza `hitTestSelf`
                  // (un `Icon` no pinta ni responde a hit-test fuera de su
                  // propio tamaño), así que el `GestureDetector` con
                  // `HitTestBehavior.opaque` es el que realmente extiende
                  // el área táctil a los 44x44 completos.
                  ReorderableDragStartListener(
                    index: index,
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        child: const Center(
                          child: Icon(
                            Icons.drag_indicator,
                            size: 24,
                            color: FincoreColors.textSubtle,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (onToggleDone != null)
                    // Checkbox del sprint flutter-budgets-item-completion-v1.
                    // Rechazamos `Checkbox` desnudo — el touch target de M3
                    // ya es 40x40, pero el ícono se ve chico y sin borde en
                    // dark theme. Envolvemos en un contenedor 44x44 tapable.
                    Semantics(
                      button: true,
                      checked: done,
                      label: done
                          ? 'Marcado como completado, tap para desmarcar'
                          : 'Sin completar, tap para marcar',
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: InkWell(
                          onTap: onToggleDone,
                          customBorder: const CircleBorder(),
                          child: Center(
                            child: AnimatedSwitcher(
                              duration: kMotionFast,
                              switchInCurve: kCurveStandard,
                              switchOutCurve: kCurveExit,
                              child: Icon(
                                done
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                key: ValueKey(done),
                                size: 22,
                                color: done
                                    ? amountColor
                                    : FincoreColors.textSubtle,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: InkWell(
                      onTap: onTap,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 4,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimatedDefaultTextStyle(
                                    duration: kMotionFast,
                                    curve: kCurveStandard,
                                    style: TextStyle(
                                      color: nameColor,
                                      fontWeight: FontWeight.w500,
                                      decoration: done
                                          ? TextDecoration.lineThrough
                                          : TextDecoration.none,
                                      decorationColor: FincoreColors.textMuted,
                                      decorationThickness: 2,
                                    ),
                                    child: Text(
                                      item.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (categoryBadgeBuilder != null) ...[
                                    const SizedBox(height: 4),
                                    Opacity(
                                      opacity: done ? 0.5 : 1.0,
                                      child: categoryBadgeBuilder!(
                                          item.categoryId),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            AnimatedDefaultTextStyle(
                              duration: kMotionFast,
                              curve: kCurveStandard,
                              style: TextStyle(
                                color: effectiveAmountColor,
                                fontWeight: FontWeight.w600,
                                decoration: done
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                                decorationColor: FincoreColors.textMuted,
                                decorationThickness: 2,
                              ),
                              child: Text(formatAmount(item.amount)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    color: FincoreColors.textSubtle,
                    tooltip: 'Eliminar',
                    onPressed: onDelete,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

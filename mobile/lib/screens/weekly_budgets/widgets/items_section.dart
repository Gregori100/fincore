import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/theme/fincore_motion.dart';
import 'package:fincore/theme/fincore_typography.dart';
import 'package:fincore/utils/money.dart';
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
///
/// Sprint flutter-budgets-running-balance-v1: `cumulativeAfter` es el
/// saldo acumulado del presupuesto tras aplicar este renglón según su
/// `sort_order`. Ingresos suman, gastos restan. La cascada arranca en 0
/// para el primer ingreso y "arrastra" el subtotal final de la sección
/// de ingresos al primer gasto. Opcional: si null, el _ItemRow no
/// renderiza el subtítulo. Lo calcula el caller para que el widget no
/// dependa del `kind` cruzado entre secciones.
class BudgetItemDisplay {
  final String id;
  final String name;
  final String? categoryId;
  final int amount;
  final bool isDone;
  final int? cumulativeAfter;

  const BudgetItemDisplay({
    required this.id,
    required this.name,
    this.categoryId,
    required this.amount,
    this.isDone = false,
    this.cumulativeAfter,
  });

  BudgetItemDisplay copyWith({int? cumulativeAfter}) {
    return BudgetItemDisplay(
      id: id,
      name: name,
      categoryId: categoryId,
      amount: amount,
      isDone: isDone,
      cumulativeAfter: cumulativeAfter ?? this.cumulativeAfter,
    );
  }
}

/// Sprint flutter-budgets-running-balance-v1: calcula el saldo acumulado
/// tras cada renglón. Recibe las dos secciones en el orden en que se
/// muestran (ya filtradas por kind y ordenadas por sort_order) y devuelve
/// copias con `cumulativeAfter` seteado.
///
/// La cascada arranca en 0 sumando los ingresos; el subtotal final de la
/// sección de ingresos "arrastra" al primer gasto. `isDone` NO altera el
/// cálculo (representa el plan, no lo realizado).
///
/// Función pura para permitir tests unitarios sin harness de widget. La
/// invoca `WeeklyBudgetScreen.build` sobre el snapshot del stream.
({List<BudgetItemDisplay> income, List<BudgetItemDisplay> expense})
    withCumulativeCascade({
  required List<BudgetItemDisplay> income,
  required List<BudgetItemDisplay> expense,
}) {
  int running = 0;
  final incomeOut = <BudgetItemDisplay>[];
  for (final i in income) {
    running += i.amount;
    incomeOut.add(i.copyWith(cumulativeAfter: running));
  }
  final expenseOut = <BudgetItemDisplay>[];
  for (final e in expense) {
    running -= e.amount;
    expenseOut.add(e.copyWith(cumulativeAfter: running));
  }
  return (income: incomeOut, expense: expenseOut);
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
///
/// Sprint flutter-budgets-polish-v1 (P1a): el borrado dejó de vivir como
/// botón X inline y pasó a swipe-to-delete (`Dismissible`). Libera ~44dp
/// de ancho por row y usa un patrón nativo Android. El `Dismissible`
/// captura horizontal drag; el `ReorderableDragStartListener` sigue con
/// vertical drag por el handle — ejes ortogonales, sin conflicto.
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
                // P1a: Dismissible como wrapper — su `key` es la que
                // `ReorderableListView` observa para identificar el hijo. El
                // `_ItemRow` interno ya no necesita key. `confirmDismiss`
                // delega en el caller: `onDeleteItem` muestra el ConfirmDialog
                // y devuelve un bool que se propaga. Si el usuario cancela,
                // el swipe se revierte y no se llama al DAO.
                Dismissible(
                  key: ValueKey(items[i].id),
                  direction: DismissDirection.endToStart,
                  background: const _DismissBackground(),
                  confirmDismiss: (_) async {
                    onDeleteItem(items[i].id);
                    // Retornamos false para que Dismissible NO remueva la
                    // fila de la UI: el caller ya ejecuta `deleteItem` en el
                    // DAO que dispara la re-emisión del stream, y la fila
                    // desaparece "por sí sola" cuando el nuevo snapshot llega.
                    // Devolver true acá causaría un flicker: el widget se
                    // quita optimistamente + luego el stream re-emite lo
                    // mismo + se vuelve a montar durante 1 frame.
                    return false;
                  },
                  child: _ItemRow(
                    index: i,
                    item: items[i],
                    amountColor: amountColor,
                    onTap: () => onTapItem(items[i].id),
                    onToggleDone: onToggleDone == null
                        ? null
                        : () => onToggleDone!(items[i].id),
                    categoryBadgeBuilder: categoryBadgeBuilder,
                  ),
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
  final VoidCallback? onToggleDone;
  final Widget Function(String? categoryId)? categoryBadgeBuilder;

  const _ItemRow({
    required this.index,
    required this.item,
    required this.amountColor,
    required this.onTap,
    required this.onToggleDone,
    required this.categoryBadgeBuilder,
  });

  @override
  Widget build(BuildContext context) {
    // Sprint flutter-budgets-item-completion-v1: cuando `is_done`, el
    // stripe lateral y el monto se atenúan y el nombre queda tachado.
    // El drag handle y el checkbox mantienen contraste completo — siguen
    // siendo affordances tapables.
    //
    // Sprint flutter-budgets-polish-v1 (P2a): stripe + monto + badge
    // comparten `alphaMuted` (0.45) en vez de 3 valores distintos. Fija
    // una "atenuación única" para el estado `done` que se lee coherente.
    final done = item.isDone;
    final effectiveAmountColor = done
        ? amountColor.withValues(alpha: FincoreColors.alphaMuted)
        : amountColor;
    final nameColor = done ? FincoreColors.textMuted : FincoreColors.textPrimary;
    final stripeColor = done
        ? amountColor.withValues(alpha: FincoreColors.alphaMuted)
        : amountColor;

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
                  //
                  // P1b (polish-v1): handle subordinado al checkbox. Ícono
                  // 20sp (era 24) + `textSubtle` a alpha 0.55 permanente.
                  // Mantiene el touch target 44x44 pero deja el checkbox
                  // como affordance dominante — dejan de leerse como dos
                  // botones "gemelos" grises.
                  ReorderableDragStartListener(
                    index: index,
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        child: Center(
                          child: Icon(
                            Icons.drag_indicator,
                            size: 20,
                            color: FincoreColors.textSubtle
                                .withValues(alpha: 0.55),
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
                    //
                    // P3a (polish-v1): `check_circle_outline` en lugar de
                    // `radio_button_unchecked` para el estado no-marcado.
                    // Mismo family que `check_circle` → sin salto de peso
                    // óptico en el AnimatedSwitcher y metáfora correcta
                    // (tarea completada, no selección única).
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
                                    : Icons.check_circle_outline,
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
                                    // P2a (polish-v1): badge también en
                                    // alphaMuted cuando done. Antes 0.5,
                                    // ahora 0.45 igual que stripe/monto.
                                    Opacity(
                                      opacity: done
                                          ? FincoreColors.alphaMuted
                                          : 1.0,
                                      child: categoryBadgeBuilder!(
                                          item.categoryId),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Sprint flutter-budgets-running-balance-v1:
                            // Column con monto arriba + subtotal acumulado
                            // debajo. El subtotal solo se renderiza si el
                            // caller lo pasó (cumulativeAfter != null). No
                            // lo atenuamos por `isDone` porque el saldo
                            // sigue siendo real; el tachado ya comunica el
                            // estado del renglón.
                            //
                            // P1c (polish-v1): hairline 1px de border entre
                            // monto y subtotal. Corta la lectura de "misma
                            // unidad de información" cuando el monto está
                            // apagado (isDone) y el subtotal es rojo
                            // (negativo) — evita que se lea como "alerta".
                            //
                            // P2d (polish-v1): Semantics agrupado sobre la
                            // Column completa con label descriptivo. Sin
                            // esto, TalkBack lee 2 nodos con símbolo "="
                            // literal ("igual, cien pesos").
                            Semantics(
                              container: true,
                              label: item.cumulativeAfter == null
                                  ? 'Monto ${formatCents(item.amount)}'
                                  : 'Monto ${formatCents(item.amount)}, '
                                      'saldo acumulado '
                                      '${formatCents(item.cumulativeAfter!)}',
                              excludeSemantics: true,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
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
                                    child: Text(formatCents(item.amount)),
                                  ),
                                  if (item.cumulativeAfter != null) ...[
                                    const SizedBox(height: 3),
                                    Container(
                                      width: 32,
                                      height: 1,
                                      color: FincoreColors.border,
                                    ),
                                    const SizedBox(height: 3),
                                    // P2b (polish-v1): `label` en lugar de
                                    // `overline`. `overline` tiene tracking
                                    // 1.2 pensado para labels en mayúsculas
                                    // ("MIS CUENTAS"); aplicado a una cifra
                                    // deja los dígitos con demasiado aire.
                                    // `label` (12sp/0.1 tracking) se lee
                                    // como número, no como etiqueta.
                                    //
                                    // P2c (polish-v1): TweenAnimationBuilder
                                    // sobre el valor. Cuando el reorder
                                    // cambia la cascada, el número se anima
                                    // en kMotionFast en vez de saltar de un
                                    // frame al siguiente. Comunica que "esto
                                    // se recalculó" como consecuencia del
                                    // reorder.
                                    // El tween interpola en `double` para que
                                    // el conteo sea suave; el display redondea
                                    // al centavo entero (RN-IC-04).
                                    TweenAnimationBuilder<double>(
                                      tween: Tween<double>(
                                        end: item.cumulativeAfter!.toDouble(),
                                      ),
                                      duration: kMotionFast,
                                      curve: kCurveStandard,
                                      builder: (context, value, _) {
                                        return Text(
                                          '= ${formatCents(value.round())}',
                                          style: label.copyWith(
                                            color: value < 0
                                                ? FincoreColors.negative
                                                : FincoreColors.textMuted,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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

/// P1a (polish-v1): background que aparece al hacer swipe hacia la izquierda
/// sobre un `_ItemRow`. Rojo con ícono `delete_outline` alineado a la
/// derecha, siguiendo el patrón Material que Diego ya reconoce de Gmail,
/// Todoist, etc.
class _DismissBackground extends StatelessWidget {
  const _DismissBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: FincoreColors.negative.withValues(
          alpha: FincoreColors.alphaTint,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: const Icon(
        Icons.delete_outline,
        color: FincoreColors.negative,
        size: 24,
      ),
    );
  }
}

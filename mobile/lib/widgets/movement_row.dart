import 'package:fincore/constants/kinds.dart';
import 'package:fincore/data/daos/entries_dao.dart';
import 'package:fincore/data/database.dart' as db;
import 'package:fincore/models/category.dart' as model;
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/theme/fincore_radii.dart';
import 'package:fincore/theme/fincore_spacing.dart';
import 'package:fincore/theme/fincore_typography.dart';
import 'package:fincore/widgets/amount_formatter.dart';
import 'package:fincore/widgets/base_card.dart';
import 'package:fincore/widgets/category_badge.dart' as cb;
import 'package:fincore/widgets/entry_account_label.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Card unificado de un movimiento. Reemplaza los widgets duplicados
/// `_EntryTile` del Dashboard y `_Row` de la lista paginada de
/// `/entries`. Layout de 3 líneas:
///
///   Línea 1: [ícono] descripción                    monto
///   Línea 2: cuenta · fecha · kind
///   Línea 3: [badge de categoría]   (solo si existe)
///
/// El tap navega al form de edición del movimiento. Si algún caller
/// necesita un comportamiento distinto en el futuro, se le agrega un
/// `onTap` opcional al constructor.
/// True si el kind acepta categoría. Sprint
/// flutter-entries-bulk-recategorize-v1: en modo selección solo estos
/// kinds pueden formar parte del batch. `transfer`, `debt_payment` y
/// `loan_payment` no aceptan categoría por RN-011 y quedan disabled.
bool isKindCategorizable(JournalKind k) => switch (k) {
      JournalKind.income ||
      JournalKind.expense ||
      JournalKind.creditExpense =>
        true,
      _ => false,
    };

class MovementRow extends StatelessWidget {
  final EntryWithRelations item;

  /// Formato de fecha corto (día + mes abreviado). Dashboard usa
  /// `'d MMM'`; la lista de `/entries` usa `'d MMM y'`. Pasado desde el
  /// caller para conservar la diferencia sin duplicar lógica.
  final String dateFormatPattern;

  /// Sprint flutter-entries-bulk-recategorize-v1: cuando `true`, la card
  /// reemplaza el ícono leading por un checkbox visual, el tap toggle
  /// selección (via `onTap` del caller) y las cards no-categorizables
  /// (transfer/debt_payment/loan_payment) se ven disabled + ignoran gestos.
  final bool selectionMode;

  /// Solo aplica cuando `selectionMode` es true. Estado del checkbox
  /// leading.
  final bool isSelected;

  /// Override del tap. Si `null`, mantiene el navigate default a
  /// `/entries/:id/edit`. El caller pasa un handler propio para toggle
  /// selección o dispatch a un flujo distinto.
  final VoidCallback? onTap;

  /// Handler opcional para long-press. Uso típico: entrar en modo
  /// selección desde el listado. Si `null`, no hay long-press activo.
  final VoidCallback? onLongPress;

  const MovementRow({
    super.key,
    required this.item,
    this.dateFormatPattern = 'd MMM y',
    this.selectionMode = false,
    this.isSelected = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final entry = item.entry;
    final kind = parseJournalKind(entry.kind);
    final color = _amountColor(kind);
    final signedAmount = _signedAmount(kind, entry.amount);
    final dateStr = DateFormat(dateFormatPattern, 'es_MX').format(
      entry.occurredAt,
    );
    final accountLabel = entryAccountLabel(item);
    final subtitleParts = [
      if (accountLabel != null) accountLabel,
      dateStr,
      kind.label,
    ];
    final hasCategory = item.category != null;
    final hasArchivedAccount = entryHasArchivedAccount(item);
    // Sprint flutter-loans-v1: chip pequeño naranja para movimientos ligados
    // a un préstamo (income inicial o loan_payment). Diego identifica que
    // ese movimiento se administra desde /loans, no desde /entries.
    final belongsToLoan = entry.loanId != null;

    // Sprint flutter-entries-bulk-recategorize-v1: en modo selección los
    // kinds no-categorizables se ven atenuados y no reciben gestos. Aparecen
    // en la lista para no cambiar el orden ni ocultar información al usuario,
    // pero comunican visualmente que no forman parte del batch posible.
    final isDisabled = selectionMode && !isKindCategorizable(kind);

    // Tap: en modo selección el caller provee un handler que toggle. Fuera
    // de modo selección, navega al form de edit por default (comportamiento
    // histórico). onTap explícito del caller siempre gana.
    final VoidCallback? effectiveTap = isDisabled
        ? null
        : (onTap ?? () => context.push('/entries/${entry.id}/edit'));
    final VoidCallback? effectiveLongPress = isDisabled ? null : onLongPress;

    final card = BaseCard(
      onTap: effectiveTap,
      onLongPress: effectiveLongPress,
      padding: kEdgeListItem,
      // isSelected propaga hover-tint del BaseCard cuando el row está
      // seleccionado — sin necesidad de duplicar la lógica de highlight en
      // este archivo. Mantiene la superficie coherente con otros usos.
      isSelected: selectionMode && isSelected,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (selectionMode)
            _SelectionLeading(
              isSelected: isSelected,
              isDisabled: isDisabled,
              kindColor: color,
            )
          else
            Container(
              // token-exception: 32 es tamaño de icono/leading, no de spacing.
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: FincoreColors.alphaTint),
                borderRadius: BorderRadius.circular(kRadiusMd),
              ),
              child: Icon(_kindIcon(kind), size: 16, color: color),
            ),
          const SizedBox(width: kSpaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        entry.description?.isNotEmpty == true
                            ? entry.description!
                            : kind.label,
                        style: bodyM.copyWith(fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: kSpaceSm),
                    Text(
                      signedAmount,
                      style: bodyM.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: kSpaceXs),
                Text(
                  subtitleParts.join(' · '),
                  style: hasArchivedAccount
                      ? overline.copyWith(
                          fontStyle: FontStyle.italic,
                          color: FincoreColors.textSubtle,
                        )
                      : overline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (hasCategory) ...[
                  const SizedBox(height: kSpaceXs),
                  cb.CategoryBadge(
                    category: _toModelCategory(item.category!),
                    compact: true,
                  ),
                ],
                if (belongsToLoan) ...[
                  const SizedBox(height: kSpaceXs),
                  const _LoanChip(),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    // Kinds no-categorizables en modo selección: atenuar toda la card y
    // dejar claro que no participa. `IgnorePointer` bloquea ripple/gestos
    // aunque effectiveTap ya sea null (defensa en profundidad).
    if (isDisabled) {
      return IgnorePointer(
        child: Opacity(opacity: FincoreColors.alphaMuted, child: card),
      );
    }
    return card;
  }

  Color _amountColor(JournalKind k) => switch (k) {
        JournalKind.income => FincoreColors.positive,
        JournalKind.expense ||
        JournalKind.creditExpense =>
          FincoreColors.negative,
        JournalKind.debtPayment ||
        JournalKind.transfer =>
          FincoreColors.accent,
        // F-DES-2: pago de préstamo con categoryOrange (marca del módulo).
        // warning queda reservado para alertas reales (chip próximo pago).
        JournalKind.loanPayment => FincoreColors.categoryOrange,
      };

  IconData _kindIcon(JournalKind k) => switch (k) {
        JournalKind.income => Icons.arrow_downward,
        JournalKind.expense => Icons.arrow_upward,
        JournalKind.creditExpense => Icons.credit_card_outlined,
        JournalKind.debtPayment => Icons.payments_outlined,
        JournalKind.transfer => Icons.swap_horiz,
        JournalKind.loanPayment => Icons.request_quote_outlined,
      };

  String _signedAmount(JournalKind k, double amount) => switch (k) {
        JournalKind.income => formatAmount(amount, showSign: true),
        JournalKind.expense ||
        JournalKind.creditExpense =>
          '-${formatAmount(amount)}',
        JournalKind.debtPayment ||
        JournalKind.transfer ||
        JournalKind.loanPayment =>
          formatAmount(amount),
      };

  model.Category _toModelCategory(db.Category c) {
    return model.Category(
      id: c.id,
      name: c.name,
      appliesTo: c.appliesTo,
      colorSlug: c.colorSlug,
      iconSlug: c.iconSlug,
      monthlyLimit: c.monthlyLimit,
      deletedAt: c.deletedAt,
    );
  }
}

/// Sprint flutter-entries-bulk-recategorize-v1: leading 32x32 que
/// reemplaza el ícono de kind cuando el `MovementRow` corre en modo
/// selección. Estados:
///
/// - `disabled` (kind no-categorizable): ícono block muted, sin borde.
/// - `unselected` (categorizable): círculo con contorno neutro.
/// - `selected`: círculo relleno accent con check.
///
/// Mismo tamaño que el ícono default para no romper layout.
class _SelectionLeading extends StatelessWidget {
  final bool isSelected;
  final bool isDisabled;
  final Color kindColor;

  const _SelectionLeading({
    required this.isSelected,
    required this.isDisabled,
    required this.kindColor,
  });

  @override
  Widget build(BuildContext context) {
    if (isDisabled) {
      return const SizedBox(
        width: 32,
        height: 32,
        child: Center(
          child: Icon(
            Icons.block,
            size: 18,
            color: FincoreColors.textSubtle,
          ),
        ),
      );
    }
    if (isSelected) {
      return Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: FincoreColors.accent,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.check,
          size: 18,
          color: FincoreColors.canvas,
        ),
      );
    }
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: FincoreColors.border, width: 1.5),
      ),
    );
  }
}

/// Chip pequeño naranja para el subtítulo de un movimiento ligado a préstamo.
/// F-DES-2: usa `categoryOrange` (marca del módulo) en vez de `warning`
/// (reservado para alertas reales — chip próximo pago del dashboard).
class _LoanChip extends StatelessWidget {
  const _LoanChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: kSpaceSm, vertical: kSpace2xs),
      decoration: BoxDecoration(
        color: FincoreColors.categoryOrange
            .withValues(alpha: FincoreColors.alphaTint),
        borderRadius: BorderRadius.circular(kRadiusSm),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.request_quote_outlined,
              size: 11, color: FincoreColors.categoryOrange),
          SizedBox(width: kSpace2xs),
          Text(
            'préstamo',
            style: TextStyle(
              color: FincoreColors.categoryOrange,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

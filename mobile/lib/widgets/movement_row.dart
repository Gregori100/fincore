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
class MovementRow extends StatelessWidget {
  final EntryWithRelations item;

  /// Formato de fecha corto (día + mes abreviado). Dashboard usa
  /// `'d MMM'`; la lista de `/entries` usa `'d MMM y'`. Pasado desde el
  /// caller para conservar la diferencia sin duplicar lógica.
  final String dateFormatPattern;

  const MovementRow({
    super.key,
    required this.item,
    this.dateFormatPattern = 'd MMM y',
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

    return BaseCard(
      onTap: () => context.push('/entries/${entry.id}/edit'),
      padding: kEdgeListItem,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
  }

  Color _amountColor(JournalKind k) => switch (k) {
        JournalKind.income => FincoreColors.positive,
        JournalKind.expense ||
        JournalKind.creditExpense =>
          FincoreColors.negative,
        JournalKind.debtPayment ||
        JournalKind.transfer =>
          FincoreColors.accent,
        // Sprint flutter-loans-v1: pago de préstamo pinta naranja como el
        // resto del módulo (KPI, chip · préstamo, iconografía).
        JournalKind.loanPayment => FincoreColors.warning,
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

/// Chip pequeño naranja para el subtítulo de un movimiento ligado a préstamo.
/// Sprint flutter-loans-v1: señal visual de que el entry se administra desde
/// /loans y NO es editable desde entry_form_screen.
class _LoanChip extends StatelessWidget {
  const _LoanChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: kSpaceSm, vertical: kSpace2xs),
      decoration: BoxDecoration(
        color:
            FincoreColors.warning.withValues(alpha: FincoreColors.alphaTint),
        borderRadius: BorderRadius.circular(kRadiusSm),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.request_quote_outlined,
              size: 11, color: FincoreColors.warning),
          SizedBox(width: kSpace2xs),
          Text(
            'préstamo',
            style: TextStyle(
              color: FincoreColors.warning,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

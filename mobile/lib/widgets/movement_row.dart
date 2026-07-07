import 'package:fincore/constants/kinds.dart';
import 'package:fincore/data/daos/entries_dao.dart';
import 'package:fincore/data/database.dart' as db;
import 'package:fincore/models/category.dart' as model;
import 'package:fincore/theme/fincore_colors.dart';
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

    return BaseCard(
      onTap: () => context.push('/entries/${entry.id}/edit'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_kindIcon(kind), size: 16, color: color),
          ),
          const SizedBox(width: 12),
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
                        style: const TextStyle(
                          color: FincoreColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      signedAmount,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitleParts.join(' · '),
                  style: const TextStyle(
                    color: FincoreColors.textSubtle,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (hasCategory) ...[
                  const SizedBox(height: 6),
                  cb.CategoryBadge(
                    category: _toModelCategory(item.category!),
                    compact: true,
                  ),
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
      };

  IconData _kindIcon(JournalKind k) => switch (k) {
        JournalKind.income => Icons.arrow_downward,
        JournalKind.expense => Icons.arrow_upward,
        JournalKind.creditExpense => Icons.credit_card_outlined,
        JournalKind.debtPayment => Icons.payments_outlined,
        JournalKind.transfer => Icons.swap_horiz,
      };

  String _signedAmount(JournalKind k, double amount) => switch (k) {
        JournalKind.income => formatAmount(amount, showSign: true),
        JournalKind.expense ||
        JournalKind.creditExpense =>
          '-${formatAmount(amount)}',
        JournalKind.debtPayment ||
        JournalKind.transfer =>
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

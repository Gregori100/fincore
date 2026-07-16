import 'package:fincore/constants/kinds.dart';
import 'package:fincore/data/daos/entries_dao.dart';
import 'package:fincore/data/database.dart' as db;

/// Texto compacto que resume las cuentas involucradas en un movimiento.
/// Formato según el kind:
///
/// - `income`                        → nombre de la cuenta destino.
/// - `expense` / `credit_expense`    → nombre de la cuenta origen.
/// - `debt_payment` / `transfer`     → "origen → destino".
///
/// Sprint flutter-accounts-archive-v1: cuando una cuenta involucrada está
/// archivada (`archived_at != null`) el nombre se sufija con "(archivada)"
/// para dejar clara la señal en /entries y en el Dashboard. La cuenta sigue
/// participando del histórico pero está fuera de los pickers de alta.
///
/// Devuelve `null` si faltan los datos necesarios (cuenta borrada por FK
/// colgante o entry corrupto), para que el caller pueda omitirlo del
/// subtexto sin colgar la UI. Usado por el Dashboard y por la lista
/// paginada de `/entries` (sprint UX de visibilidad de cuenta).
String? entryAccountLabel(EntryWithRelations item) {
  final kind = parseJournalKind(item.entry.kind);
  final originName = _decoratedName(item.accountOrigin);
  final destName = _decoratedName(item.accountDestination);
  switch (kind) {
    case JournalKind.income:
      return destName;
    case JournalKind.expense:
    case JournalKind.creditExpense:
      return originName;
    case JournalKind.debtPayment:
    case JournalKind.transfer:
      if (originName != null && destName != null) {
        return '$originName → $destName';
      }
      return originName ?? destName;
  }
}

String? _decoratedName(db.Account? account) {
  if (account == null) return null;
  if (account.archivedAt != null) return '${account.name} (archivada)';
  return account.name;
}

/// Retorna true si alguna de las cuentas del entry está archivada. Útil para
/// aplicar estilo diferenciado (italic + textSubtle) al subtítulo en la UI
/// sin repetir la lógica de detección en cada caller.
bool entryHasArchivedAccount(EntryWithRelations item) {
  return item.accountOrigin?.archivedAt != null ||
      item.accountDestination?.archivedAt != null;
}

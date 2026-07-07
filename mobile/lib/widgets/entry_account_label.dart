import 'package:fincore/constants/kinds.dart';
import 'package:fincore/data/daos/entries_dao.dart';

/// Texto compacto que resume las cuentas involucradas en un movimiento.
/// Formato según el kind:
///
/// - `income`                        → nombre de la cuenta destino.
/// - `expense` / `credit_expense`    → nombre de la cuenta origen.
/// - `debt_payment` / `transfer`     → "origen → destino".
///
/// Devuelve `null` si faltan los datos necesarios (cuenta borrada por FK
/// colgante o entry corrupto), para que el caller pueda omitirlo del
/// subtexto sin colgar la UI. Usado por el Dashboard y por la lista
/// paginada de `/entries` (sprint UX de visibilidad de cuenta).
String? entryAccountLabel(EntryWithRelations item) {
  final kind = parseJournalKind(item.entry.kind);
  final originName = item.accountOrigin?.name;
  final destName = item.accountDestination?.name;
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

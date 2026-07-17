/// Tipos de movimiento (journal entry) que el cliente expone al usuario.
/// Los valores `apiValue()` deben coincidir 1:1 con `JournalEntry::KIND_*` del
/// backend (`backend/app/Models/JournalEntry.php`). NO incluimos `adjustment`
/// porque no está implementado en backend.
enum JournalKind {
  income,
  expense,
  creditExpense,
  debtPayment,
  transfer,
  // Sprint flutter-loans-v1: pago de préstamo (kind 'loan_payment'). Se
  // registra desde /loans/:id/payments/new/*, NO desde el KindPicker de
  // /entries/new. Existe en el enum para que `parseJournalKind` no explote
  // al leer entries persistidas (el famoso bug del "recuadro gris" en la
  // lista de movimientos).
  loanPayment,
}

extension JournalKindX on JournalKind {
  /// String que viaja al backend (snake_case).
  String get apiValue {
    switch (this) {
      case JournalKind.income:
        return 'income';
      case JournalKind.expense:
        return 'expense';
      case JournalKind.creditExpense:
        return 'credit_expense';
      case JournalKind.debtPayment:
        return 'debt_payment';
      case JournalKind.transfer:
        return 'transfer';
      case JournalKind.loanPayment:
        return 'loan_payment';
    }
  }

  /// Etiqueta visible en la UI (español).
  String get label {
    switch (this) {
      case JournalKind.income:
        return 'Ingreso';
      case JournalKind.expense:
        return 'Gasto';
      case JournalKind.creditExpense:
        return 'Gasto a tarjeta';
      case JournalKind.debtPayment:
        return 'Pago de tarjeta';
      case JournalKind.transfer:
        return 'Transferencia';
      case JournalKind.loanPayment:
        return 'Pago de préstamo';
    }
  }

  /// Si requiere o no categoría asociada.
  /// transfer, debt_payment y loan_payment no aceptan categoría (validado
  /// por DAO). loan_payment lleva su propio split principal/interest y
  /// los intereses aparecen en spending_by_category como renglón sintético.
  bool get acceptsCategory {
    return this == JournalKind.income ||
        this == JournalKind.expense ||
        this == JournalKind.creditExpense;
  }

  /// `applies_to` válido para categorías filtradas por este kind.
  /// Income → categorías 'income' o 'both'. Expense/credit_expense → 'expense' o 'both'.
  List<String> get validCategoryAppliesTo {
    switch (this) {
      case JournalKind.income:
        return ['income', 'both'];
      case JournalKind.expense:
      case JournalKind.creditExpense:
        return ['expense', 'both'];
      case JournalKind.debtPayment:
      case JournalKind.transfer:
      case JournalKind.loanPayment:
        return const <String>[];
    }
  }
}

/// Parsea el string del backend a enum. Lanza si es desconocido.
JournalKind parseJournalKind(String apiValue) {
  for (final k in JournalKind.values) {
    if (k.apiValue == apiValue) return k;
  }
  throw FormatException('JournalKind desconocido: $apiValue');
}

/// Set canónico de kinds válidos derivado del enum. Hotfix
/// branch-quality-review (F-ARCH-02): fuente única de verdad para
/// validaciones cross-módulo. Antes del hotfix existían 3 hardcoded sets
/// duplicados en `EntriesDao._validKinds`, `BackupService._validKinds` y
/// `EntriesFilters._kValidKinds` — la triplicación causó que el chip
/// "Pago de préstamo" en filtros no round-trippeara porque uno de los
/// 3 sets no se actualizó tras agregar `loanPayment` al enum.
final Set<String> kAllJournalKinds = {
  for (final k in JournalKind.values) k.apiValue,
};

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
    }
  }

  /// Si requiere o no categoría asociada.
  /// transfer y debt_payment no aceptan categoría (validado por backend).
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

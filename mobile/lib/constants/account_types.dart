import 'package:fincore/constants/kinds.dart';

/// Tipos de cuenta. cash es la Bolsa singleton (no se crea, no se elimina).
/// Coincide con `Account::TYPE_*` del backend.
enum AccountType {
  cash,
  debit,
  credit,
}

extension AccountTypeX on AccountType {
  String get apiValue {
    switch (this) {
      case AccountType.cash:
        return 'cash';
      case AccountType.debit:
        return 'debit';
      case AccountType.credit:
        return 'credit';
    }
  }

  String get label {
    switch (this) {
      case AccountType.cash:
        return 'Bolsa';
      case AccountType.debit:
        return 'Débito';
      case AccountType.credit:
        return 'Crédito';
    }
  }

  /// cash y debit son "cash-like" — backend los trata equivalente para origen/destino
  /// excepto en credit_expense (que exige credit) y debt_payment (que exige credit como destination).
  bool get isCashLike => this == AccountType.cash || this == AccountType.debit;

  /// ¿Puede ser `account_origin_id` para este kind?
  bool canBeOrigin(JournalKind kind) {
    switch (kind) {
      case JournalKind.income:
        return false; // income tiene origin = null
      case JournalKind.expense:
        return isCashLike;
      case JournalKind.creditExpense:
        return this == AccountType.credit;
      case JournalKind.debtPayment:
        return isCashLike;
      case JournalKind.transfer:
        return isCashLike;
    }
  }

  /// ¿Puede ser `account_destination_id` para este kind?
  bool canBeDestination(JournalKind kind) {
    switch (kind) {
      case JournalKind.income:
        return isCashLike;
      case JournalKind.expense:
        return false; // expense tiene destination = null
      case JournalKind.creditExpense:
        return false; // credit_expense tiene destination = null
      case JournalKind.debtPayment:
        return this == AccountType.credit;
      case JournalKind.transfer:
        return isCashLike;
    }
  }
}

AccountType parseAccountType(String apiValue) {
  for (final t in AccountType.values) {
    if (t.apiValue == apiValue) return t;
  }
  throw FormatException('AccountType desconocido: $apiValue');
}

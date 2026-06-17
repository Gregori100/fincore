import 'package:fincore/constants/account_types.dart';
import 'package:fincore/constants/category_catalog.dart';
import 'package:fincore/constants/kinds.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JournalKind', () {
    test('apiValue snake_case matches backend', () {
      expect(JournalKind.income.apiValue, 'income');
      expect(JournalKind.creditExpense.apiValue, 'credit_expense');
      expect(JournalKind.debtPayment.apiValue, 'debt_payment');
    });

    test('parseJournalKind acepta los 5 valores backend', () {
      expect(parseJournalKind('income'), JournalKind.income);
      expect(parseJournalKind('expense'), JournalKind.expense);
      expect(parseJournalKind('credit_expense'), JournalKind.creditExpense);
      expect(parseJournalKind('debt_payment'), JournalKind.debtPayment);
      expect(parseJournalKind('transfer'), JournalKind.transfer);
    });

    test('parseJournalKind desconocido lanza', () {
      expect(() => parseJournalKind('adjustment'), throwsA(isA<FormatException>()));
    });

    test('acceptsCategory: solo income/expense/creditExpense', () {
      expect(JournalKind.income.acceptsCategory, isTrue);
      expect(JournalKind.expense.acceptsCategory, isTrue);
      expect(JournalKind.creditExpense.acceptsCategory, isTrue);
      expect(JournalKind.transfer.acceptsCategory, isFalse);
      expect(JournalKind.debtPayment.acceptsCategory, isFalse);
    });

    test('validCategoryAppliesTo coherente con backend', () {
      expect(JournalKind.income.validCategoryAppliesTo, ['income', 'both']);
      expect(JournalKind.expense.validCategoryAppliesTo, ['expense', 'both']);
      expect(JournalKind.creditExpense.validCategoryAppliesTo, ['expense', 'both']);
      expect(JournalKind.transfer.validCategoryAppliesTo, isEmpty);
    });
  });

  group('AccountType', () {
    test('canBeOrigin para los 5 kinds × 3 tipos', () {
      // income: ningún tipo puede ser origin
      expect(AccountType.cash.canBeOrigin(JournalKind.income), isFalse);
      expect(AccountType.debit.canBeOrigin(JournalKind.income), isFalse);
      expect(AccountType.credit.canBeOrigin(JournalKind.income), isFalse);

      // expense: cash o debit
      expect(AccountType.cash.canBeOrigin(JournalKind.expense), isTrue);
      expect(AccountType.debit.canBeOrigin(JournalKind.expense), isTrue);
      expect(AccountType.credit.canBeOrigin(JournalKind.expense), isFalse);

      // creditExpense: solo credit
      expect(AccountType.credit.canBeOrigin(JournalKind.creditExpense), isTrue);
      expect(AccountType.cash.canBeOrigin(JournalKind.creditExpense), isFalse);

      // debtPayment: cash o debit
      expect(AccountType.cash.canBeOrigin(JournalKind.debtPayment), isTrue);
      expect(AccountType.credit.canBeOrigin(JournalKind.debtPayment), isFalse);

      // transfer: cash o debit
      expect(AccountType.cash.canBeOrigin(JournalKind.transfer), isTrue);
      expect(AccountType.credit.canBeOrigin(JournalKind.transfer), isFalse);
    });

    test('canBeDestination coherente', () {
      expect(AccountType.cash.canBeDestination(JournalKind.income), isTrue);
      expect(AccountType.credit.canBeDestination(JournalKind.income), isFalse);
      expect(AccountType.credit.canBeDestination(JournalKind.debtPayment), isTrue);
      expect(AccountType.cash.canBeDestination(JournalKind.debtPayment), isFalse);
      expect(AccountType.debit.canBeDestination(JournalKind.transfer), isTrue);
      expect(AccountType.credit.canBeDestination(JournalKind.transfer), isFalse);
      expect(AccountType.cash.canBeDestination(JournalKind.expense), isFalse);
    });
  });

  group('CategoryCatalog', () {
    test('los 10 slugs de color están definidos', () {
      const expected = {'blue', 'green', 'red', 'orange', 'purple', 'pink', 'teal', 'yellow', 'indigo', 'gray'};
      final actual = kCategoryColors.map((c) => c.slug).toSet();
      expect(actual, expected);
    });

    test('colorBySlug retorna fallback si slug desconocido', () {
      expect(colorBySlug('inexistente'), kFallbackCategoryColor);
    });

    test('iconBySlug retorna fallback si slug desconocido', () {
      expect(iconBySlug('inexistente'), kFallbackCategoryIcon);
    });
  });
}

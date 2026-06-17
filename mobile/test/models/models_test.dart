import 'package:fincore/constants/account_types.dart';
import 'package:fincore/constants/kinds.dart';
import 'package:fincore/models/account.dart';
import 'package:fincore/models/category.dart';
import 'package:fincore/models/domain_error.dart';
import 'package:fincore/models/finance_state.dart';
import 'package:fincore/models/journal_entry.dart';
import 'package:fincore/models/paginated.dart';
import 'package:fincore/models/user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('User', () {
    test('fromJson parses email_verified_at', () {
      final u = User.fromJson({
        'id': 'u1',
        'name': 'Diego',
        'email': 'a@b.com',
        'email_verified_at': '2026-01-01T00:00:00Z',
      });
      expect(u.isVerified, isTrue);
    });

    test('fromJson trata null como no verificado', () {
      final u = User.fromJson({
        'id': 'u1',
        'name': 'Diego',
        'email': 'a@b.com',
        'email_verified_at': null,
      });
      expect(u.isVerified, isFalse);
    });
  });

  group('Account', () {
    test('fromJson cash con metadata de credit null', () {
      final a = Account.fromJson({
        'id': 'a1',
        'name': 'Bolsa',
        'type': 'cash',
        'description': null,
        'is_protected': true,
        'deleted_at': null,
        'balance': 100,
      });
      expect(a.type, AccountType.cash);
      expect(a.isProtected, isTrue);
      expect(a.creditLimit, isNull);
    });

    test('fromJson credit con metadata completa', () {
      final a = Account.fromJson({
        'id': 'a1',
        'name': 'Visa',
        'type': 'credit',
        'description': null,
        'is_protected': false,
        'deleted_at': null,
        'credit_limit': 50000,
        'closing_day': 15,
        'payment_day': 5,
        'balance': 12000,
      });
      expect(a.isCredit, isTrue);
      expect(a.creditLimit, 50000);
      expect(a.closingDay, 15);
      expect(a.paymentDay, 5);
    });
  });

  group('Category', () {
    test('fromJson incluye applies_to, color_slug, icon_slug', () {
      final c = Category.fromJson({
        'id': 'c1',
        'name': 'Comida',
        'applies_to': 'expense',
        'color_slug': 'orange',
        'icon_slug': 'cake',
        'monthly_limit': null,
        'deleted_at': null,
      });
      expect(c.appliesTo, 'expense');
      expect(c.colorSlug, 'orange');
      expect(c.isArchived, isFalse);
    });

    test('matchesKindFilter filtra correctamente', () {
      const cat = Category(
        id: 'x', name: 'X', appliesTo: 'expense',
        colorSlug: 'blue', iconSlug: 'tag', monthlyLimit: null, deletedAt: null,
      );
      expect(cat.matchesKindFilter(['expense', 'both']), isTrue);
      expect(cat.matchesKindFilter(['income', 'both']), isFalse);
    });
  });

  group('JournalEntry', () {
    test('fromJson parses kind + relaciones embebidas opcionales', () {
      final e = JournalEntry.fromJson({
        'id': 'e1',
        'kind': 'expense',
        'account_origin_id': 'a1',
        'account_destination_id': null,
        'amount': 100,
        'description': 'Café',
        'occurred_at': '2026-06-12T10:00:00Z',
        'category_id': null,
        'deleted_at': null,
        'category': null,
      });
      expect(e.kind, JournalKind.expense);
      expect(e.amount, 100);
      expect(e.category, isNull);
    });
  });

  group('Paginated', () {
    test('hasNext correcto cuando current < last', () {
      final p = Paginated<String>.fromJson(
        {
          'data': [{'x': 'a'}, {'x': 'b'}],
          'current_page': 1,
          'last_page': 3,
          'per_page': 15,
          'total': 45,
        },
        (m) => m['x'] as String,
      );
      expect(p.hasNext, isTrue);
      expect(p.data.length, 2);
    });

    test('hasNext false cuando lastPage es null', () {
      final p = Paginated<String>.fromJson(
        {'data': [], 'current_page': 1},
        (m) => '',
      );
      expect(p.hasNext, isFalse);
    });
  });

  group('DomainError', () {
    test('fromJson formato DomainException preserva code', () {
      final e = DomainError.fromJson(
        {'error': 'Pagás de más', 'code': 'overpay_debt'},
        statusCode: 422,
      );
      expect(e.code, 'overpay_debt');
      expect(e.message, 'Pagás de más');
    });

    test('fromJson formato validación Laravel parsea fieldErrors', () {
      final e = DomainError.fromJson(
        {
          'message': 'Invalid.',
          'errors': {'email': ['El email es inválido.']},
        },
        statusCode: 422,
      );
      expect(e.code, isNull);
      expect(e.fieldErrors['email'], ['El email es inválido.']);
    });
  });

  group('FinanceState', () {
    test('fromJson parsea totales + listas', () {
      final s = FinanceState.fromJson({
        'bo': 1500,
        'de': 3000,
        'cr': 47000,
        'accounts': [],
        'recent_entries': [],
        'categories': [],
      });
      expect(s.bo, 1500);
      expect(s.de, 3000);
      expect(s.cr, 47000);
    });

    test('fromJson tolera campos faltantes con default 0/[]', () {
      final s = FinanceState.fromJson({});
      expect(s.bo, 0);
      expect(s.accounts, isEmpty);
    });
  });
}

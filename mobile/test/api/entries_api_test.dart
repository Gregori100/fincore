import 'package:fincore/api/entries_api.dart';
import 'package:fincore/constants/kinds.dart';
import 'package:fincore/models/domain_error.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/mock_dio.dart';

Map<String, dynamic> _entryJson({
  String id = 'e1',
  String kind = 'expense',
  String? originId = 'a1',
  String? destinationId,
  num amount = 100,
  String? categoryId,
}) {
  return {
    'id': id,
    'kind': kind,
    'account_origin_id': originId,
    'account_destination_id': destinationId,
    'amount': amount,
    'description': 'Café',
    'occurred_at': '2026-06-12T10:00:00Z',
    'category_id': categoryId,
    'deleted_at': null,
  };
}

void main() {
  late MockApiClient client;
  late MockDio dio;
  late EntriesApi entries;

  setUpAll(registerDioFallbacks);

  setUp(() {
    client = MockApiClient();
    dio = MockDio();
    when(() => client.dio).thenReturn(dio);
    entries = EntriesApi(client);
  });

  test('registerIncome → POST /finance/income con account_destination_id', () async {
    when(() => dio.post<Map<String, dynamic>>(
          '/finance/income',
          data: any(named: 'data'),
        )).thenAnswer((_) async => buildResponse('/finance/income', {
          'data': _entryJson(kind: 'income', originId: null, destinationId: 'd1'),
        }));

    final e = await entries.registerIncome(
      accountDestinationId: 'd1',
      amount: 100,
      occurredAt: DateTime.parse('2026-06-12T10:00:00Z'),
    );
    expect(e.kind, JournalKind.income);
    expect(e.accountDestinationId, 'd1');
  });

  test('registerExpense → POST /finance/expense con account_origin_id', () async {
    when(() => dio.post<Map<String, dynamic>>(
          '/finance/expense',
          data: any(named: 'data'),
        )).thenAnswer((_) async => buildResponse('/finance/expense', {
          'data': _entryJson(),
        }));

    final e = await entries.registerExpense(
      accountOriginId: 'a1',
      amount: 50,
      occurredAt: DateTime.now(),
    );
    expect(e.kind, JournalKind.expense);
  });

  test('registerCreditExpense → POST /finance/credit-expense', () async {
    when(() => dio.post<Map<String, dynamic>>(
          '/finance/credit-expense',
          data: any(named: 'data'),
        )).thenAnswer((_) async => buildResponse('/finance/credit-expense', {
          'data': _entryJson(kind: 'credit_expense'),
        }));

    final e = await entries.registerCreditExpense(
      accountOriginId: 'a1',
      amount: 500,
      occurredAt: DateTime.now(),
    );
    expect(e.kind, JournalKind.creditExpense);
  });

  test('registerDebtPayment → POST /finance/pay-credit', () async {
    when(() => dio.post<Map<String, dynamic>>(
          '/finance/pay-credit',
          data: any(named: 'data'),
        )).thenAnswer((_) async => buildResponse('/finance/pay-credit', {
          'data': _entryJson(kind: 'debt_payment', destinationId: 'c1'),
        }));

    final e = await entries.registerDebtPayment(
      accountOriginId: 'a1',
      accountDestinationId: 'c1',
      amount: 200,
      occurredAt: DateTime.now(),
    );
    expect(e.kind, JournalKind.debtPayment);
  });

  test('registerDebtPayment con overpay_debt → DomainError code=overpay_debt', () async {
    when(() => dio.post<Map<String, dynamic>>(
          '/finance/pay-credit',
          data: any(named: 'data'),
        )).thenThrow(buildDioException(
      path: '/finance/pay-credit',
      statusCode: 422,
      body: {'error': 'Pagás más de lo que debés.', 'code': 'overpay_debt'},
    ));

    expect(
      () => entries.registerDebtPayment(
        accountOriginId: 'a1',
        accountDestinationId: 'c1',
        amount: 99999,
        occurredAt: DateTime.now(),
      ),
      throwsA(isA<DomainError>().having((e) => e.code, 'code', 'overpay_debt')),
    );
  });

  test('registerTransfer → POST /finance/transfer', () async {
    when(() => dio.post<Map<String, dynamic>>(
          '/finance/transfer',
          data: any(named: 'data'),
        )).thenAnswer((_) async => buildResponse('/finance/transfer', {
          'data': _entryJson(kind: 'transfer', destinationId: 'd1'),
        }));

    final e = await entries.registerTransfer(
      accountOriginId: 'a1',
      accountDestinationId: 'd1',
      amount: 1000,
      occurredAt: DateTime.now(),
    );
    expect(e.kind, JournalKind.transfer);
  });

  test('update → PATCH /finance/entries/{id} con fields', () async {
    when(() => dio.patch<Map<String, dynamic>>(
          '/finance/entries/e1',
          data: any(named: 'data'),
        )).thenAnswer((_) async => buildResponse('/finance/entries/e1', {
          'data': _entryJson(amount: 300),
        }));

    final e = await entries.update('e1', {'amount': 300});
    expect(e.amount, 300);
  });

  test('cancel exitoso → DELETE /finance/entries/{id}', () async {
    when(() => dio.delete<dynamic>('/finance/entries/e1'))
        .thenAnswer((_) async => buildResponse<dynamic>('/finance/entries/e1', null, statusCode: 204));
    await entries.cancel('e1');
  });

  test('cancel con 404 (race condition) NO lanza — race silenciada', () async {
    when(() => dio.delete<dynamic>('/finance/entries/e1')).thenThrow(
      buildDioException(
        path: '/finance/entries/e1',
        statusCode: 404,
        body: {'message': 'Not found'},
      ),
    );
    await entries.cancel('e1'); // sin throw
  });

  test('cancel con 422 sí lanza', () async {
    when(() => dio.delete<dynamic>('/finance/entries/e1')).thenThrow(
      buildDioException(
        path: '/finance/entries/e1',
        statusCode: 422,
        body: {'error': 'No editable', 'code': 'immutable_journal_field'},
      ),
    );
    expect(() => entries.cancel('e1'), throwsA(isA<DomainError>()));
  });
}

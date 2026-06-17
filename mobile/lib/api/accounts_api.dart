import 'package:dio/dio.dart';
import 'package:fincore/api/api_client.dart';
import 'package:fincore/models/account.dart';

class AccountsApi {
  final ApiClient client;
  AccountsApi(this.client);

  Future<List<Account>> list({bool includeArchived = false}) async {
    try {
      final response = await client.dio.get<Map<String, dynamic>>(
        '/finance/accounts',
        queryParameters: includeArchived ? <String, dynamic>{'include_archived': 1} : null,
      );
      final data = (response.data!['data'] as List<dynamic>);
      return data.map((e) => Account.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw dioToDomainError(e);
    }
  }

  Future<Account> create({
    required String name,
    required String type, // 'debit' | 'credit'
    String? description,
    num? creditLimit,
    int? closingDay,
    int? paymentDay,
    num? interestRate,
    num? minimumPaymentPct,
  }) async {
    try {
      final response = await client.dio.post<Map<String, dynamic>>(
        '/finance/accounts',
        data: <String, dynamic>{
          'name': name,
          'type': type,
          if (description != null) 'description': description,
          if (creditLimit != null) 'credit_limit': creditLimit,
          if (closingDay != null) 'closing_day': closingDay,
          if (paymentDay != null) 'payment_day': paymentDay,
          if (interestRate != null) 'interest_rate': interestRate,
          if (minimumPaymentPct != null) 'minimum_payment_pct': minimumPaymentPct,
        },
      );
      return Account.fromJson(response.data!['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw dioToDomainError(e);
    }
  }

  Future<Account> update(String id, Map<String, dynamic> fields) async {
    try {
      final response = await client.dio.patch<Map<String, dynamic>>(
        '/finance/accounts/$id',
        data: fields,
      );
      return Account.fromJson(response.data!['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw dioToDomainError(e);
    }
  }

  Future<void> delete(String id) async {
    try {
      await client.dio.delete<dynamic>('/finance/accounts/$id');
    } on DioException catch (e) {
      throw dioToDomainError(e);
    }
  }
}

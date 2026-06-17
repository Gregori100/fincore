import 'package:dio/dio.dart';
import 'package:fincore/api/api_client.dart';
import 'package:fincore/constants/kinds.dart';
import 'package:fincore/models/journal_entry.dart';
import 'package:fincore/models/paginated.dart';

/// Filtros opcionales para la lista de entries.
class EntriesFilter {
  final String? accountId;
  final String? categoryId;
  final JournalKind? kind;
  final DateTime? from;
  final DateTime? to;
  final int? page;

  const EntriesFilter({
    this.accountId,
    this.categoryId,
    this.kind,
    this.from,
    this.to,
    this.page,
  });

  Map<String, dynamic> toQuery() {
    final qp = <String, dynamic>{};
    if (accountId != null) qp['account_id'] = accountId;
    if (categoryId != null) qp['category_id'] = categoryId;
    if (kind != null) qp['kind'] = kind!.apiValue;
    if (from != null) qp['from'] = _ymd(from!);
    if (to != null) qp['to'] = _ymd(to!);
    if (page != null) qp['page'] = page;
    return qp;
  }

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class EntriesApi {
  final ApiClient client;
  EntriesApi(this.client);

  Future<Paginated<JournalEntry>> list(EntriesFilter filter) async {
    try {
      final response = await client.dio.get<Map<String, dynamic>>(
        '/finance/entries',
        queryParameters: filter.toQuery().isEmpty ? null : filter.toQuery(),
      );
      return Paginated<JournalEntry>.fromJson(
        response.data!,
        (m) => JournalEntry.fromJson(m),
      );
    } on DioException catch (e) {
      throw dioToDomainError(e);
    }
  }

  Future<JournalEntry> registerIncome({
    required String accountDestinationId,
    required num amount,
    required DateTime occurredAt,
    String? description,
    String? categoryId,
  }) =>
      _postEntry('/finance/income', {
        'account_destination_id': accountDestinationId,
        'amount': amount,
        'occurred_at': occurredAt.toIso8601String(),
        if (description != null) 'description': description,
        if (categoryId != null) 'category_id': categoryId,
      });

  Future<JournalEntry> registerExpense({
    required String accountOriginId,
    required num amount,
    required DateTime occurredAt,
    String? description,
    String? categoryId,
  }) =>
      _postEntry('/finance/expense', {
        'account_origin_id': accountOriginId,
        'amount': amount,
        'occurred_at': occurredAt.toIso8601String(),
        if (description != null) 'description': description,
        if (categoryId != null) 'category_id': categoryId,
      });

  Future<JournalEntry> registerCreditExpense({
    required String accountOriginId,
    required num amount,
    required DateTime occurredAt,
    String? description,
    String? categoryId,
  }) =>
      _postEntry('/finance/credit-expense', {
        'account_origin_id': accountOriginId,
        'amount': amount,
        'occurred_at': occurredAt.toIso8601String(),
        if (description != null) 'description': description,
        if (categoryId != null) 'category_id': categoryId,
      });

  Future<JournalEntry> registerDebtPayment({
    required String accountOriginId,
    required String accountDestinationId,
    required num amount,
    required DateTime occurredAt,
    String? description,
  }) =>
      _postEntry('/finance/pay-credit', {
        'account_origin_id': accountOriginId,
        'account_destination_id': accountDestinationId,
        'amount': amount,
        'occurred_at': occurredAt.toIso8601String(),
        if (description != null) 'description': description,
      });

  Future<JournalEntry> registerTransfer({
    required String accountOriginId,
    required String accountDestinationId,
    required num amount,
    required DateTime occurredAt,
    String? description,
  }) =>
      _postEntry('/finance/transfer', {
        'account_origin_id': accountOriginId,
        'account_destination_id': accountDestinationId,
        'amount': amount,
        'occurred_at': occurredAt.toIso8601String(),
        if (description != null) 'description': description,
      });

  Future<JournalEntry> _postEntry(String path, Map<String, dynamic> body) async {
    try {
      final response = await client.dio.post<Map<String, dynamic>>(path, data: body);
      return JournalEntry.fromJson(response.data!['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw dioToDomainError(e);
    }
  }

  Future<JournalEntry> update(String id, Map<String, dynamic> fields) async {
    try {
      final response = await client.dio.patch<Map<String, dynamic>>(
        '/finance/entries/$id',
        data: fields,
      );
      return JournalEntry.fromJson(response.data!['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw dioToDomainError(e);
    }
  }

  /// Cancelar entry. 404 se trata como "ya estaba cancelado" (race con otro device).
  /// El caller decide si refrescar la lista o silenciar.
  Future<void> cancel(String id) async {
    try {
      await client.dio.delete<dynamic>('/finance/entries/$id');
    } on DioException catch (e) {
      final domain = dioToDomainError(e);
      if (domain.statusCode == 404) {
        // Tratar como éxito; caller decide qué hacer.
        return;
      }
      throw domain;
    }
  }
}

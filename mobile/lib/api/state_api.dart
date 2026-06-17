import 'package:dio/dio.dart';
import 'package:fincore/api/api_client.dart';
import 'package:fincore/models/finance_state.dart';

class StateApi {
  final ApiClient client;
  StateApi(this.client);

  /// GET /api/finance/state → BO/DE/CR + cuentas + entries recientes + categorías.
  Future<FinanceState> fetch() async {
    try {
      final response = await client.dio.get<Map<String, dynamic>>('/finance/state');
      return FinanceState.fromJson(response.data!);
    } on DioException catch (e) {
      throw dioToDomainError(e);
    }
  }
}

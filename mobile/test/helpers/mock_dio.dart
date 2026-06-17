import 'package:dio/dio.dart';
import 'package:fincore/api/api_client.dart';
import 'package:fincore/models/domain_error.dart';
import 'package:mocktail/mocktail.dart';

/// Mocks usados por los tests de la capa API.
///
/// Las `*_api.dart` reciben un `ApiClient` y sólo tocan `client.dio`. Mockeamos
/// los dos: el `ApiClient` para responder a `.dio` con un `MockDio`, y el
/// `MockDio` para responder a `get`/`post`/`patch`/`delete` con respuestas
/// controladas o `DioException` cuando el test simula errores.
class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

/// Builder de Response que simplifica setear status + data.
Response<T> buildResponse<T>(
  String path,
  T data, {
  int statusCode = 200,
}) {
  return Response<T>(
    requestOptions: RequestOptions(path: path),
    data: data,
    statusCode: statusCode,
  );
}

/// Builder de DioException con un Response asociado. Simula lo que el
/// `_ErrorInterceptor` haría en runtime: parsear el body como `DomainError` y
/// adjuntarlo a `err.error` para que `dioToDomainError` lo retorne directo.
DioException buildDioException({
  required String path,
  int statusCode = 422,
  Map<String, dynamic>? body,
  DioExceptionType type = DioExceptionType.badResponse,
}) {
  final options = RequestOptions(path: path);
  final response = Response<Map<String, dynamic>>(
    requestOptions: options,
    data: body,
    statusCode: statusCode,
  );
  final domainError = body != null
      ? DomainError.fromJson(body, statusCode: statusCode)
      : DomainError(
          message: 'Error.',
          code: null,
          fieldErrors: const <String, List<String>>{},
          statusCode: statusCode,
        );
  return DioException(
    requestOptions: options,
    response: response,
    error: domainError,
    type: type,
  );
}

void registerDioFallbacks() {
  registerFallbackValue(RequestOptions(path: '/'));
  registerFallbackValue(<String, dynamic>{});
}

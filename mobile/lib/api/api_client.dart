import 'package:dio/dio.dart';
import 'package:fincore/models/domain_error.dart';
import 'package:fincore/storage/token_storage.dart';

/// Callback que se dispara cuando el interceptor detecta sesión inválida (401).
typedef OnUnauthorized = Future<void> Function();

/// Callback que se dispara cuando el backend reporta cuenta no verificada (403 con
/// texto del middleware `verified` de Laravel).
typedef OnUnverified = Future<void> Function();

class ApiClient {
  final Dio dio;
  final TokenStorage tokenStorage;
  final OnUnauthorized? onUnauthorized;
  final OnUnverified? onUnverified;

  ApiClient({
    required String baseUrl,
    required this.tokenStorage,
    this.onUnauthorized,
    this.onUnverified,
    Dio? dio,
  }) : dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 15),
                headers: <String, String>{
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                },
                // No lanzamos en 4xx; el interceptor decide.
                validateStatus: (status) => status != null && status < 500,
              ),
            ) {
    this.dio.interceptors.add(_AuthInterceptor(tokenStorage));
    this.dio.interceptors.add(_ErrorInterceptor(onUnauthorized, onUnverified));
  }
}

class _AuthInterceptor extends Interceptor {
  final TokenStorage tokenStorage;
  _AuthInterceptor(this.tokenStorage);

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await tokenStorage.read();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}

class _ErrorInterceptor extends Interceptor {
  final OnUnauthorized? onUnauthorized;
  final OnUnverified? onUnverified;

  _ErrorInterceptor(this.onUnauthorized, this.onUnverified);

  @override
  Future<void> onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) async {
    final status = response.statusCode ?? 0;

    // 2xx pasa derecho.
    if (status >= 200 && status < 300) {
      handler.next(response);
      return;
    }

    // 401: sesión inválida → callback (típicamente limpia token + nav a Login).
    if (status == 401) {
      if (onUnauthorized != null) {
        await onUnauthorized!();
      }
      handler.reject(_buildDioException(response, 'Sesión expirada.'));
      return;
    }

    // 403: distinguir cuenta no verificada vs permiso negado.
    if (status == 403) {
      final body = response.data;
      final msg = body is Map<String, dynamic> ? body['message'] as String? : null;
      final isVerify = msg != null && msg.toLowerCase().contains('email');
      if (isVerify && onUnverified != null) {
        await onUnverified!();
      }
      handler.reject(_buildDioException(response, msg ?? 'Acceso denegado.'));
      return;
    }

    // 422 / 409: errores de dominio o validación.
    if (status == 422 || status == 409) {
      handler.reject(_buildDioException(response, 'Solicitud inválida.'));
      return;
    }

    // 429: throttle.
    if (status == 429) {
      handler.reject(_buildDioException(response, 'Demasiados intentos. Esperá 1 minuto.'));
      return;
    }

    // 4xx genérico.
    handler.reject(_buildDioException(response, 'Error de solicitud.'));
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Errores que no son response (network, timeout) — los normalizamos como DomainError(network).
    handler.next(err);
  }

  DioException _buildDioException(Response<dynamic> response, String fallback) {
    final body = response.data;
    DomainError domain;
    if (body is Map<String, dynamic>) {
      domain = DomainError.fromJson(body, statusCode: response.statusCode ?? 0);
    } else {
      domain = DomainError(
        message: fallback,
        code: null,
        fieldErrors: const <String, List<String>>{},
        statusCode: response.statusCode ?? 0,
      );
    }
    return DioException(
      requestOptions: response.requestOptions,
      response: response,
      error: domain,
      type: DioExceptionType.badResponse,
    );
  }
}

/// Convierte un `DioException` a `DomainError` para mostrar en UI.
DomainError dioToDomainError(DioException err) {
  if (err.error is DomainError) return err.error as DomainError;
  switch (err.type) {
    case DioExceptionType.connectionError:
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.sendTimeout:
      return DomainError.network('No se pudo conectar al servidor. Verificá tu conexión.');
    case DioExceptionType.cancel:
      return DomainError.network('Solicitud cancelada.');
    case DioExceptionType.badCertificate:
      return DomainError.network('El certificado del servidor no es válido.');
    case DioExceptionType.badResponse:
    case DioExceptionType.unknown:
      return DomainError.network(err.message ?? 'Error desconocido.');
  }
}

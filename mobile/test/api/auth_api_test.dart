import 'package:dio/dio.dart';
import 'package:fincore/api/auth_api.dart';
import 'package:fincore/models/domain_error.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/mock_dio.dart';

void main() {
  late MockApiClient client;
  late MockDio dio;
  late AuthApi auth;

  setUpAll(registerDioFallbacks);

  setUp(() {
    client = MockApiClient();
    dio = MockDio();
    when(() => client.dio).thenReturn(dio);
    auth = AuthApi(client);
  });

  group('AuthApi.login', () {
    test('200 retorna LoginResponse con user y token', () async {
      when(() => dio.post<Map<String, dynamic>>(
            '/auth/login',
            data: any(named: 'data'),
          )).thenAnswer((_) async => buildResponse('/auth/login', {
            'user': {
              'id': 'u1',
              'name': 'Diego',
              'email': 'a@b.com',
              'email_verified_at': '2026-01-01T00:00:00Z',
            },
            'token': 'abc.def.ghi',
          }));

      final r = await auth.login(email: 'a@b.com', password: 'secret');

      expect(r.token, 'abc.def.ghi');
      expect(r.user.name, 'Diego');
      expect(r.user.isVerified, isTrue);
    });

    test('422 con DomainException viaja como DomainError', () async {
      when(() => dio.post<Map<String, dynamic>>(
            '/auth/login',
            data: any(named: 'data'),
          )).thenThrow(buildDioException(
        path: '/auth/login',
        statusCode: 422,
        body: {'error': 'Credenciales inválidas.', 'code': 'invalid_credentials'},
      ));

      expect(
        () => auth.login(email: 'a@b.com', password: 'x'),
        throwsA(isA<DomainError>().having((e) => e.code, 'code', 'invalid_credentials')),
      );
    });

    test('429 throttle se convierte en DomainError con statusCode 429', () async {
      when(() => dio.post<Map<String, dynamic>>(
            '/auth/login',
            data: any(named: 'data'),
          )).thenThrow(buildDioException(
        path: '/auth/login',
        statusCode: 429,
        body: {'message': 'Too Many Attempts.'},
      ));

      expect(
        () => auth.login(email: 'a@b.com', password: 'x'),
        throwsA(isA<DomainError>().having((e) => e.statusCode, 'statusCode', 429)),
      );
    });

    test('network error se convierte en DomainError(network)', () async {
      when(() => dio.post<Map<String, dynamic>>(
            '/auth/login',
            data: any(named: 'data'),
          )).thenThrow(DioException(
        requestOptions: RequestOptions(path: '/auth/login'),
        type: DioExceptionType.connectionError,
      ));

      expect(
        () => auth.login(email: 'a@b.com', password: 'x'),
        throwsA(isA<DomainError>().having((e) => e.code, 'code', 'network_error')),
      );
    });
  });

  group('AuthApi.me', () {
    test('200 retorna User', () async {
      when(() => dio.get<Map<String, dynamic>>('/auth/me')).thenAnswer(
        (_) async => buildResponse('/auth/me', {
          'id': 'u1',
          'name': 'Diego',
          'email': 'a@b.com',
          'email_verified_at': null,
        }),
      );

      final u = await auth.me();
      expect(u.isVerified, isFalse);
      expect(u.email, 'a@b.com');
    });

    test('401 viaja como DomainError', () async {
      when(() => dio.get<Map<String, dynamic>>('/auth/me')).thenThrow(
        buildDioException(
          path: '/auth/me',
          statusCode: 401,
          body: {'message': 'Unauthenticated.'},
        ),
      );

      expect(() => auth.me(), throwsA(isA<DomainError>()));
    });
  });

  group('AuthApi.logout', () {
    test('OK pasa silenciosamente', () async {
      when(() => dio.post<dynamic>('/auth/logout')).thenAnswer(
        (_) async => buildResponse<dynamic>('/auth/logout', null, statusCode: 204),
      );
      await auth.logout(); // no throw
    });

    test('Network error es silenciado a propósito', () async {
      when(() => dio.post<dynamic>('/auth/logout')).thenThrow(
        DioException(requestOptions: RequestOptions(path: '/auth/logout'),
            type: DioExceptionType.connectionError),
      );
      await auth.logout(); // sin throw — logout local es lo importante
    });
  });

  group('AuthApi.resendVerification', () {
    test('204 pasa OK', () async {
      when(() => dio.post<dynamic>('/auth/email/verification-notification'))
          .thenAnswer((_) async =>
              buildResponse<dynamic>('/auth/email/verification-notification', null, statusCode: 204));
      await auth.resendVerification();
    });

    test('429 throttle es DomainError', () async {
      when(() => dio.post<dynamic>('/auth/email/verification-notification'))
          .thenThrow(buildDioException(
        path: '/auth/email/verification-notification',
        statusCode: 429,
        body: {'message': 'Too Many Attempts.'},
      ));

      expect(() => auth.resendVerification(),
          throwsA(isA<DomainError>().having((e) => e.statusCode, 'statusCode', 429)));
    });
  });
}

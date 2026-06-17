import 'package:dio/dio.dart';
import 'package:fincore/api/api_client.dart';
import 'package:fincore/models/user.dart';

class LoginResponse {
  final User user;
  final String token;
  const LoginResponse({required this.user, required this.token});
}

class AuthApi {
  final ApiClient client;
  AuthApi(this.client);

  /// POST /api/auth/login → {user, token}
  Future<LoginResponse> login({required String email, required String password}) async {
    try {
      final response = await client.dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: <String, String>{'email': email, 'password': password},
      );
      final data = response.data!;
      return LoginResponse(
        user: User.fromJson(data['user'] as Map<String, dynamic>),
        token: data['token'] as String,
      );
    } on DioException catch (e) {
      throw dioToDomainError(e);
    }
  }

  /// POST /api/auth/logout. Tolera fallo de red (el caller debería limpiar local igual).
  Future<void> logout() async {
    try {
      await client.dio.post<dynamic>('/auth/logout');
    } on DioException {
      // Silenciado a propósito: el caller hace clear local incondicionalmente.
    }
  }

  /// GET /api/auth/me → User.
  Future<User> me() async {
    try {
      final response = await client.dio.get<Map<String, dynamic>>('/auth/me');
      return User.fromJson(response.data!);
    } on DioException catch (e) {
      throw dioToDomainError(e);
    }
  }

  /// POST /api/auth/email/verification-notification. Throttle 6,1 del backend.
  Future<void> resendVerification() async {
    try {
      await client.dio.post<dynamic>('/auth/email/verification-notification');
    } on DioException catch (e) {
      throw dioToDomainError(e);
    }
  }
}

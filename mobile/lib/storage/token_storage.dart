import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wrapper sobre `flutter_secure_storage` para el bearer token Sanctum.
///
/// En Android usa Android Keystore. En Linux desktop, `useSessionKeyring: false`
/// evita dependencia de un keyring del SO (puede no estar disponible en dev).
class TokenStorage {
  static const _key = 'fincore.auth.token';

  final FlutterSecureStorage _storage;

  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              lOptions: LinuxOptions(),
            );

  Future<String?> read() => _storage.read(key: _key);

  Future<void> write(String token) => _storage.write(key: _key, value: token);

  Future<void> clear() => _storage.delete(key: _key);
}

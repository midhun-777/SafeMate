import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure Storage Service for SafeMate.
/// Universal Engineering Rule #6: Never store secrets in plain text or SharedPreferences.
/// Uses Android Keystore-backed EncryptedSharedPreferences and iOS Keychain Services.
class SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  static const String _keyAuthToken = 'safemate_auth_token';
  static const String _keyRefreshToken = 'safemate_refresh_token';
  static const String _keyUserId = 'safemate_user_id';

  Future<void> saveSessionTokens({
    required String accessToken,
    required String refreshToken,
    required String userId,
  }) async {
    await Future.wait([
      _storage.write(key: _keyAuthToken, value: accessToken),
      _storage.write(key: _keyRefreshToken, value: refreshToken),
      _storage.write(key: _keyUserId, value: userId),
    ]);
  }

  Future<String?> getAccessToken() => _storage.read(key: _keyAuthToken);
  Future<String?> getRefreshToken() => _storage.read(key: _keyRefreshToken);
  Future<String?> getUserId() => _storage.read(key: _keyUserId);

  Future<void> clearSession() async {
    await Future.wait([
      _storage.delete(key: _keyAuthToken),
      _storage.delete(key: _keyRefreshToken),
      _storage.delete(key: _keyUserId),
    ]);
  }

  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  Future<String?> read(String key) => _storage.read(key: key);

  Future<void> delete(String key) => _storage.delete(key: key);
}

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Token d'accès : flutter_secure_storage, jamais dans Drift.
abstract class TokenStore {
  Future<String?> read(String key);
  Future<void> write(String key, String? value);
}

abstract final class SecureKey {
  static const token = 'token';
  static const pinHash = 'pin_hash';
  static const pinSalt = 'pin_salt';
}

class SecureTokenStore implements TokenStore {
  const SecureTokenStore([this._storage = const FlutterSecureStorage()]);
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String? value) => value == null
      ? _storage.delete(key: key)
      : _storage.write(key: key, value: value);
}

class MemoryTokenStore implements TokenStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String? value) async =>
      value == null ? values.remove(key) : values[key] = value;
}

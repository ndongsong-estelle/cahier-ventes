import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'token_store.dart';

/// "Demander le code à chaque ouverture" : hash sha256 salé dans le stockage sécurisé, vérifié hors ligne.
class PinLock {
  PinLock(this.store);
  final TokenStore store;

  static String hash(String salt, String pin) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  Future<void> save(String pin) async {
    final rnd = Random.secure();
    final salt = base64Url.encode(
      List<int>.generate(16, (_) => rnd.nextInt(256)),
    );
    await store.write(SecureKey.pinSalt, salt);
    await store.write(SecureKey.pinHash, hash(salt, pin));
  }

  Future<void> clear() async {
    await store.write(SecureKey.pinHash, null);
    await store.write(SecureKey.pinSalt, null);
  }

  Future<bool> get isSet async => await store.read(SecureKey.pinHash) != null;

  Future<bool> check(String pin) async {
    final salt = await store.read(SecureKey.pinSalt);
    final expected = await store.read(SecureKey.pinHash);
    if (salt == null || expected == null) return true;
    return hash(salt, pin) == expected;
  }
}

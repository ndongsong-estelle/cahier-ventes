import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../db/settings_store.dart';
import '../providers.dart';
import 'auth_api.dart';
import 'token_store.dart';

enum SessionStatus { loading, loggedOut, loggedIn }

class SessionState {
  const SessionState(
    this.status, {
    this.shopName,
    this.phone,
    this.mustChangePin = false,
    this.notice,
  });

  final SessionStatus status;
  final String? shopName;
  final String? phone;
  final bool mustChangePin;

  /// Message à afficher sur C1 (ex. compte ouvert ailleurs).
  final String? notice;

  bool get isLoggedIn => status == SessionStatus.loggedIn;
}

const otherPhoneNotice = 'Votre compte est ouvert sur un autre téléphone.';

/// Hook appelé après une connexion réussie (restauration de la copie, T-07).
typedef AfterLogin = Future<void> Function(
  Ref ref, {
  required bool sameAccount,
});

/// Après connexion : copie du serveur restaurée, ou cahier local envoyé s'il est plus récent.
final afterLoginProvider = Provider<AfterLogin?>(
  (ref) =>
      (ref, {required sameAccount}) =>
          ref.read(backupServiceProvider).afterLogin(sameAccount: sameAccount),
);

const restoringMessage = 'Récupération de votre cahier…';

class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() {
    Future.microtask(_restore);
    return const SessionState(SessionStatus.loading);
  }

  SettingsStore get _settings => ref.read(settingsStoreProvider);
  TokenStore get _tokens => ref.read(tokenStoreProvider);

  Future<void> _restore() async {
    await deviceId();
    final token = await _tokens.read(SecureKey.token);
    final userId = await _settings.get(SettingKey.userId);
    if (token != null && userId != null) {
      state = SessionState(
        SessionStatus.loggedIn,
        shopName: await _settings.get(SettingKey.shopName),
        phone: await _settings.get(SettingKey.phone),
      );
    } else {
      state = const SessionState(SessionStatus.loggedOut);
    }
  }

  /// device_id (UUID) créé au premier lancement.
  Future<String> deviceId() async {
    var id = await _settings.get(SettingKey.deviceId);
    if (id == null) {
      id = const Uuid().v4();
      await _settings.set(SettingKey.deviceId, id);
      await _settings.set(
        SettingKey.installedAt,
        DateTime.now().toUtc().toIso8601String(),
      );
    }
    return id;
  }

  Future<Map<String, dynamic>> deviceInfo() async => {
    'id': await deviceId(),
    'app_version': AppConfig.appVersion,
    'android_version': _androidVersion(),
    'model': null,
  };

  String? _androidVersion() {
    try {
      return Platform.operatingSystemVersion;
    } catch (_) {
      return null;
    }
  }

  /// Enregistre la session. Si le cahier local est celui d'un autre compte, il est effacé d'abord.
  Future<void> signedIn(AuthResult result) async {
    final previous = await _settings.get(SettingKey.userId);
    final sameAccount = previous == null || previous == result.user.id;
    if (!sameAccount) {
      final device = await deviceId();
      final installed = await _settings.get(SettingKey.installedAt);
      await ref.read(databaseProvider).wipe();
      await _settings.set(SettingKey.deviceId, device);
      await _settings.set(SettingKey.installedAt, installed);
      await _tokens.write(SecureKey.pinHash, null);
      await _tokens.write(SecureKey.pinSalt, null);
    }
    await _tokens.write(SecureKey.token, result.token);
    await _settings.set(SettingKey.userId, result.user.id);
    await _settings.set(SettingKey.phone, result.user.phone);
    await _settings.set(SettingKey.shopName, result.user.shopName);

    final hook = ref.read(afterLoginProvider);
    if (hook != null) {
      state = const SessionState(
        SessionStatus.loading,
        notice: restoringMessage,
      );
      try {
        await hook(ref, sameAccount: previous == result.user.id);
      } catch (_) {
        // Sans réseau ou copie abîmée : on continue, la copie sera retentée plus tard.
      }
    }

    state = SessionState(
      SessionStatus.loggedIn,
      shopName: result.user.shopName,
      phone: result.user.phone,
      mustChangePin: result.mustChangePin,
    );
  }

  void pinChanged() {
    state = SessionState(
      SessionStatus.loggedIn,
      shopName: state.shopName,
      phone: state.phone,
    );
  }

  Future<void> shopNameChanged(String name) async {
    await _settings.set(SettingKey.shopName, name);
    state = SessionState(
      state.status,
      shopName: name,
      phone: state.phone,
      mustChangePin: state.mustChangePin,
    );
  }

  /// 401 : on efface le token, on garde le cahier, on revient à C1.
  Future<void> expired() async {
    if (state.status == SessionStatus.loggedOut) return;
    await _tokens.write(SecureKey.token, null);
    state = const SessionState(
      SessionStatus.loggedOut,
      notice: otherPhoneNotice,
    );
  }

  /// Se déconnecter : le cahier reste sur le téléphone jusqu'à la prochaine connexion.
  Future<void> loggedOut() async {
    await _tokens.write(SecureKey.token, null);
    state = const SessionState(SessionStatus.loggedOut);
  }

  /// Compte supprimé : tout est effacé du téléphone.
  Future<void> deleted() async {
    await _tokens.write(SecureKey.token, null);
    await _tokens.write(SecureKey.pinHash, null);
    await _tokens.write(SecureKey.pinSalt, null);
    final device = await deviceId();
    await ref.read(databaseProvider).wipe();
    await _settings.set(SettingKey.deviceId, device);
    state = const SessionState(SessionStatus.loggedOut);
  }
}

final sessionProvider = NotifierProvider<SessionController, SessionState>(
  SessionController.new,
);

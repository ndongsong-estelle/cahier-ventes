import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/api_client.dart';
import 'auth/auth_api.dart';
import 'auth/session.dart';
import 'auth/token_store.dart';
import 'config/app_config.dart';
import 'db/database.dart';
import 'db/ledger_repository.dart';
import 'db/settings_store.dart';

/// Remplacé dans les tests (NativeDatabase.memory()).
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final tokenStoreProvider = Provider<TokenStore>(
  (ref) => const SecureTokenStore(),
);

final settingsStoreProvider = Provider<SettingsStore>(
  (ref) => SettingsStore(ref.watch(databaseProvider)),
);

final ledgerProvider = Provider<LedgerRepository>(
  (ref) => LedgerRepository(ref.watch(databaseProvider)),
);

/// Remplacé dans les tests par un faux adaptateur HTTP.
final httpAdapterProvider = Provider<HttpClientAdapter?>((ref) => null);

final apiClientProvider = Provider<ApiClient>((ref) {
  final tokens = ref.watch(tokenStoreProvider);
  final settings = ref.watch(settingsStoreProvider);
  return ApiClient(
    baseUrl: AppConfig.apiUrl,
    token: () => tokens.read(SecureKey.token),
    onServerTime: (server) {
      final offset = server.difference(DateTime.now()).inSeconds;
      settings.set(SettingKey.clockOffsetSeconds, '$offset');
    },
    onUnauthorized: () => ref.read(sessionProvider.notifier).expired(),
    adapter: ref.watch(httpAdapterProvider),
  );
});

final authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(ref.watch(apiClientProvider)),
);

/// Petite valeur modifiable (remplace StateProvider).
class ValueController<T> extends Notifier<T> {
  ValueController(this._initial);
  final T _initial;

  @override
  T build() => _initial;

  void set(T value) => state = value;
}

/// Numéro WhatsApp de l'aide, renvoyé par GET /config.
final supportWhatsappProvider =
    NotifierProvider<ValueController<String?>, String?>(
      () => ValueController<String?>(null),
    );

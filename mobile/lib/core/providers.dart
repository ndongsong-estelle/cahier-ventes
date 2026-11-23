import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/api_client.dart';
import 'auth/auth_api.dart';
import 'auth/pin_lock.dart';
import 'auth/session.dart';
import 'auth/token_store.dart';
import 'backup/backup_api.dart';
import 'backup/backup_service.dart';
import 'backup/manual_backup.dart';
import 'config/app_config.dart';
import 'db/database.dart';
import 'db/ledger_repository.dart';
import 'db/settings_store.dart';
import 'photos/photo_service.dart';
import 'sync/sync_runner.dart';
import 'telemetry/telemetry.dart';
import 'notifications/weekly_notification.dart';
import 'ui/contact.dart';
import 'ui/share.dart';

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

/// Signale toute écriture dans le cahier : les écrans se recalculent.
final ledgerChangesProvider = StreamProvider<int>((ref) async* {
  var n = 0;
  yield n;
  await for (final _ in ref.watch(databaseProvider).tableUpdates()) {
    yield ++n;
  }
});

/// Remplacé dans les tests par un faux sélecteur de photos.
final photoServiceProvider = Provider<PhotoService>(
  (ref) => DevicePhotoService(),
);

final backupApiProvider = Provider<BackupApi>(
  (ref) => HttpBackupApi(ref.watch(apiClientProvider)),
);

final backupServiceProvider = Provider<BackupService>(
  (ref) =>
      BackupService(ref.watch(databaseProvider), ref.watch(backupApiProvider)),
);

/// Étapes lancées à l'ouverture puis toutes les heures (T-13 y ajoute l'envoi des statistiques).
final syncStepsProvider = Provider<List<SyncStep>>((ref) {
  final api = ref.watch(apiClientProvider);
  final settings = ref.watch(settingsStoreProvider);
  final backup = ref.watch(backupServiceProvider);
  final telemetry = ref.watch(telemetryProvider);
  return [
    ({required onOpen}) async {
      final c = await fetchConfig(api, settings);
      final support = c['support_whatsapp'];
      if (support is String) {
        ref.read(supportWhatsappProvider.notifier).set(support);
      }
    },
    ({required onOpen}) => telemetry.flush(api),
    ({required onOpen}) => backup.maybeSend(onOpen: onOpen),
  ];
});

final syncRunnerProvider = Provider<SyncRunner>((ref) {
  final runner = SyncRunner(ref.watch(syncStepsProvider));
  ref.onDispose(runner.stop);
  return runner;
});

/// Ouvre WhatsApp, le téléphone, une page web. Remplacé dans les tests.
final urlOpenerProvider = Provider<UrlOpener>((ref) => openExternal);

final sharerProvider = Provider<Sharer>((ref) => const SystemSharer());

final weeklyNotificationProvider = Provider<WeeklyNotification>(
  (ref) => LocalWeeklyNotification(),
);

/// Programme (ou retire) la notification du dimanche selon le réglage weekly_summary.
Future<void> applyWeeklySetting(
  SettingsStore settings,
  WeeklyNotification n,
) async {
  final on = await settings.getBool(SettingKey.weeklySummary, fallback: true);
  try {
    on ? await n.schedule() : await n.cancel();
  } catch (_) {
    // Notifications indisponibles : l'app continue.
  }
}

final pinLockProvider = Provider<PinLock>(
  (ref) => PinLock(ref.watch(tokenStoreProvider)),
);

final filePickerProvider = Provider<CahierFilePicker>(
  (ref) => const SystemFilePicker(),
);

final manualBackupProvider = Provider<ManualBackup>(
  (ref) => ManualBackup(
    ref.watch(databaseProvider),
    photosDir: DevicePhotoService.folder,
    tempDir: defaultTempDir,
  ),
);

/// Verrou à l'ouverture (true = écran du code secret affiché).
final appLockedProvider = NotifierProvider<ValueController<bool>, bool>(
  () => ValueController<bool>(false),
);

final telemetryProvider = Provider<Telemetry>(
  (ref) => Telemetry(ref.watch(databaseProvider)),
);

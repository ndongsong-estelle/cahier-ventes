import '../api/api_client.dart';
import '../db/database.dart';
import '../db/settings_store.dart';
import 'backup_api.dart';
import 'cahier_file.dart';

abstract final class BackupKey {
  static const enabled = 'backup_enabled';
  static const minIntervalMinutes = 'backup_min_interval_minutes';
}

enum BackupOutcome { sent, unchanged, tooSoon, disabled, failed }

/// Copie automatique du cahier (docs/02).
class BackupService {
  BackupService(this.db, this.api, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase db;
  final BackupApi api;
  final DateTime Function() _clock;

  SettingsStore get _settings => SettingsStore(db);

  /// Envoi si activé ET contenu changé ET assez de temps depuis la dernière copie.
  /// [onOpen] : à l'ouverture, une copie de plus de 24 h est toujours renvoyée si le contenu a changé.
  /// [force] : sans attendre l'intervalle (reconnexion avec un cahier plus récent).
  Future<BackupOutcome> maybeSend({
    bool onOpen = false,
    bool force = false,
  }) async {
    if (!await _settings.getBool(BackupKey.enabled, fallback: true)) {
      return BackupOutcome.disabled;
    }
    final file = await CahierFile.export(db);
    if (file.sha256Hex == await _settings.get(SettingKey.lastBackupHash)) {
      return BackupOutcome.unchanged;
    }

    final last = DateTime.tryParse(
      await _settings.get(SettingKey.lastBackupAt) ?? '',
    );
    if (!force && last != null) {
      var wait = await _settings.getInt(BackupKey.minIntervalMinutes) ?? 360;
      if (onOpen && wait > 24 * 60) wait = 24 * 60;
      if (_clock().difference(last).inMinutes < wait) {
        return BackupOutcome.tooSoon;
      }
    }
    try {
      await api.upload(file.gz, file.sha256Hex, file.counts);
    } on ApiException catch (e) {
      if (e.status == 403) {
        await _settings.setBool(BackupKey.enabled, false);
        return BackupOutcome.disabled;
      }
      return BackupOutcome.failed;
    }
    await _settings.set(
      SettingKey.lastBackupAt,
      _clock().toUtc().toIso8601String(),
    );
    await _settings.set(SettingKey.lastBackupHash, file.sha256Hex);
    return BackupOutcome.sent;
  }

  /// Restauration : dernière copie, vérification sha256, remplacement. False si aucune copie.
  Future<bool> restoreLatest([BackupMeta? known]) async {
    final meta = known ?? await api.latest();
    if (meta == null) return false;
    final file = CahierFile.decode(
      await api.download(meta.id),
      expectedSha256: meta.sha256,
    );
    if (file == null) throw const FormatException('Copie abîmée');
    await file.importInto(db);
    await _settings.set(SettingKey.lastBackupHash, file.sha256Hex);
    await _settings.set(
      SettingKey.lastBackupAt,
      meta.createdAt.toUtc().toIso8601String(),
    );
    return true;
  }

  /// Après connexion. Même personne avec un cahier plus récent que la copie : on l'envoie ;
  /// sinon on restaure la copie du serveur.
  Future<void> afterLogin({required bool sameAccount}) async {
    final meta = await api.latest();
    final localChange = await lastLocalChange();
    if (meta == null) {
      if (localChange != null) await maybeSend(force: true);
      return;
    }
    if (sameAccount &&
        localChange != null &&
        localChange.isAfter(meta.createdAt)) {
      await maybeSend(force: true);
      return;
    }
    await restoreLatest(meta);
  }

  /// Dernière modification du cahier sur ce téléphone (null si vide).
  Future<DateTime?> lastLocalChange() async {
    final row = await db
        .customSelect(
          'SELECT MAX(m) AS m FROM ('
          'SELECT MAX(updated_at) AS m FROM sales UNION ALL '
          'SELECT MAX(updated_at) FROM payments UNION ALL '
          'SELECT MAX(updated_at) FROM articles UNION ALL '
          'SELECT MAX(updated_at) FROM people)',
          readsFrom: {db.sales, db.payments, db.articles, db.people},
        )
        .getSingle();
    final v = row.data['m'];
    return v is int ? DateTime.fromMillisecondsSinceEpoch(v * 1000) : null;
  }
}

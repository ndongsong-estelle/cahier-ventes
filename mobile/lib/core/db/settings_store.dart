import 'package:drift/drift.dart' show Value;

import 'database.dart';

/// Clés du tableau settings (docs/02).
abstract final class SettingKey {
  static const userId = 'user_id';
  static const phone = 'phone';
  static const shopName = 'shop_name';
  static const shopPhone = 'shop_phone';
  static const weeklySummary = 'weekly_summary';
  static const pinOnOpen = 'pin_on_open';
  static const deviceId = 'device_id';
  static const lastBackupAt = 'last_backup_at';
  static const lastBackupHash = 'last_backup_hash';
  static const clockOffsetSeconds = 'clock_offset_seconds';
  static const installedAt = 'installed_at';
}

class SettingsStore {
  SettingsStore(this.db);
  final AppDatabase db;

  Future<String?> get(String key) async {
    final row = await (db.select(
      db.settings,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> set(String key, String? value) => db
      .into(db.settings)
      .insertOnConflictUpdate(
        SettingsCompanion.insert(key: key, value: Value(value)),
      );

  Future<bool> getBool(String key, {bool fallback = false}) async {
    final v = await get(key);
    return v == null ? fallback : v == '1';
  }

  Future<void> setBool(String key, bool value) => set(key, value ? '1' : '0');

  Future<int?> getInt(String key) async => int.tryParse(await get(key) ?? '');
}

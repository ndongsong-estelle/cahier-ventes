import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/token_store.dart';
import '../../core/backup/backup_service.dart';
import '../../core/db/settings_store.dart';
import '../../core/format/dates.dart';
import '../../core/providers.dart';

class SettingsView {
  const SettingsView({
    required this.phone,
    required this.shopPhone,
    required this.pinOnOpen,
    required this.weekly,
    required this.backupLine,
    required this.support,
    required this.lastBackupAt,
    required this.outboxCount,
  });

  final String? phone;
  final String? shopPhone;
  final bool pinOnOpen;
  final bool weekly;
  final String backupLine;
  final String? support;
  final DateTime? lastBackupAt;
  final int outboxCount;
}

/// "aujourd'hui à 14 h", "hier à 9 h 05", "le 12 novembre à 14 h".
String whenText(DateTime at, DateTime now) {
  final l = at.toLocal();
  final h = l.minute == 0
      ? '${l.hour} h'
      : '${l.hour} h ${l.minute.toString().padLeft(2, '0')}';
  if (sameDay(l, now)) return "aujourd'hui à $h";
  if (sameDay(l, now.subtract(const Duration(days: 1)))) return 'hier à $h';
  final d = formatDay(l).split(' ');
  return 'le ${d[1]} ${d[2]} à $h';
}

String backupLine({
  DateTime? lastAt,
  required bool waiting,
  required DateTime now,
}) {
  if (waiting) return 'En attente de réseau';
  if (lastAt == null) return 'Pas encore de copie';
  return 'Dernière copie de votre cahier : ${whenText(lastAt, now)}';
}

final settingsViewProvider = FutureProvider.autoDispose<SettingsView>((
  ref,
) async {
  ref.watch(ledgerChangesProvider);
  final s = ref.read(settingsStoreProvider);
  final db = ref.read(databaseProvider);
  final last = DateTime.tryParse(await s.get(SettingKey.lastBackupAt) ?? '');
  final outbox = await db.select(db.outbox).get();
  return SettingsView(
    phone: await s.get(SettingKey.phone),
    shopPhone: await s.get(SettingKey.shopPhone),
    pinOnOpen:
        await s.getBool(SettingKey.pinOnOpen) &&
        await ref.read(tokenStoreProvider).read(SecureKey.pinHash) != null,
    weekly: await s.getBool(SettingKey.weeklySummary, fallback: true),
    backupLine: backupLine(
      lastAt: last,
      waiting: await s.getBool(BackupKey.waiting),
      now: DateTime.now(),
    ),
    support:
        ref.read(supportWhatsappProvider) ?? await s.get('support_whatsapp'),
    lastBackupAt: last,
    outboxCount: outbox.length,
  );
});

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../api/api_client.dart';
import '../config/app_config.dart';
import '../db/database.dart';
import 'whitelist.dart';

/// Statistiques d'usage : outbox locale puis lots de 200 ; supprimés seulement après une réponse 2xx.
class Telemetry {
  Telemetry(this.db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase db;
  final DateTime Function() _clock;
  static const batchSize = 200;

  /// Événement de la liste blanche. Hors liste : refusé (erreur en mode debug, ignoré sinon).
  Future<void> track(
    String name, [
    Map<String, Object?> props = const {},
  ]) async {
    if (!isAllowed(name, props)) {
      assert(false, 'Événement hors liste blanche : $name $props');
      return;
    }
    await _put('event', {'name': name, 'props': props});
  }

  Future<void> answer(String questionId, {String? value, String? text}) =>
      _put('answer', {'question_id': questionId, 'value': value, 'text': text});

  Future<void> error(Object error, StackTrace? stack) {
    final s = stack?.toString() ?? '';
    return _put('error', {
      'message': '$error'.length > 1000
          ? '$error'.substring(0, 1000)
          : '$error',
      'stack': s.length > 4096 ? s.substring(0, 4096) : s,
      'app_version': AppConfig.appVersion,
    });
  }

  Future<void> _put(String kind, Map<String, Object?> data) async {
    final id = const Uuid().v4();
    final t = _clock();
    await db
        .into(db.outbox)
        .insert(
          OutboxCompanion.insert(
            id: id,
            kind: kind,
            payload: jsonEncode({
              'id': id,
              ...data,
              'occurred_at': t.toUtc().toIso8601String(),
            }),
            createdAt: t,
          ),
        );
  }

  /// Envoie tout ce qui attend. Sans réseau : rien n'est perdu, on réessaiera.
  Future<void> flush(ApiClient api) async {
    for (final (kind, path) in const [
      ('event', '/events'),
      ('answer', '/answers'),
      ('error', '/errors'),
    ]) {
      while (true) {
        final rows =
            await (db.select(db.outbox)
                  ..where((o) => o.kind.equals(kind))
                  ..orderBy([(o) => OrderingTerm.asc(o.createdAt)])
                  ..limit(batchSize))
                .get();
        if (rows.isEmpty) break;
        await api.post(path, {
          'sent_at': _clock().toUtc().toIso8601String(),
          'items': [for (final r in rows) jsonDecode(r.payload)],
        });
        await (db.delete(
          db.outbox,
        )..where((o) => o.id.isIn(rows.map((r) => r.id)))).go();
        if (rows.length < batchSize) break;
      }
    }
  }
}

/// Raccourci pour les écrans : n'attend pas et ne lève jamais.
void trackWith(
  Telemetry t,
  String name, [
  Map<String, Object?> props = const {},
]) {
  t.track(name, props).catchError((_) {});
}

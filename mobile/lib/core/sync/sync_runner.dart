import 'dart:convert';
import 'dart:async';

import '../api/api_client.dart';
import '../backup/backup_service.dart';
import '../db/settings_store.dart';

typedef SyncStep = Future<void> Function({required bool onOpen});

/// Envois réseau : à l'ouverture puis au plus une fois par heure, une seule opération à la fois.
/// Sans réseau, rien ne bloque : on réessaiera plus tard.
class SyncRunner {
  SyncRunner(this.steps, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final List<SyncStep> steps;
  final DateTime Function() _clock;
  Future<void>? _running;
  DateTime? _lastRun;
  Timer? _timer;

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(hours: 1), (_) => run());
    run(onOpen: true);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Retour dans l'app : relance si la dernière tentative a plus d'une heure.
  void resumed() {
    final last = _lastRun;
    if (_timer != null &&
        (last == null || _clock().difference(last).inMinutes >= 60)) {
      run(onOpen: true);
    }
  }

  Future<void> run({bool onOpen = false}) {
    return _running ??= _runAll(onOpen).whenComplete(() => _running = null);
  }

  Future<void> _runAll(bool onOpen) async {
    _lastRun = _clock();
    for (final step in steps) {
      try {
        await step(onOpen: onOpen);
      } on ApiException {
        // Pas de réseau ou serveur indisponible : on continue sans bloquer.
      } catch (_) {
        // Une erreur d'un envoi ne doit jamais gêner l'utilisatrice.
      }
    }
  }
}

/// GET /config : réglages de la copie et numéro de l'aide.
Future<Map<String, dynamic>> fetchConfig(
  ApiClient api,
  SettingsStore settings,
) async {
  final c = await api.get('/config');
  await settings.setBool(BackupKey.enabled, c['backup_enabled'] != false);
  final interval = c['backup_min_interval_minutes'];
  if (interval is int) {
    await settings.set(BackupKey.minIntervalMinutes, '$interval');
  }
  final support = c['support_whatsapp'];
  if (support is String) await settings.set('support_whatsapp', support);
  final questions = c['questions'];
  if (questions is List) {
    await settings.set('questions_json', jsonEncode(questions));
  }
  return c;
}

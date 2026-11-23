import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/db/settings_store.dart';
import '../../core/providers.dart';
import '../../core/telemetry/telemetry.dart';
import '../../core/theme/app_theme.dart';

class ShortQuestion {
  const ShortQuestion({
    required this.id,
    required this.text,
    required this.kind,
    required this.choices,
    required this.afterDays,
  });

  factory ShortQuestion.fromJson(Map<String, dynamic> j) => ShortQuestion(
    id: j['id'] as String,
    text: j['text'] as String,
    kind: j['kind'] as String,
    choices: [
      for (final c in (j['choices'] as List?) ?? const [])
        (value: (c as Map)['value'] as String, label: c['label'] as String),
    ],
    afterDays: (j['after_days'] as int?) ?? 0,
  );

  final String id;
  final String text;
  final String kind;
  final List<({String value, String label})> choices;
  final int afterDays;
}

/// Questions par défaut (docs/01), remplacées par celles du serveur dès que /config a répondu.
const defaultQuestions = [
  {
    'id': 'aide',
    'text': "Est-ce que l'app vous aide ?",
    'kind': 'choice',
    'choices': [
      {'value': 'oui', 'label': '😀 Oui'},
      {'value': 'un_peu', 'label': '😐 Un peu'},
      {'value': 'non', 'label': '🙁 Non'},
    ],
    'after_days': 3,
  },
  {
    'id': 'manque',
    'text': "Qu'est-ce qui vous manque ?",
    'kind': 'text',
    'after_days': 10,
  },
];

const _doneKey = 'questions_done';
const _dayKey = 'question_day';

String _today(DateTime now) => '${now.year}-${now.month}-${now.day}';

/// Au plus une question par jour ; disparaît pour de bon dès qu'on répond ou qu'on ferme.
/// "après N jours" = N jours différents avec des ventes.
Future<ShortQuestion?> pickQuestion(
  SettingsStore settings,
  Future<int> Function() saleDays,
  DateTime now,
) async {
  final raw = await settings.get('questions_json');
  final list = [
    for (final q in (raw == null ? defaultQuestions : jsonDecode(raw) as List))
      ShortQuestion.fromJson((q as Map).cast<String, dynamic>()),
  ];
  final done = ((jsonDecode(
    await settings.get(_doneKey) ?? '[]',
  ) as List).cast<String>()).toSet();
  final day = (await settings.get(_dayKey) ?? '').split('|');
  if (day.first == _today(now)) {
    final id = day.length > 1 ? day[1] : '';
    if (done.contains(id)) return null;
    return list.where((q) => q.id == id).firstOrNull;
  }
  final days = await saleDays();
  for (final q in list..sort((a, b) => a.afterDays.compareTo(b.afterDays))) {
    if (done.contains(q.id) || days < q.afterDays) continue;
    await settings.set(_dayKey, '${_today(now)}|${q.id}');
    return q;
  }
  return null;
}

Future<void> closeQuestion(SettingsStore settings, String id) async {
  final done = ((jsonDecode(
    await settings.get(_doneKey) ?? '[]',
  ) as List).cast<String>()).toSet()..add(id);
  await settings.set(_dayKey, '${_today(DateTime.now())}|$id');
  await settings.set(_doneKey, jsonEncode(done.toList()));
}

final questionProvider = FutureProvider.autoDispose<ShortQuestion?>((ref) {
  ref.watch(ledgerChangesProvider);
  final db = ref.read(databaseProvider);
  return pickQuestion(ref.read(settingsStoreProvider), () async {
    final row = await db
        .customSelect(
          "SELECT COUNT(DISTINCT date(sold_at, 'unixepoch', 'localtime')) AS n FROM sales WHERE deleted_at IS NULL",
          readsFrom: {db.sales},
        )
        .getSingle();
    return row.read<int>('n');
  }, DateTime.now());
});

/// Carte en haut d'Aujourd'hui.
class QuestionCard extends ConsumerStatefulWidget {
  const QuestionCard({super.key});

  @override
  ConsumerState<QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends ConsumerState<QuestionCard> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _answer(ShortQuestion q, {String? value, String? text}) async {
    final telemetry = ref.read(telemetryProvider);
    await telemetry.answer(q.id, value: value, text: text);
    trackWith(telemetry, 'question_answered', {'question_id': q.id});
    await closeQuestion(ref.read(settingsStoreProvider), q.id);
  }

  Future<void> _close(ShortQuestion q) =>
      closeQuestion(ref.read(settingsStoreProvider), q.id);

  @override
  Widget build(BuildContext context) {
    final q = ref.watch(questionProvider).value;
    if (q == null) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      color: const Color(0xFFEAF5EE),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    q.text,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (q.kind == 'choice')
                  IconButton(
                    tooltip: 'Fermer',
                    icon: const Icon(Icons.close),
                    onPressed: () => _close(q),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (q.kind == 'choice')
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in q.choices)
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(64, 52),
                        backgroundColor: Colors.white,
                      ),
                      onPressed: () => _answer(q, value: c.value),
                      child: Text(
                        c.label,
                        style: const TextStyle(fontSize: 19),
                      ),
                    ),
                ],
              )
            else ...[
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: TextField(
                  controller: _text,
                  maxLength: 200,
                  style: const TextStyle(fontSize: 19),
                  decoration: const InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed: () => _answer(q, text: _text.text.trim()),
                    child: const Text('Envoyer'),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.muted,
                    ),
                    onPressed: () => _close(q),
                    child: const Text('Plus tard'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

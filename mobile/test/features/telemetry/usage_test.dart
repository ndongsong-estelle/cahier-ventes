import 'dart:convert';

import 'package:cahier_ventes/core/db/settings_store.dart';
import 'package:cahier_ventes/core/providers.dart';
import 'package:cahier_ventes/core/sync/sync_runner.dart';
import 'package:cahier_ventes/core/telemetry/whitelist.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers.dart';

Future<List<Map<String, dynamic>>> outboxEvents(
  TestEnv env,
  WidgetTester tester,
) async {
  final rows = await tester.runAsync(() => env.db.select(env.db.outbox).get());
  return [
    for (final r in rows!)
      if (r.kind == 'event') jsonDecode(r.payload) as Map<String, dynamic>,
  ];
}

void main() {
  testWidgets('événements émis pendant l usage : tous dans la liste blanche', (
    tester,
  ) async {
    final env = TestEnv();
    await env.loggedIn();
    await env.pump(tester);
    await tester.tap(find.text('Mes articles'));
    await settle(tester);
    await tester.tap(find.text("Aujourd'hui").last);
    await settle(tester);
    await tester.tap(find.text("J'AI VENDU"));
    await settle(tester);
    await tester.tap(find.widgetWithText(OutlinedButton, '2'));
    await tester.pump();
    await tester.tap(find.widgetWithText(OutlinedButton, '000'));
    await tester.pump();
    await tester.tap(find.text('PAYÉ'));
    await settle(tester);
    await tapText(tester, 'Annuler');

    final events = await outboxEvents(env, tester);
    final names = events.map((e) => e['name']).toList();
    expect(
      names,
      containsAll([
        'app_opened',
        'tab_viewed',
        'sale_started',
        'sale_saved',
        'sale_undone',
      ]),
    );
    for (final e in events) {
      expect(
        isAllowed(
          e['name'] as String,
          (e['props'] as Map).cast<String, Object?>(),
        ),
        isTrue,
        reason: '$e',
      );
      expect(e['id'], isNotEmpty);
      expect(e['occurred_at'], isNotEmpty);
    }
    final saved =
        events.firstWhere((e) => e['name'] == 'sale_saved')['props'] as Map;
    expect(saved['payment'], 'paid');
    expect(saved['amount_bucket'], 'lt5k');
  });

  testWidgets('serveur coupé : l app reste utilisable, rien n est perdu', (
    tester,
  ) async {
    final env = TestEnv();
    env.server.offline = true;
    await env.loggedIn();
    await env.pump(tester);
    final runner = SyncRunner(env.container.read(syncStepsProvider));
    await tester.runAsync(() => runner.run(onOpen: true));
    await tester.tap(find.text("J'AI VENDU"));
    await settle(tester);
    await tester.tap(find.widgetWithText(OutlinedButton, '5'));
    await tester.pump();
    await tester.tap(find.text('PAYÉ'));
    await settle(tester);
    await tester.runAsync(() => runner.run());
    expect(find.text('Vente enregistrée'), findsOneWidget);
    expect((await outboxEvents(env, tester)).length, greaterThanOrEqualTo(3));
  });

  testWidgets(
    'question courte : après 3 jours avec des ventes, une par jour, disparaît après réponse',
    (tester) async {
      final env = TestEnv();
      await env.loggedIn();
      await env.pump(tester);
      final l = env.container.read(ledgerProvider);
      expect(find.text("Est-ce que l'app vous aide ?"), findsNothing);

      final now = DateTime.now();
      await tester.runAsync(() async {
        for (final d in [0, 1, 2]) {
          await l.addSale(
            amount: 1000,
            soldAt: DateTime(now.year, now.month, now.day - d, 9),
          );
        }
      });
      await settle(tester);
      expect(find.text("Est-ce que l'app vous aide ?"), findsOneWidget);
      await tester.tap(find.text('😀 Oui'));
      await settle(tester);
      expect(find.text("Est-ce que l'app vous aide ?"), findsNothing);

      final rows = await tester.runAsync(
        () => env.db.select(env.db.outbox).get(),
      );
      final answer = rows!.firstWhere((r) => r.kind == 'answer');
      expect(jsonDecode(answer.payload), containsPair('value', 'oui'));

      // 10 jours de ventes : la question suivante attend demain (au plus une par jour).
      await tester.runAsync(() async {
        for (var d = 3; d < 12; d++) {
          await l.addSale(
            amount: 1000,
            soldAt: DateTime(now.year, now.month, now.day - d, 9),
          );
        }
      });
      await settle(tester);
      expect(find.text("Qu'est-ce qui vous manque ?"), findsNothing);
      final s = env.container.read(settingsStoreProvider);
      await tester.runAsync(() => s.set('question_day', '2000-1-1|aide'));
      await tester.runAsync(() => l.addSale(amount: 1));
      await settle(tester);
      expect(find.text("Qu'est-ce qui vous manque ?"), findsOneWidget);
      await tapText(tester, 'Plus tard');
      expect(find.text("Qu'est-ce qui vous manque ?"), findsNothing);
      expect(await tester.runAsync(() => s.get(SettingKey.userId)), '1');
    },
  );
}

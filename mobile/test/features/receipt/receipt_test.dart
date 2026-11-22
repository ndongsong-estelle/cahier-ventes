import 'package:cahier_ventes/core/db/ledger_repository.dart';
import 'package:cahier_ventes/core/format/fcfa.dart';
import 'package:cahier_ventes/core/providers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';

void main() {
  testWidgets(
    'Reçu : boutique, articles, montant, reçu, reste, Merci ; Envoyer et WhatsApp',
    (tester) async {
      final env = TestEnv();
      final opened = <Uri>[];
      await env.loggedIn();
      await env.pumpWith(tester, [
        urlOpenerProvider.overrideWithValue((u) async => opened.add(u)),
      ]);
      final l = env.container.read(ledgerProvider);
      await tester.runAsync(() async {
        final robe = await l.addArticle(name: 'Robe', price: 15000);
        final p = await l.addPerson('Awa', phone: '+237690000001');
        await l.addSale(
          amount: 15000,
          personId: p,
          articles: [SoldArticle(robe, 1)],
          paidNow: 5000,
        );
      });
      await settle(tester);
      await tester.tap(find.text('Awa'));
      await settle(tester);
      await tapText(tester, 'Envoyer le reçu');

      expect(find.text('Chez Awa'), findsOneWidget);
      expect(find.text('+237690123456'), findsOneWidget);
      expect(find.text('Robe ×1'), findsOneWidget);
      expect(find.text(formatFcfa(10000)), findsOneWidget);
      expect(find.text('Merci !'), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(find.text('Envoyer'));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await settle(tester);
      expect(env.sharer.images, hasLength(1));
      expect(env.sharer.images.single.$1.length, greaterThan(1000));

      await tapText(tester, 'WhatsApp Awa');
      expect(opened.single.path, '/237690000001');
      expect(
        opened.single.queryParameters['text'],
        contains('Reste : ${formatFcfa(10000)}'),
      );
    },
  );
}

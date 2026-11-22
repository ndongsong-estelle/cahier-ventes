import 'package:cahier_ventes/core/db/ledger_repository.dart';
import 'package:cahier_ventes/core/format/fcfa.dart';
import 'package:cahier_ventes/core/notifications/weekly_notification.dart';
import 'package:cahier_ventes/core/providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers.dart';

void main() {
  test('prochain dimanche 19 h', () {
    expect(
      nextSunday19h(DateTime(2026, 11, 18, 10)),
      DateTime(2026, 11, 22, 19),
    );
    expect(
      nextSunday19h(DateTime(2026, 11, 22, 18, 59)),
      DateTime(2026, 11, 22, 19),
    );
    expect(
      nextSunday19h(DateTime(2026, 11, 22, 19, 0)),
      DateTime(2026, 11, 29, 19),
    );
  });

  testWidgets('connectée : notification du dimanche programmée', (
    tester,
  ) async {
    final env = TestEnv();
    await env.loggedIn();
    await env.pump(tester);
    expect(env.notifications.scheduled, 1);
  });

  testWidgets('Bilan : semaine, mois, comparaison et 3 plus vendus', (
    tester,
  ) async {
    final env = TestEnv();
    await env.loggedIn();
    await env.pump(tester);
    final l = env.container.read(ledgerProvider);
    final now = DateTime.now();
    await tester.runAsync(() async {
      final a = await l.addArticle(name: 'Riz', price: 1000);
      final b = await l.addArticle(name: 'Huile', price: 2000);
      final c = await l.addArticle(name: 'Sucre', price: 500);
      final d = await l.addArticle(name: 'Sel', price: 100);
      final p = await l.addPerson('Awa');
      await l.addSale(
        amount: 5000,
        articles: [SoldArticle(a, 5)],
        paidNow: 5000,
      );
      await l.addSale(
        amount: 6000,
        personId: p,
        articles: [SoldArticle(b, 3)],
        paidNow: 1000,
      );
      await l.addSale(
        amount: 1000,
        articles: [SoldArticle(c, 2), SoldArticle(d, 1)],
        paidNow: 1000,
      );
      // Semaine dernière : 20 000 F vendus.
      await l.addSale(
        amount: 20000,
        paidNow: 20000,
        soldAt: now.subtract(const Duration(days: 7)),
      );
    });
    await tester.tap(find.text("vendus aujourd'hui"));
    await settle(tester);

    expect(find.text('Cette semaine'), findsOneWidget);
    expect(find.text(formatFcfa(12000)), findsOneWidget);
    expect(find.text(formatFcfa(5000)), findsWidgets); // on vous doit 5 000
    expect(
      find.text('-${formatFcfa(8000)} par rapport à la semaine dernière'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    expect(find.text('Riz'), findsOneWidget);
    expect(find.text('×5'), findsOneWidget);
    expect(find.text('Sel'), findsNothing); // seulement 3

    await tester.tap(find.text('Ce mois'));
    await settle(tester);
    expect(find.textContaining('par rapport au mois dernier'), findsOneWidget);
  });
}

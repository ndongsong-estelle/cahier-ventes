import 'package:cahier_ventes/core/format/fcfa.dart';
import 'package:cahier_ventes/core/providers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';

String f(int v) => formatFcfa(v);

void main() {
  testWidgets('vide : invitation à toucher J ai vendu', (tester) async {
    final env = TestEnv();
    await env.loggedIn();
    await env.pump(tester);
    expect(
      find.text("Pas encore de vente aujourd'hui. Touchez J'ai vendu."),
      findsOneWidget,
    );
    expect(find.text("J'AI VENDU"), findsOneWidget);
  });

  testWidgets('total du jour, reçu, on vous doit et liste', (tester) async {
    final env = TestEnv();
    await env.loggedIn();
    await env.pump(tester);
    final ledger = env.container.read(ledgerProvider);
    final now = DateTime.now();
    await tester.runAsync(() async {
      final p = await ledger.addPerson('Maman Ngo');
      await ledger.addSale(amount: 15000, personId: p, paidNow: 5000);
      await ledger.addSale(amount: 8000, paidNow: 8000);
      // Hier : ne compte pas aujourd'hui.
      await ledger.addSale(
        amount: 99000,
        soldAt: DateTime(now.year, now.month, now.day - 1, 12),
      );
    });
    await settle(tester);

    expect(find.text(f(23000)), findsOneWidget);
    expect(find.text('Reçu ${f(13000)}'), findsOneWidget);
    expect(find.text('On vous doit ${f(10000)}'), findsOneWidget);
    expect(find.text('Maman Ngo'), findsOneWidget);
    expect(find.text('Doit ${f(10000)}'), findsOneWidget);
    expect(find.text('Payé'), findsOneWidget);

    await tester.tap(find.byTooltip("Jour d'avant"));
    await settle(tester);
    expect(find.text(f(99000)), findsWidgets);
  });

  testWidgets('toucher le total ouvre le Bilan', (tester) async {
    final env = TestEnv();
    await env.loggedIn();
    await env.pump(tester);
    await tester.tap(find.text("vendus aujourd'hui"));
    await settle(tester);
    expect(find.text('Bilan'), findsOneWidget);
  });

  testWidgets('Aujourd hui tient sur 360 × 640 avec police à 130 %', (
    tester,
  ) async {
    final layoutErrors = smallPhone(tester);
    final env = TestEnv();
    await env.loggedIn();
    await env.pump(tester);
    await tester.runAsync(() async {
      final l = env.container.read(ledgerProvider);
      final p = await l.addPerson('Maman Ngo Bassogog Christelle');
      await l.addSale(amount: 1250000, personId: p, paidNow: 5000);
    });
    await settle(tester);
    expect(layoutErrors(), isEmpty);
  });
}

import 'package:cahier_ventes/core/db/ledger_queries.dart';
import 'package:cahier_ventes/core/db/ledger_repository.dart';
import 'package:cahier_ventes/core/domain/ledger.dart';
import 'package:cahier_ventes/core/format/fcfa.dart';
import 'package:cahier_ventes/core/providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers.dart';

Future<(TestEnv, LedgerRepository, String)> openDetail(
  WidgetTester tester,
) async {
  final env = TestEnv();
  await env.loggedIn();
  await env.pump(tester);
  final ledger = env.container.read(ledgerProvider);
  final id = (await tester.runAsync(() async {
    final riz = await ledger.addArticle(name: 'Riz', price: 5000, remaining: 5);
    final p = await ledger.addPerson('Awa');
    return ledger.addSale(
      amount: 10000,
      personId: p,
      articles: [SoldArticle(riz, 2)],
      paidNow: 4000,
      method: PayMethod.orangeMoney,
    );
  }))!;
  await settle(tester);
  await tester.tap(find.text('Awa'));
  await settle(tester);
  return (env, ledger, id);
}

void main() {
  testWidgets('montant, articles, reçu avec moyen, ce qui reste', (
    tester,
  ) async {
    await openDetail(tester);
    expect(find.text(formatFcfa(10000)), findsOneWidget);
    expect(find.text('Riz ×2'), findsOneWidget);
    expect(find.text('Reçu ${formatFcfa(4000)}'), findsOneWidget);
    expect(find.text('Orange Money · ${formatFcfa(4000)}'), findsOneWidget);
    expect(find.text('On vous doit ${formatFcfa(6000)}'), findsOneWidget);
  });

  testWidgets('"Awa a payé" : pavé prérempli avec le reste', (tester) async {
    final (_, ledger, id) = await openDetail(tester);
    await tapText(tester, 'Awa a payé');
    expect(find.byKey(const Key('pay-amount')), findsOneWidget);
    expect(find.text(formatFcfa(6000)), findsWidgets);
    await tester.tap(find.text('MoMo'));
    await tester.pump();
    await tapText(tester, 'Payé');
    final line = (await tester.runAsync(() => ledger.saleLine(id)))!;
    expect(statusOf(line), SaleStatus.paid);
    expect(find.text('Awa a payé'), findsNothing);
  });

  testWidgets(
    'Modifier rouvre J ai vendu prérempli ; Annuler remet comme avant',
    (tester) async {
      final (_, ledger, id) = await openDetail(tester);
      await tapText(tester, 'Modifier');
      expect(find.text(formatFcfa(10000)), findsOneWidget);
      expect(find.text('Riz ×2'), findsOneWidget);
      await tester.tap(find.byTooltip('Retirer'));
      await tester.pump();
      expect(find.text(formatFcfa(0)), findsOneWidget);
      for (final d in ['3', '000']) {
        await tester.tap(find.widgetWithText(OutlinedButton, d).last);
        await tester.pump();
      }
      await tapText(tester, 'Garder');
      var line = (await tester.runAsync(() => ledger.saleLine(id)))!;
      expect(line.amount, 3000);
      expect(received(line), 3000); // dernier paiement réduit
      expect(
        (await tester.runAsync(() => ledger.saleDetail(id)))!.articles,
        isEmpty,
      );

      await tapText(tester, 'Annuler');
      line = (await tester.runAsync(() => ledger.saleLine(id)))!;
      expect(line.amount, 10000);
      expect(received(line), 4000);
      final detail = (await tester.runAsync(() => ledger.saleDetail(id)))!;
      expect(detail.articles.single.quantity, 2);
      expect(detail.articles.single.article.remaining, 3);
    },
  );

  testWidgets('Supprimer avec confirmation, puis Annuler', (tester) async {
    final (_, ledger, id) = await openDetail(tester);
    await tapText(tester, 'Supprimer');
    expect(find.text('Supprimer cette vente ?'), findsOneWidget);
    await tapText(tester, 'Garder');
    expect(
      (await tester.runAsync(() => ledger.saleLine(id)))!.deleted,
      isFalse,
    );

    await tapText(tester, 'Supprimer');
    await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
    await settle(tester);
    expect((await tester.runAsync(() => ledger.saleLine(id)))!.deleted, isTrue);
    expect(find.text('Vente supprimée'), findsOneWidget);
    await tapText(tester, 'Annuler');
    final line = (await tester.runAsync(() => ledger.saleLine(id)))!;
    expect(line.deleted, isFalse);
    expect(received(line), 4000);
  });

  testWidgets('supprimer un paiement', (tester) async {
    final (_, ledger, id) = await openDetail(tester);
    await tester.tap(find.byTooltip('Supprimer ce paiement'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
    await settle(tester);
    expect(received((await tester.runAsync(() => ledger.saleLine(id)))!), 0);
    expect(find.text('On vous doit ${formatFcfa(10000)}'), findsOneWidget);
  });
}

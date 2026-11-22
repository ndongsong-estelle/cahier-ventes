import 'package:cahier_ventes/core/db/ledger_queries.dart';
import 'package:cahier_ventes/core/db/ledger_repository.dart';
import 'package:cahier_ventes/core/format/fcfa.dart';
import 'package:cahier_ventes/core/providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers.dart';
import '../sell/sell_test.dart' show FakePhotos;

Future<(TestEnv, LedgerRepository)> openArticles(
  WidgetTester tester, {
  Future<void> Function(LedgerRepository)? seed,
}) async {
  final env = TestEnv();
  await env.loggedIn();
  await env.pumpWith(tester, [
    photoServiceProvider.overrideWithValue(FakePhotos()),
  ]);
  final ledger = env.container.read(ledgerProvider);
  if (seed != null) await tester.runAsync(() => seed(ledger));
  await tester.tap(find.text('Mes articles'));
  await settle(tester);
  return (env, ledger);
}

void main() {
  testWidgets(
    'grille : prix, nom, pastilles, les plus vendus d abord, initiales',
    (tester) async {
      await openArticles(
        tester,
        seed: (l) async {
          await l.addArticle(
            name: 'Savon de Marseille',
            price: 500,
            remaining: 2,
          );
          final riz = await l.addArticle(
            name: 'Riz',
            price: 1000,
            remaining: 0,
          );
          await l.addArticle(price: 750);
          await l.addSale(amount: 3000, articles: [SoldArticle(riz, 3)]);
        },
      );
      expect(find.text(formatFcfa(1000)), findsOneWidget);
      expect(find.text('Savon de Marseille'), findsOneWidget);
      expect(find.text('Plus que 2'), findsOneWidget);
      expect(find.text('Épuisé'), findsOneWidget);
      expect(find.text('SD'), findsOneWidget);
      expect(find.text('?'), findsOneWidget);
      final riz = tester.getTopLeft(find.text('Riz'));
      final savon = tester.getTopLeft(find.text('Savon de Marseille'));
      expect(riz.dx < savon.dx || riz.dy < savon.dy, isTrue);
    },
  );

  testWidgets('ajouter un article : photo, prix, nom facultatif', (
    tester,
  ) async {
    final (_, ledger) = await openArticles(tester);
    await tester.tap(find.text('Ajouter un article'));
    await settle(tester);
    await tapText(tester, 'Photo');
    await tester.enterText(find.byType(TextField).at(0), '2500');
    await tapText(tester, 'Garder');
    final list = (await tester.runAsync(() => ledger.articlesForSale()))!;
    expect(list.single.price, 2500);
    expect(list.single.name, isNull);
    expect(list.single.photoPath, '/tmp/photo-test.jpg');
  });

  testWidgets('fiche : il en reste avec − et +, puis Ne plus afficher', (
    tester,
  ) async {
    late String id;
    final (_, ledger) = await openArticles(
      tester,
      seed: (l) async => id = await l.addArticle(name: 'Pagne', price: 6000),
    );
    await tester.tap(find.text('Pagne'));
    await settle(tester);
    expect(find.text('Il en reste combien ?'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Un de plus'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byTooltip('Un de plus'));
      await settle(tester);
    }
    await tester.tap(find.byTooltip('Un de moins'));
    await settle(tester);
    expect((await tester.runAsync(() => ledger.article(id)))!.remaining, 2);
    expect(find.text('Plus que 2'), findsOneWidget);

    await tapText(tester, 'Ne plus afficher');
    expect(await tester.runAsync(() => ledger.articlesForSale()), isEmpty);
    await tapText(tester, 'Annuler');
    expect(
      (await tester.runAsync(() => ledger.articlesForSale()))!,
      hasLength(1),
    );
  });

  testWidgets('fiche : modifier le prix', (tester) async {
    late String id;
    final (_, ledger) = await openArticles(
      tester,
      seed: (l) async => id = await l.addArticle(name: 'Pagne', price: 6000),
    );
    await tester.tap(find.text('Pagne'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).at(0), '6500');
    await tapText(tester, 'Garder');
    expect((await tester.runAsync(() => ledger.article(id)))!.price, 6500);
  });
}

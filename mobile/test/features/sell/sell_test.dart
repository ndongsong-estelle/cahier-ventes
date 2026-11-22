import 'package:cahier_ventes/core/db/ledger_repository.dart';
import 'package:cahier_ventes/core/domain/ledger.dart';
import 'package:cahier_ventes/core/format/fcfa.dart';
import 'package:cahier_ventes/core/photos/photo_service.dart';
import 'package:cahier_ventes/core/providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers.dart';

class FakePhotos implements PhotoService {
  final deleted = <String>[];
  String? next = '/tmp/photo-test.jpg';

  @override
  Future<String?> pick({bool camera = false}) async => next;

  @override
  Future<void> delete(String path) async => deleted.add(path);
}

Future<(TestEnv, LedgerRepository)> openSell(
  WidgetTester tester, {
  Future<void> Function(LedgerRepository)? seed,
}) async {
  final env = TestEnv();
  await env.loggedIn();
  await env.pump(tester);
  final ledger = env.container.read(ledgerProvider);
  if (seed != null) await tester.runAsync(() => seed(ledger));
  await tester.tap(find.text("J'AI VENDU"));
  await settle(tester);
  return (env, ledger);
}

Future<void> typeAmount(WidgetTester tester, String digits) async {
  for (final d in digits.split('')) {
    await tester.tap(find.widgetWithText(OutlinedButton, d).last);
  }
  await tester.pump();
}

void main() {
  testWidgets('article connu paidButton en espèces en 3 touchers', (
    tester,
  ) async {
    late String robe;
    final (env, ledger) = await openSell(
      tester,
      seed: (l) async => robe = await l.addArticle(
        name: 'Robe fleurie',
        price: 15000,
        remaining: 4,
      ),
    ); // toucher 1 : J'ai vendu
    await tester.tap(find.byKey(Key('article-$robe'))); // toucher 2 : photo
    await tester.pump();
    expect(find.text(formatFcfa(15000)), findsOneWidget);
    expect(find.text('Robe fleurie ×1'), findsOneWidget);
    await tester.tap(find.text('PAYÉ')); // toucher 3
    await settle(tester);

    final sales = await tester.runAsync(() => ledger.saleLines());
    expect(sales!.single.amount, 15000);
    expect(statusOf(sales.single), SaleStatus.paid);
    expect(sales.single.payments.single.amount, 15000);
    expect((await tester.runAsync(() => ledger.article(robe)))!.remaining, 3);
    expect(find.text('Vente enregistrée'), findsOneWidget);
    expect(find.text('Robe fleurie'), findsOneWidget); // sur Aujourd'hui
  });

  testWidgets('retoucher = ×2, la croix retire', (tester) async {
    late String savon;
    await openSell(
      tester,
      seed: (l) async => savon = await l.addArticle(name: 'Savon', price: 500),
    );
    await tester.tap(find.byKey(Key('article-$savon')));
    await tester.tap(find.byKey(Key('article-$savon')));
    await tester.pump();
    expect(find.text('Savon ×2'), findsOneWidget);
    expect(find.text(formatFcfa(1000)), findsOneWidget);
    await tester.tap(find.byTooltip('Retirer'));
    await tester.pump();
    expect(find.text(formatFcfa(0)), findsOneWidget);
  });

  testWidgets('boutons désactivés tant que le montant est 0', (tester) async {
    await openSell(tester);
    final paidButton = tester.widget<FilledButton>(
      find.ancestor(of: find.text('PAYÉ'), matching: find.byType(FilledButton)),
    );
    expect(paidButton.onPressed, isNull);
    await typeAmount(tester, '2');
    final after = tester.widget<FilledButton>(
      find.ancestor(of: find.text('PAYÉ'), matching: find.byType(FilledButton)),
    );
    expect(after.onPressed, isNotNull);
  });

  testWidgets('"Pas encore" sans nom demande le nom', (tester) async {
    final (_, ledger) = await openSell(tester);
    await typeAmount(tester, '5');
    await tester.tap(find.widgetWithText(OutlinedButton, '000'));
    await tester.pump();
    expect(find.text(formatFcfa(5000)), findsOneWidget);
    await tester.tap(find.text('PAS ENCORE'));
    await settle(tester);
    expect(find.text('Qui vous doit ?'), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'Sali',
    );
    await tester.pump();
    await tester.tap(find.text('Continuer'));
    await settle(tester);

    final sale = (await tester.runAsync(() => ledger.saleLines()))!.single;
    expect(sale.amount, 5000);
    expect(remaining(sale), 5000);
    expect(sale.personId, isNotNull);
    expect(find.text('Sali'), findsOneWidget);
  });

  testWidgets('"Une partie" : montant reçu puis nom', (tester) async {
    final (_, ledger) = await openSell(
      tester,
      seed: (l) => l.addSale(amount: 100, personId: null).then((_) async {
        await l.personByName('Maman Ngo');
      }),
    );
    await typeAmount(tester, '8');
    await tester.tap(find.widgetWithText(OutlinedButton, '000'));
    await tester.tap(find.text('UNE PARTIE'));
    await settle(tester);
    expect(find.text('Combien avez-vous reçu ?'), findsOneWidget);
    final dialogKey = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(OutlinedButton, '3'),
    );
    await tester.tap(dialogKey);
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(OutlinedButton, '000'),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Continuer'));
    await settle(tester);
    expect(find.text('Qui vous doit ?'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(ActionChip, 'Maman Ngo'),
      ),
    );
    await settle(tester);

    final sales = (await tester.runAsync(() => ledger.saleLines()))!;
    final sale = sales.firstWhere((s) => s.amount == 8000);
    expect(received(sale), 3000);
    expect(statusOf(sale), SaleStatus.partial);
  });

  testWidgets('Annuler supprime la vente et rétablit "il en reste"', (
    tester,
  ) async {
    late String riz;
    final (_, ledger) = await openSell(
      tester,
      seed: (l) async =>
          riz = await l.addArticle(name: 'Riz', price: 1000, remaining: 2),
    );
    await tester.tap(find.byKey(Key('article-$riz')));
    await tester.pump();
    await tester.tap(find.text('PAYÉ'));
    await settle(tester);
    expect((await tester.runAsync(() => ledger.article(riz)))!.remaining, 1);

    await tester.tap(find.text('Annuler'));
    await settle(tester);
    expect(await tester.runAsync(() => ledger.saleLines()), isEmpty);
    expect((await tester.runAsync(() => ledger.article(riz)))!.remaining, 2);
    expect(
      find.text("Pas encore de vente aujourd'hui. Touchez J'ai vendu."),
      findsOneWidget,
    );
  });

  testWidgets('nouvelle photo : Garder crée l article', (tester) async {
    final env = TestEnv();
    final photos = FakePhotos();
    await env.loggedIn();
    await env.pumpWith(tester, [
      photoServiceProvider.overrideWithValue(photos),
    ]);
    await tester.tap(find.text("J'AI VENDU"));
    await settle(tester);
    await tester.tap(find.text('Photo'));
    await settle(tester);
    expect(
      find.text('Garder cet article pour la prochaine fois ?'),
      findsOneWidget,
    );
    final fields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), '2500');
    await tester.enterText(fields.at(1), 'Pagne');
    await tester.tap(find.text('Garder'));
    await settle(tester);
    expect(find.text('Pagne ×1'), findsOneWidget);
    expect(find.text(formatFcfa(2500)), findsOneWidget);
  });

  testWidgets('tient sur 360 × 640 avec police à 130 %', (tester) async {
    final layoutErrors = smallPhone(tester);
    await openSell(
      tester,
      seed: (l) async {
        await l.addArticle(name: 'Robe', price: 15000);
        await l.personByName('Maman Ngo');
      },
    );
    expect(layoutErrors(), isEmpty);
    expect(find.text('PAS ENCORE'), findsOneWidget);
  });
}

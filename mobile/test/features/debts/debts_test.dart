import 'package:cahier_ventes/core/db/ledger_queries.dart';
import 'package:cahier_ventes/core/db/ledger_repository.dart';
import 'package:cahier_ventes/core/format/fcfa.dart';
import 'package:cahier_ventes/core/providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers.dart';

Future<(TestEnv, LedgerRepository, List<Uri>)> openDebts(
  WidgetTester tester, {
  Future<void> Function(LedgerRepository)? seed,
}) async {
  final env = TestEnv();
  final opened = <Uri>[];
  await env.loggedIn();
  await env.pumpWith(tester, [
    urlOpenerProvider.overrideWithValue((u) async => opened.add(u)),
  ]);
  final ledger = env.container.read(ledgerProvider);
  if (seed != null) await tester.runAsync(() => seed(ledger));
  await tester.tap(find.text('On me doit'));
  await settle(tester);
  return (env, ledger, opened);
}

Future<void> seedTwo(LedgerRepository l) async {
  final now = DateTime.now();
  final ngo = await l.addPerson('Maman Ngo');
  final sali = await l.addPerson('Sali', phone: '+237690000002');
  await l.addSale(
    amount: 10000,
    personId: ngo,
    soldAt: now.subtract(const Duration(days: 12)),
  );
  await l.addSale(
    amount: 15000,
    personId: ngo,
    paidNow: 0,
    soldAt: now.subtract(const Duration(days: 3)),
  );
  await l.addSale(amount: 40000, personId: sali, paidNow: 0);
  await l.addSale(amount: 5000, paidNow: 5000);
}

void main() {
  testWidgets('vide : Bravo', (tester) async {
    await openDebts(tester);
    expect(
      find.text("Personne ne vous doit d'argent. Bravo !"),
      findsOneWidget,
    );
  });

  testWidgets('total, tri par montant décroissant, depuis N jours', (
    tester,
  ) async {
    await openDebts(tester, seed: seedTwo);
    expect(find.text('On vous doit ${formatFcfa(65000)}'), findsOneWidget);
    final sali = tester.getTopLeft(find.text('Sali')).dy;
    final ngo = tester.getTopLeft(find.text('Maman Ngo')).dy;
    expect(sali < ngo, isTrue);
    expect(find.text('depuis 12 jours'), findsOneWidget);
  });

  testWidgets(
    'WhatsApp : message de relance ; numéro inconnu demandé une fois puis gardé',
    (tester) async {
      final (env, ledger, opened) = await openDebts(tester, seed: seedTwo);
      await tester.tap(find.byTooltip('Relancer Sali'));
      await settle(tester);
      expect(opened.single.host, 'wa.me');
      expect(opened.single.path, '/237690000002');
      expect(
        opened.single.queryParameters['text'],
        "Bonjour Sali, c'est Chez Awa. Il reste ${formatFcfa(40000)} à régler. Merci et bonne journée !",
      );

      await tester.tap(find.byTooltip('Relancer Maman Ngo'));
      await settle(tester);
      expect(find.text('Numéro de Maman Ngo'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '677 11 22 33');
      await tapText(tester, 'Garder');
      expect(opened.last.path, '/237677112233');

      await tester.tap(find.byTooltip('Relancer Maman Ngo'));
      await settle(tester);
      expect(find.text('Numéro de Maman Ngo'), findsNothing);
      expect(opened, hasLength(3));
    },
  );

  testWidgets(
    'fiche : "a payé" prérempli = tout, réparti de la plus ancienne',
    (tester) async {
      final (_, ledger, _) = await openDebts(tester, seed: seedTwo);
      await tester.tap(find.text('Maman Ngo'));
      await settle(tester);
      expect(find.text(formatFcfa(25000)), findsWidgets);
      await tapText(tester, 'Maman Ngo a payé');
      expect(find.byKey(const Key('pay-amount')), findsOneWidget);

      // Montant trop grand : message et bouton désactivé.
      Finder key(String k) => find.descendant(
        of: find.byType(Dialog),
        matching: find.widgetWithText(OutlinedButton, k),
      );
      await tester.tap(key('0'));
      await tester.pump();
      expect(
        find.text('Maman Ngo ne vous doit que ${formatFcfa(25000)}.'),
        findsOneWidget,
      );
      for (var i = 0; i < 6; i++) {
        await tester.tap(find.byIcon(Icons.backspace_outlined).last);
        await tester.pump();
      }
      for (final k in ['1', '2', '000']) {
        await tester.tap(key(k));
        await tester.pump();
      }
      await tester.tap(find.widgetWithText(FilledButton, 'Payé'));
      await settle(tester);

      final person = (await tester.runAsync(() async {
        final d = await ledger.debts();
        return d.people.firstWhere((p) => p.person.name == 'Maman Ngo');
      }))!;
      expect(person.owed, 13000);
      // La plus ancienne (10 000) est soldée, la suivante a reçu 2 000.
      final detail = (await tester.runAsync(
        () => ledger.personDebt(person.person.id),
      ))!;
      expect(detail.unpaid.single.rest, 13000);
      expect(
        find.text('Maman Ngo a payé ${formatFcfa(12000)}'),
        findsOneWidget,
      );

      await tapText(tester, 'Annuler');
      final back = (await tester.runAsync(
        () => ledger.personDebt(person.person.id),
      ))!;
      expect(back.owed, 25000);
    },
  );

  testWidgets('fiche : Appeler et modifier le nom', (tester) async {
    final (_, ledger, opened) = await openDebts(tester, seed: seedTwo);
    await tester.tap(find.text('Sali'));
    await settle(tester);
    await tapText(tester, 'Appeler');
    expect(opened.single.scheme, 'tel');
    await tester.tap(find.byTooltip('Modifier le nom ou le numéro'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).first, 'Sali Bello');
    await tapText(tester, 'Garder');
    final d = (await tester.runAsync(() => ledger.debts()))!;
    expect(d.people.map((p) => p.person.name), contains('Sali Bello'));
  });
}

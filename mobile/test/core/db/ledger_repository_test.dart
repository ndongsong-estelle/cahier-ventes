import 'package:cahier_ventes/core/db/database.dart';
import 'package:cahier_ventes/core/db/ledger_repository.dart';
import 'package:cahier_ventes/core/domain/ledger.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late LedgerRepository repo;
  var clock = DateTime(2026, 11, 4, 10);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    clock = DateTime(2026, 11, 4, 10);
    repo = LedgerRepository(db, clock: () => clock);
  });
  tearDown(() => db.close());

  test(
    'vente payée : un paiement du montant total à l heure de la vente',
    () async {
      final id = await repo.addSale(amount: 2500, paidNow: 2500);
      final s = await repo.saleLine(id);
      expect(s.payments.single.amount, 2500);
      expect(s.payments.single.paidAt, s.soldAt);
      expect(statusOf(s), SaleStatus.paid);
    },
  );

  test(
    'il en reste : décompté, rétabli à la suppression et à la modification',
    () async {
      final riz = await repo.addArticle(name: 'Riz', price: 500, remaining: 3);
      final id = await repo.addSale(
        amount: 1000,
        articles: [SoldArticle(riz, 2)],
        paidNow: 1000,
      );
      expect((await repo.article(riz))!.remaining, 1);

      await repo.updateSale(id, articles: [SoldArticle(riz, 3)]);
      expect((await repo.article(riz))!.remaining, 0);

      // Jamais de blocage : on peut vendre un article épuisé.
      final id2 = await repo.addSale(
        amount: 500,
        articles: [SoldArticle(riz, 1)],
      );
      expect((await repo.article(riz))!.remaining, -1);

      await repo.deleteSale(id2);
      await repo.deleteSale(id);
      await repo.deleteSale(id); // deux fois : sans effet
      expect((await repo.article(riz))!.remaining, 3);
    },
  );

  test('article non compté : remaining reste null', () async {
    final a = await repo.addArticle(name: 'Savon', price: 300);
    await repo.addSale(amount: 300, articles: [SoldArticle(a, 1)]);
    expect((await repo.article(a))!.remaining, isNull);
  });

  test('suppression : la vente et ses paiements ne comptent plus', () async {
    final p = await repo.addPerson('Awa');
    final id = await repo.addSale(amount: 4000, personId: p, paidNow: 1000);
    expect(owedBy(await repo.saleLines(personId: p)), 3000);
    await repo.deleteSale(id);
    expect(await repo.saleLines(personId: p), isEmpty);
    final gone = await repo.saleLine(id);
    expect(gone.deleted, isTrue);
    expect(gone.payments.every((x) => x.deleted), isTrue);
  });

  test('modification du montant : le dernier paiement est réduit', () async {
    final id = await repo.addSale(amount: 5000, paidNow: 5000);
    await repo.updateSale(id, amount: 3000);
    final s = await repo.saleLine(id);
    expect(s.amount, 3000);
    expect(received(s), 3000);
    expect(remaining(s), 0);
  });

  test('"Awa a payé" réparti sur 3 ventes, surplus refusé', () async {
    final p = await repo.addPerson('Awa');
    for (final (amount, day) in [(1000, 1), (2000, 2), (3000, 3)]) {
      await repo.addSale(
        amount: amount,
        personId: p,
        soldAt: DateTime(2026, 11, day, 9),
      );
    }
    final r = await repo.personPaid(p, 2500, method: PayMethod.momo);
    expect(r.allocations.map((a) => a.amount), [1000, 1500]);
    expect(owedBy(await repo.saleLines(personId: p)), 3500);

    final r2 = await repo.personPaid(p, 9000);
    expect(r2.leftover, 5500);
    expect(owedBy(await repo.saleLines(personId: p)), 0);
  });

  test('paiement sur une vente plafonné au reste', () async {
    final id = await repo.addSale(amount: 2000, paidNow: 500);
    expect(await repo.addPayment(id, 5000), 1500);
    expect(await repo.addPayment(id, 100), 0);
  });

  test('montant nul refusé', () async {
    expect(() => repo.addSale(amount: 0), throwsArgumentError);
  });

  test('personne retrouvée par son nom', () async {
    final a = await repo.personByName('Awa');
    expect(await repo.personByName(' awa '), a);
    expect(await repo.personByName('Brice'), isNot(a));
  });

  test('changer la personne d une vente', () async {
    final a = await repo.addPerson('Awa');
    final b = await repo.addPerson('Brice');
    final id = await repo.addSale(amount: 1000, personId: a);
    await repo.updateSale(id, personId: Value(b));
    expect(await repo.saleLines(personId: a), isEmpty);
    expect((await repo.saleLines(personId: b)).single.id, id);
  });

  test('wipe vide tout', () async {
    await repo.addSale(amount: 1000, paidNow: 1000);
    await db.wipe();
    expect(await repo.saleLines(), isEmpty);
  });
}

import 'package:cahier_ventes/core/domain/ledger.dart';
import 'package:flutter_test/flutter_test.dart';

PaymentLine pay(String id, int amount, DateTime at, {bool deleted = false}) =>
    PaymentLine(id: id, amount: amount, paidAt: at, deleted: deleted);

SaleLine sale(
  String id,
  int amount,
  DateTime at, {
  List<PaymentLine> payments = const [],
  String? person = 'p1',
  bool deleted = false,
}) => SaleLine(
  id: id,
  amount: amount,
  soldAt: at,
  personId: person,
  payments: payments,
  deleted: deleted,
);

void main() {
  final t0 = DateTime(2026, 11, 2, 10); // lundi

  group('reçu et reste', () {
    test('paiement partiel', () {
      final s = sale('s', 10000, t0, payments: [pay('a', 4000, t0)]);
      expect(received(s), 4000);
      expect(remaining(s), 6000);
      expect(statusOf(s), SaleStatus.partial);
    });

    test('paiement supprimé ignoré, payé et pas encore payé', () {
      final s = sale(
        's',
        5000,
        t0,
        payments: [pay('a', 5000, t0, deleted: true)],
      );
      expect(remaining(s), 5000);
      expect(statusOf(s), SaleStatus.unpaid);
      expect(
        statusOf(sale('x', 5000, t0, payments: [pay('b', 5000, t0)])),
        SaleStatus.paid,
      );
    });

    test('reste jamais négatif', () {
      final s = sale('s', 3000, t0, payments: [pay('a', 5000, t0)]);
      expect(remaining(s), 0);
    });

    test('paiement plafonné au reste', () {
      final s = sale('s', 3000, t0, payments: [pay('a', 1000, t0)]);
      expect(cappedPayment(s, 5000), 2000);
      expect(cappedPayment(s, 500), 500);
    });
  });

  group('répartition "{Nom} a payé X"', () {
    final sales = [
      sale('recent', 3000, t0.add(const Duration(days: 2))),
      sale('old', 2000, t0, payments: [pay('a', 500, t0)]),
      sale('mid', 4000, t0.add(const Duration(days: 1))),
    ];

    test('sur 3 ventes, de la plus ancienne à la plus récente', () {
      final r = allocatePersonPayment(sales, 6000);
      expect(r.allocations, const [
        Allocation('old', 1500),
        Allocation('mid', 4000),
        Allocation('recent', 500),
      ]);
      expect(r.leftover, 0);
    });

    test('montant trop grand : le surplus n est pas enregistré', () {
      final r = allocatePersonPayment(sales, 10000);
      expect(r.allocations.fold(0, (s, a) => s + a.amount), 8500);
      expect(r.leftover, 1500);
    });

    test('ventes soldées et supprimées ignorées', () {
      final r = allocatePersonPayment([
        sale('paid', 1000, t0, payments: [pay('a', 1000, t0)]),
        sale('gone', 1000, t0, deleted: true),
        sale('open', 1000, t0),
      ], 1000);
      expect(r.allocations, const [Allocation('open', 1000)]);
    });
  });

  group('modification du montant', () {
    final s = sale(
      's',
      10000,
      t0,
      payments: [
        pay('first', 4000, t0),
        pay('last', 6000, t0.add(const Duration(hours: 1))),
      ],
    );

    test('montant plus grand : rien à changer', () {
      expect(paymentsForNewAmount(s, 12000), isEmpty);
    });

    test('réduit le dernier paiement', () {
      expect(paymentsForNewAmount(s, 8000), const [
        PaymentChange('last', 4000),
      ]);
    });

    test('puis le précédent si cela ne suffit pas', () {
      expect(paymentsForNewAmount(s, 3000), const [
        PaymentChange('last', 0),
        PaymentChange('first', 3000),
      ]);
    });
  });

  group('on vous doit', () {
    test('par personne, total, depuis N jours', () {
      final sales = [
        sale('a', 2000, t0, person: 'p1'),
        sale(
          'b',
          3000,
          t0.add(const Duration(days: 3)),
          person: 'p1',
          payments: [pay('x', 1000, t0)],
        ),
        sale('c', 1500, t0, person: 'p2'),
        sale('d', 9000, t0, person: null),
        sale('e', 9000, t0, person: 'p2', deleted: true),
      ];
      expect(owedBy(sales.where((s) => s.personId == 'p1')), 4000);
      expect(totalOwed(sales), 5500);
      final now = DateTime(2026, 11, 7, 8);
      expect(
        daysSinceOldestUnpaid(sales.where((s) => s.personId == 'p1'), now),
        5,
      );
      expect(
        daysSinceOldestUnpaid([
          sale('z', 1, t0, payments: [pay('q', 1, t0)]),
        ], now),
        isNull,
      );
    });

    test('jours calendaires : hier 23 h 59 = 1 jour', () {
      expect(
        calendarDaysBetween(
          DateTime(2026, 11, 3, 23, 59),
          DateTime(2026, 11, 4, 0, 1),
        ),
        1,
      );
    });
  });

  group('périodes', () {
    test('autour de minuit', () {
      final day = dayOf(DateTime(2026, 11, 4, 0, 0));
      expect(day.contains(DateTime(2026, 11, 3, 23, 59, 59)), isFalse);
      expect(day.contains(DateTime(2026, 11, 4)), isTrue);
      expect(day.contains(DateTime(2026, 11, 4, 23, 59, 59)), isTrue);
      expect(day.contains(DateTime(2026, 11, 5)), isFalse);
    });

    test('semaine du lundi 0 h au dimanche', () {
      final sunday = DateTime(2026, 11, 8, 22);
      final w = weekOf(sunday);
      expect(w.start, DateTime(2026, 11, 2));
      expect(w.end, DateTime(2026, 11, 9));
      expect(weekOf(DateTime(2026, 11, 9)).start, DateTime(2026, 11, 9));
      expect(w.contains(DateTime(2026, 11, 1, 23, 59)), isFalse);
      expect(w.contains(DateTime(2026, 11, 9)), isFalse);
    });

    test('vendu et reçu de la période', () {
      final today = dayOf(DateTime(2026, 11, 4, 12));
      final sales = [
        sale(
          'a',
          5000,
          DateTime(2026, 11, 3, 23, 50),
          payments: [pay('x', 2000, DateTime(2026, 11, 4, 0, 10))],
        ),
        sale(
          'b',
          3000,
          DateTime(2026, 11, 4, 9),
          payments: [pay('y', 3000, DateTime(2026, 11, 4, 9))],
        ),
        sale('c', 7000, DateTime(2026, 11, 4, 10), deleted: true),
      ];
      expect(soldIn(sales, today), 3000);
      expect(receivedIn(sales, today), 5000);
    });
  });

  group('il en reste', () {
    test('étiquettes', () {
      expect(stockLabel(null), isNull);
      expect(stockLabel(5), 'Il en reste 5');
      expect(stockLabel(2), 'Plus que 2');
      expect(stockLabel(1), 'Plus que 1');
      expect(stockLabel(0), 'Épuisé');
      expect(stockLabel(-3), 'Épuisé');
    });
  });

  test('articles les plus vendus sur 30 jours', () {
    final now = DateTime(2026, 11, 30);
    final top = topArticles([
      SoldQuantity('riz', 2, DateTime(2026, 11, 20)),
      SoldQuantity('huile', 5, DateTime(2026, 11, 25)),
      SoldQuantity('riz', 4, DateTime(2026, 11, 28)),
      SoldQuantity('sucre', 50, DateTime(2026, 10, 1)),
    ], now);
    expect(top.map((e) => '${e.key}:${e.value}'), ['riz:6', 'huile:5']);
  });

  test('mois et périodes précédentes', () {
    final m = monthOf(DateTime(2026, 1, 15, 8));
    expect(m.start, DateTime(2026, 1, 1));
    expect(m.end, DateTime(2026, 2, 1));
    expect(previousMonth(m).start, DateTime(2025, 12, 1));
    final w = weekOf(DateTime(2026, 11, 4));
    expect(previousWeek(w).start, DateTime(2026, 10, 26));
    expect(previousWeek(w).end, w.start);
  });
}

import 'package:drift/drift.dart';

import '../domain/ledger.dart';
import '../domain/ledger.dart' as ledger_rules show received;
import '../format/fcfa.dart';
import 'database.dart';
import 'ledger_repository.dart';

/// Une ligne de vente prête à afficher.
class SaleItem {
  const SaleItem({
    required this.line,
    required this.title,
    this.personName,
    this.photoPath,
  });

  final SaleLine line;
  final String title;
  final String? personName;
  final String? photoPath;

  String get id => line.id;
  int get amount => line.amount;
  DateTime get soldAt => line.soldAt;
  int get rest => remaining(line);
  SaleStatus get status => statusOf(line);
}

class DaySummary {
  const DaySummary({
    required this.period,
    required this.sold,
    required this.received,
    required this.owed,
    required this.sales,
  });

  final Period period;
  final int sold;
  final int received;
  final int owed;
  final List<SaleItem> sales;
}

/// Lectures composées pour les écrans.
extension LedgerQueries on LedgerRepository {
  Future<List<SaleItem>> saleItems(List<SaleLine> lines) async {
    if (lines.isEmpty) return const [];
    final personIds = lines.map((l) => l.personId).nonNulls.toSet();
    final people = personIds.isEmpty
        ? <String, Person>{}
        : {
            for (final p in await (db.select(
              db.people,
            )..where((p) => p.id.isIn(personIds))).get())
              p.id: p,
          };
    final saleIds = lines.map((l) => l.id).toList();
    final articleRows = await (db.select(db.saleArticles).join([
      innerJoin(
        db.articles,
        db.articles.id.equalsExp(db.saleArticles.articleId),
      ),
    ])..where(db.saleArticles.saleId.isIn(saleIds))).get();
    final articlesBySale = <String, List<Article>>{};
    for (final row in articleRows) {
      articlesBySale
          .putIfAbsent(row.readTable(db.saleArticles).saleId, () => [])
          .add(row.readTable(db.articles));
    }
    final photos = {
      for (final s in await (db.select(
        db.sales,
      )..where((s) => s.id.isIn(saleIds))).get())
        s.id: s.photoPath,
    };
    return [
      for (final l in lines)
        () {
          final person = people[l.personId];
          final arts = articlesBySale[l.id] ?? const [];
          final firstNamed = arts.where((a) => a.name != null).firstOrNull;
          return SaleItem(
            line: l,
            personName: person?.name,
            title: person?.name ?? firstNamed?.name ?? 'Vente',
            photoPath:
                photos[l.id] ??
                arts.map((a) => a.photoPath).nonNulls.firstOrNull,
          );
        }(),
    ];
  }

  /// Aujourd'hui (ou un autre jour) : vendu, reçu, ce qu'on vous doit sur les ventes du jour.
  Future<DaySummary> daySummary(DateTime day) async {
    final period = dayOf(day);
    final daySales =
        await (db.select(db.sales)
              ..where(
                (s) =>
                    s.deletedAt.isNull() &
                    s.soldAt.isBiggerOrEqualValue(period.start) &
                    s.soldAt.isSmallerThanValue(period.end),
              )
              ..orderBy([(s) => OrderingTerm.desc(s.soldAt)]))
            .get();
    final lines = [
      ...await saleLines(saleIds: daySales.map((s) => s.id).toList()),
    ];
    final order = {for (var i = 0; i < daySales.length; i++) daySales[i].id: i};
    lines.sort((a, b) => order[a.id]!.compareTo(order[b.id]!));
    return DaySummary(
      period: period,
      sold: soldIn(lines, period),
      received: await receivedBetween(period),
      owed: owedBy(lines),
      sales: await saleItems(lines),
    );
  }

  /// Reçu (période) : tous les paiements de la période, quelle que soit la date de la vente.
  Future<int> receivedBetween(Period period) async {
    final row = await db
        .customSelect(
          'SELECT COALESCE(SUM(p.amount), 0) AS total FROM payments p '
          'JOIN sales s ON s.id = p.sale_id '
          'WHERE p.deleted_at IS NULL AND s.deleted_at IS NULL '
          'AND p.paid_at >= ? AND p.paid_at < ?',
          variables: [
            Variable.withDateTime(period.start),
            Variable.withDateTime(period.end),
          ],
          readsFrom: {db.payments, db.sales},
        )
        .getSingle();
    return row.read<int>('total');
  }
}

extension SellQueries on LedgerRepository {
  /// Articles visibles, les plus vendus (30 jours) d'abord, puis les plus récents.
  Future<List<Article>> articlesForSale() async {
    final all =
        await (db.select(db.articles)
              ..where((a) => a.deletedAt.isNull() & a.hidden.equals(false))
              ..orderBy([(a) => OrderingTerm.desc(a.createdAt)]))
            .get();
    final rank = {
      for (final (i, e) in topArticles(await soldQuantities(), now).indexed)
        e.key: i,
    };
    final big = rank.length + 1;
    final indexed = all.indexed.toList()
      ..sort((x, y) {
        final c = (rank[x.$2.id] ?? big).compareTo(rank[y.$2.id] ?? big);
        return c != 0 ? c : x.$1.compareTo(y.$1);
      });
    return [for (final (_, a) in indexed) a];
  }

  /// Noms déjà utilisés, du plus récent au plus ancien.
  Future<List<Person>> recentPeople({int limit = 30}) async {
    final rows = await db
        .customSelect(
          'SELECT p.id FROM people p LEFT JOIN sales s ON s.person_id = p.id AND s.deleted_at IS NULL '
          'WHERE p.deleted_at IS NULL GROUP BY p.id '
          'ORDER BY MAX(COALESCE(s.sold_at, p.created_at)) DESC LIMIT ?',
          variables: [Variable.withInt(limit)],
          readsFrom: {db.people, db.sales},
        )
        .get();
    final ids = rows.map((r) => r.read<String>('id')).toList();
    if (ids.isEmpty) return const [];
    final people = {
      for (final p in await (db.select(
        db.people,
      )..where((p) => p.id.isIn(ids))).get())
        p.id: p,
    };
    return [for (final id in ids) ?people[id]];
  }

  /// Une photo encore utilisée par une vente ou un article ?
  Future<bool> photoInUse(String path) async {
    final row = await db
        .customSelect(
          'SELECT (SELECT COUNT(*) FROM sales WHERE photo_path = ?1 AND deleted_at IS NULL) + '
          '(SELECT COUNT(*) FROM articles WHERE photo_path = ?1 AND deleted_at IS NULL) AS n',
          variables: [Variable.withString(path)],
          readsFrom: {db.sales, db.articles},
        )
        .getSingle();
    return row.read<int>('n') > 0;
  }
}

class SoldLine {
  const SoldLine(this.article, this.quantity);
  final Article article;
  final int quantity;

  String get label => '${article.name ?? formatFcfa(article.price)} ×$quantity';
}

class SaleDetail {
  const SaleDetail({
    required this.sale,
    required this.line,
    required this.person,
    required this.articles,
    required this.payments,
  });

  final Sale sale;
  final SaleLine line;
  final Person? person;
  final List<SoldLine> articles;

  /// Paiements non supprimés, du plus ancien au plus récent.
  final List<Payment> payments;

  int get received => ledger_rules.received(line);
  int get rest => remaining(line);
  SaleStatus get status => statusOf(line);
  List<String> get photos => [
    ?sale.photoPath,
    for (final a in articles) ?a.article.photoPath,
  ];
}

extension DetailQueries on LedgerRepository {
  Future<SaleDetail?> saleDetail(String saleId) async {
    final sale = await (db.select(
      db.sales,
    )..where((s) => s.id.equals(saleId))).getSingleOrNull();
    if (sale == null) return null;
    final person = sale.personId == null
        ? null
        : await (db.select(
            db.people,
          )..where((p) => p.id.equals(sale.personId!))).getSingleOrNull();
    final rows = await (db.select(db.saleArticles).join([
      innerJoin(
        db.articles,
        db.articles.id.equalsExp(db.saleArticles.articleId),
      ),
    ])..where(db.saleArticles.saleId.equals(saleId))).get();
    final payments =
        await (db.select(db.payments)
              ..where((p) => p.saleId.equals(saleId) & p.deletedAt.isNull())
              ..orderBy([
                (p) => OrderingTerm.asc(p.paidAt),
                (p) => OrderingTerm.asc(p.createdAt),
              ]))
            .get();
    return SaleDetail(
      sale: sale,
      line: await saleLine(saleId),
      person: person,
      articles: [
        for (final r in rows)
          SoldLine(
            r.readTable(db.articles),
            r.readTable(db.saleArticles).quantity,
          ),
      ],
      payments: payments,
    );
  }
}

class PersonDebt {
  const PersonDebt({
    required this.person,
    required this.owed,
    required this.days,
    this.unpaid = const [],
  });
  final Person person;
  final int owed;

  /// "depuis N jours" (null si plus rien n'est dû).
  final int? days;

  /// Ventes avec un reste, de la plus ancienne à la plus récente.
  final List<SaleItem> unpaid;
}

class DebtsSummary {
  const DebtsSummary(this.total, this.people);
  final int total;
  final List<PersonDebt> people;
}

extension DebtQueries on LedgerRepository {
  /// On me doit : personnes qui doivent, du plus gros montant au plus petit.
  Future<DebtsSummary> debts() async {
    final lines = (await saleLines()).where((l) => l.personId != null).toList();
    final byPerson = <String, List<SaleLine>>{};
    for (final l in lines) {
      byPerson.putIfAbsent(l.personId!, () => []).add(l);
    }
    final people = {
      for (final p in await (db.select(
        db.people,
      )..where((p) => p.id.isIn(byPerson.keys))).get())
        p.id: p,
    };
    final list = <PersonDebt>[];
    for (final e in byPerson.entries) {
      final owed = owedBy(e.value);
      final person = people[e.key];
      if (owed <= 0 || person == null) continue;
      list.add(
        PersonDebt(
          person: person,
          owed: owed,
          days: daysSinceOldestUnpaid(e.value, now),
        ),
      );
    }
    list.sort((a, b) => b.owed.compareTo(a.owed));
    return DebtsSummary(totalOwed(lines), list);
  }

  Future<PersonDebt?> personDebt(String personId) async {
    final person = await (db.select(
      db.people,
    )..where((p) => p.id.equals(personId))).getSingleOrNull();
    if (person == null) return null;
    final lines = await saleLines(personId: personId);
    final open = lines.where((l) => remaining(l) > 0).toList()
      ..sort((a, b) => a.soldAt.compareTo(b.soldAt));
    return PersonDebt(
      person: person,
      owed: owedBy(lines),
      days: daysSinceOldestUnpaid(lines, now),
      unpaid: await saleItems(open),
    );
  }
}

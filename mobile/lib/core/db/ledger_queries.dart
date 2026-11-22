import 'package:drift/drift.dart';

import '../domain/ledger.dart';
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

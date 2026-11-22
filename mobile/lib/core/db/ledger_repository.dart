import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../domain/ledger.dart';
import 'database.dart';

const _uuid = Uuid();
String newId() => _uuid.v4();

enum PayMethod {
  cash('cash', 'Espèces'),
  orangeMoney('orange_money', 'Orange Money'),
  momo('momo', 'MoMo');

  const PayMethod(this.code, this.label);
  final String code;
  final String label;

  static PayMethod fromCode(String code) =>
      values.firstWhere((m) => m.code == code, orElse: () => cash);
}

class SoldArticle {
  const SoldArticle(this.articleId, this.quantity);
  final String articleId;
  final int quantity;
}

/// Accès au cahier. Toutes les écritures passent par ici (transactions, "il en reste", restes).
class LedgerRepository {
  LedgerRepository(this.db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase db;
  final DateTime Function() _clock;

  DateTime get now => _clock();

  // ---------- Personnes ----------

  Future<String> addPerson(String name, {String? phone}) async {
    final id = newId();
    final t = now;
    await db
        .into(db.people)
        .insert(
          PeopleCompanion.insert(
            id: id,
            name: name.trim(),
            phone: Value(phone),
            createdAt: t,
            updatedAt: t,
          ),
        );
    return id;
  }

  Future<void> updatePerson(String id, {String? name, String? phone}) async {
    await (db.update(db.people)..where((p) => p.id.equals(id))).write(
      PeopleCompanion(
        name: name == null ? const Value.absent() : Value(name.trim()),
        phone: phone == null ? const Value.absent() : Value(phone),
        updatedAt: Value(now),
      ),
    );
  }

  /// Personne existante avec ce nom (sans tenir compte des majuscules), sinon nouvelle.
  Future<String> personByName(String name) async {
    final wanted = name.trim().toLowerCase();
    final all = await (db.select(
      db.people,
    )..where((p) => p.deletedAt.isNull())).get();
    for (final p in all) {
      if (p.name.toLowerCase() == wanted) return p.id;
    }
    return addPerson(name);
  }

  // ---------- Articles ----------

  Future<String> addArticle({
    String? name,
    required int price,
    int? remaining,
    String? photoPath,
  }) async {
    final id = newId();
    final t = now;
    await db
        .into(db.articles)
        .insert(
          ArticlesCompanion.insert(
            id: id,
            name: Value(name?.trim().isEmpty ?? true ? null : name!.trim()),
            price: price,
            remaining: Value(remaining),
            photoPath: Value(photoPath),
            createdAt: t,
            updatedAt: t,
          ),
        );
    return id;
  }

  Future<void> updateArticle(String id, ArticlesCompanion changes) async {
    await (db.update(db.articles)..where((a) => a.id.equals(id))).write(
      changes.copyWith(updatedAt: Value(now)),
    );
  }

  Future<void> _shiftRemaining(String articleId, int delta) async {
    await db.customUpdate(
      'UPDATE articles SET remaining = remaining + ?, updated_at = ? '
      'WHERE id = ? AND remaining IS NOT NULL',
      variables: [
        Variable.withInt(delta),
        Variable.withDateTime(now),
        Variable.withString(articleId),
      ],
      updates: {db.articles},
    );
  }

  // ---------- Ventes ----------

  /// Enregistre une vente. [paidNow] : montant reçu tout de suite (null = rien).
  Future<String> addSale({
    required int amount,
    String? personId,
    List<SoldArticle> articles = const [],
    int? paidNow,
    PayMethod method = PayMethod.cash,
    DateTime? soldAt,
    String? photoPath,
  }) {
    if (amount <= 0) throw ArgumentError.value(amount, 'amount');
    return db.transaction(() async {
      final id = newId();
      final t = now;
      final at = soldAt ?? t;
      await db
          .into(db.sales)
          .insert(
            SalesCompanion.insert(
              id: id,
              amount: amount,
              personId: Value(personId),
              soldAt: at,
              photoPath: Value(photoPath),
              createdAt: t,
              updatedAt: t,
            ),
          );
      for (final a in articles) {
        await db
            .into(db.saleArticles)
            .insert(
              SaleArticlesCompanion.insert(
                id: newId(),
                saleId: id,
                articleId: a.articleId,
                quantity: a.quantity,
              ),
            );
        await _shiftRemaining(a.articleId, -a.quantity);
      }
      final paid = paidNow == null ? 0 : (paidNow > amount ? amount : paidNow);
      if (paid > 0) await _insertPayment(id, paid, method, at);
      return id;
    });
  }

  Future<void> _insertPayment(
    String saleId,
    int amount,
    PayMethod method,
    DateTime paidAt,
  ) async {
    final t = now;
    await db
        .into(db.payments)
        .insert(
          PaymentsCompanion.insert(
            id: newId(),
            saleId: saleId,
            amount: amount,
            method: method.code,
            paidAt: paidAt,
            createdAt: t,
            updatedAt: t,
          ),
        );
  }

  /// Supprime une vente (et ses paiements) ; "il en reste" est rétabli.
  Future<void> deleteSale(String saleId) => db.transaction(() async {
    final t = now;
    final sale = await (db.select(
      db.sales,
    )..where((s) => s.id.equals(saleId))).getSingleOrNull();
    if (sale == null || sale.deletedAt != null) return;
    for (final line in await _linesOf(saleId)) {
      await _shiftRemaining(line.articleId, line.quantity);
    }
    await (db.update(db.sales)..where((s) => s.id.equals(saleId))).write(
      SalesCompanion(deletedAt: Value(t), updatedAt: Value(t)),
    );
    await (db.update(db.payments)
          ..where((p) => p.saleId.equals(saleId) & p.deletedAt.isNull()))
        .write(PaymentsCompanion(deletedAt: Value(t), updatedAt: Value(t)));
  });

  Future<List<SaleArticle>> _linesOf(String saleId) =>
      (db.select(db.saleArticles)..where((l) => l.saleId.equals(saleId))).get();

  /// Modifie une vente. Montant plus petit que le reçu : le dernier paiement est réduit.
  Future<void> updateSale(
    String saleId, {
    int? amount,
    Value<String?> personId = const Value.absent(),
    List<SoldArticle>? articles,
    DateTime? soldAt,
  }) => db.transaction(() async {
    final t = now;
    if (amount != null) {
      if (amount <= 0) throw ArgumentError.value(amount, 'amount');
      final line = await saleLine(saleId);
      for (final change in paymentsForNewAmount(line, amount)) {
        await (db.update(
          db.payments,
        )..where((p) => p.id.equals(change.paymentId))).write(
          change.newAmount == 0
              ? PaymentsCompanion(deletedAt: Value(t), updatedAt: Value(t))
              : PaymentsCompanion(
                  amount: Value(change.newAmount),
                  updatedAt: Value(t),
                ),
        );
      }
    }
    if (articles != null) {
      for (final old in await _linesOf(saleId)) {
        await _shiftRemaining(old.articleId, old.quantity);
      }
      await (db.delete(
        db.saleArticles,
      )..where((l) => l.saleId.equals(saleId))).go();
      for (final a in articles) {
        await db
            .into(db.saleArticles)
            .insert(
              SaleArticlesCompanion.insert(
                id: newId(),
                saleId: saleId,
                articleId: a.articleId,
                quantity: a.quantity,
              ),
            );
        await _shiftRemaining(a.articleId, -a.quantity);
      }
    }
    await (db.update(db.sales)..where((s) => s.id.equals(saleId))).write(
      SalesCompanion(
        amount: amount == null ? const Value.absent() : Value(amount),
        personId: personId,
        soldAt: soldAt == null ? const Value.absent() : Value(soldAt),
        updatedAt: Value(t),
      ),
    );
  });

  /// Paiement sur une vente, plafonné au reste. Renvoie le montant enregistré.
  Future<int> addPayment(
    String saleId,
    int amount, {
    PayMethod method = PayMethod.cash,
  }) => db.transaction(() async {
    final part = cappedPayment(await saleLine(saleId), amount);
    if (part > 0) await _insertPayment(saleId, part, method, now);
    return part;
  });

  Future<void> deletePayment(String paymentId) async {
    final t = now;
    await (db.update(db.payments)..where((p) => p.id.equals(paymentId))).write(
      PaymentsCompanion(deletedAt: Value(t), updatedAt: Value(t)),
    );
  }

  /// "{Nom} a payé X" : réparti de la plus ancienne vente à la plus récente.
  Future<AllocationResult> personPaid(
    String personId,
    int amount, {
    PayMethod method = PayMethod.cash,
  }) => db.transaction(() async {
    final sales = await saleLines(personId: personId);
    final result = allocatePersonPayment(sales, amount);
    for (final a in result.allocations) {
      await _insertPayment(a.saleId, a.amount, method, now);
    }
    return result;
  });

  // ---------- Lecture ----------

  Future<SaleLine> saleLine(String saleId) async {
    final lines = await saleLines(saleIds: [saleId], includeDeleted: true);
    return lines.single;
  }

  /// Ventes avec leurs paiements, prêtes pour les règles de calcul.
  Future<List<SaleLine>> saleLines({
    String? personId,
    List<String>? saleIds,
    bool includeDeleted = false,
  }) async {
    final q = db.select(db.sales);
    q.where((s) {
      Expression<bool> e = const Constant(true);
      if (!includeDeleted) e = e & s.deletedAt.isNull();
      if (personId != null) e = e & s.personId.equals(personId);
      if (saleIds != null) e = e & s.id.isIn(saleIds);
      return e;
    });
    final sales = await q.get();
    if (sales.isEmpty) return const [];
    final pays = await (db.select(
      db.payments,
    )..where((p) => p.saleId.isIn(sales.map((s) => s.id)))).get();
    final bySale = <String, List<PaymentLine>>{};
    for (final p in pays) {
      bySale
          .putIfAbsent(p.saleId, () => [])
          .add(
            PaymentLine(
              id: p.id,
              amount: p.amount,
              paidAt: p.paidAt,
              deleted: p.deletedAt != null,
            ),
          );
    }
    return [
      for (final s in sales)
        SaleLine(
          id: s.id,
          amount: s.amount,
          soldAt: s.soldAt,
          personId: s.personId,
          payments: bySale[s.id] ?? const [],
          deleted: s.deletedAt != null,
        ),
    ];
  }

  Future<Article?> article(String id) =>
      (db.select(db.articles)..where((a) => a.id.equals(id))).getSingleOrNull();

  Future<List<SoldQuantity>> soldQuantities() async {
    final rows = await db
        .customSelect(
          'SELECT sa.article_id, sa.quantity, s.sold_at FROM sale_articles sa '
          'JOIN sales s ON s.id = sa.sale_id WHERE s.deleted_at IS NULL',
          readsFrom: {db.saleArticles, db.sales},
        )
        .get();
    return [
      for (final r in rows)
        SoldQuantity(
          r.read<String>('article_id'),
          r.read<int>('quantity'),
          r.read<DateTime>('sold_at'),
        ),
    ];
  }
}

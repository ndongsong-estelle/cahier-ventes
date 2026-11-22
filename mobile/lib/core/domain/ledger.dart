/// Règles de calcul du cahier (docs/02). Fonctions pures, sans base de données.
/// Ce qu'on vous doit est toujours recalculé depuis les ventes et les paiements, jamais stocké.
library;

class PaymentLine {
  const PaymentLine({
    required this.id,
    required this.amount,
    required this.paidAt,
    this.deleted = false,
  });

  final String id;
  final int amount;
  final DateTime paidAt;
  final bool deleted;
}

class SaleLine {
  const SaleLine({
    required this.id,
    required this.amount,
    required this.soldAt,
    this.personId,
    this.payments = const [],
    this.deleted = false,
  });

  final String id;
  final int amount;
  final DateTime soldAt;
  final String? personId;
  final List<PaymentLine> payments;
  final bool deleted;
}

/// reçu(vente) = somme des paiements non supprimés.
int received(SaleLine sale) =>
    sale.payments.where((p) => !p.deleted).fold(0, (sum, p) => sum + p.amount);

/// reste(vente) = max(0, montant − reçu).
int remaining(SaleLine sale) {
  final rest = sale.amount - received(sale);
  return rest > 0 ? rest : 0;
}

enum SaleStatus { paid, partial, unpaid }

SaleStatus statusOf(SaleLine sale) {
  final got = received(sale);
  if (got >= sale.amount) return SaleStatus.paid;
  if (got > 0) return SaleStatus.partial;
  return SaleStatus.unpaid;
}

/// Montant accepté pour un paiement sur une vente : jamais plus que le reste.
int cappedPayment(SaleLine sale, int amount) {
  final rest = remaining(sale);
  return amount < rest ? amount : rest;
}

class Allocation {
  const Allocation(this.saleId, this.amount);
  final String saleId;
  final int amount;

  @override
  bool operator ==(Object other) =>
      other is Allocation && other.saleId == saleId && other.amount == amount;

  @override
  int get hashCode => Object.hash(saleId, amount);

  @override
  String toString() => 'Allocation($saleId, $amount)';
}

class AllocationResult {
  const AllocationResult(this.allocations, this.leftover);
  final List<Allocation> allocations;

  /// Partie du montant qui dépasse ce qui est dû (non enregistrée).
  final int leftover;
}

/// "{Nom} a payé X" : réparti sur ses ventes avec reste > 0, de la plus ancienne à la plus récente.
AllocationResult allocatePersonPayment(List<SaleLine> sales, int amount) {
  final open = sales.where((s) => !s.deleted && remaining(s) > 0).toList()
    ..sort((a, b) => a.soldAt.compareTo(b.soldAt));
  var left = amount;
  final result = <Allocation>[];
  for (final sale in open) {
    if (left <= 0) break;
    final part = cappedPayment(sale, left);
    result.add(Allocation(sale.id, part));
    left -= part;
  }
  return AllocationResult(result, left > 0 ? left : 0);
}

/// Changement à appliquer à un paiement après modification du montant d'une vente.
class PaymentChange {
  const PaymentChange(this.paymentId, this.newAmount);
  final String paymentId;

  /// 0 = le paiement est supprimé.
  final int newAmount;

  @override
  bool operator ==(Object other) =>
      other is PaymentChange &&
      other.paymentId == paymentId &&
      other.newAmount == newAmount;

  @override
  int get hashCode => Object.hash(paymentId, newAmount);

  @override
  String toString() => 'PaymentChange($paymentId, $newAmount)';
}

/// Modifier le montant : si le reçu dépasse le nouveau montant, réduire le dernier paiement
/// (puis le précédent si cela ne suffit pas).
List<PaymentChange> paymentsForNewAmount(SaleLine sale, int newAmount) {
  var excess = received(sale) - newAmount;
  if (excess <= 0) return const [];
  final live = sale.payments.where((p) => !p.deleted).toList()
    ..sort((a, b) => a.paidAt.compareTo(b.paidAt));
  final changes = <PaymentChange>[];
  for (final p in live.reversed) {
    if (excess <= 0) break;
    final cut = p.amount < excess ? p.amount : excess;
    changes.add(PaymentChange(p.id, p.amount - cut));
    excess -= cut;
  }
  return changes;
}

/// On vous doit (personne) = somme de ses restes.
int owedBy(Iterable<SaleLine> sales) =>
    sales.where((s) => !s.deleted).fold(0, (sum, s) => sum + remaining(s));

/// Total : somme sur toutes les personnes (seules les ventes avec une personne comptent).
int totalOwed(Iterable<SaleLine> sales) =>
    owedBy(sales.where((s) => s.personId != null));

/// "depuis N jours" = jours (calendaires, heure locale) depuis sa plus ancienne vente non soldée.
int? daysSinceOldestUnpaid(Iterable<SaleLine> sales, DateTime now) {
  DateTime? oldest;
  for (final s in sales) {
    if (s.deleted || remaining(s) == 0) continue;
    if (oldest == null || s.soldAt.isBefore(oldest)) oldest = s.soldAt;
  }
  if (oldest == null) return null;
  return calendarDaysBetween(oldest, now);
}

int calendarDaysBetween(DateTime from, DateTime to) {
  final a = from.toLocal();
  final b = to.toLocal();
  // Date.UTC évite les décalages d'heure d'été.
  final da = DateTime.utc(a.year, a.month, a.day);
  final db = DateTime.utc(b.year, b.month, b.day);
  return db.difference(da).inDays;
}

/// Période [start, end[ en heure locale du téléphone.
class Period {
  const Period(this.start, this.end);
  final DateTime start;
  final DateTime end;

  bool contains(DateTime t) {
    final l = t.toLocal();
    return !l.isBefore(start) && l.isBefore(end);
  }
}

Period dayOf(DateTime now) {
  final l = now.toLocal();
  final start = DateTime(l.year, l.month, l.day);
  return Period(start, DateTime(l.year, l.month, l.day + 1));
}

/// Semaine = lundi 0 h à lundi suivant 0 h, heure locale.
Period weekOf(DateTime now) {
  final l = now.toLocal();
  final monday = DateTime(
    l.year,
    l.month,
    l.day - (l.weekday - DateTime.monday),
  );
  return Period(monday, DateTime(monday.year, monday.month, monday.day + 7));
}

/// Vendu (période) = somme des montants des ventes de la période.
int soldIn(Iterable<SaleLine> sales, Period period) => sales
    .where((s) => !s.deleted && period.contains(s.soldAt))
    .fold(0, (sum, s) => sum + s.amount);

/// Reçu (période) = somme des paiements de la période (ventes non supprimées).
int receivedIn(Iterable<SaleLine> sales, Period period) {
  var total = 0;
  for (final s in sales) {
    if (s.deleted) continue;
    for (final p in s.payments) {
      if (!p.deleted && period.contains(p.paidAt)) total += p.amount;
    }
  }
  return total;
}

/// Étiquette "Il en reste" : null si l'article n'est pas compté.
enum StockLevel { untracked, plenty, low, out }

StockLevel stockLevel(int? remaining) {
  if (remaining == null) return StockLevel.untracked;
  if (remaining <= 0) return StockLevel.out;
  if (remaining <= 2) return StockLevel.low;
  return StockLevel.plenty;
}

String? stockLabel(int? remaining) => switch (stockLevel(remaining)) {
  StockLevel.untracked => null,
  StockLevel.out => 'Épuisé',
  StockLevel.low => 'Plus que $remaining',
  StockLevel.plenty => 'Il en reste $remaining',
};

class SoldQuantity {
  const SoldQuantity(this.articleId, this.quantity, this.soldAt);
  final String articleId;
  final int quantity;
  final DateTime soldAt;
}

/// Articles les plus vendus = somme des quantités sur 30 jours, du plus vendu au moins vendu.
List<MapEntry<String, int>> topArticles(
  Iterable<SoldQuantity> lines,
  DateTime now, {
  int days = 30,
}) {
  final since = now.subtract(Duration(days: days));
  final totals = <String, int>{};
  for (final l in lines) {
    if (l.soldAt.isBefore(since) || l.soldAt.isAfter(now)) continue;
    totals[l.articleId] = (totals[l.articleId] ?? 0) + l.quantity;
  }
  return totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
}

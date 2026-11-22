import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/db/ledger_queries.dart';
import '../../core/providers.dart';

/// Articles visibles, les plus vendus d'abord.
final articlesProvider = FutureProvider.autoDispose<List<Article>>((ref) {
  ref.watch(ledgerChangesProvider);
  return ref.read(ledgerProvider).articlesForSale();
});

final articleProvider = FutureProvider.autoDispose.family<Article?, String>((
  ref,
  id,
) {
  ref.watch(ledgerChangesProvider);
  return ref.read(ledgerProvider).article(id);
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/ledger_queries.dart';
import '../../core/providers.dart';

/// Jour affiché sur Aujourd'hui (minuit local).
final shownDayProvider = NotifierProvider<ValueController<DateTime>, DateTime>(
  () {
    final n = DateTime.now();
    return ValueController(DateTime(n.year, n.month, n.day));
  },
);

final daySummaryProvider = FutureProvider.family<DaySummary, DateTime>((
  ref,
  day,
) {
  ref.watch(ledgerChangesProvider);
  return ref.read(ledgerProvider).daySummary(day);
});

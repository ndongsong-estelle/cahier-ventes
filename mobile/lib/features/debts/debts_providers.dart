import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/ledger_queries.dart';
import '../../core/providers.dart';

final debtsProvider = FutureProvider.autoDispose<DebtsSummary>((ref) {
  ref.watch(ledgerChangesProvider);
  return ref.read(ledgerProvider).debts();
});

final personDebtProvider = FutureProvider.autoDispose
    .family<PersonDebt?, String>((ref, id) {
      ref.watch(ledgerChangesProvider);
      return ref.read(ledgerProvider).personDebt(id);
    });

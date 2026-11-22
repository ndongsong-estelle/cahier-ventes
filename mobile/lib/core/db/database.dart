import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [Settings, People, Articles, Sales, SaleArticles, Payments, Outbox],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'cahier'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Vide tout le cahier (changement de compte sur ce téléphone).
  Future<void> wipe() => transaction(() async {
    for (final TableInfo table in [
      payments,
      saleArticles,
      sales,
      articles,
      people,
      outbox,
      settings,
    ]) {
      await delete(table).go();
    }
  });
}

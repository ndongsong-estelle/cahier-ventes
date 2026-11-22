// Les contraintes check() de drift se réfèrent à la colonne elle-même.
// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';

/// Clé/valeur : user_id, phone, shop_name, shop_phone, weekly_summary, pin_on_open, device_id,
/// last_backup_at, last_backup_hash, clock_offset_seconds, installed_at.
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}

@DataClassName('Person')
class People extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Articles extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().nullable()();
  IntColumn get price => integer()();
  TextColumn get photoPath => text().nullable()();
  IntColumn get remaining => integer().nullable()();
  BoolColumn get hidden => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Sales extends Table {
  TextColumn get id => text()();
  IntColumn get amount => integer().check(amount.isBiggerThanValue(0))();
  TextColumn get personId => text().nullable().references(People, #id)();
  DateTimeColumn get soldAt => dateTime()();
  TextColumn get photoPath => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class SaleArticles extends Table {
  TextColumn get id => text()();
  TextColumn get saleId => text().references(Sales, #id)();
  TextColumn get articleId => text().references(Articles, #id)();
  IntColumn get quantity => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// method : cash | orange_money | momo
class Payments extends Table {
  TextColumn get id => text()();
  TextColumn get saleId => text().references(Sales, #id)();
  IntColumn get amount => integer().check(amount.isBiggerThanValue(0))();
  TextColumn get method => text()();
  DateTimeColumn get paidAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// kind : event | answer | error
@DataClassName('OutboxItem')
class Outbox extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()();
  TextColumn get payload => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

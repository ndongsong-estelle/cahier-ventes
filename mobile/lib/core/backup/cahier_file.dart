import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import '../db/database.dart';
import '../db/settings_store.dart';

/// data.json : tables métier + shop_name, shop_phone ; sans photos, sans token.
/// Même contenu pour la copie automatique et la copie manuelle.
class CahierFile {
  CahierFile(this.json, this.counts);

  static const formatVersion = 1;

  final String json;
  final Map<String, int> counts;

  late final String sha256Hex = sha256.convert(utf8.encode(json)).toString();
  late final List<int> gz = gzip.encode(utf8.encode(json));

  static Future<CahierFile> export(AppDatabase db) async {
    final settings = SettingsStore(db);
    List<Map<String, dynamic>> rows<T extends DataClass>(
      List<T> list,
      String Function(T) id,
    ) => [
      for (final r in list..sort((a, b) => id(a).compareTo(id(b)))) r.toJson(),
    ];

    final tables = {
      'people': rows(await db.select(db.people).get(), (r) => r.id),
      'articles': rows(await db.select(db.articles).get(), (r) => r.id),
      'sales': rows(await db.select(db.sales).get(), (r) => r.id),
      'sale_articles': rows(
        await db.select(db.saleArticles).get(),
        (r) => r.id,
      ),
      'payments': rows(await db.select(db.payments).get(), (r) => r.id),
    };
    final data = {
      'format_version': formatVersion,
      'shop_name': await settings.get(SettingKey.shopName),
      'shop_phone': await settings.get(SettingKey.shopPhone),
      'tables': tables,
    };
    return CahierFile(jsonEncode(data), {
      for (final e in tables.entries) e.key: e.value.length,
    });
  }

  /// Lit un fichier gzip et vérifie son sha256. Null si abîmé.
  static CahierFile? decode(List<int> gzBytes, {String? expectedSha256}) {
    try {
      final json = utf8.decode(gzip.decode(gzBytes));
      final file = CahierFile(json, const {});
      if (expectedSha256 != null &&
          file.sha256Hex != expectedSha256.toLowerCase()) {
        return null;
      }
      return file;
    } catch (_) {
      return null;
    }
  }

  /// Remplace le cahier du téléphone par ce fichier, dans une transaction.
  Future<void> importInto(AppDatabase db) async {
    final data = jsonDecode(json) as Map<String, dynamic>;
    final version = data['format_version'] as int? ?? 0;
    if (version > formatVersion) {
      throw const FormatException(
        'Copie faite avec une version plus récente de l\'app.',
      );
    }
    final t = (data['tables'] as Map).cast<String, dynamic>();
    List<Map<String, dynamic>> list(String k) =>
        ((t[k] as List?) ?? const []).cast<Map<String, dynamic>>();
    Map<String, dynamic> photo(Map<String, dynamic> row) {
      final path = row['photoPath'] as String?;
      return path != null && !File(path).existsSync()
          ? {...row, 'photoPath': null}
          : row;
    }

    await db.transaction(() async {
      for (final TableInfo table in [
        db.payments,
        db.saleArticles,
        db.sales,
        db.articles,
        db.people,
      ]) {
        await db.delete(table).go();
      }
      await db.batch((b) {
        b.insertAll(db.people, [
          for (final r in list('people')) Person.fromJson(r),
        ]);
        b.insertAll(db.articles, [
          for (final r in list('articles')) Article.fromJson(photo(r)),
        ]);
        b.insertAll(db.sales, [
          for (final r in list('sales')) Sale.fromJson(photo(r)),
        ]);
        b.insertAll(db.saleArticles, [
          for (final r in list('sale_articles')) SaleArticle.fromJson(r),
        ]);
        b.insertAll(db.payments, [
          for (final r in list('payments')) Payment.fromJson(r),
        ]);
      });
      final settings = SettingsStore(db);
      if (data['shop_name'] != null) {
        await settings.set(SettingKey.shopName, data['shop_name'] as String);
      }
      await settings.set(SettingKey.shopPhone, data['shop_phone'] as String?);
    });
  }
}

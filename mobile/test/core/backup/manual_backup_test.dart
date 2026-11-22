import 'dart:io';

import 'package:archive/archive.dart';
import 'package:cahier_ventes/core/backup/cahier_file.dart';
import 'package:cahier_ventes/core/backup/manual_backup.dart';
import 'package:cahier_ventes/core/db/database.dart';
import 'package:cahier_ventes/core/db/ledger_repository.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test(
    'fichier .cahier : data.json + photos, remis sur un autre téléphone',
    () async {
      final dirA = await Directory.systemTemp.createTemp('a');
      final dirB = await Directory.systemTemp.createTemp('b');
      final tmp = await Directory.systemTemp.createTemp('t');
      final photo = File('${dirA.path}/robe.jpg')
        ..writeAsBytesSync([1, 2, 3, 4]);

      final a = AppDatabase(NativeDatabase.memory());
      final b = AppDatabase(NativeDatabase.memory());
      final l = LedgerRepository(a);
      final robe = await l.addArticle(
        name: 'Robe',
        price: 15000,
        photoPath: photo.path,
      );
      await l.addSale(
        amount: 15000,
        articles: [SoldArticle(robe, 1)],
        paidNow: 15000,
      );

      final path = await ManualBackup(
        a,
        photosDir: () async => dirA,
        tempDir: () async => tmp,
      ).export();
      expect(path, endsWith('.cahier'));

      await LedgerRepository(b).addSale(amount: 999); // remplacé
      await ManualBackup(
        b,
        photosDir: () async => dirB,
        tempDir: () async => tmp,
      ).import(path);

      final article = (await b.select(b.articles).get()).single;
      expect(article.photoPath, '${dirB.path}/robe.jpg');
      expect(File(article.photoPath!).readAsBytesSync(), [1, 2, 3, 4]);
      final sales = await b.select(b.sales).get();
      expect(sales.single.amount, 15000);
      await a.close();
      await b.close();
    },
  );

  test(
    'fichier invalide ou version trop récente refusé, cahier gardé',
    () async {
      final tmp = await Directory.systemTemp.createTemp('t');
      final db = AppDatabase(NativeDatabase.memory());
      await LedgerRepository(db).addSale(amount: 500);
      final m = ManualBackup(
        db,
        photosDir: () async => tmp,
        tempDir: () async => tmp,
      );

      final junk = File('${tmp.path}/x.cahier')
        ..writeAsStringSync('pas un zip');
      expect(() => m.import(junk.path), throwsFormatException);

      final future = Archive()
        ..add(
          ArchiveFile.bytes(
            'data.json',
            '{"format_version": ${CahierFile.formatVersion + 1}, "tables": {}}'
                .codeUnits,
          ),
        );
      final newer = File('${tmp.path}/y.cahier')
        ..writeAsBytesSync(ZipEncoder().encodeBytes(future));
      expect(() => m.import(newer.path), throwsFormatException);

      expect((await db.select(db.sales).get()).single.amount, 500);
      await db.close();
    },
  );
}

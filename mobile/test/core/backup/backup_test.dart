import 'dart:convert';

import 'package:cahier_ventes/core/api/api_client.dart';
import 'package:cahier_ventes/core/backup/backup_api.dart';
import 'package:cahier_ventes/core/backup/backup_service.dart';
import 'package:cahier_ventes/core/backup/cahier_file.dart';
import 'package:cahier_ventes/core/db/database.dart';
import 'package:cahier_ventes/core/db/ledger_repository.dart';
import 'package:cahier_ventes/core/db/settings_store.dart';
import 'package:cahier_ventes/core/sync/sync_runner.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';

/// Serveur de copies en mémoire, comme le vrai : vérifie le sha256 du contenu décompressé.
class MemoryBackupServer implements BackupApi {
  final copies = <(BackupMeta, List<int>)>[];
  bool enabled = true;
  DateTime Function() clock = DateTime.now;

  @override
  Future<void> upload(
    List<int> gz,
    String sha256,
    Map<String, int> counts,
  ) async {
    if (!enabled) throw ApiException(status: 403, code: 'backup_disabled');
    final check = CahierFile.decode(gz, expectedSha256: sha256);
    if (check == null) throw ApiException(status: 422, code: 'bad_sha256');
    copies.add((
      BackupMeta(id: 'b${copies.length}', createdAt: clock(), sha256: sha256),
      gz,
    ));
  }

  @override
  Future<BackupMeta?> latest() async => copies.isEmpty ? null : copies.last.$1;

  @override
  Future<List<int>> download(String id) async =>
      copies.firstWhere((c) => c.$1.id == id).$2;
}

AppDatabase memoryDb() => AppDatabase(NativeDatabase.memory());

/// Le contenu métier sans les chemins de photos (non copiées).
String withoutPhotos(String json) {
  final data = jsonDecode(json) as Map<String, dynamic>;
  for (final rows in (data['tables'] as Map).values) {
    for (final r in rows as List) {
      (r as Map).remove('photoPath');
    }
  }
  return jsonEncode(data);
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late DateTime now;
  late MemoryBackupServer server;
  late AppDatabase phoneA, phoneB;

  setUp(() {
    now = DateTime(2026, 11, 20, 9);
    server = MemoryBackupServer()..clock = () => now;
    phoneA = memoryDb();
    phoneB = memoryDb();
  });
  tearDown(() async {
    await phoneA.close();
    await phoneB.close();
  });

  Future<void> fillCahier(AppDatabase db) async {
    final l = LedgerRepository(db, clock: () => now);
    await SettingsStore(db).set(SettingKey.shopName, 'Chez Awa');
    final robe = await l.addArticle(
      name: 'Robe',
      price: 15000,
      remaining: 3,
      photoPath: '/absent/robe.jpg',
    );
    final awa = await l.addPerson('Awa', phone: '+237690000001');
    final s1 = await l.addSale(
      amount: 15000,
      articles: [SoldArticle(robe, 1)],
      paidNow: 15000,
    );
    await l.addSale(
      amount: 8000,
      personId: awa,
      paidNow: 3000,
      method: PayMethod.momo,
    );
    await l.deleteSale(s1);
    await l.addSale(
      amount: 2000,
      personId: awa,
      photoPath: '/absent/vente.jpg',
    );
  }

  test(
    'téléphone A -> serveur -> téléphone B : cahier identique (hors photos)',
    () async {
      await fillCahier(phoneA);
      final a = BackupService(phoneA, server, clock: () => now);
      expect(await a.maybeSend(), BackupOutcome.sent);

      final b = BackupService(phoneB, server, clock: () => now);
      await b.afterLogin(sameAccount: false);

      final exportA = await CahierFile.export(phoneA);
      final exportB = await CahierFile.export(phoneB);
      expect(withoutPhotos(exportB.json), withoutPhotos(exportA.json));
      expect(exportB.counts, {
        'people': 1,
        'articles': 1,
        'sales': 3,
        'sale_articles': 1,
        'payments': 2,
      });
      final sales = await phoneB.select(phoneB.sales).get();
      expect(sales.every((s) => s.photoPath == null), isTrue);
      expect(await SettingsStore(phoneB).get(SettingKey.shopName), 'Chez Awa');
    },
  );

  test(
    'copie inchangée non renvoyée, puis intervalle minimum respecté',
    () async {
      await fillCahier(phoneA);
      final a = BackupService(phoneA, server, clock: () => now);
      expect(await a.maybeSend(), BackupOutcome.sent);
      expect(await a.maybeSend(), BackupOutcome.unchanged);
      expect(server.copies, hasLength(1));

      await LedgerRepository(
        phoneA,
        clock: () => now,
      ).addSale(amount: 500, paidNow: 500);
      now = now.add(const Duration(hours: 1));
      expect(await a.maybeSend(), BackupOutcome.tooSoon);
      now = now.add(const Duration(hours: 5));
      expect(await a.maybeSend(), BackupOutcome.sent);
      expect(server.copies, hasLength(2));
    },
  );

  test('à l ouverture : intervalle plafonné à 24 h', () async {
    await SettingsStore(phoneA).set(BackupKey.minIntervalMinutes, '${48 * 60}');
    await fillCahier(phoneA);
    final a = BackupService(phoneA, server, clock: () => now);
    await a.maybeSend();
    await LedgerRepository(phoneA, clock: () => now).addSale(amount: 500);
    now = now.add(const Duration(hours: 25));
    expect(await a.maybeSend(), BackupOutcome.tooSoon);
    expect(await a.maybeSend(onOpen: true), BackupOutcome.sent);
  });

  test('backup_enabled=false (renvoyé par /config) : rien envoyé', () async {
    await fillCahier(phoneA);
    await SettingsStore(phoneA).setBool(BackupKey.enabled, false);
    final a = BackupService(phoneA, server, clock: () => now);
    expect(await a.maybeSend(), BackupOutcome.disabled);
    expect(server.copies, isEmpty);
  });

  test(
    'serveur qui refuse (403) : la copie se coupe sur le téléphone',
    () async {
      await fillCahier(phoneA);
      server.enabled = false;
      final a = BackupService(phoneA, server, clock: () => now);
      expect(await a.maybeSend(), BackupOutcome.disabled);
      expect(
        await SettingsStore(phoneA).getBool(BackupKey.enabled, fallback: true),
        isFalse,
      );
    },
  );

  test('reconnexion : cahier local plus récent envoyé, sinon copie du serveur restaurée', () async {
    await fillCahier(phoneA);
    final a = BackupService(phoneA, server, clock: () => now);
    await a.maybeSend();

    now = now.add(const Duration(minutes: 10));
    await LedgerRepository(phoneA, clock: () => now).addSale(amount: 700);
    await a.afterLogin(sameAccount: true);
    expect(server.copies, hasLength(2));

    // Copie du serveur plus récente que ce téléphone : on la restaure.
    now = now.add(const Duration(minutes: 10));
    await fillCahier(phoneB);
    await BackupService(
      phoneB,
      server,
      clock: () => now,
    ).maybeSend(force: true);
    await a.afterLogin(sameAccount: true);
    expect(
      withoutPhotos((await CahierFile.export(phoneA)).json),
      withoutPhotos((await CahierFile.export(phoneB)).json),
    );
  });

  test('copie abîmée : restauration refusée, cahier gardé', () async {
    await fillCahier(phoneA);
    final file = await CahierFile.export(phoneA);
    expect(CahierFile.decode(file.gz, expectedSha256: 'a' * 64), isNull);
    expect(CahierFile.decode([1, 2, 3]), isNull);
  });

  test('HttpBackupApi : envoi multipart et 404 sans copie', () async {
    final fake = FakeServer()
      ..on('POST /backups', (_) => (201, {'backup': {}}))
      ..on('GET /backups/latest', (_) => (404, {'code': 'no_backup'}));
    final api = HttpBackupApi(
      ApiClient(baseUrl: 'http://x/api', token: () async => 't', adapter: fake),
    );
    expect(await api.latest(), isNull);
    await fillCahier(phoneA);
    final file = await CahierFile.export(phoneA);
    await api.upload(file.gz, file.sha256Hex, file.counts);
    final form = fake.calls.last.data as FormData;
    expect(form.fields.map((f) => f.key), containsAll(['sha256', 'counts']));
    expect(form.files.single.key, 'file');
  });

  test(
    'SyncRunner : une seule opération à la fois, erreurs réseau sans effet',
    () async {
      var calls = 0;
      final runner = SyncRunner([
        ({required onOpen}) async {
          calls++;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          throw ApiException();
        },
      ]);
      await Future.wait([runner.run(), runner.run()]);
      expect(calls, 1);
    },
  );
}

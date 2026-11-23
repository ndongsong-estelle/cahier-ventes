import 'dart:convert';
import 'dart:io';

import 'package:cahier_ventes/core/api/api_client.dart';
import 'package:cahier_ventes/core/db/database.dart';
import 'package:cahier_ventes/core/telemetry/telemetry.dart';
import 'package:cahier_ventes/core/telemetry/whitelist.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('liste blanche de l app = celle de docs/02', () {
    final doc = File('../docs/02-technique.md').readAsStringSync();
    final block = RegExp(r'Liste blanche[^\n]*\n([\s\S]*?)amount_bucket :')
        .firstMatch(doc)!
        .group(1)!;
    final names = RegExp(r'([a-z_]+) \{')
        .allMatches(block)
        .map((m) => m.group(1))
        .toSet();
    expect(whitelist.keys.toSet(), names);
  });

  test('chaque événement émis dans le code est dans la liste blanche', () {
    final emitted = <String>{};
    for (final f in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart') || f.path.endsWith('.g.dart')) continue;
      final src = f.readAsStringSync();
      for (final m in RegExp(
        r"(?:trackWith\([^,]+,|\.track\()\s*'([a-z_]+)'",
      ).allMatches(src)) {
        emitted.add(m.group(1)!);
      }
    }
    expect(emitted, isNotEmpty);
    expect(emitted.difference(whitelist.keys.toSet()), isEmpty);
    // Tous les événements de la liste sont réellement émis quelque part.
    expect(whitelist.keys.toSet().difference(emitted), isEmpty);
  });

  test('props hors liste refusées, tranches de montant', () {
    expect(isAllowed('tab_viewed', {'tab': 'today'}), isTrue);
    expect(isAllowed('tab_viewed', {'tab': 'secret'}), isFalse);
    expect(isAllowed('sale_saved', {'customer': 'Awa'}), isFalse);
    expect(isAllowed('inconnu', {}), isFalse);
    expect([4999, 5000, 20000, 20001, 100000, 100001].map(amountBucket), [
      'lt5k',
      '5k_20k',
      '5k_20k',
      '20k_100k',
      '20k_100k',
      'gt100k',
    ]);
  });

  test('lots de 200, supprimés seulement après une réponse 2xx', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final t = Telemetry(db);
    for (var i = 0; i < 450; i++) {
      await t.track('app_opened');
    }
    await t.answer('aide', value: 'oui');
    final server = FakeServer()..offline = true;
    final api = ApiClient(
      baseUrl: 'http://x/api',
      token: () async => 't',
      adapter: server,
    );

    await expectLater(t.flush(api), throwsA(isA<ApiException>()));
    expect(await db.select(db.outbox).get(), hasLength(451));

    server.calls.clear();
    server
      ..offline = false
      ..on(
        'POST /events',
        (r) => (202, {'accepted': ((r.data as Map)['items'] as List).length}),
      )
      ..on('POST /answers', (_) => (202, {'accepted': 1}));
    await t.flush(api);
    expect(server.count('POST /events'), 3);
    expect(server.count('POST /answers'), 1);
    final first =
        server.calls.firstWhere((c) => c.path == '/events').data as Map;
    expect((first['items'] as List), hasLength(200));
    expect(first['sent_at'], isA<String>());
    expect(await db.select(db.outbox).get(), isEmpty);
    await db.close();
  });

  test('erreur : message et pile tronquée à 4 Ko', () async {
    final db = AppDatabase(NativeDatabase.memory());
    await Telemetry(db)
        .error(StateError('boum'), StackTrace.fromString('x' * 9000));
    final row = (await db.select(db.outbox).get()).single;
    final p = jsonDecode(row.payload) as Map;
    expect(row.kind, 'error');
    expect((p['stack'] as String).length, 4096);
    expect(p['app_version'], isNotEmpty);
    await db.close();
  });
}

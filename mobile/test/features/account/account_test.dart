import 'package:cahier_ventes/core/auth/token_store.dart';
import 'package:cahier_ventes/core/backup/cahier_file.dart';
import 'package:cahier_ventes/core/db/database.dart';
import 'package:cahier_ventes/core/db/ledger_repository.dart';
import 'package:cahier_ventes/core/format/fcfa.dart';
import 'package:drift/native.dart';
import 'package:cahier_ventes/core/providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers.dart';

Future<void> enterPhone(WidgetTester tester, TestEnv env) async {
  await tester.enterText(find.byType(TextField), '6 90 12 34 56');
  await tapText(tester, 'Continuer');
}

void main() {
  testWidgets('création du compte', (tester) async {
    final env = TestEnv();
    env.server
      ..on(
        'POST /auth/check',
        (_) => (200, {'exists': false, 'otp_required': false}),
      )
      ..on(
        'POST /auth/register',
        (_) => (201, {'token': 'abc', 'user': userJson()}),
      );
    await env.pump(tester);

    expect(find.text('Votre cahier de ventes'), findsOneWidget);
    await enterPhone(tester, env);
    expect(env.server.lastBody('POST /auth/check')['phone'], '+237690123456');
    expect(find.text('Nom de votre boutique'), findsOneWidget);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Chez Awa');
    await tester.enterText(fields.at(1), '4826');
    await tester.enterText(fields.at(2), '4826');
    await tapText(tester, 'Créer mon compte');

    expect(await env.tokens.read(SecureKey.token), 'abc');
    final body = env.server.lastBody('POST /auth/register');
    expect(body['shop_name'], 'Chez Awa');
    expect((body['device'] as Map)['id'], isNotEmpty);
    expect(find.text('Mes articles'), findsOneWidget); // onglets visibles
  });

  testWidgets('code faible refusé sans appeler le serveur', (tester) async {
    final env = TestEnv();
    env.server.on(
      'POST /auth/check',
      (_) => (200, {'exists': false, 'otp_required': false}),
    );
    await env.pump(tester);
    await enterPhone(tester, env);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Chez Awa');
    await tester.enterText(fields.at(1), '1234');
    await tester.enterText(fields.at(2), '1234');
    await tapText(tester, 'Créer mon compte');

    expect(
      find.text('Choisissez un code plus difficile à deviner.'),
      findsOneWidget,
    );
    expect(env.server.count('POST /auth/register'), 0);

    await tester.enterText(fields.at(1), '4826');
    await tester.enterText(fields.at(2), '4862');
    await tapText(tester, 'Créer mon compte');
    expect(find.text('Les deux codes ne sont pas pareils.'), findsOneWidget);
  });

  testWidgets('connexion avec le code secret, puis mauvais code', (
    tester,
  ) async {
    final env = TestEnv();
    var good = false;
    env.server
      ..on(
        'POST /auth/check',
        (_) => (200, {'exists': true, 'otp_required': false}),
      )
      ..on('POST /auth/login', (r) {
        if ((r.data as Map)['pin'] != '4826') {
          return (422, {'code': 'wrong_pin', 'message': 'x'});
        }
        good = true;
        return (
          200,
          {'token': 'tok2', 'user': userJson(), 'must_change_pin': false},
        );
      });
    await env.pump(tester);
    await enterPhone(tester, env);
    expect(find.text('Bonjour ! Tapez votre code secret'), findsOneWidget);

    for (final d in ['1', '1', '1', '2']) {
      await tester.tap(find.text(d).last);
    }
    await settle(tester);
    expect(find.text("Ce n'est pas le bon code secret."), findsOneWidget);

    for (final d in ['4', '8', '2', '6']) {
      await tester.tap(find.text(d).last);
    }
    await settle(tester);
    expect(good, isTrue);
    expect(await env.tokens.read(SecureKey.token), 'tok2');
    expect(find.text('On me doit'), findsOneWidget);
  });

  testWidgets('trop d essais : message du verrouillage', (tester) async {
    final env = TestEnv();
    env.server
      ..on(
        'POST /auth/check',
        (_) => (200, {'exists': true, 'otp_required': false}),
      )
      ..on(
        'POST /auth/login',
        (_) => (
          423,
          {
            'code': 'locked',
            'message': "Trop d'essais. Réessayez dans 15 minutes.",
          },
        ),
      );
    await env.pump(tester);
    await enterPhone(tester, env);
    for (final d in ['4', '8', '2', '6']) {
      await tester.tap(find.text(d).last);
    }
    await settle(tester);
    expect(
      find.text("Trop d'essais. Réessayez dans 15 minutes."),
      findsOneWidget,
    );
  });

  testWidgets('sans réseau : message et Réessayer', (tester) async {
    final env = TestEnv();
    env.server.offline = true;
    env.server.on(
      'POST /auth/check',
      (_) => (200, {'exists': false, 'otp_required': false}),
    );
    await env.pump(tester);
    await enterPhone(tester, env);
    expect(
      find.text(
        'Il faut internet pour ouvrir votre compte. Réessayez quand vous avez du réseau.',
      ),
      findsOneWidget,
    );
    env.server.offline = false;
    await tapText(tester, 'Réessayer');
    expect(find.text('Nom de votre boutique'), findsOneWidget);
  });

  testWidgets('401 : token effacé, cahier gardé, retour à C1 avec le message', (
    tester,
  ) async {
    final env = TestEnv();
    await env.loggedIn();
    env.server.on('GET /me', (_) => (401, {'message': 'Unauthenticated.'}));
    await env.pump(tester);
    expect(find.text("Aujourd'hui"), findsWidgets);
    final saleId = await env.container
        .read(ledgerProvider)
        .addSale(amount: 1000);

    await tester.runAsync(() async {
      try {
        await env.container.read(apiClientProvider).get('/me');
      } catch (_) {}
    });
    await settle(tester);

    expect(
      find.text('Votre compte est ouvert sur un autre téléphone.'),
      findsOneWidget,
    );
    expect(find.text('Votre cahier de ventes'), findsOneWidget);
    expect(await env.tokens.read(SecureKey.token), isNull);
    expect(
      (await env.container.read(ledgerProvider).saleLine(saleId)).amount,
      1000,
    );
  });

  testWidgets('cahier d un autre compte effacé à la connexion', (tester) async {
    final env = TestEnv();
    await env.loggedIn(userId: '9');
    await env.tokens.write(SecureKey.token, null);
    env.server
      ..on(
        'POST /auth/check',
        (_) => (200, {'exists': true, 'otp_required': false}),
      )
      ..on(
        'POST /auth/login',
        (_) => (200, {'token': 't', 'user': userJson(id: 5)}),
      );
    await env.pump(tester);
    final ledger = env.container.read(ledgerProvider);
    await tester.runAsync(() => ledger.addSale(amount: 7000));
    final deviceBefore = await tester.runAsync(
      () => env.container.read(settingsStoreProvider).get('device_id'),
    );

    await enterPhone(tester, env);
    for (final d in ['4', '8', '2', '6']) {
      await tester.tap(find.text(d).last);
    }
    await settle(tester);

    expect(await tester.runAsync(() => ledger.saleLines()), isEmpty);
    final settings = env.container.read(settingsStoreProvider);
    expect(await tester.runAsync(() => settings.get('user_id')), '5');
    expect(
      await tester.runAsync(() => settings.get('device_id')),
      deviceBefore,
    );
  });

  testWidgets('code provisoire : nouveau code demandé après connexion', (
    tester,
  ) async {
    final env = TestEnv();
    env.server
      ..on(
        'POST /auth/check',
        (_) => (200, {'exists': true, 'otp_required': false}),
      )
      ..on(
        'POST /auth/login',
        (_) =>
            (200, {'token': 't', 'user': userJson(), 'must_change_pin': true}),
      )
      ..on('POST /auth/pin', (_) => (200, {'user': userJson()}));
    await env.pump(tester);
    await enterPhone(tester, env);
    for (final d in ['5', '0', '7', '3']) {
      await tester.tap(find.text(d).last);
    }
    await settle(tester);
    expect(find.text('Choisissez un nouveau code secret'), findsOneWidget);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '4826');
    await tester.enterText(fields.at(1), '4826');
    await tapText(tester, 'Continuer');
    expect(env.server.lastBody('POST /auth/pin'), {
      'current_pin': '5073',
      'new_pin': '4826',
    });
    expect(find.text('Mes articles'), findsOneWidget);
  });

  testWidgets('après connexion : la copie du serveur est récupérée', (
    tester,
  ) async {
    final env = TestEnv();
    final other = AppDatabase(NativeDatabase.memory());
    final file = await tester.runAsync(() async {
      final l = LedgerRepository(other);
      final p = await l.addPerson('Maman Ngo');
      await l.addSale(amount: 15000, personId: p, paidNow: 5000);
      return CahierFile.export(other);
    });
    await tester.runAsync(other.close);
    env.server
      ..on(
        'POST /auth/check',
        (_) => (200, {'exists': true, 'otp_required': false}),
      )
      ..on('POST /auth/login', (_) => (200, {'token': 't', 'user': userJson()}))
      ..on(
        'GET /backups/latest',
        (_) => (
          200,
          {
            'id': 'b1',
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'sha256': file!.sha256Hex,
          },
        ),
      )
      ..on('GET /backups/b1/file', (_) => (200, file!.gz));
    await env.pump(tester);
    await enterPhone(tester, env);
    for (final d in ['4', '8', '2', '6']) {
      await tester.tap(find.text(d).last);
    }
    await settle(tester);
    expect(find.text('Maman Ngo'), findsOneWidget);
    expect(find.text(formatFcfa(15000)), findsWidgets);
  });
}

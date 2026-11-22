import 'package:cahier_ventes/core/auth/pin_lock.dart';
import 'package:cahier_ventes/core/auth/token_store.dart';
import 'package:cahier_ventes/core/db/settings_store.dart';
import 'package:cahier_ventes/core/providers.dart';
import 'package:cahier_ventes/features/settings/settings_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers.dart';

Future<TestEnv> openSettings(WidgetTester tester, {TestEnv? env}) async {
  env ??= TestEnv();
  await env.loggedIn();
  await env.pump(tester);
  await tester.tap(find.byTooltip('Réglages'));
  await settle(tester);
  return env;
}

void main() {
  test('textes de la dernière copie', () {
    final now = DateTime(2026, 11, 22, 18);
    expect(
      backupLine(lastAt: null, waiting: false, now: now),
      'Pas encore de copie',
    );
    expect(
      backupLine(lastAt: now, waiting: true, now: now),
      'En attente de réseau',
    );
    expect(
      backupLine(lastAt: DateTime(2026, 11, 22, 14), waiting: false, now: now),
      "Dernière copie de votre cahier : aujourd'hui à 14 h",
    );
    expect(whenText(DateTime(2026, 11, 21, 9, 5), now), 'hier à 9 h 05');
    expect(whenText(DateTime(2026, 11, 12, 14), now), 'le 12 novembre à 14 h');
  });

  test('code à l ouverture : hash salé, jamais le code en clair', () async {
    final store = MemoryTokenStore();
    final lock = PinLock(store);
    await lock.save('4826');
    expect(store.values.values, isNot(contains('4826')));
    expect(await lock.check('4826'), isTrue);
    expect(await lock.check('1111'), isFalse);
  });

  testWidgets('Réglages : compte, copie, bilan du dimanche', (tester) async {
    final env = await openSettings(tester);
    expect(find.text('+237690123456'), findsOneWidget);
    expect(find.text('Chez Awa'), findsOneWidget);
    await scrollTo(tester, 'Pas encore de copie');
    expect(find.text('Pas encore de copie'), findsOneWidget);
    await tapText(tester, 'Bilan du dimanche');
    expect(env.notifications.cancelled, 1);
    final s = env.container.read(settingsStoreProvider);
    expect(
      await tester.runAsync(
        () => s.getBool(SettingKey.weeklySummary, fallback: true),
      ),
      isFalse,
    );
  });

  testWidgets('Envoyer une copie partage un fichier .cahier', (tester) async {
    final env = await openSettings(tester);
    await tester.runAsync(
      () => env.container.read(ledgerProvider).addSale(amount: 1000),
    );
    await scrollTo(tester, 'Envoyer une copie');
    await tester.runAsync(() async {
      await tester.tap(find.text('Envoyer une copie'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await settle(tester);
    expect(env.sharer.files.single, endsWith('.cahier'));
  });

  testWidgets('Remettre une copie : avertissement puis remplacement', (
    tester,
  ) async {
    final env = await openSettings(tester);
    final ledger = env.container.read(ledgerProvider);
    final path = await tester.runAsync(() async {
      await ledger.addSale(amount: 4000);
      final p = await env.container.read(manualBackupProvider).export();
      await ledger.addSale(amount: 9000);
      return p;
    });
    env.picker.next = path;
    await tapText(tester, 'Remettre une copie');
    expect(find.text('Cela remplace votre cahier actuel.'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('Remettre'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await settle(tester);
    final sales = await tester.runAsync(() => ledger.saleLines());
    expect(sales!.map((s) => s.amount), [4000]);
  });

  testWidgets(
    'Demander le code à chaque ouverture : verrou à la prochaine ouverture',
    (tester) async {
      final env = await openSettings(tester);
      await tapText(tester, 'Demander le code à chaque ouverture');
      await tester.enterText(find.byType(TextField), '4826');
      await tapText(tester, 'Garder');
      expect(await env.tokens.read(SecureKey.pinHash), isNotNull);

      // Nouvelle ouverture de l'app avec le même téléphone.
      await tester.pumpWidget(const SizedBox());
      await env.pump(tester);
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
      expect(find.text('Bonjour ! Tapez votre code secret'), findsNothing);
    },
  );

  testWidgets('Se déconnecter : retour au numéro, cahier gardé', (
    tester,
  ) async {
    final env = await openSettings(tester);
    await tester.runAsync(
      () => env.container.read(ledgerProvider).addSale(amount: 1000),
    );
    env.server.on('POST /auth/logout', (_) => (200, {'ok': true}));
    await tapText(tester, 'Se déconnecter');
    await tapText(tester, 'Se déconnecter');
    expect(find.text('Votre cahier de ventes'), findsOneWidget);
    expect(await env.tokens.read(SecureKey.token), isNull);
    expect(
      await tester.runAsync(
        () => env.container.read(ledgerProvider).saleLines(),
      ),
      hasLength(1),
    );
  });

  testWidgets('Supprimer mon compte : code demandé, tout effacé', (
    tester,
  ) async {
    final env = await openSettings(tester);
    await tester.runAsync(
      () => env.container.read(ledgerProvider).addSale(amount: 1000),
    );
    env.server.on(
      'DELETE /me',
      (r) => (r.data as Map)['pin'] == '4826'
          ? (200, {'deleted': true})
          : (422, {'code': 'wrong_pin'}),
    );
    await tapText(tester, 'Supprimer mon compte');
    await tester.enterText(find.byType(TextField), '4826');
    await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
    await settle(tester);
    expect(find.text('Votre cahier de ventes'), findsOneWidget);
    expect(
      await tester.runAsync(
        () => env.container.read(ledgerProvider).saleLines(),
      ),
      isEmpty,
    );
  });

  testWidgets('Supprimer mon compte sans réseau : message', (tester) async {
    final env = await openSettings(tester);
    env.server.offline = true;
    await tapText(tester, 'Supprimer mon compte');
    await tester.enterText(find.byType(TextField), '4826');
    await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
    await settle(tester);
    expect(
      find.textContaining('Il faut internet pour supprimer votre compte'),
      findsOneWidget,
    );
  });

  testWidgets('Version touchée 7 fois : écran technique', (tester) async {
    await openSettings(tester);
    for (var i = 0; i < 7; i++) {
      await tapText(tester, 'Version 1.0.0');
    }
    expect(find.text('Technique'), findsOneWidget);
    expect(find.textContaining('10.0.2.2'), findsOneWidget);
  });
}

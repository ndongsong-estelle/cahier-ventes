import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  testWidgets("Connectée : l'app démarre sur Aujourd'hui avec trois onglets", (
    tester,
  ) async {
    final env = TestEnv();
    await env.loggedIn();
    await env.pump(tester);
    expect(find.text("Aujourd'hui"), findsWidgets);
    expect(find.text('On me doit'), findsOneWidget);
    expect(find.text('Mes articles'), findsOneWidget);

    await tester.tap(find.text('Mes articles'));
    await settle(tester);
    expect(find.text('Mes articles'), findsNWidgets(2));

    await tester.tap(find.byTooltip('Réglages'));
    await settle(tester);
    expect(find.text('Réglages'), findsOneWidget);
  });

  testWidgets('Pas connectée : écran du numéro', (tester) async {
    final env = TestEnv();
    await env.pump(tester);
    expect(find.text('Votre cahier de ventes'), findsOneWidget);
  });
}

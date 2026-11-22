import 'package:cahier_ventes/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets("L'app démarre sur Aujourd'hui avec trois onglets", (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: CahierApp()));
    await tester.pumpAndSettle();
    expect(find.text("Aujourd'hui"), findsWidgets);
    expect(find.text('On me doit'), findsOneWidget);
    expect(find.text('Mes articles'), findsOneWidget);

    await tester.tap(find.text('Mes articles'));
    await tester.pumpAndSettle();
    expect(find.text('Mes articles'), findsNWidgets(2));

    await tester.tap(find.byTooltip('Réglages'));
    await tester.pumpAndSettle();
    expect(find.text('Réglages'), findsOneWidget);
  });
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:cahier_ventes/app.dart';
import 'package:cahier_ventes/core/auth/token_store.dart';
import 'package:cahier_ventes/core/db/database.dart';
import 'package:cahier_ventes/core/providers.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show ButtonStyleButton;

typedef Handler = (int, Map<String, dynamic>) Function(RequestOptions r);

/// Faux serveur : une réponse par "METHODE /chemin".
class FakeServer implements HttpClientAdapter {
  final Map<String, Handler> routes = {};
  final List<RequestOptions> calls = [];
  bool offline = false;

  void on(String route, Handler h) => routes[route] = h;

  int count(String route) =>
      calls.where((r) => '${r.method} ${r.path}' == route).length;

  Map<String, dynamic> lastBody(String route) {
    final r = calls.lastWhere((r) => '${r.method} ${r.path}' == route);
    return Map<String, dynamic>.from(r.data as Map);
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(options);
    if (offline) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );
    }
    final key = '${options.method} ${options.path}';
    final h = routes[key];
    final (status, body) = h == null
        ? (404, {'message': 'absent'})
        : h(options);
    return ResponseBody.fromString(
      jsonEncode({
        ...body,
        'server_time': DateTime.now().toUtc().toIso8601String(),
      }),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class TestEnv {
  TestEnv() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  }

  final db = AppDatabase(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
  );
  final tokens = MemoryTokenStore();
  final server = FakeServer();

  List<Override> get overrides => [
    databaseProvider.overrideWithValue(db),
    tokenStoreProvider.overrideWithValue(tokens),
    httpAdapterProvider.overrideWithValue(server),
  ];

  late ProviderContainer container;

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container = ProviderContainer(overrides: overrides),
        child: const CahierApp(),
      ),
    );
    await settle(tester);
  }

  /// Connecte d'avance (token + user_id), comme après un premier lancement.
  Future<void> loggedIn({String userId = '1'}) async {
    await tokens.write(SecureKey.token, 'tok');
    final s = ProviderContainer(overrides: overrides)
        .read(settingsStoreProvider);
    await s.set('user_id', userId);
    await s.set('shop_name', 'Chez Awa');
    await s.set('phone', '+237690123456');
  }
}

/// pumpAndSettle avec les attentes de la base réelle.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
  }
}

Map<String, dynamic> userJson({int id = 1, String shop = 'Chez Awa'}) => {
  'id': id,
  'phone': '+237690123456',
  'shop_name': shop,
  'phone_verified': false,
};

/// Touche le dernier widget qui porte ce texte (après l'avoir fait défiler à l'écran).
Future<void> tapText(WidgetTester tester, String text) async {
  final button = find.ancestor(
    of: find.text(text),
    matching: find.bySubtype<ButtonStyleButton>(),
  );
  final f = button.evaluate().isNotEmpty ? button.first : find.text(text).last;
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await settle(tester);
}

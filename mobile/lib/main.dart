import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'core/providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();

  // Erreurs : gardées dans l'outbox et envoyées avec les statistiques.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    container
        .read(telemetryProvider)
        .error(details.exception, details.stack)
        .catchError((_) {});
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    container.read(telemetryProvider).error(error, stack).catchError((_) {});
    return true;
  };

  runApp(
    UncontrolledProviderScope(container: container, child: const CahierApp()),
  );
}

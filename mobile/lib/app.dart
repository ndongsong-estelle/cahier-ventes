import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'core/auth/session.dart';
import 'core/providers.dart';
import 'core/router/router.dart';
import 'core/theme/app_theme.dart';

class CahierApp extends ConsumerStatefulWidget {
  const CahierApp({super.key});

  @override
  ConsumerState<CahierApp> createState() => _CahierAppState();
}

class _CahierAppState extends ConsumerState<CahierApp> {
  final _refresh = ValueNotifier<int>(0);
  late final GoRouter _router = buildRouter(
    session: () => ref.read(sessionProvider),
    refresh: _refresh,
  );

  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onResume: () => ref.read(syncRunnerProvider).resumed(),
  );

  @override
  void initState() {
    super.initState();
    _lifecycle;
    Future.microtask(() {
      if (mounted && ref.read(sessionProvider).isLoggedIn) {
        ref.read(syncRunnerProvider).start();
      }
    });
  }

  Future<void> _startNotifications() async {
    try {
      await ref
          .read(weeklyNotificationProvider)
          .init(onOpenBilan: () => _router.push(Routes.bilan));
      await applyWeeklySetting(
        ref.read(settingsStoreProvider),
        ref.read(weeklyNotificationProvider),
      );
    } catch (_) {
      // Pas de notifications sur cet appareil : rien ne bloque.
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _router.dispose();
    _refresh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionProvider, (before, now) {
      _refresh.value++;
      if (now.isLoggedIn && before?.isLoggedIn != true) {
        ref.read(syncRunnerProvider).start();
        _startNotifications();
      }
      if (!now.isLoggedIn && before?.isLoggedIn == true) {
        ref.read(syncRunnerProvider).stop();
      }
    });
    return MaterialApp.router(
      title: 'Cahier de ventes',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: _router,
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
    );
  }
}

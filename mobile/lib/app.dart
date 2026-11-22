import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'core/auth/session.dart';
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

  @override
  void dispose() {
    _router.dispose();
    _refresh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionProvider, (_, _) => _refresh.value++);
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

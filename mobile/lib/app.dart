import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'core/router/router.dart';
import 'core/theme/app_theme.dart';

class CahierApp extends StatefulWidget {
  const CahierApp({super.key, this.router});

  final GoRouter? router;

  @override
  State<CahierApp> createState() => _CahierAppState();
}

class _CahierAppState extends State<CahierApp> {
  late final GoRouter _router = widget.router ?? buildRouter();

  @override
  Widget build(BuildContext context) {
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

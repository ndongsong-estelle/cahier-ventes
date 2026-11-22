import 'package:go_router/go_router.dart';

import '../../features/articles/ui/articles_screen.dart';
import '../../features/debts/ui/debts_screen.dart';
import '../../features/settings/ui/settings_screen.dart';
import '../../features/today/ui/today_screen.dart';
import 'home_shell.dart';

abstract final class Routes {
  static const today = '/';
  static const debts = '/on-me-doit';
  static const articles = '/articles';
  static const settings = '/reglages';
}

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: Routes.today,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.today,
                builder: (_, _) => const TodayScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.debts,
                builder: (_, _) => const DebtsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.articles,
                builder: (_, _) => const ArticlesScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(path: Routes.settings, builder: (_, _) => const SettingsScreen()),
    ],
  );
}

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/account/ui/create_account_screen.dart';
import '../../features/account/ui/new_pin_screen.dart';
import '../../features/account/ui/otp_screen.dart';
import '../../features/account/ui/phone_screen.dart';
import '../../features/account/ui/pin_login_screen.dart';
import '../../features/articles/ui/articles_screen.dart';
import '../../features/debts/ui/debts_screen.dart';
import '../../features/sell/ui/sell_screen.dart';
import '../../features/settings/ui/settings_screen.dart';
import '../../features/today/ui/today_screen.dart';
import '../auth/session.dart';
import 'home_shell.dart';

abstract final class Routes {
  static const loading = '/chargement';
  static const account = '/compte';
  static const accountSms = '/compte/sms';
  static const accountCreate = '/compte/creer';
  static const accountPin = '/compte/code';
  static const accountNewPin = '/compte/nouveau-code';
  static const today = '/';
  static const debts = '/on-me-doit';
  static const articles = '/articles';
  static const settings = '/reglages';
  static const sell = '/vendre';
  static const bilan = '/bilan';
  static String saleDetail(String id) => '/vente/$id';
}

GoRouter buildRouter({
  required SessionState Function() session,
  required Listenable refresh,
}) {
  return GoRouter(
    initialLocation: Routes.loading,
    refreshListenable: refresh,
    redirect: (context, state) {
      final s = session();
      final here = state.matchedLocation;
      final inAccount = here.startsWith(Routes.account);
      switch (s.status) {
        case SessionStatus.loading:
          return here == Routes.loading ? null : Routes.loading;
        case SessionStatus.loggedOut:
          return inAccount ? null : Routes.account;
        case SessionStatus.loggedIn:
          if (s.mustChangePin) {
            return here == Routes.accountNewPin ? null : Routes.accountNewPin;
          }
          return inAccount || here == Routes.loading ? Routes.today : null;
      }
    },
    routes: [
      GoRoute(path: Routes.loading, builder: (_, _) => const LoadingScreen()),
      GoRoute(
        path: Routes.account,
        builder: (_, _) => const PhoneScreen(),
        routes: [
          GoRoute(path: 'sms', builder: (_, _) => const OtpScreen()),
          GoRoute(
            path: 'creer',
            builder: (_, _) => const CreateAccountScreen(),
          ),
          GoRoute(path: 'code', builder: (_, _) => const PinLoginScreen()),
          GoRoute(
            path: 'nouveau-code',
            builder: (_, _) => const NewPinScreen(),
          ),
        ],
      ),
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
      GoRoute(path: Routes.sell, builder: (_, _) => const SellScreen()),
      GoRoute(
        path: Routes.bilan,
        builder: (_, _) => const PendingScreen(title: 'Bilan'),
      ),
      GoRoute(
        path: '/vente/:id',
        builder: (_, _) => const PendingScreen(title: 'Vente'),
      ),
    ],
  );
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key, this.message});
  final String? message;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message!, style: const TextStyle(fontSize: 20)),
          ],
        ],
      ),
    ),
  );
}

/// Écran pas encore construit (remplacé par son ticket).
class PendingScreen extends StatelessWidget {
  const PendingScreen({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: const SizedBox.shrink(),
  );
}

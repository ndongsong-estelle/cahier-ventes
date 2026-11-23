import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../providers.dart';
import '../telemetry/telemetry.dart';

/// Trois onglets en bas : Aujourd'hui · On me doit · Mes articles.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) {
          trackWith(ref.read(telemetryProvider), 'tab_viewed', {
            'tab': const ['today', 'debts', 'articles'][i],
          });
          shell.goBranch(i, initialLocation: i == shell.currentIndex);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined, size: 30),
            selectedIcon: Icon(Icons.today, size: 30),
            label: "Aujourd'hui",
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline, size: 30),
            selectedIcon: Icon(Icons.person, size: 30),
            label: 'On me doit',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined, size: 30),
            selectedIcon: Icon(Icons.inventory_2, size: 30),
            label: 'Mes articles',
          ),
        ],
      ),
    );
  }
}

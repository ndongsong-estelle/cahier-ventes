import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../router/router.dart';

/// Engrenage en haut à droite : Réglages.
class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      iconSize: 32,
      tooltip: 'Réglages',
      icon: const Icon(Icons.settings),
      onPressed: () => context.push(Routes.settings),
    );
  }
}

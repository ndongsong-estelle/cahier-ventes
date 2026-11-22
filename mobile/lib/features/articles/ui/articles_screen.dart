import 'package:material_ui/material_ui.dart';

import '../../../core/ui/settings_button.dart';

class ArticlesScreen extends StatelessWidget {
  const ArticlesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mes articles"),
        actions: const [SettingsButton()],
      ),
      body: const SizedBox.shrink(),
    );
  }
}

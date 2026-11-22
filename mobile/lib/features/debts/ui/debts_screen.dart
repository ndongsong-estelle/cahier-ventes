import 'package:material_ui/material_ui.dart';

import '../../../core/ui/settings_button.dart';

class DebtsScreen extends StatelessWidget {
  const DebtsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("On me doit"),
        actions: const [SettingsButton()],
      ),
      body: const SizedBox.shrink(),
    );
  }
}

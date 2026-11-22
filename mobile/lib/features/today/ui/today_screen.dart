import 'package:material_ui/material_ui.dart';

import '../../../core/ui/settings_button.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Aujourd'hui"),
        actions: const [SettingsButton()],
      ),
      body: const SizedBox.shrink(),
    );
  }
}

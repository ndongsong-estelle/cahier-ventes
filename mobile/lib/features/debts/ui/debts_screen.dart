import 'package:material_ui/material_ui.dart';

import '../../../core/ui/sell_button.dart';
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
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: const SellButton(),
      body: const SizedBox.shrink(),
    );
  }
}

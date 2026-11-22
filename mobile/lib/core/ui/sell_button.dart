import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../router/router.dart';
import '../theme/app_theme.dart';

/// "J'ai vendu" : gros, vert, icône +, en bas au centre.
class SellButton extends StatelessWidget {
  const SellButton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 68,
      child: FloatingActionButton.extended(
        heroTag: 'sell',
        backgroundColor: AppColors.green,
        foregroundColor: Colors.white,
        onPressed: () => context.push(Routes.sell),
        icon: const Icon(Icons.add, size: 34),
        label: const Text(
          "J'AI VENDU",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

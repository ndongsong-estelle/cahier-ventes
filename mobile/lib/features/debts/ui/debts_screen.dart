import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format/fcfa.dart';
import '../../../core/router/router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/sell_button.dart';
import '../../../core/ui/settings_button.dart';
import '../debts_providers.dart';
import '../remind.dart';

/// On me doit : qui vous doit, du plus gros montant au plus petit.
class DebtsScreen extends ConsumerWidget {
  const DebtsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debts = ref.watch(debtsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('On me doit'),
        actions: const [SettingsButton()],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: const SellButton(),
      body: debts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (d) => ListView(
          padding: const EdgeInsets.only(bottom: 110),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'On vous doit ${formatFcfa(d.total)}',
                  style: const TextStyle(
                    fontSize: AppSizes.amountSmall,
                    fontWeight: FontWeight.w800,
                    color: AppColors.red,
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            if (d.people.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  "Personne ne vous doit d'argent. Bravo !",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20),
                ),
              ),
            for (final p in d.people)
              InkWell(
                onTap: () => context.push(Routes.person(p.person.id)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.person.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (p.days != null)
                              Text(
                                p.days == 0
                                    ? "depuis aujourd'hui"
                                    : 'depuis ${p.days} jour${p.days! > 1 ? 's' : ''}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: AppColors.muted,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            formatFcfa(p.owed),
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              color: AppColors.red,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Relancer ${p.person.name}',
                        iconSize: 30,
                        color: AppColors.green,
                        icon: const Icon(Icons.chat),
                        onPressed: () => remind(context, ref, p.person, p.owed),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

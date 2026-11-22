import 'package:material_ui/material_ui.dart';

import '../../../core/db/database.dart';
import '../../../core/format/fcfa.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/amount_dialog.dart';
import '../../../core/ui/sale_tile.dart';

/// "Qui vous doit ?" : suggestions + saisie. Renvoie le nom ou null.
Future<String?> askWhoOwes(BuildContext context, List<Person> people) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final typed = controller.text.trim().toLowerCase();
        final matches = people
            .where((p) => typed.isEmpty || p.name.toLowerCase().contains(typed))
            .take(8)
            .toList();
        return AlertDialog(
          title: const Text('Qui vous doit ?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  autofocus: people.isEmpty,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(fontSize: 22),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.person),
                    hintText: 'Nom',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in matches)
                      ActionChip(
                        label: Text(
                          p.name,
                          style: const TextStyle(fontSize: 18),
                        ),
                        onPressed: () => Navigator.of(context).pop(p.name),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            FilledButton.icon(
              onPressed: controller.text.trim().isEmpty
                  ? null
                  : () => Navigator.of(context).pop(controller.text.trim()),
              icon: const Icon(Icons.check),
              label: const Text('Continuer'),
            ),
          ],
        );
      },
    ),
  );
}

/// "Combien avez-vous reçu ?" : pavé. Renvoie le montant ou null.
Future<int?> askReceived(BuildContext context, int total) async {
  final r = await showAmountDialog(
    context,
    title: 'Combien avez-vous reçu ?',
    initial: 0,
    buttonLabel: 'Continuer',
    hint: 'sur ${formatFcfa(total)}',
    color: AppColors.orangeText,
  );
  return r?.$1;
}

class KeepArticle {
  const KeepArticle(this.price, this.name);
  final int price;
  final String? name;
}

/// "Garder cet article pour la prochaine fois ?" (photo, prix prérempli, nom facultatif).
Future<KeepArticle?> askKeepArticle(
  BuildContext context,
  String photoPath,
  int amount,
) {
  final price = TextEditingController(text: amount > 0 ? '$amount' : '');
  final name = TextEditingController();
  return showDialog<KeepArticle>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Garder cet article pour la prochaine fois ?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SaleThumb(photoPath: photoPath, size: 120),
            const SizedBox(height: 12),
            TextField(
              controller: price,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 22),
              decoration: const InputDecoration(
                labelText: 'Prix',
                suffixText: 'F',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: name,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 22),
              decoration: const InputDecoration(labelText: 'Nom (facultatif)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Non merci'),
        ),
        FilledButton(
          onPressed: () {
            final p = parseFcfa(price.text) ?? 0;
            if (p <= 0) return;
            final n = name.text.trim();
            Navigator.of(context).pop(KeepArticle(p, n.isEmpty ? null : n));
          },
          child: const Text('Garder'),
        ),
      ],
    ),
  );
}

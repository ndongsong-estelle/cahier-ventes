import 'package:material_ui/material_ui.dart';

import '../db/ledger_repository.dart';
import '../format/fcfa.dart';
import '../theme/app_theme.dart';
import 'amount_pad.dart';

class PaymentInput {
  const PaymentInput(this.amount, this.method);
  final int amount;
  final PayMethod method;
}

/// "{Nom} a payé" : pavé prérempli avec le reste + moyen (Espèces par défaut).
Future<PaymentInput?> askPayment(
  BuildContext context, {
  required String title,
  required int rest,
}) {
  var value = rest;
  var method = PayMethod.cash;
  return showDialog<PaymentInput>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 340,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  child: Text(
                    formatFcfa(value),
                    key: const Key('pay-amount'),
                    style: const TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w800,
                      color: AppColors.green,
                    ),
                  ),
                ),
                Text(
                  'On vous doit ${formatFcfa(rest)}',
                  style: const TextStyle(fontSize: 18, color: AppColors.muted),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final m in PayMethod.values)
                      ChoiceChip(
                        label: Text(
                          m.label,
                          style: const TextStyle(fontSize: 17),
                        ),
                        selected: method == m,
                        onSelected: (_) => setState(() => method = m),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                AmountPad(
                  value: value,
                  keyHeight: 50,
                  onChanged: (v) => setState(() => value = v),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton.icon(
            onPressed: value <= 0
                ? null
                : () => Navigator.of(context).pop(PaymentInput(value, method)),
            icon: const Icon(Icons.check),
            label: const Text('Payé'),
          ),
        ],
      ),
    ),
  );
}

/// Confirmation avant de supprimer : [Garder] [Supprimer].
Future<bool> confirmDelete(BuildContext context, String question) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(question),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Garder'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.red),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Supprimer'),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Bandeau "… · Annuler" pendant 5 secondes.
void showUndo(BuildContext context, String text, Future<void> Function() undo) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 5),
        content: Text(text, style: const TextStyle(fontSize: 20)),
        action: SnackBarAction(label: 'Annuler', onPressed: undo),
      ),
    );
}

import 'package:material_ui/material_ui.dart';

import '../db/ledger_repository.dart';
import '../format/fcfa.dart';
import '../theme/app_theme.dart';
import 'amount_dialog.dart';

class PaymentInput {
  const PaymentInput(this.amount, this.method);
  final int amount;
  final PayMethod method;
}

/// "{Nom} a payé" : pavé prérempli avec le reste + moyen (Espèces par défaut).
/// Montant trop grand : "{Nom} ne vous doit que X F." et bouton désactivé.
Future<PaymentInput?> askPayment(
  BuildContext context, {
  required String title,
  required int rest,
  String? personName,
}) async {
  final r = await showAmountDialog(
    context,
    title: title,
    initial: rest,
    buttonLabel: 'Payé',
    hint: 'On vous doit ${formatFcfa(rest)}',
    max: rest,
    tooMuch: (max) => personName == null
        ? 'On ne vous doit que ${formatFcfa(max)}.'
        : '$personName ne vous doit que ${formatFcfa(max)}.',
    askMethod: true,
  );
  return r == null ? null : PaymentInput(r.$1, r.$2);
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

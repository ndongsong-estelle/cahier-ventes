import 'package:material_ui/material_ui.dart';

import '../db/ledger_repository.dart';
import '../format/fcfa.dart';
import '../theme/app_theme.dart';
import 'amount_pad.dart';

/// Saisie d'un montant en plein écran : grand montant, pavé géant, un gros bouton.
/// Tient sur un petit téléphone, police agrandie comprise.
Future<(int, PayMethod)?> showAmountDialog(
  BuildContext context, {
  required String title,
  required int initial,
  required String buttonLabel,
  String? hint,
  int? max,
  String Function(int max)? tooMuch,
  bool askMethod = false,
  Color color = AppColors.green,
}) {
  var value = initial;
  var method = PayMethod.cash;
  return showDialog<(int, PayMethod)>(
    context: context,
    builder: (context) => Dialog.fullscreen(
      child: StatefulBuilder(
        builder: (context, setState) {
          final over = max != null && value > max;
          return Scaffold(
            appBar: AppBar(
              title: Text(title),
              leading: IconButton(
                tooltip: 'Annuler',
                iconSize: 30,
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            body: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              formatFcfa(value),
                              key: const Key('pay-amount'),
                              style: TextStyle(
                                fontSize: AppSizes.amountLarge,
                                fontWeight: FontWeight.w800,
                                color: color,
                              ),
                            ),
                          ),
                        ),
                        if (hint != null)
                          Center(
                            child: Text(
                              hint,
                              style: const TextStyle(
                                fontSize: 18,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                        if (over && tooMuch != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              tooMuch(max),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 18,
                                color: AppColors.red,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        if (askMethod) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            alignment: WrapAlignment.center,
                            children: [
                              for (final m in PayMethod.values)
                                ChoiceChip(
                                  label: Text(
                                    m.label,
                                    style: const TextStyle(fontSize: 18),
                                  ),
                                  selected: method == m,
                                  onSelected: (_) => setState(() => method = m),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: AmountPad(
                      value: value,
                      keyHeight: 54,
                      onChanged: (v) => setState(() => value = v),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.green,
                        ),
                        onPressed: value <= 0 || over
                            ? null
                            : () => Navigator.of(context).pop((value, method)),
                        icon: const Icon(Icons.check, size: 28),
                        label: Text(buttonLabel),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}

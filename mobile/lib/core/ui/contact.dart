import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../features/account/account_flow.dart' show normalizePhone;
import '../format/fcfa.dart';

/// Message de relance (docs/01).
String reminderText({
  required String name,
  required String shop,
  required int amount,
}) =>
    'Bonjour $name, c\'est $shop. Il reste ${formatFcfa(amount)} à régler. Merci et bonne journée !';

typedef UrlOpener = Future<void> Function(Uri uri);

Future<void> openExternal(Uri uri) async {
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

Uri whatsAppUri(String phone, String text) => Uri.parse(
  'https://wa.me/${phone.replaceAll(RegExp(r'\D'), '')}?text=${Uri.encodeComponent(text)}',
);

Uri callUri(String phone) => Uri(scheme: 'tel', path: phone);

/// Numéro inconnu : le demander une fois (pavé). Renvoie +2376XXXXXXXX ou null.
Future<String?> askPhone(BuildContext context, String name) {
  final controller = TextEditingController();
  String? error;
  return showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text('Numéro de $name'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.phone,
              style: const TextStyle(fontSize: 24),
              decoration: InputDecoration(
                prefixText: '+237 ',
                errorText: error,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final p = normalizePhone(controller.text);
              if (p == null) {
                setState(() => error = 'Ce numéro ne semble pas correct.');
                return;
              }
              Navigator.of(context).pop(p);
            },
            child: const Text('Garder'),
          ),
        ],
      ),
    ),
  );
}

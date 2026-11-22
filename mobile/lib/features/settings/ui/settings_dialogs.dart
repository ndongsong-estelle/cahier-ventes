import 'package:material_ui/material_ui.dart';

import '../../account/ui/widgets.dart';

/// Petite fenêtre avec un champ texte. Renvoie le texte ou null.
Future<String?> askText(
  BuildContext context, {
  required String title,
  String initial = '',
}) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        maxLength: 60,
        textCapitalization: TextCapitalization.words,
        style: const TextStyle(fontSize: 22),
        decoration: const InputDecoration(counterText: ''),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(c.text.trim()),
          child: const Text('Garder'),
        ),
      ],
    ),
  );
}

/// Fenêtre avec des champs code secret. Renvoie les codes tapés ou null.
Future<List<String>?> askPins(
  BuildContext context, {
  required String title,
  required List<String> labels,
  String okLabel = 'Garder',
  String? text,
  bool danger = false,
}) {
  final controllers = [for (final _ in labels) TextEditingController()];
  return showDialog<List<String>>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (text != null) ...[
              Text(text, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 12),
            ],
            for (var i = 0; i < labels.length; i++) ...[
              PinField(label: labels[i], controller: controllers[i]),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(danger ? 'Garder' : 'Annuler'),
        ),
        FilledButton(
          style: danger
              ? FilledButton.styleFrom(backgroundColor: const Color(0xFFC62828))
              : null,
          onPressed: () =>
              Navigator.of(context).pop([for (final c in controllers) c.text]),
          child: Text(okLabel),
        ),
      ],
    ),
  );
}

/// Question oui/non. [yes] : libellé du bouton qui agit.
Future<bool> askYesNo(
  BuildContext context, {
  required String title,
  String? text,
  required String yes,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: text == null
          ? null
          : Text(text, style: const TextStyle(fontSize: 18)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(yes),
        ),
      ],
    ),
  );
  return r ?? false;
}

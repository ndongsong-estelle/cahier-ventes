import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Mots interdits dans l'interface (docs/01, Glossaire).
const forbidden = [
  'encaissé',
  'crédit',
  'débit',
  'remise',
  'stock',
  'synchroniser',
  'sauvegarde',
  'valider',
  'paramètres',
  'transaction',
  'serveur',
  'données',
  'identifiant',
  'mot de passe',
  'otp',
];

void main() {
  test('aucun mot interdit dans les textes de l app', () {
    final literal = RegExp(
      "'((?:[^'\\\\]|\\\\.)*)'|\"((?:[^\"\\\\]|\\\\.)*)\"",
    );
    final problems = <String>[];
    for (final f in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart') || f.path.endsWith('.g.dart')) continue;
      for (final line in f.readAsLinesSync()) {
        final t = line.trim();
        if (t.startsWith('import ') ||
            t.startsWith('//') ||
            t.startsWith('part ')) {
          continue;
        }
        for (final m in literal.allMatches(line)) {
          final text = (m.group(1) ?? m.group(2) ?? '').toLowerCase();
          // Clés techniques (snake_case, chemins, routes) : pas affichées.
          if (RegExp(r'^[a-z0-9_/:.\-]*$').hasMatch(text)) continue;
          for (final w in forbidden) {
            if (RegExp('(^|[^a-zà-ÿ])${RegExp.escape(w)}([^a-zà-ÿ]|\$)')
                .hasMatch(text)) {
              problems.add('${f.path}: "$text" ($w)');
            }
          }
        }
      }
    }
    expect(problems, isEmpty);
  });
}

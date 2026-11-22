/// Montants en int FCFA, jamais de float. Espaces insécables : "15 000 F" ne se coupe pas.
const String nbsp = ' ';

String formatFcfa(int amount) {
  final negative = amount < 0;
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(nbsp);
    buffer.write(digits[i]);
  }
  return '${negative ? '-' : ''}$buffer${nbsp}F';
}

/// Lit une saisie ("15 000", "15000 F") en int. Null si vide ou invalide.
int? parseFcfa(String input) {
  final cleaned = input.replaceAll(RegExp(r'[^0-9]'), '');
  if (cleaned.isEmpty || cleaned.length > 12) return null;
  return int.parse(cleaned);
}

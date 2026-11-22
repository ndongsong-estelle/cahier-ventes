import 'package:cahier_ventes/core/format/fcfa.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatFcfa groupe par milliers avec espaces insécables', () {
    expect(formatFcfa(0), '0${nbsp}F');
    expect(formatFcfa(500), '500${nbsp}F');
    expect(formatFcfa(15000), '15${nbsp}000${nbsp}F');
    expect(formatFcfa(1250000), '1${nbsp}250${nbsp}000${nbsp}F');
    expect(formatFcfa(-2000), '-2${nbsp}000${nbsp}F');
  });

  test('parseFcfa lit une saisie en int', () {
    expect(parseFcfa('15 000'), 15000);
    expect(parseFcfa('15000 F'), 15000);
    expect(parseFcfa(''), isNull);
    expect(parseFcfa('abc'), isNull);
  });
}

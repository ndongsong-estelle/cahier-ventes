/// Même règle que le serveur (backend/app/Support/WeakPin.php).
const _weakList = {
  '1122',
  '2580',
  '0852',
  '1004',
  '2000',
  '2001',
  '1010',
  '6969',
};

bool isWeakPin(String pin) {
  if (!RegExp(r'^\d{4}$').hasMatch(pin)) return true;
  final d = pin.split('').map(int.parse).toList();
  if (d.toSet().length == 1) return true;
  var up = true, down = true;
  for (var i = 1; i < 4; i++) {
    up = up && d[i] == d[i - 1] + 1;
    down = down && d[i] == d[i - 1] - 1;
  }
  if (up || down) return true;
  if (d[0] == d[2] && d[1] == d[3]) return true;
  return _weakList.contains(pin);
}

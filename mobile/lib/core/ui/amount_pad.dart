import 'package:material_ui/material_ui.dart';

/// Pavé numérique géant avec touche "000". Montant en int, 9 chiffres au plus.
class AmountPad extends StatelessWidget {
  const AmountPad({
    super.key,
    required this.value,
    required this.onChanged,
    this.keyHeight = 58,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final double keyHeight;

  void _type(String digits) {
    final next = value == 0
        ? digits.replaceFirst(RegExp(r'^0+'), '')
        : '$value$digits';
    if (next.isEmpty || next.length > 9) return;
    onChanged(int.parse(next));
  }

  void _back() {
    final s = '$value';
    onChanged(s.length <= 1 ? 0 : int.parse(s.substring(0, s.length - 1)));
  }

  @override
  Widget build(BuildContext context) {
    Widget key(
      String label,
      VoidCallback onTap, {
      Widget? child,
      String? tooltip,
    }) => Expanded(
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: SizedBox(
          height: keyHeight,
          child: Tooltip(
            message: tooltip ?? label,
            excludeFromSemantics: true,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: Size(48, keyHeight),
                padding: EdgeInsets.zero,
              ),
              onPressed: onTap,
              child:
                  child ??
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
            ),
          ),
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(children: [for (final d in row) key(d, () => _type(d))]),
        Row(
          children: [
            key('000', () => _type('000')),
            key('0', () => _type('0')),
            key(
              '⌫',
              _back,
              tooltip: 'Effacer',
              child: const Icon(Icons.backspace_outlined, size: 30),
            ),
          ],
        ),
      ],
    );
  }
}

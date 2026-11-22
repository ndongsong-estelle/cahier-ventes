import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';

/// Gros bouton principal (64 dp minimum, toute la largeur).
class BigButton extends StatelessWidget {
  const BigButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final child = busy
        ? const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Colors.white,
            ),
          )
        : Text(label, textAlign: TextAlign.center);
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: color == null
            ? null
            : FilledButton.styleFrom(backgroundColor: color),
        onPressed: busy ? null : onPressed,
        icon: icon == null || busy ? null : Icon(icon, size: 30),
        label: child,
      ),
    );
  }
}

/// Message d'erreur ou d'information sous un champ.
class Notice extends StatelessWidget {
  const Notice(this.text, {super.key, this.color = AppColors.red});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      text,
      style: TextStyle(
        fontSize: AppSizes.bodyText,
        color: color,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

/// Pas de réseau : message + "Réessayer".
class NoNetwork extends StatelessWidget {
  const NoNetwork({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.wifi_off, size: 56, color: AppColors.muted),
      const SizedBox(height: 12),
      Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 20),
      ),
      const SizedBox(height: 20),
      BigButton(label: 'Réessayer', icon: Icons.refresh, onPressed: onRetry),
    ],
  );
}

/// Champ code secret (4 chiffres, pavé numérique, masqué).
class PinField extends StatelessWidget {
  const PinField({
    super.key,
    required this.label,
    required this.controller,
    this.onChanged,
  });
  final String label;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    onChanged: onChanged,
    keyboardType: TextInputType.number,
    obscureText: true,
    maxLength: 4,
    style: const TextStyle(fontSize: 28, letterSpacing: 12),
    decoration: InputDecoration(labelText: label, counterText: ''),
  );
}

/// Pavé numérique en grand, avec 4 cases (C3, verrouillage).
class PinPad extends StatefulWidget {
  const PinPad({super.key, required this.onCompleted, this.enabled = true});

  final ValueChanged<String> onCompleted;
  final bool enabled;

  @override
  State<PinPad> createState() => PinPadState();
}

class PinPadState extends State<PinPad> {
  String _pin = '';

  void clear() => setState(() => _pin = '');

  void _tap(String d) {
    if (!widget.enabled || _pin.length >= 4) return;
    setState(() => _pin += d);
    if (_pin.length == 4) widget.onCompleted(_pin);
  }

  void _back() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    Widget key(String d) => Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: SizedBox(
          height: 64,
          child: OutlinedButton(
            onPressed: () => _tap(d),
            child: Text(d, style: const TextStyle(fontSize: 28)),
          ),
        ),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: '${_pin.length} chiffres sur 4',
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 4; i++)
                Container(
                  margin: const EdgeInsets.all(8),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _pin.length
                        ? AppColors.text
                        : Colors.transparent,
                    border: Border.all(color: AppColors.text, width: 2),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(children: [for (final d in row) key(d)]),
        Row(
          children: [
            const Expanded(child: SizedBox()),
            key('0'),
            Expanded(
              child: IconButton(
                iconSize: 32,
                tooltip: 'Effacer',
                onPressed: _back,
                icon: const Icon(Icons.backspace_outlined),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

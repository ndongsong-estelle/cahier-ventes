import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../account/ui/widgets.dart';

/// Écran du code secret par-dessus l'app quand "Demander le code à chaque ouverture" est actif.
class LockGate extends ConsumerWidget {
  const LockGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locked = ref.watch(appLockedProvider);
    return Stack(
      children: [
        child,
        if (locked) const Positioned.fill(child: _LockOverlay()),
      ],
    );
  }
}

/// Le verrou est au-dessus du Navigator : il lui faut son propre Overlay (infobulles du pavé).
class _LockOverlay extends StatefulWidget {
  const _LockOverlay();

  @override
  State<_LockOverlay> createState() => _LockOverlayState();
}

class _LockOverlayState extends State<_LockOverlay> {
  final _entry = OverlayEntry(builder: (_) => const _LockScreen());

  @override
  void dispose() {
    _entry.remove();
    _entry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Overlay(initialEntries: [_entry]);
}

class _LockScreen extends ConsumerStatefulWidget {
  const _LockScreen();

  @override
  ConsumerState<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<_LockScreen> {
  final _pad = GlobalKey<PinPadState>();
  String? _error;

  Future<void> _check(String pin) async {
    if (await ref.read(pinLockProvider).check(pin)) {
      ref.read(appLockedProvider.notifier).set(false);
      return;
    }
    setState(() => _error = "Ce n'est pas le bon code secret.");
    _pad.currentState?.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(Icons.lock, size: 64, color: AppColors.green),
            const SizedBox(height: 12),
            Text(
              'Bonjour ! Tapez votre code secret',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (_error != null) Center(child: Notice(_error!)),
            const SizedBox(height: 16),
            PinPad(key: _pad, onCompleted: _check),
          ],
        ),
      ),
    );
  }
}

/// Faut-il verrouiller ? (option active et code enregistré)
Future<bool> shouldLock(WidgetRef ref) async {
  final on = await ref.read(settingsStoreProvider).getBool('pin_on_open');
  return on && await ref.read(pinLockProvider).isSet;
}

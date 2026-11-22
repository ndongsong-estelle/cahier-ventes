import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/api/api_client.dart';
import '../../../core/auth/session.dart';
import '../../../core/auth/weak_pin.dart';
import '../../../core/providers.dart';
import '../account_flow.dart';
import 'widgets.dart';

/// Nouveau code secret : après un code provisoire, ou après "Code oublié ?" par SMS.
class NewPinScreen extends ConsumerStatefulWidget {
  const NewPinScreen({super.key});

  @override
  ConsumerState<NewPinScreen> createState() => _NewPinScreenState();
}

class _NewPinScreenState extends ConsumerState<NewPinScreen> {
  final _pin = TextEditingController();
  final _pin2 = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    _pin2.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    String? problem;
    if (!RegExp(r'^\d{4}$').hasMatch(_pin.text)) {
      problem = 'Le code secret a 4 chiffres.';
    } else if (isWeakPin(_pin.text)) {
      problem = 'Choisissez un code plus difficile à deviner.';
    } else if (_pin.text != _pin2.text) {
      problem = 'Les deux codes ne sont pas pareils.';
    }
    setState(() => _error = problem);
    if (problem != null) return;
    setState(() => _busy = true);
    final flow = ref.read(accountFlowProvider);
    final session = ref.read(sessionProvider.notifier);
    final api = ref.read(authApiProvider);
    try {
      if (ref.read(sessionProvider).isLoggedIn) {
        await api.changePin(flow.temporaryPin ?? '', _pin.text);
        session.pinChanged();
      } else {
        final result = await api.resetPin(
          phone: flow.phone,
          otpTicket: flow.otpTicket ?? '',
          newPin: _pin.text,
          device: await session.deviceInfo(),
        );
        await session.signedIn(result);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = messageFor(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Code secret')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          PinField(
            label: 'Choisissez un nouveau code secret',
            controller: _pin,
          ),
          const SizedBox(height: 16),
          PinField(label: 'Tapez-le encore une fois', controller: _pin2),
          if (_error != null) Notice(_error!),
          const SizedBox(height: 24),
          BigButton(label: 'Continuer', busy: _busy, onPressed: _save),
        ],
      ),
    );
  }
}

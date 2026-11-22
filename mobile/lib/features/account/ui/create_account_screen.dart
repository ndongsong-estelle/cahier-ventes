import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_client.dart';
import '../../../core/auth/session.dart';
import '../../../core/auth/weak_pin.dart';
import '../../../core/config/app_config.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../account_flow.dart';
import 'widgets.dart';

/// C2. Créer mon compte (un seul écran).
class CreateAccountScreen extends ConsumerStatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  ConsumerState<CreateAccountScreen> createState() =>
      _CreateAccountScreenState();
}

class _CreateAccountScreenState extends ConsumerState<CreateAccountScreen> {
  final _shop = TextEditingController();
  final _pin = TextEditingController();
  final _pin2 = TextEditingController();
  bool _busy = false;
  bool _offline = false;
  String? _error;

  @override
  void dispose() {
    _shop.dispose();
    _pin.dispose();
    _pin2.dispose();
    super.dispose();
  }

  String? _check() {
    final pin = _pin.text;
    return switch (true) {
      _ when _shop.text.trim().length < 2 =>
        'Écrivez le nom de votre boutique.',
      _ when !RegExp(r'^\d{4}$').hasMatch(pin) =>
        'Le code secret a 4 chiffres.',
      _ when isWeakPin(pin) => 'Choisissez un code plus difficile à deviner.',
      _ when pin != _pin2.text => 'Les deux codes ne sont pas pareils.',
      _ => null,
    };
  }

  Future<void> _create() async {
    final problem = _check();
    setState(() {
      _error = problem;
      _offline = false;
    });
    if (problem != null) return;
    setState(() => _busy = true);
    final flow = ref.read(accountFlowProvider);
    final session = ref.read(sessionProvider.notifier);
    try {
      final result = await ref
          .read(authApiProvider)
          .register(
            phone: flow.phone,
            shopName: _shop.text.trim(),
            pin: _pin.text,
            device: await session.deviceInfo(),
            otpTicket: flow.otpTicket,
          );
      await session.signedIn(result);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _offline = e.isNetwork;
          _error = e.isNetwork ? null : messageFor(e);
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Créer mon compte')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: _shop,
            textCapitalization: TextCapitalization.words,
            maxLength: 60,
            style: const TextStyle(fontSize: 22),
            decoration: const InputDecoration(
              labelText: 'Nom de votre boutique',
              counterText: '',
            ),
          ),
          const SizedBox(height: 20),
          PinField(
            label: 'Choisissez un code secret de 4 chiffres',
            controller: _pin,
          ),
          const SizedBox(height: 16),
          PinField(label: 'Tapez-le encore une fois', controller: _pin2),
          if (_error != null) Notice(_error!),
          const SizedBox(height: 16),
          const Text(
            'Une copie de votre cahier est gardée en sécurité pour que vous ne perdiez rien '
            'si vous changez de téléphone. Nous voyons aussi comment l\'app est utilisée, '
            'pour l\'améliorer.',
            style: TextStyle(
              fontSize: AppSizes.bodyText,
              color: AppColors.muted,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => launchUrl(
                Uri.parse('${AppConfig.siteUrl}/confidentialite'),
                mode: LaunchMode.externalApplication,
              ),
              child: const Text('En savoir plus'),
            ),
          ),
          const SizedBox(height: 8),
          if (_offline)
            NoNetwork(message: noNetworkMessage, onRetry: _create)
          else
            BigButton(
              label: 'Créer mon compte',
              icon: Icons.check,
              busy: _busy,
              onPressed: _create,
            ),
        ],
      ),
    );
  }
}

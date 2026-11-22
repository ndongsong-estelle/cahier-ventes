import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_client.dart';
import '../../../core/auth/session.dart';
import '../../../core/config/app_config.dart';
import '../../../core/providers.dart';
import '../../../core/router/router.dart';
import '../account_flow.dart';
import 'widgets.dart';

/// C3. Se connecter.
class PinLoginScreen extends ConsumerStatefulWidget {
  const PinLoginScreen({super.key});

  @override
  ConsumerState<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends ConsumerState<PinLoginScreen> {
  final _pad = GlobalKey<PinPadState>();
  bool _busy = false;
  bool _offline = false;
  String? _error;
  String? _lastPin;

  Future<void> _login(String pin) async {
    _lastPin = pin;
    setState(() {
      _busy = true;
      _error = null;
      _offline = false;
    });
    final flow = ref.read(accountFlowProvider);
    final session = ref.read(sessionProvider.notifier);
    try {
      final result = await ref
          .read(authApiProvider)
          .login(
            phone: flow.phone,
            pin: pin,
            device: await session.deviceInfo(),
          );
      if (result.mustChangePin) {
        ref
            .read(accountFlowProvider.notifier)
            .update((f) => f.copyWith(temporaryPin: pin));
      }
      await session.signedIn(result);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _offline = e.isNetwork;
        _error = e.isNetwork ? null : messageFor(e);
      });
      _pad.currentState?.clear();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgot() async {
    final flow = ref.read(accountFlowProvider);
    if (flow.otpRequired) {
      try {
        await ref.read(authApiProvider).sendOtp(flow.phone);
        ref
            .read(accountFlowProvider.notifier)
            .update((f) => f.copyWith(purpose: OtpPurpose.reset));
        if (mounted) context.push(Routes.accountSms);
      } on ApiException catch (e) {
        setState(() => _error = messageFor(e));
      }
      return;
    }
    final number =
        (ref.read(supportWhatsappProvider) ?? AppConfig.supportWhatsapp)
            .replaceAll(RegExp(r'\D'), '');
    final text = Uri.encodeComponent(
      "Bonjour, j'ai oublié mon code secret. Mon numéro : ${flow.phone}",
    );
    await launchUrl(
      Uri.parse('https://wa.me/$number?text=$text'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final otp = ref.watch(accountFlowProvider.select((f) => f.otpRequired));
    return Scaffold(
      appBar: AppBar(title: const Text('Se connecter')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        children: [
          Text(
            'Bonjour ! Tapez votre code secret',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          if (_offline)
            NoNetwork(
              message: noNetworkMessage,
              onRetry: () => _login(_lastPin ?? ''),
            )
          else ...[
            PinPad(key: _pad, enabled: !_busy, onCompleted: _login),
            if (_busy)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(),
                ),
              ),
            if (_error != null) Center(child: Notice(_error!)),
          ],
          const SizedBox(height: 8),
          TextButton(
            onPressed: _forgot,
            child: Text(
              otp
                  ? 'Code oublié ?'
                  : 'Code oublié ? Contactez l\'aide sur WhatsApp',
            ),
          ),
        ],
      ),
    );
  }
}

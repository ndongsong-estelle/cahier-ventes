import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sms_autofill/sms_autofill.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/router/router.dart';
import '../account_flow.dart';
import 'widgets.dart';

/// Code reçu par SMS (6 cases, remplissage automatique, "Renvoyer" après 60 s).
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> with CodeAutoFill {
  final _code = TextEditingController();
  Timer? _timer;
  int _wait = 60;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startTimer();
    try {
      listenForCode();
    } catch (_) {
      // Remplissage automatique indisponible : saisie à la main.
    }
  }

  @override
  void codeUpdated() {
    if (code != null && code!.length == 6) {
      _code.text = code!;
      _verify();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _wait = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_wait <= 1) t.cancel();
      if (mounted) setState(() => _wait--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    try {
      cancel();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _verify() async {
    if (_code.text.length != 6 || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final flow = ref.read(accountFlowProvider);
    try {
      final ticket = await ref
          .read(authApiProvider)
          .verifyOtp(flow.phone, _code.text);
      ref
          .read(accountFlowProvider.notifier)
          .update((f) => f.copyWith(otpTicket: ticket));
      if (!mounted) return;
      context.pushReplacement(
        flow.purpose == OtpPurpose.create
            ? Routes.accountCreate
            : Routes.accountNewPin,
      );
    } on ApiException catch (e) {
      setState(() => _error = messageFor(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    try {
      await ref
          .read(authApiProvider)
          .sendOtp(ref.read(accountFlowProvider).phone);
      _startTimer();
    } on ApiException catch (e) {
      setState(() => _error = messageFor(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Code reçu par SMS')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Tapez le code reçu au ${ref.watch(accountFlowProvider).phone}',
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 32, letterSpacing: 14),
            decoration: const InputDecoration(counterText: ''),
            onChanged: (v) {
              if (v.length == 6) _verify();
            },
          ),
          if (_error != null) Notice(_error!),
          const SizedBox(height: 16),
          BigButton(label: 'Continuer', busy: _busy, onPressed: _verify),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _wait > 0 ? null : _resend,
            child: Text(_wait > 0 ? 'Renvoyer ($_wait s)' : 'Renvoyer'),
          ),
        ],
      ),
    );
  }
}

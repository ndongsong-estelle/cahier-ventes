import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/api/api_client.dart';
import '../../../core/auth/session.dart';
import '../../../core/providers.dart';
import '../../../core/router/router.dart';
import '../../../core/theme/app_theme.dart';
import '../account_flow.dart';
import 'widgets.dart';

/// C1. Numéro.
class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final _phone = TextEditingController();
  bool _busy = false;
  String? _error;
  bool _offline = false;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final phone = normalizePhone(_phone.text);
    if (phone == null) {
      setState(() => _error = 'Ce numéro ne semble pas correct.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _offline = false;
    });
    try {
      final api = ref.read(authApiProvider);
      final check = await api.check(phone);
      final flow = ref.read(accountFlowProvider.notifier);
      flow.update(
        (_) => AccountFlow(
          phone: phone,
          exists: check.exists,
          otpRequired: check.otpRequired,
        ),
      );
      if (!mounted) return;
      if (check.exists) {
        context.push(Routes.accountPin);
      } else if (check.otpRequired) {
        await api.sendOtp(phone);
        flow.update((f) => f.copyWith(purpose: OtpPurpose.create));
        if (mounted) context.push(Routes.accountSms);
      } else {
        context.push(Routes.accountCreate);
      }
    } on ApiException catch (e) {
      setState(() {
        _offline = e.isNetwork;
        _error = e.isNetwork ? null : messageFor(e);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notice = ref.watch(sessionProvider.select((s) => s.notice));
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (notice != null) Notice(notice, color: AppColors.orangeText),
            const SizedBox(height: 24),
            const Icon(Icons.menu_book, size: 88, color: AppColors.green),
            const SizedBox(height: 12),
            Text(
              'Votre cahier de ventes',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 32),
            if (_offline)
              NoNetwork(message: noNetworkMessage, onRetry: _continue)
            else ...[
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumberNational],
                style: const TextStyle(fontSize: 26),
                decoration: const InputDecoration(
                  labelText: 'Votre numéro',
                  prefixText: '+237 ',
                  prefixStyle: TextStyle(fontSize: 26, color: AppColors.text),
                ),
                onSubmitted: (_) => _continue(),
              ),
              if (_error != null) Notice(_error!),
              const SizedBox(height: 24),
              BigButton(label: 'Continuer', busy: _busy, onPressed: _continue),
            ],
          ],
        ),
      ),
    );
  }
}

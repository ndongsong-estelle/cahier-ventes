import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';

enum OtpPurpose { create, reset }

/// Ce que l'on sait pendant le parcours C1 → C2/C3.
class AccountFlow {
  const AccountFlow({
    this.phone = '',
    this.exists = false,
    this.otpRequired = false,
    this.otpTicket,
    this.purpose = OtpPurpose.create,
    this.temporaryPin,
  });

  final String phone;
  final bool exists;
  final bool otpRequired;
  final String? otpTicket;
  final OtpPurpose purpose;

  /// Code provisoire donné par Estha, à remplacer juste après la connexion.
  final String? temporaryPin;

  AccountFlow copyWith({
    String? phone,
    bool? exists,
    bool? otpRequired,
    String? otpTicket,
    OtpPurpose? purpose,
    String? temporaryPin,
  }) => AccountFlow(
    phone: phone ?? this.phone,
    exists: exists ?? this.exists,
    otpRequired: otpRequired ?? this.otpRequired,
    otpTicket: otpTicket ?? this.otpTicket,
    purpose: purpose ?? this.purpose,
    temporaryPin: temporaryPin ?? this.temporaryPin,
  );
}

class AccountFlowController extends Notifier<AccountFlow> {
  @override
  AccountFlow build() => const AccountFlow();

  void update(AccountFlow Function(AccountFlow) change) =>
      state = change(state);
}

final accountFlowProvider =
    NotifierProvider<AccountFlowController, AccountFlow>(
      AccountFlowController.new,
    );

/// Numéro saisi → +2376XXXXXXXX, ou null.
String? normalizePhone(String raw) {
  var d = raw.replaceAll(RegExp(r'\D'), '');
  if (d.startsWith('00')) d = d.substring(2);
  if (d.length == 9) d = '237$d';
  return RegExp(r'^2376\d{8}$').hasMatch(d) ? '+$d' : null;
}

const noNetworkMessage =
    'Il faut internet pour ouvrir votre compte. Réessayez quand vous avez du réseau.';

/// Phrase courte à montrer pour une erreur d'API.
String messageFor(ApiException e) {
  if (e.isNetwork) return noNetworkMessage;
  return switch (e.code) {
    'weak_pin' => 'Choisissez un code plus difficile à deviner.',
    'wrong_pin' => "Ce n'est pas le bon code secret.",
    'locked' => e.message ?? "Trop d'essais. Réessayez dans 15 minutes.",
    'invalid_phone' => 'Ce numéro ne semble pas correct.',
    'phone_taken' => 'Ce numéro a déjà un compte. Connectez-vous.',
    'wrong_otp' => 'Ce code ne marche pas. Vérifiez le SMS.',
    _ => e.message ?? 'Un problème est survenu. Réessayez.',
  };
}

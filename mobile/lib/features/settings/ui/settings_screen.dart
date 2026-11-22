import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/api/api_client.dart';
import '../../../core/auth/session.dart';
import '../../../core/auth/weak_pin.dart';
import '../../../core/config/app_config.dart';
import '../../../core/db/settings_store.dart';
import '../../../core/providers.dart';
import '../../../core/router/router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/contact.dart';
import '../../../core/ui/pay_dialog.dart' show showUndo;
import '../../account/account_flow.dart' show messageFor;
import '../settings_providers.dart';
import 'settings_dialogs.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _versionTaps = 0;

  void _say(String text) => ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(content: Text(text, style: const TextStyle(fontSize: 19))),
    );

  String _netMessage(ApiException e, String what) => e.isNetwork
      ? 'Il faut internet pour $what. Réessayez quand vous avez du réseau.'
      : messageFor(e);

  Future<void> _shopName(String current) async {
    final name = await askText(
      context,
      title: 'Nom de la boutique',
      initial: current,
    );
    if (name == null || name.length < 2 || name == current) return;
    try {
      final user = await ref.read(authApiProvider).updateShopName(name);
      await ref.read(sessionProvider.notifier).shopNameChanged(user.shopName);
      ref.invalidate(settingsViewProvider);
    } on ApiException catch (e) {
      _say(_netMessage(e, 'changer le nom'));
    }
  }

  Future<void> _shopPhone(String? current) async {
    final phone = await askPhone(context, 'la boutique');
    if (phone == null) return;
    final settings = ref.read(settingsStoreProvider);
    await settings.set(SettingKey.shopPhone, phone);
    ref.invalidate(settingsViewProvider);
    if (!mounted) return;
    showUndo(context, "C'est noté", () async {
      await settings.set(SettingKey.shopPhone, current);
      ref.invalidate(settingsViewProvider);
    });
  }

  Future<void> _changePin() async {
    final pins = await askPins(
      context,
      title: 'Changer mon code secret',
      labels: const [
        'Code secret actuel',
        'Nouveau code secret',
        'Tapez-le encore une fois',
      ],
    );
    if (pins == null) return;
    if (isWeakPin(pins[1])) {
      return _say('Choisissez un code plus difficile à deviner.');
    }
    if (pins[1] != pins[2]) return _say('Les deux codes ne sont pas pareils.');
    try {
      await ref.read(authApiProvider).changePin(pins[0], pins[1]);
      final lock = ref.read(pinLockProvider);
      if (await lock.isSet) await lock.save(pins[1]);
      _say('Votre code secret est changé.');
    } on ApiException catch (e) {
      _say(_netMessage(e, 'changer le code secret'));
    }
  }

  Future<void> _pinOnOpen(bool on) async {
    final settings = ref.read(settingsStoreProvider);
    final lock = ref.read(pinLockProvider);
    if (on) {
      final pins = await askPins(
        context,
        title: 'Tapez votre code secret',
        labels: const ['Code secret'],
      );
      if (pins == null || !RegExp(r'^\d{4}$').hasMatch(pins[0])) return;
      await lock.save(pins[0]);
    } else {
      await lock.clear();
    }
    await settings.setBool(SettingKey.pinOnOpen, on);
    ref.invalidate(settingsViewProvider);
  }

  Future<void> _weekly(bool on) async {
    final settings = ref.read(settingsStoreProvider);
    await settings.setBool(SettingKey.weeklySummary, on);
    await applyWeeklySetting(settings, ref.read(weeklyNotificationProvider));
    ref.invalidate(settingsViewProvider);
  }

  Future<void> _logout() async {
    final ok = await askYesNo(
      context,
      title: 'Se déconnecter ?',
      text: 'Votre cahier reste sur ce téléphone. Il faudra internet et votre code secret pour revenir.',
      yes: 'Se déconnecter',
    );
    if (!ok) return;
    try {
      await ref.read(backupServiceProvider).maybeSend(force: true);
      await ref.read(authApiProvider).logout();
    } catch (_) {
      // Sans réseau : on se déconnecte quand même sur ce téléphone.
    }
    await ref.read(sessionProvider.notifier).loggedOut();
  }

  Future<void> _delete() async {
    final pins = await askPins(
      context,
      title: 'Supprimer mon compte',
      text:
          'Votre compte et la copie de votre cahier seront effacés du serveur et de ce téléphone. '
          'Cela ne peut pas être annulé. Il faut internet.',
      labels: const ['Code secret'],
      okLabel: 'Supprimer',
      danger: true,
    );
    if (pins == null) return;
    try {
      await ref.read(authApiProvider).deleteAccount(pins[0]);
      await ref.read(sessionProvider.notifier).deleted();
    } on ApiException catch (e) {
      _say(_netMessage(e, 'supprimer votre compte'));
    }
  }

  Future<void> _sendCopy() async {
    final path = await ref.read(manualBackupProvider).export();
    await ref
        .read(sharerProvider)
        .shareFile(path, text: 'Copie de votre cahier');
  }

  Future<void> _restoreCopy() async {
    final path = await ref.read(filePickerProvider).pick();
    if (path == null || !mounted) return;
    final ok = await askYesNo(
      context,
      title: 'Remettre une copie',
      text: 'Cela remplace votre cahier actuel.',
      yes: 'Remettre',
    );
    if (!ok) return;
    try {
      await ref.read(manualBackupProvider).import(path);
      _say('Votre cahier est remis.');
    } on FormatException catch (e) {
      _say(e.message);
    }
  }

  Future<void> _help(String? support) async {
    final number = support ?? AppConfig.supportWhatsapp;
    final phone = ref.read(sessionProvider).phone ?? '';
    await ref.read(urlOpenerProvider)(
      whatsAppUri(
        number,
        "Bonjour, j'ai besoin d'aide avec le Cahier de ventes. Mon numéro : $phone",
      ),
    );
  }

  void _version() {
    if (++_versionTaps >= 7) {
      _versionTaps = 0;
      context.push(Routes.technical);
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(settingsViewProvider);
    final shop = ref.watch(sessionProvider.select((s) => s.shopName)) ?? '';
    const big = TextStyle(fontSize: 20);
    const small = TextStyle(fontSize: 17, color: AppColors.muted);
    Widget header(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        t,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: AppColors.green,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: view.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (v) => ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            header('Mon compte'),
            ListTile(
              leading: const Icon(Icons.phone_android),
              title: Text(v.phone ?? '', style: big),
            ),
            ListTile(
              leading: const Icon(Icons.storefront),
              title: Text(shop, style: big),
              subtitle: const Text('Nom de la boutique', style: small),
              trailing: const Icon(Icons.edit),
              onTap: () => _shopName(shop),
            ),
            ListTile(
              leading: const Icon(Icons.chat),
              title: Text(v.shopPhone ?? 'Ajouter', style: big),
              subtitle: const Text(
                'Numéro WhatsApp de la boutique (pour le reçu)',
                style: small,
              ),
              trailing: const Icon(Icons.edit),
              onTap: () => _shopPhone(v.shopPhone),
            ),
            ListTile(
              leading: const Icon(Icons.password),
              title: const Text('Changer mon code secret', style: big),
              onTap: _changePin,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.lock),
              title: const Text(
                'Demander le code à chaque ouverture',
                style: big,
              ),
              value: v.pinOnOpen,
              onChanged: _pinOnOpen,
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Se déconnecter', style: big),
              onTap: _logout,
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: AppColors.red),
              title: const Text(
                'Supprimer mon compte',
                style: TextStyle(fontSize: 20, color: AppColors.red),
              ),
              onTap: _delete,
            ),
            header('Bilan du dimanche'),
            SwitchListTile(
              secondary: const Icon(Icons.notifications),
              title: const Text('Bilan du dimanche', style: big),
              value: v.weekly,
              onChanged: _weekly,
            ),
            header('Copie de votre cahier'),
            ListTile(
              leading: const Icon(Icons.cloud_done),
              title: Text(v.backupLine, style: big),
            ),
            ListTile(
              leading: const Icon(Icons.send),
              title: const Text('Envoyer une copie', style: big),
              onTap: _sendCopy,
            ),
            ListTile(
              leading: const Icon(Icons.restore),
              title: const Text('Remettre une copie', style: big),
              onTap: _restoreCopy,
            ),
            header('Aide'),
            ListTile(
              leading: const Icon(Icons.support_agent),
              title: const Text('Aide sur WhatsApp', style: big),
              onTap: () => _help(v.support),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text('Version ${AppConfig.appVersion}', style: small),
              onTap: _version,
            ),
          ],
        ),
      ),
    );
  }
}

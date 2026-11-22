import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/config/app_config.dart';
import '../../../core/format/dates.dart';
import '../settings_providers.dart';

/// Écran technique (7 touchers sur la version) : pour Estha au téléphone.
class TechnicalScreen extends ConsumerWidget {
  const TechnicalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(settingsViewProvider).value;
    const style = TextStyle(fontSize: 18);
    final last = v?.lastBackupAt;
    return Scaffold(
      appBar: AppBar(title: const Text('Technique')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Dernier envoi réussi : ${last == null ? '—' : '${formatDate(last)} ${formatTime(last)}'}',
            style: style,
          ),
          const SizedBox(height: 8),
          Text('En attente : ${v?.outboxCount ?? 0}', style: style),
          const SizedBox(height: 8),
          SelectableText('Adresse : ${AppConfig.apiUrl}', style: style),
          const SizedBox(height: 8),
          Text('Version : ${AppConfig.appVersion}', style: style),
        ],
      ),
    );
  }
}

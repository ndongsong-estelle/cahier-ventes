import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/db/ledger_queries.dart';
import '../../../core/format/fcfa.dart';
import '../../../core/providers.dart';
import '../../../core/router/router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/pay_dialog.dart';
import '../../../core/ui/sale_tile.dart';
import '../../account/account_flow.dart' show normalizePhone;
import '../debts_providers.dart';
import '../remind.dart';

/// Fiche d'une personne.
class PersonScreen extends ConsumerWidget {
  const PersonScreen({super.key, required this.personId});
  final String personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debt = ref.watch(personDebtProvider(personId));
    return Scaffold(
      appBar: AppBar(
        title: Text(debt.value?.person.name ?? ''),
        actions: [
          if (debt.value != null)
            IconButton(
              tooltip: 'Modifier le nom ou le numéro',
              iconSize: 30,
              icon: const Icon(Icons.edit),
              onPressed: () => _edit(context, ref, debt.value!),
            ),
        ],
      ),
      body: debt.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (d) => d == null ? const SizedBox.shrink() : _Body(d),
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, PersonDebt d) async {
    final name = TextEditingController(text: d.person.name);
    final phone = TextEditingController(
      text: d.person.phone?.replaceFirst('+237', '') ?? '',
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(d.person.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(fontSize: 22),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.person)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              style: const TextStyle(fontSize: 22),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.phone),
                prefixText: '+237 ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Garder'),
          ),
        ],
      ),
    );
    if (saved != true || name.text.trim().length < 2) return;
    final ledger = ref.read(ledgerProvider);
    final oldName = d.person.name, oldPhone = d.person.phone;
    await ledger.updatePerson(
      d.person.id,
      name: name.text.trim(),
      phone: normalizePhone(phone.text) ?? oldPhone,
    );
    if (!context.mounted) return;
    showUndo(
      context,
      'C\'est noté',
      () => ledger.updatePerson(d.person.id, name: oldName, phone: oldPhone),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body(this.d);
  final PersonDebt d;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = d.person.name;

    Future<void> paid() async {
      final input = await askPayment(
        context,
        title: '$name a payé',
        rest: d.owed,
        personName: name,
      );
      if (input == null) return;
      final ledger = ref.read(ledgerProvider);
      final before = [for (final s in d.unpaid) await ledger.snapshot(s.id)];
      await ledger.personPaid(d.person.id, input.amount, method: input.method);
      if (!context.mounted) return;
      showUndo(context, '$name a payé ${formatFcfa(input.amount)}', () async {
        for (final s in before) {
          await ledger.restoreSnapshot(s);
        }
        await ledger.removePaymentsAfter(before);
      });
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formatFcfa(d.owed),
              style: TextStyle(
                fontSize: AppSizes.amountLarge,
                fontWeight: FontWeight.w800,
                color: d.owed > 0 ? AppColors.red : AppColors.green,
              ),
            ),
          ),
        ),
        Center(
          child: Text(
            d.owed > 0 ? 'On vous doit' : 'Payé',
            style: const TextStyle(fontSize: 20, color: AppColors.muted),
          ),
        ),
        const SizedBox(height: 16),
        if (d.owed > 0)
          FilledButton.icon(
            onPressed: paid,
            icon: const Icon(Icons.check, size: 28),
            label: Text('$name a payé'),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: d.owed > 0
                    ? () => remind(context, ref, d.person, d.owed)
                    : null,
                icon: const Icon(Icons.chat, size: 26),
                label: const Text('Relancer'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => callPerson(context, ref, d.person),
                icon: const Icon(Icons.call, size: 26),
                label: const Text('Appeler'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final s in d.unpaid)
          SaleTile(
            item: s,
            showDate: true,
            onTap: () => context.push(Routes.saleDetail(s.id)),
          ),
      ],
    );
  }
}

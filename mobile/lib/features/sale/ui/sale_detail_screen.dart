import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/db/ledger_queries.dart';
import '../../../core/db/ledger_repository.dart';
import '../../../core/domain/ledger.dart';
import '../../../core/format/dates.dart';
import '../../../core/format/fcfa.dart';
import '../../../core/providers.dart';
import '../../../core/router/router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/pay_dialog.dart';
import '../../../core/ui/sale_tile.dart';

final saleDetailProvider = FutureProvider.autoDispose
    .family<SaleDetail?, String>((ref, id) {
      ref.watch(ledgerChangesProvider);
      return ref.read(ledgerProvider).saleDetail(id);
    });

/// Détail d'une vente.
class SaleDetailScreen extends ConsumerWidget {
  const SaleDetailScreen({super.key, required this.saleId});
  final String saleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(saleDetailProvider(saleId));
    return Scaffold(
      appBar: AppBar(title: const Text('Vente')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (d) => d == null || d.sale.deletedAt != null
            ? const Center(
                child: Text(
                  'Cette vente a été supprimée.',
                  style: TextStyle(fontSize: 20),
                ),
              )
            : _Detail(d),
      ),
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail(this.d);
  final SaleDetail d;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.read(ledgerProvider);
    final name = d.person?.name;

    Future<void> pay() async {
      final input = await askPayment(
        context,
        title: name == null ? 'Payé' : '$name a payé',
        rest: d.rest,
        personName: name,
      );
      if (input == null) return;
      await ledger.addPayment(d.sale.id, input.amount, method: input.method);
    }

    Future<void> remove() async {
      if (!await confirmDelete(context, 'Supprimer cette vente ?')) return;
      await ledger.deleteSale(d.sale.id);
      if (!context.mounted) return;
      showUndo(context, 'Vente supprimée', () => ledger.restoreSale(d.sale.id));
      context.pop();
    }

    Future<void> removePayment(String id) async {
      if (!await confirmDelete(context, 'Supprimer ce paiement ?')) return;
      await ledger.deletePayment(id);
      if (!context.mounted) return;
      showUndo(context, 'Paiement supprimé', () => ledger.restorePayment(id));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Center(
          child: FittedBox(
            child: Text(
              formatFcfa(d.sale.amount),
              style: const TextStyle(
                fontSize: AppSizes.amountLarge,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        Center(
          child: StatusLabel(status: d.status, rest: d.rest),
        ),
        const SizedBox(height: 12),
        if (d.photos.isNotEmpty)
          SizedBox(
            height: 96,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final p in d.photos)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: SaleThumb(photoPath: p, size: 96),
                  ),
              ],
            ),
          ),
        if (d.articles.isNotEmpty)
          Wrap(
            spacing: 6,
            children: [
              for (final a in d.articles)
                Chip(
                  label: Text(a.label, style: const TextStyle(fontSize: 18)),
                ),
            ],
          ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.person, size: 30),
          title: Text(name ?? 'Sans nom', style: const TextStyle(fontSize: 20)),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.schedule, size: 30),
          title: Text(
            '${formatDay(d.sale.soldAt)} · ${formatTime(d.sale.soldAt)}',
            style: const TextStyle(fontSize: 20),
          ),
        ),
        const Divider(),
        Text(
          'Reçu ${formatFcfa(d.received)}',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.green,
          ),
        ),
        for (final p in d.payments)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.payments,
              color: AppColors.green,
              size: 28,
            ),
            title: Text(
              '${PayMethod.fromCode(p.method).label} · ${formatFcfa(p.amount)}',
              style: const TextStyle(fontSize: 19),
            ),
            subtitle: Text(
              '${formatDay(p.paidAt)} · ${formatTime(p.paidAt)}',
              style: const TextStyle(fontSize: 16),
            ),
            trailing: IconButton(
              tooltip: 'Supprimer ce paiement',
              icon: const Icon(Icons.close),
              onPressed: () => removePayment(p.id),
            ),
          ),
        if (d.rest > 0) ...[
          const SizedBox(height: 8),
          Text(
            'On vous doit ${formatFcfa(d.rest)}',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: d.status == SaleStatus.partial
                  ? AppColors.orangeText
                  : AppColors.red,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: pay,
            icon: const Icon(Icons.check, size: 28),
            label: Text(name == null ? 'Payé' : '$name a payé'),
          ),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => context.push(Routes.receipt(d.sale.id)),
          icon: const Icon(Icons.send, size: 26),
          label: const Text('Envoyer le reçu'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => context.push(Routes.editSale(d.sale.id)),
          icon: const Icon(Icons.edit, size: 26),
          label: const Text('Modifier'),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: AppColors.red),
          onPressed: remove,
          icon: const Icon(Icons.delete_outline, size: 26),
          label: const Text('Supprimer'),
        ),
      ],
    );
  }
}

import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/auth/session.dart';
import '../../../core/db/ledger_queries.dart';
import '../../../core/db/settings_store.dart';
import '../../../core/format/dates.dart';
import '../../../core/format/fcfa.dart';
import '../../../core/providers.dart';
import '../../../core/telemetry/telemetry.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/contact.dart';
import '../../sale/ui/sale_detail_screen.dart';

final shopPhoneProvider = FutureProvider.autoDispose<String?>((ref) async {
  ref.watch(ledgerChangesProvider);
  final settings = ref.read(settingsStoreProvider);
  return await settings.get(SettingKey.shopPhone) ??
      await settings.get(SettingKey.phone);
});

/// Texte du reçu (WhatsApp direct, et légende du partage).
String receiptText(SaleDetail d, String shop) {
  final items = d.articles.isEmpty
      ? 'Article'
      : d.articles
            .map((a) => '${a.article.name ?? 'Article'} ×${a.quantity}')
            .join(', ');
  final rest = d.rest > 0 ? ' Reste : ${formatFcfa(d.rest)}.' : '';
  return '$shop · ${formatDate(d.sale.soldAt)}\n$items\nMontant : ${formatFcfa(d.sale.amount)}. '
      'Reçu : ${formatFcfa(d.received)}.$rest\nMerci !';
}

/// Reçu : image partagée par Android, et WhatsApp direct si la personne a un numéro.
class ReceiptScreen extends ConsumerStatefulWidget {
  const ReceiptScreen({super.key, required this.saleId});
  final String saleId;

  @override
  ConsumerState<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends ConsumerState<ReceiptScreen> {
  final _boundary = GlobalKey();

  Future<void> _share(SaleDetail d, String shop) async {
    final render =
        _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await render.toImage(pixelRatio: 2.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    await ref
        .read(sharerProvider)
        .shareImage(
          bytes!.buffer.asUint8List(),
          name: 'recu-${d.sale.id.substring(0, 8)}',
          text: receiptText(d, shop),
        );
    trackWith(ref.read(telemetryProvider), 'receipt_sent');
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(saleDetailProvider(widget.saleId)).value;
    final phone = ref.watch(shopPhoneProvider).value;
    final shop = ref.watch(sessionProvider.select((s) => s.shopName)) ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Reçu')),
      body: detail == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                RepaintBoundary(
                  key: _boundary,
                  child: _ReceiptCard(detail: detail, shop: shop, phone: phone),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => _share(detail, shop),
                  icon: const Icon(Icons.send, size: 28),
                  label: const Text('Envoyer'),
                ),
                if (detail.person?.phone != null) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () {
                      trackWith(ref.read(telemetryProvider), 'receipt_sent');
                      ref.read(urlOpenerProvider)(
                        whatsAppUri(
                          detail.person!.phone!,
                          receiptText(detail, shop),
                        ),
                      );
                    },
                    icon: const Icon(Icons.chat, size: 26),
                    label: Text('WhatsApp ${detail.person!.name}'),
                  ),
                ],
              ],
            ),
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({required this.detail, required this.shop, this.phone});
  final SaleDetail detail;
  final String shop;
  final String? phone;

  @override
  Widget build(BuildContext context) {
    const label = TextStyle(fontSize: 19, color: AppColors.text);
    const strong = TextStyle(
      fontSize: 19,
      fontWeight: FontWeight.w800,
      color: AppColors.text,
    );
    Widget row(String a, String b, {TextStyle style = label}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(a, style: style)),
          Text(b, style: style),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDDDDD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            shop,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          if (phone != null)
            Text(phone!, textAlign: TextAlign.center, style: label),
          Text(
            formatDate(detail.sale.soldAt),
            textAlign: TextAlign.center,
            style: label,
          ),
          const Divider(height: 24),
          if (detail.articles.isEmpty)
            row('Article', formatFcfa(detail.sale.amount))
          else
            for (final a in detail.articles)
              row(
                '${a.article.name ?? 'Article'} ×${a.quantity}',
                formatFcfa(a.article.price * a.quantity),
              ),
          const Divider(height: 24),
          row('Montant', formatFcfa(detail.sale.amount), style: strong),
          row('Reçu', formatFcfa(detail.received)),
          if (detail.rest > 0)
            row(
              'Reste',
              formatFcfa(detail.rest),
              style: strong.copyWith(color: AppColors.red),
            ),
          const SizedBox(height: 12),
          const Text(
            'Merci !',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.green,
            ),
          ),
        ],
      ),
    );
  }
}

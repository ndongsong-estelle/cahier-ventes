import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/db/database.dart';
import '../../../core/db/ledger_queries.dart';
import '../../../core/db/ledger_repository.dart';
import '../../../core/format/fcfa.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/amount_pad.dart';
import '../../../core/ui/pay_dialog.dart';
import '../../../core/ui/sale_tile.dart';
import 'sell_dialogs.dart';

class SellData {
  const SellData(this.articles, this.people);
  final List<Article> articles;
  final List<Person> people;
}

final sellDataProvider = FutureProvider.autoDispose<SellData>((ref) async {
  final ledger = ref.read(ledgerProvider);
  return SellData(await ledger.articlesForSale(), await ledger.recentPeople());
});

enum _Paid { all, part, none }

/// J'ai vendu (écran le plus important).
class SellScreen extends ConsumerStatefulWidget {
  const SellScreen({super.key, this.saleId});

  /// Vente à modifier (null = nouvelle vente).
  final String? saleId;

  @override
  ConsumerState<SellScreen> createState() => _SellScreenState();
}

class _SellScreenState extends ConsumerState<SellScreen> {
  int _amount = 0;
  final Map<String, int> _tags = {};
  final List<Article> _known = [];
  String? _photo;
  final _name = TextEditingController();
  PayMethod _method = PayMethod.cash;
  bool _saving = false;

  int _received = 0;

  bool get _editing => widget.saleId != null;

  @override
  void initState() {
    super.initState();
    if (_editing) _load();
  }

  Future<void> _load() async {
    final d = await ref.read(ledgerProvider).saleDetail(widget.saleId!);
    if (d == null || !mounted) return;
    setState(() {
      _amount = d.sale.amount;
      _photo = d.sale.photoPath;
      _name.text = d.person?.name ?? '';
      _received = d.received;
      for (final a in d.articles) {
        if (_article(a.article.id) == null) _known.add(a.article);
        _tags[a.article.id] = (_tags[a.article.id] ?? 0) + a.quantity;
      }
    });
  }

  /// Modifier : un seul bouton "Garder". Les paiements se corrigent depuis le détail.
  Future<void> _saveEdit(List<Person> people) async {
    if (_amount <= 0 || _saving) return;
    var name = _name.text.trim();
    if (name.isEmpty && _received < _amount) {
      name = (await askWhoOwes(context, people))?.trim() ?? '';
      if (name.isEmpty) return;
    }
    setState(() => _saving = true);
    final ledger = ref.read(ledgerProvider);
    final id = widget.saleId!;
    final before = await ledger.snapshot(id);
    await ledger.updateSale(
      id,
      amount: _amount,
      personId: Value(name.isEmpty ? null : await ledger.personByName(name)),
      articles: [for (final e in _tags.entries) SoldArticle(e.key, e.value)],
    );
    if (_photo != before.sale.photoPath) await ledger.setSalePhoto(id, _photo);
    if (!mounted) return;
    showUndo(context, 'Vente modifiée', () => ledger.restoreSnapshot(before));
    context.pop();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Article? _article(String id) => _known.where((a) => a.id == id).firstOrNull;

  void _addArticle(Article a) {
    if (_article(a.id) == null) _known.add(a);
    setState(() {
      _tags[a.id] = (_tags[a.id] ?? 0) + 1;
      _amount += a.price;
    });
  }

  void _removeTag(String id) {
    final a = _article(id);
    final qty = _tags.remove(id) ?? 0;
    if (a == null) return;
    setState(() {
      final next = _amount - a.price * qty;
      _amount = next > 0 ? next : 0;
    });
  }

  Future<void> _pickPhoto({bool camera = false}) async {
    final photos = ref.read(photoServiceProvider);
    final path = await photos.pick(camera: camera);
    if (path == null || !mounted) return;
    final keep = await askKeepArticle(context, path, _amount);
    if (!mounted) return;
    if (keep == null) {
      final old = _photo;
      setState(() => _photo = path);
      if (old != null) await photos.delete(old);
      return;
    }
    final ledger = ref.read(ledgerProvider);
    final id = await ledger.addArticle(
      name: keep.name,
      price: keep.price,
      photoPath: path,
    );
    final article = (await ledger.article(id))!;
    _known.add(article);
    setState(() {
      _tags[id] = (_tags[id] ?? 0) + 1;
      if (_amount == 0) _amount = keep.price;
    });
    ref.invalidate(sellDataProvider);
  }

  Future<void> _save(_Paid paid, List<Person> people) async {
    if (_amount <= 0 || _saving) return;
    int? paidNow = switch (paid) {
      _Paid.all => _amount,
      _Paid.none => null,
      _Paid.part => await askReceived(context, _amount),
    };
    if (paid == _Paid.part && paidNow == null) return;
    var name = _name.text.trim();
    final owes = paidNow == null || paidNow < _amount;
    if (owes && name.isEmpty) {
      if (!mounted) return;
      name = (await askWhoOwes(context, people))?.trim() ?? '';
      if (name.isEmpty) return;
    }
    setState(() => _saving = true);
    final ledger = ref.read(ledgerProvider);
    final personId = name.isEmpty ? null : await ledger.personByName(name);
    final saleId = await ledger.addSale(
      amount: _amount,
      personId: personId,
      articles: [for (final e in _tags.entries) SoldArticle(e.key, e.value)],
      paidNow: paidNow,
      method: _method,
      photoPath: _photo,
    );
    if (!mounted) return;
    final photos = ref.read(photoServiceProvider);
    final photo = _photo;
    showUndo(context, 'Vente enregistrée', () async {
      await ledger.deleteSale(saleId);
      if (photo != null && !await ledger.photoInUse(photo)) {
        await photos.delete(photo);
      }
    });
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(sellDataProvider);
    final people = data.value?.people ?? const <Person>[];
    final articles = data.value?.articles ?? const <Article>[];
    for (final a in articles) {
      if (_article(a.id) == null) _known.add(a);
    }
    final typed = _name.text.trim().toLowerCase();
    final suggestions = people
        .where(
          (p) =>
              p.name.toLowerCase() != typed &&
              (typed.isEmpty || p.name.toLowerCase().contains(typed)),
        )
        .take(8)
        .toList();
    final enabled = _amount > 0 && !_saving;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  Row(
                    children: [
                      IconButton(
                        iconSize: 32,
                        tooltip: 'Annuler',
                        icon: const Icon(Icons.close),
                        onPressed: () => context.pop(),
                      ),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            formatFcfa(_amount),
                            key: const Key('sell-amount'),
                            style: const TextStyle(
                              fontSize: AppSizes.amountLarge,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                  if (_tags.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final e in _tags.entries)
                          InputChip(
                            label: Text(
                              '${_article(e.key)?.name ?? formatFcfa(_article(e.key)?.price ?? 0)} ×${e.value}',
                              style: const TextStyle(fontSize: 18),
                            ),
                            deleteButtonTooltipMessage: 'Retirer',
                            onDeleted: () => _removeTag(e.key),
                          ),
                      ],
                    ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 72,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        if (_photo != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Stack(
                              children: [
                                SaleThumb(photoPath: _photo, size: 68),
                                const Positioned(
                                  right: 2,
                                  top: 2,
                                  child: Icon(
                                    Icons.check_circle,
                                    color: AppColors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        for (final a in articles)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Tooltip(
                              message: a.name ?? formatFcfa(a.price),
                              child: InkWell(
                                key: Key('article-${a.id}'),
                                onTap: () => _addArticle(a),
                                child: a.photoPath != null
                                    ? SaleThumb(
                                        photoPath: a.photoPath,
                                        size: 68,
                                      )
                                    : Container(
                                        width: 68,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: AppColors.muted,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Text(
                                          a.name ?? formatFcfa(a.price),
                                          maxLines: 3,
                                          textAlign: TextAlign.center,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(68, 68),
                          ),
                          onPressed: () => _pickPhoto(),
                          icon: const Icon(Icons.add_photo_alternate, size: 28),
                          label: const Text('Photo'),
                        ),
                        IconButton(
                          tooltip: 'Appareil photo',
                          iconSize: 30,
                          onPressed: () => _pickPhoto(camera: true),
                          icon: const Icon(Icons.photo_camera),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    style: const TextStyle(fontSize: 20),
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.person),
                      hintText: 'Nom (facultatif)',
                      isDense: true,
                    ),
                  ),
                  if (suggestions.isNotEmpty)
                    SizedBox(
                      height: 52,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final p in suggestions)
                            Padding(
                              padding: const EdgeInsets.only(right: 6, top: 4),
                              child: ActionChip(
                                label: Text(
                                  p.name,
                                  style: const TextStyle(fontSize: 18),
                                ),
                                onPressed: () =>
                                    setState(() => _name.text = p.name),
                              ),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final m in PayMethod.values)
                        ChoiceChip(
                          label: Text(
                            m.label,
                            style: const TextStyle(fontSize: 18),
                          ),
                          selected: _method == m,
                          onSelected: (_) => setState(() => _method = m),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: AmountPad(
                value: _amount,
                keyHeight: 54,
                onChanged: (v) => setState(() => _amount = v),
              ),
            ),
            if (_editing)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                child: Row(
                  children: [
                    _ActionButton(
                      label: 'Garder',
                      icon: Icons.check,
                      color: AppColors.green,
                      onPressed: enabled ? () => _saveEdit(people) : null,
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                child: Row(
                  children: [
                    _ActionButton(
                      label: 'PAYÉ',
                      icon: Icons.check,
                      color: AppColors.green,
                      onPressed: enabled
                          ? () => _save(_Paid.all, people)
                          : null,
                    ),
                    _ActionButton(
                      label: 'UNE PARTIE',
                      color: AppColors.orangeText,
                      onPressed: enabled
                          ? () => _save(_Paid.part, people)
                          : null,
                    ),
                    _ActionButton(
                      label: 'PAS ENCORE',
                      color: AppColors.red,
                      onPressed: enabled
                          ? () => _save(_Paid.none, people)
                          : null,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.color,
    this.icon,
    this.onPressed,
  });
  final String label;
  final Color color;
  final IconData? icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          minimumSize: const Size(48, AppSizes.mainButtonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
        onPressed: onPressed,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 4),
                Icon(icon, size: 24),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

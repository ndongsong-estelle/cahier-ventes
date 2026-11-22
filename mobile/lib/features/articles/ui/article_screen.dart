import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/db/database.dart';
import '../../../core/db/ledger_queries.dart';
import '../../../core/format/fcfa.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/pay_dialog.dart';
import '../articles_providers.dart';
import 'article_tile.dart';

/// "+ Ajouter un article" (articleId null) ou fiche article.
class ArticleScreen extends ConsumerStatefulWidget {
  const ArticleScreen({super.key, this.articleId});
  final String? articleId;

  @override
  ConsumerState<ArticleScreen> createState() => _ArticleScreenState();
}

class _ArticleScreenState extends ConsumerState<ArticleScreen> {
  final _price = TextEditingController();
  final _name = TextEditingController();
  String? _photo;
  bool _loaded = false;
  String? _error;

  bool get _isNew => widget.articleId == null;

  @override
  void dispose() {
    _price.dispose();
    _name.dispose();
    super.dispose();
  }

  void _fill(Article a) {
    if (_loaded) return;
    _loaded = true;
    _price.text = '${a.price}';
    _name.text = a.name ?? '';
    _photo = a.photoPath;
  }

  Future<void> _pick({bool camera = false}) async {
    final path = await ref.read(photoServiceProvider).pick(camera: camera);
    if (path != null && mounted) setState(() => _photo = path);
  }

  Future<void> _save(Article? before) async {
    final price = parseFcfa(_price.text) ?? 0;
    if (price <= 0) {
      setState(() => _error = 'Écrivez le prix.');
      return;
    }
    final ledger = ref.read(ledgerProvider);
    final name = _name.text.trim();
    if (before == null) {
      await ledger.addArticle(name: name, price: price, photoPath: _photo);
      if (!mounted) return;
      context.pop();
      return;
    }
    await ledger.updateArticle(
      before.id,
      ArticlesCompanion(
        price: Value(price),
        name: Value(name.isEmpty ? null : name),
        photoPath: Value(_photo),
      ),
    );
    final oldPhoto = before.photoPath;
    if (oldPhoto != null &&
        oldPhoto != _photo &&
        !await ledger.photoInUse(oldPhoto)) {
      await ref.read(photoServiceProvider).delete(oldPhoto);
    }
    if (!mounted) return;
    showUndo(
      context,
      'Article modifié',
      () => ledger.updateArticle(
        before.id,
        ArticlesCompanion(
          price: Value(before.price),
          name: Value(before.name),
          photoPath: Value(before.photoPath),
        ),
      ),
    );
    context.pop();
  }

  Future<void> _setRemaining(Article a, int? value) => ref
      .read(ledgerProvider)
      .updateArticle(a.id, ArticlesCompanion(remaining: Value(value)));

  Future<void> _hide(Article a) async {
    final ledger = ref.read(ledgerProvider);
    await ledger.updateArticle(
      a.id,
      const ArticlesCompanion(hidden: Value(true)),
    );
    if (!mounted) return;
    showUndo(
      context,
      "L'article n'est plus affiché",
      () => ledger.updateArticle(
        a.id,
        const ArticlesCompanion(hidden: Value(false)),
      ),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final article = _isNew
        ? null
        : ref.watch(articleProvider(widget.articleId!)).value;
    if (article != null) _fill(article);
    if (!_isNew && article == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final preview = Article(
      id: article?.id ?? 'new',
      name: _name.text.trim().isEmpty ? null : _name.text.trim(),
      price: parseFcfa(_price.text) ?? 0,
      photoPath: _photo,
      remaining: article?.remaining,
      hidden: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isNew ? 'Ajouter un article' : (article!.name ?? 'Article'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: SizedBox(
              width: 220,
              height: 220,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: _pick,
                  child: ArticlePicture(article: preview),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _pick,
                icon: const Icon(Icons.add_photo_alternate, size: 28),
                label: const Text('Photo'),
              ),
              IconButton(
                tooltip: 'Appareil photo',
                iconSize: 30,
                onPressed: () => _pick(camera: true),
                icon: const Icon(Icons.photo_camera),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _price,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
            onChanged: (_) => setState(() => _error = null),
            decoration: InputDecoration(
              labelText: 'Prix',
              suffixText: 'F',
              errorText: _error,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 22),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Nom (facultatif)'),
          ),
          if (article != null) ...[
            const SizedBox(height: 20),
            const Text(
              'Il en reste combien ?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.outlined(
                  tooltip: 'Un de moins',
                  iconSize: 32,
                  onPressed:
                      article.remaining == null || article.remaining! <= 0
                      ? null
                      : () => _setRemaining(article, article.remaining! - 1),
                  icon: const Icon(Icons.remove),
                ),
                SizedBox(
                  width: 100,
                  child: Text(
                    article.remaining == null ? '—' : '${article.remaining}',
                    key: const Key('remaining'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton.outlined(
                  tooltip: 'Un de plus',
                  iconSize: 32,
                  onPressed: () => _setRemaining(
                    article,
                    (article.remaining == null || article.remaining! < 0
                            ? 0
                            : article.remaining!) +
                        1,
                  ),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            Center(child: StockBadge(remaining: article.remaining)),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => _save(article),
            icon: const Icon(Icons.check, size: 28),
            label: const Text('Garder'),
          ),
          if (article != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: AppColors.red),
              onPressed: () => _hide(article),
              icon: const Icon(Icons.visibility_off, size: 26),
              label: const Text('Ne plus afficher'),
            ),
          ],
        ],
      ),
    );
  }
}

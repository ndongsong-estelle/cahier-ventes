import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/router.dart';
import '../../../core/ui/settings_button.dart';
import '../articles_providers.dart';
import 'article_tile.dart';

/// Mes articles : grille de grandes photos, les plus vendus d'abord.
class ArticlesScreen extends ConsumerWidget {
  const ArticlesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final articles = ref.watch(articlesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes articles'),
        actions: const [SettingsButton()],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: SizedBox(
        height: 64,
        child: FloatingActionButton.extended(
          heroTag: null,
          onPressed: () => context.push(Routes.newArticle),
          icon: const Icon(Icons.add, size: 30),
          label: const Text(
            'Ajouter un article',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ),
      ),
      body: articles.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) => list.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Ajoutez vos articles avec une photo et un prix : ils seront prêts dans J\'ai vendu.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20),
                ),
              )
            : GridView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 110),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 200,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.72,
                ),
                itemCount: list.length,
                itemBuilder: (context, i) => ArticleTile(
                  article: list[i],
                  onTap: () => context.push(Routes.article(list[i].id)),
                ),
              ),
      ),
    );
  }
}

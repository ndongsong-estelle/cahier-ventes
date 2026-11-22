import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../../../core/db/database.dart';
import '../../../core/domain/ledger.dart';
import '../../../core/format/fcfa.dart';
import '../../../core/theme/app_theme.dart';

const _tileColors = [
  Color(0xFF2E7D32),
  Color(0xFF1565C0),
  Color(0xFF6A1B9A),
  Color(0xFF00838F),
  Color(0xFF4E342E),
  Color(0xFFAD1457),
];

String initials(String? name) {
  final words = (name ?? '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return '?';
  return words.take(2).map((w) => w.characters.first.toUpperCase()).join();
}

/// Grande photo (ou tuile colorée avec initiales) d'un article.
class ArticlePicture extends StatelessWidget {
  const ArticlePicture({super.key, required this.article});
  final Article article;

  @override
  Widget build(BuildContext context) {
    final path = article.photoPath;
    if (path != null && File(path).existsSync()) {
      return Image.file(File(path), fit: BoxFit.cover, cacheWidth: 400);
    }
    final color =
        _tileColors[(article.name ?? article.id).hashCode.abs() %
            _tileColors.length];
    return ColoredBox(
      color: color,
      child: Center(
        child: Text(
          initials(article.name),
          style: const TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Pastille "Plus que 2" (orange) ou "Épuisé" (rouge).
class StockBadge extends StatelessWidget {
  const StockBadge({super.key, required this.remaining});
  final int? remaining;

  @override
  Widget build(BuildContext context) {
    final level = stockLevel(remaining);
    if (level != StockLevel.low && level != StockLevel.out) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: level == StockLevel.out ? AppColors.red : AppColors.orange,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        stockLabel(remaining)!,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

class ArticleTile extends StatelessWidget {
  const ArticleTile({super.key, required this.article, this.onTap});
  final Article article;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ArticlePicture(article: article),
                  Positioned(
                    left: 6,
                    top: 6,
                    child: StockBadge(remaining: article.remaining),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatFcfa(article.price),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          if (article.name != null)
            Text(
              article.name!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17, color: AppColors.muted),
            ),
        ],
      ),
    );
  }
}

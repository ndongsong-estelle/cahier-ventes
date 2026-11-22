import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../db/ledger_queries.dart';
import '../domain/ledger.dart';
import '../format/dates.dart';
import '../format/fcfa.dart';
import '../theme/app_theme.dart';

/// Couleur d'un état : vert = reçu, rouge = on vous doit, orange = une partie.
Color statusColor(SaleStatus s) => switch (s) {
  SaleStatus.paid => AppColors.green,
  SaleStatus.partial => AppColors.orange,
  SaleStatus.unpaid => AppColors.red,
};

/// Pastille + texte court ("Payé", "Doit 10 000 F").
class StatusLabel extends StatelessWidget {
  const StatusLabel({super.key, required this.status, required this.rest});
  final SaleStatus status;
  final int rest;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    final textColor = status == SaleStatus.partial
        ? AppColors.orangeText
        : color;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 14, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            status == SaleStatus.paid ? 'Payé' : 'Doit ${formatFcfa(rest)}',
            style: TextStyle(
              fontSize: AppSizes.bodyText,
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

/// Petite image d'une vente (photo, sinon icône).
class SaleThumb extends StatelessWidget {
  const SaleThumb({super.key, this.photoPath, this.size = 52});
  final String? photoPath;
  final double size;

  @override
  Widget build(BuildContext context) {
    final path = photoPath;
    final file = path == null ? null : File(path);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: size,
        height: size,
        child: file != null && file.existsSync()
            ? Image.file(file, fit: BoxFit.cover, cacheWidth: 160)
            : const ColoredBox(
                color: Color(0xFFE8EDE9),
                child: Icon(
                  Icons.shopping_basket,
                  color: AppColors.green,
                  size: 28,
                ),
              ),
      ),
    );
  }
}

class SaleTile extends StatelessWidget {
  const SaleTile({
    super.key,
    required this.item,
    this.onTap,
    this.showDate = false,
  });
  final SaleItem item;
  final VoidCallback? onTap;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            SaleThumb(photoPath: item.photoPath),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  StatusLabel(status: item.status, rest: item.rest),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 130),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      formatFcfa(item.amount),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    showDate ? formatDay(item.soldAt) : formatTime(item.soldAt),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.muted,
                    ),
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

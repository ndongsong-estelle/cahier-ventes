import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/db/ledger_queries.dart';
import '../../../core/format/dates.dart';
import '../../../core/format/fcfa.dart';
import '../../../core/router/router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/sale_tile.dart';
import '../../../core/ui/sell_button.dart';
import '../../../core/ui/settings_button.dart';
import '../questions.dart';
import '../today_providers.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(shownDayProvider);
    final summary = ref.watch(daySummaryProvider(day));
    final now = DateTime.now();
    final isToday = sameDay(day, now);

    void shift(int days) {
      final next = DateTime(day.year, day.month, day.day + days);
      if (next.isAfter(now)) return;
      ref.read(shownDayProvider.notifier).set(next);
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            IconButton(
              iconSize: 34,
              tooltip: 'Jour d\'avant',
              icon: const Icon(Icons.chevron_left),
              onPressed: () => shift(-1),
            ),
            Expanded(
              child: Text(
                formatDay(day),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              iconSize: 34,
              tooltip: 'Jour d\'après',
              icon: const Icon(Icons.chevron_right),
              onPressed: isToday ? null : () => shift(1),
            ),
          ],
        ),
        actions: const [SettingsButton()],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: const SellButton(),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v > 300) shift(-1);
          if (v < -300) shift(1);
        },
        child: summary.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (s) => _DayView(summary: s, isToday: isToday),
        ),
      ),
    );
  }
}

class _DayView extends StatelessWidget {
  const _DayView({required this.summary, required this.isToday});
  final DaySummary summary;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 110),
      children: [
        if (isToday) const QuestionCard(),
        InkWell(
          onTap: () => context.push(Routes.bilan),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Column(
              children: [
                FittedBox(
                  child: Text(
                    formatFcfa(summary.sold),
                    style: const TextStyle(
                      fontSize: AppSizes.amountLarge,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  isToday ? "vendus aujourd'hui" : 'vendus ce jour-là',
                  style: const TextStyle(fontSize: 20, color: AppColors.muted),
                ),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    _Dot(
                      color: AppColors.green,
                      text: 'Reçu ${formatFcfa(summary.received)}',
                    ),
                    _Dot(
                      color: AppColors.red,
                      text: 'On vous doit ${formatFcfa(summary.owed)}',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        if (summary.sales.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 0),
            child: Column(
              children: [
                Text(
                  isToday
                      ? "Pas encore de vente aujourd'hui. Touchez J'ai vendu."
                      : 'Pas de vente ce jour-là.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20),
                ),
                if (isToday) ...[
                  const SizedBox(height: 16),
                  const Icon(
                    Icons.arrow_downward,
                    size: 56,
                    color: AppColors.green,
                  ),
                ],
              ],
            ),
          )
        else
          for (final item in summary.sales)
            SaleTile(
              item: item,
              onTap: () => context.push(Routes.saleDetail(item.id)),
            ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.text});
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.circle, size: 14, color: color),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: AppSizes.bodyText,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}

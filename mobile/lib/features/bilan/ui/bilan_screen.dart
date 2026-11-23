import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/db/ledger_queries.dart';
import '../../../core/domain/ledger.dart';
import '../../../core/format/fcfa.dart';
import '../../../core/providers.dart';
import '../../../core/telemetry/telemetry.dart';
import '../../../core/theme/app_theme.dart';
import '../../articles/ui/article_tile.dart';

enum BilanKind { week, month }

final bilanProvider = FutureProvider.autoDispose
    .family<PeriodReport, BilanKind>((ref, kind) {
      ref.watch(ledgerChangesProvider);
      final ledger = ref.read(ledgerProvider);
      final now = ledger.now;
      return switch (kind) {
        BilanKind.week => ledger.report(weekOf(now), previousWeek(weekOf(now))),
        BilanKind.month => ledger.report(
          monthOf(now),
          previousMonth(monthOf(now)),
        ),
      };
    });

/// Bilan : Cette semaine / Ce mois.
class BilanScreen extends ConsumerStatefulWidget {
  const BilanScreen({super.key});

  @override
  ConsumerState<BilanScreen> createState() => _BilanScreenState();
}

class _BilanScreenState extends ConsumerState<BilanScreen> {
  @override
  void initState() {
    super.initState();
    trackWith(ref.read(telemetryProvider), 'summary_opened', {
      'period': 'week',
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bilan'),
          bottom: TabBar(
            onTap: (i) => trackWith(
              ref.read(telemetryProvider),
              'summary_opened',
              {'period': i == 0 ? 'week' : 'month'},
            ),
            labelStyle: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            tabs: [
              Tab(text: 'Cette semaine'),
              Tab(text: 'Ce mois'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_Report(BilanKind.week), _Report(BilanKind.month)],
        ),
      ),
    );
  }
}

class _Report extends ConsumerWidget {
  const _Report(this.kind);
  final BilanKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(bilanProvider(kind));
    return report.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (r) {
        final diff = r.sold - r.previousSold;
        final before = kind == BilanKind.week
            ? 'à la semaine dernière'
            : 'au mois dernier';
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  formatFcfa(r.sold),
                  style: const TextStyle(
                    fontSize: AppSizes.amountLarge,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const Center(
              child: Text(
                'vendus',
                style: TextStyle(fontSize: 20, color: AppColors.muted),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  diff >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                  color: diff >= 0 ? AppColors.green : AppColors.red,
                  size: 28,
                  semanticLabel: diff >= 0 ? 'plus' : 'moins',
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '${diff >= 0 ? '+' : '-'}${formatFcfa(diff.abs())} par rapport $before',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: diff >= 0 ? AppColors.green : AppColors.red,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _Line(color: AppColors.green, label: 'Reçu', amount: r.received),
            _Line(color: AppColors.red, label: 'On vous doit', amount: r.owed),
            const SizedBox(height: 16),
            if (r.top.isNotEmpty) ...[
              const Text(
                'Les plus vendus',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              for (final t in r.top)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: SizedBox(
                    width: 56,
                    height: 56,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: ArticlePicture(article: t.article),
                    ),
                  ),
                  title: Text(
                    t.article.name ?? formatFcfa(t.article.price),
                    style: const TextStyle(fontSize: 20),
                  ),
                  trailing: Text(
                    '×${t.quantity}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.color, required this.label, required this.amount});
  final Color color;
  final String label;
  final int amount;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(Icons.circle, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 21))),
        Text(
          formatFcfa(amount),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}

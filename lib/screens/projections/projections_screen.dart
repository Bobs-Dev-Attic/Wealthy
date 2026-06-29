import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../models/projection_result.dart';
import '../../services/engine/tax.dart';
import '../../state/providers.dart';
import '../../widgets/app_scaffold.dart';

class ProjectionsScreen extends ConsumerWidget {
  const ProjectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(planDataProvider);
    return AppScaffold(
      title: 'Projections',
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (d) {
          if (d.accounts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Add accounts and expenses to see projections.',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                        onPressed: () => context.go('/accounts'),
                        child: const Text('Add accounts')),
                  ],
                ),
              ),
            );
          }
          final p = ref.watch(projectionProvider);
          if (p == null) return const Center(child: CircularProgressIndicator());
          return PageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SuccessHeader(result: p),
                SectionCard(
                  title: 'Portfolio over time (Monte Carlo, ${p.monteCarlo.runs} runs)',
                  child: SizedBox(height: 260, child: _BandChart(mc: p.monteCarlo)),
                ),
                SectionCard(
                  title: 'Ending balance range (age ${p.ledger.isNotEmpty ? p.ledger.last.age : ''})',
                  child: Column(
                    children: [
                      _row('Pessimistic (10th pct)', money(p.monteCarlo.endingP10)),
                      _row('Median (50th pct)', money(p.monteCarlo.endingP50)),
                      _row('Optimistic (90th pct)', money(p.monteCarlo.endingP90)),
                    ],
                  ),
                ),
                SectionCard(
                  title: 'Year by year (expected returns)',
                  child: _LedgerTable(ledger: p.ledger),
                ),
                const SizedBox(height: 8),
                Text(
                  'Estimates only — not tax or financial advice. Federal tax model uses '
                  '${TaxEngine.taxYear} brackets; state tax is not modeled.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
      );
}

class _SuccessHeader extends StatelessWidget {
  const _SuccessHeader({required this.result});
  final ProjectionResult result;

  @override
  Widget build(BuildContext context) {
    final rate = result.monteCarlo.successRate;
    final color = rate >= 0.85
        ? Colors.greenAccent
        : rate >= 0.6
            ? Colors.amberAccent
            : Colors.redAccent;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: rate,
                    strokeWidth: 7,
                    color: color,
                    backgroundColor: Colors.white12,
                  ),
                  Text(percent(rate), style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Plan success rate',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    rate >= 0.85
                        ? 'Strong — your plan survives most market scenarios.'
                        : rate >= 0.6
                            ? 'Borderline — consider lower spending or later retirement.'
                            : 'At risk — spending likely outpaces your assets.',
                  ),
                  if (result.depletionAge != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Expected case depletes at age ${result.depletionAge}.',
                          style: const TextStyle(color: Colors.amberAccent)),
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

class _BandChart extends StatelessWidget {
  const _BandChart({required this.mc});
  final MonteCarloResult mc;

  List<FlSpot> _spots(List<double> band) =>
      [for (var i = 0; i < band.length; i++) FlSpot(mc.ages[i].toDouble(), band[i])];

  @override
  Widget build(BuildContext context) {
    if (mc.ages.isEmpty) return const SizedBox();
    final maxY = mc.bandP90.fold(0.0, (m, v) => v > m ? v : m);
    return LineChart(
      LineChartData(
        minX: mc.ages.first.toDouble(),
        maxX: mc.ages.last.toDouble(),
        minY: 0,
        maxY: maxY == 0 ? 1 : maxY * 1.1,
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (v, _) => Text(moneyCompact(v),
                  style: const TextStyle(fontSize: 9)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: ((mc.ages.last - mc.ages.first) / 6).ceilToDouble().clamp(1, 100),
              getTitlesWidget: (v, _) =>
                  Text(v.toInt().toString(), style: const TextStyle(fontSize: 9)),
            ),
          ),
        ),
        lineBarsData: [
          _line(_spots(mc.bandP90), Colors.greenAccent.withValues(alpha: 0.7)),
          _line(_spots(mc.bandP50), Theme.of(context).colorScheme.primary, width: 3),
          _line(_spots(mc.bandP10), Colors.redAccent.withValues(alpha: 0.7)),
        ],
      ),
    );
  }

  LineChartBarData _line(List<FlSpot> spots, Color color, {double width = 2}) => LineChartBarData(
        spots: spots,
        isCurved: true,
        color: color,
        barWidth: width,
        dotData: const FlDotData(show: false),
      );
}

class _LedgerTable extends StatelessWidget {
  const _LedgerTable({required this.ledger});
  final List<YearLedger> ledger;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 36,
        dataRowMinHeight: 32,
        dataRowMaxHeight: 40,
        columns: const [
          DataColumn(label: Text('Age')),
          DataColumn(label: Text('Soc. Sec.')),
          DataColumn(label: Text('Other inc.')),
          DataColumn(label: Text('RMD')),
          DataColumn(label: Text('Spending')),
          DataColumn(label: Text('Withdrawal')),
          DataColumn(label: Text('WR')),
          DataColumn(label: Text('Taxes')),
          DataColumn(label: Text('End balance')),
        ],
        rows: [
          for (final y in ledger)
            DataRow(
              color: y.shortfall
                  ? WidgetStatePropertyAll(Colors.red.withValues(alpha: 0.12))
                  : null,
              cells: [
                DataCell(Text('${y.age}')),
                DataCell(Text(money(y.socialSecurity))),
                DataCell(Text(money(y.otherIncome))),
                DataCell(Text(money(y.requiredRmd))),
                DataCell(Text(money(y.spending))),
                DataCell(Text(money(y.grossWithdrawal))),
                DataCell(Text(percent(y.withdrawalRate))),
                DataCell(Text(money(y.taxes))),
                DataCell(Text(money(y.endPortfolio))),
              ],
            ),
        ],
      ),
    );
  }
}

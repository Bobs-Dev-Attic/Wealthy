import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../models/projection_result.dart';

Color successColor(double rate) {
  if (rate >= 0.85) return Colors.greenAccent;
  if (rate >= 0.6) return Colors.amberAccent;
  return Colors.redAccent;
}

/// A compact labeled metric tile.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, this.icon, this.color});
  final String label;
  final String value;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: color ?? Theme.of(context).colorScheme.primary),
              const SizedBox(height: 6),
            ],
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 2),
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}

/// Circular success-rate gauge with a short verdict.
class SuccessGauge extends StatelessWidget {
  const SuccessGauge({super.key, required this.rate, this.depletionAge});
  final double rate;
  final int? depletionAge;

  @override
  Widget build(BuildContext context) {
    final color = successColor(rate);
    return Row(
      children: [
        SizedBox(
          width: 72,
          height: 72,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: rate.clamp(0, 1),
                strokeWidth: 8,
                color: color,
                backgroundColor: Colors.white12,
              ),
              Text(percent(rate), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Plan success rate', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(rate >= 0.85
                  ? 'Strong — survives most market scenarios.'
                  : rate >= 0.6
                      ? 'Borderline — consider spending less or retiring later.'
                      : 'At risk — spending likely outpaces your assets.'),
              if (depletionAge != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Expected case depletes at age $depletionAge.',
                      style: const TextStyle(color: Colors.amberAccent, fontSize: 12)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Monte Carlo percentile bands of portfolio balance over time.
class BandChart extends StatelessWidget {
  const BandChart({super.key, required this.mc});
  final MonteCarloResult mc;

  List<FlSpot> _spots(List<double> band) =>
      [for (var i = 0; i < band.length && i < mc.ages.length; i++) FlSpot(mc.ages[i].toDouble(), band[i])];

  @override
  Widget build(BuildContext context) {
    if (mc.ages.isEmpty) return const Center(child: Text('—'));
    final maxY = mc.bandP90.fold(0.0, (m, v) => v > m ? v : m);
    return LineChart(
      LineChartData(
        minX: mc.ages.first.toDouble(),
        maxX: mc.ages.last.toDouble(),
        minY: 0,
        maxY: maxY <= 0 ? 1 : maxY * 1.1,
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: _titles(maxY <= 0 ? 1 : maxY * 1.1),
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

/// Net worth (assets minus debt) over time from the deterministic plan.
class NetWorthChart extends StatelessWidget {
  const NetWorthChart({super.key, required this.ledger});
  final List<YearLedger> ledger;

  @override
  Widget build(BuildContext context) {
    if (ledger.isEmpty) return const Center(child: Text('Add an age and some accounts to see this.'));
    final spots = [for (final y in ledger) FlSpot(y.age.toDouble(), y.netWorth)];
    final maxY = ledger.fold(0.0, (m, y) => y.netWorth > m ? y.netWorth : m);
    final minY = ledger.fold(0.0, (m, y) => y.netWorth < m ? y.netWorth : m);
    return LineChart(
      LineChartData(
        minX: ledger.first.age.toDouble(),
        maxX: ledger.last.age.toDouble(),
        minY: minY < 0 ? minY * 1.1 : 0,
        maxY: maxY <= 0 ? 1 : maxY * 1.1,
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: _titles(maxY <= 0 ? 1 : maxY * 1.1),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Theme.of(context).colorScheme.primary,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

FlTitlesData _titles(double maxY) => FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 64,
          getTitlesWidget: (v, _) =>
              Text(money(v), style: const TextStyle(fontSize: 9)),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 22,
          getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 9)),
        ),
      ),
    );

/// Scrollable year-by-year ledger table.
class LedgerTable extends StatelessWidget {
  const LedgerTable({super.key, required this.ledger});
  final List<YearLedger> ledger;

  @override
  Widget build(BuildContext context) {
    if (ledger.isEmpty) return const Center(child: Text('—'));
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 34,
        dataRowMinHeight: 30,
        dataRowMaxHeight: 38,
        columns: const [
          DataColumn(label: Text('Age')),
          DataColumn(label: Text('Soc.Sec.')),
          DataColumn(label: Text('Other inc.')),
          DataColumn(label: Text('RMD')),
          DataColumn(label: Text('Spending')),
          DataColumn(label: Text('Withdrawal')),
          DataColumn(label: Text('Taxes')),
          DataColumn(label: Text('Portfolio')),
          DataColumn(label: Text('Debt')),
          DataColumn(label: Text('Net worth')),
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
                DataCell(Text(money(y.taxes))),
                DataCell(Text(money(y.endPortfolio))),
                DataCell(Text(money(y.liabilityBalance))),
                DataCell(Text(money(y.netWorth))),
              ],
            ),
        ],
      ),
    );
  }
}

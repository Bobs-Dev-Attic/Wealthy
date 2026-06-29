import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../models/enums.dart';
import '../../state/plan_controller.dart';
import '../../state/projection_controller.dart';
import '../../widgets/result_widgets.dart';

const _pad = EdgeInsets.fromLTRB(16, 14, 16, 24);

/// Overview tiles + success gauge.
class SummaryView extends ConsumerWidget {
  const SummaryView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(projectionControllerProvider);
    final s = ref.watch(planControllerProvider);
    final mc = p?.monteCarlo;
    return ListView(
      padding: _pad,
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.1,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            StatTile(label: 'Net worth', value: money(s.netWorth), icon: Icons.account_balance_wallet_outlined),
            StatTile(
              label: 'Plan success',
              value: mc == null ? '—' : percent(mc.successRate),
              icon: Icons.verified_outlined,
              color: mc == null ? null : successColor(mc.successRate),
            ),
            StatTile(label: 'Assets', value: money(s.totalAssets), icon: Icons.savings_outlined),
            StatTile(label: 'Debts', value: money(s.totalLiabilities), icon: Icons.credit_card_outlined),
            StatTile(
                label: 'First-yr withdrawal',
                value: p == null ? '—' : percent(p.firstYearWithdrawalRate),
                icon: Icons.percent_outlined),
            StatTile(
                label: 'Median ending',
                value: mc == null ? '—' : money(mc.endingP50),
                icon: Icons.flag_outlined),
          ],
        ),
        const SizedBox(height: 12),
        if (mc != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SuccessGauge(rate: mc.successRate, depletionAge: p?.depletionAge),
            ),
          ),
        const SizedBox(height: 8),
        const _Disclaimer(),
      ],
    );
  }
}

/// Net worth over time.
class NetWorthView extends ConsumerWidget {
  const NetWorthView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(projectionControllerProvider);
    final s = ref.watch(planControllerProvider);
    return ListView(
      padding: _pad,
      children: [
        _ChartCard(
          title: 'Net worth over time',
          height: 240,
          child: NetWorthChart(ledger: p?.ledger ?? const []),
        ),
        Row(children: [
          Expanded(child: StatTile(label: 'Assets today', value: money(s.totalAssets))),
          const SizedBox(width: 8),
          Expanded(child: StatTile(label: 'Debts today', value: money(s.totalLiabilities))),
          const SizedBox(width: 8),
          Expanded(child: StatTile(label: 'Net worth', value: money(s.netWorth))),
        ]),
      ],
    );
  }
}

/// Monte Carlo retirement outlook.
class RetirementView extends ConsumerWidget {
  const RetirementView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(projectionControllerProvider);
    if (p == null) return const _Empty('Add an age and accounts to run projections.');
    final mc = p.monteCarlo;
    return ListView(
      padding: _pad,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SuccessGauge(rate: mc.successRate, depletionAge: p.depletionAge),
          ),
        ),
        _ChartCard(
          title: 'Portfolio range — ${mc.runs} simulations',
          height: 230,
          child: BandChart(mc: mc),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _row('Pessimistic (10th pct)', money(mc.endingP10)),
              _row('Median (50th pct)', money(mc.endingP50)),
              _row('Optimistic (90th pct)', money(mc.endingP90)),
            ]),
          ),
        ),
      ],
    );
  }
}

/// Year-by-year cash flow ledger.
class CashFlowView extends ConsumerWidget {
  const CashFlowView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(projectionControllerProvider);
    if (p == null || p.ledger.isEmpty) return const _Empty('Add inputs to see year-by-year cash flow.');
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: LedgerTable(ledger: p.ledger),
        ),
      ),
    );
  }
}

/// Tax estimate over time.
class TaxesView extends ConsumerWidget {
  const TaxesView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(projectionControllerProvider);
    if (p == null || p.ledger.isEmpty) return const _Empty('Add income and accounts to estimate taxes.');
    final lifetime = p.ledger.fold(0.0, (s, y) => s + y.taxes);
    final spots = [for (final y in p.ledger) FlSpot(y.age.toDouble(), y.taxes)];
    final maxY = p.ledger.fold(0.0, (m, y) => y.taxes > m ? y.taxes : m);
    return ListView(
      padding: _pad,
      children: [
        Row(children: [
          Expanded(child: StatTile(label: 'Lifetime taxes (est.)', value: money(lifetime))),
          const SizedBox(width: 8),
          Expanded(child: StatTile(label: 'First-year tax', value: money(p.ledger.first.taxes))),
        ]),
        _ChartCard(
          title: 'Estimated federal tax by year',
          height: 220,
          child: _SimpleLine(spots: spots, maxY: maxY, color: Colors.orangeAccent),
        ),
        const _Disclaimer(),
      ],
    );
  }
}

/// Required Minimum Distributions.
class RmdView extends ConsumerWidget {
  const RmdView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(projectionControllerProvider);
    if (p == null || p.ledger.isEmpty) return const _Empty('Add a traditional/401(k)/IRA balance to see RMDs.');
    final withRmd = p.ledger.where((y) => y.requiredRmd > 0).toList();
    final firstRmd = withRmd.isEmpty ? null : withRmd.first;
    final spots = [for (final y in p.ledger) FlSpot(y.age.toDouble(), y.requiredRmd)];
    final maxY = p.ledger.fold(0.0, (m, y) => y.requiredRmd > m ? y.requiredRmd : m);
    return ListView(
      padding: _pad,
      children: [
        Row(children: [
          Expanded(
              child: StatTile(
                  label: 'First RMD',
                  value: firstRmd == null ? 'None' : '${money(firstRmd.requiredRmd)} @ ${firstRmd.age}')),
          const SizedBox(width: 8),
          Expanded(
              child: StatTile(
                  label: 'RMD starts at age', value: firstRmd == null ? '—' : '${firstRmd.age}')),
        ]),
        _ChartCard(
          title: 'Required minimum distributions',
          height: 220,
          child: _SimpleLine(spots: spots, maxY: maxY, color: Colors.purpleAccent),
        ),
        const _Disclaimer(),
      ],
    );
  }
}

/// Healthcare costs over time (derived from healthcare expenses).
class HealthcareView extends ConsumerWidget {
  const HealthcareView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(planControllerProvider);
    final now = DateTime.now();
    final startAge = s.profile.currentAge(now);
    final endAge = s.profile.lifeExpectancy;
    final hc = s.expenses.where((e) => e.category == ExpenseCategory.healthcare).toList();
    if (hc.isEmpty) {
      return const _Empty('Add a healthcare expense to project medical costs (it grows at healthcare inflation).');
    }
    final spots = <FlSpot>[];
    double maxY = 0;
    for (var age = startAge; age <= endAge; age++) {
      final t = age - startAge;
      double cost = 0;
      for (final e in hc) {
        if (e.activeAt(age, retirementAge: s.profile.retirementAge)) {
          cost += e.annualAmount * math.pow(1 + s.assumptions.healthcareInflation, t);
        }
      }
      spots.add(FlSpot(age.toDouble(), cost));
      maxY = math.max(maxY, cost);
    }
    final total = hc.fold(0.0, (a, e) => a + e.annualAmount);
    return ListView(
      padding: _pad,
      children: [
        Row(children: [
          Expanded(child: StatTile(label: 'Healthcare / yr today', value: money(total))),
          const SizedBox(width: 8),
          Expanded(
              child: StatTile(
                  label: 'At age $endAge',
                  value: money(spots.isEmpty ? 0 : spots.last.y))),
        ]),
        _ChartCard(
          title: 'Healthcare cost by age',
          height: 220,
          child: _SimpleLine(spots: spots, maxY: maxY, color: Colors.tealAccent),
        ),
      ],
    );
  }
}

// --- shared ----------------------------------------------------------------

Widget _row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ]),
    );

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child, required this.height});
  final String title;
  final Widget child;
  final double height;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            SizedBox(height: height, child: child),
          ],
        ),
      ),
    );
  }
}

class _SimpleLine extends StatelessWidget {
  const _SimpleLine({required this.spots, required this.maxY, required this.color});
  final List<FlSpot> spots;
  final double maxY;
  final Color color;
  @override
  Widget build(BuildContext context) {
    if (spots.isEmpty) return const Center(child: Text('—'));
    return LineChart(LineChartData(
      minY: 0,
      maxY: maxY <= 0 ? 1 : maxY * 1.1,
      gridData: const FlGridData(show: true, drawVerticalLine: false),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (v, _) => Text(moneyCompact(v), style: const TextStyle(fontSize: 9))),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 9))),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: color,
          barWidth: 2.5,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.12)),
        ),
      ],
    ));
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      Center(child: Padding(padding: const EdgeInsets.all(28), child: Text(text, textAlign: TextAlign.center)));
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text('Estimates only — not tax or financial advice. Federal tax model, 2025 brackets.',
            style: Theme.of(context).textTheme.bodySmall),
      );
}

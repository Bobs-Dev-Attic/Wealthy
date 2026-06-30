import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../models/enums.dart';
import '../../services/engine/tax_optimization.dart';
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
    final s = ref.watch(planControllerProvider);
    final optimization = s.taxProfile.hasData
        ? TaxOptimization.analyze(s.taxProfile, s.profile.filingStatus)
        : null;
    if ((p == null || p.ledger.isEmpty) && optimization == null) {
      return const _Empty('Add income and accounts — or run the Taxes interview — '
          'to estimate taxes and optimization strategies.');
    }
    final children = <Widget>[];
    if (p != null && p.ledger.isNotEmpty) {
      final lifetime = p.ledger.fold(0.0, (sum, y) => sum + y.taxes);
      final spots = [for (final y in p.ledger) FlSpot(y.age.toDouble(), y.taxes)];
      final maxY = p.ledger.fold(0.0, (m, y) => y.taxes > m ? y.taxes : m);
      children.addAll([
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
      ]);
    }
    if (optimization != null) {
      children.add(_TaxOptimizationCard(a: optimization));
    }
    children.add(const _Disclaimer());
    return ListView(padding: _pad, children: children);
  }
}

/// Current-year tax snapshot plus actionable optimization strategies, computed
/// from the figures entered in the Taxes interview.
class _TaxOptimizationCard extends StatelessWidget {
  const _TaxOptimizationCard({required this.a});
  final TaxAnalysis a;
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.insights_outlined, size: 18),
              const SizedBox(width: 8),
              Text('Tax optimization (current year)',
                  style: Theme.of(context).textTheme.titleSmall),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: StatTile(label: 'Est. AGI', value: money(a.agi))),
              const SizedBox(width: 8),
              Expanded(child: StatTile(label: 'Taxable income', value: money(a.taxableIncome))),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: StatTile(label: 'Est. federal tax', value: money(a.estimatedTax))),
              const SizedBox(width: 8),
              Expanded(child: StatTile(label: 'Marginal rate', value: percent(a.marginalRate))),
              const SizedBox(width: 8),
              Expanded(child: StatTile(label: 'Effective rate', value: percent(a.effectiveRate))),
            ]),
            const SizedBox(height: 12),
            Text('Strategies', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            for (final tip in a.tips) _TipRow(tip: tip),
          ],
        ),
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  const _TipRow({required this.tip});
  final TaxTip tip;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2, right: 8),
            child: Icon(Icons.check_circle_outline, size: 16, color: Colors.tealAccent),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tip.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text(tip.detail, style: const TextStyle(fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
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
      lineTouchData: moneyTouchData(),
      gridData: const FlGridData(show: true, drawVerticalLine: false),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 46,
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

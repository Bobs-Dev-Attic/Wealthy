import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../models/enums.dart';
import '../../models/liability.dart';
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

/// Debt: an amortization schedule for each liability with sliders to adjust the
/// monthly payment and interest rate. Changes flow back into the plan so every
/// other result (net worth, cash flow) updates in real time.
class DebtView extends ConsumerWidget {
  const DebtView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liabilities = ref.watch(planControllerProvider.select((s) => s.liabilities));
    final c = ref.read(planControllerProvider.notifier);
    if (liabilities.isEmpty) {
      return const _Empty('Add a liability to see its amortization schedule.');
    }
    final totalBalance = liabilities.fold(0.0, (s, l) => s + l.balance);
    final totalMonthly = liabilities.fold(0.0, (s, l) => s + l.monthlyPayment);
    return ListView(
      padding: _pad,
      children: [
        Row(children: [
          Expanded(child: StatTile(label: 'Total debt', value: money(totalBalance))),
          const SizedBox(width: 8),
          Expanded(child: StatTile(label: 'Monthly payments', value: money(totalMonthly))),
        ]),
        const SizedBox(height: 4),
        for (final l in liabilities)
          _DebtCard(key: ValueKey(l.id), liability: l, onChanged: c.updateLiability),
        const _Disclaimer2(
            'Estimates assume a fixed rate and constant payment. Adjusting a slider updates your plan.'),
      ],
    );
  }
}

class _DebtCard extends StatelessWidget {
  const _DebtCard({super.key, required this.liability, required this.onChanged});
  final Liability liability;
  final ValueChanged<Liability> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = liability;
    final cs = Theme.of(context).colorScheme;
    final sched = _amortize(l.balance, l.interestRate, l.monthlyPayment);
    final monthlyInterest = l.balance * l.interestRate / 12;

    // Slider bounds, kept wide enough to always contain the current value.
    final payMax = [l.monthlyPayment * 2, l.balance / 12, monthlyInterest * 3, 100.0]
        .reduce(math.max)
        .ceilToDouble();
    final rateMax = math.max(0.30, l.interestRate);

    return Card(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(_debtIcon(l.type), size: 18, color: cs.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(l.name.isEmpty ? l.type.label : l.name,
                    style: Theme.of(context).textTheme.titleSmall),
              ),
              Text(money(l.balance), style: const TextStyle(fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: StatTile(
                      label: 'Payoff time',
                      value: sched.amortizes ? _durationLabel(sched.months) : 'Never')),
              const SizedBox(width: 8),
              Expanded(
                  child: StatTile(
                      label: 'Total interest',
                      value: sched.amortizes ? money(sched.totalInterest) : '—')),
            ]),
            if (!sched.amortizes)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(children: [
                  Icon(Icons.warning_amber_rounded, size: 16, color: cs.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Payment of ${money(l.monthlyPayment)} doesn\'t cover ${money(monthlyInterest)}/mo '
                      'in interest — the balance never goes down. Raise the payment below.',
                      style: TextStyle(fontSize: 12, color: cs.error),
                    ),
                  ),
                ]),
              ),
            const SizedBox(height: 8),
            _SliderRow(
              label: 'Monthly payment',
              valueLabel: money(l.monthlyPayment),
              value: l.monthlyPayment.clamp(0, payMax).toDouble(),
              min: 0,
              max: payMax,
              divisions: 200,
              onChanged: (v) => onChanged(l.copyWith(monthlyPayment: v.roundToDouble())),
            ),
            _SliderRow(
              label: 'Interest rate',
              valueLabel: percent(l.interestRate),
              value: l.interestRate.clamp(0, rateMax).toDouble(),
              min: 0,
              max: rateMax,
              divisions: (rateMax / 0.0025).round(),
              onChanged: (v) => onChanged(l.copyWith(interestRate: v)),
            ),
            if (sched.amortizes && sched.years.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Amortization (per year)', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              _AmortTable(years: sched.years),
            ],
          ],
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });
  final String label;
  final String valueLabel;
  final double value, min, max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant))),
          Text(valueLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ]),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max <= min ? min + 1 : max,
            divisions: divisions < 1 ? 1 : divisions,
            label: valueLabel,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _AmortTable extends StatelessWidget {
  const _AmortTable({required this.years});
  final List<_DebtYear> years;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final head = TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant);
    const cell = TextStyle(fontSize: 12);
    Widget row(String a, String b, String c, String d, {TextStyle? style, Color? bg}) => Container(
          color: bg,
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
          child: Row(children: [
            SizedBox(width: 38, child: Text(a, style: style ?? cell)),
            Expanded(child: Text(b, style: style ?? cell, textAlign: TextAlign.right)),
            Expanded(child: Text(c, style: style ?? cell, textAlign: TextAlign.right)),
            Expanded(child: Text(d, style: style ?? cell, textAlign: TextAlign.right)),
          ]),
        );
    return Column(
      children: [
        row('Yr', 'Principal', 'Interest', 'Balance', style: head),
        for (final y in years)
          row(
            '${y.year}',
            money(y.principal),
            money(y.interest),
            money(y.endingBalance),
            bg: y.year.isEven ? cs.surfaceContainerHighest.withValues(alpha: 0.3) : null,
          ),
      ],
    );
  }
}

class _DebtYear {
  final int year;
  final double principal;
  final double interest;
  final double endingBalance;
  const _DebtYear(this.year, this.principal, this.interest, this.endingBalance);
}

/// Computes a yearly amortization schedule. [amortizes] is false when the
/// payment never covers the monthly interest (balance would never reach zero).
({bool amortizes, int months, double totalInterest, List<_DebtYear> years}) _amortize(
    double balance, double annualRate, double payment) {
  if (balance <= 0) {
    return (amortizes: true, months: 0, totalInterest: 0, years: const []);
  }
  final r = annualRate / 12;
  if (payment <= balance * r + 1e-9) {
    return (amortizes: false, months: 0, totalInterest: 0, years: const []);
  }
  const maxMonths = 50 * 12;
  double bal = balance;
  double totalInterest = 0;
  int months = 0;
  final years = <_DebtYear>[];
  while (bal > 0 && months < maxMonths) {
    double yearPrincipal = 0, yearInterest = 0;
    for (var m = 0; m < 12 && bal > 0 && months < maxMonths; m++) {
      final interest = bal * r;
      var principal = payment - interest;
      if (principal <= 0) break;
      if (principal > bal) principal = bal;
      bal -= principal;
      yearPrincipal += principal;
      yearInterest += interest;
      totalInterest += interest;
      months++;
    }
    years.add(_DebtYear(years.length + 1, yearPrincipal, yearInterest, bal < 0.01 ? 0 : bal));
    if (bal < 0.01) break;
  }
  return (amortizes: true, months: months, totalInterest: totalInterest, years: years);
}

String _durationLabel(int months) {
  final y = months ~/ 12;
  final m = months % 12;
  if (y == 0) return '$m mo';
  if (m == 0) return '$y yr';
  return '$y yr $m mo';
}

IconData _debtIcon(LiabilityType t) => switch (t) {
      LiabilityType.mortgage => Icons.house_outlined,
      LiabilityType.auto => Icons.directions_car_outlined,
      LiabilityType.student => Icons.school_outlined,
      LiabilityType.creditCard => Icons.credit_card,
      LiabilityType.loan => Icons.request_quote_outlined,
      LiabilityType.other => Icons.account_balance_outlined,
    };

class _Disclaimer2 extends StatelessWidget {
  const _Disclaimer2(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(text, style: Theme.of(context).textTheme.bodySmall),
      );
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

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../models/enums.dart';
import '../../services/engine/roth_conversion.dart';
import '../../state/plan_controller.dart';
import '../../widgets/editor_fields.dart';
import '../../widgets/result_widgets.dart';

const _pad = EdgeInsets.fromLTRB(16, 14, 16, 24);

/// RMD tax-bomb analysis + Roth-conversion strategy comparison. Seeded once
/// from the user's saved plan (age, filing status, account balances) but
/// fully editable here, since this tool is often used to test "what if"
/// numbers — e.g. a different retirement age or income — without changing
/// the saved plan.
class RothConversionView extends ConsumerStatefulWidget {
  const RothConversionView({super.key});
  @override
  ConsumerState<RothConversionView> createState() => _RothConversionViewState();
}

class _RothConversionViewState extends ConsumerState<RothConversionView> {
  late int _currentAge;
  late int _retirementAge;
  late int _planEndAge;
  late double _traditionalBalance;
  late double _rothBalance;
  late double _preRetirementIncome;
  late double _postRetirementIncome;
  double _growthRate = 0.06;
  late FilingStatus _filingStatus;
  double _customAnnualAmount = 0;
  bool _seeded = false;

  void _seedFromPlan() {
    if (_seeded) return;
    final s = ref.read(planControllerProvider);
    final now = DateTime.now();
    final traditional = s.accounts
        .where((a) => a.type.taxBucket == TaxBucket.taxDeferred)
        .fold(0.0, (sum, a) => sum + a.balance);
    final roth = s.accounts
        .where((a) => a.type.taxBucket == TaxBucket.taxFree)
        .fold(0.0, (sum, a) => sum + a.balance);
    _currentAge = s.profile.currentAge(now);
    _retirementAge = s.profile.retirementAge;
    _planEndAge = s.profile.lifeExpectancy;
    _traditionalBalance = traditional;
    _rothBalance = roth;
    _preRetirementIncome = s.taxProfile.wages;
    _postRetirementIncome = s.taxProfile.ssBenefits + s.taxProfile.iraPensionDistributions;
    _filingStatus = s.profile.filingStatus;
    _seeded = true;
  }

  RothConversionInputs get _inputs => RothConversionInputs(
        currentAge: _currentAge,
        retirementAge: _retirementAge,
        planEndAge: _planEndAge,
        traditionalBalance: _traditionalBalance,
        rothBalance: _rothBalance,
        preRetirementIncome: _preRetirementIncome,
        postRetirementIncome: _postRetirementIncome,
        growthRate: _growthRate,
        filingStatus: _filingStatus,
      );

  @override
  Widget build(BuildContext context) {
    _seedFromPlan();

    final inputsCard = _InputsCard(
      currentAge: _currentAge,
      retirementAge: _retirementAge,
      planEndAge: _planEndAge,
      traditionalBalance: _traditionalBalance,
      rothBalance: _rothBalance,
      preRetirementIncome: _preRetirementIncome,
      postRetirementIncome: _postRetirementIncome,
      growthRate: _growthRate,
      filingStatus: _filingStatus,
      customAnnualAmount: _customAnnualAmount,
      onCurrentAge: (v) => setState(() => _currentAge = v),
      onRetirementAge: (v) => setState(() => _retirementAge = v),
      onPlanEndAge: (v) => setState(() => _planEndAge = v),
      onTraditionalBalance: (v) => setState(() => _traditionalBalance = v),
      onRothBalance: (v) => setState(() => _rothBalance = v),
      onPreRetirementIncome: (v) => setState(() => _preRetirementIncome = v),
      onPostRetirementIncome: (v) => setState(() => _postRetirementIncome = v),
      onGrowthRate: (v) => setState(() => _growthRate = v),
      onFilingStatus: (v) => setState(() => _filingStatus = v),
      onCustomAnnualAmount: (v) => setState(() => _customAnnualAmount = v),
    );

    if (_traditionalBalance <= 0) {
      return ListView(
        padding: _pad,
        children: [
          inputsCard,
          const _Empty('Enter a traditional 401(k)/IRA balance above to analyze the RMD tax bomb.'),
        ],
      );
    }

    final results = RothConversionEngine.compareAll(
      _inputs,
      customAnnualAmount: _customAnnualAmount > 0 ? _customAnnualAmount : null,
    );
    final baseline = results.first;
    final firstRmd = baseline.firstRmdYear;

    return ListView(
      padding: _pad,
      children: [
        inputsCard,
        const SizedBox(height: 12),
        Row(children: [
          const Icon(Icons.warning_amber_outlined, size: 18, color: Colors.orangeAccent),
          const SizedBox(width: 8),
          Text('The RMD tax bomb', style: Theme.of(context).textTheme.titleSmall),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              child: StatTile(
                  label: 'First RMD',
                  value: firstRmd == null ? 'None by age $_planEndAge' : '${money(firstRmd.rmd)} @ ${firstRmd.age}')),
          const SizedBox(width: 8),
          Expanded(
              child: StatTile(
                  label: 'Lifetime tax if untouched',
                  value: money(baseline.totalLifetimeTax),
                  color: Colors.orangeAccent)),
        ]),
        const SizedBox(height: 8),
        _ChartCard(
          title: 'Traditional balance by strategy',
          height: 220,
          child: _StrategyLines(results: results),
        ),
        const SizedBox(height: 12),
        Text('Roth conversion strategies', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        for (final r in results) _StrategyCard(result: r, baseline: baseline),
        const _Disclaimer(),
      ],
    );
  }
}

class _InputsCard extends StatelessWidget {
  const _InputsCard({
    required this.currentAge,
    required this.retirementAge,
    required this.planEndAge,
    required this.traditionalBalance,
    required this.rothBalance,
    required this.preRetirementIncome,
    required this.postRetirementIncome,
    required this.growthRate,
    required this.filingStatus,
    required this.customAnnualAmount,
    required this.onCurrentAge,
    required this.onRetirementAge,
    required this.onPlanEndAge,
    required this.onTraditionalBalance,
    required this.onRothBalance,
    required this.onPreRetirementIncome,
    required this.onPostRetirementIncome,
    required this.onGrowthRate,
    required this.onFilingStatus,
    required this.onCustomAnnualAmount,
  });

  final int currentAge;
  final int retirementAge;
  final int planEndAge;
  final double traditionalBalance;
  final double rothBalance;
  final double preRetirementIncome;
  final double postRetirementIncome;
  final double growthRate;
  final FilingStatus filingStatus;
  final double customAnnualAmount;

  final ValueChanged<int> onCurrentAge;
  final ValueChanged<int> onRetirementAge;
  final ValueChanged<int> onPlanEndAge;
  final ValueChanged<double> onTraditionalBalance;
  final ValueChanged<double> onRothBalance;
  final ValueChanged<double> onPreRetirementIncome;
  final ValueChanged<double> onPostRetirementIncome;
  final ValueChanged<double> onGrowthRate;
  final ValueChanged<FilingStatus> onFilingStatus;
  final ValueChanged<double> onCustomAnnualAmount;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.person_outline, size: 18),
              const SizedBox(width: 8),
              Text('Your numbers', style: Theme.of(context).textTheme.titleSmall),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: IntField(label: 'Current age', value: currentAge, onChanged: onCurrentAge)),
              const SizedBox(width: 10),
              Expanded(
                  child:
                      IntField(label: 'Retirement age', value: retirementAge, onChanged: onRetirementAge)),
              const SizedBox(width: 10),
              Expanded(
                  child: IntField(label: 'Plan to age', value: planEndAge, onChanged: onPlanEndAge)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: MoneyField(
                      label: 'Traditional 401(k)/IRA balance',
                      value: traditionalBalance,
                      onChanged: onTraditionalBalance,
                      help: 'Combined balance of all tax-deferred accounts — the pool RMDs are '
                          'calculated from and the source for conversions.')),
              const SizedBox(width: 10),
              Expanded(
                  child: MoneyField(label: 'Roth balance', value: rothBalance, onChanged: onRothBalance)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: MoneyField(
                      label: 'Income while working',
                      value: preRetirementIncome,
                      onChanged: onPreRetirementIncome,
                      help: 'Ordinary taxable income before your retirement age — this fills up '
                          'brackets and shrinks conversion room.')),
              const SizedBox(width: 10),
              Expanded(
                  child: MoneyField(
                      label: 'Income in retirement',
                      value: postRetirementIncome,
                      onChanged: onPostRetirementIncome,
                      help: 'Ordinary income after retiring but before RMDs — Social Security, a '
                          'pension, part-time work. The gap years here are the best window to '
                          'convert.')),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: PercentField(label: 'Expected growth rate', value: growthRate, onChanged: onGrowthRate)),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<FilingStatus>(
                  value: filingStatus,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Filing status'),
                  items: [
                    for (final fs in FilingStatus.values)
                      DropdownMenuItem(value: fs, child: Text(fs.label)),
                  ],
                  onChanged: (v) {
                    if (v != null) onFilingStatus(v);
                  },
                ),
              ),
            ]),
            const SizedBox(height: 10),
            MoneyField(
                label: 'Custom annual conversion (optional)',
                value: customAnnualAmount,
                onChanged: onCustomAnnualAmount,
                help: 'Adds a "custom" strategy that converts this fixed amount every year '
                    'until RMDs start, so you can test your own number.'),
          ],
        ),
      ),
    );
  }
}

/// Traditional-balance trajectory for every strategy, overlaid on one chart.
class _StrategyLines extends StatelessWidget {
  const _StrategyLines({required this.results});
  final List<ConversionResult> results;

  static const _colors = [
    Colors.redAccent,
    Colors.orangeAccent,
    Colors.amberAccent,
    Colors.tealAccent,
    Colors.purpleAccent,
  ];

  @override
  Widget build(BuildContext context) {
    final maxY = results.fold(0.0, (m, r) {
      final localMax = r.years.fold(0.0, (m2, y) => y.traditionalStart > m2 ? y.traditionalStart : m2);
      return localMax > m ? localMax : m;
    });
    return LineChart(LineChartData(
      minY: 0,
      maxY: maxY <= 0 ? 1 : maxY * 1.1,
      lineTouchData: moneyTouchData(
        seriesLabels: {for (var i = 0; i < results.length; i++) i: results[i].strategy.label},
      ),
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
        for (var i = 0; i < results.length; i++)
          LineChartBarData(
            spots: [for (final y in results[i].years) FlSpot(y.age.toDouble(), y.traditionalStart)],
            isCurved: true,
            color: _colors[i % _colors.length],
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
          ),
      ],
    ));
  }
}

class _StrategyCard extends StatelessWidget {
  const _StrategyCard({required this.result, required this.baseline});
  final ConversionResult result;
  final ConversionResult baseline;

  @override
  Widget build(BuildContext context) {
    final isBaseline = result.strategy == baseline.strategy;
    final savings = baseline.totalLifetimeTax - result.totalLifetimeTax;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(result.strategy.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 2),
            Text(result.strategy.description, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: StatTile(label: 'Converted', value: money(result.totalConverted))),
              const SizedBox(width: 8),
              Expanded(child: StatTile(label: 'Lifetime tax', value: money(result.totalLifetimeTax))),
              const SizedBox(width: 8),
              Expanded(
                child: StatTile(
                  label: isBaseline ? 'Tax vs. baseline' : 'Tax savings',
                  value: isBaseline ? '—' : money(savings),
                  color: isBaseline ? null : (savings > 0 ? Colors.tealAccent : Colors.redAccent),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: StatTile(label: 'Ending Roth balance', value: money(result.endingRoth))),
              const SizedBox(width: 8),
              Expanded(
                  child: StatTile(
                      label: 'Traditional at RMD age',
                      value: money(result.years
                          .firstWhere((y) => y.age == RothConversionEngine.rmdAge,
                              orElse: () => result.years.last)
                          .traditionalStart))),
            ]),
          ],
        ),
      ),
    );
  }
}

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
        child: Text(
            'Estimates only — not tax advice. Assumes flat income in real terms and no state '
            'tax. Federal tax model, 2025 brackets.',
            style: Theme.of(context).textTheme.bodySmall),
      );
}

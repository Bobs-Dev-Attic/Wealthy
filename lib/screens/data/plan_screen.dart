import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/enums.dart';
import '../../models/plan_assumptions.dart';
import '../../state/providers.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/editor_fields.dart';

class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({super.key});
  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen> {
  PlanAssumptions? _draft;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(planDataProvider);
    return AppScaffold(
      title: 'Assumptions',
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          final a = _draft ??= data.assumptions;
          return PageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionCard(
                  title: 'Market & inflation',
                  child: Column(
                    children: [
                      Row(children: [
                        Expanded(
                          child: PercentField(
                              label: 'Expected return',
                              value: a.marketReturnMean,
                              onChanged: (v) => _draft = a.copyWith(marketReturnMean: v)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: PercentField(
                              label: 'Volatility',
                              value: a.marketReturnStdev,
                              onChanged: (v) => _draft = a.copyWith(marketReturnStdev: v)),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: PercentField(
                              label: 'Inflation',
                              value: a.inflation,
                              onChanged: (v) => _draft = a.copyWith(inflation: v)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: PercentField(
                              label: 'Healthcare inflation',
                              value: a.healthcareInflation,
                              onChanged: (v) => _draft = a.copyWith(healthcareInflation: v)),
                        ),
                      ]),
                    ],
                  ),
                ),
                SectionCard(
                  title: 'Withdrawal strategy',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<WithdrawalStrategy>(
                        value: a.withdrawalStrategy,
                        decoration: const InputDecoration(labelText: 'Strategy'),
                        items: [
                          for (final s in WithdrawalStrategy.values)
                            DropdownMenuItem(value: s, child: Text(s.label)),
                        ],
                        onChanged: (s) => setState(() =>
                            _draft = a.copyWith(withdrawalStrategy: s ?? a.withdrawalStrategy)),
                      ),
                      const SizedBox(height: 12),
                      PercentField(
                          label: 'Withdrawal rate (for % / guardrail strategies)',
                          value: a.withdrawalRate,
                          onChanged: (v) => _draft = a.copyWith(withdrawalRate: v)),
                    ],
                  ),
                ),
                SectionCard(
                  title: 'Horizon & simulation',
                  child: Column(
                    children: [
                      Row(children: [
                        Expanded(
                          child: IntField(
                              label: 'Plan to age',
                              value: a.endAge,
                              onChanged: (v) => _draft = a.copyWith(endAge: v)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: IntField(
                              label: 'Social Security claim age',
                              value: a.ssClaimAge,
                              onChanged: (v) => _draft = a.copyWith(ssClaimAge: v)),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      IntField(
                          label: 'Monte Carlo simulations (100–5000)',
                          value: a.simulationCount,
                          onChanged: (v) => _draft = a.copyWith(simulationCount: v)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _saving
                      ? null
                      : () async {
                          setState(() => _saving = true);
                          await ref.read(dataServiceProvider).saveAssumptions(_draft!);
                          ref.invalidate(planDataProvider);
                          if (context.mounted) {
                            setState(() => _saving = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Assumptions saved')));
                          }
                        },
                  child: const Text('Save assumptions'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

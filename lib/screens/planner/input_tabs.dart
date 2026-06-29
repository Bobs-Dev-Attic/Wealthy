import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/enums.dart';
import '../../models/liability.dart';
import '../../state/plan_controller.dart';
import '../../widgets/editor_fields.dart';

const _gap = SizedBox(height: 10);
const _hgap = SizedBox(width: 10);

EdgeInsets get _pad => const EdgeInsets.fromLTRB(16, 12, 16, 24);

/// "You" — the minimum input; just an age unlocks a first plan.
class YouTab extends ConsumerWidget {
  const YouTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(planControllerProvider);
    final c = ref.read(planControllerProvider.notifier);
    final now = DateTime.now();
    final age = s.profile.currentAge(now);
    return ListView(
      padding: _pad,
      children: [
        const _Hint('Start with your age. Everything below is optional — add more for a sharper plan.'),
        _gap,
        Row(children: [
          Expanded(
            child: IntField(
              label: 'Current age',
              value: age,
              onChanged: (v) => c.setCurrentAge(v, now),
            ),
          ),
          _hgap,
          Expanded(
            child: IntField(
              label: 'Retirement age',
              value: s.profile.retirementAge,
              onChanged: (v) => c.setProfile(s.profile.copyWith(retirementAge: v)),
            ),
          ),
        ]),
        _gap,
        Row(children: [
          Expanded(
            child: IntField(
              label: 'Plan through age',
              value: s.profile.lifeExpectancy,
              onChanged: (v) => c.setProfile(s.profile.copyWith(
                  lifeExpectancy: v,
                  // keep assumptions end age in sync
                  )),
            ),
          ),
          _hgap,
          Expanded(
            child: TextFormField(
              initialValue: s.profile.name ?? '',
              decoration: const InputDecoration(labelText: 'Name (optional)'),
              onChanged: (v) => c.setProfile(s.profile.copyWith(name: v)),
            ),
          ),
        ]),
      ],
    );
  }
}

/// Investments / accounts.
class InvestmentsTab extends ConsumerWidget {
  const InvestmentsTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(planControllerProvider);
    final c = ref.read(planControllerProvider.notifier);
    return _ListTabScaffold(
      addLabel: 'Add account',
      onAdd: c.addAccount,
      emptyHint: 'Add your brokerage, 401(k)/IRA, Roth, HSA and cash accounts.',
      itemCount: s.accounts.length,
      itemBuilder: (i) {
        final a = s.accounts[i];
        return _RowCard(
          key: ValueKey(a.id ?? i),
          onRemove: () => c.removeAccount(a),
          children: [
            Row(children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  initialValue: a.name,
                  decoration: const InputDecoration(labelText: 'Name'),
                  onChanged: (v) => c.updateAccount(a.copyWith(name: v)),
                ),
              ),
              _hgap,
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<AccountType>(
                  value: a.type,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: [
                    for (final t in AccountType.values)
                      DropdownMenuItem(value: t, child: Text(t.label, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (t) => c.updateAccount(a.copyWith(type: t)),
                ),
              ),
            ]),
            _gap,
            Row(children: [
              Expanded(
                child: MoneyField(
                  label: 'Balance',
                  value: a.balance,
                  onChanged: (v) => c.updateAccount(a.copyWith(balance: v)),
                ),
              ),
              _hgap,
              Expanded(
                child: PercentField(
                  label: 'Return',
                  value: a.expectedReturn,
                  onChanged: (v) => c.updateAccount(a.copyWith(expectedReturn: v)),
                ),
              ),
            ]),
          ],
        );
      },
    );
  }
}

/// Income sources.
class IncomeTab extends ConsumerWidget {
  const IncomeTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(planControllerProvider);
    final c = ref.read(planControllerProvider.notifier);
    return _ListTabScaffold(
      addLabel: 'Add income',
      onAdd: c.addIncome,
      emptyHint: 'Add Social Security, pensions and annuities with the age they start.',
      itemCount: s.incomes.length,
      itemBuilder: (i) {
        final inc = s.incomes[i];
        return _RowCard(
          key: ValueKey(inc.id ?? i),
          onRemove: () => c.removeIncome(inc),
          children: [
            Row(children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<IncomeType>(
                  value: inc.type,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: [
                    for (final t in IncomeType.values)
                      DropdownMenuItem(value: t, child: Text(t.label, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (t) => c.updateIncome(inc.copyWith(type: t)),
                ),
              ),
              _hgap,
              Expanded(
                child: MoneyField(
                  label: 'Annual',
                  value: inc.annualAmount,
                  onChanged: (v) => c.updateIncome(inc.copyWith(annualAmount: v)),
                ),
              ),
            ]),
            _gap,
            Row(children: [
              Expanded(
                child: IntField(
                  label: 'Starts at age',
                  value: inc.startAge,
                  onChanged: (v) => c.updateIncome(inc.copyWith(startAge: v)),
                ),
              ),
              _hgap,
              Expanded(
                child: PercentField(
                  label: 'Annual increase',
                  value: inc.colaRate,
                  onChanged: (v) => c.updateIncome(inc.copyWith(colaRate: v)),
                ),
              ),
            ]),
          ],
        );
      },
    );
  }
}

/// Expenses.
class ExpensesTab extends ConsumerWidget {
  const ExpensesTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(planControllerProvider);
    final c = ref.read(planControllerProvider.notifier);
    return _ListTabScaffold(
      addLabel: 'Add expense',
      onAdd: c.addExpense,
      emptyHint: 'Add yearly living costs, housing, healthcare and travel.',
      itemCount: s.expenses.length,
      itemBuilder: (i) {
        final e = s.expenses[i];
        return _RowCard(
          key: ValueKey(e.id ?? i),
          onRemove: () => c.removeExpense(e),
          children: [
            Row(children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<ExpenseCategory>(
                  value: e.category,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    for (final cat in ExpenseCategory.values)
                      DropdownMenuItem(value: cat, child: Text(cat.label, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (cat) => c.updateExpense(
                      e.copyWith(category: cat, inflationRate: cat == ExpenseCategory.healthcare ? 0.05 : e.inflationRate)),
                ),
              ),
              _hgap,
              Expanded(
                child: MoneyField(
                  label: 'Annual',
                  value: e.annualAmount,
                  onChanged: (v) => c.updateExpense(e.copyWith(annualAmount: v)),
                ),
              ),
            ]),
          ],
        );
      },
    );
  }
}

/// Liabilities / debts.
class LiabilitiesTab extends ConsumerWidget {
  const LiabilitiesTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(planControllerProvider);
    final c = ref.read(planControllerProvider.notifier);
    return _ListTabScaffold(
      addLabel: 'Add debt',
      onAdd: c.addLiability,
      emptyHint: 'Add mortgage, auto, student or other loans and credit cards.',
      itemCount: s.liabilities.length,
      itemBuilder: (i) {
        final l = s.liabilities[i];
        return _RowCard(
          key: ValueKey(l.id ?? i),
          onRemove: () => c.removeLiability(l),
          children: [
            Row(children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<LiabilityType>(
                  value: l.type,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: [
                    for (final t in LiabilityType.values)
                      DropdownMenuItem(value: t, child: Text(t.label, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (t) => c.updateLiability(l.copyWith(type: t)),
                ),
              ),
              _hgap,
              Expanded(
                child: MoneyField(
                  label: 'Balance',
                  value: l.balance,
                  onChanged: (v) => c.updateLiability(l.copyWith(balance: v)),
                ),
              ),
            ]),
            _gap,
            Row(children: [
              Expanded(
                child: PercentField(
                  label: 'Rate',
                  value: l.interestRate,
                  onChanged: (v) => c.updateLiability(l.copyWith(interestRate: v)),
                ),
              ),
              _hgap,
              Expanded(
                child: MoneyField(
                  label: 'Monthly payment',
                  value: l.monthlyPayment,
                  onChanged: (v) => c.updateLiability(l.copyWith(monthlyPayment: v)),
                ),
              ),
            ]),
          ],
        );
      },
    );
  }
}

/// Taxes — filing status and state.
class TaxesTab extends ConsumerWidget {
  const TaxesTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(planControllerProvider);
    final c = ref.read(planControllerProvider.notifier);
    return ListView(
      padding: _pad,
      children: [
        const _Hint('Used to estimate federal income tax, capital-gains and Social Security taxation.'),
        _gap,
        DropdownButtonFormField<FilingStatus>(
          value: s.profile.filingStatus,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Filing status'),
          items: [
            for (final f in FilingStatus.values) DropdownMenuItem(value: f, child: Text(f.label)),
          ],
          onChanged: (f) => c.setProfile(s.profile.copyWith(filingStatus: f)),
        ),
        _gap,
        TextFormField(
          initialValue: s.profile.state ?? '',
          decoration: const InputDecoration(
              labelText: 'State (optional)', helperText: 'For context; state tax is not modeled'),
          onChanged: (v) => c.setProfile(s.profile.copyWith(state: v)),
        ),
      ],
    );
  }
}

/// Assumptions.
class AssumptionsTab extends ConsumerWidget {
  const AssumptionsTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(planControllerProvider);
    final c = ref.read(planControllerProvider.notifier);
    final a = s.assumptions;
    return ListView(
      padding: _pad,
      children: [
        Row(children: [
          Expanded(child: PercentField(label: 'Expected return', value: a.marketReturnMean, onChanged: (v) => c.setAssumptions(a.copyWith(marketReturnMean: v)))),
          _hgap,
          Expanded(child: PercentField(label: 'Volatility', value: a.marketReturnStdev, onChanged: (v) => c.setAssumptions(a.copyWith(marketReturnStdev: v)))),
        ]),
        _gap,
        Row(children: [
          Expanded(child: PercentField(label: 'Inflation', value: a.inflation, onChanged: (v) => c.setAssumptions(a.copyWith(inflation: v)))),
          _hgap,
          Expanded(child: PercentField(label: 'Healthcare inflation', value: a.healthcareInflation, onChanged: (v) => c.setAssumptions(a.copyWith(healthcareInflation: v)))),
        ]),
        _gap,
        DropdownButtonFormField<WithdrawalStrategy>(
          value: a.withdrawalStrategy,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Withdrawal strategy'),
          items: [
            for (final w in WithdrawalStrategy.values) DropdownMenuItem(value: w, child: Text(w.label)),
          ],
          onChanged: (w) => c.setAssumptions(a.copyWith(withdrawalStrategy: w)),
        ),
        _gap,
        Row(children: [
          Expanded(child: PercentField(label: 'Withdrawal rate', value: a.withdrawalRate, onChanged: (v) => c.setAssumptions(a.copyWith(withdrawalRate: v)))),
          _hgap,
          Expanded(child: IntField(label: 'Simulations', value: a.simulationCount, onChanged: (v) => c.setAssumptions(a.copyWith(simulationCount: v)))),
        ]),
      ],
    );
  }
}

// --- shared building blocks ------------------------------------------------

class _ListTabScaffold extends StatelessWidget {
  const _ListTabScaffold({
    required this.addLabel,
    required this.onAdd,
    required this.emptyHint,
    required this.itemCount,
    required this.itemBuilder,
  });
  final String addLabel;
  final VoidCallback onAdd;
  final String emptyHint;
  final int itemCount;
  final Widget Function(int) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: _pad,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 18),
            label: Text(addLabel),
          ),
        ),
        if (itemCount == 0) Padding(padding: const EdgeInsets.only(top: 12), child: _Hint(emptyHint)),
        for (var i = 0; i < itemCount; i++) itemBuilder(i),
      ],
    );
  }
}

class _RowCard extends StatelessWidget {
  const _RowCard({super.key, required this.children, required this.onRemove});
  final List<Widget> children;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Column(children: children)),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: 'Remove',
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant));
}

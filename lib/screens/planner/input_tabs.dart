import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../models/enums.dart';
import '../../models/holding.dart';
import '../../models/liability.dart';
import '../../models/quote_result.dart';
import '../../models/tax_profile.dart';
import '../../state/plan_controller.dart';
import '../../widgets/editor_fields.dart';
import 'interview.dart';

/// A tab header row: action buttons on the left, a running total on the right.
class TabHeader extends StatelessWidget {
  const TabHeader({super.key, required this.actions, this.totalLabel, this.totalValue});
  final List<Widget> actions;
  final String? totalLabel;
  final double? totalValue;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: actions,
          ),
        ),
        if (totalLabel != null)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(totalLabel!,
                    style: TextStyle(
                        fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                Text(money(totalValue ?? 0),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
      ],
    );
  }
}

/// A button that launches a guided interview for a tab.
class GuidedButton extends StatelessWidget {
  const GuidedButton({super.key, required this.onPressed});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.auto_awesome, size: 18),
      label: const Text('Guided setup'),
    );
  }
}

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
        TabHeader(
          totalLabel: 'Net worth',
          totalValue: s.netWorth,
          actions: [GuidedButton(onPressed: () => launchInterview(context, youInterview()))],
        ),
        _gap,
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
    return ListView(
      padding: _pad,
      children: [
        TabHeader(
          totalLabel: 'Total assets',
          totalValue: s.totalAssets,
          actions: [
            FilledButton.tonalIcon(
              onPressed: c.addAccount,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add account'),
            ),
            GuidedButton(onPressed: () => launchInterview(context, investmentsInterview())),
          ],
        ),
        if (s.totalAssets > 0) _TaxMixCard(byBucket: s.assetsByTaxBucket),
        if (s.accounts.isEmpty && s.holdings.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: _Hint('Add account balances, or individual holdings (stocks, ETFs, funds) below.'),
          ),
        for (final a in s.accounts)
          _RowCard(
            key: ValueKey(a.id),
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
          ),
        const SizedBox(height: 14),
        const _HoldingsSection(),
      ],
    );
  }
}

/// Compact breakdown of total assets by tax treatment. This is the dimension
/// that determines post-retirement taxes: pre-tax balances are taxed as income
/// when withdrawn (and force RMDs), Roth/HSA come out tax-free, and taxable
/// accounts are taxed only on gains.
class _TaxMixCard extends StatelessWidget {
  const _TaxMixCard({required this.byBucket});
  final Map<TaxBucket, double> byBucket;

  static const _order = [
    TaxBucket.taxDeferred,
    TaxBucket.taxFree,
    TaxBucket.taxable,
    TaxBucket.hsa,
    TaxBucket.cash,
  ];

  Color _color(TaxBucket b, ColorScheme cs) => switch (b) {
        TaxBucket.taxDeferred => Colors.orangeAccent,
        TaxBucket.taxFree => Colors.greenAccent,
        TaxBucket.taxable => Colors.blueAccent,
        TaxBucket.hsa => Colors.tealAccent,
        TaxBucket.cash => cs.outline,
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final entries = [
      for (final b in _order)
        if ((byBucket[b] ?? 0) > 0) (b, byBucket[b]!),
    ];
    if (entries.isEmpty) return const SizedBox.shrink();
    final preTax = byBucket[TaxBucket.taxDeferred] ?? 0;
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.account_balance_wallet_outlined, size: 16),
              const SizedBox(width: 6),
              Text('Assets by tax treatment',
                  style: Theme.of(context).textTheme.titleSmall),
            ]),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (b, v) in entries)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _color(b, cs).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _color(b, cs).withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(b.label, style: const TextStyle(fontSize: 11.5)),
                        Text(money(v),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                  ),
              ],
            ),
            if (preTax > 0) ...[
              const SizedBox(height: 10),
              Text(
                'Pre-tax balances (${money(preTax)}) are taxed as ordinary income when '
                'withdrawn and trigger RMDs at 73. Run the Taxes interview to model the bite.',
                style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Individual securities with live-ish prices, shown under Investments.
class _HoldingsSection extends ConsumerStatefulWidget {
  const _HoldingsSection();
  @override
  ConsumerState<_HoldingsSection> createState() => _HoldingsSectionState();
}

class _HoldingsSectionState extends ConsumerState<_HoldingsSection> {
  static String _shares(double n) =>
      n == n.roundToDouble() ? n.toInt().toString() : n.toString();

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(planControllerProvider);
    final c = ref.read(planControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: Text('Individual holdings (stocks, ETFs, funds)',
                style: Theme.of(context).textTheme.titleSmall),
          ),
          Text(money(s.holdingsValue), style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.tonalIcon(
              onPressed: c.addHolding,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add holding'),
            ),
            OutlinedButton.icon(
              onPressed: s.holdings.every((h) => h.symbol.trim().isEmpty)
                  ? null
                  : () => showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => const PriceRefreshDialog(),
                      ),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh prices'),
            ),
          ],
        ),
        if (s.holdings.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: _Hint('Enter a ticker (e.g. AAPL, VTI, VTSAX) and shares, then Refresh prices.'),
          ),
        for (final h in s.holdings)
          _RowCard(
            key: ValueKey(h.id),
            onRemove: () => c.removeHolding(h),
            children: [
              Row(children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    initialValue: h.symbol,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Ticker'),
                    onChanged: (v) => c.updateHolding(h.copyWith(symbol: v.trim().toUpperCase())),
                  ),
                ),
                _hgap,
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    initialValue: h.shares == 0 ? '' : _shares(h.shares),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Shares'),
                    onChanged: (v) => c.updateHolding(h.copyWith(shares: double.tryParse(v) ?? 0)),
                  ),
                ),
              ]),
              _gap,
              Row(children: [
                Expanded(
                  flex: 4,
                  child: DropdownButtonFormField<AccountType>(
                    value: h.accountType,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Account'),
                    items: [
                      for (final t in Holding.investable)
                        DropdownMenuItem(value: t, child: Text(t.label, overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (t) => c.updateHolding(h.copyWith(accountType: t)),
                  ),
                ),
                _hgap,
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(money(h.marketValue),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(h.lastPrice != null ? '@ ${moneyCents(h.lastPrice!)}' : 'no price yet',
                          style: TextStyle(
                              fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ]),
            ],
          ),
        const SizedBox(height: 8),
        Text('Prices via Yahoo Finance / Stooq — delayed / end-of-day, for estimates only.',
            style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

/// Drives a price refresh and shows a live diagnostic of the API call: the
/// symbols requested, an in-progress spinner, then per-symbol results (price +
/// source, or why it failed) and any error returned by the quotes function.
class PriceRefreshDialog extends ConsumerStatefulWidget {
  const PriceRefreshDialog({super.key});
  @override
  ConsumerState<PriceRefreshDialog> createState() => _PriceRefreshDialogState();
}

class _PriceRefreshDialogState extends ConsumerState<PriceRefreshDialog> {
  bool _loading = true;
  QuoteResult? _result;
  late List<String> _requested;

  @override
  void initState() {
    super.initState();
    final s = ref.read(planControllerProvider);
    _requested = s.holdings
        .map((h) => h.symbol.trim().toUpperCase())
        .where((x) => x.isNotEmpty)
        .toSet()
        .toList();
    _run();
  }

  Future<void> _run() async {
    setState(() => _loading = true);
    final r = await ref.read(planControllerProvider.notifier).refreshPrices();
    if (mounted) {
      setState(() {
        _result = r;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final r = _result;
    return AlertDialog(
      title: Row(children: [
        const Icon(Icons.refresh, size: 20),
        const SizedBox(width: 8),
        const Text('Refresh prices'),
      ]),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _kv('Endpoint', 'POST /functions/v1/quotes'),
              _kv('Source', 'Yahoo Finance, falling back to Stooq'),
              _kv('Symbols (${_requested.length})',
                  _requested.isEmpty ? '—' : _requested.join(', ')),
              if (r != null && r.httpStatus != null) _kv('HTTP status', '${r.httpStatus}'),
              const Divider(height: 22),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Row(children: [
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 12),
                    Text('Calling quotes function…'),
                  ]),
                )
              else if (r != null) ...[
                if (r.error != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(Icons.error_outline, size: 18, color: cs.onErrorContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(r.error!,
                            style: TextStyle(color: cs.onErrorContainer, fontSize: 12.5)),
                      ),
                    ]),
                  ),
                if (r.error != null) const SizedBox(height: 10),
                Text('${r.pricedCount} of ${_requested.length} priced',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                if (r.details.isNotEmpty)
                  for (final d in r.details) _detailRow(d, cs)
                else if (r.error == null)
                  Text('No per-symbol detail returned.',
                      style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (!_loading)
          TextButton.icon(
              onPressed: _run, icon: const Icon(Icons.refresh, size: 16), label: const Text('Retry')),
        FilledButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 120,
              child: Text(k,
                  style: TextStyle(
                      fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant))),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 12.5))),
        ]),
      );

  Widget _detailRow(QuoteDetail d, ColorScheme cs) {
    final ok = d.ok;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Icon(ok ? Icons.check_circle_outline : Icons.cancel_outlined,
            size: 16, color: ok ? Colors.green : cs.error),
        const SizedBox(width: 8),
        SizedBox(width: 70, child: Text(d.symbol, style: const TextStyle(fontWeight: FontWeight.bold))),
        Expanded(
          child: Text(
            ok
                ? '${moneyCents(d.price!)}  ·  ${d.source ?? ''}'
                : d.status,
            style: TextStyle(fontSize: 12.5, color: ok ? null : cs.onSurfaceVariant),
          ),
        ),
      ]),
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
      onInterview: () => launchInterview(context, incomeInterview()),
      totalLabel: 'Income / yr',
      totalValue: s.annualIncome,
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
      onInterview: () => launchInterview(context, expensesInterview()),
      totalLabel: 'Expenses / yr',
      totalValue: s.annualExpenses,
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
      onInterview: () => launchInterview(context, liabilitiesInterview()),
      totalLabel: 'Total debt',
      totalValue: s.totalLiabilities,
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

/// Taxes — filing status, state, and the tax-return figures used for
/// optimization. Mirrors the fields collected by the guided interview so they
/// can also be edited directly here.
class TaxesTab extends ConsumerWidget {
  const TaxesTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(planControllerProvider);
    final c = ref.read(planControllerProvider.notifier);
    final t = s.taxProfile;
    void set(TaxProfile next) => c.setTaxProfile(next);

    Widget pair(Widget a, Widget b) => Row(children: [Expanded(child: a), _hgap, Expanded(child: b)]);

    return ListView(
      padding: _pad,
      children: [
        TabHeader(
          totalLabel: 'Net worth',
          totalValue: s.netWorth,
          actions: [GuidedButton(onPressed: () => launchInterview(context, taxesInterview()))],
        ),
        _gap,
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
        const SizedBox(height: 18),
        _SectionLabel('Tax-return figures'),
        const _Hint('From your most recent federal return (Form 1040). Drives the '
            'tax-optimization strategies on the Taxes results tab.'),
        _gap,
        pair(
          MoneyField(
              label: 'Wages & salary',
              value: t.wages,
              onChanged: (v) => set(t.copyWith(wages: v)),
              help: 'Form 1040, line 1a — total wages, salaries and tips '
                  '(box 1 of your W-2s).'),
          MoneyField(
              label: 'Taxable interest',
              value: t.interest,
              onChanged: (v) => set(t.copyWith(interest: v)),
              help: 'Form 1040, line 2b — taxable interest (totaled on '
                  'Schedule B if over \$1,500).'),
        ),
        _gap,
        pair(
          MoneyField(
              label: 'Ordinary dividends',
              value: t.ordinaryDividends,
              onChanged: (v) => set(t.copyWith(ordinaryDividends: v)),
              help: 'Form 1040, line 3b — total ordinary dividends '
                  '(box 1a of your 1099-DIVs).'),
          MoneyField(
              label: 'Qualified dividends',
              value: t.qualifiedDividends,
              onChanged: (v) => set(t.copyWith(qualifiedDividends: v)),
              help: 'Form 1040, line 3a — the qualified portion '
                  '(box 1b of your 1099-DIVs).'),
        ),
        _gap,
        pair(
          MoneyField(
              label: 'Long-term gains',
              value: t.longTermGains,
              onChanged: (v) => set(t.copyWith(longTermGains: v)),
              help: 'Schedule D, line 15 (net long-term gain) — flows to '
                  'Form 1040, line 7.'),
          MoneyField(
              label: 'Short-term gains',
              value: t.shortTermGains,
              onChanged: (v) => set(t.copyWith(shortTermGains: v)),
              help: 'Schedule D, line 7 (net short-term gain) — flows to '
                  'Form 1040, line 7.'),
        ),
        _gap,
        pair(
          MoneyField(
              label: 'Business income',
              value: t.businessIncome,
              onChanged: (v) => set(t.copyWith(businessIncome: v)),
              help: 'Net profit from Schedule C (or K-1) — reported on '
                  'Schedule 1, line 3, then Form 1040, line 8.'),
          MoneyField(
              label: 'IRA/pension distributions',
              value: t.iraPensionDistributions,
              onChanged: (v) => set(t.copyWith(iraPensionDistributions: v)),
              help: 'Form 1040 — taxable IRA distributions (line 4b) plus '
                  'taxable pensions & annuities (line 5b).'),
        ),
        _gap,
        pair(
          MoneyField(
              label: 'Social Security',
              value: t.ssBenefits,
              onChanged: (v) => set(t.copyWith(ssBenefits: v)),
              help: 'Form 1040, line 6a — gross Social Security benefits '
                  '(box 5 of your SSA-1099).'),
          MoneyField(
              label: 'Other income',
              value: t.otherIncome,
              onChanged: (v) => set(t.copyWith(otherIncome: v)),
              help: 'Additional income from Schedule 1, line 9 (rental, '
                  'royalties, unemployment, etc.) — Form 1040, line 8.'),
        ),
        _gap,
        pair(
          MoneyField(
              label: 'Pre-tax contributions',
              value: t.pretaxContributions,
              onChanged: (v) => set(t.copyWith(pretaxContributions: v)),
              help: '401(k)/403(b): box 12 code D/E/G on your W-2. '
                  'Deductible IRA: Schedule 1, line 20. HSA: Schedule 1, line 13.'),
          DropdownButtonFormField<bool>(
            value: t.usesItemized,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Deduction method'),
            items: const [
              DropdownMenuItem(value: false, child: Text('Standard deduction')),
              DropdownMenuItem(value: true, child: Text('Itemize')),
            ],
            onChanged: (v) => set(t.copyWith(usesItemized: v ?? false)),
          ),
        ),
        _gap,
        pair(
          MoneyField(
              label: 'Itemized deductions',
              value: t.itemizedDeductions,
              onChanged: (v) => set(t.copyWith(itemizedDeductions: v)),
              help: 'Schedule A, line 17 (total itemized deductions) — '
                  'flows to Form 1040, line 12.'),
          MoneyField(
              label: 'Total tax paid',
              value: t.estTotalTax,
              onChanged: (v) => set(t.copyWith(estTotalTax: v)),
              help: 'Form 1040, line 24 — your total tax for the year.'),
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
        TabHeader(actions: const [], totalLabel: 'Net worth', totalValue: s.netWorth),
        _gap,
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
    this.onInterview,
    this.totalLabel,
    this.totalValue,
  });
  final String addLabel;
  final VoidCallback onAdd;
  final String emptyHint;
  final int itemCount;
  final Widget Function(int) itemBuilder;
  final VoidCallback? onInterview;
  final String? totalLabel;
  final double? totalValue;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: _pad,
      children: [
        TabHeader(
          totalLabel: totalLabel,
          totalValue: totalValue,
          actions: [
            FilledButton.tonalIcon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: Text(addLabel),
            ),
            if (onInterview != null) GuidedButton(onPressed: onInterview!),
          ],
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      );
}

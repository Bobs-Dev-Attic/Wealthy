import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../models/account.dart';
import '../../models/enums.dart';
import '../../models/expense.dart';
import '../../models/income_source.dart';
import '../../models/liability.dart';
import '../../models/tax_profile.dart';
import '../../services/engine/social_security.dart';
import '../../state/plan_controller.dart';

/// A guided "interview" — a series of questions that fill in one tab's data.
enum IKind { money, age, percent, text, choice }

class IField {
  final String key;
  final String label;
  final IKind kind;
  final List<String> choices;
  const IField(this.key, this.label, this.kind, {this.choices = const []});
}

class IStep {
  final String title;
  final String? helper;
  final List<IField> fields;
  final void Function(WidgetRef ref, Map<String, dynamic> values) apply;

  /// Optional reference button shown under the fields (e.g. a Social Security
  /// table). [infoBuilder] gets the current field values and returns a dialog.
  final String? infoLabel;
  final Widget Function(BuildContext context, Map<String, dynamic> values)? infoBuilder;

  const IStep({
    required this.title,
    this.helper,
    required this.fields,
    required this.apply,
    this.infoLabel,
    this.infoBuilder,
  });
}

class Interview {
  final String title;
  final IconData icon;
  final List<IStep> steps;
  const Interview({required this.title, required this.icon, required this.steps});
}

Future<void> launchInterview(BuildContext context, Interview interview) {
  return showDialog(
    context: context,
    useSafeArea: false,
    builder: (_) => _InterviewDialog(interview: interview),
  );
}

// --- Upsert helpers (match by name so re-running doesn't duplicate) ----------

void _upsertExpense(WidgetRef ref, String name, ExpenseCategory cat, double annual) {
  final c = ref.read(planControllerProvider.notifier);
  final s = ref.read(planControllerProvider);
  for (final e in s.expenses) {
    if (e.name.toLowerCase() == name.toLowerCase()) {
      c.updateExpense(e.copyWith(annualAmount: annual, category: cat));
      return;
    }
  }
  c.createExpense(Expense(name: name, category: cat, annualAmount: annual));
}

void _upsertIncome(WidgetRef ref, String name, IncomeType type, double amt, int startAge) {
  final c = ref.read(planControllerProvider.notifier);
  final s = ref.read(planControllerProvider);
  for (final i in s.incomes) {
    if (i.name.toLowerCase() == name.toLowerCase()) {
      c.updateIncome(i.copyWith(annualAmount: amt, startAge: startAge, type: type));
      return;
    }
  }
  c.createIncome(IncomeSource(name: name, type: type, annualAmount: amt, startAge: startAge));
}

void _upsertAccount(WidgetRef ref, String name, AccountType type, double balance) {
  final c = ref.read(planControllerProvider.notifier);
  final s = ref.read(planControllerProvider);
  for (final a in s.accounts) {
    if (a.name.toLowerCase() == name.toLowerCase()) {
      c.updateAccount(a.copyWith(balance: balance, type: type));
      return;
    }
  }
  c.createAccount(Account(name: name, type: type, balance: balance));
}

void _upsertLiability(
    WidgetRef ref, String name, LiabilityType type, double balance, double pay, double rate) {
  final c = ref.read(planControllerProvider.notifier);
  final s = ref.read(planControllerProvider);
  for (final l in s.liabilities) {
    if (l.name.toLowerCase() == name.toLowerCase()) {
      c.updateLiability(l.copyWith(balance: balance, monthlyPayment: pay, type: type));
      return;
    }
  }
  c.createLiability(
      Liability(name: name, type: type, balance: balance, monthlyPayment: pay, interestRate: rate));
}

/// A single money question that patches one field of the tax profile.
IStep _taxMoneyStep(
  String title,
  String helper,
  String label,
  TaxProfile Function(TaxProfile t, double v) patch,
) =>
    IStep(
      title: title,
      helper: helper,
      fields: [IField('amt', label, IKind.money)],
      apply: (ref, v) {
        final amt = (v['amt'] as double?) ?? 0;
        if (amt <= 0) return;
        final c = ref.read(planControllerProvider.notifier);
        c.setTaxProfile(patch(ref.read(planControllerProvider).taxProfile, amt));
      },
    );

// --- Interview definitions ---------------------------------------------------

IStep _expenseStep(String name, ExpenseCategory cat, {String freq = 'month'}) {
  final unit = freq == 'week' ? 'per week' : freq == 'year' ? 'per year' : 'per month';
  return IStep(
    title: name,
    helper: 'About how much do you spend on ${name.toLowerCase()} $unit? Leave blank to skip.',
    fields: [IField('amt', 'Amount $unit', IKind.money)],
    apply: (ref, v) {
      final amt = (v['amt'] as double?) ?? 0;
      if (amt <= 0) return;
      final annual = freq == 'week' ? amt * 52 : freq == 'year' ? amt : amt * 12;
      _upsertExpense(ref, name, cat, annual);
    },
  );
}

Interview expensesInterview() => Interview(
      title: 'Expenses',
      icon: Icons.receipt_long_outlined,
      steps: [
        _expenseStep('Mortgage or rent', ExpenseCategory.housing),
        _expenseStep('Electricity', ExpenseCategory.electricity),
        _expenseStep('Water & sewer', ExpenseCategory.water),
        _expenseStep('Gas & heating', ExpenseCategory.gas),
        _expenseStep('Internet & cable', ExpenseCategory.internet),
        _expenseStep('Phone', ExpenseCategory.phone),
        _expenseStep('Streaming & subscriptions', ExpenseCategory.subscriptions),
        _expenseStep('Groceries', ExpenseCategory.groceries, freq: 'week'),
        _expenseStep('Dining out', ExpenseCategory.dining),
        _expenseStep('Transportation & fuel', ExpenseCategory.transportation),
        _expenseStep('Insurance (auto/home/life)', ExpenseCategory.insurance),
        _expenseStep('Healthcare & medical', ExpenseCategory.healthcare),
        _expenseStep('Personal care & clothing', ExpenseCategory.personal),
        _expenseStep('Education or tuition', ExpenseCategory.education),
        _expenseStep('Childcare', ExpenseCategory.childcare),
        _expenseStep('Pets', ExpenseCategory.pets),
        _expenseStep('Charity & gifts', ExpenseCategory.charity),
        _expenseStep('Travel & vacations', ExpenseCategory.travel, freq: 'year'),
        _expenseStep('Other spending', ExpenseCategory.other),
      ],
    );

IStep _incomeStep(String name, IncomeType type, {int startAge = 65}) => IStep(
      title: name,
      helper: 'Expected $name. Leave blank to skip.',
      fields: [
        const IField('amt', 'Annual amount', IKind.money),
        IField('age', 'Age it starts (default $startAge)', IKind.age),
      ],
      apply: (ref, v) {
        final amt = (v['amt'] as double?) ?? 0;
        if (amt <= 0) return;
        final age = (v['age'] as int?) ?? 0;
        _upsertIncome(ref, name, type, amt, age > 0 ? age : startAge);
      },
    );

IStep _socialSecurityStep() => IStep(
      title: 'Social Security',
      helper: 'Your estimated annual benefit and the age you plan to claim. '
          'Tap the table to see how claiming age changes the amount.',
      fields: const [
        IField('amt', 'Annual amount', IKind.money),
        IField('age', 'Claim age (default 67)', IKind.age),
      ],
      apply: (ref, v) {
        final amt = (v['amt'] as double?) ?? 0;
        if (amt <= 0) return;
        final age = (v['age'] as int?) ?? 0;
        _upsertIncome(ref, 'Social Security', IncomeType.socialSecurity, amt, age > 0 ? age : 67);
      },
      infoLabel: 'Show benefit-by-age table',
      infoBuilder: (ctx, v) =>
          SocialSecurityTableDialog(initialAnnual: (v['amt'] as double?) ?? 0),
    );

Interview incomeInterview() => Interview(
      title: 'Income',
      icon: Icons.payments_outlined,
      steps: [
        _socialSecurityStep(),
        _incomeStep('Pension', IncomeType.pension),
        _incomeStep('Annuity', IncomeType.annuity),
        _incomeStep('Part-time / employment', IncomeType.employment),
        _incomeStep('Rental income', IncomeType.other),
        _incomeStep('Other income', IncomeType.other),
      ],
    );

IStep _accountStep(String name, AccountType type) => IStep(
      title: name,
      helper: 'Current balance of your $name. Leave blank to skip.',
      fields: [const IField('bal', 'Current balance', IKind.money)],
      apply: (ref, v) {
        final b = (v['bal'] as double?) ?? 0;
        if (b <= 0) return;
        _upsertAccount(ref, name, type, b);
      },
    );

Interview investmentsInterview() => Interview(
      title: 'Investments',
      icon: Icons.account_balance_outlined,
      steps: [
        _accountStep('Checking & savings', AccountType.cash),
        _accountStep('Brokerage / taxable', AccountType.taxable),
        _accountStep('401(k) / 403(b)', AccountType.traditional401k),
        _accountStep('Traditional IRA', AccountType.traditionalIra),
        _accountStep('Roth 401(k)', AccountType.roth401k),
        _accountStep('Roth IRA', AccountType.rothIra),
        _accountStep('HSA', AccountType.hsa),
        _accountStep('Other investments', AccountType.taxable),
      ],
    );

IStep _liabilityStep(String name, LiabilityType type, double rate) => IStep(
      title: name,
      helper: 'Balance and monthly payment for your $name. Leave blank to skip.',
      fields: [
        const IField('bal', 'Outstanding balance', IKind.money),
        const IField('pay', 'Monthly payment', IKind.money),
      ],
      apply: (ref, v) {
        final b = (v['bal'] as double?) ?? 0;
        if (b <= 0) return;
        final pay = (v['pay'] as double?) ?? 0;
        _upsertLiability(ref, name, type, b, pay, rate);
      },
    );

Interview liabilitiesInterview() => Interview(
      title: 'Liabilities',
      icon: Icons.credit_card_outlined,
      steps: [
        _liabilityStep('Mortgage', LiabilityType.mortgage, 0.06),
        _liabilityStep('Auto loan', LiabilityType.auto, 0.07),
        _liabilityStep('Student loans', LiabilityType.student, 0.05),
        _liabilityStep('Credit cards', LiabilityType.creditCard, 0.20),
        _liabilityStep('Personal / other loans', LiabilityType.loan, 0.08),
      ],
    );

Interview taxesInterview() => Interview(
      title: 'Taxes',
      icon: Icons.request_quote_outlined,
      steps: [
        IStep(
          title: 'Filing status',
          helper: 'How do you file your federal taxes?',
          fields: [
            IField('fs', 'Filing status', IKind.choice,
                choices: [for (final f in FilingStatus.values) f.label]),
          ],
          apply: (ref, v) {
            final label = v['fs'] as String?;
            if (label == null) return;
            final fs = FilingStatus.values.firstWhere((x) => x.label == label,
                orElse: () => FilingStatus.single);
            final c = ref.read(planControllerProvider.notifier);
            c.setProfile(ref.read(planControllerProvider).profile.copyWith(filingStatus: fs));
          },
        ),
        IStep(
          title: 'Your state',
          helper: 'Which state do you live in? (optional — for context)',
          fields: [const IField('st', 'State', IKind.text)],
          apply: (ref, v) {
            final st = (v['st'] as String?) ?? '';
            if (st.isEmpty) return;
            final c = ref.read(planControllerProvider.notifier);
            c.setProfile(ref.read(planControllerProvider).profile.copyWith(state: st));
          },
        ),
        // --- Figures from your most recent return (Form 1040) ---------------
        _taxMoneyStep(
          'Wages & salary',
          'From your W-2 / Form 1040 line 1 — total wages, salaries and tips for '
              'the year. Leave blank if retired.',
          'Annual wages',
          (t, v) => t.copyWith(wages: v),
        ),
        _taxMoneyStep(
          'Taxable interest',
          'Interest income from banks, CDs and bonds (1040 line 2b).',
          'Taxable interest',
          (t, v) => t.copyWith(interest: v),
        ),
        _taxMoneyStep(
          'Ordinary dividends',
          'Total ordinary dividends (1040 line 3b), including the qualified portion.',
          'Ordinary dividends',
          (t, v) => t.copyWith(ordinaryDividends: v),
        ),
        _taxMoneyStep(
          'Qualified dividends',
          'The qualified portion of those dividends (1040 line 3a) — taxed at the '
              'lower capital-gains rate.',
          'Qualified dividends',
          (t, v) => t.copyWith(qualifiedDividends: v),
        ),
        _taxMoneyStep(
          'Long-term capital gains',
          'Net long-term gains from assets held over a year (Schedule D). Taxed at '
              'preferential rates.',
          'Long-term gains',
          (t, v) => t.copyWith(longTermGains: v),
        ),
        _taxMoneyStep(
          'Short-term capital gains',
          'Net short-term gains from assets held a year or less (Schedule D). Taxed '
              'as ordinary income.',
          'Short-term gains',
          (t, v) => t.copyWith(shortTermGains: v),
        ),
        _taxMoneyStep(
          'Business / self-employment income',
          'Net profit from a business or 1099 work (Schedule C / K-1).',
          'Business income',
          (t, v) => t.copyWith(businessIncome: v),
        ),
        _taxMoneyStep(
          'IRA, pension & annuity distributions',
          'Taxable retirement-account withdrawals, pensions and annuities '
              '(1040 lines 4b + 5b).',
          'Distributions',
          (t, v) => t.copyWith(iraPensionDistributions: v),
        ),
        _taxMoneyStep(
          'Social Security benefits',
          'Total Social Security received for the year (1040 line 6a, the gross '
              'amount).',
          'Social Security',
          (t, v) => t.copyWith(ssBenefits: v),
        ),
        _taxMoneyStep(
          'Other income',
          'Anything not captured above — rental, royalties, unemployment, etc.',
          'Other income',
          (t, v) => t.copyWith(otherIncome: v),
        ),
        _taxMoneyStep(
          'Pre-tax contributions',
          'Money you put into a 401(k), traditional IRA, or HSA before tax this '
              'year — these reduce taxable income.',
          'Pre-tax contributions',
          (t, v) => t.copyWith(pretaxContributions: v),
        ),
        IStep(
          title: 'Deduction method',
          helper: 'Do you take the standard deduction or itemize? Itemizing helps '
              'only when deductible expenses exceed the standard amount.',
          fields: const [
            IField('method', 'Deduction method', IKind.choice,
                choices: ['Standard deduction', 'Itemize']),
          ],
          apply: (ref, v) {
            final m = v['method'] as String?;
            if (m == null) return;
            final c = ref.read(planControllerProvider.notifier);
            c.setTaxProfile(ref
                .read(planControllerProvider)
                .taxProfile
                .copyWith(usesItemized: m == 'Itemize'));
          },
        ),
        _taxMoneyStep(
          'Itemized deductions',
          'If you itemize, the total of mortgage interest, SALT (capped at '
              '\$10,000), charity and medical. Skip if you take the standard '
              'deduction.',
          'Itemized total',
          (t, v) => t.copyWith(itemizedDeductions: v),
        ),
        _taxMoneyStep(
          'Total tax paid',
          'Total federal tax from last year\'s return (1040 line 22), if you know '
              'it — used to sanity-check the estimate.',
          'Total tax',
          (t, v) => t.copyWith(estTotalTax: v),
        ),
      ],
    );

Interview youInterview() => Interview(
      title: 'About you',
      icon: Icons.person_outline,
      steps: [
        IStep(
          title: 'Your age',
          helper: 'How old are you today?',
          fields: [const IField('age', 'Current age', IKind.age)],
          apply: (ref, v) {
            final a = (v['age'] as int?) ?? 0;
            if (a > 0) ref.read(planControllerProvider.notifier).setCurrentAge(a, DateTime.now());
          },
        ),
        IStep(
          title: 'Retirement',
          helper: 'At what age do you plan to retire?',
          fields: [const IField('rage', 'Retirement age', IKind.age)],
          apply: (ref, v) {
            final a = (v['rage'] as int?) ?? 0;
            if (a <= 0) return;
            final c = ref.read(planControllerProvider.notifier);
            c.setProfile(ref.read(planControllerProvider).profile.copyWith(retirementAge: a));
          },
        ),
        IStep(
          title: 'Plan horizon',
          helper: 'Through what age should we plan? (life expectancy)',
          fields: [const IField('eage', 'Plan through age', IKind.age)],
          apply: (ref, v) {
            final a = (v['eage'] as int?) ?? 0;
            if (a <= 0) return;
            final c = ref.read(planControllerProvider.notifier);
            c.setProfile(ref.read(planControllerProvider).profile.copyWith(lifeExpectancy: a));
          },
        ),
      ],
    );

/// Reference table showing how the Social Security benefit changes with the age
/// it is claimed (62–70), driven by an estimated full-retirement-age benefit.
class SocialSecurityTableDialog extends StatefulWidget {
  const SocialSecurityTableDialog({super.key, required this.initialAnnual});
  final double initialAnnual;
  @override
  State<SocialSecurityTableDialog> createState() => _SocialSecurityTableDialogState();
}

class _SocialSecurityTableDialogState extends State<SocialSecurityTableDialog> {
  late final TextEditingController _ctrl = TextEditingController(
      text: widget.initialAnnual > 0 ? widget.initialAnnual.toStringAsFixed(0) : '');

  double get _fra => parseMoney(_ctrl.text);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fra = _fra;
    return AlertDialog(
      title: const Text('Social Security by claim age'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter your estimated benefit at full retirement age (67). The table '
                'shows how claiming earlier or later changes it. Estimates only — use '
                'your ssa.gov statement for exact figures.',
                style: TextStyle(fontSize: 12.5),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ctrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Annual benefit at age 67', prefixText: '\$ '),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowHeight: 34,
                  dataRowMinHeight: 30,
                  dataRowMaxHeight: 36,
                  columnSpacing: 18,
                  columns: const [
                    DataColumn(label: Text('Age')),
                    DataColumn(label: Text('% of FRA')),
                    DataColumn(label: Text('Monthly')),
                    DataColumn(label: Text('Annual')),
                  ],
                  rows: [
                    for (var age = 62; age <= 70; age++)
                      _row(age, fra, isFra: age == SocialSecurity.fra),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
      ],
    );
  }

  DataRow _row(int age, double fra, {required bool isFra}) {
    final pct = SocialSecurity.adjustForClaimAge(1.0, age);
    final annual = SocialSecurity.adjustForClaimAge(fra, age);
    final style = isFra ? const TextStyle(fontWeight: FontWeight.bold) : null;
    Widget cell(String s) => Text(s, style: style);
    return DataRow(
      color: isFra
          ? WidgetStatePropertyAll(Colors.tealAccent.withValues(alpha: 0.12))
          : null,
      cells: [
        DataCell(cell(isFra ? '$age (FRA)' : '$age')),
        DataCell(cell('${(pct * 100).round()}%')),
        DataCell(cell(fra > 0 ? money(annual / 12) : '—')),
        DataCell(cell(fra > 0 ? money(annual) : '—')),
      ],
    );
  }
}

// --- The wizard UI -----------------------------------------------------------

class _InterviewDialog extends ConsumerStatefulWidget {
  const _InterviewDialog({required this.interview});
  final Interview interview;
  @override
  ConsumerState<_InterviewDialog> createState() => _InterviewDialogState();
}

class _InterviewDialogState extends ConsumerState<_InterviewDialog> {
  int _i = 0;
  final Map<String, TextEditingController> _ctrls = {};
  final Map<String, String?> _choices = {};

  List<IStep> get _steps => widget.interview.steps;

  TextEditingController _ctrl(String key) => _ctrls.putIfAbsent(key, () => TextEditingController());

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> _collect() {
    final step = _steps[_i];
    final values = <String, dynamic>{};
    for (final f in step.fields) {
      final key = '$_i.${f.key}';
      values[f.key] = switch (f.kind) {
        IKind.money => parseMoney(_ctrls[key]?.text ?? ''),
        IKind.percent => parsePercent(_ctrls[key]?.text ?? ''),
        IKind.age => int.tryParse(_ctrls[key]?.text ?? '') ?? 0,
        IKind.text => (_ctrls[key]?.text ?? '').trim(),
        IKind.choice => _choices[key],
      };
    }
    return values;
  }

  void _applyCurrent() => _steps[_i].apply(ref, _collect());

  void _next({required bool apply}) {
    if (apply) _applyCurrent();
    if (_i < _steps.length - 1) {
      setState(() => _i++);
    } else {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${widget.interview.title} updated')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_i];
    final isLast = _i == _steps.length - 1;
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
          title: Row(children: [
            Icon(widget.interview.icon, size: 20),
            const SizedBox(width: 8),
            Text('${widget.interview.title} setup'),
          ]),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(value: (_i + 1) / _steps.length, minHeight: 4),
          ),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Step ${_i + 1} of ${_steps.length}',
                      style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 8),
                  Text(step.title, style: Theme.of(context).textTheme.headlineSmall),
                  if (step.helper != null) ...[
                    const SizedBox(height: 8),
                    Text(step.helper!, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                  const SizedBox(height: 20),
                  for (final f in step.fields) ...[
                    _fieldWidget(f),
                    const SizedBox(height: 12),
                  ],
                  if (step.infoLabel != null && step.infoBuilder != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => showDialog(
                          context: context,
                          builder: (_) => step.infoBuilder!(context, _collect()),
                        ),
                        icon: const Icon(Icons.table_chart_outlined, size: 18),
                        label: Text(step.infoLabel!),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                if (_i > 0)
                  TextButton(onPressed: () => setState(() => _i--), child: const Text('Back')),
                const Spacer(),
                TextButton(onPressed: () => _next(apply: false), child: const Text('Skip')),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => _next(apply: true),
                  child: Text(isLast ? 'Finish' : 'Next'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fieldWidget(IField f) {
    final key = '$_i.${f.key}';
    switch (f.kind) {
      case IKind.choice:
        return DropdownButtonFormField<String>(
          value: _choices[key],
          isExpanded: true,
          decoration: InputDecoration(labelText: f.label),
          items: [for (final c in f.choices) DropdownMenuItem(value: c, child: Text(c))],
          onChanged: (v) => setState(() => _choices[key] = v),
        );
      case IKind.text:
        return TextField(
          controller: _ctrl(key),
          decoration: InputDecoration(labelText: f.label),
        );
      case IKind.age:
        return TextField(
          controller: _ctrl(key),
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: f.label),
        );
      case IKind.percent:
        return TextField(
          controller: _ctrl(key),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: f.label, suffixText: '%'),
        );
      case IKind.money:
        return TextField(
          controller: _ctrl(key),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: f.label, prefixText: '\$ '),
          autofocus: true,
        );
    }
  }
}

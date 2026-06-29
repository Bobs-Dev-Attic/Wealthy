import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../models/account.dart';
import '../../models/enums.dart';
import '../../models/expense.dart';
import '../../models/income_source.dart';
import '../../models/liability.dart';
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
  const IStep({required this.title, this.helper, required this.fields, required this.apply});
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
        _expenseStep('Electricity', ExpenseCategory.living),
        _expenseStep('Water & sewer', ExpenseCategory.living),
        _expenseStep('Gas & heating', ExpenseCategory.living),
        _expenseStep('Internet & cable', ExpenseCategory.living),
        _expenseStep('Phone', ExpenseCategory.living),
        _expenseStep('Streaming & subscriptions', ExpenseCategory.living),
        _expenseStep('Groceries', ExpenseCategory.living, freq: 'week'),
        _expenseStep('Dining out', ExpenseCategory.living),
        _expenseStep('Transportation & fuel', ExpenseCategory.living),
        _expenseStep('Insurance (auto/home/life)', ExpenseCategory.living),
        _expenseStep('Healthcare & medical', ExpenseCategory.healthcare),
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

Interview incomeInterview() => Interview(
      title: 'Income',
      icon: Icons.payments_outlined,
      steps: [
        _incomeStep('Social Security', IncomeType.socialSecurity, startAge: 67),
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
        _accountStep('401(k) / 403(b)', AccountType.traditional),
        _accountStep('Traditional IRA', AccountType.traditional),
        _accountStep('Roth IRA / Roth 401(k)', AccountType.roth),
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

  void _applyCurrent() {
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
    step.apply(ref, values);
  }

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

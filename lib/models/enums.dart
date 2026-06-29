/// Account tax treatment.
enum AccountType { taxable, traditional, roth, hsa, cash }

/// Income source kinds. `socialSecurity` is taxed specially (provisional income).
enum IncomeType { socialSecurity, pension, annuity, employment, other }

enum ExpenseCategory {
  housing,
  electricity,
  water,
  gas,
  internet,
  phone,
  utilities,
  groceries,
  dining,
  food,
  transportation,
  insurance,
  healthcare,
  subscriptions,
  entertainment,
  personal,
  education,
  childcare,
  pets,
  charity,
  travel,
  living,
  other,
}

enum FilingStatus { single, marriedJoint, marriedSeparate, headOfHousehold }

enum WithdrawalStrategy { fixedPercent, inflationAdjusted, guardrails, vpw }

/// Maps between Dart enums and the snake_case strings stored in Postgres.
extension AccountTypeX on AccountType {
  String get db => switch (this) {
        AccountType.taxable => 'taxable',
        AccountType.traditional => 'traditional',
        AccountType.roth => 'roth',
        AccountType.hsa => 'hsa',
        AccountType.cash => 'cash',
      };
  String get label => switch (this) {
        AccountType.taxable => 'Taxable brokerage',
        AccountType.traditional => 'Traditional / 401(k) / IRA',
        AccountType.roth => 'Roth',
        AccountType.hsa => 'HSA',
        AccountType.cash => 'Cash / savings',
      };
  /// Tax-deferred accounts subject to Required Minimum Distributions.
  bool get isTaxDeferred => this == AccountType.traditional;
  static AccountType fromDb(String s) =>
      AccountType.values.firstWhere((e) => e.db == s, orElse: () => AccountType.taxable);
}

extension IncomeTypeX on IncomeType {
  String get db => switch (this) {
        IncomeType.socialSecurity => 'social_security',
        IncomeType.pension => 'pension',
        IncomeType.annuity => 'annuity',
        IncomeType.employment => 'employment',
        IncomeType.other => 'other',
      };
  String get label => switch (this) {
        IncomeType.socialSecurity => 'Social Security',
        IncomeType.pension => 'Pension',
        IncomeType.annuity => 'Annuity',
        IncomeType.employment => 'Employment',
        IncomeType.other => 'Other',
      };
  static IncomeType fromDb(String s) =>
      IncomeType.values.firstWhere((e) => e.db == s, orElse: () => IncomeType.other);
}

extension ExpenseCategoryX on ExpenseCategory {
  String get db => switch (this) {
        ExpenseCategory.housing => 'housing',
        ExpenseCategory.electricity => 'electricity',
        ExpenseCategory.water => 'water',
        ExpenseCategory.gas => 'gas',
        ExpenseCategory.internet => 'internet',
        ExpenseCategory.phone => 'phone',
        ExpenseCategory.utilities => 'utilities',
        ExpenseCategory.groceries => 'groceries',
        ExpenseCategory.dining => 'dining',
        ExpenseCategory.food => 'food',
        ExpenseCategory.transportation => 'transportation',
        ExpenseCategory.insurance => 'insurance',
        ExpenseCategory.healthcare => 'healthcare',
        ExpenseCategory.subscriptions => 'subscriptions',
        ExpenseCategory.entertainment => 'entertainment',
        ExpenseCategory.personal => 'personal',
        ExpenseCategory.education => 'education',
        ExpenseCategory.childcare => 'childcare',
        ExpenseCategory.pets => 'pets',
        ExpenseCategory.charity => 'charity',
        ExpenseCategory.travel => 'travel',
        ExpenseCategory.living => 'living',
        ExpenseCategory.other => 'other',
      };
  String get label => switch (this) {
        ExpenseCategory.housing => 'Housing / rent',
        ExpenseCategory.electricity => 'Electricity',
        ExpenseCategory.water => 'Water & sewer',
        ExpenseCategory.gas => 'Gas & heating',
        ExpenseCategory.internet => 'Internet & cable',
        ExpenseCategory.phone => 'Phone',
        ExpenseCategory.utilities => 'Utilities (other)',
        ExpenseCategory.groceries => 'Groceries',
        ExpenseCategory.dining => 'Dining out',
        ExpenseCategory.food => 'Food (other)',
        ExpenseCategory.transportation => 'Transportation & fuel',
        ExpenseCategory.insurance => 'Insurance',
        ExpenseCategory.healthcare => 'Healthcare & medical',
        ExpenseCategory.subscriptions => 'Streaming & subscriptions',
        ExpenseCategory.entertainment => 'Entertainment',
        ExpenseCategory.personal => 'Personal care & clothing',
        ExpenseCategory.education => 'Education',
        ExpenseCategory.childcare => 'Childcare',
        ExpenseCategory.pets => 'Pets',
        ExpenseCategory.charity => 'Charity & gifts',
        ExpenseCategory.travel => 'Travel & vacations',
        ExpenseCategory.living => 'Living (other essentials)',
        ExpenseCategory.other => 'Other',
      };
  static ExpenseCategory fromDb(String s) =>
      ExpenseCategory.values.firstWhere((e) => e.db == s, orElse: () => ExpenseCategory.other);
}

extension FilingStatusX on FilingStatus {
  String get db => switch (this) {
        FilingStatus.single => 'single',
        FilingStatus.marriedJoint => 'married_joint',
        FilingStatus.marriedSeparate => 'married_separate',
        FilingStatus.headOfHousehold => 'head_of_household',
      };
  String get label => switch (this) {
        FilingStatus.single => 'Single',
        FilingStatus.marriedJoint => 'Married filing jointly',
        FilingStatus.marriedSeparate => 'Married filing separately',
        FilingStatus.headOfHousehold => 'Head of household',
      };
  static FilingStatus fromDb(String s) =>
      FilingStatus.values.firstWhere((e) => e.db == s, orElse: () => FilingStatus.single);
}

extension WithdrawalStrategyX on WithdrawalStrategy {
  String get db => switch (this) {
        WithdrawalStrategy.fixedPercent => 'fixed_percent',
        WithdrawalStrategy.inflationAdjusted => 'inflation_adjusted',
        WithdrawalStrategy.guardrails => 'guardrails',
        WithdrawalStrategy.vpw => 'vpw',
      };
  String get label => switch (this) {
        WithdrawalStrategy.fixedPercent => 'Fixed % of portfolio',
        WithdrawalStrategy.inflationAdjusted => 'Inflation-adjusted (4% rule)',
        WithdrawalStrategy.guardrails => 'Guyton-Klinger guardrails',
        WithdrawalStrategy.vpw => 'Variable percentage (VPW)',
      };
  static WithdrawalStrategy fromDb(String s) =>
      WithdrawalStrategy.values.firstWhere((e) => e.db == s,
          orElse: () => WithdrawalStrategy.inflationAdjusted);
}

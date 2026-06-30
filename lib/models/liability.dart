import 'dart:math' as math;

/// Debt the user owes — reduces net worth and, while outstanding, adds a
/// payment to annual expenses.
enum LiabilityType { mortgage, auto, student, creditCard, loan, other }

/// For mortgages, the rate/loan structure (informational + shown on the debt
/// schedule).
enum MortgageKind { fixed, variable, jumbo }

extension MortgageKindX on MortgageKind {
  String get db => switch (this) {
        MortgageKind.fixed => 'fixed',
        MortgageKind.variable => 'variable',
        MortgageKind.jumbo => 'jumbo',
      };
  String get label => switch (this) {
        MortgageKind.fixed => 'Fixed-rate',
        MortgageKind.variable => 'Variable / ARM',
        MortgageKind.jumbo => 'Jumbo',
      };
  static MortgageKind? fromDb(String? s) {
    if (s == null || s.isEmpty) return null;
    for (final k in MortgageKind.values) {
      if (k.db == s) return k;
    }
    return null;
  }
}

extension LiabilityTypeX on LiabilityType {
  String get db => switch (this) {
        LiabilityType.mortgage => 'mortgage',
        LiabilityType.auto => 'auto',
        LiabilityType.student => 'student',
        LiabilityType.creditCard => 'credit_card',
        LiabilityType.loan => 'loan',
        LiabilityType.other => 'other',
      };
  String get label => switch (this) {
        LiabilityType.mortgage => 'Mortgage',
        LiabilityType.auto => 'Auto loan',
        LiabilityType.student => 'Student loan',
        LiabilityType.creditCard => 'Credit card',
        LiabilityType.loan => 'Loan',
        LiabilityType.other => 'Other',
      };
  static LiabilityType fromDb(String s) =>
      LiabilityType.values.firstWhere((e) => e.db == s, orElse: () => LiabilityType.other);
}

class Liability {
  final String? id;
  final String name;
  final LiabilityType type;
  final double balance;
  final double interestRate;
  final double monthlyPayment;

  /// Mortgage-only structure (null for non-mortgages).
  final MortgageKind? mortgageKind;

  /// Optional loan term in years (0 = unspecified). Bounds the schedule.
  final int termYears;

  /// Optional extra amount paid each month on top of [monthlyPayment].
  final double extraMonthlyPayment;

  const Liability({
    this.id,
    required this.name,
    required this.type,
    required this.balance,
    this.interestRate = 0.05,
    this.monthlyPayment = 0,
    this.mortgageKind,
    this.termYears = 0,
    this.extraMonthlyPayment = 0,
  });

  Liability copyWith({
    String? id,
    String? name,
    LiabilityType? type,
    double? balance,
    double? interestRate,
    double? monthlyPayment,
    MortgageKind? mortgageKind,
    int? termYears,
    double? extraMonthlyPayment,
  }) =>
      Liability(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        balance: balance ?? this.balance,
        interestRate: interestRate ?? this.interestRate,
        monthlyPayment: monthlyPayment ?? this.monthlyPayment,
        mortgageKind: mortgageKind ?? this.mortgageKind,
        termYears: termYears ?? this.termYears,
        extraMonthlyPayment: extraMonthlyPayment ?? this.extraMonthlyPayment,
      );

  factory Liability.fromJson(Map<String, dynamic> j) => Liability(
        id: j['id'] as String?,
        name: (j['name'] ?? '') as String,
        type: LiabilityTypeX.fromDb((j['type'] ?? 'other') as String),
        balance: (j['balance'] as num?)?.toDouble() ?? 0,
        interestRate: (j['interest_rate'] as num?)?.toDouble() ?? 0.05,
        monthlyPayment: (j['monthly_payment'] as num?)?.toDouble() ?? 0,
        mortgageKind: MortgageKindX.fromDb(j['mortgage_kind'] as String?),
        termYears: (j['term_years'] as num?)?.toInt() ?? 0,
        extraMonthlyPayment: (j['extra_monthly_payment'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toInsert(String userId) => {
        'user_id': userId,
        'name': name,
        'type': type.db,
        'balance': balance,
        'interest_rate': interestRate,
        'monthly_payment': monthlyPayment,
        'mortgage_kind': mortgageKind?.db,
        'term_years': termYears,
        'extra_monthly_payment': extraMonthlyPayment,
      };

  /// Total paid each month, including any extra payment.
  double get totalMonthlyPayment => monthlyPayment + extraMonthlyPayment;

  double get annualPayment => totalMonthlyPayment * 12;

  /// Years to pay off at the current payment using the standard amortization
  /// formula. Returns 99 if the payment never covers the interest.
  double get payoffYears {
    if (balance <= 0) return 0;
    final pay = totalMonthlyPayment;
    if (pay <= 0) return 99;
    final r = interestRate / 12;
    if (r <= 0) return (balance / pay) / 12;
    final monthlyInterest = balance * r;
    if (pay <= monthlyInterest) return 99;
    final n = -math.log(1 - (r * balance) / pay) / math.log(1 + r);
    return n / 12;
  }

  /// Outstanding balance after [years] of payments (amortized, floored at 0).
  double balanceAfter(double years) {
    if (balance <= 0) return 0;
    final months = years * 12;
    final r = interestRate / 12;
    final pay = totalMonthlyPayment;
    if (pay <= 0) {
      // No payments: balance grows with interest.
      return balance * math.pow(1 + r, months).toDouble();
    }
    if (r <= 0) {
      return math.max(0, balance - pay * months);
    }
    final grown = balance * math.pow(1 + r, months).toDouble();
    final paid = pay * ((math.pow(1 + r, months).toDouble() - 1) / r);
    return math.max(0, grown - paid);
  }
}

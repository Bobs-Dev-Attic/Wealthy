import 'dart:math' as math;

/// Debt the user owes — reduces net worth and, while outstanding, adds a
/// payment to annual expenses.
enum LiabilityType { mortgage, auto, student, creditCard, loan, other }

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

  const Liability({
    this.id,
    required this.name,
    required this.type,
    required this.balance,
    this.interestRate = 0.05,
    this.monthlyPayment = 0,
  });

  Liability copyWith({
    String? id,
    String? name,
    LiabilityType? type,
    double? balance,
    double? interestRate,
    double? monthlyPayment,
  }) =>
      Liability(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        balance: balance ?? this.balance,
        interestRate: interestRate ?? this.interestRate,
        monthlyPayment: monthlyPayment ?? this.monthlyPayment,
      );

  factory Liability.fromJson(Map<String, dynamic> j) => Liability(
        id: j['id'] as String?,
        name: (j['name'] ?? '') as String,
        type: LiabilityTypeX.fromDb((j['type'] ?? 'other') as String),
        balance: (j['balance'] as num?)?.toDouble() ?? 0,
        interestRate: (j['interest_rate'] as num?)?.toDouble() ?? 0.05,
        monthlyPayment: (j['monthly_payment'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toInsert(String userId) => {
        'user_id': userId,
        'name': name,
        'type': type.db,
        'balance': balance,
        'interest_rate': interestRate,
        'monthly_payment': monthlyPayment,
      };

  double get annualPayment => monthlyPayment * 12;

  /// Years to pay off at the current payment using the standard amortization
  /// formula. Returns 99 if the payment never covers the interest.
  double get payoffYears {
    if (balance <= 0) return 0;
    if (monthlyPayment <= 0) return 99;
    final r = interestRate / 12;
    if (r <= 0) return (balance / monthlyPayment) / 12;
    final monthlyInterest = balance * r;
    if (monthlyPayment <= monthlyInterest) return 99;
    final n = -math.log(1 - (r * balance) / monthlyPayment) / math.log(1 + r);
    return n / 12;
  }

  /// Outstanding balance after [years] of payments (amortized, floored at 0).
  double balanceAfter(double years) {
    if (balance <= 0) return 0;
    final months = years * 12;
    final r = interestRate / 12;
    if (monthlyPayment <= 0) {
      // No payments: balance grows with interest.
      return balance * math.pow(1 + r, months).toDouble();
    }
    if (r <= 0) {
      return math.max(0, balance - monthlyPayment * months);
    }
    final grown = balance * math.pow(1 + r, months).toDouble();
    final paid = monthlyPayment * ((math.pow(1 + r, months).toDouble() - 1) / r);
    return math.max(0, grown - paid);
  }
}

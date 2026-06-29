import 'dart:math' as math;

/// Pure helpers for withdrawal strategies. The year-by-year loop lives in the
/// simulator ([RetirementProjection]); these functions provide the per-strategy
/// math so they can be unit tested in isolation.
class Withdrawal {
  /// Variable Percentage Withdrawal: the fraction of the current portfolio to
  /// spend at [age], using an annuity-payout formula over the remaining horizon
  /// with an assumed real return. Older ages withdraw a larger fraction.
  static double vpwFraction(int age, {int planEndAge = 100, double realReturn = 0.03}) {
    final years = math.max(1, planEndAge - age + 1);
    if (realReturn == 0) return 1 / years;
    return realReturn / (1 - math.pow(1 + realReturn, -years));
  }

  /// Guyton-Klinger guardrails applied to a base (inflation-adjusted) spend.
  ///
  /// If the current withdrawal rate drifts more than [band] above the initial
  /// rate, cut spending by [adjust]; if it drifts more than [band] below, raise
  /// spending by [adjust]. Returns the adjusted base spend.
  static double guardrailAdjust({
    required double baseSpend,
    required double currentWithdrawalRate,
    required double initialWithdrawalRate,
    double band = 0.20,
    double adjust = 0.10,
  }) {
    if (initialWithdrawalRate <= 0) return baseSpend;
    final upper = initialWithdrawalRate * (1 + band);
    final lower = initialWithdrawalRate * (1 - band);
    if (currentWithdrawalRate > upper) return baseSpend * (1 - adjust);
    if (currentWithdrawalRate < lower) return baseSpend * (1 + adjust);
    return baseSpend;
  }
}

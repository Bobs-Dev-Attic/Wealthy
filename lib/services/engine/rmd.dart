/// Required Minimum Distributions (RMDs).
///
/// Uses the IRS Uniform Lifetime Table (in effect since 2022). Under SECURE 2.0
/// the required beginning age is 73 (for those reaching 72 after 2022). RMD for
/// a year = prior year-end tax-deferred balance / the age's distribution period.
class Rmd {
  /// SECURE 2.0 required beginning age.
  static const int startAge = 73;

  /// Uniform Lifetime Table distribution periods (divisors) by age.
  static const Map<int, double> _table = {
    72: 27.4, 73: 26.5, 74: 25.5, 75: 24.6, 76: 23.7, 77: 22.9, 78: 22.0,
    79: 21.1, 80: 20.2, 81: 19.4, 82: 18.5, 83: 17.7, 84: 16.8, 85: 16.0,
    86: 15.2, 87: 14.4, 88: 13.7, 89: 12.9, 90: 12.2, 91: 11.5, 92: 10.8,
    93: 10.1, 94: 9.5, 95: 8.9, 96: 8.4, 97: 7.8, 98: 7.3, 99: 6.8, 100: 6.4,
    101: 6.0, 102: 5.6, 103: 5.2, 104: 4.9, 105: 4.6, 106: 4.3, 107: 4.1,
    108: 3.9, 109: 3.7, 110: 3.5, 111: 3.4, 112: 3.3, 113: 3.1, 114: 3.0,
    115: 2.9, 116: 2.8, 117: 2.7, 118: 2.5, 119: 2.3, 120: 2.0,
  };

  /// Distribution period for an age, or null if no RMD applies yet.
  static double? divisorForAge(int age) {
    if (age < startAge) return null;
    if (age >= 120) return 2.0;
    return _table[age];
  }

  /// Required distribution for [taxDeferredBalance] at [age]. Zero before [startAge].
  static double amount(double taxDeferredBalance, int age) {
    final divisor = divisorForAge(age);
    if (divisor == null || taxDeferredBalance <= 0) return 0;
    return taxDeferredBalance / divisor;
  }
}

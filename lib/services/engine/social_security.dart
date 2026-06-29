/// Social Security helpers.
///
/// Benefits are entered by the user as an annual amount (typically from their
/// ssa.gov statement). This module adjusts a Full Retirement Age (FRA) benefit
/// for an earlier or later claim age, and applies cost-of-living increases.
class SocialSecurity {
  /// Full Retirement Age used for claim-age adjustments.
  static const int fra = 67;

  /// Adjusts an FRA benefit for the chosen [claimAge].
  ///
  /// Early claiming (62–66): reduced 5/9% per month for the first 36 months and
  /// 5/12% per month beyond. Delayed claiming (68–70): +8% per year of delayed
  /// retirement credits. Claiming after 70 yields no further increase.
  static double adjustForClaimAge(double benefitAtFra, int claimAge) {
    if (claimAge == fra) return benefitAtFra;
    if (claimAge < fra) {
      final monthsEarly = (fra - claimAge) * 12;
      final first36 = monthsEarly > 36 ? 36 : monthsEarly;
      final beyond = monthsEarly > 36 ? monthsEarly - 36 : 0;
      final reduction = first36 * (5 / 9 / 100) + beyond * (5 / 12 / 100);
      return benefitAtFra * (1 - reduction);
    }
    final cappedAge = claimAge > 70 ? 70 : claimAge;
    final yearsDelayed = cappedAge - fra;
    return benefitAtFra * (1 + 0.08 * yearsDelayed);
  }

  /// Benefit at a given [age], started at [claimAge] with annual [cola] growth.
  /// Returns 0 before the claim age.
  static double benefitAtAge({
    required double benefitAtClaim,
    required int claimAge,
    required int age,
    required double cola,
  }) {
    if (age < claimAge) return 0;
    final years = age - claimAge;
    return benefitAtClaim * _pow1p(cola, years);
  }

  static double _pow1p(double rate, int years) {
    var f = 1.0;
    for (var i = 0; i < years; i++) {
      f *= (1 + rate);
    }
    return f;
  }
}

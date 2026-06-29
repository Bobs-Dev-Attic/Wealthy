/// Healthcare cost helper.
///
/// Provides rough default annual out-of-pocket + premium estimates so the UI can
/// prefill a healthcare expense. Pre-65 costs (private/ACA marketplace) are
/// materially higher than post-65 Medicare costs. Actual modeling uses the
/// user's entered healthcare expense grown at the plan's healthcare inflation.
class Healthcare {
  static const int medicareAge = 65;

  /// Default first-year healthcare cost (today's dollars) for a single person.
  static const double preMedicareAnnual = 12000; // private/ACA before 65
  static const double medicareAnnual = 7000; // Part B/D + Medigap + OOP at 65+

  /// Suggested annual healthcare cost at a given [age] in today's dollars.
  static double suggestedAnnual(int age, {bool couple = false}) {
    final base = age < medicareAge ? preMedicareAnnual : medicareAnnual;
    return couple ? base * 2 : base;
  }

  /// Cost at [age], inflating [baseAnnualAtStart] (today's dollars) by
  /// [healthcareInflation] over [yearsFromNow].
  static double costAtAge({
    required double baseAnnualAtStart,
    required double healthcareInflation,
    required int yearsFromNow,
  }) {
    var f = 1.0;
    for (var i = 0; i < yearsFromNow; i++) {
      f *= (1 + healthcareInflation);
    }
    return baseAnnualAtStart * f;
  }
}

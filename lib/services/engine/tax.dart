import '../../models/enums.dart';

/// Simplified U.S. **federal** income tax estimator for retirement planning.
///
/// This is an estimate, not tax advice. It models ordinary-income brackets,
/// the standard deduction, long-term capital-gains stacking, and the taxation
/// of Social Security benefits via provisional income. State tax is not modeled.
///
/// Tax year: 2025. Brackets/thresholds live in [_Brackets] so they can be
/// updated annually in one place.
class TaxEngine {
  /// Tax year these tables correspond to.
  static const int taxYear = 2025;

  /// Standard deduction by filing status (2025).
  static double standardDeduction(FilingStatus fs) => switch (fs) {
        FilingStatus.single => 15000,
        FilingStatus.marriedJoint => 30000,
        FilingStatus.marriedSeparate => 15000,
        FilingStatus.headOfHousehold => 22500,
      };

  /// Portion of Social Security benefits that is federally taxable.
  ///
  /// [otherIncome] is all non-SS income counted toward provisional income
  /// (ordinary income + long-term gains + tax-exempt interest).
  static double taxableSocialSecurity(
    double ssBenefits,
    double otherIncome,
    FilingStatus fs,
  ) {
    if (ssBenefits <= 0) return 0;
    final (base1, base2) = switch (fs) {
      FilingStatus.marriedJoint => (32000.0, 44000.0),
      FilingStatus.marriedSeparate => (0.0, 0.0),
      _ => (25000.0, 34000.0),
    };
    final provisional = otherIncome + 0.5 * ssBenefits;
    double taxable;
    if (provisional <= base1) {
      taxable = 0;
    } else if (provisional <= base2) {
      taxable = 0.5 * (provisional - base1);
    } else {
      final lower = 0.5 * (base2 - base1);
      taxable = 0.85 * (provisional - base2) + lower;
    }
    return taxable.clamp(0, 0.85 * ssBenefits).toDouble();
  }

  /// Estimated federal income tax for a retirement year.
  ///
  /// - [ordinaryIncomeExSS]: wages, pensions, annuities, traditional/IRA
  ///   withdrawals, RMDs, and taxable interest (everything taxed as ordinary,
  ///   excluding Social Security).
  /// - [ssBenefits]: gross Social Security received.
  /// - [longTermGains]: realized long-term capital gains from taxable accounts.
  static double federalIncomeTax({
    required double ordinaryIncomeExSS,
    required double ssBenefits,
    required double longTermGains,
    required FilingStatus fs,
  }) {
    final stdDed = standardDeduction(fs);
    final taxableSS = taxableSocialSecurity(
      ssBenefits,
      ordinaryIncomeExSS + longTermGains,
      fs,
    );

    final grossOrdinary = ordinaryIncomeExSS + taxableSS;
    final deductionOnOrdinary = grossOrdinary < stdDed ? grossOrdinary : stdDed;
    final remainingDeduction = stdDed - deductionOnOrdinary;
    final ordinaryTaxable = grossOrdinary - deductionOnOrdinary;
    final gainsTaxable = (longTermGains - remainingDeduction).clamp(0, double.infinity).toDouble();

    final ordinaryTax = _bracketTax(ordinaryTaxable, _Brackets.ordinary(fs));
    final ltcgTax = _capGainsTax(ordinaryTaxable, gainsTaxable, fs);
    return ordinaryTax + ltcgTax;
  }

  /// Effective average tax rate on the given income mix (for display).
  static double effectiveRate({
    required double ordinaryIncomeExSS,
    required double ssBenefits,
    required double longTermGains,
    required FilingStatus fs,
  }) {
    final gross = ordinaryIncomeExSS + ssBenefits + longTermGains;
    if (gross <= 0) return 0;
    final tax = federalIncomeTax(
      ordinaryIncomeExSS: ordinaryIncomeExSS,
      ssBenefits: ssBenefits,
      longTermGains: longTermGains,
      fs: fs,
    );
    return tax / gross;
  }

  /// Marginal ordinary rate at the given ordinary taxable income.
  static double marginalOrdinaryRate(double taxableOrdinary, FilingStatus fs) {
    final brackets = _Brackets.ordinary(fs);
    for (final (cap, rate) in brackets) {
      if (taxableOrdinary <= cap) return rate;
    }
    return brackets.last.$2;
  }

  /// Upper bound of the ordinary bracket containing [taxableOrdinary]
  /// (infinity for the top bracket).
  static double topOfOrdinaryBracket(double taxableOrdinary, FilingStatus fs) {
    for (final (cap, _) in _Brackets.ordinary(fs)) {
      if (taxableOrdinary < cap) return cap;
    }
    return double.infinity;
  }

  /// Top of the 0% long-term capital-gains bracket (taxable income).
  static double ltcgZeroTop(FilingStatus fs) => _Brackets.capGainsTops(fs).$1;

  static double _bracketTax(double taxable, List<(double, double)> brackets) {
    if (taxable <= 0) return 0;
    double tax = 0;
    double prevCap = 0;
    for (final (cap, rate) in brackets) {
      if (taxable > cap) {
        tax += (cap - prevCap) * rate;
        prevCap = cap;
      } else {
        tax += (taxable - prevCap) * rate;
        return tax;
      }
    }
    return tax;
  }

  /// Long-term capital gains stacked on top of ordinary taxable income.
  static double _capGainsTax(double ordinaryTaxable, double gains, FilingStatus fs) {
    if (gains <= 0) return 0;
    final (top0, top15) = _Brackets.capGainsTops(fs);
    final start = ordinaryTaxable;
    final gains0 = ((top0 - start).clamp(0, gains)).toDouble();
    var remaining = gains - gains0;
    final basis15 = start > top0 ? start : top0;
    final gains15 = ((top15 - basis15).clamp(0, remaining)).toDouble();
    remaining -= gains15;
    final gains20 = remaining;
    return gains15 * 0.15 + gains20 * 0.20;
  }
}

/// 2025 federal bracket tables.
class _Brackets {
  /// Ordinary-income brackets as (upper bound, marginal rate). Last bound is
  /// effectively infinity.
  static List<(double, double)> ordinary(FilingStatus fs) => switch (fs) {
        FilingStatus.marriedJoint => const [
            (23850, 0.10),
            (96950, 0.12),
            (206700, 0.22),
            (394600, 0.24),
            (501050, 0.32),
            (751600, 0.35),
            (double.infinity, 0.37),
          ],
        FilingStatus.headOfHousehold => const [
            (17000, 0.10),
            (64850, 0.12),
            (103350, 0.22),
            (197300, 0.24),
            (250500, 0.32),
            (626350, 0.35),
            (double.infinity, 0.37),
          ],
        FilingStatus.marriedSeparate => const [
            (11925, 0.10),
            (48475, 0.12),
            (103350, 0.22),
            (197300, 0.24),
            (250525, 0.32),
            (375800, 0.35),
            (double.infinity, 0.37),
          ],
        FilingStatus.single => const [
            (11925, 0.10),
            (48475, 0.12),
            (103350, 0.22),
            (197300, 0.24),
            (250525, 0.32),
            (626350, 0.35),
            (double.infinity, 0.37),
          ],
      };

  /// (top of 0% bracket, top of 15% bracket) for long-term capital gains.
  static (double, double) capGainsTops(FilingStatus fs) => switch (fs) {
        FilingStatus.marriedJoint => (96700, 600050),
        FilingStatus.headOfHousehold => (64750, 566700),
        FilingStatus.marriedSeparate => (48350, 300000),
        FilingStatus.single => (48350, 533400),
      };
}

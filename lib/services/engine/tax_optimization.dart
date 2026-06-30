import '../../models/enums.dart';
import '../../models/tax_profile.dart';
import 'tax.dart';

/// A single, plain-language tax-optimization suggestion.
class TaxTip {
  final String title;
  final String detail;
  const TaxTip(this.title, this.detail);
}

/// The result of analyzing a [TaxProfile] for optimization opportunities.
class TaxAnalysis {
  final double totalIncome;
  final double agi;
  final double deductionUsed; // larger of standard / itemized actually applied
  final double standardDeduction;
  final double taxableIncome;
  final double ordinaryTaxable; // taxable income excluding LTCG/qualified divs
  final double estimatedTax;
  final double marginalRate;
  final double effectiveRate;
  final double roomToNextBracket; // ordinary headroom before the next bracket
  final double ltcgZeroRoom; // gains taxable at 0% still available this year
  final bool itemizeBeats; // itemized > standard
  final List<TaxTip> tips;

  const TaxAnalysis({
    required this.totalIncome,
    required this.agi,
    required this.deductionUsed,
    required this.standardDeduction,
    required this.taxableIncome,
    required this.ordinaryTaxable,
    required this.estimatedTax,
    required this.marginalRate,
    required this.effectiveRate,
    required this.roomToNextBracket,
    required this.ltcgZeroRoom,
    required this.itemizeBeats,
    required this.tips,
  });
}

/// Analyzes a user's tax-return figures and surfaces concrete optimization
/// strategies (Roth-conversion headroom, 0% capital-gains harvesting, deduction
/// choice, etc.). Estimates only — not tax advice.
class TaxOptimization {
  static TaxAnalysis analyze(TaxProfile p, FilingStatus fs) {
    // Preferential-rate income (taxed in the LTCG stack).
    final preferential =
        (p.longTermGains.clamp(0, double.infinity) + p.qualifiedDividends).toDouble();
    // Ordinary income: everything else. Qualified dividends are a subset of
    // ordinary dividends, so back them out to avoid double counting.
    final ordinaryDivs =
        (p.ordinaryDividends - p.qualifiedDividends).clamp(0, double.infinity).toDouble();
    final ordinaryIncome = p.wages +
        p.interest +
        ordinaryDivs +
        p.shortTermGains +
        p.businessIncome +
        p.iraPensionDistributions +
        p.otherIncome;

    final taxableSS = TaxEngine.taxableSocialSecurity(
        p.ssBenefits, ordinaryIncome + preferential, fs);

    final totalIncome = ordinaryIncome + preferential + p.ssBenefits;
    final agi = ordinaryIncome + preferential + taxableSS - p.pretaxContributions;

    final std = TaxEngine.standardDeduction(fs);
    final itemizeBeats = p.usesItemized && p.itemizedDeductions > std;
    final deductionUsed = itemizeBeats ? p.itemizedDeductions : std;

    final grossOrdinary =
        (ordinaryIncome + taxableSS - p.pretaxContributions).clamp(0, double.infinity).toDouble();
    final dedOnOrdinary = grossOrdinary < deductionUsed ? grossOrdinary : deductionUsed;
    final ordinaryTaxable = grossOrdinary - dedOnOrdinary;
    final remainingDed = deductionUsed - dedOnOrdinary;
    final gainsTaxable =
        (preferential - remainingDed).clamp(0, double.infinity).toDouble();
    final taxableIncome = ordinaryTaxable + gainsTaxable;

    final estimatedTax = TaxEngine.federalIncomeTax(
      ordinaryIncomeExSS: (ordinaryIncome - p.pretaxContributions)
          .clamp(0, double.infinity)
          .toDouble(),
      ssBenefits: p.ssBenefits,
      longTermGains: preferential,
      fs: fs,
    );

    final marginal = TaxEngine.marginalOrdinaryRate(ordinaryTaxable, fs);
    final grossForRate = ordinaryIncome + preferential + p.ssBenefits;
    final effective = grossForRate > 0 ? estimatedTax / grossForRate : 0.0;

    final topOfBracket = TaxEngine.topOfOrdinaryBracket(ordinaryTaxable, fs);
    final roomToNext =
        topOfBracket.isFinite ? (topOfBracket - ordinaryTaxable) : double.infinity;

    final ltcgZeroTop = TaxEngine.ltcgZeroTop(fs);
    // 0% LTCG applies until taxable income (ordinary first, then gains) reaches
    // the 0% top; headroom is what's left after ordinary taxable fills it.
    final ltcgZeroRoom = (ltcgZeroTop - ordinaryTaxable - gainsTaxable)
        .clamp(0, double.infinity)
        .toDouble();

    final tips = _buildTips(
      p: p,
      fs: fs,
      marginal: marginal,
      roomToNext: roomToNext,
      ltcgZeroRoom: ltcgZeroRoom,
      itemizeBeats: itemizeBeats,
      std: std,
      taxableIncome: taxableIncome,
    );

    return TaxAnalysis(
      totalIncome: totalIncome,
      agi: agi,
      deductionUsed: deductionUsed,
      standardDeduction: std,
      taxableIncome: taxableIncome,
      ordinaryTaxable: ordinaryTaxable,
      estimatedTax: estimatedTax,
      marginalRate: marginal,
      effectiveRate: effective,
      roomToNextBracket: roomToNext,
      ltcgZeroRoom: ltcgZeroRoom,
      itemizeBeats: itemizeBeats,
      tips: tips,
    );
  }

  static List<TaxTip> _buildTips({
    required TaxProfile p,
    required FilingStatus fs,
    required double marginal,
    required double roomToNext,
    required double ltcgZeroRoom,
    required bool itemizeBeats,
    required double std,
    required double taxableIncome,
  }) {
    final tips = <TaxTip>[];
    String dollars(double v) => '\$${v.round().toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+$)'),
          (m) => '${m[1]},',
        )}';
    final pct = '${(marginal * 100).round()}%';

    // Roth conversion / fill-the-bracket headroom.
    if (roomToNext.isFinite && roomToNext > 1000) {
      tips.add(TaxTip(
        'Roth-conversion / bracket headroom',
        'You have about ${dollars(roomToNext)} of room before your income leaves '
            'the $pct bracket. Converting that much from a traditional IRA/401(k) '
            'to Roth — or otherwise realizing ordinary income — would be taxed at '
            'no more than $pct this year.',
      ));
    }

    // 0% long-term capital-gains harvesting.
    if (ltcgZeroRoom > 1000) {
      tips.add(TaxTip(
        '0% capital-gains harvesting',
        'About ${dollars(ltcgZeroRoom)} of long-term gains could be realized at the '
            '0% federal rate this year. Selling and immediately repurchasing '
            'appreciated holdings resets your cost basis tax-free.',
      ));
    }

    // Deduction strategy.
    if (p.usesItemized || p.itemizedDeductions > 0) {
      if (itemizeBeats) {
        tips.add(TaxTip(
          'Itemizing helps',
          'Your itemized deductions (${dollars(p.itemizedDeductions)}) exceed the '
              '${dollars(std)} standard deduction, so itemizing is the better choice. '
              'Bunching charitable gifts or a donor-advised fund can stretch the gap.',
        ));
      } else {
        tips.add(TaxTip(
          'Standard deduction wins',
          'The ${dollars(std)} standard deduction beats your itemized total '
              '(${dollars(p.itemizedDeductions)}). Consider "bunching" deductible '
              'expenses (charity, medical) into alternating years to clear the bar.',
        ));
      }
    } else {
      tips.add(TaxTip(
        'Using the standard deduction',
        'You\'re taking the ${dollars(std)} standard deduction. If charitable, '
            'medical, or SALT deductions are sizable, track them — bunching into one '
            'year can beat the standard amount.',
      ));
    }

    // Tax-deferred / pre-tax savings while working.
    if (p.wages > 0) {
      tips.add(TaxTip(
        'Pre-tax contributions',
        'Each \$1 added to a 401(k), traditional IRA, or HSA cuts taxable income at '
            'your $pct marginal rate. Maxing tax-deferred accounts is usually the '
            'highest-value lever while wages are high.',
      ));
    }

    // Social Security taxation awareness.
    if (p.ssBenefits > 0) {
      final taxableSS = TaxEngine.taxableSocialSecurity(
          p.ssBenefits,
          p.wages + p.interest + p.ordinaryDividends + p.iraPensionDistributions,
          fs);
      tips.add(TaxTip(
        'Social Security taxation',
        'About ${dollars(taxableSS)} of your ${dollars(p.ssBenefits)} in benefits is '
            'federally taxable at current income. Keeping other income lower (Roth '
            'withdrawals, gain timing) can reduce how much of your benefit is taxed.',
      ));
    }

    // Short-term gains warning.
    if (p.shortTermGains > 0) {
      tips.add(TaxTip(
        'Short-term gains taxed as ordinary income',
        'Your ${dollars(p.shortTermGains)} of short-term gains is taxed at $pct, far '
            'above the long-term rate. Holding positions past one year before selling '
            'would move them to preferential capital-gains rates.',
      ));
    }

    return tips;
  }
}

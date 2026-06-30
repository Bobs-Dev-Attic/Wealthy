/// Figures from a user's most recent tax return, used for tax-optimization
/// analysis (Roth conversions, gain harvesting, deduction strategy, etc.).
class TaxProfile {
  final String userId;
  final double wages;
  final double interest;
  final double ordinaryDividends;
  final double qualifiedDividends;
  final double longTermGains;
  final double shortTermGains;
  final double businessIncome;
  final double iraPensionDistributions;
  final double ssBenefits;
  final double otherIncome;
  final double pretaxContributions; // 401k/IRA/HSA pre-tax + other adjustments
  final double itemizedDeductions;
  final bool usesItemized;
  final double estTotalTax; // total tax from the return, if known

  const TaxProfile({
    required this.userId,
    this.wages = 0,
    this.interest = 0,
    this.ordinaryDividends = 0,
    this.qualifiedDividends = 0,
    this.longTermGains = 0,
    this.shortTermGains = 0,
    this.businessIncome = 0,
    this.iraPensionDistributions = 0,
    this.ssBenefits = 0,
    this.otherIncome = 0,
    this.pretaxContributions = 0,
    this.itemizedDeductions = 0,
    this.usesItemized = false,
    this.estTotalTax = 0,
  });

  /// True once the user has entered anything meaningful.
  bool get hasData =>
      wages > 0 ||
      interest > 0 ||
      ordinaryDividends > 0 ||
      longTermGains > 0 ||
      shortTermGains > 0 ||
      businessIncome > 0 ||
      iraPensionDistributions > 0 ||
      ssBenefits > 0 ||
      otherIncome > 0;

  TaxProfile copyWith({
    double? wages,
    double? interest,
    double? ordinaryDividends,
    double? qualifiedDividends,
    double? longTermGains,
    double? shortTermGains,
    double? businessIncome,
    double? iraPensionDistributions,
    double? ssBenefits,
    double? otherIncome,
    double? pretaxContributions,
    double? itemizedDeductions,
    bool? usesItemized,
    double? estTotalTax,
  }) =>
      TaxProfile(
        userId: userId,
        wages: wages ?? this.wages,
        interest: interest ?? this.interest,
        ordinaryDividends: ordinaryDividends ?? this.ordinaryDividends,
        qualifiedDividends: qualifiedDividends ?? this.qualifiedDividends,
        longTermGains: longTermGains ?? this.longTermGains,
        shortTermGains: shortTermGains ?? this.shortTermGains,
        businessIncome: businessIncome ?? this.businessIncome,
        iraPensionDistributions: iraPensionDistributions ?? this.iraPensionDistributions,
        ssBenefits: ssBenefits ?? this.ssBenefits,
        otherIncome: otherIncome ?? this.otherIncome,
        pretaxContributions: pretaxContributions ?? this.pretaxContributions,
        itemizedDeductions: itemizedDeductions ?? this.itemizedDeductions,
        usesItemized: usesItemized ?? this.usesItemized,
        estTotalTax: estTotalTax ?? this.estTotalTax,
      );

  factory TaxProfile.fromJson(Map<String, dynamic> j) => TaxProfile(
        userId: j['user_id'] as String,
        wages: _d(j['wages']),
        interest: _d(j['interest']),
        ordinaryDividends: _d(j['ordinary_dividends']),
        qualifiedDividends: _d(j['qualified_dividends']),
        longTermGains: _d(j['long_term_gains']),
        shortTermGains: _d(j['short_term_gains']),
        businessIncome: _d(j['business_income']),
        iraPensionDistributions: _d(j['ira_pension_distributions']),
        ssBenefits: _d(j['ss_benefits']),
        otherIncome: _d(j['other_income']),
        pretaxContributions: _d(j['pretax_contributions']),
        itemizedDeductions: _d(j['itemized_deductions']),
        usesItemized: (j['uses_itemized'] as bool?) ?? false,
        estTotalTax: _d(j['est_total_tax']),
      );

  Map<String, dynamic> toUpsert() => {
        'user_id': userId,
        'wages': wages,
        'interest': interest,
        'ordinary_dividends': ordinaryDividends,
        'qualified_dividends': qualifiedDividends,
        'long_term_gains': longTermGains,
        'short_term_gains': shortTermGains,
        'business_income': businessIncome,
        'ira_pension_distributions': iraPensionDistributions,
        'ss_benefits': ssBenefits,
        'other_income': otherIncome,
        'pretax_contributions': pretaxContributions,
        'itemized_deductions': itemizedDeductions,
        'uses_itemized': usesItemized,
        'est_total_tax': estTotalTax,
        'updated_at': DateTime.now().toIso8601String(),
      };

  static double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
}

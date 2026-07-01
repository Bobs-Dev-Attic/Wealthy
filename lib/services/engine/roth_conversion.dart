import 'dart:math' as math;

import '../../models/enums.dart';
import 'rmd.dart';
import 'tax.dart';

/// A Roth-conversion strategy to simulate against a traditional balance.
enum ConversionStrategy { none, fillCurrentBracket, fillNextBracket, levelGapYears, custom }

extension ConversionStrategyX on ConversionStrategy {
  String get label => switch (this) {
        ConversionStrategy.none => 'Do nothing (RMDs only)',
        ConversionStrategy.fillCurrentBracket => 'Fill to top of current bracket',
        ConversionStrategy.fillNextBracket => 'Fill through the next bracket',
        ConversionStrategy.levelGapYears => 'Level installments to zero by RMD age',
        ConversionStrategy.custom => 'Custom fixed amount',
      };

  String get description => switch (this) {
        ConversionStrategy.none =>
          'No conversions. The traditional balance keeps growing untaxed until '
              'RMDs begin, then forced withdrawals are taxed as ordinary income.',
        ConversionStrategy.fillCurrentBracket =>
          'Each year before RMDs start, convert just enough to use up the room left '
              'in your current marginal bracket — the classic "fill the bracket" move.',
        ConversionStrategy.fillNextBracket =>
          'A more aggressive version: convert enough to also fill the next bracket up, '
              'paying a higher marginal rate now to shrink the balance faster.',
        ConversionStrategy.levelGapYears =>
          'Split the traditional balance into equal conversions across every year '
              'between now and RMD age, smoothing the tax hit evenly.',
        ConversionStrategy.custom => 'Convert a fixed dollar amount every year until RMDs start.',
      };
}

/// One year of a simulated conversion strategy.
class ConversionYear {
  final int age;
  final double traditionalStart;
  final double conversion;
  final double rmd;
  final double ordinaryIncome; // wages/pension/SS-adjacent income excluding conversion/RMD
  final double taxableEvent; // conversion + rmd
  final double taxOnEvent; // incremental tax attributable to the conversion/RMD
  final double marginalRate;
  final double traditionalEnd;
  final double rothEnd;

  const ConversionYear({
    required this.age,
    required this.traditionalStart,
    required this.conversion,
    required this.rmd,
    required this.ordinaryIncome,
    required this.taxableEvent,
    required this.taxOnEvent,
    required this.marginalRate,
    required this.traditionalEnd,
    required this.rothEnd,
  });
}

/// The full simulated result of one strategy.
class ConversionResult {
  final ConversionStrategy strategy;
  final List<ConversionYear> years;

  const ConversionResult({required this.strategy, required this.years});

  double get totalConversionTax =>
      years.fold(0.0, (s, y) => s + (y.conversion > 0 ? y.taxOnEvent : 0));
  double get totalRmdTax => years.fold(0.0, (s, y) => s + (y.rmd > 0 ? y.taxOnEvent : 0));
  double get totalLifetimeTax => years.fold(0.0, (s, y) => s + y.taxOnEvent);
  double get totalConverted => years.fold(0.0, (s, y) => s + y.conversion);
  ConversionYear? get firstRmdYear {
    for (final y in years) {
      if (y.rmd > 0) return y;
    }
    return null;
  }

  double get endingTraditional => years.isEmpty ? 0 : years.last.traditionalEnd;
  double get endingRoth => years.isEmpty ? 0 : years.last.rothEnd;
}

/// The inputs describing a person for RMD tax-bomb / Roth-conversion analysis.
class RothConversionInputs {
  final int currentAge;
  final int retirementAge;
  final int planEndAge;
  final double traditionalBalance;
  final double rothBalance;
  final double preRetirementIncome; // ordinary income while still working
  final double postRetirementIncome; // ordinary income after retiring (pension/SS/part-time)
  final double growthRate;
  final FilingStatus filingStatus;

  const RothConversionInputs({
    required this.currentAge,
    required this.retirementAge,
    required this.planEndAge,
    required this.traditionalBalance,
    this.rothBalance = 0,
    this.preRetirementIncome = 0,
    this.postRetirementIncome = 0,
    this.growthRate = 0.06,
    this.filingStatus = FilingStatus.single,
  });

  double otherIncomeAt(int age) => age < retirementAge ? preRetirementIncome : postRetirementIncome;
}

/// Simulates the RMD "tax bomb" and compares Roth-conversion strategies against
/// it. Every strategy shares the same growth assumption and other-income
/// schedule so the only difference is how/when the traditional balance is
/// converted or forced out via RMDs.
class RothConversionEngine {
  static const int rmdAge = Rmd.startAge;

  static ConversionResult run(
    RothConversionInputs inp,
    ConversionStrategy strategy, {
    double customAnnualAmount = 0,
  }) {
    final fs = inp.filingStatus;
    final gapYears = math.max(0, rmdAge - inp.currentAge);
    final levelAmount = _levelPayment(inp.traditionalBalance, inp.growthRate, gapYears);
    final years = <ConversionYear>[];

    var trad = inp.traditionalBalance;
    var roth = inp.rothBalance;

    for (var age = inp.currentAge; age <= inp.planEndAge; age++) {
      final tradStart = trad;
      final other = inp.otherIncomeAt(age);
      final std = TaxEngine.standardDeduction(fs);
      final ordinaryTaxable = (other - std).clamp(0, double.infinity).toDouble();

      // --- Decide this year's conversion (only during the pre-RMD gap) ---
      double conversion = 0;
      if (age < rmdAge && trad > 0) {
        switch (strategy) {
          case ConversionStrategy.none:
            conversion = 0;
          case ConversionStrategy.fillCurrentBracket:
            final topOfBracket = TaxEngine.topOfOrdinaryBracket(ordinaryTaxable, fs);
            final room = topOfBracket.isFinite ? topOfBracket - ordinaryTaxable : trad;
            conversion = room.clamp(0, trad).toDouble();
          case ConversionStrategy.fillNextBracket:
            final topOfCurrent = TaxEngine.topOfOrdinaryBracket(ordinaryTaxable, fs);
            final topOfNext = topOfCurrent.isFinite
                ? TaxEngine.topOfOrdinaryBracket(topOfCurrent + 1, fs)
                : double.infinity;
            final room = topOfNext.isFinite ? topOfNext - ordinaryTaxable : trad;
            conversion = room.clamp(0, trad).toDouble();
          case ConversionStrategy.levelGapYears:
            conversion = levelAmount.clamp(0, trad).toDouble();
          case ConversionStrategy.custom:
            conversion = customAnnualAmount.clamp(0, trad).toDouble();
        }
      }

      // --- RMD once required, on whatever remains after this year's conversion ---
      final rmd = age >= rmdAge ? Rmd.amount(trad - conversion, age) : 0.0;

      // --- Tax: incremental tax caused by the conversion + RMD together ---
      final baseTax = TaxEngine.federalIncomeTax(
        ordinaryIncomeExSS: other,
        ssBenefits: 0,
        longTermGains: 0,
        fs: fs,
      );
      final withEventTax = TaxEngine.federalIncomeTax(
        ordinaryIncomeExSS: other + conversion + rmd,
        ssBenefits: 0,
        longTermGains: 0,
        fs: fs,
      );
      final taxOnEvent = withEventTax - baseTax;
      final marginal = TaxEngine.marginalOrdinaryRate(ordinaryTaxable + conversion + rmd, fs);

      trad = trad - conversion - rmd;
      roth += conversion;

      years.add(ConversionYear(
        age: age,
        traditionalStart: tradStart,
        conversion: conversion,
        rmd: rmd,
        ordinaryIncome: other,
        taxableEvent: conversion + rmd,
        taxOnEvent: taxOnEvent,
        marginalRate: marginal,
        traditionalEnd: trad,
        rothEnd: roth,
      ));

      trad *= (1 + inp.growthRate);
      roth *= (1 + inp.growthRate);
    }

    return ConversionResult(strategy: strategy, years: years);
  }

  /// The level annual conversion (an annuity-due payment) that fully drains
  /// [balance] over [years] years while it keeps growing at [growthRate] —
  /// i.e. the fixed amount that reaches (approximately) zero right at RMD age.
  static double _levelPayment(double balance, double growthRate, int years) {
    if (years <= 0) return 0;
    if (growthRate == 0) return balance / years;
    final growth = 1 + growthRate;
    // Present value factor of an n-payment annuity-due at rate growthRate.
    final factor = (1 - math.pow(growth, -years)) / growthRate * growth;
    return balance / factor;
  }

  /// Runs the baseline plus every preset strategy for side-by-side comparison.
  static List<ConversionResult> compareAll(RothConversionInputs inp, {double? customAnnualAmount}) {
    return [
      run(inp, ConversionStrategy.none),
      run(inp, ConversionStrategy.fillCurrentBracket),
      run(inp, ConversionStrategy.fillNextBracket),
      run(inp, ConversionStrategy.levelGapYears),
      if (customAnnualAmount != null && customAnnualAmount > 0)
        run(inp, ConversionStrategy.custom, customAnnualAmount: customAnnualAmount),
    ];
  }
}

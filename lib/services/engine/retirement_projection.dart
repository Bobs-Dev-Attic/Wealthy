import 'dart:math' as math;

import '../../models/account.dart';
import '../../models/enums.dart';
import '../../models/expense.dart';
import '../../models/holding.dart';
import '../../models/income_source.dart';
import '../../models/liability.dart';
import '../../models/plan_assumptions.dart';
import '../../models/profile.dart';
import '../../models/projection_result.dart';
import 'monte_carlo.dart';
import 'rmd.dart';
import 'tax.dart';
import 'withdrawal.dart';

/// Flattened, engine-ready snapshot of a user's plan. Built once via
/// [PlanInputs.from] and reused across the deterministic projection and every
/// Monte Carlo path.
class PlanInputs {
  final int startAge;
  final int retirementAge;
  final int endAge;
  final FilingStatus filingStatus;

  // Aggregated starting balances by tax bucket.
  final double cash;
  final double taxable;
  final double taxableBasis;
  final double traditional;
  final double roth;
  final double hsa;

  final List<IncomeSource> incomes;
  final List<Expense> expenses;
  final List<Liability> liabilities;

  final double inflation;
  final double healthcareInflation;
  final double marketReturnMean;
  final double marketReturnStdev;
  final double cashReturn;
  final WithdrawalStrategy strategy;
  final double withdrawalRate;
  final int simulationCount;

  const PlanInputs({
    required this.startAge,
    required this.retirementAge,
    required this.endAge,
    required this.filingStatus,
    required this.cash,
    required this.taxable,
    required this.taxableBasis,
    required this.traditional,
    required this.roth,
    required this.hsa,
    required this.incomes,
    required this.expenses,
    this.liabilities = const [],
    required this.inflation,
    required this.healthcareInflation,
    required this.marketReturnMean,
    required this.marketReturnStdev,
    required this.cashReturn,
    required this.strategy,
    required this.withdrawalRate,
    required this.simulationCount,
  });

  double get totalPortfolio => cash + taxable + traditional + roth + hsa;
  double get totalLiabilities => liabilities.fold(0.0, (s, l) => s + l.balance);

  factory PlanInputs.from({
    required Profile profile,
    required PlanAssumptions assumptions,
    required List<Account> accounts,
    required List<IncomeSource> incomes,
    required List<Expense> expenses,
    List<Liability> liabilities = const [],
    List<Holding> holdings = const [],
    required DateTime now,
  }) {
    double cash = 0, taxable = 0, basis = 0, trad = 0, roth = 0, hsa = 0;
    for (final a in accounts) {
      switch (a.type.taxBucket) {
        case TaxBucket.cash:
          cash += a.balance;
        case TaxBucket.taxable:
          taxable += a.balance;
          basis += a.costBasis;
        case TaxBucket.taxDeferred:
          trad += a.balance;
        case TaxBucket.taxFree:
          roth += a.balance;
        case TaxBucket.hsa:
          hsa += a.balance;
      }
    }
    for (final h in holdings) {
      final v = h.marketValue;
      switch (h.accountType.taxBucket) {
        case TaxBucket.taxable:
          taxable += v;
          basis += h.costBasis;
        case TaxBucket.taxDeferred:
          trad += v;
        case TaxBucket.taxFree:
          roth += v;
        case TaxBucket.hsa:
          hsa += v;
        case TaxBucket.cash:
          cash += v;
      }
    }
    return PlanInputs(
      startAge: profile.currentAge(now),
      retirementAge: profile.retirementAge,
      endAge: math.max(profile.currentAge(now) + 1, assumptions.endAge),
      filingStatus: profile.filingStatus,
      cash: cash,
      taxable: taxable,
      taxableBasis: basis,
      traditional: trad,
      roth: roth,
      hsa: hsa,
      incomes: incomes,
      expenses: expenses,
      liabilities: liabilities,
      inflation: assumptions.inflation,
      healthcareInflation: assumptions.healthcareInflation,
      marketReturnMean: assumptions.marketReturnMean,
      marketReturnStdev: assumptions.marketReturnStdev,
      cashReturn: 0.02,
      strategy: assumptions.withdrawalStrategy,
      withdrawalRate: assumptions.withdrawalRate,
      simulationCount: assumptions.simulationCount,
    );
  }
}

/// The retirement cash-flow simulator.
class RetirementProjection {
  /// Simulates one path. [marketReturn] supplies the nominal return for risky
  /// assets in projection year `t` (t=0 is the first year); cash grows at a
  /// fixed rate. Deterministic projections pass a constant mean return; Monte
  /// Carlo passes random draws.
  static PathResult simulatePath({
    required PlanInputs inp,
    required double Function(int t) marketReturn,
  }) {
    double cash = inp.cash;
    double taxable = inp.taxable;
    double basis = inp.taxableBasis;
    double trad = inp.traditional;
    double roth = inp.roth;
    double hsa = inp.hsa;

    final fs = inp.filingStatus;
    final years = <YearLedger>[];
    bool everShort = false;

    double guardrailBase = 0;
    double initialWr = 0;

    var t = 0;
    for (var age = inp.startAge; age <= inp.endAge; age++, t++) {
      final startPortfolio = cash + taxable + trad + roth + hsa;

      // --- Expenses (each grown by its own inflation; healthcare special) ---
      double expenses = 0;
      for (final e in inp.expenses) {
        if (e.activeAt(age, retirementAge: inp.retirementAge)) {
          final rate =
              e.category == ExpenseCategory.healthcare ? inp.healthcareInflation : e.inflationRate;
          expenses += e.annualAmount * math.pow(1 + rate, t);
        }
      }

      // --- Liabilities: add the payment while outstanding; track the balance ---
      double liabilityBalanceEnd = 0;
      for (final l in inp.liabilities) {
        if (t < l.payoffYears) expenses += l.annualPayment;
        liabilityBalanceEnd += l.balanceAfter((t + 1).toDouble());
      }

      // --- Guaranteed income (SS taxed specially) ---
      double ss = 0, other = 0;
      for (final inc in inp.incomes) {
        if (inc.activeAt(age)) {
          final grown =
              inc.annualAmount * math.pow(1 + inc.colaRate, math.max(0, age - inc.startAge));
          if (inc.type == IncomeType.socialSecurity) {
            ss += grown;
          } else {
            other += grown;
          }
        }
      }
      final guaranteed = ss + other;

      // --- Desired spending per strategy ---
      double desired;
      switch (inp.strategy) {
        case WithdrawalStrategy.inflationAdjusted:
          desired = expenses;
        case WithdrawalStrategy.fixedPercent:
          desired = guaranteed + inp.withdrawalRate * startPortfolio;
        case WithdrawalStrategy.vpw:
          desired = guaranteed + Withdrawal.vpwFraction(age, planEndAge: inp.endAge) * startPortfolio;
        case WithdrawalStrategy.guardrails:
          if (t == 0) {
            guardrailBase = expenses;
            initialWr = startPortfolio > 0 ? (expenses - guaranteed) / startPortfolio : 0;
          } else {
            guardrailBase *= (1 + inp.inflation);
            final wr = startPortfolio > 0 ? (guardrailBase - guaranteed) / startPortfolio : 0;
            guardrailBase = Withdrawal.guardrailAdjust(
              baseSpend: guardrailBase,
              currentWithdrawalRate: wr.toDouble(),
              initialWithdrawalRate: initialWr,
            );
          }
          desired = guardrailBase;
      }
      if (desired < 0) desired = 0;

      final netNeed = math.max(0.0, desired - guaranteed);
      final rmd = Rmd.amount(trad, age);
      final available = cash + taxable + trad + roth + hsa;

      // Allocate a gross portfolio draw [g] across buckets in tax-efficient
      // order, returning realized ordinary income, LTCG, and basis sold.
      ({double delivered, double ordinary, double ltcg, double basisSold, double shortfall})
          allocate(double g) {
        var remaining = g;
        double tradUsed = 0, ltcg = 0, basisSold = 0;
        // 1. RMD from traditional first.
        final rmdTake = math.min(rmd, trad);
        tradUsed += rmdTake;
        remaining -= rmdTake;
        // 2. Cash.
        final cashTake = math.min(math.max(0, remaining), cash);
        remaining -= cashTake;
        // 3. Taxable (realize proportional gains).
        final taxTake = math.min(math.max(0, remaining), taxable);
        if (taxable > 0 && taxTake > 0) {
          final basisFrac = basis / taxable;
          basisSold = taxTake * basisFrac;
          ltcg += taxTake - basisSold;
        }
        remaining -= taxTake;
        // 4. Traditional beyond RMD.
        final tradTake = math.min(math.max(0, remaining), trad - rmdTake);
        tradUsed += tradTake;
        remaining -= tradTake;
        // 5. Roth, 6. HSA (tax-free).
        final rothTake = math.min(math.max(0, remaining), roth);
        remaining -= rothTake;
        final hsaTake = math.min(math.max(0, remaining), hsa);
        remaining -= hsaTake;
        final shortfall = math.max(0.0, remaining);
        return (
          delivered: g - shortfall,
          ordinary: tradUsed,
          ltcg: ltcg,
          basisSold: basisSold,
          shortfall: shortfall,
        );
      }

      double taxFor(double g) {
        final a = allocate(g);
        return TaxEngine.federalIncomeTax(
          ordinaryIncomeExSS: other + a.ordinary,
          ssBenefits: ss,
          longTermGains: a.ltcg,
          fs: fs,
        );
      }

      // Solve gross draw so that after-tax cash covers the need; never below RMD.
      var g = math.max(rmd, netNeed);
      for (var i = 0; i < 8; i++) {
        final tax = taxFor(g);
        final newG = math.max(rmd, netNeed + tax).clamp(0, available).toDouble();
        if ((newG - g).abs() < 1) {
          g = newG;
          break;
        }
        g = newG;
      }

      final alloc = allocate(g);
      final totalTax = TaxEngine.federalIncomeTax(
        ordinaryIncomeExSS: other + alloc.ordinary,
        ssBenefits: ss,
        longTermGains: alloc.ltcg,
        fs: fs,
      );

      // Apply withdrawals to balances.
      final rmdTake = math.min(rmd, trad);
      var rem = g - rmdTake;
      trad -= rmdTake;
      final cashTake = math.min(math.max(0.0, rem), cash);
      cash -= cashTake;
      rem -= cashTake;
      final taxTake = math.min(math.max(0.0, rem), taxable);
      if (taxable > 0 && taxTake > 0) {
        final basisFrac = basis / taxable;
        basis -= taxTake * basisFrac;
      }
      taxable -= taxTake;
      rem -= taxTake;
      final tradTake2 = math.min(math.max(0.0, rem), trad);
      trad -= tradTake2;
      rem -= tradTake2;
      final rothTake = math.min(math.max(0.0, rem), roth);
      roth -= rothTake;
      rem -= rothTake;
      final hsaTake = math.min(math.max(0.0, rem), hsa);
      hsa -= hsaTake;

      // Net spendable cash this year and shortfall detection.
      final spendable = guaranteed + alloc.delivered - totalTax;
      final shortfall = spendable + 1 < desired;
      if (shortfall) everShort = true;

      // Surplus (e.g. forced RMD beyond need) is reinvested into taxable.
      final surplus = spendable - desired;
      if (surplus > 0) {
        taxable += surplus;
        basis += surplus; // reinvested at current value → new basis
      }

      // --- Growth on remaining balances ---
      final r = marketReturn(t);
      cash *= (1 + inp.cashReturn);
      taxable *= (1 + r);
      trad *= (1 + r);
      roth *= (1 + r);
      hsa *= (1 + r);
      for (final v in [cash, taxable, trad, roth, hsa]) {
        if (v.isNaN) break;
      }

      final endPortfolio = cash + taxable + trad + roth + hsa;
      years.add(YearLedger(
        age: age,
        startPortfolio: startPortfolio,
        socialSecurity: ss,
        otherIncome: other,
        requiredRmd: rmd,
        spending: desired,
        grossWithdrawal: g,
        taxes: totalTax,
        endPortfolio: endPortfolio,
        withdrawalRate: startPortfolio > 0 ? g / startPortfolio : 0,
        shortfall: shortfall,
        liabilityBalance: liabilityBalanceEnd,
        netWorth: endPortfolio - liabilityBalanceEnd,
      ));
    }

    return PathResult(
      years: years,
      success: !everShort,
      endingBalance: years.isEmpty ? 0 : years.last.endPortfolio,
    );
  }

  /// Full projection: deterministic ledger (mean returns) + Monte Carlo bands.
  static ProjectionResult project(PlanInputs inp, {int? seed}) {
    final deterministic = simulatePath(
      inp: inp,
      marketReturn: (_) => inp.marketReturnMean,
    );
    final mc = MonteCarlo.run(inp, seed: seed);

    int? depletion;
    for (final y in deterministic.years) {
      if (y.endPortfolio <= 1 && depletion == null) depletion = y.age;
    }

    return ProjectionResult(
      ledger: deterministic.years,
      deterministicEnding: deterministic.endingBalance,
      monteCarlo: mc,
      currentAssets: inp.totalPortfolio,
      currentLiabilities: inp.totalLiabilities,
      firstYearWithdrawalRate:
          deterministic.years.isNotEmpty ? deterministic.years.first.withdrawalRate : 0,
      depletionAge: depletion,
    );
  }
}

/// One year of the deterministic retirement cash-flow projection.
class YearLedger {
  final int age;
  final double startPortfolio;
  final double socialSecurity;
  final double otherIncome; // pensions, annuities, employment
  final double requiredRmd;
  final double spending; // total desired household spending
  final double grossWithdrawal; // pulled from accounts
  final double taxes;
  final double endPortfolio;
  final double withdrawalRate; // grossWithdrawal / startPortfolio
  final bool shortfall; // could not fund desired spending this year

  const YearLedger({
    required this.age,
    required this.startPortfolio,
    required this.socialSecurity,
    required this.otherIncome,
    required this.requiredRmd,
    required this.spending,
    required this.grossWithdrawal,
    required this.taxes,
    required this.endPortfolio,
    required this.withdrawalRate,
    required this.shortfall,
  });
}

/// Result of simulating a single path.
class PathResult {
  final List<YearLedger> years;
  final bool success; // never failed to fund spending
  final double endingBalance;

  const PathResult({required this.years, required this.success, required this.endingBalance});
}

/// Monte Carlo summary across many random return paths.
class MonteCarloResult {
  final int runs;
  final double successRate;
  final double endingP10;
  final double endingP50;
  final double endingP90;

  /// Per-year portfolio percentile bands (index 0 = first projected year).
  final List<double> bandP10;
  final List<double> bandP50;
  final List<double> bandP90;
  final List<int> ages;

  const MonteCarloResult({
    required this.runs,
    required this.successRate,
    required this.endingP10,
    required this.endingP50,
    required this.endingP90,
    required this.bandP10,
    required this.bandP50,
    required this.bandP90,
    required this.ages,
  });
}

/// Bundled output for the projections screen.
class ProjectionResult {
  final List<YearLedger> ledger;
  final double deterministicEnding;
  final MonteCarloResult monteCarlo;
  final double currentNetWorth;
  final double firstYearWithdrawalRate;
  final int? depletionAge; // age the deterministic plan runs out, or null

  const ProjectionResult({
    required this.ledger,
    required this.deterministicEnding,
    required this.monteCarlo,
    required this.currentNetWorth,
    required this.firstYearWithdrawalRate,
    required this.depletionAge,
  });
}

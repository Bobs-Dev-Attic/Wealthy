import 'dart:math' as math;

import '../../models/projection_result.dart';
import 'retirement_projection.dart';

/// Monte Carlo runner: simulates many random-return paths and summarizes the
/// probability of the plan lasting through the horizon, plus percentile bands
/// of the portfolio balance over time.
class MonteCarlo {
  /// Hard cap on simulations for responsiveness on the web.
  static const int maxRuns = 5000;

  static MonteCarloResult run(PlanInputs inp, {int? seed}) {
    final runs = inp.simulationCount.clamp(100, maxRuns);
    final rng = math.Random(seed ?? 0xC0FFEE);
    final yearCount = inp.endAge - inp.startAge + 1;

    final endings = <double>[];
    final byYear = List.generate(yearCount, (_) => <double>[]);
    var successes = 0;

    for (var n = 0; n < runs; n++) {
      final path = RetirementProjection.simulatePath(
        inp: inp,
        marketReturn: (_) => _sampleNormal(rng, inp.marketReturnMean, inp.marketReturnStdev),
      );
      if (path.success) successes++;
      endings.add(path.endingBalance);
      for (var i = 0; i < path.years.length && i < yearCount; i++) {
        byYear[i].add(path.years[i].endPortfolio);
      }
    }

    final ages = [for (var i = 0; i < yearCount; i++) inp.startAge + i];
    return MonteCarloResult(
      runs: runs,
      successRate: successes / runs,
      endingP10: _percentile(endings, 0.10),
      endingP50: _percentile(endings, 0.50),
      endingP90: _percentile(endings, 0.90),
      bandP10: [for (final y in byYear) _percentile(y, 0.10)],
      bandP50: [for (final y in byYear) _percentile(y, 0.50)],
      bandP90: [for (final y in byYear) _percentile(y, 0.90)],
      ages: ages,
    );
  }

  /// Draws a normal sample via Box-Muller. Returns are floored at -90% to avoid
  /// nonsensical sub-(-100%) annual returns.
  static double _sampleNormal(math.Random rng, double mean, double stdev) {
    final u1 = 1 - rng.nextDouble();
    final u2 = rng.nextDouble();
    final z = math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
    final r = mean + stdev * z;
    return r < -0.9 ? -0.9 : r;
  }

  static double _percentile(List<double> values, double p) {
    if (values.isEmpty) return 0;
    final sorted = [...values]..sort();
    final idx = (p * (sorted.length - 1)).round().clamp(0, sorted.length - 1);
    return sorted[idx];
  }
}

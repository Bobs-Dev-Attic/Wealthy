import 'enums.dart';

/// Economic + strategy assumptions that drive the projection engine.
class PlanAssumptions {
  final String userId;
  final double inflation;
  final double healthcareInflation;
  final double marketReturnMean;
  final double marketReturnStdev;
  final WithdrawalStrategy withdrawalStrategy;
  final double withdrawalRate;
  final int simulationCount;
  final int endAge;
  final int ssClaimAge;

  const PlanAssumptions({
    required this.userId,
    this.inflation = 0.03,
    this.healthcareInflation = 0.05,
    this.marketReturnMean = 0.06,
    this.marketReturnStdev = 0.12,
    this.withdrawalStrategy = WithdrawalStrategy.inflationAdjusted,
    this.withdrawalRate = 0.04,
    this.simulationCount = 1000,
    this.endAge = 95,
    this.ssClaimAge = 67,
  });

  PlanAssumptions copyWith({
    double? inflation,
    double? healthcareInflation,
    double? marketReturnMean,
    double? marketReturnStdev,
    WithdrawalStrategy? withdrawalStrategy,
    double? withdrawalRate,
    int? simulationCount,
    int? endAge,
    int? ssClaimAge,
  }) =>
      PlanAssumptions(
        userId: userId,
        inflation: inflation ?? this.inflation,
        healthcareInflation: healthcareInflation ?? this.healthcareInflation,
        marketReturnMean: marketReturnMean ?? this.marketReturnMean,
        marketReturnStdev: marketReturnStdev ?? this.marketReturnStdev,
        withdrawalStrategy: withdrawalStrategy ?? this.withdrawalStrategy,
        withdrawalRate: withdrawalRate ?? this.withdrawalRate,
        simulationCount: simulationCount ?? this.simulationCount,
        endAge: endAge ?? this.endAge,
        ssClaimAge: ssClaimAge ?? this.ssClaimAge,
      );

  factory PlanAssumptions.fromJson(Map<String, dynamic> j) => PlanAssumptions(
        userId: j['user_id'] as String,
        inflation: (j['inflation'] as num?)?.toDouble() ?? 0.03,
        healthcareInflation: (j['healthcare_inflation'] as num?)?.toDouble() ?? 0.05,
        marketReturnMean: (j['market_return_mean'] as num?)?.toDouble() ?? 0.06,
        marketReturnStdev: (j['market_return_stdev'] as num?)?.toDouble() ?? 0.12,
        withdrawalStrategy:
            WithdrawalStrategyX.fromDb((j['withdrawal_strategy'] ?? 'inflation_adjusted') as String),
        withdrawalRate: (j['withdrawal_rate'] as num?)?.toDouble() ?? 0.04,
        simulationCount: (j['simulation_count'] as num?)?.toInt() ?? 1000,
        endAge: (j['end_age'] as num?)?.toInt() ?? 95,
        ssClaimAge: (j['ss_claim_age'] as num?)?.toInt() ?? 67,
      );

  Map<String, dynamic> toUpdate() => {
        'inflation': inflation,
        'healthcare_inflation': healthcareInflation,
        'market_return_mean': marketReturnMean,
        'market_return_stdev': marketReturnStdev,
        'withdrawal_strategy': withdrawalStrategy.db,
        'withdrawal_rate': withdrawalRate,
        'simulation_count': simulationCount,
        'end_age': endAge,
        'ss_claim_age': ssClaimAge,
        'updated_at': DateTime.now().toIso8601String(),
      };
}

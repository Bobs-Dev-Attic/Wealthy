import 'package:flutter_test/flutter_test.dart';
import 'package:wealthy/models/enums.dart';
import 'package:wealthy/models/expense.dart';
import 'package:wealthy/services/engine/retirement_projection.dart';

PlanInputs inputs({
  required double taxable,
  required double expense,
  double mean = 0.05,
  double stdev = 0.10,
  int endAge = 90,
}) {
  return PlanInputs(
    startAge: 65,
    retirementAge: 65,
    endAge: endAge,
    filingStatus: FilingStatus.single,
    cash: 0,
    taxable: taxable,
    taxableBasis: taxable, // no embedded gains → simple taxes
    traditional: 0,
    roth: 0,
    hsa: 0,
    incomes: const [],
    expenses: [
      Expense(
        name: 'Living',
        category: ExpenseCategory.living,
        annualAmount: expense,
        inflationRate: 0,
        startAge: 65,
      ),
    ],
    inflation: 0,
    healthcareInflation: 0,
    marketReturnMean: mean,
    marketReturnStdev: stdev,
    cashReturn: 0.02,
    strategy: WithdrawalStrategy.inflationAdjusted,
    withdrawalRate: 0.04,
    simulationCount: 500,
  );
}

void main() {
  group('RetirementProjection', () {
    test('healthy plan: 4% spend on a 5% portfolio rarely fails', () {
      final result = RetirementProjection.project(inputs(taxable: 1000000, expense: 40000));
      expect(result.ledger.length, 26); // ages 65..90 inclusive
      expect(result.ledger.first.grossWithdrawal, closeTo(40000, 200));
      expect(result.ledger.first.withdrawalRate, closeTo(0.04, 0.005));
      expect(result.monteCarlo.successRate, greaterThan(0.8));
      expect(result.depletionAge, isNull);
    });

    test('over-spending plan depletes and reports low success', () {
      final result = RetirementProjection.project(
        inputs(taxable: 200000, expense: 50000, mean: 0.04),
      );
      expect(result.monteCarlo.successRate, lessThan(0.1));
      expect(result.depletionAge, isNotNull);
    });

    test('RMDs are forced once the plan reaches age 73', () {
      final inp = PlanInputs(
        startAge: 72,
        retirementAge: 72,
        endAge: 80,
        filingStatus: FilingStatus.single,
        cash: 0,
        taxable: 0,
        taxableBasis: 0,
        traditional: 1000000,
        roth: 0,
        hsa: 0,
        incomes: const [],
        expenses: const [], // no spending need; RMD still forced
        inflation: 0,
        healthcareInflation: 0,
        marketReturnMean: 0.05,
        marketReturnStdev: 0.0,
        cashReturn: 0.02,
        strategy: WithdrawalStrategy.inflationAdjusted,
        withdrawalRate: 0.04,
        simulationCount: 100,
      );
      final result = RetirementProjection.project(inp);
      final age72 = result.ledger.firstWhere((y) => y.age == 72);
      final age73 = result.ledger.firstWhere((y) => y.age == 73);
      expect(age72.requiredRmd, 0);
      expect(age73.requiredRmd, greaterThan(0));
      // Forced RMD is withdrawn even with no spending need.
      expect(age73.grossWithdrawal, greaterThan(0));
    });
  });
}

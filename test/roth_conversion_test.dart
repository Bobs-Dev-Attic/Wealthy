import 'package:flutter_test/flutter_test.dart';
import 'package:wealthy/models/enums.dart';
import 'package:wealthy/services/engine/roth_conversion.dart';

void main() {
  group('RothConversionEngine', () {
    final inputs = RothConversionInputs(
      currentAge: 60,
      retirementAge: 65,
      planEndAge: 90,
      traditionalBalance: 2000000,
      preRetirementIncome: 300000,
      postRetirementIncome: 40000,
      growthRate: 0.06,
      filingStatus: FilingStatus.marriedJoint,
    );

    test('doing nothing produces RMDs starting at 73 and no conversions', () {
      final r = RothConversionEngine.run(inputs, ConversionStrategy.none);
      expect(r.totalConverted, 0);
      final firstRmd = r.firstRmdYear;
      expect(firstRmd, isNotNull);
      expect(firstRmd!.age, RothConversionEngine.rmdAge);
      expect(r.totalRmdTax, greaterThan(0));
    });

    test('fill-current-bracket converts at a lower marginal rate once income drops in retirement', () {
      final r = RothConversionEngine.run(inputs, ConversionStrategy.fillCurrentBracket);
      final workingYear = r.years.firstWhere((y) => y.age == 62);
      final gapYear = r.years.firstWhere((y) => y.age == 67);
      expect(gapYear.marginalRate, lessThan(workingYear.marginalRate));
    });

    test('fill-next-bracket converts at least as much as fill-current-bracket each year', () {
      final current = RothConversionEngine.run(inputs, ConversionStrategy.fillCurrentBracket);
      final next = RothConversionEngine.run(inputs, ConversionStrategy.fillNextBracket);
      expect(next.totalConverted, greaterThanOrEqualTo(current.totalConverted));
    });

    test('leveling converts an equal amount every gap year and hits ~zero by RMD age', () {
      final r = RothConversionEngine.run(inputs, ConversionStrategy.levelGapYears);
      final gapConversions = r.years
          .where((y) => y.age < RothConversionEngine.rmdAge)
          .map((y) => y.conversion)
          .toList();
      expect(gapConversions.every((c) => (c - gapConversions.first).abs() < 1), isTrue);
      final atRmdAge = r.years.firstWhere((y) => y.age == RothConversionEngine.rmdAge);
      expect(atRmdAge.traditionalStart, closeTo(0, 1000));
    });

    test('custom strategy respects the fixed annual amount', () {
      final r = RothConversionEngine.run(inputs, ConversionStrategy.custom, customAnnualAmount: 50000);
      final gapYear = r.years.firstWhere((y) => y.age == 62);
      expect(gapYear.conversion, 50000);
    });

    test('a strategy that converts nothing leaves the biggest RMD tax bomb', () {
      final results = RothConversionEngine.compareAll(inputs);
      final none = results.firstWhere((r) => r.strategy == ConversionStrategy.none);
      for (final r in results) {
        if (r.strategy != ConversionStrategy.none) {
          expect(none.totalRmdTax, greaterThanOrEqualTo(r.totalRmdTax));
        }
      }
    });
  });
}

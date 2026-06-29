import 'package:flutter_test/flutter_test.dart';
import 'package:wealthy/models/enums.dart';
import 'package:wealthy/services/engine/tax.dart';

void main() {
  group('TaxEngine', () {
    test('standard deduction by filing status (2025)', () {
      expect(TaxEngine.standardDeduction(FilingStatus.single), 15000);
      expect(TaxEngine.standardDeduction(FilingStatus.marriedJoint), 30000);
      expect(TaxEngine.standardDeduction(FilingStatus.headOfHousehold), 22500);
    });

    test('single filer, \$60k ordinary income, no SS or gains', () {
      // Taxable = 60,000 - 15,000 = 45,000.
      // 10% * 11,925 + 12% * (45,000 - 11,925) = 1192.5 + 3969 = 5161.5
      final tax = TaxEngine.federalIncomeTax(
        ordinaryIncomeExSS: 60000,
        ssBenefits: 0,
        longTermGains: 0,
        fs: FilingStatus.single,
      );
      expect(tax, closeTo(5161.5, 1));
    });

    test('long-term gains fall in the 0% bracket when income is low', () {
      // No ordinary income; $40k LTCG is under the single 0% ceiling (48,350)
      // after the standard deduction, so tax is $0.
      final tax = TaxEngine.federalIncomeTax(
        ordinaryIncomeExSS: 0,
        ssBenefits: 0,
        longTermGains: 40000,
        fs: FilingStatus.single,
      );
      expect(tax, 0);
    });

    test('Social Security is untaxed at low provisional income', () {
      final taxable = TaxEngine.taxableSocialSecurity(20000, 5000, FilingStatus.single);
      expect(taxable, 0);
    });

    test('Social Security taxation caps at 85% of benefits', () {
      final taxable = TaxEngine.taxableSocialSecurity(30000, 200000, FilingStatus.single);
      expect(taxable, closeTo(0.85 * 30000, 1));
    });
  });
}

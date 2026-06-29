import 'package:flutter_test/flutter_test.dart';
import 'package:wealthy/services/engine/withdrawal.dart';

void main() {
  group('Withdrawal', () {
    test('VPW fraction increases with age', () {
      final at65 = Withdrawal.vpwFraction(65);
      final at85 = Withdrawal.vpwFraction(85);
      expect(at85, greaterThan(at65));
      expect(at65, inInclusiveRange(0.02, 0.10));
    });

    test('guardrails cut spending when withdrawal rate runs hot', () {
      final adjusted = Withdrawal.guardrailAdjust(
        baseSpend: 50000,
        currentWithdrawalRate: 0.06, // > 0.04 * 1.2
        initialWithdrawalRate: 0.04,
      );
      expect(adjusted, closeTo(45000, 0.01));
    });

    test('guardrails raise spending when withdrawal rate runs cold', () {
      final adjusted = Withdrawal.guardrailAdjust(
        baseSpend: 50000,
        currentWithdrawalRate: 0.025, // < 0.04 * 0.8
        initialWithdrawalRate: 0.04,
      );
      expect(adjusted, closeTo(55000, 0.01));
    });
  });
}

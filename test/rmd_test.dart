import 'package:flutter_test/flutter_test.dart';
import 'package:wealthy/services/engine/rmd.dart';

void main() {
  group('Rmd', () {
    test('no RMD before age 73', () {
      expect(Rmd.divisorForAge(72), isNull);
      expect(Rmd.amount(500000, 70), 0);
    });

    test('uses the Uniform Lifetime Table divisor', () {
      expect(Rmd.divisorForAge(73), 26.5);
      expect(Rmd.divisorForAge(75), 24.6);
    });

    test('amount = balance / divisor', () {
      // 26.5 divisor at 73 → 1,000,000 / 26.5 ≈ 37,735.85
      expect(Rmd.amount(1000000, 73), closeTo(37735.85, 1));
    });

    test('very old ages floor at divisor 2.0', () {
      expect(Rmd.divisorForAge(125), 2.0);
    });
  });
}

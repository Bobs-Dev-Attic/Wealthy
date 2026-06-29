import 'package:flutter_test/flutter_test.dart';
import 'package:wealthy/services/engine/social_security.dart';

void main() {
  group('SocialSecurity', () {
    test('no adjustment at full retirement age', () {
      expect(SocialSecurity.adjustForClaimAge(24000, 67), 24000);
    });

    test('claiming at 62 reduces the benefit by 30%', () {
      // 60 months early: 36 * (5/9)%/mo + 24 * (5/12)%/mo = 20% + 10% = 30%.
      expect(SocialSecurity.adjustForClaimAge(2000, 62), closeTo(1400, 0.5));
    });

    test('delaying to 70 adds 24% in delayed credits', () {
      expect(SocialSecurity.adjustForClaimAge(2000, 70), closeTo(2480, 0.5));
    });

    test('benefit is zero before the claim age and grows with COLA', () {
      expect(
        SocialSecurity.benefitAtAge(benefitAtClaim: 20000, claimAge: 67, age: 65, cola: 0.02),
        0,
      );
      expect(
        SocialSecurity.benefitAtAge(benefitAtClaim: 20000, claimAge: 67, age: 69, cola: 0.02),
        closeTo(20000 * 1.02 * 1.02, 1),
      );
    });
  });
}

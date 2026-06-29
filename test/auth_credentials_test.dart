import 'package:flutter_test/flutter_test.dart';
import 'package:wealthy/services/auth_service.dart';

void main() {
  group('AuthCredentials', () {
    test('encode/decode round-trips', () {
      const creds = AuthCredentials(userId: 'abc-123', accessCode: 'WLTH-AAAA-BBBB');
      final encoded = creds.encode();
      final decoded = AuthCredentials.decode(encoded);
      expect(decoded, isNotNull);
      expect(decoded!.userId, 'abc-123');
      expect(decoded.accessCode, 'WLTH-AAAA-BBBB');
    });

    test('rejects malformed payloads', () {
      expect(AuthCredentials.decode('not-a-key'), isNull);
      expect(AuthCredentials.decode('WLTH1|onlyonepart'), isNull);
    });
  });
}

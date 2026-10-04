import 'package:flutter_test/flutter_test.dart';
import 'package:magic_social_auth/src/models/social_auth_result.dart';

void main() {
  group('SocialAuthResult.fromJson', () {
    test('a sign-in carries the token and the user', () {
      final SocialAuthResult result = SocialAuthResult.fromJson({
        'data': {
          'user': {'id': 7, 'email': 'user@example.com'},
          'token': '1|abc',
        },
        'message': 'Login successful',
      });

      expect(result.isTwoFactor, isFalse);
      expect(result.token, '1|abc');
      expect(result.user, {'id': 7, 'email': 'user@example.com'});
      expect(result.deletionCancelled, isFalse);
      expect(result.connectedProvider, isNull);
      expect(result.confirmationToken, isNull);
    });

    test('a sign-in that cancelled a scheduled deletion says so', () {
      final SocialAuthResult result = SocialAuthResult.fromJson({
        'data': {
          'user': {'id': 7},
          'token': '1|abc',
          'deletion_cancelled': true,
        },
      });

      expect(result.deletionCancelled, isTrue);
    });

    test('a 2FA challenge carries the challenge token and no session', () {
      final SocialAuthResult result = SocialAuthResult.fromJson({
        'two_factor': true,
        'two_factor_token': 'eyJpdiI6',
      });

      expect(result.isTwoFactor, isTrue);
      expect(result.twoFactorToken, 'eyJpdiI6');
      expect(result.token, isNull);
      expect(result.user, isNull);
    });

    test('a connect names the linked provider', () {
      final SocialAuthResult result = SocialAuthResult.fromJson({
        'data': {'provider': 'github', 'email': 'user@example.com'},
      });

      expect(result.connectedProvider, 'github');
      expect(result.token, isNull);
    });

    test('a confirm carries the confirmation token', () {
      final SocialAuthResult result = SocialAuthResult.fromJson({
        'data': {'confirmation_token': 'c0nf1rm'},
      });

      expect(result.confirmationToken, 'c0nf1rm');
      expect(result.isTwoFactor, isFalse);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:magic_social_auth/src/exceptions/social_auth_exception.dart';

void main() {
  group('SocialAuthException', () {
    test('creates exception with message', () {
      const exception = SocialAuthException('Test error');
      expect(exception.message, 'Test error');
    });

    test('toString returns message', () {
      const exception = SocialAuthException('Test error');
      expect(exception.toString(), 'SocialAuthException: Test error');
    });

    test('different messages create different exceptions', () {
      const exception1 = SocialAuthException('Error 1');
      const exception2 = SocialAuthException('Error 2');
      expect(exception1.message, isNot(equals(exception2.message)));
    });
  });

  group('SocialAuthCancelledException', () {
    test('creates cancelled exception with default message', () {
      const exception = SocialAuthCancelledException();
      expect(exception.message, 'Authentication was cancelled by user');
    });

    test('toString returns cancellation message', () {
      const exception = SocialAuthCancelledException();
      expect(
        exception.toString(),
        'SocialAuthException: Authentication was cancelled by user',
      );
    });

    test('is a subtype of SocialAuthException', () {
      const exception = SocialAuthCancelledException();
      expect(exception, isA<SocialAuthException>());
    });
  });
}

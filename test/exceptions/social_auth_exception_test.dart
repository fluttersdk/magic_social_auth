import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_social_auth/src/exceptions/social_auth_exception.dart';

void main() {
  group('SocialAuthException', () {
    test('creates exception with message', () {
      const exception = SocialAuthException('Test error');
      expect(exception.message, 'Test error');
      expect(exception.code, isNull);
      expect(exception.statusCode, isNull);
    });

    test('toString returns message', () {
      const exception = SocialAuthException('Test error');
      expect(exception.toString(), 'SocialAuthException: Test error');
    });

    test('toString names the code when there is one', () {
      const exception = SocialAuthException(
        'Taken',
        code: 'social_email_taken',
      );
      expect(
        exception.toString(),
        'SocialAuthException: Taken (social_email_taken)',
      );
    });

    test('different messages create different exceptions', () {
      const exception1 = SocialAuthException('Error 1');
      const exception2 = SocialAuthException('Error 2');
      expect(exception1.message, isNot(equals(exception2.message)));
    });
  });

  group('SocialAuthException.fromResponse', () {
    test('reads message and code from a coded refusal', () {
      final exception = SocialAuthException.fromResponse(
        MagicResponse(
          data: {'message': 'Already linked.', 'code': 'social_account_taken'},
          statusCode: 409,
        ),
      );

      expect(exception.message, 'Already linked.');
      expect(exception.code, 'social_account_taken');
      expect(exception.statusCode, 409);
    });

    test('a refusal without a code keeps its message and no code', () {
      final exception = SocialAuthException.fromResponse(
        MagicResponse(data: {'message': 'Unauthenticated.'}, statusCode: 401),
      );

      expect(exception.message, 'Unauthenticated.');
      expect(exception.code, isNull);
      expect(exception.statusCode, 401);
    });

    test('a failure with no body falls back to the transport message', () {
      final exception = SocialAuthException.fromResponse(
        MagicResponse(data: null, statusCode: 0, message: 'Connection refused'),
      );

      expect(exception.message, 'Connection refused');
      expect(exception.code, isNull);
      expect(exception.statusCode, 0);
    });
  });

  group('SocialAuthCancelledException', () {
    test('invites a retry, since a failed App Link check looks the same', () {
      const exception = SocialAuthCancelledException();
      expect(
        exception.message,
        'The sign-in was cancelled or did not finish. Please try again.',
      );
      expect(exception.superseded, isFalse);
    });

    test('a superseded flow is marked so the caller can stay quiet', () {
      const exception = SocialAuthCancelledException(superseded: true);
      expect(exception.superseded, isTrue);
    });

    test('is a subtype of SocialAuthException', () {
      const exception = SocialAuthCancelledException();
      expect(exception, isA<SocialAuthException>());
    });
  });
}

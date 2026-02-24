import 'package:flutter_test/flutter_test.dart';
import 'package:magic_social_auth/src/models/social_token.dart';

void main() {
  group('SocialToken', () {
    test('supports authorizationCode field', () {
      final token = SocialToken(
        provider: 'github',
        accessToken: '',
        authorizationCode: 'auth_code_123',
      );

      expect(token.authorizationCode, equals('auth_code_123'));
    });

    test('isCodeExchange returns true when authorizationCode is present', () {
      final token = SocialToken(
        provider: 'github',
        accessToken: '',
        authorizationCode: 'auth_code_123',
      );

      expect(token.isCodeExchange, isTrue);
    });

    test('isCodeExchange returns false when authorizationCode is null', () {
      const token = SocialToken(
        provider: 'google',
        accessToken: 'access_token_123',
      );

      expect(token.isCodeExchange, isFalse);
    });

    test('toMap includes authorization_code when present', () {
      final token = SocialToken(
        provider: 'github',
        accessToken: '',
        authorizationCode: 'auth_code_123',
      );

      final map = token.toMap();

      expect(map['authorization_code'], equals('auth_code_123'));
      expect(map['provider'], equals('github'));
    });

    test('toMap excludes authorization_code when null', () {
      const token = SocialToken(
        provider: 'google',
        accessToken: 'access_token_123',
      );

      final map = token.toMap();

      expect(map.containsKey('authorization_code'), isFalse);
      expect(map['access_token'], equals('access_token_123'));
    });

    test('token can be created with accessToken only (token flow)', () {
      const token = SocialToken(
        provider: 'google',
        accessToken: 'access_token_123',
      );

      expect(token.accessToken, equals('access_token_123'));
      expect(token.authorizationCode, isNull);
    });

    test('token can be created with authorizationCode only (code flow)', () {
      final token = SocialToken(
        provider: 'github',
        accessToken: '',
        authorizationCode: 'auth_code_123',
      );

      expect(token.authorizationCode, equals('auth_code_123'));
      expect(token.accessToken, isEmpty);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:magic_social_auth/src/flow/pkce.dart';

void main() {
  // The two regexes the backend validates with:
  // SocialRedirectRequest.php:39 and SocialExchangeRequest.php:31.
  final RegExp challengeShape = RegExp(r'^[A-Za-z0-9_-]{43}$');
  final RegExp verifierShape = RegExp(r'^[A-Za-z0-9._~-]{43,128}$');

  group('Pkce', () {
    test('the RFC 7636 appendix B verifier yields its published challenge', () {
      expect(
        Pkce.challengeFor('dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk'),
        // RFC 7636 appendix B, verbatim.
        'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
      );
    });

    test('1,000 generated pairs pass the backend regexes', () {
      for (int i = 0; i < 1000; i++) {
        final Pkce pkce = Pkce.generate();

        expect(pkce.verifier, matches(verifierShape));
        expect(pkce.challenge, matches(challengeShape));
      }
    });

    test('the verifier is 64 characters and the challenge derives from it', () {
      final Pkce pkce = Pkce.generate();

      expect(pkce.verifier, hasLength(64));
      expect(pkce.challenge, Pkce.challengeFor(pkce.verifier));
    });

    test('every pair is fresh', () {
      final Set<String> verifiers = {
        for (int i = 0; i < 100; i++) Pkce.generate().verifier,
      };

      expect(verifiers, hasLength(100));
    });
  });
}

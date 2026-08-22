import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:magic/magic.dart';
import 'package:magic_social_auth/src/drivers/google_driver.dart';
import 'package:magic_social_auth/src/exceptions/social_auth_exception.dart';
import 'package:magic_social_auth/src/models/social_platform.dart';
import 'package:magic_social_auth/src/models/social_token.dart';

void main() {
  group('GoogleDriver', () {
    late GoogleDriver driver;

    setUp(() {
      driver = GoogleDriver({
        'client_id': 'test-client-id',
        'server_client_id': 'test-server-client-id',
        'scopes': ['email', 'profile'],
      });
    });

    test('name returns google', () {
      expect(driver.name, 'google');
    });

    test('supports iOS, Android, and Web platforms', () {
      expect(
        driver.supportedPlatforms,
        containsAll([
          SocialPlatform.ios,
          SocialPlatform.android,
          SocialPlatform.web,
        ]),
      );
    });

    test('supportsPlatform returns true for supported platforms', () {
      expect(driver.supportsPlatform(SocialPlatform.ios), isTrue);
      expect(driver.supportsPlatform(SocialPlatform.android), isTrue);
      expect(driver.supportsPlatform(SocialPlatform.web), isTrue);
    });

    test('config is accessible', () {
      expect(driver.config['client_id'], 'test-client-id');
      expect(driver.config['server_client_id'], 'test-server-client-id');
      expect(driver.config['scopes'], ['email', 'profile']);
    });

    test('has signOut method', () {
      // Verify signOut method exists (calling it requires Magic container)
      expect(driver.signOut, isA<Function>());
    });

    // -------------------------------------------------------------------------
    // The error-translation contract
    //
    // `getToken`'s try/catch IS the driver's contract: a provider error becomes
    // SocialAuthException, and a user cancel becomes SocialAuthCancelledException
    // so a consumer can tell "backed out" from "failed". Nothing reached that
    // code before, because every path into it goes through the platform channel,
    // which is why `nativeSignIn` and `supportsNativeSignIn` exist as seams.
    // -------------------------------------------------------------------------

    setUp(() {
      // The `catch (e)` clause logs before it throws, and `Log` resolves
      // `Magic.make<LogManager>('log')`, so without a binding the test sees a
      // container error instead of the translation it is asserting on. The two
      // clauses above it (cancel, rethrow) never log, which is why only this
      // case needed it.
      MagicApp.reset();
      MagicApp.instance.singleton('log', LogManager.new);
    });

    tearDown(MagicApp.reset);

    test('a native failure is translated, not raised raw', () async {
      // Regression guard for a bare `return nativeSignIn()`: an unawaited
      // future completes after the try has exited, so the catch clauses never
      // see the error and the caller gets the raw one.
      final driver =
          _FakeGoogleDriver(throwing: StateError('token read blew up'));

      await expectLater(
        driver.getToken(),
        throwsA(isA<SocialAuthException>()),
      );
    });

    test('a cancel is translated to SocialAuthCancelledException', () async {
      final driver = _FakeGoogleDriver(
        throwing: const GoogleSignInException(
          code: GoogleSignInExceptionCode.canceled,
          description: 'user closed the sheet',
        ),
      );

      await expectLater(
        driver.getToken(),
        throwsA(isA<SocialAuthCancelledException>()),
      );
    });

    test('a SocialAuthException from below is rethrown unchanged', () async {
      final original = const SocialAuthException('already ours');
      final driver = _FakeGoogleDriver(throwing: original);

      await expectLater(
        driver.getToken(),
        throwsA(same(original)),
      );
    });

    test('the native path returns its token when nothing throws', () async {
      final driver = _FakeGoogleDriver();

      final SocialToken token = await driver.getToken();

      expect(token.provider, 'google');
      expect(token.accessToken, 'native-access-token');
    });
  });
}

/// A [GoogleDriver] with the platform channel stood in for.
///
/// Only the two seams are replaced: `getToken`'s own control flow, and the
/// catch clauses under test, are the real ones.
class _FakeGoogleDriver extends GoogleDriver {
  _FakeGoogleDriver({this.throwing})
      : super(const {
          'client_id': 'test',
          'scopes': ['email']
        });

  /// Thrown from the native path, or null to return a token.
  final Object? throwing;

  @override
  Future<void> ensureInitialized() async {}

  @override
  bool get supportsNativeSignIn => true;

  @override
  Future<SocialToken> nativeSignIn() async {
    if (throwing != null) throw throwing!;
    return const SocialToken(
      provider: 'google',
      accessToken: 'native-access-token',
    );
  }
}

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_social_auth/src/drivers/apple_driver.dart';
import 'package:magic_social_auth/src/exceptions/social_auth_exception.dart';
import 'package:magic_social_auth/src/models/social_auth_result.dart';
import 'package:magic_social_auth/src/models/social_platform.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

void main() {
  late FakeNetworkDriver http;
  late FakeLogManager log;

  setUp(() {
    MagicApp.reset();
    log = Log.fake();
    http = Http.fake({
      '/auth/social/apple/token': Http.response({
        'data': {
          'user': {'id': 1},
          'token': '1|abc',
        },
      }),
    });
  });

  tearDown(MagicApp.reset);

  List<MagicRequest> sent() => [
    for (final (MagicRequest request, _) in http.recorded) request,
  ];

  test('runs natively on iOS only', () {
    final AppleDriver driver = AppleDriver(const {});

    expect(driver.name, 'apple');
    expect(driver.supportedPlatforms, {SocialPlatform.ios});
  });

  group('signIn', () {
    test('gives Apple the hashed nonce and the backend the raw one', () async {
      final _FakeAppleDriver driver = _FakeAppleDriver();

      await driver.signIn();

      final Map<dynamic, dynamic> body = sent().single.data as Map;
      final String raw = body['nonce'] as String;
      expect(sent().single.url, '/auth/social/apple/token');
      expect(raw, isNotEmpty);
      expect(driver.nonces.single, sha256.convert(utf8.encode(raw)).toString());
      expect(driver.nonces.single, isNot(raw));
      expect(body, {
        'id_token': 'apple-id-token',
        'nonce': raw,
        'authorization_code': 'apple-code',
        'intent': 'signin',
      });
    });

    test('mints a new nonce on every call', () async {
      final _FakeAppleDriver driver = _FakeAppleDriver();

      await driver.signIn();
      await driver.signIn();

      expect(driver.nonces.toSet(), hasLength(2));
    });

    test('hands the first-authorization name to the caller', () async {
      final AppleSignInResult result = await _FakeAppleDriver(
        givenName: 'Ada',
        familyName: 'Lovelace',
      ).signIn();

      expect(result.givenName, 'Ada');
      expect(result.familyName, 'Lovelace');
      expect(result.token, '1|abc');
    });

    test('a canceled sheet becomes SocialAuthCancelledException', () async {
      final _FakeAppleDriver driver = _FakeAppleDriver(
        throwing: const SignInWithAppleAuthorizationException(
          code: AuthorizationErrorCode.canceled,
          message: 'canceled',
        ),
      );

      await expectLater(
        driver.signIn(),
        throwsA(isA<SocialAuthCancelledException>()),
      );
      expect(sent(), isEmpty);
    });

    test(
      'another Apple failure is coded sdk_error; its detail is logged',
      () async {
        final _FakeAppleDriver driver = _FakeAppleDriver(
          throwing: const SignInWithAppleAuthorizationException(
            code: AuthorizationErrorCode.failed,
            message: 'keychain unavailable',
          ),
        );

        await expectLater(
          driver.signIn(),
          throwsA(
            isA<SocialAuthException>()
                .having(
                  (e) => e is SocialAuthCancelledException,
                  'cancel',
                  false,
                )
                .having((e) => e.code, 'code', 'sdk_error')
                .having(
                  (e) => e.message,
                  'message',
                  isNot(contains('keychain unavailable')),
                ),
          ),
        );
        expect(log.entries.single.message, contains('keychain unavailable'));
      },
    );

    test('a plain SDK error is coded sdk_error too', () async {
      final _FakeAppleDriver driver = _FakeAppleDriver(
        throwing: const SignInWithAppleNotSupportedException(
          message: 'not on this device',
        ),
      );

      await expectLater(
        driver.signIn(),
        throwsA(
          isA<SocialAuthException>().having((e) => e.code, 'code', 'sdk_error'),
        ),
      );
      expect(log.entries.single.level, 'error');
    });

    test('a credential without an identity token is refused', () async {
      await expectLater(
        _FakeAppleDriver(identityToken: null).signIn(),
        throwsA(
          isA<SocialAuthException>().having((e) => e.code, 'code', 'sdk_error'),
        ),
      );
      expect(sent(), isEmpty);
    });
  });

  test('connect posts intent connect with the proof', () async {
    await _FakeAppleDriver().connect({'code': '123456'});

    final Map<dynamic, dynamic> body = sent().single.data as Map;
    expect(body['intent'], 'connect');
    expect(body['code'], '123456');
    expect(body['nonce'], isA<String>());
  });

  test('confirm posts intent confirm', () async {
    http = Http.fake({
      '/auth/social/apple/token': Http.response({
        'data': {'confirmation_token': 'c0nf'},
      }),
    });

    final SocialAuthResult result = await _FakeAppleDriver().confirm();

    expect((sent().single.data as Map)['intent'], 'confirm');
    expect(result.confirmationToken, 'c0nf');
  });
}

/// An [AppleDriver] with the Apple sheet stood in for.
class _FakeAppleDriver extends AppleDriver {
  _FakeAppleDriver({
    this.throwing,
    this.identityToken = 'apple-id-token',
    this.givenName,
    this.familyName,
  }) : super(const {}, platform: SocialPlatform.ios);

  final Object? throwing;

  final String? identityToken;

  final String? givenName;

  final String? familyName;

  /// The nonce every sheet was given, in order.
  final List<String> nonces = [];

  @override
  Future<AuthorizationCredentialAppleID> requestCredential(
    String hashedNonce,
  ) async {
    nonces.add(hashedNonce);
    if (throwing != null) throw throwing!;

    return AuthorizationCredentialAppleID(
      userIdentifier: 'apple-user',
      givenName: givenName,
      familyName: familyName,
      authorizationCode: 'apple-code',
      email: null,
      identityToken: identityToken,
      state: null,
    );
  }
}

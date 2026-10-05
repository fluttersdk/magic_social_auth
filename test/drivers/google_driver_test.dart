import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:magic/magic.dart';
import 'package:magic_social_auth/src/drivers/google_driver.dart';
import 'package:magic_social_auth/src/exceptions/social_auth_exception.dart';
import 'package:magic_social_auth/src/models/social_auth_result.dart';
import 'package:magic_social_auth/src/models/social_platform.dart';

void main() {
  late FakeNetworkDriver http;
  late FakeLogManager log;

  setUp(() {
    MagicApp.reset();
    log = Log.fake();
    GoogleDriver.resetInitialization();
    _FakeGoogleDriver.initializations.clear();
    http = Http.fake({
      '/auth/social/google/token': Http.response({
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

  test('runs natively on iOS and Android only', () {
    final GoogleDriver driver = GoogleDriver(const {});

    expect(driver.name, 'google');
    expect(driver.supportedPlatforms, {
      SocialPlatform.ios,
      SocialPlatform.android,
    });
  });

  group('signIn', () {
    test('posts the ID token with intent signin and no nonce', () async {
      final _FakeGoogleDriver driver = _FakeGoogleDriver();

      final SocialAuthResult result = await driver.signIn();

      final MagicRequest request = sent().single;
      expect(request.method, 'POST');
      expect(request.url, '/auth/social/google/token');
      expect(request.data, {'id_token': 'google-id-token', 'intent': 'signin'});
      expect((request.data as Map).containsKey('nonce'), isFalse);
      expect(result.token, '1|abc');
    });

    test('a canceled sheet becomes SocialAuthCancelledException', () async {
      final _FakeGoogleDriver driver = _FakeGoogleDriver(
        throwing: const GoogleSignInException(
          code: GoogleSignInExceptionCode.canceled,
        ),
      );

      await expectLater(
        driver.signIn(),
        throwsA(isA<SocialAuthCancelledException>()),
      );
      expect(sent(), isEmpty);
    });

    test(
      'another SDK failure is coded sdk_error; its detail is logged',
      () async {
        final _FakeGoogleDriver driver = _FakeGoogleDriver(
          throwing: const GoogleSignInException(
            code: GoogleSignInExceptionCode.clientConfigurationError,
            description: 'serverClientId missing',
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
                  isNot(contains('serverClientId')),
                ),
          ),
        );
        expect(
          log.entries.single,
          isA<FakeLogEntry>()
              .having((e) => e.level, 'level', 'error')
              .having((e) => e.message, 'message', contains('serverClientId')),
        );
      },
    );

    test('an account without an ID token is refused before any post', () async {
      final _FakeGoogleDriver driver = _FakeGoogleDriver(idToken: null);

      await expectLater(
        driver.signIn(),
        throwsA(
          isA<SocialAuthException>().having((e) => e.code, 'code', 'sdk_error'),
        ),
      );
      expect(sent(), isEmpty);
      expect(log.entries.single.message, contains('server_client_id'));
    });

    test('a backend refusal surfaces with its code', () async {
      http = Http.fake({
        '/auth/social/google/token': Http.response({
          'message': 'Taken.',
          'code': 'social_email_taken',
        }, 409),
      });

      await expectLater(
        _FakeGoogleDriver().signIn(),
        throwsA(
          isA<SocialAuthException>().having(
            (e) => e.code,
            'code',
            'social_email_taken',
          ),
        ),
      );
    });
  });

  group('initialize', () {
    test('two drivers share one initialize call', () async {
      await _FakeGoogleDriver().signIn();
      await _FakeGoogleDriver().signIn();
      await _FakeGoogleDriver().signOut();

      expect(_FakeGoogleDriver.initializations, hasLength(1));
    });

    test('passes ios_client_id only on iOS, server_client_id on both', () {
      const Map<String, dynamic> config = {
        'ios_client_id': 'ios.apps.googleusercontent.com',
        'server_client_id': 'web.apps.googleusercontent.com',
      };

      final GoogleDriver ios = GoogleDriver(
        config,
        platform: SocialPlatform.ios,
      );
      final GoogleDriver android = GoogleDriver(
        config,
        platform: SocialPlatform.android,
      );

      expect(ios.clientId, 'ios.apps.googleusercontent.com');
      expect(android.clientId, isNull);
      expect(ios.serverClientId, 'web.apps.googleusercontent.com');
      expect(android.serverClientId, 'web.apps.googleusercontent.com');
    });

    test('an empty client id is no client id, so Info.plist applies', () {
      const Map<String, dynamic> config = {
        'ios_client_id': '',
        'server_client_id': '',
      };

      final GoogleDriver ios = GoogleDriver(
        config,
        platform: SocialPlatform.ios,
      );

      expect(ios.clientId, isNull);
      expect(ios.serverClientId, isNull);
    });
  });

  group('connect', () {
    test('posts intent connect with the proof', () async {
      final _FakeGoogleDriver driver = _FakeGoogleDriver();
      http = Http.fake({
        '/auth/social/google/token': Http.response({
          'data': {'provider': 'google', 'email': 'a@example.com'},
        }),
      });

      final SocialAuthResult result = await driver.connect({'password': 'x'});

      expect(sent().single.data, {
        'id_token': 'google-id-token',
        'intent': 'connect',
        'password': 'x',
      });
      expect(result.connectedProvider, 'google');
    });

    test('beginConnect opens the sheet only when its call runs', () async {
      final _FakeGoogleDriver driver = _FakeGoogleDriver();

      final Future<SocialAuthResult> Function() finish = await driver
          .beginConnect(null);

      expect(driver.sheets, 0);
      await finish();
      expect(driver.sheets, 1);
      expect(sent().single.data, {
        'id_token': 'google-id-token',
        'intent': 'connect',
      });
    });
  });

  test(
    'confirm posts intent confirm and reads the confirmation token',
    () async {
      http = Http.fake({
        '/auth/social/google/token': Http.response({
          'data': {'confirmation_token': 'c0nf'},
        }),
      });

      final SocialAuthResult result = await _FakeGoogleDriver().confirm();

      expect(sent().single.data, {
        'id_token': 'google-id-token',
        'intent': 'confirm',
      });
      expect(result.confirmationToken, 'c0nf');
    },
  );

  group('signOut', () {
    test('signs the SDK out after the memoized initialize', () async {
      final _FakeGoogleDriver driver = _FakeGoogleDriver();

      await driver.signOut();

      expect(_FakeGoogleDriver.initializations, hasLength(1));
      expect(driver.sdkSignOuts, 1);
    });

    test('never touches the SDK off iOS and Android', () async {
      final _FakeGoogleDriver driver = _FakeGoogleDriver(
        platform: SocialPlatform.macos,
      );

      await driver.signOut();

      expect(_FakeGoogleDriver.initializations, isEmpty);
      expect(driver.sdkSignOuts, 0);
    });
  });
}

/// A [GoogleDriver] with the platform channel stood in for; the memoized
/// initialize and every post are the real ones.
class _FakeGoogleDriver extends GoogleDriver {
  _FakeGoogleDriver({
    this.throwing,
    this.idToken = 'google-id-token',
    SocialPlatform platform = SocialPlatform.android,
  }) : super(const {'server_client_id': 'web-client'}, platform: platform);

  /// Every SDK initialize, across all instances.
  static final List<_FakeGoogleDriver> initializations = [];

  final Object? throwing;

  final String? idToken;

  int sheets = 0;

  int sdkSignOuts = 0;

  @override
  Future<void> initializeSdk() async => initializations.add(this);

  @override
  Future<String?> nativeSignIn() async {
    sheets++;
    if (throwing != null) throw throwing!;

    return idToken;
  }

  @override
  Future<void> signOutSdk() async => sdkSignOuts++;
}

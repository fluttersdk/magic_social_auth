import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:magic/magic.dart';
import 'package:magic_social_auth/src/exceptions/social_auth_exception.dart';
import 'package:magic_social_auth/src/flow/nonce.dart';
import 'package:magic_social_auth/src/flow/pkce.dart';
import 'package:magic_social_auth/src/flow/social_flow.dart';
import 'package:magic_social_auth/src/flow/web_flow_slot.dart';
import 'package:magic_social_auth/src/models/social_auth_result.dart';
import 'package:magic_social_auth/src/models/social_platform.dart';

void main() {
  late FakeNetworkDriver http;
  late FakeLogManager log;

  /// The backend's answer per path; anything unlisted answers 404.
  late Map<String, MagicResponse> answers;

  setUp(() {
    MagicApp.reset();
    log = Log.fake();
    Config.set('network.drivers.api', {
      'base_url': 'https://api.example.com/api/v1',
    });
    Config.set('social_auth.callback', {
      'ios': 'com.example.app://auth/social',
      'android': 'https://app.example.com/auth/social',
    });
    answers = {};
    http = Http.fake(
      (MagicRequest request) =>
          answers[request.url] ?? Http.response({'message': 'Not Found'}, 404),
    );
  });

  tearDown(MagicApp.reset);

  List<MagicRequest> sent() => [
    for (final (MagicRequest request, _) in http.recorded) request,
  ];

  group('redirectUrl', () {
    test('is absolute from the network base_url', () {
      final SocialFlow flow = SocialFlow(platform: SocialPlatform.android);

      final Uri url = flow.redirectUrl(
        'github',
        SocialPlatform.android,
        'C' * 43,
      );

      expect(
        url.toString(),
        'https://api.example.com/api/v1/auth/social/github/redirect'
        '?platform=android&challenge=${'C' * 43}',
      );
    });

    test('joins a base_url with a trailing slash without doubling it', () {
      Config.set('network.drivers.api.base_url', 'https://api.example.com/v1/');
      final SocialFlow flow = SocialFlow(platform: SocialPlatform.ios);

      final Uri url = flow.redirectUrl('apple', SocialPlatform.ios, 'C' * 43);

      expect(url.path, '/v1/auth/social/apple/redirect');
    });

    test('carries a ticket for a connect and intent=confirm for a confirm', () {
      final SocialFlow flow = SocialFlow(platform: SocialPlatform.web);

      final Uri connect = flow.redirectUrl(
        'github',
        SocialPlatform.web,
        'C' * 43,
        ticket: 't1',
      );
      final Uri confirm = flow.redirectUrl(
        'github',
        SocialPlatform.web,
        'C' * 43,
        confirm: true,
      );

      expect(connect.queryParameters['ticket'], 't1');
      expect(connect.queryParameters.containsKey('intent'), isFalse);
      expect(confirm.queryParameters['intent'], 'confirm');
      expect(confirm.queryParameters.containsKey('ticket'), isFalse);
    });
  });

  group('signIn', () {
    test(
      'browses the redirect, then exchanges the code with its verifier',
      () async {
        answers['/auth/social/exchange'] = Http.response({
          'data': {
            'user': {'id': 1},
            'token': '1|abc',
          },
        });
        final _ScriptedFlow flow = _ScriptedFlow(SocialPlatform.android)
          ..callbackFor = (_) => 'https://app.example.com/auth/social?code=Zk3';

        final SocialAuthResult result = await flow.signIn('github');

        final Uri browsed = Uri.parse(flow.calls.single.url);
        expect(browsed.path, '/api/v1/auth/social/github/redirect');
        expect(browsed.queryParameters['platform'], 'android');
        final MagicRequest exchange = sent().single;
        expect(exchange.url, '/auth/social/exchange');
        expect(exchange.method, 'POST');
        expect(exchange.data, {
          'code': 'Zk3',
          'code_verifier': (exchange.data as Map)['code_verifier'],
        });
        expect(
          Pkce.challengeFor((exchange.data as Map)['code_verifier'] as String),
          browsed.queryParameters['challenge'],
        );
        expect(result.token, '1|abc');
      },
    );

    test('reaches authenticate with no await before it', () {
      final _ScriptedFlow flow = _ScriptedFlow(SocialPlatform.web)..hold = true;

      unawaited(flow.signIn('google'));

      // Synchronously: a browser opens a popup only inside the click's task.
      expect(flow.calls, hasLength(1));
    });

    test('mints a new PKCE pair on every call', () async {
      answers['/auth/social/exchange'] = Http.response({
        'data': {'token': 't'},
      });
      final _ScriptedFlow flow = _ScriptedFlow(SocialPlatform.ios)
        ..callbackFor = (_) => 'com.example.app://auth/social?code=x';

      await flow.signIn('github');
      await flow.signIn('github');

      final Set<String?> challenges = {
        for (final call in flow.calls)
          Uri.parse(call.url).queryParameters['challenge'],
      };
      expect(challenges, hasLength(2));
    });

    test('a callback error throws its code and exchanges nothing', () async {
      final _ScriptedFlow flow = _ScriptedFlow(SocialPlatform.ios)
        ..callbackFor = (_) =>
            'com.example.app://auth/social?error=social_email_taken';

      await expectLater(
        flow.signIn('google'),
        throwsA(
          isA<SocialAuthException>().having(
            (e) => e.code,
            'code',
            'social_email_taken',
          ),
        ),
      );
      expect(sent(), isEmpty);
    });

    test('a browser cancel becomes SocialAuthCancelledException', () async {
      final _ScriptedFlow flow = _ScriptedFlow(SocialPlatform.android)
        ..failWith = PlatformException(code: 'CANCELED');

      await expectLater(
        flow.signIn('github'),
        throwsA(
          isA<SocialAuthCancelledException>().having(
            (e) => e.superseded,
            'superseded',
            isFalse,
          ),
        ),
      );
    });

    test('the web popup timing out is a cancel', () async {
      // flutter_web_auth_2 5.1.0 lib/src/web.dart:120, after 300 polls.
      final _ScriptedFlow flow = _ScriptedFlow(SocialPlatform.web)
        ..failWith = PlatformException(
          code: 'error',
          message: 'Timeout waiting for callback value',
        );

      await expectLater(
        flow.signIn('github'),
        throwsA(
          isA<SocialAuthCancelledException>().having(
            (e) => e.superseded,
            'superseded',
            isFalse,
          ),
        ),
      );
    });

    test('another browser failure is coded sdk_error, detail logged', () async {
      final _ScriptedFlow flow = _ScriptedFlow(SocialPlatform.ios)
        ..failWith = PlatformException(
          code: 'EUNKNOWN',
          message: 'ASWebAuthenticationSession failed',
        );

      await expectLater(
        flow.signIn('github'),
        throwsA(
          isA<SocialAuthException>()
              .having((e) => e is SocialAuthCancelledException, 'cancel', false)
              .having((e) => e.code, 'code', 'sdk_error')
              .having(
                (e) => e.message,
                'message',
                isNot(contains('ASWebAuthenticationSession')),
              ),
        ),
      );
      expect(
        log.entries.single.message,
        contains('ASWebAuthenticationSession'),
      );
    });

    test('a callback with neither code nor error is coded sdk_error', () async {
      final _ScriptedFlow flow = _ScriptedFlow(SocialPlatform.ios)
        ..callbackFor = (_) => 'com.example.app://auth/social';

      await expectLater(
        flow.signIn('github'),
        throwsA(
          isA<SocialAuthException>().having((e) => e.code, 'code', 'sdk_error'),
        ),
      );
      expect(sent(), isEmpty);
    });

    test('a refused exchange throws the backend code and status', () async {
      answers['/auth/social/exchange'] = Http.response({
        'message': 'This sign-in has expired.',
        'code': 'flow_expired',
      }, 422);
      final _ScriptedFlow flow = _ScriptedFlow(SocialPlatform.android)
        ..callbackFor = (_) => 'https://app.example.com/auth/social?code=old';

      await expectLater(
        flow.signIn('github'),
        throwsA(
          isA<SocialAuthException>()
              .having((e) => e.code, 'code', 'flow_expired')
              .having((e) => e.statusCode, 'statusCode', 422),
        ),
      );
    });
  });

  group('browser options per platform', () {
    setUp(() {
      answers['/auth/social/exchange'] = Http.response({
        'data': {'token': 't'},
      });
    });

    test('iOS uses the custom scheme, ephemeral only for a confirm', () async {
      answers['/auth/social/exchange'] = Http.response({
        'data': {'confirmation_token': 'c0nf1rm'},
      });
      final _ScriptedFlow flow = _ScriptedFlow(SocialPlatform.ios)
        ..callbackFor = (_) => 'com.example.app://auth/social?code=x';

      await flow.signIn('apple');
      final SocialAuthResult confirmed = await flow.confirm('apple');

      expect(flow.calls[0].scheme, 'com.example.app');
      expect(flow.calls[0].options.preferEphemeral, isFalse);
      expect(flow.calls[1].options.preferEphemeral, isTrue);
      expect(Uri.parse(flow.calls[1].url).queryParameters['intent'], 'confirm');
      expect(confirmed.confirmationToken, 'c0nf1rm');
    });

    test('Android uses the https App Link and is never ephemeral', () async {
      final _ScriptedFlow flow = _ScriptedFlow(SocialPlatform.android)
        ..callbackFor = (_) => 'https://app.example.com/auth/social?code=x';

      await flow.confirm('github');

      final call = flow.calls.single;
      expect(call.scheme, 'https');
      expect(call.options.httpsHost, 'app.example.com');
      expect(call.options.httpsPath, '/auth/social');
      expect(call.options.preferEphemeral, isFalse);
    });

    test('a missing callback for the platform fails loudly', () async {
      Config.set('social_auth.callback', <String, dynamic>{});
      final _ScriptedFlow flow = _ScriptedFlow(SocialPlatform.ios);

      await expectLater(
        flow.signIn('apple'),
        throwsA(isA<SocialAuthException>()),
      );
      expect(flow.calls, isEmpty);
    });
  });

  group('connect', () {
    test('posts link-ticket, then browses with the same challenge', () async {
      answers['/user/social-accounts/link-ticket'] = Http.response({
        'data': {'ticket': 't1ck3t'},
      });
      answers['/auth/social/exchange'] = Http.response({
        'data': {'provider': 'github', 'email': 'user@example.com'},
      });
      final _ScriptedFlow flow = _ScriptedFlow(SocialPlatform.android)
        ..callbackFor = (_) => 'https://app.example.com/auth/social?code=c';

      final SocialAuthResult result = await flow.connect('github', {
        'password': 'CurrentSecret123',
      });

      final List<MagicRequest> requests = sent();
      expect(requests.map((r) => r.url), [
        '/user/social-accounts/link-ticket',
        '/auth/social/exchange',
      ]);
      final Map ticketBody = requests.first.data as Map;
      expect(ticketBody['provider'], 'github');
      expect(ticketBody['password'], 'CurrentSecret123');
      final Uri browsed = Uri.parse(flow.calls.single.url);
      expect(browsed.queryParameters['challenge'], ticketBody['challenge']);
      expect(browsed.queryParameters['ticket'], 't1ck3t');
      expect(
        Pkce.challengeFor((requests.last.data as Map)['code_verifier']),
        ticketBody['challenge'],
      );
      expect(result.connectedProvider, 'github');
    });

    test('a guest sends no proof', () async {
      answers['/user/social-accounts/link-ticket'] = Http.response({
        'data': {'ticket': 't'},
      });
      answers['/auth/social/exchange'] = Http.response({
        'data': {'provider': 'github'},
      });
      final _ScriptedFlow flow = _ScriptedFlow(SocialPlatform.ios)
        ..callbackFor = (_) => 'com.example.app://auth/social?code=c';

      await flow.connect('github', null);

      expect((sent().first.data as Map).keys, ['provider', 'challenge']);
    });

    test('a ticket answer without a ticket is coded sdk_error', () async {
      answers['/user/social-accounts/link-ticket'] = Http.response({
        'data': <String, dynamic>{},
      });
      final _ScriptedFlow flow = _ScriptedFlow(SocialPlatform.ios);

      await expectLater(
        flow.connect('github', null),
        throwsA(
          isA<SocialAuthException>().having((e) => e.code, 'code', 'sdk_error'),
        ),
      );
      expect(flow.calls, isEmpty);
    });

    test('a refused ticket opens no browser', () async {
      answers['/user/social-accounts/link-ticket'] = Http.response({
        'message': 'Please confirm your identity to continue.',
        'code': 'step_up_required',
      }, 422);
      final _ScriptedFlow flow = _ScriptedFlow(SocialPlatform.ios);

      await expectLater(
        flow.connect('github', null),
        throwsA(
          isA<SocialAuthException>().having(
            (e) => e.code,
            'code',
            'step_up_required',
          ),
        ),
      );
      expect(flow.calls, isEmpty);
    });
  });

  group('one browser flow at a time', () {
    test('a stale web poller hands the newest flow its callback', () async {
      answers['/auth/social/exchange'] = Http.response({
        'data': {'token': 'second'},
      });
      final _ScriptedFlow flow = _ScriptedFlow(SocialPlatform.web)..hold = true;

      final Future<SocialAuthResult> first = flow.signIn('github');
      final Future<SocialAuthResult> second = flow.signIn('github');
      // flutter_web_auth_2 web: every pending flow polls one localStorage key
      // and the first to see it takes it, here the stale one.
      flow.pending[0].complete('https://app.example.com/auth.html?code=c2');

      await expectLater(
        first,
        throwsA(
          isA<SocialAuthCancelledException>().having(
            (e) => e.superseded,
            'superseded',
            isTrue,
          ),
        ),
      );
      expect((await second).token, 'second');
      final MagicRequest exchange = sent().single;
      expect((exchange.data as Map)['code'], 'c2');
      expect(
        Pkce.challengeFor((exchange.data as Map)['code_verifier']),
        Uri.parse(flow.calls[1].url).queryParameters['challenge'],
      );
    });

    test(
      'a refusal a stale web poller takes reaches the newest flow',
      () async {
        final _ScriptedFlow flow = _ScriptedFlow(SocialPlatform.web)
          ..hold = true;

        final Future<SocialAuthResult> first = flow.signIn('github');
        final Future<SocialAuthResult> second = flow.signIn('github');
        flow.pending[0].complete(
          'https://app.example.com/auth.html?error=social_email_taken',
        );

        await expectLater(first, throwsA(isA<SocialAuthCancelledException>()));
        await expectLater(
          second,
          throwsA(
            isA<SocialAuthException>().having(
              (e) => e.code,
              'code',
              'social_email_taken',
            ),
          ),
        );
        expect(sent(), isEmpty);
      },
    );

    test('a stale web flow finishing last is discarded too', () async {
      answers['/auth/social/exchange'] = Http.response({
        'data': {'token': 'second'},
      });
      final _ScriptedFlow flow = _ScriptedFlow(SocialPlatform.web)..hold = true;

      final Future<SocialAuthResult> first = flow.signIn('github');
      final Future<SocialAuthResult> second = flow.signIn('github');
      flow.pending[1].complete('https://app.example.com/auth.html?code=c2');
      await second;
      flow.pending[0].complete('https://app.example.com/auth.html?code=c1');

      await expectLater(first, throwsA(isA<SocialAuthCancelledException>()));
      expect(sent(), hasLength(1));
    });

    test('a mobile start while one is open is refused', () async {
      answers['/auth/social/exchange'] = Http.response({
        'data': {'token': 'only'},
      });
      final _ScriptedFlow flow = _ScriptedFlow(SocialPlatform.android)
        ..hold = true;

      final Future<SocialAuthResult> first = flow.signIn('github');
      await expectLater(
        flow.signIn('github'),
        throwsA(
          isA<SocialAuthCancelledException>().having(
            (e) => e.superseded,
            'superseded',
            isTrue,
          ),
        ),
      );
      flow.pending.single.complete(
        'https://app.example.com/auth/social?code=c1',
      );

      expect((await first).token, 'only');
      expect(flow.calls, hasLength(1));
    });

    test('a finished mobile flow frees the browser', () async {
      final _ScriptedFlow flow = _ScriptedFlow(SocialPlatform.android)
        ..failWith = PlatformException(code: 'CANCELED');

      await expectLater(flow.signIn('github'), throwsA(anything));
      await expectLater(flow.signIn('github'), throwsA(anything));

      expect(flow.calls, hasLength(2));
    });
  });

  group('token', () {
    test('Apple gets the raw nonce and the authorization code', () async {
      answers['/auth/social/apple/token'] = Http.response({
        'data': {'token': '1|abc'},
      });
      final Nonce nonce = Nonce.generate();
      final SocialFlow flow = SocialFlow(platform: SocialPlatform.ios);

      final SocialAuthResult result = await flow.token(
        'apple',
        idToken: 'eyJ.id.token',
        nonce: nonce,
        authorizationCode: 'c1a2',
      );

      expect(sent().single.data, {
        'id_token': 'eyJ.id.token',
        'nonce': nonce.raw,
        'authorization_code': 'c1a2',
        'intent': 'signin',
      });
      expect(result.token, '1|abc');
    });

    test('Google sends no nonce; a connect carries the proof', () async {
      answers['/auth/social/google/token'] = Http.response({
        'data': {'provider': 'google'},
      });
      final SocialFlow flow = SocialFlow(platform: SocialPlatform.android);

      await flow.token(
        'google',
        idToken: 'eyJ.id.token',
        intent: SocialIntent.connect,
        proof: {'confirmation_token': 'c0nf1rm'},
      );

      expect(sent().single.data, {
        'id_token': 'eyJ.id.token',
        'intent': 'connect',
        'confirmation_token': 'c0nf1rm',
      });
    });

    test('a refused token throws the backend code', () async {
      answers['/auth/social/google/token'] = Http.response({
        'message': 'Try again later.',
        'code': 'provider_unavailable',
      }, 503);
      final SocialFlow flow = SocialFlow(platform: SocialPlatform.android);

      await expectLater(
        flow.token('google', idToken: 'x'),
        throwsA(
          isA<SocialAuthException>()
              .having((e) => e.code, 'code', 'provider_unavailable')
              .having((e) => e.statusCode, 'statusCode', 503),
        ),
      );
    });
  });
}

/// A [SocialFlow] with the browser stood in for.
///
/// Only [SocialFlow.authenticate] is replaced; URL building, the slot, callback
/// parsing and the exchange are the real ones. Each flow gets its own slot so
/// one test's pending flow cannot supersede another's.
class _ScriptedFlow extends SocialFlow {
  _ScriptedFlow(SocialPlatform platform)
    : super(platform: platform, slot: WebFlowSlot());

  /// Every browser opening, in order.
  final List<({String url, String scheme, FlutterWebAuth2Options options})>
  calls = [];

  /// When true, each opening waits on a completer in [pending].
  bool hold = false;

  final List<Completer<String>> pending = [];

  /// The callback URL the browser lands on for a given redirect URL.
  String Function(String url) callbackFor = (_) =>
      throw StateError('no callback scripted');

  /// Thrown by the browser instead of answering.
  Object? failWith;

  @override
  Future<String> authenticate({
    required String url,
    required String callbackUrlScheme,
    required FlutterWebAuth2Options options,
  }) {
    calls.add((url: url, scheme: callbackUrlScheme, options: options));

    if (failWith != null) return Future.error(failWith!);

    if (hold) {
      final Completer<String> completer = Completer<String>();
      pending.add(completer);

      return completer.future;
    }

    return Future.value(callbackFor(url));
  }
}

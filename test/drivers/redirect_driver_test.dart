import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:magic/magic.dart';
import 'package:magic_social_auth/src/drivers/redirect_driver.dart';
import 'package:magic_social_auth/src/flow/pkce.dart';
import 'package:magic_social_auth/src/flow/social_flow.dart';
import 'package:magic_social_auth/src/flow/web_flow_slot.dart';
import 'package:magic_social_auth/src/models/social_auth_result.dart';
import 'package:magic_social_auth/src/models/social_platform.dart';

void main() {
  late FakeNetworkDriver http;

  setUp(() {
    MagicApp.reset();
    Config.set('network.drivers.api', {
      'base_url': 'https://api.example.com/api/v1',
    });
    Config.set('social_auth.callback', {
      'android': 'https://app.example.com/auth/social',
    });
    http = Http.fake({
      '/user/social-accounts/link-ticket': Http.response({
        'data': {'ticket': 'tkt'},
      }),
      '/auth/social/exchange': Http.response({
        'data': {'provider': 'github', 'token': '1|abc'},
      }),
    });
  });

  tearDown(MagicApp.reset);

  List<MagicRequest> sent() => [
    for (final (MagicRequest request, _) in http.recorded) request,
  ];

  test('carries the provider name it was built for', () {
    final RedirectDriver driver = RedirectDriver('microsoft', const {});

    expect(driver.name, 'microsoft');
    expect(driver.supportedPlatforms, {
      SocialPlatform.ios,
      SocialPlatform.android,
      SocialPlatform.web,
    });
  });

  test('signIn opens the browser with no await before it', () {
    final _ScriptedFlow flow = _ScriptedFlow(SocialPlatform.web)..hold = true;

    unawaited(RedirectDriver('github', const {}, flow: flow).signIn());

    expect(flow.urls, hasLength(1));
    expect(flow.urls.single.path, '/api/v1/auth/social/github/redirect');
  });

  test('signIn exchanges the callback code for the result', () async {
    final _ScriptedFlow flow = _ScriptedFlow(SocialPlatform.web);

    final SocialAuthResult result = await RedirectDriver(
      'github',
      const {},
      flow: flow,
    ).signIn();

    expect(sent().single.url, '/auth/social/exchange');
    expect(result.token, '1|abc');
  });

  group('beginConnect', () {
    test('mints the ticket first and opens the browser only on call', () async {
      final _ScriptedFlow flow = _ScriptedFlow(SocialPlatform.web)..hold = true;
      final RedirectDriver driver = RedirectDriver(
        'github',
        const {},
        flow: flow,
      );

      final Future<SocialAuthResult> Function() open = await driver
          .beginConnect({'password': 'x'});

      final MagicRequest ticket = sent().single;
      expect(ticket.url, '/user/social-accounts/link-ticket');
      expect(flow.urls, isEmpty);

      unawaited(open());

      // Synchronously: the popup belongs to the tap that ran [open].
      expect(flow.urls, hasLength(1));
      final Uri browsed = flow.urls.single;
      expect(browsed.queryParameters['ticket'], 'tkt');
      expect(
        browsed.queryParameters['challenge'],
        (ticket.data as Map)['challenge'],
      );
      expect((ticket.data as Map)['password'], 'x');
    });

    test('a guest sends no proof', () async {
      final _ScriptedFlow flow = _ScriptedFlow(SocialPlatform.android);

      await RedirectDriver('github', const {}, flow: flow).connect(null);

      expect((sent().first.data as Map).keys, {'provider', 'challenge'});
    });

    test(
      'connect exchanges with the verifier of the ticket challenge',
      () async {
        final _ScriptedFlow flow = _ScriptedFlow(SocialPlatform.android);

        final SocialAuthResult result = await RedirectDriver(
          'github',
          const {},
          flow: flow,
        ).connect({'password': 'x'});

        final [MagicRequest ticket, MagicRequest exchange] = sent();
        expect(
          Pkce.challengeFor((exchange.data as Map)['code_verifier'] as String),
          (ticket.data as Map)['challenge'],
        );
        expect(result.connectedProvider, 'github');
      },
    );
  });

  test('confirm runs the browser flow with intent confirm', () async {
    final _ScriptedFlow flow = _ScriptedFlow(SocialPlatform.web);

    await RedirectDriver('apple', const {}, flow: flow).confirm();

    expect(flow.urls.single.path, '/api/v1/auth/social/apple/redirect');
    expect(flow.urls.single.queryParameters['intent'], 'confirm');
  });
}

/// A [SocialFlow] whose browser answers from a script.
class _ScriptedFlow extends SocialFlow {
  _ScriptedFlow(SocialPlatform platform)
    : super(platform: platform, slot: WebFlowSlot());

  /// Every URL the browser opened, in order.
  final List<Uri> urls = [];

  /// When true, the browser never answers.
  bool hold = false;

  @override
  Future<String> authenticate({
    required String url,
    required String callbackUrlScheme,
    required FlutterWebAuth2Options options,
  }) {
    urls.add(Uri.parse(url));

    if (hold) return Completer<String>().future;

    return Future.value('https://app.example.com/auth.html?code=Zk3');
  }
}

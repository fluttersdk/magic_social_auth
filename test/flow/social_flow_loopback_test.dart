import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:magic/magic.dart';
import 'package:magic_social_auth/src/flow/pkce.dart';
import 'package:magic_social_auth/src/flow/social_flow.dart';
import 'package:magic_social_auth/src/flow/web_flow_slot.dart';
import 'package:magic_social_auth/src/models/social_auth_result.dart';
import 'package:magic_social_auth/src/models/social_platform.dart';

class _User extends Model with Authenticatable {
  @override
  String get table => 'users';

  @override
  String get resource => 'users';
}

/// One request as the socket saw it.
typedef _Seen = ({String path, String? authorization, Map body});

/// A loopback backend answering the social routes.
///
/// `Http.fake()` never runs an interceptor and never encodes a body, so what
/// the server actually receives (the JSON on the wire, the bearer the
/// `AuthInterceptor` attaches) is only observable on a real socket.
///
/// This file deliberately never calls `TestWidgetsFlutterBinding
/// .ensureInitialized()`: the test binding installs an `HttpOverrides` whose
/// client answers every request 400, and nothing here needs the binding.
class _Backend {
  _Backend._(this._server) {
    _server.listen(_answer);
  }

  final HttpServer _server;

  final List<_Seen> seen = [];

  static Future<_Backend> start() async =>
      _Backend._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  String get baseUrl => 'http://127.0.0.1:${_server.port}/api/v1';

  Future<void> _answer(HttpRequest request) async {
    final String raw = await utf8.decoder.bind(request).join();
    seen.add((
      path: request.uri.path,
      authorization: request.headers.value('authorization'),
      body: raw.isEmpty ? {} : jsonDecode(raw) as Map,
    ));

    final Object answer = switch (request.uri.path) {
      '/api/v1/user/social-accounts/link-ticket' => {
        'data': {'ticket': 't1ck3t'},
      },
      '/api/v1/auth/social/exchange' => {
        'data': {
          'user': {'id': 1},
          'token': '1|issued',
        },
      },
      _ => {'message': 'Not Found'},
    };

    request.response
      ..statusCode = 200
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(answer));
    await request.response.close();
  }

  Future<void> close() => _server.close(force: true);
}

/// The browser stood in for: it lands on the App Link with a fixed code and
/// remembers the redirect it was sent to.
class _LoopbackFlow extends SocialFlow {
  _LoopbackFlow()
    : super(platform: SocialPlatform.android, slot: WebFlowSlot());

  final List<Uri> browsed = [];

  @override
  Future<String> authenticate({
    required String url,
    required String callbackUrlScheme,
    required FlutterWebAuth2Options options,
  }) async {
    browsed.add(Uri.parse(url));

    return 'https://app.example.com/auth/social?code=Zk3';
  }
}

void main() {
  late _Backend backend;

  setUp(() async {
    MagicApp.reset();
    Magic.flush();
    Log.fake();
    Vault.fake();
    backend = await _Backend.start();
    Config.set('network.drivers.api', {
      'base_url': backend.baseUrl,
      'headers': {'Accept': 'application/json'},
    });
    Config.set('social_auth.callback', {
      'android': 'https://app.example.com/auth/social',
    });

    // The real stack: the driver the NetworkServiceProvider builds from config,
    // with the AuthInterceptor the AuthServiceProvider adds to it.
    NetworkServiceProvider(MagicApp.instance).register();
    Magic.singleton('auth', AuthManager.new);
    Auth.manager.forgetGuards();
    Magic.make<NetworkDriver>('network').addInterceptor(AuthInterceptor());
  });

  tearDown(() async {
    await backend.close();
    Auth.manager.forgetGuards();
    Vault.unfake();
    Log.unfake();
    MagicApp.reset();
    Magic.flush();
  });

  test('a sign-in exchanges {code, code_verifier} for the session', () async {
    final _LoopbackFlow flow = _LoopbackFlow();

    final SocialAuthResult result = await flow.signIn('github');

    final _Seen exchange = backend.seen.single;
    expect(exchange.path, '/api/v1/auth/social/exchange');
    expect(exchange.body.keys, ['code', 'code_verifier']);
    expect(exchange.body['code'], 'Zk3');
    expect(
      Pkce.challengeFor(exchange.body['code_verifier'] as String),
      flow.browsed.single.queryParameters['challenge'],
    );
    expect(exchange.authorization, isNull);
    expect(result.token, '1|issued');
  });

  test(
    'a connect sends the bearer on link-ticket and on the exchange',
    () async {
      final BaseGuard guard = Auth.guard() as BaseGuard;
      await guard.storeToken('signed-in-token');
      guard.setUser(_User()..setRawAttributes({'id': 1}, sync: true));
      final _LoopbackFlow flow = _LoopbackFlow();

      await flow.connect('github', {'password': 'CurrentSecret123'});

      final [_Seen ticket, _Seen exchange] = backend.seen;
      expect(ticket.path, '/api/v1/user/social-accounts/link-ticket');
      expect(ticket.authorization, 'Bearer signed-in-token');
      expect(ticket.body['provider'], 'github');
      expect(ticket.body['password'], 'CurrentSecret123');
      expect(
        flow.browsed.single.toString(),
        startsWith('${backend.baseUrl}/auth/social/github/redirect?'),
      );
      expect(
        flow.browsed.single.queryParameters['challenge'],
        ticket.body['challenge'],
      );
      expect(flow.browsed.single.queryParameters['ticket'], 't1ck3t');
      expect(exchange.authorization, 'Bearer signed-in-token');
      expect(
        Pkce.challengeFor(exchange.body['code_verifier'] as String),
        ticket.body['challenge'],
      );
    },
  );
}

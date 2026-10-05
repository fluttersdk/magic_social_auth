import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:magic/magic.dart';

import '../exceptions/social_auth_exception.dart';
import '../models/social_auth_result.dart';
import '../models/social_platform.dart';
import 'nonce.dart';
import 'pkce.dart';
import 'web_flow_slot.dart';

/// Why a native ID token is posted to the token endpoint.
enum SocialIntent {
  signIn('signin'),
  connect('connect'),
  confirm('confirm');

  const SocialIntent(this.value);

  /// The `intent` the backend reads.
  final String value;
}

/// The client half of magic-starter-laravel's social login contract.
///
/// Two ways in. The browser flow (any provider): [redirectUrl] starts it at
/// the backend, [browse] waits for the callback carrying a one-time code, and
/// [exchange] trades that code plus the PKCE verifier for the outcome.
/// [signIn], [connect] and [confirm] compose it. The native token endpoint
/// (Google and Apple SDKs): [token] posts the provider's ID token.
///
/// Every flow mints a new [Pkce] pair and a new link ticket; nothing is cached
/// or persisted, so a retry is always a fresh flow. Requests go through magic's
/// `Http` facade, so the auth interceptor attaches the bearer a connect or a
/// confirm needs.
///
/// The browser callback is read from `social_auth.callback.ios` (a custom
/// scheme URL, `myapp://auth/social`) and `social_auth.callback.android` (an
/// https App Link, `https://example.com/auth/social`); they must match the
/// backend's `redirects.ios` and `redirects.android`. The web flow lands on
/// the app's own `auth.html` and needs no callback key.
class SocialFlow {
  SocialFlow({SocialPlatform? platform, WebFlowSlot? slot})
    : platform = platform ?? SocialPlatformExtension.current,
      _slot = slot ?? WebFlowSlot.shared;

  /// The platform the backend picks its redirect target for.
  final SocialPlatform platform;

  final WebFlowSlot _slot;

  /// Signs in with [provider] through the browser.
  ///
  /// On the web the popup opens in the same synchronous run as this call, so
  /// call it straight from the tap handler with no `await` before it.
  ///
  /// Throws [SocialAuthCancelledException] when the user backs out or another
  /// flow takes the browser, and [SocialAuthException] with the backend's code
  /// for a refusal (`social_email_taken`, `flow_expired`, ...).
  Future<SocialAuthResult> signIn(String provider) {
    return authorize(provider, Pkce.generate());
  }

  /// Links [provider] to the signed-in account.
  ///
  /// [proof] is the step-up field the account can give (`{'password': ...}`,
  /// `{'code': ...}` or `{'confirmation_token': ...}`); null for a guest, who
  /// sends none. The link ticket's request is an `await`, so on the web the
  /// popup this opens afterwards is blocked; there, call [linkTicket] first and
  /// [authorize] with the same [Pkce] and the ticket from the user's next tap.
  Future<SocialAuthResult> connect(
    String provider,
    Map<String, String>? proof,
  ) async {
    final Pkce pkce = Pkce.generate();
    final String ticket = await linkTicket(provider, pkce.challenge, proof);

    return authorize(provider, pkce, ticket: ticket);
  }

  /// Re-authenticates with an already linked [provider] for a step-up proof.
  ///
  /// The result carries [SocialAuthResult.confirmationToken]. On iOS the sheet
  /// is ephemeral, so the provider asks for the account again instead of
  /// waving a remembered session through.
  Future<SocialAuthResult> confirm(String provider) {
    return authorize(provider, Pkce.generate(), confirm: true);
  }

  /// Runs one browser flow for [pkce] and exchanges its code.
  ///
  /// The browser opens before the first `await`. A [ticket] makes the flow a
  /// connect and [confirm] a step-up; never both.
  Future<SocialAuthResult> authorize(
    String provider,
    Pkce pkce, {
    String? ticket,
    bool confirm = false,
  }) async {
    // 1. A mobile sheet is modal, so a second start is a double tap; the web
    //    lets a new click supersede a popup that may have been closed silently.
    if (platform != SocialPlatform.web && _slot.isOpen) {
      throw const SocialAuthCancelledException(superseded: true);
    }

    final Object flow = _slot.claim();

    try {
      // 2. Open the browser in this synchronous run: a popup opened after an
      //    await is blocked as not user-initiated. A stale web flow may take
      //    this flow's callback, so the one it forwards counts as well.
      final Uri callback;
      try {
        callback = await Future.any([
          browse(
            redirectUrl(
              provider,
              platform,
              pkce.challenge,
              ticket: ticket,
              confirm: confirm,
            ),
            ephemeral: confirm,
          ),
          _slot.forwarded(flow),
        ]);
      } catch (_) {
        if (!_slot.isCurrent(flow)) {
          throw const SocialAuthCancelledException(superseded: true);
        }

        rethrow;
      }

      // 3. A superseded web poller usually holds the newest flow's callback
      //    (they share one localStorage key), so it goes there. A code that
      //    was this flow's own fails the newest flow's PKCE check at once,
      //    which beats the newest flow waiting out its 300 s timeout.
      if (!_slot.isCurrent(flow)) {
        _slot.forward(callback);
        throw const SocialAuthCancelledException(superseded: true);
      }

      return await exchange(_codeFrom(callback), pkce.verifier);
    } finally {
      _slot.release(flow);
    }
  }

  /// The backend URL that starts a browser flow for [provider].
  ///
  /// Absolute, from `network.drivers.api.base_url`, the same key magic's
  /// network driver is built from.
  Uri redirectUrl(
    String provider,
    SocialPlatform platform,
    String challenge, {
    String? ticket,
    bool confirm = false,
  }) {
    final Map<String, dynamic> network =
        Config.get<Map<String, dynamic>>('network.drivers.api') ?? {};
    final String base = network['base_url'] as String? ?? '';
    final Uri api = Uri.parse(base.endsWith('/') ? base : '$base/');

    return api
        .resolve('auth/social/$provider/redirect')
        .replace(
          queryParameters: {
            'platform': platform.name,
            'challenge': challenge,
            'ticket': ?ticket,
            if (confirm) 'intent': 'confirm',
          },
        );
  }

  /// Opens [url] in the system browser and returns the callback URL it lands
  /// on, carrying either a `code` or an `error`.
  ///
  /// [ephemeral] asks iOS for a session that shares no cookies; Android never
  /// gets one, since its ephemeral mode drops the Auth Tab for a Custom Tab
  /// that needs a callback activity the app does not declare.
  ///
  /// Throws [SocialAuthCancelledException] when the browser reports a cancel
  /// or the web popup times out, [SocialAuthException] coded `sdk_error` for
  /// any other browser failure (the detail goes to `Log.error`), and
  /// [UnsupportedPlatformException] off iOS, Android and web.
  Future<Uri> browse(Uri url, {bool ephemeral = false}) async {
    final (String scheme, FlutterWebAuth2Options options) = _browserFor(
      ephemeral,
    );

    try {
      return Uri.parse(
        await authenticate(
          url: url.toString(),
          callbackUrlScheme: scheme,
          options: options,
        ),
      );
    } on PlatformException catch (error) {
      if (error.code == 'CANCELED' || _isWebTimeout(error)) {
        throw const SocialAuthCancelledException();
      }

      Log.error('Social browser flow failed: ${error.code} ${error.message}');
      throw const SocialAuthException(
        'The sign-in could not be completed.',
        code: 'sdk_error',
      );
    }
  }

  /// Trades a callback [code] and the flow's [verifier] for its outcome.
  Future<SocialAuthResult> exchange(String code, String verifier) async {
    return SocialAuthResult.fromJson(
      await _post('/auth/social/exchange', {
        'code': code,
        'code_verifier': verifier,
      }),
    );
  }

  /// Asks for a single-use link ticket bound to the caller, [provider] and
  /// [challenge]. [proof] is as in [connect].
  Future<String> linkTicket(
    String provider,
    String challenge,
    Map<String, String>? proof,
  ) async {
    final Map<String, dynamic> json = await _post(
      '/user/social-accounts/link-ticket',
      {'provider': provider, 'challenge': challenge, ...?proof},
    );
    final Object? data = json['data'];
    final Object? ticket = data is Map ? data['ticket'] : null;

    if (ticket is! String) {
      Log.error('Link ticket answer carried no ticket: $json');
      throw const SocialAuthException(
        'The account could not be linked.',
        code: 'sdk_error',
      );
    }

    return ticket;
  }

  /// Posts a native SDK's [idToken] to `auth/social/{provider}/token`.
  ///
  /// [provider] is `google` or `apple`. [nonce] is Apple's only: its raw value
  /// is sent, Apple got the hash. Google takes none. [authorizationCode] is
  /// Apple's too, redeemed for the refresh token that account deletion
  /// revokes. [proof] is as in [connect], for [SocialIntent.connect].
  Future<SocialAuthResult> token(
    String provider, {
    required String idToken,
    Nonce? nonce,
    String? authorizationCode,
    SocialIntent intent = SocialIntent.signIn,
    Map<String, String>? proof,
  }) async {
    return SocialAuthResult.fromJson(
      await _post('/auth/social/$provider/token', {
        'id_token': idToken,
        'nonce': ?nonce?.raw,
        'authorization_code': ?authorizationCode,
        'intent': intent.value,
        ...?proof,
      }),
    );
  }

  /// The browser call, separated so tests can stand in for the platform.
  @visibleForTesting
  Future<String> authenticate({
    required String url,
    required String callbackUrlScheme,
    required FlutterWebAuth2Options options,
  }) {
    return FlutterWebAuth2.authenticate(
      url: url,
      callbackUrlScheme: callbackUrlScheme,
      options: options,
    );
  }

  (String, FlutterWebAuth2Options) _browserFor(bool ephemeral) {
    switch (platform) {
      case SocialPlatform.web:
        // The web plugin ignores the scheme (auth.html posts the URL back to
        // its opener) but still asserts it is a valid one.
        return ('https', const FlutterWebAuth2Options());
      case SocialPlatform.ios:
        final Uri callback = _callback('ios');

        return (
          callback.scheme,
          FlutterWebAuth2Options(preferEphemeral: ephemeral),
        );
      case SocialPlatform.android:
        final Uri callback = _callback('android');
        final bool https = callback.scheme == 'https';

        return (
          callback.scheme,
          FlutterWebAuth2Options(
            httpsHost: https ? callback.host : null,
            httpsPath: https ? callback.path : null,
          ),
        );
      case SocialPlatform.macos:
      case SocialPlatform.windows:
      case SocialPlatform.linux:
        throw UnsupportedPlatformException(
          'Social sign-in runs on iOS, Android and web, not ${platform.name}.',
        );
    }
  }

  Uri _callback(String platformKey) {
    final String? url = Config.get<String>('social_auth.callback.$platformKey');

    if (url == null || url.isEmpty) {
      throw SocialAuthException(
        'Set social_auth.callback.$platformKey to the URL the backend '
        'redirects $platformKey to.',
      );
    }

    return Uri.parse(url);
  }

  String _codeFrom(Uri callback) {
    final String? error = callback.queryParameters['error'];
    if (error != null) {
      throw SocialAuthException('The sign-in was refused.', code: error);
    }

    final String? code = callback.queryParameters['code'];
    if (code == null || code.isEmpty) {
      Log.error('Social callback carried neither code nor error: $callback');
      throw const SocialAuthException(
        'The sign-in could not be completed.',
        code: 'sdk_error',
      );
    }

    return code;
  }

  /// flutter_web_auth_2 5.1.0 gives up on a web popup after its timeout with
  /// `PlatformException(code: 'error', message: 'Timeout waiting for callback
  /// value')` (`lib/src/web.dart:120`); the user walked away, so it is a
  /// cancel.
  bool _isWebTimeout(PlatformException error) =>
      platform == SocialPlatform.web &&
      error.code == 'error' &&
      error.message == 'Timeout waiting for callback value';

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final MagicResponse response = await Http.post(path, data: body);

    if (!response.successful) throw SocialAuthException.fromResponse(response);

    final Object? json = response.data;

    return json is Map<String, dynamic> ? json : {};
  }
}

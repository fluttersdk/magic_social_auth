import '../contracts/social_driver.dart';
import '../flow/pkce.dart';
import '../flow/social_flow.dart';
import '../models/social_auth_result.dart';
import '../models/social_platform.dart';

/// Any provider through the backend's browser flow.
///
/// Serves GitHub and Microsoft everywhere, Apple off iOS and Google on the
/// web: the backend talks to the provider, and the app only carries a PKCE
/// pair and a one-time code (see [SocialFlow]).
class RedirectDriver extends SocialDriver {
  RedirectDriver(this.name, super.config, {super.platform, SocialFlow? flow})
    : _browser = flow ?? SocialFlow(platform: platform);

  @override
  final String name;

  final SocialFlow _browser;

  @override
  Set<SocialPlatform> get supportedPlatforms => {
    SocialPlatform.ios,
    SocialPlatform.android,
    SocialPlatform.web,
  };

  @override
  Future<SocialAuthResult> signIn() => _browser.signIn(name);

  @override
  Future<Future<SocialAuthResult> Function()> beginConnect(
    Map<String, String>? proof,
  ) async {
    // The ticket is bound to this pair's challenge, so the flow it opens must
    // spend the same pair.
    final Pkce pkce = Pkce.generate();
    final String ticket = await _browser.linkTicket(
      name,
      pkce.challenge,
      proof,
    );

    return () => _browser.authorize(name, pkce, ticket: ticket);
  }

  @override
  Future<SocialAuthResult> confirm() => _browser.confirm(name);
}

import '../models/social_auth_result.dart';
import '../models/social_platform.dart';

/// One provider's way into magic-starter-laravel's social login.
///
/// A driver ends every flow at the backend and answers what it concluded; it
/// never logs the app in itself, so the caller decides what a session, a 2FA
/// challenge or a cancelled deletion means. Failures are typed:
/// `SocialAuthCancelledException` when the user backs out,
/// `SocialAuthException` with the backend's `code` for a refusal.
abstract class SocialDriver {
  SocialDriver(this.config, {SocialPlatform? platform})
    : platform = platform ?? SocialPlatformExtension.current;

  /// The provider's entry under `social_auth.providers`.
  final Map<String, dynamic> config;

  /// The platform this driver runs its flows for.
  final SocialPlatform platform;

  /// The provider name the backend routes on (`google`, `github`, ...).
  String get name;

  /// Platforms this driver can run a flow on.
  Set<SocialPlatform> get supportedPlatforms;

  /// Whether [platform] (default: the driver's own) is supported.
  bool supportsPlatform([SocialPlatform? platform]) {
    return supportedPlatforms.contains(platform ?? this.platform);
  }

  /// Signs in, or registers, with the provider.
  ///
  /// On the web the provider opens before the first `await`, so call it
  /// straight from the tap handler.
  Future<SocialAuthResult> signIn();

  /// Prepares a connect and returns the call that opens the provider.
  ///
  /// Everything that needs the network before the provider opens (a link
  /// ticket) happens here; the returned call opens the provider before its
  /// first `await`, so on the web it can run from a fresh tap. [proof] is the
  /// step-up field (`{'password': ...}`, `{'code': ...}` or
  /// `{'confirmation_token': ...}`), minted for this one connect; null for a
  /// guest, who sends none. The result carries
  /// [SocialAuthResult.connectedProvider].
  Future<Future<SocialAuthResult> Function()> beginConnect(
    Map<String, String>? proof,
  );

  /// Links the provider to the signed-in account in one go.
  ///
  /// On the web the popup opens after an `await` and is blocked; use
  /// [beginConnect] there.
  Future<SocialAuthResult> connect(Map<String, String>? proof) async {
    final Future<SocialAuthResult> Function() open = await beginConnect(proof);

    return open();
  }

  /// Re-authenticates with an already linked provider for a step-up proof,
  /// carried in [SocialAuthResult.confirmationToken].
  Future<SocialAuthResult> confirm();

  /// Ends the provider SDK's own session, if it keeps one.
  Future<void> signOut() async {}
}

import '../models/social_platform.dart';
import '../models/social_token.dart';
import '../facades/social_auth.dart';

/// Social authentication driver contract.
///
/// All drivers must implement this interface.
///
/// ```dart
/// class AppleDriver extends SocialDriver {
///   @override
///   String get name => 'apple';
///
///   @override
///   Set<SocialPlatform> get supportedPlatforms => {
///     SocialPlatform.ios,
///     SocialPlatform.android,
///     SocialPlatform.web,
///   };
///
///   @override
///   Future<SocialToken> getToken() async {
///     // Implement Apple Sign In
///   }
/// }
/// ```
abstract class SocialDriver {
  /// Driver configuration from config.
  SocialDriver(this.config);

  /// Driver configuration.
  final Map<String, dynamic> config;

  /// Driver name ('google', 'microsoft', 'github', etc.)
  String get name;

  /// Platforms supported by this driver.
  Set<SocialPlatform> get supportedPlatforms;

  /// Check if the current platform is supported.
  bool supportsPlatform([SocialPlatform? platform]) {
    platform ??= SocialPlatformExtension.current;
    return supportedPlatforms.contains(platform);
  }

  /// Get token from the social provider.
  ///
  /// This should:
  /// 1. Open native SDK or OAuth browser flow
  /// 2. Wait for user authentication
  /// 3. Return token and basic profile info
  Future<SocialToken> getToken();

  /// Full authentication flow.
  ///
  /// 1. Get token from provider
  /// 2. Let handler process it (send to backend, etc.)
  Future<void> authenticate() async {
    final token = await getToken();
    await SocialAuth.manager.handleAuth(token);
  }

  /// Sign out from the social provider.
  ///
  /// Default implementation is a no-op. Override in drivers that support
  /// sign out (e.g., Google, Apple).
  Future<void> signOut() async {
    // Default: no-op
  }
}

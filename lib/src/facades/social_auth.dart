import 'package:magic/magic.dart';

import '../social_auth_manager.dart';
import '../contracts/social_driver.dart';

/// Static facade for social authentication.
///
/// Laravel Socialite-style API.
///
/// ```dart
/// // Get driver
/// final driver = SocialAuth.driver('google');
/// await driver.authenticate();
///
/// // Check platform support
/// if (SocialAuth.supports('apple')) {
///   await SocialAuth.driver('apple').authenticate();
/// }
///
/// // Custom driver
/// SocialAuth.manager.extend('linkedin', (config) => LinkedInDriver(config));
/// ```
class SocialAuth {
  SocialAuth._();

  /// Get the manager instance.
  static SocialAuthManager get manager =>
      Magic.make<SocialAuthManager>('social_auth');

  /// Get a driver by name.
  ///
  /// ```dart
  /// await SocialAuth.driver('google').authenticate();
  /// ```
  static SocialDriver driver(String name) => manager.driver(name);

  /// Check if a provider supports the current platform.
  ///
  /// ```dart
  /// if (SocialAuth.supports('apple')) {
  ///   // Show Apple Sign In button
  /// }
  /// ```
  static bool supports(String name) {
    try {
      return driver(name).supportsPlatform();
    } catch (_) {
      return false;
    }
  }

  /// Sign out from all social providers.
  ///
  /// Clears cached credentials and driver instances.
  /// Next authentication will show fresh login prompts.
  ///
  /// ```dart
  /// await SocialAuth.signOut();
  /// ```
  static Future<void> signOut() => manager.signOut();
}

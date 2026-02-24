import 'package:magic/magic.dart';

import 'contracts/social_driver.dart';
import 'contracts/social_auth_handler.dart';
import 'drivers/google_driver.dart';
import 'drivers/microsoft_driver.dart';
import 'drivers/github_driver.dart';
import 'models/social_token.dart';
import 'exceptions/social_auth_exception.dart';
import 'ui/social_provider_icons.dart';

/// Manages social authentication drivers.
///
/// Follows the same pattern as Magic's AuthManager.
///
/// ```dart
/// // Get a driver
/// final driver = SocialAuth.driver('google');
///
/// // Register custom driver
/// SocialAuth.manager.extend('apple', (config) => AppleDriver(config));
///
/// // Set custom handler
/// SocialAuth.manager.setHandler(FirebaseAuthHandler());
/// ```
class SocialAuthManager {
  /// Singleton instance.
  static final SocialAuthManager _instance = SocialAuthManager._internal();

  /// Factory constructor returning singleton.
  factory SocialAuthManager() => _instance;

  SocialAuthManager._internal();

  /// Custom driver factories.
  final Map<String, SocialDriver Function(Map<String, dynamic>)> _factories =
      {};

  /// Resolved driver instances.
  final Map<String, SocialDriver> _drivers = {};

  /// Auth handler (customizable).
  SocialAuthHandler _handler = HttpSocialAuthHandler();

  // ---------------------------------------------------------------------------
  // Driver Methods
  // ---------------------------------------------------------------------------

  /// Get a driver by name.
  ///
  /// ```dart
  /// final google = SocialAuth.driver('google');
  /// await google.authenticate();
  /// ```
  SocialDriver driver(String name) {
    if (_drivers.containsKey(name)) {
      return _drivers[name]!;
    }
    return _drivers[name] = _resolve(name);
  }

  /// Register a custom driver.
  ///
  /// ```dart
  /// SocialAuth.manager.extend('apple', (config) => AppleDriver(config));
  /// ```
  void extend(
    String name,
    SocialDriver Function(Map<String, dynamic>) factory,
  ) {
    _factories[name] = factory;
    // Clear cached instance if exists
    _drivers.remove(name);
  }

  // ---------------------------------------------------------------------------
  // Handler Methods
  // ---------------------------------------------------------------------------

  /// Set custom auth handler.
  ///
  /// ```dart
  /// SocialAuth.manager.setHandler(FirebaseAuthHandler());
  /// ```
  void setHandler(SocialAuthHandler handler) => _handler = handler;

  /// Handle authentication (called by drivers).
  Future<void> handleAuth(SocialToken token) => _handler.handle(token);

  // ---------------------------------------------------------------------------
  // User Factory (delegates to Auth)
  // ---------------------------------------------------------------------------

  /// Create user from response data.
  ///
  /// Delegates to [Auth.manager.createUser] which uses the app's
  /// registered user factory. No separate configuration needed.
  Authenticatable createUser(Map<String, dynamic> data) {
    return Auth.manager.createUser(data);
  }

  // ---------------------------------------------------------------------------
  // Private Methods
  // ---------------------------------------------------------------------------

  /// Resolve driver by name.
  SocialDriver _resolve(String name) {
    final config = _getConfig(name);

    // Check if provider is enabled
    final enabled = config['enabled'] as bool? ?? true;
    if (!enabled) {
      throw ProviderNotConfiguredException(name);
    }

    // Check for custom driver first
    if (_factories.containsKey(name)) {
      return _factories[name]!(config);
    }

    // Built-in drivers
    return switch (name) {
      'google' => GoogleDriver(config),
      'microsoft' => MicrosoftDriver(config),
      'github' => GithubDriver(config),
      _ => throw ArgumentError('Unknown social driver: $name'),
    };
  }

  /// Get config for a provider.
  Map<String, dynamic> _getConfig(String name) {
    return Config.get<Map<String, dynamic>>('social_auth.providers.$name') ??
        {};
  }

  /// Register UI metadata for a custom social auth provider.
  ///
  /// Use alongside [extend] when adding custom drivers so the
  /// [SocialAuthButtons] widget can render the provider automatically.
  ///
  /// ```dart
  /// SocialAuth.manager.registerProviderDefaults('apple', SocialProviderDefaults(
  ///   label: 'Apple',
  ///   iconSvg: '<svg>...</svg>',
  ///   order: 4,
  /// ));
  /// ```
  void registerProviderDefaults(
    String provider,
    SocialProviderDefaults defaults,
  ) {
    SocialProviderIcons.register(provider, defaults);
  }

  /// Reset all drivers (for testing).
  void forgetDrivers() {
    _drivers.clear();
  }

  /// Sign out from all social providers.
  ///
  /// Calls signOut() on all cached driver instances, then clears the cache.
  /// This ensures fresh login prompts on next authentication attempt.
  ///
  /// ```dart
  /// await SocialAuth.signOut();
  /// ```
  Future<void> signOut() async {
    // Call signOut on all cached drivers
    for (final driver in _drivers.values) {
      await driver.signOut();
    }

    // Clear the driver cache
    _drivers.clear();
  }
}

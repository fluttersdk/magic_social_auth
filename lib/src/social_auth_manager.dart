import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:magic/magic.dart';

import 'contracts/social_driver.dart';
import 'drivers/apple_driver.dart';
import 'drivers/google_driver.dart';
import 'drivers/redirect_driver.dart';
import 'exceptions/social_auth_exception.dart';
import 'models/social_platform.dart';
import 'ui/social_provider_icons.dart';

/// Manages social authentication drivers.
///
/// Follows the same pattern as Magic's AuthManager. Google, Apple, GitHub and
/// Microsoft resolve out of the box, each to the driver that runs on the
/// current platform: the native SDK for Google on iOS and Android and for
/// Apple on iOS, the backend's browser flow everywhere else.
///
/// ```dart
/// final SocialAuthResult result = await SocialAuth.driver('google').signIn();
///
/// SocialAuth.manager.extend('gitlab', (config) => RedirectDriver('gitlab', config));
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

  /// Forces the platform built-in drivers are resolved for; null reads the
  /// running one.
  @visibleForTesting
  SocialPlatform? platformOverride;

  /// The platform built-in drivers are resolved for.
  SocialPlatform get platform =>
      platformOverride ?? SocialPlatformExtension.current;

  // ---------------------------------------------------------------------------
  // Driver Methods
  // ---------------------------------------------------------------------------

  /// Get a driver by name.
  ///
  /// ```dart
  /// final SocialAuthResult result = await SocialAuth.driver('google').signIn();
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
  /// SocialAuth.manager.extend('gitlab', (config) => RedirectDriver('gitlab', config));
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
    final SocialPlatform platform = this.platform;

    return switch (name) {
      'google' when platform != SocialPlatform.web => GoogleDriver(
        config,
        platform: platform,
      ),
      'apple' when platform == SocialPlatform.ios => AppleDriver(
        config,
        platform: platform,
      ),
      'google' ||
      'apple' ||
      'github' ||
      'microsoft' => RedirectDriver(name, config, platform: platform),
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
  /// SocialAuth.manager.registerProviderDefaults('gitlab', SocialProviderDefaults(
  ///   label: 'GitLab',
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
  /// Calls signOut() on all cached driver instances (Google signs its SDK
  /// out), then clears the cache, so the next sign-in shows a fresh prompt.
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

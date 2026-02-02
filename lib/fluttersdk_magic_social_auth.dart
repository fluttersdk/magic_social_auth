/// Social authentication plugin for Magic Framework.
///
/// Laravel Socialite-style API with extensible drivers.
///
/// ```dart
/// // Basic usage
/// await SocialAuth.driver('google').authenticate();
///
/// // Custom driver
/// SocialAuth.manager.extend('apple', (config) => AppleDriver(config));
///
/// // Custom auth handler
/// SocialAuth.manager.setHandler(FirebaseAuthHandler());
/// ```
library;

// Contracts
export 'src/contracts/social_driver.dart';
export 'src/contracts/social_auth_handler.dart';

// Models
export 'src/models/social_token.dart';
export 'src/models/social_platform.dart';

// Exceptions
export 'src/exceptions/social_auth_exception.dart';

// Drivers
export 'src/drivers/google_driver.dart';
export 'src/drivers/microsoft_driver.dart';
export 'src/drivers/github_driver.dart';

// Core
export 'src/social_auth_manager.dart';
export 'src/facades/social_auth.dart';
export 'src/providers/social_auth_service_provider.dart';

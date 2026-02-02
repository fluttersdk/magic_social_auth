import 'package:fluttersdk_magic/fluttersdk_magic.dart';

import '../social_auth_manager.dart';

/// Service provider for social authentication.
///
/// Register in your app's kernel:
///
/// ```dart
/// (app) => SocialAuthServiceProvider(app),
/// ```
class SocialAuthServiceProvider extends ServiceProvider {
  SocialAuthServiceProvider(super.app);

  @override
  void register() {
    // Register manager singleton
    app.singleton('social_auth', () => SocialAuthManager());
  }

  @override
  Future<void> boot() async {
    // Social auth manager uses the app's user factory via Auth.manager.createUser()
    // No additional configuration needed - user creation is handled automatically
  }
}

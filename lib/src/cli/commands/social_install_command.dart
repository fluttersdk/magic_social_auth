import 'package:fluttersdk_artisan/artisan.dart';

/// Scaffold command for magic_social_auth configuration files.
///
/// V1 stub: prints a notice and returns 0. Full install logic (config/social_auth.dart
/// creation, .env key injection, SocialAuthServiceProvider wiring) ships in V1.x.
class SocialInstallCommand extends ArtisanCommand {
  @override
  String get name => 'social:install';

  @override
  String get description =>
      'Scaffold the magic_social_auth configuration files and inject SocialAuthServiceProvider into appConfig.';

  @override
  CommandBoot get boot => CommandBoot.none;

  @override
  Future<int> handle(ArtisanContext ctx) async {
    // 1. Create lib/config/social_auth.dart (if absent).
    // 2. Append placeholder keys to .env (SOCIAL_AUTH_GOOGLE_CLIENT_ID, etc.) if not present.
    // 3. Inject SocialAuthServiceProvider into appConfig['app']['providers'] via ConfigEditor (from artisan helpers).
    ctx.output.writeln(
      'social:install — stub V1: configure manually via doc/getting-started/.',
    );
    return 0;
  }
}

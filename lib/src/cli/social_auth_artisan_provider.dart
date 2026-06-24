import 'package:fluttersdk_artisan/artisan.dart';

import 'commands/social_install_command.dart';

/// Contributes social:* commands to the artisan dispatcher.
///
/// Host integration:
/// ```dart
/// // lib/config/app.dart
/// final appConfig = {
///   'artisan': {
///     'providers': [MagicSocialAuthArtisanProvider.new],
///   },
/// };
/// ```
///
/// V1 ships 1 command: social:install. Full install logic deferred to V1.x.
class MagicSocialAuthArtisanProvider extends ArtisanServiceProvider {
  @override
  String get providerName => 'magic_social_auth';

  @override
  List<ArtisanCommand> commands() => <ArtisanCommand>[SocialInstallCommand()];
}

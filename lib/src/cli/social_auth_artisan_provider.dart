import 'package:fluttersdk_artisan/artisan.dart';

import 'commands/social_doctor_command.dart';
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
/// Ships `social:install` (config, native files and the starter bridge) and
/// `social:doctor` (checks them and prints the backend env to set).
class MagicSocialAuthArtisanProvider extends ArtisanServiceProvider {
  @override
  String get providerName => 'magic_social_auth';

  @override
  List<ArtisanCommand> commands() => <ArtisanCommand>[
    SocialInstallCommand(),
    SocialDoctorCommand(),
  ];
}

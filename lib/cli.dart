/// Flutter-free artisan-CLI surface for magic_social_auth.
///
/// Exposes ONLY the artisan-CLI surface ([MagicSocialAuthArtisanProvider]).
/// Does NOT export any Flutter runtime symbols (no `dart:ui` imports), so this
/// barrel is safe for consumption from pure-Dart artisan dispatchers.
///
/// Consumers register the provider in their `bin/artisan.dart`:
///
/// ```dart
/// import 'package:fluttersdk_artisan/artisan.dart';
/// import 'package:magic_social_auth/cli.dart' show MagicSocialAuthArtisanProvider;
///
/// Future<void> main(List<String> args) async {
///   final registry = ArtisanRegistry()
///     ..registerProvider(MagicSocialAuthArtisanProvider());
///   exit(await ArtisanApplication(registry: registry).dispatch(args));
/// }
/// ```
///
/// Runtime consumers (lib/main.dart of a Magic-based app) continue to import
/// `package:magic_social_auth/magic_social_auth.dart` for the full surface.
library;

export 'src/cli/social_auth_artisan_provider.dart';

import 'dart:io';
import 'dart:isolate';

import 'package:fluttersdk_artisan/artisan.dart';

/// Installs magic_social_auth into a Magic Flutter project.
///
/// Reads the bundled install.yaml manifest and delegates to
/// [ManifestInstaller] which injects [SocialAuthServiceProvider] into the
/// consumer's lib/config/app.dart providers list. No config stubs are
/// published: provider OAuth credentials are scaffolded on demand via
/// `dart run artisan social:install --providers=google,apple`.
///
/// Usage:
/// ```bash
/// dart run artisan social:install
/// dart run artisan social:install --force --non-interactive
/// dart run artisan social:install --dry-run
/// ```
class SocialInstallCommand extends ArtisanInstallCommand {
  @override
  String get signature => 'social:install $baseFlags';

  @override
  String get description =>
      'Inject SocialAuthServiceProvider into app.dart via the install.yaml manifest.';

  @override
  String pluginName(ArtisanContext ctx) => 'magic_social_auth';

  /// Resolves the absolute path to the bundled install.yaml manifest.
  ///
  /// Uses [Isolate.resolvePackageUri] so it works regardless of whether the
  /// package is consumed from pub.dev or a local path override. Returns null
  /// when the manifest cannot be located so [handle] surfaces a clean error.
  ///
  /// @return Absolute path to install.yaml, or null when not found.
  Future<String?> resolveManifestPath() async {
    final resolved = await Isolate.resolvePackageUri(
      Uri.parse('package:magic_social_auth/magic_social_auth.dart'),
    );
    if (resolved == null || resolved.scheme != 'file') return null;

    // resolved -> <plugin_root>/lib/magic_social_auth.dart. Resolving '../'
    // against that file URI drops the barrel filename and the lib/ segment,
    // landing on the package root where install.yaml lives. Resolving against
    // the URI keeps separators and normalization correct across platforms
    // instead of concatenating with a literal '/'.
    final pluginRootUri = resolved.resolve('../');
    final manifestUri = pluginRootUri.resolve('install.yaml');
    final manifestFile = File.fromUri(manifestUri);
    return manifestFile.existsSync() ? manifestFile.path : null;
  }

  @override
  Future<int> handle(ArtisanContext ctx) async {
    // 1. Locate the install.yaml bundled with this package.
    final manifestPath = await resolveManifestPath();
    if (manifestPath == null) {
      ctx.output.error(
        'magic_social_auth install.yaml could not be resolved. '
        'The package asset bundle is missing or loaded from an unexpected location.',
      );
      return 1;
    }

    // 2. Guard: manifest must be readable before attempting parse.
    if (!File(manifestPath).existsSync()) {
      ctx.output.error(
        'install.yaml not found at $manifestPath.',
      );
      return 1;
    }

    // 3. Parse the manifest; surface validation errors cleanly.
    final InstallManifest manifest;
    try {
      manifest = ManifestParser.parseFile(manifestPath);
    } on FormatException catch (e) {
      ctx.output.error('install.yaml at $manifestPath: $e');
      return 1;
    } on ManifestValidationException catch (e) {
      ctx.output.error('install.yaml at $manifestPath: ${e.message}');
      return 1;
    }

    // 4. Build the install context (overridable in tests via buildContext).
    final installContext = buildContext(ctx);

    // 5. Prepare the manifest installer and stage the always-on ops.
    //    magic_social_auth has no stubs to publish and no prompts; the
    //    manifest's magic.provider section is the only staged op.
    final installer = ManifestInstaller(
      installContext,
      manifest,
      promptOverrides: const <String, String>{},
    );
    final staged = installer.prepare(
      nonInteractive: isNonInteractive(ctx),
    );

    // 6. Commit the staged ops.
    final result = await staged.commit(
      dryRun: isDryRun(ctx),
      force: isForce(ctx),
    );

    return _renderResult(ctx, result);
  }

  /// Maps a [TransactionResult] to an exit code and emits the appropriate
  /// output line.
  ///
  /// @param ctx     The active [ArtisanContext] for output.
  /// @param result  The [TransactionResult] from [PluginInstaller.commit].
  /// @return 0 on [Success] or [DryRun]; 1 on [Conflict] or [Error].
  int _renderResult(ArtisanContext ctx, TransactionResult result) {
    return switch (result) {
      Success(:final opCount) => () {
          ctx.output.success(
            'magic_social_auth installed ($opCount op${opCount == 1 ? '' : 's'}).',
          );
          return 0;
        }(),
      DryRun(:final opCount) => () {
          ctx.output.info(
            '[dry-run] $opCount op${opCount == 1 ? '' : 's'} staged; no files written.',
          );
          return 0;
        }(),
      Conflict(:final conflicts) => () {
          final paths = conflicts.map((c) => c.absPath).join(', ');
          ctx.output.error(
            'Conflict on $paths. Re-run with --force to overwrite.',
          );
          return 1;
        }(),
      Error(:final error) => () {
          ctx.output.error('Install failed: $error');
          return 1;
        }(),
    };
  }
}

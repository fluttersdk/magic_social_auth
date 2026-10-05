import 'dart:io';
import 'dart:isolate';

import 'package:fluttersdk_artisan/artisan.dart';

/// Installs magic_social_auth into a Magic Flutter project.
///
/// The bundled install.yaml registers `SocialAuthServiceProvider`; the flags
/// decide the rest, so one non-interactive run leaves the app ready to sign in:
/// the published `lib/config/social_auth.dart` and its config factory, the iOS
/// Google keys, URL scheme and Sign in with Apple entitlement, the Android
/// callback activity, `web/auth.html`, and, when the app lists `magic_starter`,
/// the bridge that plugs this package into the starter's screens. Run
/// `social:doctor` afterwards to check the result.
///
/// Usage:
/// ```bash
/// dart run artisan social:install \
///   --providers=google,apple,github,microsoft \
///   --google-ios-client-id=123-abc.apps.googleusercontent.com \
///   --google-server-client-id=123-def.apps.googleusercontent.com \
///   --ios-scheme=myapp \
///   --android-callback=https://auth.example.com/auth/social
/// dart run artisan social:install --dry-run
/// ```
class SocialInstallCommand extends ArtisanInstallCommand {
  /// The providers the package resolves, in the order the config lists them.
  static const List<String> providerNames = <String>[
    'google',
    'apple',
    'github',
    'microsoft',
  ];

  /// Project-relative path of the published config.
  static const String configPath = 'lib/config/social_auth.dart';

  /// The config's factory, as `Magic.init` lists it.
  static const String configFactory = 'socialAuthConfig';

  /// Project-relative path of the published starter bridge.
  static const String bridgePath =
      'lib/app/providers/social_auth_starter_service_provider.dart';

  /// The provider class the bridge stub declares.
  static const String bridgeProvider = 'SocialAuthStarterServiceProvider';

  /// Project-relative path of the page flutter_web_auth_2 posts back through.
  static const String authPagePath = 'web/auth.html';

  /// The activity flutter_web_auth_2 returns an Android callback to.
  static const String callbackActivity =
      'com.linusu.flutter_web_auth_2.CallbackActivity';

  /// The entitlement Sign in with Apple needs on iOS.
  static const String appleSignInEntitlement =
      'com.apple.developer.applesignin';

  static const String _googleClientIdSuffix = '.apps.googleusercontent.com';

  static final RegExp _googleClientId = RegExp(
    r'^[A-Za-z0-9-]+\.apps\.googleusercontent\.com$',
  );

  static final RegExp _urlScheme = RegExp(r'^[A-Za-z][A-Za-z0-9+.-]*$');

  /// The URL scheme the Google SDK listens on for [clientId]: the client id
  /// with its domain parts reversed (`com.googleusercontent.apps.123-abc`).
  static String reversedClientId(String clientId) {
    return 'com.googleusercontent.apps.'
        '${clientId.replaceFirst(_googleClientIdSuffix, '')}';
  }

  /// Parses an Android App Link callback, or null when [value] is not an https
  /// URL with a host and a path to match.
  static Uri? parseAppLink(String value) {
    final Uri? uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.path.length < 2 ||
        uri.hasQuery ||
        uri.hasFragment) {
      return null;
    }

    return uri;
  }

  /// Whether a pubspec's dependencies list [package].
  static bool listsDependency(String pubspec, String package) {
    return RegExp('^\\s+$package\\s*:', multiLine: true).hasMatch(pubspec);
  }

  @override
  String get signature =>
      'social:install $baseFlags'
      '{--providers= : Comma-separated providers to enable (google, apple, github, microsoft).} '
      '{--google-ios-client-id= : Google iOS OAuth client id (123-abc.apps.googleusercontent.com).} '
      '{--google-server-client-id= : Google web OAuth client id, the audience the backend verifies.} '
      '{--ios-scheme= : Custom URL scheme the browser flow returns to on iOS (myapp).} '
      '{--android-callback= : https App Link the browser flow returns to on Android (https://host/path).}';

  @override
  String get description =>
      'Install magic_social_auth: config, providers, native iOS/Android/web files and the magic_starter bridge.';

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
      ctx.output.error('install.yaml not found at $manifestPath.');
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

    // 4. Read the flags before anything is staged: they end up inside generated
    //    Dart and XML, so a bad one must stop the run, not the build.
    final _InstallOptions options;
    try {
      options = _InstallOptions.read(ctx.input);
    } on FormatException catch (e) {
      ctx.output.error(e.message);
      return 1;
    }

    // 5. Stage the manifest's ops (the provider), then the flag-driven ones on
    //    the same installer so one transaction commits, or previews, them all.
    final installContext = buildContext(ctx);
    final installer = ManifestInstaller(
      installContext,
      manifest,
      promptOverrides: const <String, String>{},
    ).prepare(nonInteractive: isNonInteractive(ctx));
    _InstallPlan(
      installer: installer,
      context: installContext,
      options: options,
      stubsDir: '${File(manifestPath).parent.path}/assets/stubs',
    ).stage();

    // 6. Commit the staged ops.
    final result = await installer.commit(
      dryRun: isDryRun(ctx),
      force: isForce(ctx),
    );

    final int exitCode = _renderResult(ctx, result);
    final String? message = manifest.postInstall.message;
    if (result is Success && message != null) ctx.output.info(message);

    return exitCode;
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

/// The validated flags of one `social:install` run.
class _InstallOptions {
  _InstallOptions({
    required this.providers,
    this.googleIosClientId,
    this.googleServerClientId,
    this.iosScheme,
    this.androidCallback,
  });

  /// Reads and validates the flags of [input].
  ///
  /// Throws a [FormatException] naming the first flag that is not usable.
  factory _InstallOptions.read(ArtisanInput input) {
    String? flag(String name) {
      final Object? value = input.option(name);

      return value is String && value.isNotEmpty ? value : null;
    }

    final List<String> providers =
        flag('providers')?.split(',').map((name) => name.trim()).toList() ??
        SocialInstallCommand.providerNames;
    for (final String provider in providers) {
      if (!SocialInstallCommand.providerNames.contains(provider)) {
        throw FormatException(
          '--providers: unknown provider "$provider"; choose from '
          '${SocialInstallCommand.providerNames.join(', ')}.',
        );
      }
    }

    String? clientId(String name) {
      final String? value = flag(name);
      if (value != null &&
          !SocialInstallCommand._googleClientId.hasMatch(value)) {
        throw FormatException(
          '--$name: "$value" is not a Google client id '
          '(123-abc.apps.googleusercontent.com).',
        );
      }

      return value;
    }

    final String? scheme = flag('ios-scheme');
    if (scheme != null && !SocialInstallCommand._urlScheme.hasMatch(scheme)) {
      throw FormatException('--ios-scheme: "$scheme" is not a URL scheme.');
    }

    final String? callback = flag('android-callback');
    final Uri? appLink = callback == null
        ? null
        : SocialInstallCommand.parseAppLink(callback);
    if (callback != null && appLink == null) {
      throw FormatException(
        '--android-callback: "$callback" is not an https URL with a host and '
        'a path (https://auth.example.com/auth/social).',
      );
    }

    return _InstallOptions(
      providers: providers.toSet(),
      googleIosClientId: clientId('google-ios-client-id'),
      googleServerClientId: clientId('google-server-client-id'),
      iosScheme: scheme,
      androidCallback: appLink,
    );
  }

  final Set<String> providers;
  final String? googleIosClientId;
  final String? googleServerClientId;
  final String? iosScheme;
  final Uri? androidCallback;
}

/// Stages the ops that depend on the flags and on what the project holds.
class _InstallPlan {
  _InstallPlan({
    required this.installer,
    required this.context,
    required this.options,
    required this.stubsDir,
  });

  final PluginInstaller installer;
  final InstallContext context;
  final _InstallOptions options;

  /// The package's `assets/stubs`, which the substrate's default search path
  /// does not cover.
  final String stubsDir;

  void stage() {
    _stageConfig();
    _stageIos();
    _stageAndroid();
    _stageWeb();
    _stageStarterBridge();
  }

  /// Publishes the config and registers its factory with `Magic.init`.
  void _stageConfig() {
    bool enabled(String provider) => options.providers.contains(provider);
    final String? scheme = options.iosScheme;

    installer
        .writeFile(
          targetPath: SocialInstallCommand.configPath,
          content: _render('social_auth_config', <String, String>{
            'google_enabled': '${enabled('google')}',
            'google_ios_client_id': options.googleIosClientId ?? '',
            'google_server_client_id': options.googleServerClientId ?? '',
            'apple_enabled': '${enabled('apple')}',
            'github_enabled': '${enabled('github')}',
            'microsoft_enabled': '${enabled('microsoft')}',
            'ios_callback': scheme == null ? '' : '$scheme://auth/social',
            'android_callback': options.androidCallback?.toString() ?? '',
          }),
        )
        .injectConfigFactory(
          SocialInstallCommand.configFactory,
          package: 'config/social_auth.dart',
        );
  }

  /// The Google SDK reads its client ids and listens on the reversed client id
  /// scheme; Sign in with Apple needs its entitlement in every file the app
  /// target signs with.
  void _stageIos() {
    final String? iosClientId = options.googleIosClientId;
    final String? serverClientId = options.googleServerClientId;

    if (options.providers.contains('google')) {
      if (iosClientId != null) {
        installer
            .injectInfoPlistKey(key: 'GIDClientID', value: iosClientId)
            .injectInfoPlistUrlScheme(
              scheme: SocialInstallCommand.reversedClientId(iosClientId),
            );
      }
      if (serverClientId != null) {
        installer.injectInfoPlistKey(
          key: 'GIDServerClientID',
          value: serverClientId,
        );
      }
    }

    if (options.providers.contains('apple')) {
      installer.injectEntitlement(
        platform: 'ios',
        key: SocialInstallCommand.appleSignInEntitlement,
        value: const <String>['Default'],
      );
    }
  }

  /// Declares the activity the browser flow returns to. Only the intent
  /// filters decide whether an existing activity is left alone, and one that
  /// differs is reported, never rewritten.
  void _stageAndroid() {
    final Uri? callback = options.androidCallback;
    if (callback == null) return;

    installer.injectAndroidActivity(
      name: SocialInstallCommand.callbackActivity,
      exported: true,
      taskAffinity: '',
      intentFilters: <AndroidIntentFilter>[
        AndroidIntentFilter(
          autoVerify: true,
          actions: const <String>['android.intent.action.VIEW'],
          categories: const <String>[
            'android.intent.category.DEFAULT',
            'android.intent.category.BROWSABLE',
          ],
          data: <AndroidIntentData>[
            AndroidIntentData(
              scheme: 'https',
              host: callback.host,
              path: callback.path,
            ),
          ],
        ),
      ],
    );
  }

  /// A write would create `web/` in an app that has no web target.
  void _stageWeb() {
    if (!PlatformHelper.hasPlatform(context.projectRoot, 'web')) return;

    installer.writeFile(
      targetPath: SocialInstallCommand.authPagePath,
      content: _render('auth.html'),
    );
  }

  /// The bridge implements a contract of magic_starter, so it is published into
  /// the app, which is the one place that depends on both packages.
  void _stageStarterBridge() {
    final String pubspecPath = '${context.projectRoot}/pubspec.yaml';
    if (!context.fs.exists(pubspecPath) ||
        !SocialInstallCommand.listsDependency(
          context.fs.readAsString(pubspecPath),
          'magic_starter',
        )) {
      return;
    }

    installer
        .writeFile(
          targetPath: SocialInstallCommand.bridgePath,
          content: _render('social_auth_starter_service_provider'),
        )
        .injectProvider(
          SocialInstallCommand.bridgeProvider,
          package: '../app/providers/social_auth_starter_service_provider.dart',
        );
  }

  String _render(
    String stub, [
    Map<String, String> replacements = const <String, String>{},
  ]) {
    return context.stubs.replace(
      context.stubs.load('install/$stub', searchPaths: <String>[stubsDir]),
      replacements,
    );
  }
}

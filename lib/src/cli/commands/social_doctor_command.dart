import 'dart:io';

import 'package:fluttersdk_artisan/artisan.dart';

import 'social_install_command.dart';

/// `social:doctor`, checks what `social:install` set up against the project's
/// own files and prints the backend values to match.
///
/// Every way of getting the native half wrong is silent: a sign-in sheet that
/// closes at once, a button that does nothing, a review rejection months
/// later. This command reads the config, `Info.plist`, the entitlements files
/// the app target signs with, `AndroidManifest.xml`, `web/` and the pubspec,
/// and names what is missing before a device is involved. A section appears
/// only when the project has that platform.
///
/// It cannot prove an Android App Link verifies (Google fetches
/// `assetlinks.json` at install time) or that a provider console lists the
/// callback; those stay a device and a console check.
///
/// ```bash
/// dart run <app>:artisan social:doctor
/// ```
class SocialDoctorCommand extends ArtisanCommand {
  @override
  String get signature => 'social:doctor';

  @override
  String get description =>
      'Check the social login config, native setup and starter bridge; print the backend env to set.';

  @override
  CommandBoot get boot => CommandBoot.none;

  /// Resolves the Flutter project root; overridable in tests.
  String getProjectRoot() => FileHelper.findProjectRoot();

  @override
  Future<int> handle(ArtisanContext ctx) async {
    final _Inspection inspection = _Inspection(getProjectRoot());

    // 1. Without the config nothing else can be judged.
    final List<(String, List<String>)> sections = <(String, List<String>)>[
      ('Config', inspection.checkConfig()),
    ];
    if (inspection.config != null) {
      sections.addAll(<(String, List<String>)>[
        if (inspection.hasPlatform('ios')) ('iOS', inspection.checkIos()),
        if (inspection.hasPlatform('android'))
          ('Android', inspection.checkAndroid()),
        if (inspection.hasPlatform('web')) ('Web', inspection.checkWeb()),
        if (inspection.dependsOn('magic_starter'))
          ('magic_starter bridge', inspection.checkBridge()),
      ]);
    }

    // 2. One block per section; the exit code follows the issue count.
    ctx.output.writeln('magic_social_auth doctor');
    int issues = 0;
    for (final (String title, List<String> found) in sections) {
      ctx.output.writeln('');
      ctx.output.writeln(title);
      if (found.isEmpty) ctx.output.writeln('  ok');
      for (final String issue in found) {
        ctx.output.writeln('  - $issue');
      }
      issues += found.length;
    }

    // 3. The values the backend has to agree with, whatever the verdict.
    if (inspection.config != null) {
      ctx.output.writeln('');
      ctx.output.writeln('Backend env (magic-starter-laravel)');
      for (final String line in inspection.backendEnv()) {
        ctx.output.writeln('  $line');
      }
    }

    ctx.output.writeln('');
    if (issues == 0) {
      ctx.output.success('All checks passed.');
      return 0;
    }

    ctx.output.warning(
      '$issues issue${issues == 1 ? '' : 's'} found. '
      'Re-run social:install with the flags, or fix them by hand.',
    );
    return 1;
  }
}

/// A social login config read back from `lib/config/social_auth.dart`.
class _SocialConfig {
  _SocialConfig({
    required this.enabled,
    required this.googleIosClientId,
    required this.googleServerClientId,
    required this.iosCallback,
    required this.androidCallback,
  });

  /// Reads the file the install stub renders. The scan is textual, like the
  /// stub: provider entries and `callback` are flat maps of literals.
  factory _SocialConfig.parse(String source) {
    final String code = source.replaceAll(
      RegExp(r'^\s*//.*$', multiLine: true),
      '',
    );
    final Map<String, String> blocks = <String, String>{
      for (final RegExpMatch match in RegExp(
        r"'(\w+)'\s*:\s*\{([^{}]*)\}",
      ).allMatches(code))
        match.group(1)!: match.group(2)!,
    };

    String literal(String? block, String key) {
      if (block == null) return '';

      return RegExp("'$key'\\s*:\\s*'([^']*)'").firstMatch(block)?.group(1) ??
          '';
    }

    return _SocialConfig(
      enabled: <String, bool>{
        for (final MapEntry<String, String> block in blocks.entries)
          if (block.key != 'callback')
            block.key:
                RegExp(
                  r"'enabled'\s*:\s*(true|false)",
                ).firstMatch(block.value)?.group(1) !=
                'false',
      },
      googleIosClientId: literal(blocks['google'], 'ios_client_id'),
      googleServerClientId: literal(blocks['google'], 'server_client_id'),
      iosCallback: literal(blocks['callback'], 'ios'),
      androidCallback: literal(blocks['callback'], 'android'),
    );
  }

  /// Provider name to its `enabled` flag, in the order the file lists them.
  final Map<String, bool> enabled;
  final String googleIosClientId;
  final String googleServerClientId;
  final String iosCallback;
  final String androidCallback;

  /// The enabled providers, in file order.
  List<String> get providers => <String>[
    for (final MapEntry<String, bool> entry in enabled.entries)
      if (entry.value) entry.key,
  ];

  bool isEnabled(String provider) => enabled[provider] ?? false;
}

/// One `<intent-filter>` of an Android activity.
class _IntentFilter {
  _IntentFilter(this.autoVerify, this.actions, this.categories, this.data);

  final bool autoVerify;
  final List<String> actions;
  final List<String> categories;

  /// One attribute map per `<data>` element, keyed by the local `android:` name.
  final List<Map<String, String>> data;

  Set<String> _values(String attribute) => <String>{
    for (final Map<String, String> element in data) ?element[attribute],
  };

  /// Whether this filter lets an https App Link at [link] open its activity.
  ///
  /// Android merges every `<data>` of a filter, so schemes, hosts and paths
  /// are matched as sets. A filter with no host matches every host, and one
  /// with no path attribute matches every path of its host. A path pattern is
  /// not evaluated: it counts as not claiming, so a correct project is never
  /// failed on a pattern this scan cannot read.
  bool claims(Uri link) {
    if (!actions.contains('android.intent.action.VIEW') ||
        !categories.contains('android.intent.category.BROWSABLE') ||
        !_values('scheme').contains('https')) {
      return false;
    }

    final Set<String> hosts = _values('host');
    final bool hostMatches =
        hosts.isEmpty ||
        hosts.any(
          (host) =>
              host == link.host ||
              (host.startsWith('*.') && link.host.endsWith(host.substring(1))),
        );
    if (!hostMatches) return false;
    if (hosts.isEmpty) return true;

    final Set<String> paths = _values('path');
    final Set<String> prefixes = _values('pathPrefix');
    final bool pathScoped =
        paths.isNotEmpty ||
        prefixes.isNotEmpty ||
        _values('pathPattern').isNotEmpty ||
        _values('pathAdvancedPattern').isNotEmpty ||
        _values('pathSuffix').isNotEmpty;

    return !pathScoped ||
        paths.contains(link.path) ||
        prefixes.any(link.path.startsWith);
  }
}

/// One `<activity>` or `<activity-alias>` of an Android manifest.
class _Activity {
  _Activity(this.name, this.attributes, this.filters);

  final String name;

  /// Local `android:` attribute name to value.
  final Map<String, String> attributes;
  final List<_IntentFilter> filters;
}

/// What one `social:doctor` run reads from the project at [root].
class _Inspection {
  _Inspection(this.root) : config = _readConfig(root);

  final String root;

  /// Null when `lib/config/social_auth.dart` is absent.
  final _SocialConfig? config;

  static const String _apple = 'apple';
  static const String _google = 'google';

  static _SocialConfig? _readConfig(String root) {
    final File file = File('$root/${SocialInstallCommand.configPath}');

    return file.existsSync()
        ? _SocialConfig.parse(file.readAsStringSync())
        : null;
  }

  bool hasPlatform(String platform) =>
      PlatformHelper.hasPlatform(root, platform);

  String? _read(String relative) {
    final File file = File('$root/$relative');

    return file.existsSync() ? file.readAsStringSync() : null;
  }

  /// [_read] without XML comments, so a commented-out element is not config.
  String? _readXml(String relative) {
    return _read(relative)?.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
  }

  bool dependsOn(String package) {
    final String? pubspec = _read('pubspec.yaml');

    return pubspec != null &&
        SocialInstallCommand.listsDependency(pubspec, package);
  }

  /// The browser-flow providers a platform returns through its callback:
  /// Google and Apple sign in natively on iOS, Google natively on Android.
  bool _needsCallback(String platform) {
    final Set<String> native = platform == 'ios'
        ? <String>{_google, _apple}
        : <String>{_google};

    return config!.providers.any((provider) => !native.contains(provider));
  }

  List<String> checkConfig() {
    final _SocialConfig? config = this.config;
    if (config == null) {
      return <String>[
        '${SocialInstallCommand.configPath} not found. Run social:install.',
      ];
    }

    final List<String> issues = <String>[];
    if (config.providers.isEmpty) issues.add('No provider is enabled.');

    if (config.isEnabled(_google)) {
      if (config.googleIosClientId.isEmpty) {
        issues.add('social_auth.providers.google.ios_client_id is empty.');
      }
      if (config.googleServerClientId.isEmpty) {
        issues.add(
          'social_auth.providers.google.server_client_id is empty; the '
          'backend verifies the ID token against it.',
        );
      }
    }

    if (hasPlatform('ios') &&
        _needsCallback('ios') &&
        config.iosCallback.isEmpty) {
      issues.add(
        'social_auth.callback.ios is empty; the browser flow has nowhere to '
        'return to on iOS.',
      );
    }

    if (hasPlatform('android') && _needsCallback('android')) {
      if (config.androidCallback.isEmpty) {
        issues.add(
          'social_auth.callback.android is empty; the browser flow has '
          'nowhere to return to on Android.',
        );
      } else if (SocialInstallCommand.parseAppLink(config.androidCallback) ==
          null) {
        issues.add(
          'social_auth.callback.android must be an https URL with a host and '
          'a path; a custom scheme can be claimed by another app.',
        );
      }
    }

    return issues;
  }

  List<String> checkIos() {
    final _SocialConfig config = this.config!;
    final List<String> issues = <String>[];

    final String? plist = _readXml('ios/Runner/Info.plist');
    if (plist == null) {
      issues.add('ios/Runner/Info.plist not found.');
    } else if (config.isEnabled(_google)) {
      issues.addAll(_checkGoogleKeys(plist, config));
    }

    if (config.isEnabled(_apple)) {
      issues.addAll(_checkAppleEntitlement());
    } else if (config.providers.isNotEmpty) {
      issues.add(
        'Apple is disabled while ${config.providers.join(', ')} '
        '${config.providers.length == 1 ? 'is' : 'are'} enabled. App Store '
        'guideline 4.8 asks an iOS app that offers another third-party '
        'sign-in to offer Sign in with Apple too.',
      );
    }

    return issues;
  }

  /// The Google SDK reads its client ids from `Info.plist` and listens on the
  /// iOS client's reversed id; an empty id is already a config issue.
  List<String> _checkGoogleKeys(String plist, _SocialConfig config) {
    String? key(String name) => RegExp(
      '<key>$name</key>\\s*<string>([^<]*)</string>',
    ).firstMatch(plist)?.group(1);

    final Set<String> schemes = <String>{
      for (final RegExpMatch array in RegExp(
        r'<key>CFBundleURLSchemes</key>\s*<array>(.*?)</array>',
        dotAll: true,
      ).allMatches(plist))
        for (final RegExpMatch scheme in RegExp(
          r'<string>([^<]*)</string>',
        ).allMatches(array.group(1)!))
          scheme.group(1)!,
    };

    return <String>[
      if (config.googleIosClientId.isNotEmpty) ...<String>[
        if (key('GIDClientID') != config.googleIosClientId)
          'ios/Runner/Info.plist has no GIDClientID of '
              '${config.googleIosClientId}.',
        if (!schemes.contains(
          SocialInstallCommand.reversedClientId(config.googleIosClientId),
        ))
          'ios/Runner/Info.plist does not register the URL scheme '
              '${SocialInstallCommand.reversedClientId(config.googleIosClientId)}.',
      ],
      if (config.googleServerClientId.isNotEmpty &&
          key('GIDServerClientID') != config.googleServerClientId)
        'ios/Runner/Info.plist has no GIDServerClientID of '
            '${config.googleServerClientId}.',
    ];
  }

  /// Sign in with Apple must be in every entitlements file the application
  /// target signs with, since a Debug and a Release configuration can name
  /// different ones. `$(SRCROOT)` and `$(PROJECT_DIR)` both mean `ios/` for a
  /// Flutter app; any other build variable is reported, not guessed.
  List<String> _checkAppleEntitlement() {
    const String key = SocialInstallCommand.appleSignInEntitlement;
    final String pbxproj = '$root/ios/Runner.xcodeproj/project.pbxproj';

    final Set<String> signing;
    if (File(pbxproj).existsSync()) {
      try {
        signing = XcodeProjectEditor.entitlementsPaths(pbxproj);
      } on StateError catch (error) {
        return <String>[
          'Could not read which entitlements file the app target signs with: '
              '${error.message}',
        ];
      } on FormatException catch (error) {
        return <String>[
          'Could not read ios/Runner.xcodeproj/project.pbxproj: '
              '${error.message}',
        ];
      }
      if (signing.isEmpty) {
        return <String>[
          'No build configuration of the iOS app target sets '
              'CODE_SIGN_ENTITLEMENTS, so $key is never signed in.',
        ];
      }
    } else {
      signing = <String>{'Runner/Runner.entitlements'};
    }

    final RegExp entry = RegExp(
      '<key>${RegExp.escape(key)}</key>\\s*<array>(.*?)</array>',
      dotAll: true,
    );
    final List<String> issues = <String>[];
    for (final String setting in signing) {
      final String path = setting.replaceFirst(
        RegExp(r'^\$\((SRCROOT|PROJECT_DIR)\)/'),
        '',
      );
      if (path.contains(r'$(')) {
        issues.add(
          'CODE_SIGN_ENTITLEMENTS is $setting; social:doctor cannot resolve '
          'its build variable, so check by hand that it grants $key = Default.',
        );
        continue;
      }

      final String? entitlements = _readXml('ios/$path');
      if (entitlements == null) {
        issues.add('ios/$path not found, but the app target signs with it.');
      } else if (entry
              .firstMatch(entitlements)
              ?.group(1)
              ?.contains('<string>Default</string>') !=
          true) {
        issues.add('ios/$path lacks $key = Default.');
      }
    }

    return issues;
  }

  List<String> checkAndroid() {
    final String? manifest = _readXml(
      'android/app/src/main/AndroidManifest.xml',
    );
    if (manifest == null) return <String>['AndroidManifest.xml not found.'];

    final Uri? callback = SocialInstallCommand.parseAppLink(
      config!.androidCallback,
    );
    if (callback == null) return const <String>[];

    final List<_Activity> activities = _activities(manifest);
    final _Activity? target = activities
        .where(
          (activity) => activity.name == SocialInstallCommand.callbackActivity,
        )
        .firstOrNull;
    if (target == null) {
      return <String>[
        '${SocialInstallCommand.callbackActivity} is not declared in '
            'AndroidManifest.xml.',
      ];
    }

    final List<String> issues = <String>[
      if (target.attributes['exported'] != 'true')
        'The callback activity must be android:exported="true", or the '
            'browser cannot open it.',
      if (target.attributes['taskAffinity'] != '')
        'The callback activity must declare android:taskAffinity="", or the '
            'return opens inside the browser task.',
      if (!target.filters.any(
        (filter) =>
            filter.autoVerify &&
            filter.actions.contains('android.intent.action.VIEW') &&
            filter.categories.contains('android.intent.category.DEFAULT') &&
            filter.categories.contains('android.intent.category.BROWSABLE') &&
            filter.data.any(
              (data) =>
                  data['scheme'] == 'https' &&
                  data['host'] == callback.host &&
                  (data['path'] == callback.path ||
                      (data['pathPrefix']?.isNotEmpty == true &&
                          callback.path.startsWith(data['pathPrefix']!))),
            ),
      ))
        'The callback activity has no autoVerify https filter for $callback.',
    ];

    for (final _Activity activity in activities) {
      if (activity == target ||
          !activity.filters.any((f) => f.claims(callback))) {
        continue;
      }

      issues.add(
        'The App Link filter of ${activity.name} overlaps the callback '
        '$callback, so Android may open ${activity.name} instead of the '
        'callback activity. Put the callback on a host or path it does not '
        'claim.',
      );
    }

    return issues;
  }

  List<_Activity> _activities(String manifest) {
    Map<String, String> attributes(String source) => <String, String>{
      for (final RegExpMatch match in RegExp(
        r'android:(\w+)\s*=\s*"([^"]*)"',
      ).allMatches(source))
        match.group(1)!: match.group(2)!,
    };

    return <_Activity>[
      for (final RegExpMatch activity in RegExp(
        r'<(activity-alias|activity)\b([^>]*?)(?:/>|>(.*?)</\1>)',
        dotAll: true,
      ).allMatches(manifest))
        _Activity(
          attributes(activity.group(2)!)['name'] ?? '',
          attributes(activity.group(2)!),
          <_IntentFilter>[
            for (final RegExpMatch filter in RegExp(
              r'<intent-filter\b([^>]*)>(.*?)</intent-filter>',
              dotAll: true,
            ).allMatches(activity.group(3) ?? ''))
              _IntentFilter(
                attributes(filter.group(1)!)['autoVerify'] == 'true',
                _names(filter.group(2)!, 'action'),
                _names(filter.group(2)!, 'category'),
                <Map<String, String>>[
                  for (final RegExpMatch data in RegExp(
                    r'<data\b([^>]*?)/?>',
                  ).allMatches(filter.group(2)!))
                    attributes(data.group(1)!),
                ],
              ),
          ],
        ),
    ];
  }

  List<String> _names(String filter, String tag) => <String>[
    for (final RegExpMatch match in RegExp(
      '<$tag\\b[^>]*android:name\\s*=\\s*"([^"]*)"',
    ).allMatches(filter))
      match.group(1)!,
  ];

  List<String> checkWeb() {
    final String? page = _read(SocialInstallCommand.authPagePath);
    if (page == null) {
      return <String>[
        '${SocialInstallCommand.authPagePath} not found; the web popup has '
            'no page to post its result back through.',
      ];
    }

    return <String>[
      if (!page.contains('flutter-web-auth-2'))
        '${SocialInstallCommand.authPagePath} does not post the '
            'flutter-web-auth-2 message back to the app.',
    ];
  }

  List<String> checkBridge() {
    final String? providers = _read('lib/config/app.dart');

    return <String>[
      if (!File('$root/${SocialInstallCommand.bridgePath}').existsSync())
        '${SocialInstallCommand.bridgePath} not found; magic_starter offers '
            'no social login without it.',
      if (providers == null)
        'lib/config/app.dart not found.'
      else if (!providers.contains('${SocialInstallCommand.bridgeProvider}('))
        '${SocialInstallCommand.bridgeProvider} is not registered in '
            'lib/config/app.dart.',
    ];
  }

  /// The `.env` lines of magic-starter-laravel that mirror this config, and the
  /// callback each provider console has to list.
  List<String> backendEnv() {
    final _SocialConfig config = this.config!;
    const String bundleId = '<ios bundle id>';

    return <String>[
      'MAGIC_STARTER_SOCIAL_PROVIDERS=${config.providers.join(',')}',
      'MAGIC_STARTER_SOCIAL_IOS_REDIRECT=${config.iosCallback}',
      'MAGIC_STARTER_SOCIAL_ANDROID_REDIRECT=${config.androidCallback}',
      'MAGIC_STARTER_SOCIAL_WEB_REDIRECT=https://<app origin>/auth.html',
      if (config.isEnabled(_google))
        'MAGIC_STARTER_SOCIAL_GOOGLE_AUDIENCES='
            '${<String>[config.googleIosClientId, config.googleServerClientId].where((id) => id.isNotEmpty).join(',')}',
      if (config.isEnabled(_apple)) ...<String>[
        'MAGIC_STARTER_SOCIAL_APPLE_AUDIENCES=$bundleId',
        'MAGIC_STARTER_APPLE_TEAM_ID=',
        'MAGIC_STARTER_APPLE_KEY_ID=',
        'MAGIC_STARTER_APPLE_PRIVATE_KEY=',
        'MAGIC_STARTER_APPLE_BUNDLE_ID=$bundleId',
        'MAGIC_STARTER_APPLE_SERVICES_ID=',
      ],
      for (final String provider in config.providers)
        'https://<api host>/magic-starter/social/$provider/callback',
    ];
  }
}

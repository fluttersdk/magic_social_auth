import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluttersdk_artisan/artisan.dart';
import 'package:magic_social_auth/src/cli/commands/social_install_command.dart';

/// Base flags required by ArtisanInstallCommand for all invocations.
const Map<String, dynamic> _baseFlags = <String, dynamic>{
  'force': false,
  'dry-run': false,
  'non-interactive': true,
  'no-bootstrap': false,
};

/// Every provider-specific flag, set the way a real adopter would.
const Map<String, dynamic> fullInstallFlags = <String, dynamic>{
  'providers': 'google,apple,github,microsoft',
  'google-ios-client-id': '1234567890-iosclient.apps.googleusercontent.com',
  'google-server-client-id': '1234567890-webclient.apps.googleusercontent.com',
  'ios-scheme': 'exampleapp',
  'android-callback': 'https://auth.example.com/auth/social',
};

/// Reversed form of [fullInstallFlags]' iOS client id, the URL scheme the
/// Google SDK listens on.
const String reversedIosClientId =
    'com.googleusercontent.apps.1234567890-iosclient';

/// Builds a bare [ArtisanContext] with the given flag overrides.
ArtisanContext _ctx(Map<String, dynamic> overrides, [BufferedOutput? output]) {
  return ArtisanContext.bare(
    MapInput({..._baseFlags, ...overrides}),
    output ?? BufferedOutput(),
  );
}

/// Test subclass that:
///   1. Pins [resolveManifestPath] to a caller-supplied path (avoids
///      Isolate.resolvePackageUri which is unavailable in flutter test).
///   2. Overrides [buildContext] to wire the real FS with an explicit
///      projectRoot pointing at the caller-supplied tempDir.
class TestableSocialInstallCommand extends SocialInstallCommand {
  TestableSocialInstallCommand({
    required this.manifestPath,
    required this.projectRoot,
  });

  final String manifestPath;
  final String projectRoot;

  @override
  Future<String?> resolveManifestPath() async => manifestPath;

  @override
  InstallContext buildContext(ArtisanContext ctx) =>
      InstallContext.real(ctx, projectRoot: projectRoot);
}

/// The real install.yaml at the package root; flutter test always runs with
/// cwd set to the package root.
String get realManifestPath => '${Directory.current.path}/install.yaml';

/// Runs `social:install` against [root] with [flags] and answers the exit code
/// plus everything the command printed.
Future<({int exitCode, String output})> runInstall(
  Directory root,
  Map<String, dynamic> flags,
) async {
  final BufferedOutput output = BufferedOutput();
  final int exitCode = await TestableSocialInstallCommand(
    manifestPath: realManifestPath,
    projectRoot: root.path,
  ).handle(_ctx(flags, output));

  return (exitCode: exitCode, output: output.content);
}

void _write(Directory root, String relative, String content) {
  File('${root.path}/$relative')
    ..createSync(recursive: true)
    ..writeAsStringSync(content);
}

String read(Directory root, String relative) =>
    File('${root.path}/$relative').readAsStringSync();

const String _emptyPlist = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
</dict>
</plist>
''';

// Debug signs with Runner.entitlements and Release with its twin, the way a
// project with a per-build aps-environment does.
const String _splitPbxproj = r'''// !$*UTF8*$!
{
  archiveVersion = 1;
  objects = {
    1A00000000000000000001 /* Runner */ = {
      isa = PBXNativeTarget;
      buildConfigurationList = 1A00000000000000000002 /* Runner */;
      name = Runner;
      productType = "com.apple.product-type.application";
    };
    1A00000000000000000002 /* Runner */ = {
      isa = XCConfigurationList;
      buildConfigurations = (
        1A00000000000000000003 /* Debug */,
        1A00000000000000000004 /* Release */,
      );
    };
    1A00000000000000000003 /* Debug */ = {
      isa = XCBuildConfiguration;
      buildSettings = {
        CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;
      };
      name = Debug;
    };
    1A00000000000000000004 /* Release */ = {
      isa = XCBuildConfiguration;
      buildSettings = {
        CODE_SIGN_ENTITLEMENTS = Runner/RunnerRelease.entitlements;
      };
      name = Release;
    };
  };
  rootObject = 1A00000000000000000000 /* Project object */;
}
''';

/// A Flutter app manifest whose MainActivity already claims every path of
/// `app.example.com` through a host-wide App Link filter.
const String _manifestWithHostWideAppLink =
    '''<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:label="Example"
        android:name="\${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:taskAffinity="">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
            <intent-filter android:autoVerify="true">
                <action android:name="android.intent.action.VIEW"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <category android:name="android.intent.category.BROWSABLE"/>
                <data android:scheme="http"/>
                <data android:scheme="https"/>
                <data android:host="app.example.com"/>
            </intent-filter>
        </activity>
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
</manifest>
''';

/// Seeds a Magic app with every native project a social install touches: both
/// plugin lists, an Info.plist, split Debug/Release entitlements wired through
/// a pbxproj, an Android manifest with a host-wide App Link on
/// `app.example.com`, and `web/`. [withStarter] adds `magic_starter` to the
/// pubspec dependencies.
void seedSocialProject(Directory root, {bool withStarter = true}) {
  _write(root, 'pubspec.yaml', '''
name: test_app

dependencies:
  flutter:
    sdk: flutter
${withStarter ? '  magic_starter: ^0.0.38\n' : ''}''');

  _write(root, 'lib/config/app.dart', '''
import 'package:magic/magic.dart';

import '../app/providers/app_service_provider.dart';

Map<String, dynamic> get appConfig => {
  'app': {
    'name': 'Test App',
    'providers': [
      (app) => AppServiceProvider(app),
    ],
  },
};
''');

  _write(root, 'lib/main.dart', '''
import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import 'config/app.dart';

void main() async {
  await Magic.init(
    configFactories: [
      () => appConfig,
    ],
  );
}
''');

  _write(root, 'ios/Runner/Info.plist', _emptyPlist);
  _write(root, 'ios/Runner/Runner.entitlements', _emptyPlist);
  _write(root, 'ios/Runner/RunnerRelease.entitlements', _emptyPlist);
  _write(root, 'ios/Runner.xcodeproj/project.pbxproj', _splitPbxproj);
  _write(
    root,
    'android/app/src/main/AndroidManifest.xml',
    _manifestWithHostWideAppLink,
  );
  _write(root, 'web/index.html', '<html><head></head><body></body></html>\n');
}

/// Content hash of every file under [root] except the install record, whose
/// timestamp moves on every run.
String snapshot(Directory root) {
  final List<File> files =
      root
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => !file.path.contains('/.artisan/'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  return md5
      .convert(
        utf8.encode(
          files
              .map(
                (file) =>
                    '${file.path}\n${md5.convert(file.readAsBytesSync())}',
              )
              .join('\n'),
        ),
      )
      .toString();
}

/// The member names the starter's `MagicStarterSocialAuth` contract declares.
///
/// The contract lives in magic_starter; this package must not depend on it, so
/// the file is read from a checkout instead. Null when none is found.
String? _contractSource() {
  const List<String> candidates = <String>[
    '/Users/anilcan/Code/fluttersdk/.worktrees/magic_starter-social-client/'
        'lib/src/contracts/magic_starter_social_auth.dart',
    '../magic_starter/lib/src/contracts/magic_starter_social_auth.dart',
  ];

  for (final String path in candidates) {
    final File file = File(path);
    if (file.existsSync()) return file.readAsStringSync();
  }

  return null;
}

List<String> _contractMembers(String source) {
  final String body = RegExp(
    r'abstract class MagicStarterSocialAuth \{(.*?)\n\}',
    dotAll: true,
  ).firstMatch(source)!.group(1)!;
  final String withoutDocs = body.replaceAll(
    RegExp(r'^\s*///.*$', multiLine: true),
    '',
  );

  return <String>[
    for (final String declaration in withoutDocs.split(';'))
      if (RegExp(r'\b(\w+)\([^()]*\)\s*$').firstMatch(declaration.trim())
          case final RegExpMatch match?)
        match.group(1)!,
  ];
}

void main() {
  group('SocialInstallCommand', () {
    test('name is social:install', () {
      final cmd = TestableSocialInstallCommand(
        manifestPath: realManifestPath,
        projectRoot: '/test',
      );
      expect(cmd.name, 'social:install');
    });

    test('description mentions social auth or provider', () {
      final cmd = TestableSocialInstallCommand(
        manifestPath: realManifestPath,
        projectRoot: '/test',
      );
      expect(
        cmd.description.toLowerCase(),
        anyOf(contains('social'), contains('provider'), contains('inject')),
      );
    });

    test('declares every provider flag', () {
      final cmd = TestableSocialInstallCommand(
        manifestPath: realManifestPath,
        projectRoot: '/test',
      );
      final ArgParser parser = ArgParser();
      cmd.configure(parser);

      expect(
        parser.options.keys,
        containsAll(<String>[
          'providers',
          'google-ios-client-id',
          'google-server-client-id',
          'ios-scheme',
          'android-callback',
        ]),
      );
    });

    group('handle', () {
      late Directory tempDir;

      setUp(() {
        tempDir = Directory.systemTemp.createTempSync(
          'social_install_command_test_',
        );
      });

      tearDown(() {
        tempDir.deleteSync(recursive: true);
      });

      test('returns 1 when manifest is absent', () async {
        final cmd = TestableSocialInstallCommand(
          manifestPath: '/nonexistent/install.yaml',
          projectRoot: tempDir.path,
        );
        final exitCode = await cmd.handle(_ctx({}));
        expect(exitCode, 1);
      });

      test('dry-run lists every op and writes nothing', () async {
        seedSocialProject(tempDir);
        final String before = snapshot(tempDir);

        final run = await runInstall(tempDir, {
          ...fullInstallFlags,
          'dry-run': true,
        });

        expect(run.exitCode, 0);
        expect(snapshot(tempDir), before);
        expect(Directory('${tempDir.path}/.artisan').existsSync(), isFalse);
        for (final String op in <String>[
          '[inject-plist-key:ios] GIDClientID',
          '[inject-plist-key:ios] GIDServerClientID',
          '[inject-plist-url-scheme:ios] $reversedIosClientId',
          '[inject-entitlement] ios: com.apple.developer.applesignin',
          '[inject-android-activity] com.linusu.flutter_web_auth_2.CallbackActivity',
          '[write-file] lib/config/social_auth.dart',
          '[write-file] web/auth.html',
          '[write-file] lib/app/providers/social_auth_starter_service_provider.dart',
          "[inject-import] lib/config/app.dart: import 'package:magic_social_auth/magic_social_auth.dart';",
          "[inject-import] lib/config/app.dart: "
              "import '../app/providers/social_auth_starter_service_provider.dart';",
          "[inject-main-import] import 'config/social_auth.dart';",
        ]) {
          expect(run.output, contains(op));
        }
        // Two providers and the config factory.
        expect(
          RegExp(r'\[inject-after\]').allMatches(run.output),
          hasLength(3),
        );
      });

      test(
        'injects SocialAuthServiceProvider into app.dart on success',
        () async {
          seedSocialProject(tempDir);

          // Run with --force to bypass conflict detection.
          final run = await runInstall(tempDir, {'force': true});

          expect(run.exitCode, 0);
          expect(
            read(tempDir, 'lib/config/app.dart'),
            contains('SocialAuthServiceProvider'),
          );
        },
      );

      test('writes every native, config and wiring edit', () async {
        seedSocialProject(tempDir);

        final run = await runInstall(tempDir, fullInstallFlags);

        expect(run.exitCode, 0, reason: run.output);

        // 1. The published config carries the flags.
        final String config = read(tempDir, 'lib/config/social_auth.dart');
        expect(config, contains('Map<String, dynamic> get socialAuthConfig'));
        expect(
          config,
          contains(
            "'ios_client_id': '1234567890-iosclient.apps.googleusercontent.com'",
          ),
        );
        expect(
          config,
          contains(
            "'server_client_id': "
            "'1234567890-webclient.apps.googleusercontent.com'",
          ),
        );
        expect(config, contains("'ios': 'exampleapp://auth/social'"));
        expect(
          config,
          contains("'android': 'https://auth.example.com/auth/social'"),
        );
        expect(RegExp("'enabled': true").allMatches(config), hasLength(4));

        // 2. Both plugin lists name the providers and the config factory.
        final String app = read(tempDir, 'lib/config/app.dart');
        expect(app, contains('(app) => SocialAuthServiceProvider(app),'));
        expect(
          app,
          contains('(app) => SocialAuthStarterServiceProvider(app),'),
        );
        expect(
          app,
          contains(
            "import '../app/providers/social_auth_starter_service_provider.dart';",
          ),
        );
        final String main = read(tempDir, 'lib/main.dart');
        expect(main, contains('() => socialAuthConfig,'));
        expect(main, contains("import 'config/social_auth.dart';"));

        // 3. iOS: the Google keys and scheme, Apple in both signing files.
        final String plist = read(tempDir, 'ios/Runner/Info.plist');
        expect(
          plist,
          contains(
            RegExp(
              r'<key>GIDClientID</key>\s*'
              r'<string>1234567890-iosclient\.apps\.googleusercontent\.com</string>',
            ),
          ),
        );
        expect(
          plist,
          contains(
            RegExp(
              r'<key>GIDServerClientID</key>\s*'
              r'<string>1234567890-webclient\.apps\.googleusercontent\.com</string>',
            ),
          ),
        );
        expect(
          plist,
          contains(
            RegExp(
              r'<key>CFBundleURLSchemes</key>\s*<array>\s*'
              '<string>$reversedIosClientId</string>',
            ),
          ),
        );
        for (final String file in <String>[
          'ios/Runner/Runner.entitlements',
          'ios/Runner/RunnerRelease.entitlements',
        ]) {
          expect(
            read(tempDir, file),
            contains(
              RegExp(
                r'<key>com\.apple\.developer\.applesignin</key>\s*<array>\s*'
                r'<string>Default</string>',
              ),
            ),
            reason: file,
          );
        }

        // 4. Android: the callback activity, with the App Link filter.
        final String manifest = read(
          tempDir,
          'android/app/src/main/AndroidManifest.xml',
        );
        final RegExpMatch activity = RegExp(
          r'<activity\s+[^>]*com\.linusu\.flutter_web_auth_2\.CallbackActivity'
          r'.*?</activity>',
          dotAll: true,
        ).firstMatch(manifest)!;
        expect(activity.group(0), contains('android:exported="true"'));
        expect(activity.group(0), contains('android:taskAffinity=""'));
        expect(activity.group(0), contains('android:autoVerify="true"'));
        expect(activity.group(0), contains('android:scheme="https"'));
        expect(activity.group(0), contains('android:host="auth.example.com"'));
        expect(activity.group(0), contains('android:path="/auth/social"'));

        // 5. Web: the page flutter_web_auth_2 posts back through.
        final String page = read(tempDir, 'web/auth.html');
        expect(page, contains("'flutter-web-auth-2': window.location.href"));
        expect(page, contains('window.location.origin'));
        expect(page, contains("localStorage.setItem('flutter-web-auth-2'"));

        // 6. The bridge, since the app lists magic_starter.
        expect(
          read(
            tempDir,
            'lib/app/providers/social_auth_starter_service_provider.dart',
          ),
          contains(
            'class SocialAuthStarterServiceProvider extends ServiceProvider',
          ),
        );
      });

      test('a second run changes no byte', () async {
        seedSocialProject(tempDir);
        expect((await runInstall(tempDir, fullInstallFlags)).exitCode, 0);
        expect(read(tempDir, 'ios/Runner/Info.plist'), contains('GIDClientID'));
        final String afterFirst = snapshot(tempDir);

        final run = await runInstall(tempDir, fullInstallFlags);

        expect(run.exitCode, 0, reason: run.output);
        expect(snapshot(tempDir), afterFirst);
      });

      test('re-running install is idempotent (no duplicate provider)', () async {
        seedSocialProject(tempDir);

        // 1. First install must succeed.
        expect((await runInstall(tempDir, {'force': true})).exitCode, 0);

        // 2. Second install (new command instance, same project) must succeed.
        expect((await runInstall(tempDir, {'force': true})).exitCode, 0);

        // 3. Match the provider CLOSURE entry, not raw occurrences: the
        //    installer adds an import line AND the providers-list entry, so
        //    counting the bare class name would overcount. The closure
        //    `(app) => SocialAuthServiceProvider(app),` is what must appear
        //    exactly once across both runs.
        final String appContent = read(tempDir, 'lib/config/app.dart');
        final entries = RegExp(
          r'\(app\)\s*=>\s*SocialAuthServiceProvider\(app\),',
        ).allMatches(appContent);
        expect(
          entries.length,
          1,
          reason: 'SocialAuthServiceProvider entry must not be injected twice',
        );
      });

      test(
        'leaves Apple and Google native files alone when they are off',
        () async {
          seedSocialProject(tempDir);

          final run = await runInstall(tempDir, {
            'providers': 'github',
            'android-callback': 'https://auth.example.com/auth/social',
          });

          expect(run.exitCode, 0, reason: run.output);
          final String plist = read(tempDir, 'ios/Runner/Info.plist');
          expect(plist, isNot(contains('GIDClientID')));
          expect(plist, isNot(contains('CFBundleURLSchemes')));
          expect(
            read(tempDir, 'ios/Runner/Runner.entitlements'),
            isNot(contains('applesignin')),
          );
          final String config = read(tempDir, 'lib/config/social_auth.dart');
          expect(RegExp("'enabled': true").allMatches(config), hasLength(1));
          expect(RegExp("'enabled': false").allMatches(config), hasLength(3));
        },
      );

      test(
        'publishes no bridge when the app does not list magic_starter',
        () async {
          seedSocialProject(tempDir, withStarter: false);

          final run = await runInstall(tempDir, fullInstallFlags);

          expect(run.exitCode, 0, reason: run.output);
          expect(
            File(
              '${tempDir.path}/lib/app/providers/social_auth_starter_service_provider.dart',
            ).existsSync(),
            isFalse,
          );
          expect(
            read(tempDir, 'lib/config/app.dart'),
            isNot(contains('SocialAuthStarterServiceProvider')),
          );
        },
      );

      test('skips the web page when the app has no web target', () async {
        seedSocialProject(tempDir);
        Directory('${tempDir.path}/web').deleteSync(recursive: true);

        final run = await runInstall(tempDir, fullInstallFlags);

        expect(run.exitCode, 0, reason: run.output);
        expect(Directory('${tempDir.path}/web').existsSync(), isFalse);
      });

      test(
        'never rewrites a CallbackActivity the app already declares',
        () async {
          seedSocialProject(tempDir);
          const String handEdited =
              '''<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application android:label="Example">
        <activity
            android:name="com.linusu.flutter_web_auth_2.CallbackActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.VIEW"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <category android:name="android.intent.category.BROWSABLE"/>
                <data android:scheme="exampleapp"/>
            </intent-filter>
        </activity>
    </application>
</manifest>
''';
          _write(
            tempDir,
            'android/app/src/main/AndroidManifest.xml',
            handEdited,
          );

          final run = await runInstall(tempDir, fullInstallFlags);

          expect(run.exitCode, 0, reason: run.output);
          expect(
            read(tempDir, 'android/app/src/main/AndroidManifest.xml'),
            handEdited,
          );
        },
      );

      group('refuses a flag it cannot write safely', () {
        for (final MapEntry<String, Map<String, dynamic>> bad
            in <String, Map<String, dynamic>>{
              'an unknown provider': {'providers': 'google,facebook'},
              'a google client id that is not one': {
                'google-ios-client-id': "x'; evil('",
              },
              'a scheme that is not a URL scheme': {'ios-scheme': 'my app'},
              'an http callback': {
                'android-callback': 'http://auth.example.com/auth/social',
              },
              'a callback without a path': {
                'android-callback': 'https://auth.example.com',
              },
            }.entries) {
          test(bad.key, () async {
            seedSocialProject(tempDir);
            final String before = snapshot(tempDir);

            final run = await runInstall(tempDir, bad.value);

            expect(run.exitCode, 1);
            expect(run.output, contains('[ERROR]'));
            expect(snapshot(tempDir), before);
          });
        }
      });
    });

    group('bridge stub', () {
      late Directory tempDir;

      setUp(() {
        tempDir = Directory.systemTemp.createTempSync('social_bridge_stub_');
      });

      tearDown(() {
        tempDir.deleteSync(recursive: true);
      });

      final String? contract = _contractSource();

      test(
        'overrides every member of the MagicStarterSocialAuth contract',
        () async {
          seedSocialProject(tempDir);
          expect((await runInstall(tempDir, fullInstallFlags)).exitCode, 0);
          final String bridge = read(
            tempDir,
            'lib/app/providers/social_auth_starter_service_provider.dart',
          );

          final List<String> members = _contractMembers(contract!);

          expect(
            members,
            containsAll(<String>[
              'providers',
              'label',
              'icon',
              'signIn',
              'beginConnect',
              'confirm',
              'signOut',
            ]),
          );
          for (final String member in members) {
            expect(
              bridge,
              contains(RegExp('@override\\s+[^@{;]*?\\b$member\\(')),
              reason: '$member has no @override in the bridge',
            );
          }
        },
        skip: contract == null ? 'no magic_starter checkout found' : false,
      );
    });
  });
}

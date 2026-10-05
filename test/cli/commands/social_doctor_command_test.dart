import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluttersdk_artisan/artisan.dart';
import 'package:magic_social_auth/cli.dart';
import 'package:magic_social_auth/src/cli/commands/social_doctor_command.dart';

import 'social_install_command_test.dart';

/// Points the doctor at a temp project instead of the working directory.
class _TestableSocialDoctorCommand extends SocialDoctorCommand {
  _TestableSocialDoctorCommand(this.root);

  final String root;

  @override
  String getProjectRoot() => root;
}

Future<({int exitCode, String output})> _runDoctor(Directory root) async {
  final BufferedOutput output = BufferedOutput();
  final int exitCode = await _TestableSocialDoctorCommand(
    root.path,
  ).handle(ArtisanContext.bare(MapInput(const <String, dynamic>{}), output));

  return (exitCode: exitCode, output: output.content);
}

void _rewrite(
  Directory root,
  String relative,
  String Function(String content) edit,
) {
  final File file = File('${root.path}/$relative');
  file.writeAsStringSync(edit(file.readAsStringSync()));
}

const String _manifest = 'android/app/src/main/AndroidManifest.xml';

void main() {
  group('SocialDoctorCommand', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('social_doctor_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    /// Installs everything, so each test breaks exactly one thing.
    Future<void> installed([
      Map<String, dynamic> flags = fullInstallFlags,
    ]) async {
      seedSocialProject(tempDir);
      final install = await runInstall(tempDir, flags);
      expect(install.exitCode, 0, reason: install.output);
    }

    test('name is social:doctor', () {
      expect(SocialDoctorCommand().name, 'social:doctor');
    });

    test('the artisan provider contributes install and doctor', () {
      expect(
        MagicSocialAuthArtisanProvider().commands().map((c) => c.name),
        containsAll(<String>['social:install', 'social:doctor']),
      );
    });

    test('reports a full install clean', () async {
      await installed();

      final run = await _runDoctor(tempDir);

      expect(run.exitCode, 0, reason: run.output);
      expect(run.output, contains('All checks passed'));
    });

    test('prints the backend env lines to set', () async {
      await installed();

      final run = await _runDoctor(tempDir);

      for (final String line in <String>[
        'MAGIC_STARTER_SOCIAL_PROVIDERS=google,apple,github,microsoft',
        'MAGIC_STARTER_SOCIAL_IOS_REDIRECT=exampleapp://auth/social',
        'MAGIC_STARTER_SOCIAL_ANDROID_REDIRECT=https://auth.example.com/auth/social',
        'MAGIC_STARTER_SOCIAL_WEB_REDIRECT=https://<app origin>/auth.html',
        'MAGIC_STARTER_SOCIAL_GOOGLE_AUDIENCES='
            '1234567890-iosclient.apps.googleusercontent.com,'
            '1234567890-webclient.apps.googleusercontent.com',
        'MAGIC_STARTER_SOCIAL_APPLE_AUDIENCES=<ios bundle id>',
        'MAGIC_STARTER_APPLE_TEAM_ID=',
        'MAGIC_STARTER_APPLE_KEY_ID=',
        'MAGIC_STARTER_APPLE_PRIVATE_KEY=',
        'MAGIC_STARTER_APPLE_BUNDLE_ID=<ios bundle id>',
        'MAGIC_STARTER_APPLE_SERVICES_ID=',
        'https://<api host>/magic-starter/social/google/callback',
        'https://<api host>/magic-starter/social/apple/callback',
        'https://<api host>/magic-starter/social/github/callback',
        'https://<api host>/magic-starter/social/microsoft/callback',
      ]) {
        expect(run.output, contains(line));
      }
    });

    test('flags a project with no config', () async {
      seedSocialProject(tempDir);

      final run = await _runDoctor(tempDir);

      expect(run.exitCode, 1);
      expect(run.output, contains('lib/config/social_auth.dart not found'));
    });

    test('flags a callback on a host MainActivity already claims', () async {
      await installed({
        ...fullInstallFlags,
        'android-callback': 'https://app.example.com/auth/social',
      });

      final run = await _runDoctor(tempDir);

      expect(run.exitCode, 1);
      expect(run.output, contains('overlaps'));
      expect(run.output, contains('app.example.com'));
      expect(run.output, contains('.MainActivity'));
    });

    test(
      'accepts a callback on a host another activity claims elsewhere',
      () async {
        seedSocialProject(tempDir);
        _rewrite(
          tempDir,
          _manifest,
          (content) => content.replaceFirst(
            '<data android:host="app.example.com"/>',
            '<data android:host="app.example.com"/>\n'
                '                <data android:pathPrefix="/app"/>',
          ),
        );
        final install = await runInstall(tempDir, {
          ...fullInstallFlags,
          'android-callback': 'https://app.example.com/auth/social',
        });
        expect(install.exitCode, 0, reason: install.output);

        final run = await _runDoctor(tempDir);

        expect(run.exitCode, 0, reason: run.output);
      },
    );

    test('flags iOS with google enabled and apple disabled', () async {
      await installed({...fullInstallFlags, 'providers': 'google'});

      final run = await _runDoctor(tempDir);

      expect(run.exitCode, 1);
      expect(run.output, contains('Apple is disabled'));
      expect(run.output, contains('4.8'));
    });

    test('accepts a lone Apple on iOS', () async {
      await installed({...fullInstallFlags, 'providers': 'apple'});

      final run = await _runDoctor(tempDir);

      expect(run.exitCode, 0, reason: run.output);
    });

    test('flags Sign in with Apple missing from one signing file', () async {
      await installed();
      _rewrite(
        tempDir,
        'ios/Runner/RunnerRelease.entitlements',
        (content) => content.replaceAll(
          RegExp(
            r'<key>com\.apple\.developer\.applesignin</key>\s*<array>.*?</array>',
            dotAll: true,
          ),
          '',
        ),
      );

      final run = await _runDoctor(tempDir);

      expect(run.exitCode, 1);
      expect(run.output, contains('Runner/RunnerRelease.entitlements'));
      expect(run.output, contains('com.apple.developer.applesignin'));
      expect(run.output, isNot(contains('Runner/Runner.entitlements lacks')));
    });

    group('entitlements paths with build variables', () {
      const String pbxproj = 'ios/Runner.xcodeproj/project.pbxproj';

      test('expands \$(SRCROOT) and \$(PROJECT_DIR) to ios/', () async {
        await installed();
        _rewrite(
          tempDir,
          pbxproj,
          (content) => content
              .replaceAll(
                'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;',
                'CODE_SIGN_ENTITLEMENTS = '
                    '"\$(SRCROOT)/Runner/Runner.entitlements";',
              )
              .replaceAll(
                'CODE_SIGN_ENTITLEMENTS = Runner/RunnerRelease.entitlements;',
                'CODE_SIGN_ENTITLEMENTS = '
                    '"\$(PROJECT_DIR)/Runner/RunnerRelease.entitlements";',
              ),
        );
        _rewrite(
          tempDir,
          'ios/Runner/RunnerRelease.entitlements',
          (content) => content.replaceAll(
            RegExp(
              r'<key>com\.apple\.developer\.applesignin</key>\s*<array>.*?</array>',
              dotAll: true,
            ),
            '',
          ),
        );

        final run = await _runDoctor(tempDir);

        expect(run.exitCode, 1, reason: run.output);
        expect(
          run.output,
          contains('ios/Runner/RunnerRelease.entitlements lacks'),
        );
        expect(run.output, isNot(contains('Runner.entitlements not found')));
        expect(run.output, isNot(contains('\$(')));
      });

      test('names any other variable instead of reading it', () async {
        await installed();
        _rewrite(
          tempDir,
          pbxproj,
          (content) => content.replaceAll(
            'CODE_SIGN_ENTITLEMENTS = Runner/RunnerRelease.entitlements;',
            'CODE_SIGN_ENTITLEMENTS = '
                '"\$(TARGET_NAME)/RunnerRelease.entitlements";',
          ),
        );

        final run = await _runDoctor(tempDir);

        expect(run.exitCode, 1);
        expect(run.output, contains('\$(TARGET_NAME)'));
        expect(run.output, isNot(contains('not found, but the app target')));
      });
    });

    test(
      'flags the Google keys and URL scheme missing from Info.plist',
      () async {
        await installed();
        _rewrite(
          tempDir,
          'ios/Runner/Info.plist',
          (content) => content
              .replaceAll(
                RegExp(r'<key>GIDClientID</key>\s*<string>[^<]*</string>'),
                '',
              )
              .replaceAll(reversedIosClientId, 'com.other.scheme'),
        );

        final run = await _runDoctor(tempDir);

        expect(run.exitCode, 1);
        expect(run.output, contains('GIDClientID'));
        expect(run.output, contains(reversedIosClientId));
      },
    );

    test('flags a CallbackActivity without an empty taskAffinity', () async {
      await installed();
      _rewrite(tempDir, _manifest, (content) {
        final int start = content.indexOf(
          'flutter_web_auth_2.CallbackActivity',
        );

        return content.replaceRange(
          start,
          content.length,
          content.substring(start).replaceFirst('android:taskAffinity=""', ''),
        );
      });

      final run = await _runDoctor(tempDir);

      expect(run.exitCode, 1);
      expect(run.output, contains('android:taskAffinity=""'));
    });

    test('flags a CallbackActivity whose filter is not the callback', () async {
      await installed();
      _rewrite(
        tempDir,
        _manifest,
        (content) => content.replaceFirst(
          'android:host="auth.example.com"',
          'android:host="other.example.com"',
        ),
      );

      final run = await _runDoctor(tempDir);

      expect(run.exitCode, 1);
      expect(
        run.output,
        contains(
          'no autoVerify https filter for https://auth.example.com/auth/social',
        ),
      );
    });

    test('flags a project with no CallbackActivity', () async {
      await installed();
      _rewrite(
        tempDir,
        _manifest,
        (content) => content.replaceAll(
          RegExp(
            r'<activity\s+[^>]*CallbackActivity.*?</activity>',
            dotAll: true,
          ),
          '',
        ),
      );

      final run = await _runDoctor(tempDir);

      expect(run.exitCode, 1);
      expect(
        run.output,
        contains(
          'com.linusu.flutter_web_auth_2.CallbackActivity is not declared',
        ),
      );
    });

    test('flags a missing web/auth.html', () async {
      await installed();
      File('${tempDir.path}/web/auth.html').deleteSync();

      final run = await _runDoctor(tempDir);

      expect(run.exitCode, 1);
      expect(run.output, contains('web/auth.html not found'));
    });

    test(
      'flags an empty iOS callback when a browser provider needs it',
      () async {
        await installed({...fullInstallFlags}..remove('ios-scheme'));

        final run = await _runDoctor(tempDir);

        expect(run.exitCode, 1);
        expect(run.output, contains('social_auth.callback.ios is empty'));
      },
    );

    test('flags missing Google client ids', () async {
      await installed({
        'providers': 'google,apple',
        'android-callback': 'https://auth.example.com/auth/social',
      });

      final run = await _runDoctor(tempDir);

      expect(run.exitCode, 1);
      expect(run.output, contains('google.ios_client_id is empty'));
      expect(run.output, contains('google.server_client_id is empty'));
    });

    group('starter bridge', () {
      test('flags a missing bridge when magic_starter is a dependency', () async {
        await installed();
        File(
          '${tempDir.path}/lib/app/providers/social_auth_starter_service_provider.dart',
        ).deleteSync();

        final run = await _runDoctor(tempDir);

        expect(run.exitCode, 1);
        expect(
          run.output,
          contains(
            'lib/app/providers/social_auth_starter_service_provider.dart not found',
          ),
        );
      });

      test('flags a bridge no provider list registers', () async {
        await installed();
        _rewrite(
          tempDir,
          'lib/config/app.dart',
          (content) => content.replaceAll(
            '(app) => SocialAuthStarterServiceProvider(app),',
            '',
          ),
        );

        final run = await _runDoctor(tempDir);

        expect(run.exitCode, 1);
        expect(
          run.output,
          contains('SocialAuthStarterServiceProvider is not registered'),
        );
      });

      test(
        'asks for no bridge when magic_starter is not a dependency',
        () async {
          seedSocialProject(tempDir, withStarter: false);
          expect((await runInstall(tempDir, fullInstallFlags)).exitCode, 0);

          final run = await _runDoctor(tempDir);

          expect(run.exitCode, 0, reason: run.output);
        },
      );
    });
  });
}

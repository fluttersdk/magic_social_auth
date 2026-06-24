import 'dart:io';

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

/// Builds a bare [ArtisanContext] with the given flag overrides.
ArtisanContext _ctx(Map<String, dynamic> overrides) {
  return ArtisanContext.bare(
    MapInput({..._baseFlags, ...overrides}),
    BufferedOutput(),
  );
}

/// Test subclass that:
///   1. Pins [resolveManifestPath] to a caller-supplied path (avoids
///      Isolate.resolvePackageUri which is unavailable in flutter test).
///   2. Overrides [buildContext] to wire the real FS with an explicit
///      projectRoot pointing at the caller-supplied tempDir.
class _TestableSocialInstallCommand extends SocialInstallCommand {
  final String _manifestPath;
  final String _projectRoot;

  _TestableSocialInstallCommand({
    required String manifestPath,
    required String projectRoot,
  })  : _manifestPath = manifestPath,
        _projectRoot = projectRoot;

  @override
  Future<String?> resolveManifestPath() async => _manifestPath;

  @override
  InstallContext buildContext(ArtisanContext ctx) =>
      InstallContext.real(ctx, projectRoot: _projectRoot);
}

void main() {
  group('SocialInstallCommand', () {
    /// Resolved once: the real install.yaml at the package root.
    /// flutter test always runs with cwd set to the package root.
    final realManifestPath = '${Directory.current.path}/install.yaml';

    test('name is social:install', () {
      final cmd = _TestableSocialInstallCommand(
        manifestPath: realManifestPath,
        projectRoot: '/test',
      );
      expect(cmd.name, 'social:install');
    });

    test('description mentions social auth or provider', () {
      final cmd = _TestableSocialInstallCommand(
        manifestPath: realManifestPath,
        projectRoot: '/test',
      );
      expect(
        cmd.description.toLowerCase(),
        anyOf(
          contains('social'),
          contains('provider'),
          contains('inject'),
        ),
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

      /// Seeds a minimal Magic app.dart so provider injection has a target.
      void seedAppFile() {
        final appFile = File('${tempDir.path}/lib/config/app.dart');
        appFile.createSync(recursive: true);
        appFile.writeAsStringSync('''
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
      }

      test('returns 1 when manifest is absent', () async {
        final cmd = _TestableSocialInstallCommand(
          manifestPath: '/nonexistent/install.yaml',
          projectRoot: tempDir.path,
        );
        final exitCode = await cmd.handle(_ctx({}));
        expect(exitCode, 1);
      });

      test('dry-run previews the staged ops and exits 0', () async {
        final cmd = _TestableSocialInstallCommand(
          manifestPath: realManifestPath,
          projectRoot: tempDir.path,
        );
        seedAppFile();

        // 1. Seed a minimal pubspec.yaml so the installer resolves a real
        //    project root instead of bailing out with a manifest error.
        final pubspec = File('${tempDir.path}/pubspec.yaml');
        pubspec.writeAsStringSync('name: test_app\n');

        // 2. Seed .dart_tool/package_config.json (required by PluginsRegistryFile).
        final toolDir = Directory('${tempDir.path}/.dart_tool');
        toolDir.createSync(recursive: true);
        File('${tempDir.path}/.dart_tool/package_config.json')
            .writeAsStringSync('{"configVersion":2,"packages":[]}');

        // 3. A real dry-run stages ops without writing and must succeed.
        final exitCode = await cmd.handle(_ctx({'dry-run': true}));
        expect(exitCode, 0);

        // 4. Dry-run writes nothing: app.dart stays free of the provider.
        final appContent =
            File('${tempDir.path}/lib/config/app.dart').readAsStringSync();
        expect(appContent, isNot(contains('SocialAuthServiceProvider')));
      });

      test('injects SocialAuthServiceProvider into app.dart on success',
          () async {
        final cmd = _TestableSocialInstallCommand(
          manifestPath: realManifestPath,
          projectRoot: tempDir.path,
        );
        seedAppFile();

        // 1. Seed a minimal pubspec.yaml so the installer can write the record.
        final pubspec = File('${tempDir.path}/pubspec.yaml');
        pubspec.writeAsStringSync('name: test_app\n');

        // 2. Seed .dart_tool/package_config.json (required by PluginsRegistryFile).
        final toolDir = Directory('${tempDir.path}/.dart_tool');
        toolDir.createSync(recursive: true);
        File('${tempDir.path}/.dart_tool/package_config.json')
            .writeAsStringSync('{"configVersion":2,"packages":[]}');

        // 3. Run with --force to bypass conflict detection.
        final exitCode = await cmd.handle(_ctx({'force': true}));
        expect(exitCode, 0);

        // 4. Verify provider injection.
        final appContent =
            File('${tempDir.path}/lib/config/app.dart').readAsStringSync();
        expect(appContent, contains('SocialAuthServiceProvider'));
      });

      test('re-running install is idempotent (no duplicate provider)',
          () async {
        final cmd1 = _TestableSocialInstallCommand(
          manifestPath: realManifestPath,
          projectRoot: tempDir.path,
        );
        final cmd2 = _TestableSocialInstallCommand(
          manifestPath: realManifestPath,
          projectRoot: tempDir.path,
        );
        seedAppFile();

        final pubspec = File('${tempDir.path}/pubspec.yaml');
        pubspec.writeAsStringSync('name: test_app\n');

        final toolDir = Directory('${tempDir.path}/.dart_tool');
        toolDir.createSync(recursive: true);
        File('${tempDir.path}/.dart_tool/package_config.json')
            .writeAsStringSync('{"configVersion":2,"packages":[]}');

        // 1. First install must succeed.
        final firstExit = await cmd1.handle(_ctx({'force': true}));
        expect(firstExit, 0);

        // 2. Second install (new command instance, same project) must succeed.
        final secondExit = await cmd2.handle(_ctx({'force': true}));
        expect(secondExit, 0);

        // 3. Match the provider CLOSURE entry, not raw occurrences: the
        //    installer adds an import line AND the providers-list entry, so
        //    counting the bare class name would overcount. The closure
        //    `(app) => SocialAuthServiceProvider(app),` is what must appear
        //    exactly once across both runs.
        final appContent =
            File('${tempDir.path}/lib/config/app.dart').readAsStringSync();
        final entries = RegExp(
          r'\(app\)\s*=>\s*SocialAuthServiceProvider\(app\),',
        ).allMatches(appContent);
        expect(
          entries.length,
          1,
          reason: 'SocialAuthServiceProvider entry must not be injected twice',
        );
      });
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_social_auth/src/contracts/social_driver.dart';
import 'package:magic_social_auth/src/drivers/apple_driver.dart';
import 'package:magic_social_auth/src/drivers/google_driver.dart';
import 'package:magic_social_auth/src/drivers/redirect_driver.dart';
import 'package:magic_social_auth/src/exceptions/social_auth_exception.dart';
import 'package:magic_social_auth/src/models/social_auth_result.dart';
import 'package:magic_social_auth/src/models/social_platform.dart';
import 'package:magic_social_auth/src/social_auth_manager.dart';

/// A driver that records its sign-out.
class MockDriver extends SocialDriver {
  MockDriver(super.config);

  bool signOutCalled = false;

  @override
  String get name => 'mock';

  @override
  Set<SocialPlatform> get supportedPlatforms => SocialPlatform.values.toSet();

  @override
  Future<SocialAuthResult> signIn() async => const SocialAuthResult();

  @override
  Future<Future<SocialAuthResult> Function()> beginConnect(
    Map<String, String>? proof,
  ) async {
    return () async => const SocialAuthResult();
  }

  @override
  Future<SocialAuthResult> confirm() async => const SocialAuthResult();

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }
}

void main() {
  late SocialAuthManager manager;

  setUp(() {
    MagicApp.reset();
    Config.flush();
    manager = SocialAuthManager();
    manager.forgetDrivers();
  });

  tearDown(() {
    manager.platformOverride = null;
    MagicApp.reset();
  });

  group('built-in drivers', () {
    test('resolve google, apple, github and microsoft with no config', () {
      for (final String name in ['google', 'apple', 'github', 'microsoft']) {
        expect(manager.driver(name).name, name);
      }
    });

    test('use the native SDKs where they run', () {
      manager.platformOverride = SocialPlatform.ios;

      expect(manager.driver('google'), isA<GoogleDriver>());
      expect(manager.driver('apple'), isA<AppleDriver>());
      expect(manager.driver('github'), isA<RedirectDriver>());
      expect(manager.driver('microsoft'), isA<RedirectDriver>());
    });

    test('Apple on Android goes through the browser flow', () {
      manager.platformOverride = SocialPlatform.android;

      final SocialDriver apple = manager.driver('apple');

      expect(apple, isA<RedirectDriver>());
      expect(apple.name, 'apple');
      expect(apple.supportsPlatform(), isTrue);
      expect(manager.driver('google'), isA<GoogleDriver>());
    });

    test('every provider goes through the browser flow on the web', () {
      manager.platformOverride = SocialPlatform.web;

      for (final String name in ['google', 'apple', 'github', 'microsoft']) {
        expect(manager.driver(name), isA<RedirectDriver>());
        expect(manager.driver(name).supportsPlatform(), isTrue);
      }
    });

    test('a disabled provider is refused', () {
      Config.set('social_auth.providers.github', {'enabled': false});

      expect(
        () => manager.driver('github'),
        throwsA(isA<ProviderNotConfiguredException>()),
      );
    });

    test('an unknown provider is an ArgumentError', () {
      expect(() => manager.driver('nonexistent'), throwsArgumentError);
    });

    test('drivers receive their provider config', () {
      Config.set('social_auth.providers.google', {
        'server_client_id': 'web-client',
      });
      manager.platformOverride = SocialPlatform.android;

      final GoogleDriver google = manager.driver('google') as GoogleDriver;

      expect(google.serverClientId, 'web-client');
    });
  });

  group('extend', () {
    test('registers a custom driver and caches it', () {
      manager.extend('custom', (config) => MockDriver(config));

      expect(manager.driver('custom'), isA<MockDriver>());
      expect(manager.driver('custom'), same(manager.driver('custom')));
    });

    test('overrides a built-in provider', () {
      manager.extend('google', (config) => MockDriver(config));

      expect(manager.driver('google'), isA<MockDriver>());
    });

    test('forgetDrivers rebuilds on the next call', () {
      int built = 0;
      manager.extend('mock', (config) {
        built++;

        return MockDriver(config);
      });

      manager.driver('mock');
      manager.forgetDrivers();
      manager.driver('mock');

      expect(built, 2);
    });
  });

  group('signOut', () {
    test('signs out every cached driver and clears the cache', () async {
      final MockDriver first = MockDriver(const {});
      final MockDriver second = MockDriver(const {});
      int built = 0;
      manager.extend('mock1', (config) {
        built++;

        return first;
      });
      manager.extend('mock2', (config) => second);
      manager.driver('mock1');
      manager.driver('mock2');

      await manager.signOut();
      manager.driver('mock1');

      expect(first.signOutCalled, isTrue);
      expect(second.signOutCalled, isTrue);
      expect(built, 2);
    });

    test('completes with nothing cached', () async {
      await expectLater(manager.signOut(), completes);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:magic_social_auth/src/social_auth_manager.dart';
import 'package:magic_social_auth/src/contracts/social_driver.dart';
import 'package:magic_social_auth/src/models/social_token.dart';
import 'package:magic_social_auth/src/models/social_platform.dart';

/// Mock driver for testing
class MockDriver extends SocialDriver {
  bool signOutCalled = false;

  MockDriver(super.config);

  @override
  String get name => 'mock';

  @override
  Set<SocialPlatform> get supportedPlatforms => {
        SocialPlatform.web,
        SocialPlatform.ios,
        SocialPlatform.android,
        SocialPlatform.macos,
        SocialPlatform.windows,
        SocialPlatform.linux,
      };

  @override
  Future<SocialToken> getToken() async {
    return const SocialToken(
      provider: 'mock',
      accessToken: 'mock_token',
    );
  }

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }
}

void main() {
  group('SocialAuthManager Integration', () {
    late SocialAuthManager manager;

    setUp(() {
      manager = SocialAuthManager();
      manager.forgetDrivers();
    });

    test('driver returns driver instance', () {
      // Register mock driver
      manager.extend('mock', (config) => MockDriver(config));

      final driver = manager.driver('mock');
      expect(driver, isA<SocialDriver>());
      expect(driver.name, 'mock');
    });

    test('driver supportsPlatform works for registered driver', () {
      manager.extend('mock', (config) => MockDriver(config));
      final driver = manager.driver('mock');
      expect(driver.supportsPlatform(), isTrue);
    });

    test('unregistered driver throws ArgumentError', () {
      expect(
        () => manager.driver('nonexistent'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('signOut completes without error', () async {
      await expectLater(manager.signOut(), completes);
    });

    test('signOut calls driver signOut and clears cache', () async {
      int factoryCallCount = 0;
      MockDriver? lastDriver;

      manager.extend('mock', (config) {
        factoryCallCount++;
        lastDriver = MockDriver(config);
        return lastDriver!;
      });

      // Access driver to cache it
      manager.driver('mock');
      expect(factoryCallCount, 1);
      expect(lastDriver, isNotNull);
      final firstDriver = lastDriver!;

      // Call signOut
      await manager.signOut();

      // signOut should have been called
      expect(firstDriver.signOutCalled, isTrue);

      // Manager should have cleared the cache
      // Accessing driver again should call factory again
      manager.driver('mock');
      expect(factoryCallCount, 2);
    });

    test('multiple drivers can be registered and used', () {
      manager.extend('mock1', (config) => MockDriver(config));
      manager.extend('mock2', (config) => MockDriver(config));

      final driver1 = manager.driver('mock1');
      final driver2 = manager.driver('mock2');

      expect(driver1, isA<MockDriver>());
      expect(driver2, isA<MockDriver>());
      expect(driver1, isNot(same(driver2)));
    });
  });
}

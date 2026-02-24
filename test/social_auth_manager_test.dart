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
        SocialPlatform.ios,
        SocialPlatform.android,
        SocialPlatform.web,
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
  group('SocialAuthManager', () {
    late SocialAuthManager manager;

    setUp(() {
      manager = SocialAuthManager();
      manager.forgetDrivers(); // Clear any cached drivers
    });

    group('driver resolution', () {
      test('driver returns cached instance on second call', () {
        manager.extend('mock', (config) => MockDriver(config));

        final driver1 = manager.driver('mock');
        final driver2 = manager.driver('mock');

        expect(driver1, same(driver2));
      });

      test('driver throws for unsupported driver', () {
        expect(
          () => manager.driver('nonexistent'),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('extend registers custom driver factory', () {
        manager.extend('custom', (config) => MockDriver(config));
        final driver = manager.driver('custom');
        expect(driver, isA<MockDriver>());
      });

      test('forgetDrivers clears cache', () {
        int callCount = 0;
        manager.extend('mock', (config) {
          callCount++;
          return MockDriver(config);
        });

        manager.driver('mock');
        expect(callCount, 1);

        manager.forgetDrivers();

        manager.driver('mock');
        expect(callCount, 2);
      });
    });

    group('platform support', () {
      test('driver supportsPlatform can be called', () {
        manager.extend('mock', (config) => MockDriver(config));
        final driver = manager.driver('mock');
        // supportsPlatform() checks against current platform
        // MockDriver declares support for all platforms, so this will be true
        expect(driver.supportsPlatform(), isTrue);
      });

      test('resolving unsupported driver throws', () {
        expect(
          () => manager.driver('nonexistent'),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('signOut', () {
      test('signOut calls signOut on all cached drivers', () async {
        // Create mock driver and register it
        final mockDriver = MockDriver({});
        manager.extend('mock', (config) => mockDriver);

        // Access the driver to cache it
        manager.driver('mock');

        // Call signOut
        await manager.signOut();

        expect(mockDriver.signOutCalled, isTrue);
      });

      test('signOut clears cached driver instances', () async {
        // Track how many times factory is called
        int factoryCallCount = 0;
        manager.extend('mock', (config) {
          factoryCallCount++;
          return MockDriver(config);
        });

        // Access driver once - factory called once
        manager.driver('mock');
        expect(factoryCallCount, 1);

        // Call signOut - should clear cache
        await manager.signOut();

        // Access driver again - factory should be called again (not from cache)
        manager.driver('mock');
        expect(factoryCallCount, 2);
      });

      test('signOut handles multiple cached drivers', () async {
        final mockDriver1 = MockDriver({});
        final mockDriver2 = MockDriver({});

        manager.extend('mock1', (config) => mockDriver1);
        manager.extend('mock2', (config) => mockDriver2);

        // Cache both drivers
        manager.driver('mock1');
        manager.driver('mock2');

        // Call signOut
        await manager.signOut();

        // Both should have signOut called
        expect(mockDriver1.signOutCalled, isTrue);
        expect(mockDriver2.signOutCalled, isTrue);
      });
    });
  });
}

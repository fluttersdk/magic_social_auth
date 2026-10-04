import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_social_auth/src/contracts/social_driver.dart';
import 'package:magic_social_auth/src/drivers/redirect_driver.dart';
import 'package:magic_social_auth/src/facades/social_auth.dart';
import 'package:magic_social_auth/src/models/social_auth_result.dart';
import 'package:magic_social_auth/src/models/social_platform.dart';
import 'package:magic_social_auth/src/social_auth_manager.dart';

/// A driver that runs everywhere and records its sign-out.
class MockDriver extends SocialDriver {
  MockDriver(super.config, {super.platform});

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
    manager = SocialAuthManager()..forgetDrivers();
    MagicApp.instance.singleton('social_auth', () => manager);
  });

  tearDown(() {
    manager.platformOverride = null;
    MagicApp.reset();
  });

  test('driver resolves through the bound manager', () {
    manager.extend('mock', (config) => MockDriver(config));

    expect(SocialAuth.driver('mock'), same(manager.driver('mock')));
  });

  test('driver on a forced Android platform serves Apple by redirect', () {
    manager.platformOverride = SocialPlatform.android;

    expect(SocialAuth.driver('apple'), isA<RedirectDriver>());
    expect(SocialAuth.supports('apple'), isTrue);
  });

  test('supports is false for an unknown provider', () {
    expect(SocialAuth.supports('nonexistent'), isFalse);
  });

  test('supports is false for a provider off its platforms', () {
    manager.extend(
      'ios-only',
      (config) => _IosOnlyDriver(config, platform: SocialPlatform.android),
    );

    expect(SocialAuth.supports('ios-only'), isFalse);
  });

  test('signOut signs out the cached drivers', () async {
    final MockDriver driver = MockDriver(const {});
    manager.extend('mock', (config) => driver);
    SocialAuth.driver('mock');

    await SocialAuth.signOut();

    expect(driver.signOutCalled, isTrue);
  });
}

class _IosOnlyDriver extends MockDriver {
  _IosOnlyDriver(super.config, {super.platform});

  @override
  Set<SocialPlatform> get supportedPlatforms => {SocialPlatform.ios};
}
